"""Generate scientific plots from recorded results and labeled analytic models."""
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from architecture.profile import profile
from results.summarize import summarize


def save(figure, name, source_files):
    root = Path("paper/figures")
    root.mkdir(parents=True, exist_ok=True)
    figure.tight_layout()
    figure.savefig(root / f"{name}.png", dpi=200)
    figure.savefig(root / f"{name}.pdf")
    plt.close(figure)
    (root / f"{name}.sources.json").write_text(json.dumps({"sources": {str(path): hashlib.sha256(Path(path).read_bytes()).hexdigest()
                                                                     for path in source_files}}, indent=2) + "\n")


def main():
    plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})
    summary = summarize("results/runs")
    Path("results/software_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    c = json.loads(Path("config/har.json").read_text())
    groups = [g for g in summary["groups"] if g["dataset"] == c["dataset"] and g["epochs"] == 30
              and not g["mode_name"].endswith("_mean_over_modes")]
    if groups:
        labels, means, deviations, token_counts = [], [], [], []
        for group in groups:
            mode = group["execution_mode"]
            labels.append(group["mode_name"] + f"\n(n={len(group['completed_seeds'])} seeds)")
            scores = group.get("validation_batch1", group["validation"])
            means.append(100 * scores["accuracy"]["mean"])
            std = scores["accuracy"]["sample_std"]
            deviations.append(0 if std is None else 100 * std)
            token_counts.append(profile(c, mode)["tokens_after_gate"] if mode else 32)
        fig, ax = plt.subplots(figsize=(max(6, len(groups) * .8), 4))
        ax.errorbar(np.arange(len(groups)), means, yerr=deviations, fmt="o", capsize=4, color="#24567a")
        ax.set_xticks(np.arange(len(groups)), labels, rotation=35, ha="right")
        ax.set_ylabel("HAR validation accuracy (%)")
        ax.set_title("Software validation comparisons\nBatch 1 where available; error bars are seed SD")
        ax.grid(axis="y", alpha=.2)
        save(fig, "har_software_accuracy", ["results/software_summary.json", "config/har.json"])
    schedule_path = Path("results/schedule_estimates.json")
    if schedule_path.exists():
        report = json.loads(schedule_path.read_text())
        sweep = report["dense_sequence_sweep"]
        fig, axes = plt.subplots(1, 2, figsize=(8, 3.6))
        n = [row["sequence"] for row in sweep]
        axes[0].plot(n, [row["estimated_cycles"] / 1e6 for row in sweep], "o-", color="#24567a")
        axes[0].set_xlabel("Sequence length")
        axes[0].set_ylabel("Estimated cycles (millions)")
        axes[0].set_title("Uncalibrated schedule")
        for ax in axes:
            ax.grid(alpha=.2)
        # Match the current Q12 score and 40-bit weighted-state candidates.
        # These are payload comparisons; physical banking remains unproved.
        materialized = [c["heads"] * size * size * 3 for size in n]
        online = [c["heads"] * size * (c["width"] // c["heads"] * 5 + 3 + 4) for size in n]
        axes[1].plot(n, np.asarray(materialized) / 1024, "o-", label="24-bit materialized scores")
        axes[1].plot(n, np.asarray(online) / 1024, "s-", label="40-bit weighted online state")
        axes[1].set_xlabel("Sequence length")
        axes[1].set_ylabel("Illustrative payload (KiB)")
        axes[1].set_title("Full query-row payload; allocation excluded")
        axes[1].legend()
        save(fig, "sequence_sensitivity_modeled", [schedule_path, "config/har.json", "config/numerics.json"])
    nonlinear = Path("results/nonlinear_sweep.json")
    if nonlinear.exists():
        report = json.loads(nonlinear.read_text())
        fig, ax = plt.subplots(figsize=(5.2, 3.4))
        for bits in [16, 20, 24]:
            rows = [r for r in report["exp"] if r["output_fraction_bits"] == bits]
            ax.loglog([r["entries"] for r in rows], [r["max_absolute_error"] for r in rows], "o-", label=f"Q{bits} output")
        ax.set_xlabel("Exponential lookup entries")
        ax.set_ylabel("Maximum absolute error on Q12 grid")
        ax.set_title("Offline exponential approximation sweep")
        ax.legend()
        ax.grid(alpha=.2)
        save(fig, "exp_approximation_sweep", [nonlinear])


if __name__ == "__main__":
    main()
