"""Train with validation-only model selection and explicit final-test opt-in."""
import argparse
import hashlib
import json
import platform
import random
import subprocess
import time
from pathlib import Path

import numpy as np
import torch
from torch.utils.data import DataLoader, TensorDataset

from model.network import Encoder


def metrics(labels, predictions, classes):
    confusion = np.zeros((classes, classes), dtype=np.int64)
    np.add.at(confusion, (labels, predictions), 1)
    tp = confusion.diagonal()
    denominator = confusion.sum(0) + confusion.sum(1)
    f1 = np.divide(2 * tp, denominator, out=np.zeros(classes, dtype=float), where=denominator > 0)
    return {"samples": int(confusion.sum()), "accuracy": float(tp.sum() / confusion.sum()),
            "macro_f1": float(f1.mean()), "confusion_matrix": confusion.tolist()}


def loader(path, batch, shuffle, seed):
    with np.load(path) as data:
        dataset = TensorDataset(torch.from_numpy(data["x"]), torch.from_numpy(data["y"]))
    return DataLoader(dataset, batch_size=batch, shuffle=shuffle, num_workers=0,
                      generator=torch.Generator().manual_seed(seed))


@torch.no_grad()
def evaluate(model, batches, device, mode):
    model.eval()
    labels, predictions = [], []
    for x, y in batches:
        labels.extend(y.tolist())
        predictions.extend(model(x.to(device), mode).argmax(-1).cpu().tolist())
    return metrics(labels, predictions, model.config["classes"])


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--config", default="config/har.json")
    p.add_argument("--data", default="data/har")
    p.add_argument("--output", required=True)
    p.add_argument("--seed", type=int, default=17)
    p.add_argument("--epochs", type=int)
    p.add_argument("--device", choices=["cpu", "mps", "cuda"], default="cpu")
    p.add_argument("--mode", choices=["fp32", "quality", "balanced", "energy_saver"], default="fp32")
    p.add_argument("--initialize", help="Checkpoint for comparable fine-tuning")
    p.add_argument("--experiment-id", help="Distinct comparison protocol name")
    p.add_argument("--joint-modes", action="store_true", help="Train one shared checkpoint across all three runtime modes")
    p.add_argument("--keep-groups", type=int, help="Experimental ablation override")
    p.add_argument("--weight-bits", type=int, choices=[4, 8], help="Experimental ablation override")
    p.add_argument("--rts", choices=["on", "off"], help="Experimental ablation override")
    p.add_argument("--exit-block", type=int, choices=[2, 4], help="Experimental ablation override")
    p.add_argument("--final-test", action="store_true", help="Use only after locking modes and training protocol")
    args = p.parse_args()
    c = json.loads(Path(args.config).read_text())
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    torch.set_num_threads(4)
    if args.device == "cpu":
        torch.use_deterministic_algorithms(True)
    model = Encoder(c).to(args.device)
    if args.initialize:
        initial = torch.load(args.initialize, map_location="cpu", weights_only=True)
        if initial["config"] != c:
            raise ValueError("Initialization checkpoint config mismatch")
        model.load_state_dict(initial["model"])
    mode = None if args.mode == "fp32" else c["modes"][args.mode]
    if args.joint_modes and (args.mode != "fp32" or args.keep_groups is not None or args.weight_bits is not None or args.rts is not None or args.exit_block is not None):
        raise ValueError("Joint training uses the configured three modes without individual overrides")
    overrides = {"keep_groups": args.keep_groups, "weight_bits": args.weight_bits,
                 "rts": None if args.rts is None else args.rts == "on", "exit_block": args.exit_block}
    if any(value is not None for value in overrides.values()):
        mode = dict(mode or {"weight_bits": None, "keep_groups": c["window_samples"] // c["patch_samples"] // c["group_size"],
                             "rts": False, "exit_block": c["layers"]})
        mode.update({key: value for key, value in overrides.items() if value is not None})
    train = loader(Path(args.data) / "train.npz", c["batch_size"], True, args.seed)
    validation = loader(Path(args.data) / "validation.npz", c["batch_size"], False, args.seed)
    destination = Path(args.output)
    destination.mkdir(parents=True, exist_ok=False)
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    tracked_diff = subprocess.check_output(["git", "diff", "HEAD"], text=True)
    sources = {str(f): hashlib.sha256(f.read_bytes()).hexdigest() for directory in ["model", "config", "golden", "architecture"]
               for f in Path(directory).glob("**/*") if f.is_file() and "__pycache__" not in f.parts}
    manifest = {"config": c, "seed": args.seed, "mode": args.mode, "execution_mode": mode,
                "experiment_id": args.experiment_id or args.mode, "device": args.device,
                "joint_modes": args.joint_modes,
                "torch": torch.__version__, "numpy": np.__version__, "python": platform.python_version(),
                "git_commit": commit, "git_status": subprocess.check_output(["git", "status", "--porcelain"], text=True),
                "source_sha256": sources, "epochs": args.epochs or c["epochs"],
                "dataset_manifest_sha256": hashlib.sha256((Path(args.data) / "manifest.json").read_bytes()).hexdigest(),
                "initialize_sha256": hashlib.sha256(Path(args.initialize).read_bytes()).hexdigest() if args.initialize else None,
                "numeric_status": "FP32" if mode is None and not args.joint_modes else "experimental_fake_quantization_not_integer_reference",
                "final_test_requested": args.final_test}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (destination / "tracked_changes.patch").write_text(tracked_diff)
    optimizer = torch.optim.AdamW(model.parameters(), lr=c["learning_rate"], weight_decay=c["weight_decay"])
    epochs = manifest["epochs"]
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs)
    best = -1.
    for epoch in range(1, epochs + 1):
        started = time.monotonic()
        model.train()
        loss_sum = 0.
        for x, y in train:
            x, y = x.to(args.device), y.to(args.device)
            optimizer.zero_grad(set_to_none=True)
            execution_mode = random.choice(list(c["modes"].values())) if args.joint_modes else mode
            prediction, auxiliary = model(x, execution_mode, return_aux=True)
            loss = torch.nn.functional.cross_entropy(prediction, y)
            if auxiliary is not None and (execution_mode is None or execution_mode["exit_block"] != 2):
                loss = loss + 0.3 * torch.nn.functional.cross_entropy(auxiliary, y)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.)
            optimizer.step()
            loss_sum += loss.item() * len(y)
        scheduler.step()
        mode_scores = {name: evaluate(model, validation, args.device, value) for name, value in c["modes"].items()} if args.joint_modes else None
        score = evaluate(model, validation, args.device, mode) if not args.joint_modes else {
            "samples": len(validation.dataset) * len(mode_scores),
            "accuracy": sum(s["accuracy"] for s in mode_scores.values()) / len(mode_scores),
            "macro_f1": sum(s["macro_f1"] for s in mode_scores.values()) / len(mode_scores),
            "aggregation": "arithmetic_mean_over_three_modes_not_one_mode"}
        row = {"epoch": epoch, "train_loss": loss_sum / len(train.dataset), "validation": score,
               "seconds": time.monotonic() - started, "validation_modes": mode_scores}
        with (destination / "history.jsonl").open("a") as log:
            log.write(json.dumps(row) + "\n")
        if score["accuracy"] > best:
            best = score["accuracy"]
            torch.save({"model": model.state_dict(), "config": c, "seed": args.seed, "mode": args.mode, "execution_mode": mode,
                        "epoch": epoch, "validation": score, "joint_modes": args.joint_modes,
                        "validation_modes": mode_scores}, destination / "best.tmp.pt")
            (destination / "best.tmp.pt").replace(destination / "best.pt")
        print(json.dumps({"epoch": epoch, "loss": row["train_loss"], "validation_accuracy": score["accuracy"],
                          "seconds": row["seconds"]}), flush=True)
    checkpoint = torch.load(destination / "best.pt", map_location=args.device, weights_only=True)
    model.load_state_dict(checkpoint["model"])
    result = {"selected_epoch": checkpoint["epoch"], "validation": checkpoint["validation"]}
    if args.joint_modes:
        result["validation_modes"] = checkpoint["validation_modes"]
        if args.final_test:
            raise ValueError("Use separate locked per-mode test evaluation for joint checkpoints")
    if args.final_test:
        result["test"] = evaluate(model, loader(Path(args.data) / "test.npz", c["batch_size"], False, args.seed), args.device, mode)
    (destination / "metrics.tmp.json").write_text(json.dumps(result, indent=2) + "\n")
    (destination / "metrics.tmp.json").replace(destination / "metrics.json")


if __name__ == "__main__":
    main()
