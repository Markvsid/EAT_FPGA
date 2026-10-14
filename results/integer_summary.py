import json
from collections import defaultdict
from pathlib import Path

import numpy as np


def main():
    grouped = defaultdict(list)
    paths = [*Path("results/integer/calibrated").glob("*/metrics.json"), *Path("results/integer/joint").glob("*/metrics.json")]
    for metrics in sorted(paths):
        name = metrics.parent.name
        family = metrics.parent.parent.name
        export = Path("exports") / family / name / "manifest.json"
        m, manifest = json.loads(metrics.read_text()), json.loads(export.read_text())
        run = json.loads((Path(manifest["checkpoint_path"]).parent / "manifest.json").read_text())
        label = run.get("experiment_id", run["mode"])
        if family == "joint":
            mode = next(k for k, v in manifest["config"]["modes"].items() if v == manifest["mode"])
            label = "joint_" + mode
        key = (manifest["config"]["dataset"], label, json.dumps(manifest["spec"], sort_keys=True))
        grouped[key].append({"seed": run["seed"], "metrics": m, "export": str(export)})
    groups = []
    for (dataset, experiment, spec), runs in grouped.items():
        seeds = [r["seed"] for r in runs]
        if len(seeds) != len(set(seeds)):
            raise ValueError("Duplicate seeds in integer comparison")
        values = [r["metrics"]["integer"]["accuracy"] for r in runs]
        groups.append({"dataset": dataset, "experiment": experiment, "spec": json.loads(spec), "seeds": seeds,
                       "accuracy_mean": float(np.mean(values)), "accuracy_sample_std": float(np.std(values, ddof=1)) if len(values) > 1 else None,
                       "changed_predictions": sum(r["metrics"]["changed_predictions"] for r in runs),
                       "compared_windows": sum(r["metrics"]["samples"] for r in runs), "runs": runs})
    Path("results/integer_summary.json").write_text(json.dumps({"status": "validation_only_no_rtl_agreement", "groups": groups}, indent=2) + "\n")


if __name__ == "__main__":
    main()
