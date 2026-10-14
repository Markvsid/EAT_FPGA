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
    integer_path = Path("results/integer_summary.json")
    if integer_path.exists():
        rows = json.loads(integer_path.read_text())["groups"]
        table = ["| Workload | Mode | Integer validation accuracy percent | Changed predictions versus batch 1 fake quantization |",
                 "| --- | --- | --- | --- |"]
        for row in rows:
            if row["experiment"].startswith("joint_"):
                continue
            value = f"{100*row['accuracy_mean']:.3f}"
            if row["accuracy_sample_std"] is not None:
                value += f" ± {100*row['accuracy_sample_std']:.3f}"
            dataset = "HAR" if row["dataset"].startswith("UCI") else "Speech Commands 35 words"
            table.append(f"| {dataset} | {row['experiment']} | {value} | {row['changed_predictions']} / {row['compared_windows']} |")
        start, finish = "<!-- INTEGER_VALIDATION_BEGIN -->", "<!-- INTEGER_VALIDATION_END -->"
        text = paper.read_text()
        if start in text:
            prefix, rest = text.split(start, 1)
            _, suffix = rest.split(finish, 1)
            paper.write_text(prefix + start + "\n" + "\n".join(table) + "\n" + finish + suffix)


if __name__ == "__main__":
    main()
