"""Strict independent full-trace regression of aligned Torch against NumPy.

Test evaluation is explicitly subsequent to the previously observed test study.
"""
import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
import json
from pathlib import Path

import numpy as np
import torch

from golden.reference import IntegerEncoder
from model.aligned import AlignedEncoder
from model.alignment_study import ROOT, verify
from model.python_study import detailed_metrics, dump, sha


def compare_job(payload):
    job, partition = payload
    torch.set_num_threads(1)
    plan_sha = sha(ROOT / 'training_plan.json')
    out = ROOT / partition / job['name']
    export = ROOT / 'exports' / job['name']
    if (out / 'metrics.json').exists():
        old = json.loads((out / 'metrics.json').read_text())
        if old['plan_sha256'] != plan_sha or old['export_manifest_sha256'] != sha(export / 'manifest.json'):
            raise ValueError('Existing evaluation provenance mismatch')
        return job['name'] + ' reused'
    out.mkdir(parents=True, exist_ok=True)
    aligned = AlignedEncoder(export).eval()
    aligned.trace_enabled = True
    reference = IntegerEncoder(export)
    names = json.loads(Path(f"data/{job['dataset']}/manifest.json").read_text()).get('labels',
            ['WALKING', 'WALKING_UPSTAIRS', 'WALKING_DOWNSTAIRS', 'SITTING', 'STANDING', 'LAYING'])
    with np.load(f"data/{job['dataset']}/{partition}.npz") as data:
        x, y = data['x'], data['y']
    scale = 2. ** (reference.manifest['input_q12_shift'] - 12)
    aligned_logits, integer_logits, changed_groups = [], [], 0
    points, saturations, clipping = {}, Counter(), 0
    with torch.inference_mode():
        for start in range(0, len(y), 64):
            windows = x[start:start + 64]
            outputs = aligned(torch.from_numpy(windows)).numpy() * 4096.
            for index, window in enumerate(windows):
                raw = np.rint(window / scale)
                clipping += int(np.sum((raw < -128) | (raw > 127)))
                quantized = np.clip(raw, -128, 127).astype(np.int8)
                logits = reference.predict(quantized).copy()
                aligned_logits.append(outputs[index].astype(np.int64))
                integer_logits.append(logits)
                saturations.update(reference.saturations)
                for name, value in reference.trace.items():
                    if name not in aligned.trace:
                        raise ValueError('Missing aligned trace point: ' + name)
                    other = aligned.trace[name][index].numpy()
                    if other.shape != value.shape:
                        raise ValueError('Trace shape mismatch: ' + name)
                    error = int(np.abs(other - value).max(initial=0))
                    point = points.setdefault(name, {'maximum_integer_lsb_error': 0, 'compared_examples': 0})
                    point['maximum_integer_lsb_error'] = max(point['maximum_integer_lsb_error'], error)
                    point['compared_examples'] += 1
                    if error:
                        np.savez_compressed(out / 'first_divergence.npz', index=start + index, name=name, aligned=other, integer=value, input_int8=quantized)
                        raise AssertionError(f'{job["name"]} {partition} first divergence {start + index} {name} error{error}')
                if not np.array_equal(outputs[index], logits):
                    raise AssertionError('Logit mismatch despite trace check')
                if 'gate.selected_groups' in reference.trace:
                    changed_groups += int(not np.array_equal(aligned.trace['gate.selected_groups'][index].numpy(), reference.trace['gate.selected_groups']))
                if start + index == 0:
                    np.savez_compressed(out / 'golden_vectors.npz', input_int8=quantized, logits=logits, **reference.trace)
            if (start // 64) % 32 == 0:
                print(job['name'], partition, min(start + 64, len(y)), '/', len(y), flush=True)
    integer_logits, aligned_logits = np.stack(integer_logits), np.stack(aligned_logits)
    np.savez_compressed(out / 'predictions.npz', labels=y, integer_logits_q12=integer_logits, aligned_logits_q12=aligned_logits)
    row = {'name': job['name'], 'dataset': job['dataset'], 'mode': job['mode'], 'seed': job['seed'], 'partition': partition,
           'test_disclosure': 'subsequent evaluation on previously observed test sets' if partition == 'test' else None,
           'samples': len(y), 'plan_sha256': plan_sha, 'export_manifest_sha256': sha(export / 'manifest.json'),
           'predictions_sha256': sha(out / 'predictions.npz'), 'integer': detailed_metrics(y, integer_logits.argmax(-1), names),
           'aligned': detailed_metrics(y, aligned_logits.argmax(-1), names), 'changed_predictions': int(np.sum(integer_logits.argmax(-1) != aligned_logits.argmax(-1))),
           'maximum_integer_lsb_error': int(np.abs(integer_logits - aligned_logits).max()), 'changed_group_choices': changed_groups,
           'trace_points': points, 'input_clipped_values': clipping, 'saturations': dict(saturations),
           'native_kernel': reference.native.metadata if reference.native else None,
           'compared_input_batches': 'aligned batch64 against per-example NumPy integer reference'}
    dump(out / 'metrics.json', row)
    return job['name'] + ' exact ' + partition


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--partition', choices=['validation', 'test'], required=True)
    p.add_argument('--dataset', choices=['har', 'speech', 'all'], default='all')
    p.add_argument('--mode', choices=['quality', 'balanced', 'energy_saver', 'all'], default='all')
    p.add_argument('--workers', type=int, default=3)
    args = p.parse_args()
    plan = json.loads((ROOT / 'training_plan.json').read_text())
    verify(plan)
    if args.partition == 'test':
        for job in plan['jobs']:
            result = json.loads((ROOT / 'validation' / job['name'] / 'metrics.json').read_text())
            if result['maximum_integer_lsb_error'] or result['changed_group_choices'] or result['changed_predictions']:
                raise ValueError('Full validation equivalence required before test evaluation')
        freeze = ROOT / 'post_training_test_freeze.json'
        if not freeze.exists():
            dump(freeze, {'plan_sha256': sha(ROOT / 'training_plan.json'), 'test_previously_observed': True,
                          'export_manifests': {j['name']: sha(ROOT / 'exports' / j['name'] / 'manifest.json') for j in plan['jobs']},
                          'validation_metrics': {j['name']: sha(ROOT / 'validation' / j['name'] / 'metrics.json') for j in plan['jobs']}})
    jobs = [j for j in plan['jobs'] if args.dataset in ['all', j['dataset']] and args.mode in ['all', j['mode']]]
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        for result in pool.map(compare_job, [(j, args.partition) for j in jobs]):
            print(result, flush=True)


if __name__ == '__main__':
    main()
