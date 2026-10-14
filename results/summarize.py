"""Summarize actual run metrics, never substitute targets or modeled hardware."""
import argparse
import json
from collections import defaultdict
from pathlib import Path

import numpy as np


def summarize(root):
    groups = defaultdict(list)
    for path in sorted(Path(root).glob("*/metrics.json")):
        manifest = json.loads((path.parent / "manifest.json").read_text())
        result = json.loads(path.read_text())
        batch1_path = path.parent / "metrics_batch1.json"
        if batch1_path.exists():
            result["validation_batch1"] = json.loads(batch1_path.read_text())["validation"]
        label = manifest.get("experiment_id", manifest["mode"])
        if manifest.get("joint_modes"):
            label += "_mean_over_modes"
        key = (manifest["config"]["dataset"], manifest["epochs"], label,
               bool(manifest.get("initialize_sha256")),
               json.dumps(manifest.get("execution_mode"), sort_keys=True))
        groups[key].append({"run": path.parent.name, "seed": manifest["seed"], "result": result,
                            "numeric_status": manifest["numeric_status"]})
    output = []
    for (dataset, epochs, name, fine_tuned, mode), runs in groups.items():
        seeds = [r["seed"] for r in runs]
        if len(set(seeds)) != len(seeds):
            raise ValueError(f"Duplicate seeds in comparable group: {dataset}, {name}")
        row = {"dataset": dataset, "epochs": epochs, "mode_name": name, "fine_tuned": fine_tuned,
               "execution_mode": json.loads(mode),
               "runs": runs, "completed_seeds": seeds}
        for split in ["validation", "validation_batch1", "test"]:
            samples = [r["result"][split] for r in runs if split in r["result"]]
            if samples:
                row[split] = {"runs": len(samples)}
                for metric in ["accuracy", "macro_f1"]:
                    values = [s[metric] for s in samples]
                    row[split][metric] = {"mean": float(np.mean(values)),
                                         "sample_std": float(np.std(values, ddof=1)) if len(values) > 1 else None}
        output.append(row)
    return {"status": "software_only_no_hardware_measurements", "groups": output}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--runs", default="results/runs")
    p.add_argument("--output", default="results/software_summary.json")
    args = p.parse_args()
    result = summarize(args.runs)
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
