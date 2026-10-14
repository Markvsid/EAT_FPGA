"""Compare integer reference with batch-1 fake quantization on validation only."""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

import numpy as np
import torch

from golden.reference import IntegerEncoder
from model.network import Block, Encoder, Linear, RMSNorm
from model.train import metrics


def evaluate(export_path, data_path, output_path, limit=None):
    reference = IntegerEncoder(export_path)
    manifest = reference.manifest
    checkpoint_path = Path(manifest["checkpoint_path"])
    if hashlib.sha256(checkpoint_path.read_bytes()).hexdigest() != manifest["checkpoint_sha256"]:
        raise ValueError("Comparison checkpoint checksum mismatch")
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
    model = Encoder(reference.config).eval()
    model.load_state_dict(checkpoint["model"])
    float_trace = {}
    hooks = []
    for name, module in model.named_modules():
        if isinstance(module, (Linear, RMSNorm, Block)):
            point = name + ".residual2" if isinstance(module, Block) else name
            def capture(_, inputs, output, name=point):
                float_trace[name] = output.detach().numpy().squeeze(0)
            hooks.append(module.register_forward_hook(capture))
    torch.set_num_threads(2)
    with np.load(Path(data_path) / "validation.npz") as data:
        x = data["x"][:limit]
        y = data["y"][:limit]
    f = reference.spec["state_fraction_bits"]
    input_scale = 2. ** (manifest["input_q12_shift"] - f)
    integer_predictions, fake_predictions, errors = [], [], []
    saturation_counts = Counter()
    trace_errors = {}
    output_path = Path(output_path)
    output_path.mkdir(parents=True, exist_ok=False)
    for index, window in enumerate(x):
        quantized = np.clip(np.rint(window / input_scale), -128, 127).astype(np.int8)
        logits = reference.predict(quantized)
        float_trace.clear()
        with torch.no_grad():
            fake = model(torch.from_numpy(window[None]), reference.mode)[0].numpy()
        selection_same = True
        if "gate.selected_groups" in reference.trace:
            score = float_trace["gate.scorer"].reshape(-1, reference.config["group_size"]).sum(-1)
            selected = np.sort(np.argsort(-score, kind="stable")[:reference.mode["keep_groups"]])
            selection_same = np.array_equal(selected, reference.trace["gate.selected_groups"])
        for name, values in float_trace.items():
            if name not in reference.trace or values.shape != reference.trace[name].shape:
                continue
            # Later token rows cannot be compared by position if group choices differ.
            if not selection_same and (name == "norm" or name.startswith(("blocks.1", "blocks.2", "blocks.3"))):
                continue
            error = float(np.max(np.abs(reference.trace[name] / (1 << f) - values)))
            row = trace_errors.setdefault(name, {"max_absolute_real_error": 0., "compared_windows": 0})
            row["max_absolute_real_error"] = max(row["max_absolute_real_error"], error)
            row["compared_windows"] += 1
        integer_predictions.append(int(logits.argmax()))
        fake_predictions.append(int(fake.argmax()))
        errors.append(float(np.max(np.abs(logits / (1 << f) - fake))))
        saturation_counts.update(reference.saturations)
        if index == 0:
            np.savez_compressed(output_path / "golden_vectors.npz", input_int8=quantized, logits=logits, **reference.trace)
        if (index + 1) % 100 == 0:
            print(f"Compared {index + 1}/{len(x)}", flush=True)
    classes = reference.config["classes"]
    result = {"status": "candidate_integer_validation_not_hardware_equivalence", "partition": "validation",
              "samples": len(y), "mode": reference.mode, "integer": metrics(y, integer_predictions, classes),
              "fake_quantized_batch1": metrics(y, fake_predictions, classes),
              "changed_predictions": int(np.count_nonzero(np.asarray(integer_predictions) != fake_predictions)),
              "maximum_logit_absolute_error": max(errors), "mean_logit_maximum_error": float(np.mean(errors)),
              "saturations": dict(saturation_counts), "export_sha256": manifest["constants_sha256"],
              "checkpoint_sha256": manifest["checkpoint_sha256"],
              "export_manifest_sha256": hashlib.sha256((Path(export_path) / "manifest.json").read_bytes()).hexdigest(),
              "attention_int8_operands": "attention_qkv_int8_shifts" in manifest,
              "trace_errors": trace_errors,
              "native_kernel": reference.native.metadata if reference.native else None,
              "input_scale": input_scale, "input_clipped_values": int(np.count_nonzero((np.rint(x / input_scale) < -128) | (np.rint(x / input_scale) > 127)))}
    (output_path / "metrics.json").write_text(json.dumps(result, indent=2) + "\n")
    np.savez_compressed(output_path / "predictions.npz", labels=y, integer=integer_predictions, fake=fake_predictions,
                        max_logit_error=errors)
    for hook in hooks:
        hook.remove()
    print(json.dumps({key: result[key] for key in ["samples", "changed_predictions", "integer", "fake_quantized_batch1"]}))
    return result


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--export", required=True)
    p.add_argument("--data", default="data/har")
    p.add_argument("--output", required=True)
    p.add_argument("--limit", type=int)
    args = p.parse_args()
    evaluate(args.export, args.data, args.output, args.limit)
