"""Document aligned QAT accuracy and independent full-trace equivalence."""
import csv
import json
from collections import defaultdict
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

from model.alignment_study import ROOT
from model.python_study import dump, sha


def csv_file(path, rows):
    with Path(path).open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def stats(values, scale=100.):
    return float(np.mean(values) * scale), float(np.std(values, ddof=1) * scale)


def main():
    plan = json.loads((ROOT / 'training_plan.json').read_text())
    train = {j['name']: json.loads((ROOT / 'runs' / j['name'] / 'metrics.json').read_text()) for j in plan['jobs']}
    evaluations = [json.loads((ROOT / part / j['name'] / 'metrics.json').read_text()) for part in ['validation', 'test'] for j in plan['jobs']]
    grouped, summary, per_seed, per_class = defaultdict(list), [], [], []
    for row in evaluations:
        grouped[(row['dataset'], row['mode'], row['partition'])].append(row)
        per_seed.append({'name': row['name'], 'dataset': row['dataset'], 'mode': row['mode'], 'seed': row['seed'], 'partition': row['partition'],
                         'accuracy_percent': row['integer']['accuracy'] * 100, 'macro_f1': row['integer']['macro_f1'],
                         'selected_epoch': train[row['name']]['selected_epoch'], 'changed_predictions': row['changed_predictions'],
                         'maximum_integer_lsb_error': row['maximum_integer_lsb_error'], 'changed_group_choices': row['changed_group_choices'],
                         'input_clipped_values': row['input_clipped_values'], 'internal_saturation_count': sum(row['saturations'].values())})
        for c in row['integer']['per_class']:
            per_class.append({'name': row['name'], 'partition': row['partition'], **c})
    for (dataset, mode, partition), values in sorted(grouped.items()):
        accuracy, sd = stats([v['integer']['accuracy'] for v in values])
        f1, f1sd = stats([v['integer']['macro_f1'] for v in values], 1.)
        initial = [train[v['name']]['initial_validation']['accuracy'] if partition == 'validation' else
                   json.loads((Path('results/python_study/test') / v['name'] / 'metrics.json').read_text())['integer']['accuracy'] for v in values]
        oldmean, oldsd = stats(initial)
        delta, deltasd = stats([v['integer']['accuracy'] - old for v, old in zip(values, initial)])
        summary.append({'dataset': dataset, 'mode': mode, 'partition': partition, 'seeds': 3,
                        'accuracy_percent': accuracy, 'accuracy_sd_points': sd, 'macro_f1': f1, 'macro_f1_sd': f1sd,
                        'initial_integer_accuracy_percent': oldmean, 'initial_integer_accuracy_sd_points': oldsd,
                        'paired_accuracy_delta_points': delta, 'paired_delta_sd_points': deltasd,
                        'compared_examples': sum(v['samples'] for v in values),
                        'changed_predictions': sum(v['changed_predictions'] for v in values),
                        'changed_group_choices': sum(v['changed_group_choices'] for v in values),
                        'maximum_integer_lsb_error': max(v['maximum_integer_lsb_error'] for v in values)})
    csv_file(ROOT / 'summary.csv', summary)
    csv_file(ROOT / 'per_seed.csv', per_seed)
    csv_file(ROOT / 'per_class.csv', per_class)
    dump(ROOT / 'summary.json', {'plan_sha256': sha(ROOT / 'training_plan.json'), 'test_previously_observed': True, 'rows': summary})
    training_rows = []
    for job in plan['jobs']:
        r = train[job['name']]
        training_rows.append({'name': job['name'], 'epochs_run': job['epochs'], 'selected_epoch': r['selected_epoch'],
                              'initial_validation_accuracy_percent': r['initial_validation']['accuracy'] * 100,
                              'selected_validation_accuracy_percent': r['validation']['accuracy'] * 100,
                              'checkpoint_sha256': r['checkpoint_sha256'], 'export_constants_sha256': r['export_constants_sha256']})
    csv_file(ROOT / 'training.csv', training_rows)
    figure_dir = ROOT / 'figures'
    figure_dir.mkdir(exist_ok=True)
    for partition in ['validation', 'test']:
        fig, axes = plt.subplots(1, 2, figsize=(11, 4.5))
        for ax, dataset in zip(axes, ['har', 'speech']):
            data = [next(v for v in summary if v['dataset'] == dataset and v['mode'] == mode and v['partition'] == partition)
                    for mode in ['quality', 'balanced', 'energy_saver']]
            for offset, field, sd, label, color in [(-.18, 'initial_integer_accuracy_percent', 'initial_integer_accuracy_sd_points', 'Initial integer', '#396c99'),
                                                   (.18, 'accuracy_percent', 'accuracy_sd_points', 'Aligned QAT selected', '#d98236')]:
                ax.bar(np.arange(3) + offset, [v[field] for v in data], yerr=[v[sd] for v in data],
                       width=.34, capsize=3, color=color, label=label)
            ax.set_xticks(range(3), ['Quality', 'Balanced', 'Energy-Saver'])
            ax.set_ylim(0, 100)
            ax.set_ylabel('Accuracy (%)')
            ax.set_title('HAR' if dataset == 'har' else 'Speech Commands v2 · 35 words')
            ax.legend(fontsize=8)
        fig.suptitle(('Validation' if partition == 'validation' else 'Previously observed test sets') + ' · mean ± seed SD · three seeds')
        fig.tight_layout()
        fig.savefig(figure_dir / f'{partition}_accuracy.png', dpi=180)
        fig.savefig(figure_dir / f'{partition}_accuracy.pdf')
        plt.close(fig)

    initial = json.loads((ROOT / 'initial_diagnosis.json').read_text())
    lines = ['# Aligned numerical model and fine tuning results', '',
             'This study implements a trainable PyTorch forward pass with the existing integer deployment contract and verifies it against the separately implemented NumPy integer reference. All checkpoint selection uses validation data. Test results below are subsequent evaluations on the test sets already observed in commit0633422; they are not new untouched-test evidence.', '',
             '## What changed', '',
             'The original dynamic fake-quantized training model remains unchanged. The new `AlignedEncoder` uses fixed training-calibrated input, linear and QKV scales; exported per-channel weight scales and Q24 multipliers; integer bias and gamma quantization; signed24/Q12 residual state; the same rsqrt, exponential and PWL tables; tiled online attention rounding; integer summary/pooling divisions; and identical stable group ranking. No new calibration is fitted during fine-tuning.', '',
             'Forward values use independent CPU PyTorch arithmetic. A custom autograd operation returns the exact forward value and passes gradients through a differentiable surrogate. This avoids cancellation roundoff from the usual x+(q−x).detach() expression. Backward operators use floating RMSNorm, PWL and materialized attention plus identity straight-through quantization and the retained-feature scorer surrogate. These gradients are approximations; no claim of an exact derivative through discrete arithmetic is made.', '',
             'The PyTorch implementation does not call NumPy/golden inference or arithmetic. For speed, bounded integer products use floating GEMM only where integer exactness is provable: INT8 products with reduction at most256 fit all FP32 partial sums within2^22, below2^24; signed24 QK products over at most32 elements fit within2^51, below FP64’s2^53; Q20 probabilities times signed24 values over tiles of at most8 fit within2^46. Range/shape checks and highest FP32 precision are required. Other arithmetic uses INT64 containers. This is an exact numerical emulator, not an integer-only PyTorch runtime or a hardware performance model. The NumPy reference remains integer-only.', '',
             '## Controlling template requirements', '',
             'The Word plan takes priority. Section14.7 requires QAT, a full encoder numerical model, full-test prediction comparison, deterministic vectors and per-layer errors. Section14.8/G2 additionally requires Balanced HAR quality, hardware feasibility and engine/attention verification. This study checks exact integer logits, all recorded intermediate points, selected groups and summaries rather than accepting similar accuracy. It does not freeze the hardware architecture or declare all of G2 passed.', '',
             '## First divergence before training', '',
             'The initial diagnosis uses 32 evenly spaced validation examples per workload/mode/seed, 576 examples across 18 settings. On original inputs, the legacy model first exceeds one Q12 unit of real error at the embedding output on 567 examples and at the first RMSNorm on 9. With the same quantized/dequantized input as the integer model, all 192 Quality examples first exceed the threshold at the first RMSNorm; all 384 adaptive-mode examples first exceed it at embedding. Host quantization therefore does not explain the complete discrepancy. The threshold is diagnostic, not a correctness tolerance or attribution of later prediction changes to one operator.', '',
             f'The aligned implementation has maximum exact intermediate error {max(r["aligned_maximum_integer_trace_error"] for r in initial["rows"])} integer LSBs and {sum(r["aligned_changed_group_choices"] for r in initial["rows"])} changed group choices across the initial diagnosis. Full endpoint and intermediate comparisons after fine-tuning appear below. This agreement follows a new, explicit training-forward contract; it does not retroactively make the original dynamic fake-quantized forward equivalent.', '',
             '## Fine tuning protocol', '',
             'Each mode starts from its own existing mode checkpoint, not downloaded pretrained weights. Seeds17,29,43 are retained. HAR uses three complete training epochs and speech one complete epoch, batch128, CPU, one PyTorch thread per worker, deterministic algorithms, AdamW learning rate3e−5, weight decay0.01, cosine decay, gradient clipping1 and primary classification cross-entropy. No auxiliary-head loss is added. These are limited-budget fine-tuning runs rather than convergence studies. They are not training-budget-matched to the original FP32 control.', '',
             'The original epoch0 checkpoint is eligible for selection. Strictly higher validation accuracy replaces it; ties retain the earlier checkpoint. This prevents forcing a worse checkpoint merely to report new training. Selected epoch0 means fine-tuning ran but the starting model won validation selection. Every epoch’s loss and validation metrics are retained. The epoch0 full-validation predictions are checked against the previously saved integer predictions before optimization starts.', '',
             '| Checkpoint | Epochs run | Selected epoch | Initial validation % | Selected validation % |',
             '| --- | --- | --- | --- | --- |']
    for r in training_rows:
        lines.append(f'| {r["name"]} | {r["epochs_run"]} | {r["selected_epoch"]} | {r["initial_validation_accuracy_percent"]:.3f} | {r["selected_validation_accuracy_percent"]:.3f} |')
    for partition in ['validation', 'test']:
        lines += ['', '## ' + ('Validation accuracy' if partition == 'validation' else 'Accuracy on previously observed test sets'), '',
                  'Mean ± sample SD across three seeds. Paired deltas describe changes from the same mode’s original integer checkpoint; they are not significance tests.', '',
                  '| Workload | Mode | Initial integer accuracy % | Aligned selected accuracy % | Paired change points | Macro F1 |',
                  '| --- | --- | --- | --- | --- | --- |']
        for r in summary:
            if r['partition'] == partition:
                lines.append(f'| {r["dataset"]} | {r["mode"]} | {r["initial_integer_accuracy_percent"]:.3f} ± {r["initial_integer_accuracy_sd_points"]:.3f} | {r["accuracy_percent"]:.3f} ± {r["accuracy_sd_points"]:.3f} | {r["paired_accuracy_delta_points"]:+.3f} ± {r["paired_delta_sd_points"]:.3f} | {r["macro_f1"]:.4f} ± {r["macro_f1_sd"]:.4f} |')
        lines += ['', f'![{partition} accuracy](../results/alignment_study/figures/{partition}_accuracy.png)']
    lines += ['', '## Independent full model equivalence', '',
              '| Partition | Workload | Mode | Compared examples across seeds | Max integer LSB error | Changed predictions | Changed group choices |',
              '| --- | --- | --- | --- | --- | --- | --- |']
    for r in summary:
        lines.append(f'| {r["partition"]} | {r["dataset"]} | {r["mode"]} | {r["compared_examples"]} | {r["maximum_integer_lsb_error"]} | {r["changed_predictions"]} | {r["changed_group_choices"]} |')
    lines += ['', 'These denominators repeat the same partition across training seeds. Every NumPy trace point is compared exactly against the aligned model, including linear INT8 inputs/accumulators, Q/K/V, normalized states, attention, residuals, PWL outputs, scorer sums, selected groups, compacted summaries, pooling and logits. Missing points, shape mismatches, any nonzero error, or changed logits stop the pipeline and save the first divergence. Aligned evaluation uses batches64 against per-example NumPy inference, also testing fixed-scale batch independence. Full validation must pass for all18 settings before the post-training test settings are recorded and subsequent test evaluation starts.', '',
              'Exact agreement validates the software numerical contract and export implementation. It does not prove robustness to sensor noise, good task accuracy, physical feasibility, timing closure, board equivalence or energy savings. Group identity agreement is between implementations on the same input, not stability under input perturbations. New robustness and timing measurements were not performed in this alignment study.', '',
              '## Artifacts and reproduction', '',
              '- `results/alignment_study/training_plan.json`: source, data, template and initial-model hashes plus fixed training/evaluation protocol.',
              '- `initial_diagnosis.json`: legacy first-divergence and aligned intermediate comparisons.',
              '- `runs/<name>/`: initial/selected validation, complete epoch history and selected checkpoint.',
              '- `exports/<name>/`: integer weights/constants under unchanged calibration and format settings.',
              '- `validation/<name>/` and `test/<name>/`: all logits/labels, exact per-point errors, saturation counts and first-example golden vectors.',
              '- `summary.csv`, `per_seed.csv`, `per_class.csv`, `training.csv`: machine-readable results.',
              '- `post_training_test_freeze.json`: selected exports and full-validation evidence fixed before subsequent test evaluation.',
              '- `phases.json`: ordered phase timestamps. No RTL, synthesis or board evidence is implied.', '',
              '```sh', '.venv/bin/python -m results.run_alignment_study', '.venv/bin/python -m results.alignment_report',
              '.venv/bin/python -m results.alignment_audit', '.venv/bin/python -m pytest -q', '```', '',
              'Matching completed runs are reused after provenance checks. An incomplete training directory stops for explicit recovery rather than silently restarting. Original study sources, data, checkpoints, exports and frozen plan remain unchanged. Future experiments must retain the disclosure that test results have already been seen.']
    Path('paper/aligned_numerics_results.md').write_text('\n'.join(lines) + '\n')
    print('Aligned report generated:', len(train), 'trained settings;', len(evaluations), 'complete partition comparisons')


if __name__ == '__main__':
    main()
