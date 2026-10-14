"""Calibrate on training samples and export candidate integer constants.

The training model has dynamic tensor scales. This exporter replaces them with
fixed, per-linear-input power-of-two scales. Quality must be measured anew.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import torch

from model.network import Encoder, Linear, RMSNorm


def export(checkpoint_path, data_path, output, samples=1024, mode_name=None):
    if samples < 1:
        raise ValueError("Calibration sample count must be positive")
    checkpoint_path, data_path, output = map(Path, [checkpoint_path, data_path, output])
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
    c = checkpoint["config"]
    mode = c["modes"][mode_name] if mode_name else checkpoint.get("execution_mode")
    if checkpoint.get("joint_modes") and mode_name is None:
        raise ValueError("Choose --mode explicitly for a joint checkpoint")
    if mode is None:
        mode = c["modes"].get(checkpoint["mode"])
    if mode is None or mode["weight_bits"] not in [4, 8]:
        raise ValueError("Export a quantized-mode checkpoint, not FP32")
    if c["activation"] != "pwl_silu":
        raise ValueError("Only the documented PWL activation is supported")
    spec = json.loads(Path("config/numerics.json").read_text())
    model = Encoder(c).eval()
    model.load_state_dict(checkpoint["model"])
    maxima = {}
    attention_maxima = {}
    hooks = []
    for name, module in model.named_modules():
        if isinstance(module, Linear):
            def observe(_, inputs, name=name):
                maxima[name] = max(maxima.get(name, 0.), float(inputs[0].detach().abs().max()))
            hooks.append(module.register_forward_pre_hook(observe))
            if name.endswith(".qkv"):
                def observe_qkv(_, inputs, output, name=name):
                    split = output.detach().reshape(-1, 3, c["width"])
                    values = split.abs().amax(dim=(0, 2)).numpy()
                    attention_maxima[name] = np.maximum(attention_maxima.get(name, np.zeros(3)), values)
                hooks.append(module.register_forward_hook(observe_qkv))
    with np.load(data_path / "train.npz") as data:
        count = min(samples, len(data["x"]))
        # Evenly spaced, deterministic training-only calibration indices.
        indices = np.linspace(0, len(data["x"]) - 1, count, dtype=int)
        inputs = data["x"][indices]
    torch.set_num_threads(4)
    with torch.no_grad():
        # Use batch 1 because the old activation observer has batch-dependent
        # maxima; this calibrates the target inference boundary explicitly.
        for x in inputs:
            model(torch.from_numpy(x[None]), mode)
    for hook in hooks:
        hook.remove()
    arrays = {}
    layers = {}
    f = spec["state_fraction_bits"]
    input_exp = math.ceil(math.log2(max(float(np.max(np.abs(inputs))) / 127, 1e-8)))
    input_q12_shift = f + input_exp
    for name, module in model.named_modules():
        if isinstance(module, Linear):
            if name not in maxima:
                continue  # Later blocks and unused classifier after early exit.
            weights = module.weight.detach().numpy()
            weight_scale = np.maximum(np.max(np.abs(weights), axis=1) / (2 ** (mode["weight_bits"] - 1) - 1), 1e-8)
            quantized = np.clip(np.rint(weights / weight_scale[:, None]), -(2 ** (mode["weight_bits"] - 1)),
                                2 ** (mode["weight_bits"] - 1) - 1).astype(np.int8)
            exponent = math.ceil(math.log2(max(maxima[name] / 127, 1e-8)))
            exponent = max(exponent, -f)
            output_multiplier = np.rint(weight_scale * 2. ** (exponent + f) * (1 << spec["weight_multiplier_fraction_bits"])).astype(np.int64)
            if np.any(output_multiplier <= 0):
                raise ValueError(f"Unrepresentable output multiplier in {name}; revise candidate scales or multiplier width")
            bias = module.bias.detach().numpy() if module.bias is not None else np.zeros(len(weight_scale))
            # Bias is added in the dot-product accumulator domain.
            bias_integer = np.rint(bias / (weight_scale * 2. ** exponent)).astype(np.int64)
            arrays[name + ".weight"] = quantized
            arrays[name + ".bias"] = bias_integer
            arrays[name + ".multiplier"] = output_multiplier
            layers[name] = {"activation_exponent": exponent, "q12_to_int8_shift": f + exponent,
                            "calibration_maximum": maxima[name], "weight_bits": mode["weight_bits"],
                            "weight_scale": weight_scale.tolist(), "shape": list(weights.shape)}
        elif isinstance(module, RMSNorm):
            arrays[name + ".gamma"] = np.rint(module.weight.detach().numpy() * (1 << spec["norm_gamma_fraction_bits"])).astype(np.int64)
    arrays["position"] = np.rint(model.position.detach().numpy()[0] * (1 << f)).astype(np.int64)
    knots = np.arange(-4, 5, dtype=np.float64)
    arrays["silu_knots"] = np.rint(knots / (1 + np.exp(-knots)) * (1 << f)).astype(np.int64)
    if spec.get("rmsnorm_implementation") == "rsqrt_lut":
        arrays["rsqrt_table"] = np.rint(1 / np.sqrt(np.arange(1024, 2048) / 1024) * (1 << 30)).astype(np.int64)
    count_exp = spec["exp_negative_limit"] * (1 << spec["exp_input_fraction_bits"]) + 1
    arrays["exp_table"] = np.rint(np.exp(-np.arange(count_exp) / (1 << spec["exp_input_fraction_bits"]))
                                   * (1 << spec["exp_fraction_bits"])).astype(np.int64)
    scale_multiplier = round((1 / math.sqrt(c["width"] // c["heads"])) * (1 << 20))
    output.mkdir(parents=True, exist_ok=False)
    np.savez_compressed(output / "constants.npz", **arrays)
    attention_shifts = {name.removesuffix(".qkv"): [max(0, f + math.ceil(math.log2(max(float(value) / 127, 1e-8))))
                                                   for value in maxima] for name, maxima in attention_maxima.items()}
    manifest = {"schema_version": 1, "status": "candidate_integer_export_not_hardware_validated", "config": c,
                "mode": mode, "spec": spec, "layers": layers, "input_q12_shift": max(0, input_q12_shift),
                "attention_scale_multiplier_q20": scale_multiplier, "attention_qkv_int8_shifts": attention_shifts,
                "calibration_indices": indices.tolist(),
                "calibration_partition": "train", "calibration_samples": count,
                "checkpoint_sha256": hashlib.sha256(checkpoint_path.read_bytes()).hexdigest(),
                "dataset_manifest_sha256": hashlib.sha256((data_path / "manifest.json").read_bytes()).hexdigest(),
                "constants_sha256": hashlib.sha256((output / "constants.npz").read_bytes()).hexdigest(),
                "source_sha256": {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in [*Path("golden").glob("*.py"), Path("config/numerics.json")]},
                "checkpoint_path": str(checkpoint_path), "layers_omitted": sorted(set(maxima) - set(layers))}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--checkpoint", required=True)
    p.add_argument("--data", default="data/har")
    p.add_argument("--output", required=True)
    p.add_argument("--samples", type=int, default=1024)
    p.add_argument("--mode", choices=["quality", "balanced", "energy_saver"])
    args = p.parse_args()
    m = export(args.checkpoint, args.data, args.output, args.samples, args.mode)
    print(json.dumps({"mode": m["mode"], "calibration_samples": m["calibration_samples"], "layers": len(m["layers"])}))
