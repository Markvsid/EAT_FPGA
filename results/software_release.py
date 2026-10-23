"""Frozen shared-family verification, final robustness and software release.

Run `freeze` once, then `run` to reproduce/reuse all results, reports and audit.
Earlier study sources and artifacts are never edited.
"""
import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path

import numpy as np
import torch

from golden.reference import IntegerEncoder
from model.aligned import AlignedEncoder
from model.shared_aligned import MODES, SharedAlignedEncoder
from model.python_study import detailed_metrics, dump, sha

ROOT = Path('results/software_release_v1')


def freeze():
    if (ROOT / 'plan.json').exists():
        raise FileExistsError('Release plan already frozen')
    jobs = []
    for dataset in ['har', 'speech']:
        for seed in [17, 29, 43]:
            for mode in MODES:
                name = f'{dataset}_{mode}_seed{seed}'
                jobs.append({'name': name, 'dataset': dataset, 'seed': seed, 'mode': mode, 'family': 'independent',
                             'export': f'results/alignment_study/exports/{name}',
                             'validation_metrics': f'results/alignment_study/validation/{name}/metrics.json',
                             'test_metrics': f'results/alignment_study/test/{name}/metrics.json'})
    for seed in [17, 29, 43]:
        for mode in MODES:
            jobs.append({'name': f'har_joint_{mode}_seed{seed}', 'dataset': 'har', 'seed': seed, 'mode': mode,
                         'family': 'shared', 'export': f'exports/joint/har_joint_{mode}_seed{seed}'})
    artifacts = {}
    for job in jobs:
        path = Path(job['export'])
        m = json.loads((path / 'manifest.json').read_text())
        job['checkpoint'] = m['checkpoint_path']
        for p in [path / 'manifest.json', path / 'constants.npz', Path(job['checkpoint'])]:
            artifacts[str(p)] = sha(p)
        for key in ['validation_metrics', 'test_metrics']:
            if key in job:
                artifacts[job[key]] = sha(job[key])
    for dataset in ['har', 'speech']:
        for p in [Path(f'data/{dataset}/validation.npz'), Path(f'data/{dataset}/test.npz'), Path(f'data/{dataset}/manifest.json'),
                  Path(f'results/python_study/robustness/{dataset}_inputs.npz'), Path(f'results/python_study/robustness/{dataset}_inputs.json')]:
            artifacts[str(p)] = sha(p)
    for p in Path('results/python_study/robustness').glob('*fp32*seed*.json'):
        artifacts[str(p)] = sha(p)
        artifacts[str(p.with_suffix('.npz'))] = sha(p.with_suffix('.npz'))
    sources = [Path(p) for p in ['model/shared_aligned.py', 'model/aligned.py', 'model/aligned_arithmetic.py',
               'model/network.py', 'model/python_study.py', 'model/train.py', 'golden/reference.py', 'golden/arithmetic.py',
               'native/kernel.py', 'native/dot_i8.c', 'results/software_release.py', 'results/software_release_report.py']]
    plan = {'created_utc': datetime.now(timezone.utc).isoformat(), 'release': 'eat_fpga_lite_software_v1',
            'template_sha256': sha('Report_Template/FPGA_Energy_Efficient_Transformer_Research_Plan_2-Month_Extended.docx'),
            'source_sha256': {str(p): sha(p) for p in sources}, 'artifact_sha256': artifacts,
            'protocol': {'training': 'none; existing validation-selected independent models and existing joint HAR checkpoints',
                         'shared_verification': 'one aliased PyTorch network per seed, three fixed mode-specific calibration exports; full validation before subsequent tests',
                         'robustness': 'reuse byte-identical predefined 120 HAR/350 speech subsets, same clean/noise/missing/gain conditions; all27 settings, both implementations',
                         'acceptance': 'zero error at every NumPy trace point and logits, including perturbed inputs',
                         'test_disclosure': 'test sets and robustness subsets previously observed; no new untouched-test claim or selection',
                         'release_default': 'existing independent aligned models retained for continuity; shared HAR family published as an additional option, no test-driven selection',
                         'storage': 'packed W4/W8 weights, signed64 containers for other constants, exact blob deduplication; buffers/banking excluded'},
            'jobs': jobs}
    dump(ROOT / 'plan.json', plan)
    print('Frozen27 release settings', sha(ROOT / 'plan.json'), flush=True)


def verify(plan):
    for name, checksum in {**plan['source_sha256'], **plan['artifact_sha256']}.items():
        if sha(name) != checksum:
            raise ValueError('Frozen release artifact changed: ' + name)
    if sha('Report_Template/FPGA_Energy_Efficient_Transformer_Research_Plan_2-Month_Extended.docx') != plan['template_sha256']:
        raise ValueError('Controlling template changed')


