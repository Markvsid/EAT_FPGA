"""Reevaluate saved checkpoints at the batch-1 deployment boundary.

The original dynamic fake quantizer depends on batch maxima. These metrics are
kept separate from the batched validation used to select training checkpoints.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch

from model.network import Encoder
from model.train import evaluate, loader


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", choices=["har", "speech", "all"], default="all")
    args = parser.parse_args()
    torch.set_num_threads(2)
    for metrics in sorted(Path("results/runs").glob("*/metrics.json")):
        root = metrics.parent
        manifest = json.loads((root / "manifest.json").read_text())
        if manifest.get("joint_modes"):
            continue  # Evaluate each mode separately; never default to FP32.
        dataset = "har" if manifest["config"]["classes"] == 6 else "speech"
        if args.dataset != "all" and args.dataset != dataset:
            continue
        output = root / "metrics_batch1.json"
        checkpoint_hash = hashlib.sha256((root / "best.pt").read_bytes()).hexdigest()
        if output.exists():
            saved = json.loads(output.read_text())
            if saved["checkpoint_sha256"] != checkpoint_hash:
                raise ValueError("Existing batch-1 evaluation has a different checkpoint")
            continue
        checkpoint = torch.load(root / "best.pt", map_location="cpu", weights_only=True)
        model = Encoder(manifest["config"]).eval()
        model.load_state_dict(checkpoint["model"])
        mode = manifest.get("execution_mode")
        score = evaluate(model, loader(Path(f"data/{dataset}/validation.npz"), 1, False, manifest["seed"]), "cpu", mode)
        result = {"status": "software_validation_batch1", "partition": "validation", "batch_size": 1,
                  "validation": score, "selected_epoch": checkpoint["epoch"], "checkpoint_sha256": checkpoint_hash,
                  "note": "Checkpoint selected by original batched validation; this is a separate deployment-boundary reevaluation."}
        output.write_text(json.dumps(result, indent=2) + "\n")
        print(f"Batch1 {root.name}: {score['accuracy']:.6f}", flush=True)


if __name__ == "__main__":
    main()
