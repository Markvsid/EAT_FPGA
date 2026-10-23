"""Software release tables, storage accounting and scientific figures."""
from collections import defaultdict
import csv
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import torch

from architecture.profile import profile
from golden.pack import pack_signed_nibbles
from model.python_study import dump, sha
from model.shared_aligned import MODES

ROOT = Path('results/software_release_v1')


def write_csv(path, rows):
    with Path(path).open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator='\n')
        w.writeheader()
        w.writerows(rows)


def stats(values):
    return float(np.mean(values) * 100), float(np.std(values, ddof=1) * 100)


def storage(jobs):
    result = []
    for family in ['independent', 'shared']:
        for seed in [17, 29, 43]:
            group = [j for j in jobs if j['family'] == family and j['dataset'] == 'har' and j['seed'] == seed]
            checkpoints, blobs, total = {}, {}, 0
            for job in group:
                path = Path(job['export'])
                manifest = json.loads((path / 'manifest.json').read_text())
                checkpoint = Path(job['checkpoint'])
                if sha(checkpoint) not in checkpoints:
                    state = torch.load(checkpoint, map_location='cpu', weights_only=True)['model']
                    checkpoints[sha(checkpoint)] = {'file_bytes': checkpoint.stat().st_size,
                                                  'parameter_bytes': sum(v.numel() * v.element_size() for v in state.values())}
                with np.load(path / 'constants.npz') as arrays:
                    for name in arrays.files:
                        values = arrays[name]
                        if name.endswith('.weight'):
                            bits = manifest['layers'][name.removesuffix('.weight')]['weight_bits']
                            blob = pack_signed_nibbles(values) if bits == 4 else values.astype(np.int8).tobytes()
                            encoding = 'int4' if bits == 4 else 'int8'
                        else:
                            blob, encoding = values.astype('<i8').tobytes(), 'int64_container'
                        total += len(blob)
                        blobs[(encoding, hashlib.sha256(blob).hexdigest())] = len(blob)
            result.append({'family': family, 'seed': seed, 'unique_checkpoints': len(checkpoints),
                           'unique_fp32_parameter_bytes': sum(v['parameter_bytes'] for v in checkpoints.values()),
                           'checkpoint_file_bytes': sum(v['file_bytes'] for v in checkpoints.values()),
                           'all_constant_container_bytes': total, 'deduplicated_constant_container_bytes': sum(blobs.values()),
                           'hardware_banking_proven': False})
    return result


