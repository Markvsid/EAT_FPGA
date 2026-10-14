"""Integer-only full-model candidate with traceable finite-width behavior.

Input values are signed INT8 at the export's fixed input exponent. Host-side
normalization/quantization is outside this runtime. No float is used here.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from native.kernel import NativeKernel

from golden.arithmetic import checked, online_attention, pwl_activation, rmsnorm, rmsnorm_lut, round_divide, saturate, shift_round


class IntegerEncoder:
    def __init__(self, export_path, use_native=None):
        root = Path(export_path)
        self.manifest = json.loads((root / "manifest.json").read_text())
        if hashlib.sha256((root / "constants.npz").read_bytes()).hexdigest() != self.manifest["constants_sha256"]:
            raise ValueError("Integer constants checksum mismatch")
        with np.load(root / "constants.npz", allow_pickle=False) as arrays:
            self.constants = {key: arrays[key].astype(np.int64) for key in arrays.files}
        self.config = self.manifest["config"]
        self.mode = self.manifest["mode"]
        self.spec = self.manifest["spec"]
        if self.spec["state_fraction_bits"] != 12:
            raise ValueError("v1 norm epsilon and export require Q12 state")
        self.trace = {}
        self.saturations = {}
        self.native = None
        if use_native is not False and Path("native/build_metadata.json").exists():
            self.native = NativeKernel()
        if use_native is True and self.native is None:
            raise ValueError("Build the native kernel before requesting it")

    def record(self, name, value):
        value = np.asarray(value, dtype=np.int64)
        clipped = saturate(value, self.spec["state_signed_bits"])
        self.saturations[name] = self.saturations.get(name, 0) + int(np.count_nonzero(value != clipped))
        self.trace[name] = clipped.copy()
        return clipped

    def linear(self, name, x):
        layer = self.manifest["layers"][name]
        raw = shift_round(x, layer["q12_to_int8_shift"])
        q = saturate(raw, 8)
        self.saturations[name + ".input_int8"] = self.saturations.get(name + ".input_int8", 0) + int(np.count_nonzero(raw != q))
        weights = self.constants[name + ".weight"]
        # A8 and W8 with <=256 reduction elements are safe inside INT64;
        # enforce the configured finite hardware accumulator after bias addition.
        if x.shape[-1] != weights.shape[-1] or weights.shape[-1] > 256:
            raise ValueError("Unsupported reduction width")
        dot = self.native.matmul(q, weights) if self.native else q @ weights.T
        accumulator = dot + self.constants[name + ".bias"]
        checked(accumulator, self.spec["linear_accumulator_signed_bits"], name + " accumulator")
        multiplier = self.constants[name + ".multiplier"]
        if int(np.abs(accumulator).max(initial=0)) * int(np.abs(multiplier).max(initial=0)) > (1 << 62) - 1:
            raise OverflowError("Requantization product exceeds safe integer range")
        result = shift_round(accumulator * multiplier, self.spec["weight_multiplier_fraction_bits"])
        self.trace[name + ".input_int8"] = q.copy()
        self.trace[name + ".accumulator"] = accumulator.copy()
        return self.record(name, result)

    def norm(self, name, x):
        if self.spec.get("rmsnorm_implementation") == "rsqrt_lut":
            return self.record(name, rmsnorm_lut(x, self.constants[name + ".gamma"], self.constants["rsqrt_table"], self.spec))
        return self.record(name, rmsnorm(x, self.constants[name + ".gamma"], self.spec))

    def gate(self, x):
        g = self.config["group_size"]
        n, d = x.shape
        keep = self.mode["keep_groups"]
        if n % g or not 1 <= keep <= n // g:
            raise ValueError("Illegal token grouping")
        token_scores = self.linear("gate.scorer", x).reshape(n // g, g)
        # Compare exact sums, avoiding rounding-induced changes to mean ordering.
        scores = token_scores.sum(-1)
        selected = np.argsort(-scores, kind="stable")[:keep]
        mask = np.zeros(n // g, dtype=bool)
        mask[selected] = True
        self.trace["gate.group_sums"] = scores
        self.trace["gate.selected_groups"] = np.flatnonzero(mask)
        groups = x.reshape(n // g, g, d)
        result = []
        for index in range(n // g):
            if mask[index]:
                result.append(groups[index])
            elif self.mode["rts"]:
                weights = np.abs(token_scores[index]) + (1 << self.spec["state_fraction_bits"])
                checked(weights, 25, "summary importance")
                numerator = (groups[index] * weights[:, None]).sum(0)
                checked(numerator, 53, "summary weighted sum")
                result.append(round_divide(numerator, weights.sum())[None])
        return self.record("gate.compacted", np.concatenate(result, axis=0))

    def predict(self, input_int8):
        self.trace, self.saturations = {}, {}
        c = self.config
        x = np.asarray(input_int8)
        if not np.issubdtype(x.dtype, np.integer) or x.shape != (c["window_samples"], len(c["channels"])):
            raise ValueError("Expected one signed INT8 input window")
        x = checked(x, 8, "model input")
        x = x << self.manifest["input_q12_shift"]
        x = x.reshape(-1, c["patch_samples"] * len(c["channels"]))
        x = self.linear("embedding", x)
        x = self.record("position_added", x + self.constants["position"])
        for index in range(self.mode["exit_block"]):
            name = f"blocks.{index}"
            qkv = self.linear(name + ".qkv", self.norm(name + ".norm1", x))
            n, d = x.shape
            q, k, v = qkv.reshape(n, 3, c["heads"], d // c["heads"]).transpose(1, 2, 0, 3)
            if "attention_qkv_int8_shifts" in self.manifest:
                quantized = []
                for tensor, shift, kind in zip([q, k, v], self.manifest["attention_qkv_int8_shifts"][name], ["q", "k", "v"]):
                    raw = shift_round(tensor, shift)
                    clipped = saturate(raw, 8)
                    self.saturations[name + "." + kind + ".int8"] = int(np.count_nonzero(raw != clipped))
                    quantized.append(clipped << shift)
                q, k, v = quantized
            self.trace[name + ".q"] = q.copy()
            self.trace[name + ".k"] = k.copy()
            self.trace[name + ".v"] = v.copy()
            attention = online_attention(q, k, v, self.constants["exp_table"], self.spec,
                                         self.manifest["attention_scale_multiplier_q20"])
            attention = self.record(name + ".attention", attention.transpose(1, 0, 2).reshape(n, d))
            x = self.record(name + ".residual1", x + self.linear(name + ".projection", attention))
            y = self.linear(name + ".fc1", self.norm(name + ".norm2", x))
            y = self.record(name + ".activation", pwl_activation(y, self.constants["silu_knots"], self.spec))
            x = self.record(name + ".residual2", x + self.linear(name + ".fc2", y))
            if index + 1 == c["gate_after_block"] and self.mode["keep_groups"] < n // c["group_size"]:
                x = self.gate(x)
        x = self.norm("norm", x)
        x = self.record("pooled", round_divide(x.sum(0), x.shape[0]))
        classifier = "exit_classifier" if self.mode["exit_block"] == 2 else "classifier"
        return self.linear(classifier, x)
