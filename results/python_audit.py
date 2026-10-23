"""Recompute metrics from stored predictions and check the frozen evidence."""
import json
from pathlib import Path

import numpy as np

from model.python_study import ROOT, detailed_metrics, dump, sha, verify_plan


def main():
    plan = json.loads((ROOT / 'evaluation_plan.json').read_text())
    verify_plan(plan)
    count, comparisons = 0, 0
    labels = {}
    for dataset in ['har', 'speech']:
        with np.load(f'data/{dataset}/test.npz') as data:
            labels[dataset] = data['y']
    for job in plan['jobs']:
        out = ROOT / 'test' / job['name']
        metric = json.loads((out / 'metrics.json').read_text())
        assert metric['evaluation_plan_sha256'] == sha(ROOT / 'evaluation_plan.json')
        assert sha(out / 'predictions.npz') == metric['predictions_sha256']
        with np.load(out / 'predictions.npz') as data:
            assert np.array_equal(data['labels'], labels[job['dataset']])
            for key, array in [('pytorch', 'fake_logits'), ('integer', 'integer_logits_q12'),
                               ('same_checkpoint_unquantized', 'same_checkpoint_unquantized_logits')]:
                if key not in metric:
                    continue
                names = [r['label'] for r in metric[key]['per_class']]
                assert detailed_metrics(data['labels'], data[array].argmax(-1), names) == metric[key]
            if 'integer' in metric:
                changed = int(np.sum(data['integer_logits_q12'].argmax(-1) != data['fake_logits'].argmax(-1)))
                assert changed == metric['changed_predictions_vs_fake']
                comparisons += 1
        count += 1
    robustness = 0
    for path in (ROOT / 'robustness').glob('*seed*.json'):
        metric = json.loads(path.read_text())
        assert metric['evaluation_plan_sha256'] == sha(ROOT / 'evaluation_plan.json')
        assert metric['predictions_sha256'] == sha(path.with_suffix('.npz'))
        inputs = ROOT / 'robustness' / f"{metric['dataset']}_inputs.npz"
        assert metric['inputs_sha256'] == sha(inputs)
        with np.load(path.with_suffix('.npz')) as data:
            assert np.array_equal(data['labels'], labels[metric['dataset']][data['indices']])
            for condition, value in metric['conditions'].items():
                for key in ['pytorch', 'integer']:
                    if key in value:
                        names = [c['label'] for c in value[key]['per_class']]
                        assert detailed_metrics(data['labels'], data[condition + '_' + key], names) == value[key]
        robustness += 1
    timing = json.loads((ROOT / 'timing.json').read_text())
    assert timing['evaluation_plan_sha256'] == sha(ROOT / 'evaluation_plan.json')
    assert len(timing['rows']) == len(plan['jobs'])
    for row in timing['rows']:
        for key in ['pytorch', 'integer_reference']:
            if key in row:
                assert len(row[key]['samples_ms']) == 200
                assert all(np.isfinite(v) and v > 0 for v in row[key]['samples_ms'])
    assert count == 54 and comparisons == 27 and robustness == 30
    dump(ROOT / 'audit.json', {'status': 'passed', 'evaluation_plan_sha256': sha(ROOT / 'evaluation_plan.json'),
         'test_evaluations': count, 'integer_comparisons': comparisons, 'robustness_evaluations': robustness,
         'checks': ['frozen source/data/checkpoint/export SHA256', 'prediction SHA256', 'test labels and sample counts',
                    'accuracy/F1/per-class/confusion recomputation', 'integer prediction changes',
                    'robustness indices/labels/metrics/hashes', 'timing sample count and finite positive durations']})
    print('Evidence audit passed:', count, 'test evaluations,', comparisons, 'integer comparisons,', robustness, 'robustness evaluations')


if __name__ == '__main__':
    main()