def load(job):
    if job['family'] == 'shared':
        paths = {m: f"exports/joint/har_joint_{m}_seed{job['seed']}" for m in MODES}
        family = SharedAlignedEncoder(paths).eval()
        branch = family.branch(job['mode'])
        return family, branch, lambda x: family(x, job['mode'])
    branch = AlignedEncoder(job['export']).eval()
    return branch, branch, branch


def labels(dataset):
    return json.loads(Path(f'data/{dataset}/manifest.json').read_text()).get('labels',
           ['WALKING', 'WALKING_UPSTAIRS', 'WALKING_DOWNSTAIRS', 'SITTING', 'STANDING', 'LAYING'])


def compare(x, y, job):
    torch.set_num_threads(1)
    owner, branch, forward = load(job)
    branch.trace_enabled = True
    reference = IntegerEncoder(job['export'])
    scale = 2. ** (reference.manifest['input_q12_shift'] - 12)
    points, saturation = {}, Counter()
    clipping, group_changes = 0, 0
    al, il, first = [], [], None
    with torch.inference_mode():
        for start in range(0, len(y), 64):
            result = forward(torch.from_numpy(x[start:start + 64])).numpy() * 4096.
            for offset, window in enumerate(x[start:start + 64]):
                raw = np.rint(window / scale)
                clipping += int(np.sum((raw < -128) | (raw > 127)))
                inp = np.clip(raw, -128, 127).astype(np.int8)
                integer = reference.predict(inp).copy()
                for name, value in reference.trace.items():
                    other = branch.trace[name][offset].numpy()
                    if other.shape != value.shape or not np.array_equal(other, value):
                        raise AssertionError(f'{job["name"]} first differing trace {name}, example{start + offset}')
                    points[name] = points.get(name, 0) + 1
                if not np.array_equal(result[offset], integer):
                    raise AssertionError('Final logit mismatch')
                if 'gate.selected_groups' in reference.trace:
                    group_changes += int(not np.array_equal(branch.trace['gate.selected_groups'][offset].numpy(), reference.trace['gate.selected_groups']))
                al.append(result[offset].astype(np.int64))
                il.append(integer)
                saturation.update(reference.saturations)
                if first is None:
                    first = {'input_int8': inp, 'logits': integer, **{k: v.copy() for k, v in reference.trace.items()}}
            if start % 2048 == 0 and len(y) > 1000:
                print(job['name'], min(start + 64, len(y)), '/', len(y), flush=True)
    al, il = np.stack(al), np.stack(il)
    return {'integer': detailed_metrics(y, il.argmax(-1), labels(job['dataset'])),
            'aligned': detailed_metrics(y, al.argmax(-1), labels(job['dataset'])),
            'maximum_integer_error': int(np.abs(al - il).max()),
            'changed_predictions': int(np.sum(al.argmax(-1) != il.argmax(-1))), 'changed_group_choices': group_changes,
            'trace_point_examples': points, 'input_clipped_values': clipping, 'saturations': dict(saturation)}, \
           {'labels': y, 'integer_logits_q12': il, 'aligned_logits_q12': al}, first


def evaluate(payload):
    job, partition = payload
    out = ROOT / partition / job['name']
    plan_sha = sha(ROOT / 'plan.json')
    if (out / 'metrics.json').exists():
        saved = json.loads((out / 'metrics.json').read_text())
        if saved['plan_sha256'] != plan_sha or saved['predictions_sha256'] != sha(out / 'predictions.npz'):
            raise ValueError('Existing evaluation provenance mismatch')
        return job['name'] + ' reused ' + partition
    out.mkdir(parents=True, exist_ok=True)
    with np.load(f"data/{job['dataset']}/{partition}.npz") as data:
        result, arrays, first = compare(data['x'], data['y'], job)
    np.savez_compressed(out / 'predictions.npz', **arrays)
    np.savez_compressed(out / 'golden_vectors.npz', **first)
    result.update({'job': job, 'partition': partition, 'plan_sha256': plan_sha,
                   'predictions_sha256': sha(out / 'predictions.npz'), 'test_previously_observed': True})
    dump(out / 'metrics.json', result)
    return job['name'] + ' exact ' + partition


def robustness(job):
    out = ROOT / 'robustness' / job['name']
    plan_sha = sha(ROOT / 'plan.json')
    if (out / 'metrics.json').exists():
        saved = json.loads((out / 'metrics.json').read_text())
        if saved['plan_sha256'] != plan_sha or saved['predictions_sha256'] != sha(out / 'predictions.npz'):
            raise ValueError('Existing robustness provenance mismatch')
        return job['name'] + ' robustness reused'
    out.mkdir(parents=True, exist_ok=True)
    path = Path(f"results/python_study/robustness/{job['dataset']}_inputs.npz")
    conditions, arrays = {}, {}
    with np.load(path) as data:
        y = data['labels']
        arrays.update({'labels': y, 'indices': data['indices']})
        for condition in data.files:
            if condition in ['labels', 'indices']:
                continue
            result, values, first = compare(data[condition], y, job)
            conditions[condition] = result
            for key in ['integer_logits_q12', 'aligned_logits_q12']:
                arrays[condition + '_' + key] = values[key]
    np.savez_compressed(out / 'predictions.npz', **arrays)
    dump(out / 'metrics.json', {'job': job, 'plan_sha256': plan_sha, 'inputs_sha256': sha(path),
                               'predictions_sha256': sha(out / 'predictions.npz'), 'conditions': conditions,
                               'subset_previously_observed': True})
    return job['name'] + ' exact robustness'


