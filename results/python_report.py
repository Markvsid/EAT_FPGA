"""Build readable results, CSV tables and figures from the frozen Python study."""
import csv
import json
from collections import defaultdict
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

from model.python_study import ROOT, dump, sha


def write_csv(path, rows):
    if not rows:
        return
    with Path(path).open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def mean_sd(values, factor=100.):
    return float(np.mean(values) * factor), float(np.std(values, ddof=1) * factor)


def main():
    plan = json.loads((ROOT / 'evaluation_plan.json').read_text())
    rows = [json.loads(p.read_text()) for p in sorted((ROOT / 'test').glob('*/metrics.json'))]
    if len(rows) != len(plan['jobs']):
        raise ValueError(f'Incomplete test evaluation: {len(rows)}/{len(plan["jobs"])}')
    if any(r['evaluation_plan_sha256'] != sha(ROOT / 'evaluation_plan.json') for r in rows):
        raise ValueError('Evaluation plan mismatch')
    figdir = ROOT / 'figures'
    figdir.mkdir(exist_ok=True)
    groups = defaultdict(list)
    per_seed, per_class, disagreement = [], [], []
    for row in rows:
        for implementation in ['pytorch', 'integer', 'same_checkpoint_unquantized']:
            if implementation not in row:
                continue
            m = row[implementation]
            groups[(row['dataset'], row['mode_name'], implementation)].append(row)
            per_seed.append({'dataset': row['dataset'], 'mode': row['mode_name'], 'implementation': implementation,
                             'seed': row['seed'], 'samples': row['samples'], 'accuracy_percent': m['accuracy'] * 100,
                             'macro_f1': m['macro_f1'], 'checkpoint_sha256': row['checkpoint_sha256']})
            for c in m['per_class']:
                per_class.append({'dataset': row['dataset'], 'mode': row['mode_name'], 'implementation': implementation,
                                  'seed': row['seed'], **c})
        if 'integer' in row:
            disagreement.append({'name': row['name'], 'samples': row['samples'],
                                 'changed_vs_fake': row['changed_predictions_vs_fake'],
                                 'changed_vs_same_checkpoint_unquantized': row['changed_predictions_vs_same_checkpoint_unquantized'],
                                 'selected_groups_changed': row['selection_changed_windows'],
                                 'max_logit_error_vs_fake': row['max_logit_error_vs_fake'],
                                 'input_clipped_values': row['input_clipped_values'],
                                 'internal_saturations': sum(row['saturations'].values())})
    summary = []
    for (dataset, mode, implementation), values in sorted(groups.items()):
        accuracy, accuracy_sd = mean_sd([v[implementation]['accuracy'] for v in values])
        f1, f1_sd = mean_sd([v[implementation]['macro_f1'] for v in values], 1.)
        summary.append({'dataset': dataset, 'mode': mode, 'implementation': implementation, 'seeds': len(values),
                        'accuracy_percent': accuracy, 'accuracy_sd_points': accuracy_sd, 'macro_f1': f1, 'macro_f1_sd': f1_sd})
    write_csv(ROOT / 'per_seed.csv', per_seed)
    write_csv(ROOT / 'per_class.csv', per_class)
    write_csv(ROOT / 'summary.csv', summary)
    write_csv(ROOT / 'disagreements.csv', disagreement)
    dump(ROOT / 'summary.json', {'partition': 'test', 'evaluation_plan_sha256': sha(ROOT / 'evaluation_plan.json'), 'rows': summary})

    modes = ['fp32', 'fp32_control', 'quality', 'balanced', 'energy_saver']
    labels = ['Original\nFP32', 'Fine-tuned\nFP32', 'Quality', 'Balanced', 'Energy-Saver']
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
    for axis, dataset in zip(axes, ['har', 'speech']):
        for implementation, offset, color in [('pytorch', -.17, '#396c99'), ('integer', .17, '#d98236')]:
            for index, mode in enumerate(modes):
                match = [s for s in summary if s['dataset'] == dataset and s['mode'] == mode and s['implementation'] == implementation]
                if match:
                    value = match[0]
                    axis.bar(index + offset, value['accuracy_percent'], width=.32, color=color,
                             yerr=value['accuracy_sd_points'], capsize=3, label=implementation if index == (0 if implementation == 'pytorch' else 2) else None)
        axis.set_xticks(range(5), labels, fontsize=9)
        axis.set_title('UCI HAR' if dataset == 'har' else 'Speech Commands v2 · 35 words')
        axis.set_ylabel('Held-out test accuracy (%)')
        axis.set_ylim(0, 100)
        axis.legend()
    fig.suptitle('Batch 1 · mean ± sample SD over three training seeds')
    fig.tight_layout()
    fig.savefig(figdir / 'test_accuracy.png', dpi=180)
    fig.savefig(figdir / 'test_accuracy.pdf')
    plt.close(fig)
    for dataset in ['har', 'speech']:
        for mode in ['fp32_control', 'quality', 'balanced', 'energy_saver']:
            implementation = 'pytorch' if mode == 'fp32_control' else 'integer'
            values = groups[(dataset, mode, implementation)]
            cm = sum(np.array(r[implementation]['confusion_matrix']) for r in values)
            cm = cm / cm.sum(1, keepdims=True)
            names = [v['label'] for v in values[0][implementation]['per_class']]
            fig, ax = plt.subplots(figsize=(7, 6) if dataset == 'har' else (11, 10))
            im = ax.imshow(cm, vmin=0, vmax=1, cmap='Blues')
            ax.set_xticks(range(len(names)), names, rotation=90, fontsize=8)
            ax.set_yticks(range(len(names)), names, fontsize=8)
            ax.set_xlabel('Predicted class')
            ax.set_ylabel('True class')
            ax.set_title(f'{dataset.upper()} · {mode} · {implementation}\nRow-normalized confusion, pooled over three seeds')
            fig.colorbar(im, ax=ax, label='Fraction within true class')
            fig.tight_layout()
            fig.savefig(figdir / f'confusion_{dataset}_{mode}.png', dpi=160)
            plt.close(fig)

    robust = [json.loads(p.read_text()) for p in (ROOT / 'robustness').glob('*seed*.json')]
    if len(robust) != 30:
        raise ValueError(f'Incomplete robustness study: {len(robust)}/30')
    rgroups = defaultdict(list)
    for row in robust:
        for condition, value in row['conditions'].items():
            for impl in ['pytorch', 'integer']:
                if impl in value:
                    rgroups[(row['dataset'], row['mode_name'], condition, impl)].append(value[impl]['accuracy'])
    rsummary = []
    for (dataset, mode, condition, impl), values in sorted(rgroups.items()):
        mean, sd = mean_sd(values)
        clean = np.array(rgroups[(dataset, mode, 'clean', impl)])
        delta, delta_sd = mean_sd(np.array(values) - clean)
        rsummary.append({'dataset': dataset, 'mode': mode, 'condition': condition, 'implementation': impl,
                         'seeds': len(values), 'accuracy_percent': mean, 'accuracy_sd_points': sd,
                         'paired_delta_vs_clean_points': delta, 'paired_delta_sd_points': delta_sd})
    write_csv(ROOT / 'robustness_summary.csv', rsummary)
    for dataset in ['har', 'speech']:
        conditions = ['clean', 'noise_sd0.1', 'noise_sd0.25', 'missing_gyro'] if dataset == 'har' else ['clean', 'snr20', 'snr10', 'gain0.5']
        fig, ax = plt.subplots(figsize=(9, 5))
        for mode, label in zip(modes, labels):
            impl = 'pytorch' if mode in ['fp32', 'fp32_control'] else 'integer'
            values = [next(r for r in rsummary if r['dataset'] == dataset and r['mode'] == mode and r['implementation'] == impl and r['condition'] == condition) for condition in conditions]
            ax.errorbar(range(4), [v['accuracy_percent'] for v in values], yerr=[v['accuracy_sd_points'] for v in values],
                        marker='o', capsize=3, label=label.replace('\n', ' ') + (' integer' if impl == 'integer' else ''))
        ax.set_xticks(range(4), conditions)
        ax.set_ylabel('Subset accuracy (%)')
        ax.set_ylim(0, 100)
        ax.set_title(f'{dataset.upper()} · fixed stratified test subset · mean ± seed SD')
        ax.legend(fontsize=8)
        fig.tight_layout()
        fig.savefig(figdir / f'robustness_{dataset}.png', dpi=180)
        plt.close(fig)

    timing = json.loads((ROOT / 'timing.json').read_text())
    trows = []
    for row in timing['rows']:
        for impl in ['pytorch', 'integer_reference']:
            if impl in row:
                trows.append({'name': row['name'], 'implementation': impl, 'median_ms': row[impl]['median_ms'], 'p95_ms': row[impl]['p95_ms']})
    write_csv(ROOT / 'timing.csv', trows)
    structural = []
    for row in rows:
        if row['seed'] != 17:
            continue
        item = row['executed_structure']
        structural.append({'dataset': row['dataset'], 'mode': row['mode_name'], 'tokens_after_gate': item['tokens_after_gate'],
                           'executed_layers': item['mode']['exit_block'], 'executed_macs': item['executed_macs'],
                           'encoder_matrix_weight_payload_bytes_all4layers': item['payload_bytes_only']['encoder_matrix_weights'],
                           'checkpoint_file_bytes': row['checkpoint_file_bytes'],
                           'integer_constants_compressed_file_bytes': row.get('integer_constants_file_bytes', '')})
    write_csv(ROOT / 'structure.csv', structural)

    text = ['# Python held out evaluation results', '',
            'These are measured classification results from Python on unseen official test partitions. No model parameters, scales, modes, or preprocessing were fitted to test results. Hardware timing, energy and RTL equivalence have not been measured.', '',
            f'The frozen plan contains {len(plan["jobs"])} checkpoint/mode evaluations, including 27 integer comparisons. HAR has 2,947 test windows; Speech Commands has 11,005 test clips. Every configuration has seeds 17, 29 and 43. Values below are mean ± sample SD across seeds, not confidence intervals. Each seed sees the same test examples.', '',
            '## Main classification results', '',
            '| Workload | Configuration | PyTorch accuracy % | Integer accuracy % | Integer macro F1 |',
            '| --- | --- | --- | --- | --- |']
    for dataset in ['har', 'speech']:
        for mode in modes + (['joint_quality', 'joint_balanced', 'joint_energy_saver'] if dataset == 'har' else []):
            p = next(v for v in summary if v['dataset'] == dataset and v['mode'] == mode and v['implementation'] == 'pytorch')
            ints = [v for v in summary if v['dataset'] == dataset and v['mode'] == mode and v['implementation'] == 'integer']
            i = ints[0] if ints else None
            text.append(f'| {dataset} | {mode} | {p["accuracy_percent"]:.3f} ± {p["accuracy_sd_points"]:.3f} | ' +
                        (f'{i["accuracy_percent"]:.3f} ± {i["accuracy_sd_points"]:.3f} | {i["macro_f1"]:.4f} ± {i["macro_f1_sd"]:.4f} |' if i else '— | — |'))
    text += ['', '![Test accuracy](../results/python_study/figures/test_accuracy.png)', '',
             'Original FP32 checkpoints had 30 training epochs. The FP32 control and quantized modes received the same additional fine-tuning budget within each workload: HAR 30 epochs, speech 5 epochs. Shared HAR modes received 30 total joint fine-tuning epochs. Comparisons against the original baseline therefore include additional training. The FP32 control is the closer training-budget comparison. Independent mode checkpoints do not constitute one runtime-switchable weight set; the joint HAR family does.', '',
             '## HAR ablations on held out data', '',
             'These comparisons use batch1 PyTorch inference and independent training runs with paired initialization seeds. Positive changes favor the destination. They do not establish statistical significance or isolate all training effects. The equal-retained-group comparison adds summary tokens; the matched20-token comparison controls total processed token count.', '',
             '| From | To | Mean paired accuracy change points | Sample SD points |',
             '| --- | --- | --- | --- |']
    for source, destination in [('fp32_control', 'quality'), ('quality', 'dense_w4'), ('dense_w4', 'drop_keep6'),
                                ('drop_keep6', 'balanced'), ('drop_keep4', 'rts_keep4'),
                                ('drop_keep5_matched20', 'rts_keep4'), ('rts_keep4', 'energy_saver')]:
        before = {v['seed']: v['pytorch']['accuracy'] for v in groups[('har', source, 'pytorch')]}
        after = {v['seed']: v['pytorch']['accuracy'] for v in groups[('har', destination, 'pytorch')]}
        delta, sd = mean_sd([after[seed] - before[seed] for seed in [17, 29, 43]])
        text.append(f'| {source} | {destination} | {delta:+.3f} | {sd:.3f} |')
    text += ['', '## Class specific errors', '',
             'The table identifies the lowest mean per-class recall and the most frequent off-diagonal confusion after pooling counts across seeds. Pooled confusion describes repeated predictions on the same test set, not additional unique subjects or speakers. Complete precision, recall, F1 and support are in `per_class.csv`.', '',
             '| Workload | Mode | Implementation | Lowest recall class and mean recall % | Most frequent confusion | Count across seeds |',
             '| --- | --- | --- | --- | --- | --- |']
    for dataset in ['har', 'speech']:
        for mode in ['fp32_control', 'quality', 'balanced', 'energy_saver']:
            impl = 'pytorch' if mode == 'fp32_control' else 'integer'
            values = groups[(dataset, mode, impl)]
            classes = values[0][impl]['per_class']
            recall = np.mean([[c['recall'] for c in v[impl]['per_class']] for v in values], axis=0)
            worst = int(recall.argmin())
            cm = sum(np.array(v[impl]['confusion_matrix']) for v in values)
            np.fill_diagonal(cm, 0)
            a, b = np.unravel_index(cm.argmax(), cm.shape)
            text.append(f'| {dataset} | {mode} | {impl} | {classes[worst]["label"]}: {recall[worst] * 100:.2f} | {classes[a]["label"]} → {classes[b]["label"]} | {cm[a, b]} |')
    text += ['',
             '## Numerical agreement on the full test sets', '',
             '| Workload | Mode | Changed vs fake / compared examples | Agreement % | Max absolute logit error | Changed group selections |',
             '| --- | --- | --- | --- | --- | --- |']
    for dataset in ['har', 'speech']:
        for mode in ['quality', 'balanced', 'energy_saver'] + (['joint_quality', 'joint_balanced', 'joint_energy_saver'] if dataset == 'har' else []):
            values = groups[(dataset, mode, 'integer')]
            changed, count = sum(v['changed_predictions_vs_fake'] for v in values), sum(v['samples'] for v in values)
            text.append(f'| {dataset} | {mode} | {changed} / {count} | {100 * (1 - changed / count):.3f} | {max(v["max_logit_error_vs_fake"] for v in values):.5f} | {sum(v["selection_changed_windows"] for v in values)} |')
    text += ['', 'These counts repeat the test set across seeds; the denominator is not a set of independent unique examples. The template’s G2 condition is not declared passed. The template also requires hardware feasibility and unit verification, which are outside this software evaluation.', '',
             'Each integer evaluation stores input clipping and per-operation saturation counts, maximum intermediate error on semantically aligned token rows, the first golden vector and the worst final-logit-error vector. `same_checkpoint_unquantized` is a precision counterfactual with the same fine-tuned weights and token/depth mode; it is not the separately trained FP32 baseline. Both comparisons are retained in CSV/JSON.', '',
             'Group-selection changes are a distinct numerical limitation: independent HAR Balanced/Energy-Saver change retained group identities on about 39–45 percent of comparisons even though final-prediction agreement is about 98.5–98.9 percent. A subsequent exploratory validation-only diagnosis finds few exact cutoff ties and small HAR score margins relative to score perturbations. It changes no frozen inference settings. See [numerical findings](python_numerical_findings.md) for all three seeds, score margins, tie counts and the distinction between execution-path stability and classification agreement.', '',
             '| Workload | Mode | Input values clipped / input values | Internal values saturated |',
             '| --- | --- | --- | --- |']
    for (dataset, mode, impl), values in sorted(groups.items()):
        if impl != 'integer':
            continue
        text.append(f'| {dataset} | {mode} | {sum(v["input_clipped_values"] for v in values)} / {sum(v["input_values"] for v in values)} | {sum(sum(v["saturations"].values()) for v in values)} |')
    text += ['', 'Checked accumulator and intermediate overflow raises an exception; all completed test runs finished without such an exception. Saturation counts above include intentional INT8 operand and signed24 state clamping. The individual operation counts remain in each run’s metrics JSON; they are not all accumulator overflows.', '',
             '## Robustness', '',
             'Robustness uses 120 HAR windows (20/class) and 350 speech clips (10/word), sampled once with RNG seed 20261023 and shared across configurations and training seeds. It is exploratory and is not a replacement for full-test accuracy. Noise and missing-channel conditions were fixed before test evaluation. No recovery training was performed.', '',
             '| Workload | Mode | Implementation | Condition | Accuracy % | Paired change from clean points |',
             '| --- | --- | --- | --- | --- | --- |']
    for v in rsummary:
        if v['condition'] == 'clean' or v['implementation'] != ('pytorch' if v['mode'] in ['fp32', 'fp32_control'] else 'integer'):
            continue
        text.append(f'| {v["dataset"]} | {v["mode"]} | {v["implementation"]} | {v["condition"]} | {v["accuracy_percent"]:.2f} ± {v["accuracy_sd_points"]:.2f} | {v["paired_delta_vs_clean_points"]:+.2f} |')
    text += ['', 'HAR noise is expressed in training-standardized feature units. Missing gyro means replacing all three normalized body-gyro channels with zero, representing their training means. Speech perturbations operate on padded one-second waveforms, before the unchanged log-mel frontend and training normalization. White noise uses SNR20/10 dB before PCM clipping and rounding; clipping counts and clean frontend reproduction error are recorded in the subset manifest. Gain0.5 is a waveform amplitude change. Real-world noise, device shift and missing-data detectors have not been evaluated.', '',
             '![HAR robustness](../results/python_study/figures/robustness_har.png)', '',
             '![Speech robustness](../results/python_study/figures/robustness_speech.png)', '',
             '## Python timing and structural computation', '',
             f'Timing machine: {timing["cpu"]}, {timing["platform"]}; CPU batch1 with one PyTorch thread, 20 warmups and 200 timed calls cycling through the first32 training inputs. Each forward call is synchronous. Loading, preprocessing and input quantization are excluded. Integer execution includes Python checks and trace recording plus the native INT8 dot kernel. Raw per-call times are saved. There is one timing session and CPU frequency/thermal state is uncontrolled. These are software timings, not FPGA or Cortex-A53 baselines or energy measurements.', '',
             '| Workload | Mode | PyTorch median range across seeds ms | PyTorch p95 range ms | Integer median range ms | Integer p95 range ms |',
             '| --- | --- | --- | --- | --- | --- |']
    for dataset in ['har', 'speech']:
        for mode in modes:
            values = [r for r in timing['rows'] if r['dataset'] == dataset and r['mode_name'] == mode]
            def interval(impl, key):
                v = [r[impl][key] for r in values if impl in r]
                return f'{min(v):.3f}–{max(v):.3f}' if v else '—'
            text.append(f'| {dataset} | {mode} | {interval("pytorch", "median_ms")} | {interval("pytorch", "p95_ms")} | {interval("integer_reference", "median_ms")} | {interval("integer_reference", "p95_ms")} |')
    text += ['', 'Token lengths and executed depths are fixed by the mode: Quality32 tokens/4 layers; Balanced32 tokens in block1 then26/4 layers; Energy-Saver32 tokens in block1 then20/2 layers. Token identities depend on input, but token count and depth do not. `structure.csv` gives exact structural MAC counts and an encoder-matrix-only weight payload for all four layers. This excludes biases, scales, positions, other weights, banking and buffers; compressed NPZ and checkpoint sizes are file sizes, not hardware memory footprints. Sorting, nonlinear functions and data movement are excluded from MAC counts.', '',
             '| Workload | Mode | Executed MACs | MAC reduction vs Quality % | Encoder matrix weight payload bytes |',
             '| --- | --- | --- | --- | --- |']
    for dataset in ['har', 'speech']:
        dense = next(v['executed_macs'] for v in structural if v['dataset'] == dataset and v['mode'] == 'quality')
        for mode in ['quality', 'balanced', 'energy_saver']:
            v = next(v for v in structural if v['dataset'] == dataset and v['mode'] == mode)
            text.append(f'| {dataset} | {mode} | {v["executed_macs"]:,} | {100 * (1 - v["executed_macs"] / dense):.2f} | {v["encoder_matrix_weight_payload_bytes_all4layers"]:,} |')
    text += ['', 'Small improvements under weak noise on the HAR subset are descriptive observations on a small fixed sample, not evidence of a statistically established robustness benefit. White-noise speech and missing-gyro HAR results demonstrate limitations of the current models; no noise-aware retraining or missing-channel recovery is claimed.', '',
             '## Artifacts and reproduction', '',
             '- `results/python_study/evaluation_plan.json`: timestamp, template/checkpoint/export/data/source hashes and predetermined protocol.',
             '- `summary.csv`, `per_seed.csv`, `per_class.csv`, `disagreements.csv`, `structure.csv`: machine-readable full-test results.',
             '- `test/<name>/`: metrics, full logits/labels, predictions, numerical traces and checksums.',
             '- `robustness/`: exact subset indices, perturbed features, predictions and PCM clipping metadata.',
             '- `timing.json` and `timing.csv`: raw timing samples, boundaries and environment.',
             '- `figures/`: accuracy, per-class confusion and robustness plots.',
             '- `paper/python_numerical_findings.md`: controlling template requirements and validation discrepancy investigation.', '',
             'From the repository root, using the existing prepared data and saved artifacts:', '',
             '```sh', '.venv/bin/python -m model.python_study run --workers 3', '.venv/bin/python -m results.python_robustness',
             '# Wait until inference workers have finished before timing', '.venv/bin/python -m results.python_timing',
             '.venv/bin/python -m results.python_report', '.venv/bin/python -m results.python_audit', '.venv/bin/python -m pytest -q', '```', '',
             'The runner verifies frozen source, test data, checkpoints and exports, and reuses completed matching results. The initial freeze command is deliberately not repeatable over an existing plan. Future model changes require a new study and disclosure that these test results have already been seen. Hardware, submission readiness and G2 remain outstanding.']
    Path('paper/python_test_results.md').write_text('\n'.join(text) + '\n')
    print('Report generated:', len(rows), 'test evaluations;', len(robust), 'robustness evaluations')


if __name__ == '__main__':
    main()
