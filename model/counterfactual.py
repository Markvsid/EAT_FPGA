"""Toggle summaries at fixed weights, precision, scorer, and retained groups.

Independent fine-tuned variants answer a training-level comparison. This test
answers the inference-only question with identical group decisions.
"""
import argparse
import hashlib
import json
from pathlib import Path

import torch

from model.network import Encoder
from model.train import evaluate, loader


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--data", default="data/har")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    checkpoint = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    config = checkpoint["config"]
    mode = checkpoint.get("execution_mode") or config["modes"].get(checkpoint["mode"])
    if not mode or not mode["rts"]:
        raise ValueError("Use an RTS-trained checkpoint")
    model = Encoder(config).eval()
    model.load_state_dict(checkpoint["model"])
    torch.set_num_threads(2)
    scores = {}
    for value, label in [(False, "without_rts"), (True, "with_rts")]:
        score = evaluate(model, loader(Path(args.data) / "validation.npz", 1, False, checkpoint["seed"]),
                         "cpu", {**mode, "rts": value})
        scores[label] = score
    groups = config["window_samples"] // config["patch_samples"] // config["group_size"]
    result = {"status": "validation_counterfactual_same_checkpoint_and_group_decisions", "seed": checkpoint["seed"],
              "checkpoint_sha256": hashlib.sha256(Path(args.checkpoint).read_bytes()).hexdigest(), "mode": mode,
              "tokens_without_rts": mode["keep_groups"] * config["group_size"],
              "tokens_with_rts": mode["keep_groups"] * config["group_size"] + groups - mode["keep_groups"],
              "batch_size": 1, "metrics": scores,
              "accuracy_delta_with_minus_without": scores["with_rts"]["accuracy"] - scores["without_rts"]["accuracy"],
              "note": "Summary removal is an out-of-training-distribution counterfactual; compare with separately trained matched-budget controls as well."}
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: result[key] for key in ["seed", "accuracy_delta_with_minus_without", "tokens_without_rts", "tokens_with_rts"]}))


if __name__ == "__main__":
    main()