def run(workers):
    plan = json.loads((ROOT / 'plan.json').read_text())
    verify(plan)
    from results.alignment_audit import main as previous_audit
    previous_audit()
    shared = [j for j in plan['jobs'] if j['family'] == 'shared']
    for partition in ['validation', 'test']:
        if partition == 'test':
            for job in shared:
                m = json.loads((ROOT / 'validation' / job['name'] / 'metrics.json').read_text())
                assert m['maximum_integer_error'] == m['changed_predictions'] == m['changed_group_choices'] == 0
        with ProcessPoolExecutor(max_workers=workers) as pool:
            for message in pool.map(evaluate, [(j, partition) for j in shared]):
                print(message, flush=True)
    with ProcessPoolExecutor(max_workers=workers) as pool:
        for message in pool.map(robustness, plan['jobs']):
            print(message, flush=True)
    from results.software_release_report import main as report
    report()
    audit()


def audit():
    plan = json.loads((ROOT / 'plan.json').read_text())
    verify(plan)
    count = 0
    for job in plan['jobs']:
        for partition in (['validation', 'test'] if job['family'] == 'shared' else []):
            folder = ROOT / partition / job['name']
            m = json.loads((folder / 'metrics.json').read_text())
            audit_result(m, folder, job, partition)
            count += 1
        folder = ROOT / 'robustness' / job['name']
        m = json.loads((folder / 'metrics.json').read_text())
        assert m['plan_sha256'] == sha(ROOT / 'plan.json')
        path = Path(f"results/python_study/robustness/{job['dataset']}_inputs.npz")
        assert m['inputs_sha256'] == sha(path)
        assert m['predictions_sha256'] == sha(folder / 'predictions.npz')
        with np.load(folder / 'predictions.npz') as arrays, np.load(path) as inputs:
            assert np.array_equal(arrays['labels'], inputs['labels'])
            assert np.array_equal(arrays['indices'], inputs['indices'])
            for condition, value in m['conditions'].items():
                assert value['maximum_integer_error'] == value['changed_predictions'] == value['changed_group_choices'] == 0
                a, b = arrays[condition + '_integer_logits_q12'], arrays[condition + '_aligned_logits_q12']
                assert np.array_equal(a, b)
                assert detailed_metrics(arrays['labels'], a.argmax(-1), labels(job['dataset'])) == value['integer'] == value['aligned']
                assert all(n == len(arrays['labels']) for n in value['trace_point_examples'].values())
    assert count == 18
    dump(ROOT / 'audit.json', {'status': 'passed', 'plan_sha256': sha(ROOT / 'plan.json'),
         'shared_partition_comparisons': count, 'robustness_settings': len(plan['jobs']), 'robustness_conditions': 108,
         'checks': ['frozen source/checkpoint/export/data/subset hashes', 'prior independent alignment audit',
                    'zero intermediate/logit/group differences on full shared partitions and all perturbations',
                    'saved labels, indices, metrics and predictions recomputed']})
    print('Release evidence audit passed', flush=True)


def audit_result(m, folder, job, partition):
    assert m['plan_sha256'] == sha(ROOT / 'plan.json')
    assert m['predictions_sha256'] == sha(folder / 'predictions.npz')
    assert m['maximum_integer_error'] == m['changed_predictions'] == m['changed_group_choices'] == 0
    with np.load(folder / 'predictions.npz') as arrays, np.load(f"data/{job['dataset']}/{partition}.npz") as data:
        assert np.array_equal(arrays['labels'], data['y'])
        assert np.array_equal(arrays['integer_logits_q12'], arrays['aligned_logits_q12'])
        assert detailed_metrics(arrays['labels'], arrays['integer_logits_q12'].argmax(-1), labels(job['dataset'])) == m['integer'] == m['aligned']
        assert all(n == len(data['y']) for n in m['trace_point_examples'].values())


def main():
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['freeze', 'run', 'audit'])
    p.add_argument('--workers', type=int, default=3)
    args = p.parse_args()
    if args.action == 'freeze':
        freeze()
    elif args.action == 'run':
        run(args.workers)
    else:
        audit()


if __name__ == '__main__':
    main()