def main():
    plan = json.loads((ROOT / 'plan.json').read_text())
    grouped, per_seed, class_rows = defaultdict(list), [], []
    for job in plan['jobs']:
        for partition in ['validation', 'test']:
            path = ROOT / partition / job['name'] / 'metrics.json' if job['family'] == 'shared' else Path(job[partition + '_metrics'])
            m = json.loads(path.read_text())
            grouped[(job['dataset'], job['family'], job['mode'], partition)].append(m['integer'])
            per_seed.append({'dataset': job['dataset'], 'family': job['family'], 'mode': job['mode'], 'seed': job['seed'],
                             'partition': partition, 'accuracy_percent': m['integer']['accuracy'] * 100,
                             'macro_f1': m['integer']['macro_f1'], 'metrics_path': str(path)})
            for c in m['integer']['per_class']:
                class_rows.append({'name': job['name'], 'family': job['family'], 'partition': partition, **c})
    summary = []
    for (dataset, family, mode, partition), values in sorted(grouped.items()):
        a, sd = stats([v['accuracy'] for v in values])
        f, fsd = stats([v['macro_f1'] for v in values])
        summary.append({'dataset': dataset, 'family': family, 'mode': mode, 'partition': partition,
                        'accuracy_percent': a, 'accuracy_sd_points': sd, 'macro_f1': f / 100, 'macro_f1_sd': fsd / 100})
    write_csv(ROOT / 'accuracy.csv', summary)
    write_csv(ROOT / 'per_seed.csv', per_seed)
    write_csv(ROOT / 'per_class.csv', class_rows)
    banks = storage(plan['jobs'])
    write_csv(ROOT / 'storage.csv', banks)
    robust = defaultdict(list)
    for job in plan['jobs']:
        m = json.loads((ROOT / 'robustness' / job['name'] / 'metrics.json').read_text())
        for condition, value in m['conditions'].items():
            robust[(job['dataset'], job['family'], job['mode'], condition)].append((job['seed'], value['integer']))
    # Reuse the verified FP32 controls on exactly the same frozen inputs.
    for path in Path('results/python_study/robustness').glob('*fp32*seed*.json'):
        m = json.loads(path.read_text())
        for condition, value in m['conditions'].items():
            robust[(m['dataset'], 'baseline', m['mode_name'], condition)].append((m['seed'], value['pytorch']))
    rsummary = []
    for (dataset, family, mode, condition), values in sorted(robust.items()):
        a, sd = stats([v['accuracy'] for _, v in values])
        clean = dict(robust[(dataset, family, mode, 'clean')])
        delta, dsd = stats([v['accuracy'] - clean[s]['accuracy'] for s, v in values])
        rsummary.append({'dataset': dataset, 'family': family, 'mode': mode, 'condition': condition,
                         'accuracy_percent': a, 'accuracy_sd_points': sd, 'paired_delta_vs_clean_points': delta,
                         'paired_delta_sd_points': dsd})
    write_csv(ROOT / 'robustness_summary.csv', rsummary)
    shapes = []
    catalog = []
    for job in plan['jobs']:
        manifest = json.loads((Path(job['export']) / 'manifest.json').read_text())
        p = profile(manifest['config'], manifest['mode'])
        if job['seed'] == 17:
            shapes.append({'dataset': job['dataset'], 'family': job['family'], 'mode': job['mode'],
                           'tokens_after_gate': p['tokens_after_gate'], 'layers': manifest['mode']['exit_block'],
                           'weight_bits': manifest['mode']['weight_bits'], 'executed_macs': p['executed_macs']})
        catalog.append({**job, 'checkpoint_sha256': sha(job['checkpoint']),
                        'export_manifest_sha256': sha(Path(job['export']) / 'manifest.json'),
                        'constants_sha256': sha(Path(job['export']) / 'constants.npz'),
                        'loader': 'SharedAlignedEncoder' if job['family'] == 'shared' else 'AlignedEncoder'})
    write_csv(ROOT / 'structure.csv', shapes)
    dump(ROOT / 'catalog.json', {'release': plan['release'], 'plan_sha256': sha(ROOT / 'plan.json'),
         'status': 'frozen_software_release_not_hardware_g2_approval', 'default_family': 'independent',
         'shared_family': 'additional_HAR_option_not_selected_on_new_test_results',
         'test_previously_observed': True, 'models': catalog})
    dump(ROOT / 'summary.json', {'accuracy': summary, 'robustness': rsummary, 'storage': banks})
    figures(summary, rsummary, banks)
    document(plan, summary, rsummary, banks)
    print('Release report and catalog generated', flush=True)


def figures(summary, robust, banks):
    folder = ROOT / 'figures'
    folder.mkdir(exist_ok=True)
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
    for family, offset, color in [('independent', -.18, '#396c99'), ('shared', .18, '#d98236')]:
        values = [next(r for r in summary if r['dataset'] == 'har' and r['family'] == family and r['mode'] == mode and r['partition'] == 'test') for mode in MODES]
        axes[0].bar(np.arange(3) + offset, [r['accuracy_percent'] for r in values], yerr=[r['accuracy_sd_points'] for r in values], width=.34, capsize=3, label=family, color=color)
    axes[0].set_xticks(range(3), ['Quality', 'Balanced', 'Energy-Saver'])
    axes[0].set_ylabel('HAR accuracy (%)')
    axes[0].set_ylim(0, 100)
    axes[0].set_title('Previously observed test set · three seeds')
    axes[0].legend()
    for i, family in enumerate(['independent', 'shared']):
        data = [r for r in banks if r['family'] == family]
        axes[1].bar(i, np.mean([r['deduplicated_constant_container_bytes'] for r in data]) / 1024, color=['#396c99', '#d98236'][i])
    axes[1].set_xticks(range(2), ['Independent', 'Shared'])
    axes[1].set_ylabel('Deduplicated constant containers (KiB)')
    axes[1].set_title('All three mode images · no banking/buffers')
    fig.tight_layout()
    fig.savefig(folder / 'shared_accuracy_storage.png', dpi=180)
    fig.savefig(folder / 'shared_accuracy_storage.pdf')
    plt.close(fig)
    for dataset in ['har', 'speech']:
        conditions = ['clean', 'noise_sd0.1', 'noise_sd0.25', 'missing_gyro'] if dataset == 'har' else ['clean', 'snr20', 'snr10', 'gain0.5']
        fig, ax = plt.subplots(figsize=(10, 5.5))
        groups = [('baseline', 'fp32_control')] + [('independent', m) for m in MODES]
        if dataset == 'har':
            groups += [('shared', m) for m in MODES]
        for family, mode in groups:
            data = [next(r for r in robust if r['dataset'] == dataset and r['family'] == family and r['mode'] == mode and r['condition'] == c) for c in conditions]
            ax.errorbar(range(4), [v['accuracy_percent'] for v in data], yerr=[v['accuracy_sd_points'] for v in data], marker='o', capsize=2,
                        linestyle='--' if family == 'shared' else '-', label=family + ' ' + mode.replace('_', ' '))
        ax.set_xticks(range(4), conditions)
        ax.set_ylim(0, 100)
        ax.set_ylabel('Fixed subset accuracy (%)')
        ax.set_title(dataset.upper() + ' · mean ± seed SD · previously observed robustness subset')
        ax.legend(fontsize=8)
        fig.tight_layout()
        fig.savefig(folder / f'robustness_{dataset}.png', dpi=180)
        fig.savefig(folder / f'robustness_{dataset}.pdf')
        plt.close(fig)


