"""Concise current evidence, generated from recorded metrics."""
import json
from pathlib import Path

import numpy as np

from results.summarize import summarize


def main():
    summary = summarize("results/runs")
    integer = json.loads(Path("results/integer_summary.json").read_text())
    lines = ["# Software evidence summary", "", "All values below are validation results. Test partitions remain reserved; no FPGA measurements exist.", "",
             "## Training and software validation", "",
             "| Workload | Configuration | Seeds | Batched selection accuracy percent | Batch 1 accuracy percent |",
             "| --- | --- | --- | --- | --- |"]
    for group in summary["groups"]:
        if group["mode_name"] not in ["fp32", "fp32_control", "quality", "balanced", "energy_saver"] or group["epochs"] == 1:
            continue
        a = group["validation"]["accuracy"]
        selection = f"{100*a['mean']:.3f} ± {100*a['sample_std']:.3f}" if a["sample_std"] is not None else f"{100*a['mean']:.3f}"
        b = group.get("validation_batch1")
        batch = "Pending" if not b else f"{100*b['accuracy']['mean']:.3f}"
        lines.append(f"| {group['dataset']} | {group['mode_name']} | {','.join(map(str,group['completed_seeds']))} | {selection} | {batch} |")
    lines.extend(["", "## Fixed-scale integer validation", "",
                  "Integer modes use explicit finite-width arithmetic and offline-calibrated fixed scales. A changed prediction is measured against batch-1 dynamic fake quantization, not RTL.", "",
                  "| Workload | Mode or family | Seeds | Integer accuracy percent | Changed predictions / compared windows |",
                  "| --- | --- | --- | --- | --- |"])
    for group in integer["groups"]:
        value = f"{100*group['accuracy_mean']:.3f}"
        if group["accuracy_sample_std"] is not None:
            value += f" ± {100*group['accuracy_sample_std']:.3f}"
        lines.append(f"| {group['dataset']} | {group['experiment']} | {','.join(map(str,group['seeds']))} | {value} | {group['changed_predictions']} / {group['compared_windows']} |")
    comparisons = json.loads(Path("results/ablation_analysis.json").read_text())["comparisons"]
    lines.extend(["", "## HAR ablations", "", "Positive deltas favor the destination. Seed variation is not a confidence interval or significance test.", "",
                  "| From | To | Paired seeds | Mean accuracy delta in percentage points | Seed SD |",
                  "| --- | --- | --- | --- | --- |"])
    for row in comparisons:
        sd = "Not defined" if row["paired_sample_std"] is None else f"{row['paired_sample_std']:.3f}"
        lines.append(f"| {row['from']} | {row['to']} | {','.join(map(str,row['paired_seeds']))} | {row['paired_mean_delta']:.3f} | {sd} |")
    counter = [json.loads(p.read_text()) for p in Path("results/counterfactual").glob("har_balanced_seed*.json")]
    if counter:
        value = 100 * np.mean([r["accuracy_delta_with_minus_without"] for r in counter])
        lines.extend(["", f"With a fixed RTS-trained checkpoint and identical group decisions, summaries change validation accuracy by {value:.3f} percentage points on average across {len(counter)} seeds while adding two tokens. This counterfactual is separate from independently trained, matched-token-budget comparisons."])
    lines.extend(["", "## Interpretation and remaining gates", "",
                  "The 2024 FPGA simultaneous-pruning design already fuses discarded tokens. A standalone summary-on-FPGA novelty claim is unsupported. Preserve RTS as a measured ablation and position a narrower hardware contribution only after implementation evidence.", "",
                  "Speech Energy-Saver has a larger loss than the original one-percentage-point primary-workload target. Report this limitation; do not claim equal quality across all modes and tasks.", "",
                  "G1/G2 remain incomplete globally: board transfer and power bring-up, review of interfaces/formats, and the final novelty audit are outstanding. RTL, synthesis, routed timing/resources, board equivalence, Arm measurements, energy curves, and independent review are required before submission.", ""])
    Path("paper/software_evidence_summary.md").write_text("\n".join(lines))


if __name__ == "__main__":
    main()
