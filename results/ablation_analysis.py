"""Paired-seed comparisons; no significance or board-energy claims inferred."""
import json
from pathlib import Path

import numpy as np

from results.summarize import summarize


def main():
    summary = summarize("results/runs")
    groups = {g["mode_name"]: g for g in summary["groups"] if g["dataset"].startswith("UCI") and g["epochs"] == 30}
    comparisons = [("fp32_control", "quality"), ("quality", "dense_w4"), ("dense_w4", "drop_keep6"),
                   ("drop_keep6", "balanced"), ("drop_keep4", "rts_keep4"),
                   ("drop_keep5_matched20", "rts_keep4"), ("rts_keep4", "energy_saver")]
    results = []
    for left, right in comparisons:
        if left not in groups or right not in groups:
            continue
        a = {r["seed"]: r for r in groups[left]["runs"]}
        b = {r["seed"]: r for r in groups[right]["runs"]}
        seeds = sorted(set(a) & set(b))
        if not seeds:
            continue
        split = "validation_batch1" if all("validation_batch1" in a[s]["result"] and "validation_batch1" in b[s]["result"]
                                            for s in seeds) else "validation"
        delta = [100 * (b[s]["result"][split]["accuracy"] - a[s]["result"][split]["accuracy"]) for s in seeds]
        results.append({"from": left, "to": right, "paired_seeds": seeds, "partition": split,
                        "accuracy_delta_percentage_points": delta, "paired_mean_delta": float(np.mean(delta)),
                        "paired_sample_std": float(np.std(delta, ddof=1)) if len(delta) > 1 else None,
                        "complete_three_seed_comparison": seeds == [17, 29, 43]})
    Path("results/ablation_analysis.json").write_text(json.dumps({"status": "software_only_validation",
                "comparisons": results, "limitations": ["independent fine-tuning can change group decisions",
                "retention-matched comparisons do not have equal token counts with RTS",
                "20-token comparison is the matched-budget control", "no energy savings or statistical significance inferred"]}, indent=2) + "\n")


if __name__ == "__main__":
    main()
