"""Generate current experimental tables without inserting missing evidence."""
import json
from pathlib import Path

from results.summarize import summarize


def main():
    summary = summarize("results/runs")
    Path("results/software_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    text = ["# Current software evidence", "", "Generated from completed run logs. Validation only; no board measurements.", "",
            "| Workload | Experiment | Seeds | Run epochs | Selection validation accuracy percent | Batch 1 validation accuracy percent | Macro F1 | Fine tuned |",
            "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    for group in summary["groups"]:
        scores = group["validation"]
        a, f = scores["accuracy"], scores["macro_f1"]
        accuracy = f"{100 * a['mean']:.3f}"
        if a["sample_std"] is not None:
            accuracy += f" ± {100 * a['sample_std']:.3f}"
        name = group["mode_name"] + (" (one-epoch smoke)" if group["epochs"] == 1 else "")
        batch = group.get("validation_batch1")
        batch_value = "Pending" if batch is None else f"{100 * batch['accuracy']['mean']:.3f} (n={batch['runs']} seeds)"
        text.append(f"| {group['dataset']} | {name} | {','.join(map(str, group['completed_seeds']))} | {group['epochs']} | {accuracy} | {batch_value} | {f['mean']:.5f} | {group['fine_tuned']} |")
    text.extend(["", "## Integer reference candidates", "",
                 "Each row is one exported checkpoint evaluated on validation inputs. Original fake quantization uses dynamic scales; the reference uses fixed calibration scales. Numerical differences are not RTL equivalence.", "",
                 "| Export | Windows | Integer accuracy percent | Batch 1 fake accuracy percent | Changed predictions | Counted saturations |",
                 "| --- | --- | --- | --- | --- | --- |"])
    for path in sorted(Path("results/integer").glob("**/metrics.json")):
        m = json.loads(path.read_text())
        name = str(path.parent.relative_to("results/integer"))
        text.append(f"| {name} | {m['samples']} | {100 * m['integer']['accuracy']:.3f} | {100 * m['fake_quantized_batch1']['accuracy']:.3f} | {m['changed_predictions']} | {sum(m['saturations'].values())} |")
    text.extend(["", "## Outstanding evidence", "",
                 "The subsequent frozen held-out evaluation is documented in [Python test results](python_test_results.md), separately from these validation tables. Hardware bring-up, RTL equivalence, synthesis, routed timing, resource utilization, measured latency/energy, and independent review are outstanding. Do not read software accuracy or schedule estimates as FPGA results.", ""])
    Path("paper/current_results.md").write_text("\n".join(text))


if __name__ == "__main__":
    main()