def document(plan, summary, robust, banks):
    lines = ['# Frozen software release with shared HAR modes and robustness', '',
             'This release verifies the existing shared-weight HAR family under aligned arithmetic, repeats the predefined robustness study on all final aligned models, and publishes an immutable model catalog. No new training, recalibration, mode selection or hyperparameter search is performed. Test sets and robustness subsets were previously observed; these are subsequent software comparisons, not new untouched-test evidence.', '',
             '## Scope and controlling instructions', '',
             'The controlling Word plan remains authoritative. Its full-model numerical comparisons, three-seed quality reporting and finite mode requirements motivate this release. A software release freeze does not approve G2 hardware feasibility, interfaces or board equivalence. The independent aligned models remain the default for continuity; the shared HAR family is an additional published option, not a winner selected on these new test comparisons.', '',
             'There are27 aligned settings:18 independent (two workloads × three modes × three seeds) and9 shared HAR settings (one checkpoint per seed, three modes). `SharedAlignedEncoder` aliases the same actual PyTorch network object across its mode branches. Pointer identity, parameter deduplication, deterministic mode switching and rejection of unrelated checkpoints are unit-tested. Calibration and quantized constant images are still mode-specific. `shared_state_dict()` serializes the common parameters once; the general PyTorch state dictionary contains alias paths and should not be used to infer physical sharing.', '',
             '## Accuracy and exact numerical comparisons', '',
             'Mean ± sample SD across seeds17,29,43. Independent results reuse the audited final alignment study; shared results run every validation/test input through the shared adapter and separate NumPy reference. Every reference trace point, integer logit, retained-group identity and summary is checked with zero tolerance. Full shared validation must pass before the subsequent shared test comparisons.', '',
             '| Workload | Family | Mode | Validation accuracy % | Subsequent test accuracy % | Test macro F1 |',
             '| --- | --- | --- | --- | --- | --- |']
    for dataset in ['har', 'speech']:
        for family in (['independent', 'shared'] if dataset == 'har' else ['independent']):
            for mode in MODES:
                v = next(r for r in summary if r['dataset'] == dataset and r['family'] == family and r['mode'] == mode and r['partition'] == 'validation')
                t = next(r for r in summary if r['dataset'] == dataset and r['family'] == family and r['mode'] == mode and r['partition'] == 'test')
                lines.append(f'| {dataset} | {family} | {mode} | {v["accuracy_percent"]:.3f} ± {v["accuracy_sd_points"]:.3f} | {t["accuracy_percent"]:.3f} ± {t["accuracy_sd_points"]:.3f} | {t["macro_f1"]:.4f} ± {t["macro_f1_sd"]:.4f} |')
    lines += ['', 'The shared family is the previously trained joint HAR checkpoint: no additional epochs are added. This experiment aligns the forward contract and verifies the existing weights; it does not claim new accuracy gains from retraining. The independent models retain their earlier validation-selected checkpoints. The catalog publishes all three seeds rather than selecting a favorable test seed.', '',
              '## Storage tradeoff', '',
              '| HAR family | Seed | Unique checkpoints | FP32 parameter bytes | All constant containers bytes | Deduplicated constant containers bytes |',
              '| --- | --- | --- | --- | --- | --- |']
    for r in banks:
        lines.append(f'| {r["family"]} | {r["seed"]} | {r["unique_checkpoints"]} | {r["unique_fp32_parameter_bytes"]:,} | {r["all_constant_container_bytes"]:,} | {r["deduplicated_constant_container_bytes"]:,} |')
    lines += ['', 'FP32 parameter bytes describe the shadow checkpoint tensors, not FPGA memory. Constant containers use packed signed W4/W8 weights and signed64 containers for remaining constants, matching the earlier payload convention. Deduplication requires byte-identical blobs with identical encoding. Sharing one FP32 checkpoint does not eliminate distinct W8/W4 images, scales, biases or tables. Compressed checkpoint file sizes are recorded separately in `storage.csv`. Metadata, activations, buffer duplication, ports, physical banking and routing overhead are excluded; no physical fit or energy result follows from this accounting.', '',
              '![Shared accuracy and storage](../results/software_release_v1/figures/shared_accuracy_storage.png)', '',
              '## Final model robustness', '',
              'All27 settings are evaluated on the exact saved, previously observed subsets:120 HAR windows (20/class) and350 speech clips (10/word). The same inputs are used for all seeds and families. HAR conditions are clean, Gaussian noise SD0.1/0.25 in training-standardized units, and all three normalized gyro channels set to zero. Speech conditions are clean, waveform white noise at20/10dB SNR, and waveform amplitude gain0.5 before the unchanged log-mel frontend and train-only normalization. The original PCM-clipping and frontend-reconstruction metadata is retained unchanged. The FP32 control results are reused from their audited predictions on these identical subsets.', '',
              'Both aligned and NumPy implementations are run on every perturbed input, checking all intermediate points and exact logits. Input clipping and runtime saturation counts are retained per condition. This checks agreement under perturbations; it does not make predictions invariant to noise. No noise-aware fine-tuning or recovery policy is introduced.', '',
              '| Workload | Family | Mode | Condition | Accuracy % | Paired change from clean points |',
              '| --- | --- | --- | --- | --- | --- |']
    for r in robust:
        if r['condition'] == 'clean' or (r['family'] == 'baseline' and r['mode'] != 'fp32_control'):
            continue
        lines.append(f'| {r["dataset"]} | {r["family"]} | {r["mode"]} | {r["condition"]} | {r["accuracy_percent"]:.2f} ± {r["accuracy_sd_points"]:.2f} | {r["paired_delta_vs_clean_points"]:+.2f} |')
    lines += ['', '![HAR robustness](../results/software_release_v1/figures/robustness_har.png)', '',
              '![Speech robustness](../results/software_release_v1/figures/robustness_speech.png)', '',
              'These are small, class-balanced exploratory subsets, not full-test accuracy or independent draws across seeds. Mean ± seed SD is not a confidence interval or significance test. Per-class metrics, exact subset indices, logits, clipping counts and full trace comparison counts are retained. Real device shift and environmental noise are not established by these synthetic perturbations.', '',
              '## Release contents and reproduction', '',
              '`catalog.json` fixes all27 model settings, loaders, paths and checkpoint/export checksums. `plan.json` records the controlling template, sources, data, existing selected artifacts and robustness input hashes before evaluation. `accuracy.csv`, `per_seed.csv`, `per_class.csv`, `robustness_summary.csv`, `structure.csv` and `storage.csv` are machine-readable tables. Shared full-partition results and all robustness predictions live beside these tables. `audit.json` verifies the evidence. Earlier studies are preserved.', '',
              'After installing the pinned dependencies, preparing byte-identical data and building the native kernel, one command verifies/reuses the numerical results and regenerates the final release tables, plots, catalog and audit:', '',
              '```sh', '.venv/bin/python -m results.software_release run', '```', '',
              'The existing plan is intentionally immutable. Completed artifacts are reused only with matching provenance. Different prepared-data hashes, changed inference sources or altered checkpoints require a separately disclosed study rather than overwriting this release. CPU inference uses `AlignedEncoder` for independent exports or `SharedAlignedEncoder` with all three joint exports for a seed; the integer reference remains a separate implementation. The legacy dynamic encoder is not interchangeable with the aligned loaders.', '',
              '## Remaining paper requirements', '',
              'This is a software release. Runtime MAC structure is unchanged and recorded in `structure.csv`; no new hardware speed, energy, Cortex-A53 baseline, synthesis, timing closure or board-equivalence result is claimed. Physical banking, hardware G2, RTL, board measurements, fair prior-hardware comparison and independent manuscript review remain outstanding.']
    Path('paper/software_release_results.md').write_text('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
