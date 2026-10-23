"""Frozen, resumable held-out evaluation. Run freeze before run.

All inference is batch 1 on CPU. Existing checkpoints/exports are never changed.
"""
import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
import platform
import subprocess
import time
from pathlib import Path

import numpy as np
import torch

from architecture.profile import profile
from golden.reference import IntegerEncoder
from model.network import Block, Encoder, Linear, RMSNorm
from model.train import metrics

ROOT = Path('results/python_study')


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def dump(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix('.tmp.json')
    tmp.write_text(json.dumps(value, indent=2) + '\n')
    tmp.replace(path)


def detailed_metrics(y, pred, names):
    value = metrics(y, pred, len(names))
    cm = np.array(value['confusion_matrix'])
    tp, support, predicted = cm.diagonal(), cm.sum(1), cm.sum(0)
    precision = np.divide(tp, predicted, out=np.zeros(len(names)), where=predicted > 0)
    recall = np.divide(tp, support, out=np.zeros(len(names)), where=support > 0)
    f1 = np.divide(2 * precision * recall, precision + recall, out=np.zeros(len(names)), where=precision + recall > 0)
    value['per_class'] = [{'label': name, 'support': int(support[i]), 'precision': float(precision[i]),
                           'recall': float(recall[i]), 'f1': float(f1[i])} for i, name in enumerate(names)]
    return value


def load_job(job):
    checkpoint = torch.load(job['checkpoint'], map_location='cpu', weights_only=True)
    model = Encoder(checkpoint['config']).eval()
    model.load_state_dict(checkpoint['model'])
    return model, checkpoint


def freeze():
    path = ROOT / 'evaluation_plan.json'
    if path.exists():
        raise FileExistsError('Evaluation plan already frozen; do not overwrite after seeing test results')
    jobs = []
    for dataset in ['har', 'speech']:
        modes = ['fp32', 'fp32_control', 'quality', 'balanced', 'energy_saver']
        if dataset == 'har':
            modes += ['dense_w4', 'drop_keep6', 'drop_keep4', 'drop_keep5_matched20', 'rts_keep4']
        for mode in modes:
            for seed in [17, 29, 43]:
                name = f'{dataset}_{mode}_seed{seed}'
                checkpoint = Path('results/runs') / name / 'best.pt'
                manifest = json.loads((checkpoint.parent / 'manifest.json').read_text())
                export = Path('exports/calibrated') / name
                jobs.append({'name': name, 'dataset': dataset, 'mode_name': mode, 'seed': seed,
                             'checkpoint': str(checkpoint), 'checkpoint_sha256': sha(checkpoint),
                             'mode': manifest.get('execution_mode', manifest['config']['modes'].get(mode)),
                             'export': str(export) if export.exists() else None})
        if dataset == 'har':
            for seed in [17, 29, 43]:
                checkpoint = Path(f'results/runs/har_joint_seed{seed}/best.pt')
                config = torch.load(checkpoint, map_location='cpu', weights_only=True)['config']
                for mode in ['quality', 'balanced', 'energy_saver']:
                    name = f'har_joint_{mode}_seed{seed}'
                    jobs.append({'name': name, 'dataset': dataset, 'mode_name': 'joint_' + mode, 'seed': seed,
                                 'checkpoint': str(checkpoint), 'checkpoint_sha256': sha(checkpoint),
                                 'mode': config['modes'][mode], 'export': f'exports/joint/{name}'})
    for job in jobs:
        if job['export']:
            job['export_manifest_sha256'] = sha(Path(job['export']) / 'manifest.json')
            job['constants_sha256'] = sha(Path(job['export']) / 'constants.npz')
    files = [*Path('model').glob('*.py'), *Path('golden').glob('*.py'), *Path('native').glob('*.py'),
             Path('native/dot_i8.c'), *Path('config').glob('*.json'), Path('architecture/profile.py'),
             Path('results/python_robustness.py'), Path('results/python_timing.py')]
    plan = {'created_utc': datetime.now(timezone.utc).isoformat(), 'scope': 'Software evaluation freeze only; not G2 hardware/numerical approval',
            'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
            'template_sha256': sha('Report_Template/FPGA_Energy_Efficient_Transformer_Research_Plan_2-Month_Extended.docx'),
            'discrepancy_study_sha256': sha(ROOT / 'discrepancy_validation.json'),
            'source_sha256': {str(p): sha(p) for p in files},
            'data_sha256': {str(p): sha(p) for d in ['har', 'speech'] for p in
                            [Path(f'data/{d}/manifest.json'), Path(f'data/{d}/test.npz')]},
            'protocol': {'partition': 'test', 'batch_size': 1, 'device': 'cpu', 'threads_per_worker': 1,
                         'checkpoint_selection': 'existing validation-selected checkpoints, no new training or tuning',
                         'calibration': 'existing training-only 1024-example exports, unchanged',
                         'aggregation': 'mean and sample SD over three seeds, not pooled independent samples',
                         'timing': 'isolated CPU batch1, 20 warmups, 200 timed calls, first32 training windows, excludes loading and preprocessing',
                         'robustness': 'fixed stratified test subset, up to20/class HAR and10/class speech, RNG20261023; all seeds independent core modes',
                         'har_perturbations': ['Gaussian noise SD0.1 normalized units', 'Gaussian noise SD0.25 normalized units', 'zero normalized body_gyro channels3:6'],
                         'speech_perturbations': ['waveform white noise SNR20dB', 'waveform white noise SNR10dB', 'waveform gain0.5'],
                         'agreement_gate': 'report exact disagreement counts; essentially all in template has no numeric threshold; do not declare G2 passed'},
            'jobs': jobs}
    dump(path, plan)
    print('Frozen', len(jobs), 'jobs', sha(path), flush=True)


def verify_plan(plan):
    for path, checksum in {**plan['source_sha256'], **plan['data_sha256']}.items():
        if sha(path) != checksum:
            raise ValueError(f'Frozen artifact changed: {path}')
    for job in plan['jobs']:
        if sha(job['checkpoint']) != job['checkpoint_sha256']:
            raise ValueError('Checkpoint changed: ' + job['name'])
        if job['export']:
            for name, key in [('manifest.json', 'export_manifest_sha256'), ('constants.npz', 'constants_sha256')]:
                if sha(Path(job['export']) / name) != job[key]:
                    raise ValueError('Export changed: ' + job['name'])


def evaluate_job(job):
    torch.set_num_threads(1)
    plan_sha = sha(ROOT / 'evaluation_plan.json')
    out = ROOT / 'test' / job['name']
    if (out / 'metrics.json').exists():
        saved = json.loads((out / 'metrics.json').read_text())
        if saved['evaluation_plan_sha256'] != plan_sha or sha(out / 'predictions.npz') != saved['predictions_sha256']:
            raise ValueError('Existing evaluation provenance mismatch')
        return job['name'] + ' reused'
    model, checkpoint = load_job(job)
    c = checkpoint['config']
    reference = IntegerEncoder(job['export']) if job['export'] else None
    with np.load(f"data/{job['dataset']}/test.npz") as data:
        x, y = data['x'], data['y']
    manifest = json.loads(Path(f"data/{job['dataset']}/manifest.json").read_text())
    names = manifest.get('labels', ['WALKING', 'WALKING_UPSTAIRS', 'WALKING_DOWNSTAIRS', 'SITTING', 'STANDING', 'LAYING'])
    out.mkdir(parents=True, exist_ok=True)
    fake_logits, integer_logits, unquantized_logits = [], [], []
    selection_differences, saturation, clipped_inputs = 0, Counter(), 0
    trace, errors, hooks = {}, {}, []
    if reference:
        for name, module in model.named_modules():
            if isinstance(module, (Linear, RMSNorm, Block)):
                point = name + '.residual2' if isinstance(module, Block) else name
                def capture(_, inputs, output, name=point):
                    trace[name] = output.detach().numpy().squeeze(0)
                hooks.append(module.register_forward_hook(capture))
        scale = 2. ** (reference.manifest['input_q12_shift'] - 12)
    worst_error, worst_index = -1., None
    started = time.perf_counter()
    with torch.inference_mode():
        for i, window in enumerate(x):
            inp = torch.from_numpy(window[None])
            trace.clear()
            floating = model(inp, job['mode'])[0].numpy().copy()
            fake_logits.append(floating)
            if reference:
                raw = np.rint(window / scale)
                clipped_inputs += int(np.count_nonzero((raw < -128) | (raw > 127)))
                quantized = np.clip(raw, -128, 127).astype(np.int8)
                integer = reference.predict(quantized).copy()
                integer_logits.append(integer)
                saturation.update(reference.saturations)
                selection_same = True
                if 'gate.selected_groups' in reference.trace:
                    scores = trace['gate.scorer'].reshape(-1, c['group_size']).sum(-1)
                    selected = np.sort(np.argsort(-scores, kind='stable')[:job['mode']['keep_groups']])
                    selection_same = np.array_equal(selected, reference.trace['gate.selected_groups'])
                    selection_differences += int(not selection_same)
                for name, value in trace.items():
                    if name not in reference.trace or value.shape != reference.trace[name].shape:
                        continue
                    if not selection_same and (name == 'norm' or name.startswith(('blocks.1', 'blocks.2', 'blocks.3'))):
                        continue
                    error = float(np.max(np.abs(reference.trace[name] / 4096. - value)))
                    row = errors.setdefault(name, {'max_absolute_real_error': 0., 'compared_windows': 0})
                    row['max_absolute_real_error'] = max(row['max_absolute_real_error'], error)
                    row['compared_windows'] += 1
                error = float(np.max(np.abs(integer / 4096. - floating)))
                if error > worst_error:
                    worst_error, worst_index = error, i
                    np.savez_compressed(out / 'worst_error_vectors.npz', index=i, input_int8=quantized,
                                        fake_logits=floating, logits=integer, **reference.trace)
                if i == 0:
                    np.savez_compressed(out / 'golden_vectors.npz', input_int8=quantized, logits=integer, **reference.trace)
                fp_mode = dict(job['mode'], weight_bits=None)
                unquantized_logits.append(model(inp, fp_mode)[0].numpy().copy())
            if (i + 1) % 2000 == 0:
                print(job['name'], i + 1, '/', len(y), flush=True)
    arrays = {'labels': y, 'fake_logits': np.stack(fake_logits)}
    result = {'partition': 'test', 'name': job['name'], 'dataset': job['dataset'], 'mode_name': job['mode_name'],
              'seed': job['seed'], 'samples': len(y), 'batch_size': 1, 'device': 'cpu',
              'checkpoint_sha256': job['checkpoint_sha256'], 'evaluation_plan_sha256': plan_sha,
              'selected_epoch': checkpoint['epoch'], 'python': platform.python_version(), 'torch': torch.__version__,
              'numpy': np.__version__, 'machine': platform.machine(),
              'pytorch': detailed_metrics(y, arrays['fake_logits'].argmax(-1), names),
              'executed_structure': profile(c, dict(job['mode'], weight_bits=job['mode']['weight_bits'] or 32) if job['mode'] else
                                            {'weight_bits': 32, 'keep_groups': 8, 'rts': False, 'exit_block': 4}),
              'parameter_count': sum(p.numel() for p in model.parameters()),
              'checkpoint_file_bytes': Path(job['checkpoint']).stat().st_size}
    if reference:
        arrays['integer_logits_q12'] = np.stack(integer_logits)
        arrays['same_checkpoint_unquantized_logits'] = np.stack(unquantized_logits)
        ip = arrays['integer_logits_q12'].argmax(-1)
        fp, up = arrays['fake_logits'].argmax(-1), arrays['same_checkpoint_unquantized_logits'].argmax(-1)
        result.update({'integer': detailed_metrics(y, ip, names), 'changed_predictions_vs_fake': int(np.sum(ip != fp)),
                       'changed_predictions_vs_same_checkpoint_unquantized': int(np.sum(ip != up)),
                       'same_checkpoint_unquantized': detailed_metrics(y, up, names),
                       'max_logit_error_vs_fake': worst_error, 'worst_error_index': worst_index,
                       'mean_logit_max_error_vs_fake': float(np.max(np.abs(arrays['integer_logits_q12'] / 4096. - arrays['fake_logits']), axis=1).mean()),
                       'max_logit_error_vs_same_checkpoint_unquantized': float(np.max(np.abs(arrays['integer_logits_q12'] / 4096. - arrays['same_checkpoint_unquantized_logits']))),
                       'selection_changed_windows': selection_differences, 'input_clipped_values': clipped_inputs,
                       'input_values': int(x.size), 'saturations': dict(saturation), 'trace_errors': errors,
                       'integer_constants_file_bytes': (Path(job['export']) / 'constants.npz').stat().st_size,
                       'native_kernel': reference.native.metadata if reference.native else None})
    np.savez_compressed(out / 'predictions.npz', **arrays)
    result['predictions_sha256'] = sha(out / 'predictions.npz')
    result['evaluation_elapsed_seconds_not_inference_benchmark'] = time.perf_counter() - started
    dump(out / 'metrics.json', result)
    for hook in hooks:
        hook.remove()
    return job['name'] + ' complete'


def main():
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['freeze', 'run'])
    p.add_argument('--workers', type=int, default=3)
    args = p.parse_args()
    if args.action == 'freeze':
        freeze()
    else:
        plan = json.loads((ROOT / 'evaluation_plan.json').read_text())
        verify_plan(plan)
        with ProcessPoolExecutor(max_workers=args.workers) as pool:
            for result in pool.map(evaluate_job, plan['jobs']):
                print(result, flush=True)


if __name__ == '__main__':
    main()
