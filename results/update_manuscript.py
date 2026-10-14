"""Regenerate the manuscript's software table from raw completed runs."""
import json
from pathlib import Path

from results.summarize import summarize


def main():
    summary = summarize("results/runs")
    Path("results/software_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    baseline = next(g for g in summary["groups"] if g["dataset"] == "UCI HAR raw inertial signals"
                    and g["mode_name"] == "fp32" and g["epochs"] == 30 and g["execution_mode"] is None)
    lines = ["| Seed | Selected epoch | Accuracy percent | Macro F1 |", "| --- | --- | --- | --- |"]
    for run in baseline["runs"]:
        score = run["result"]["validation"]
        lines.append(f"| {run['seed']} | {run['result']['selected_epoch']} | {100 * score['accuracy']:.3f} | {score['macro_f1']:.5f} |")
    a, f = baseline["validation"]["accuracy"], baseline["validation"]["macro_f1"]
    lines.append(f"| Mean and sample standard deviation | | {100 * a['mean']:.3f} ± {100 * a['sample_std']:.3f} | {f['mean']:.5f} ± {f['sample_std']:.5f} |")
    begin, end = "<!-- SOFTWARE_RESULTS_BEGIN -->", "<!-- SOFTWARE_RESULTS_END -->"
    paper = Path("paper/manuscript.md")
    before, remaining = paper.read_text().split(begin, 1)
    _, after = remaining.split(end, 1)
    paper.write_text(before + begin + "\n" + "\n".join(lines) + "\n" + end + after)


if __name__ == "__main__":
    main()
