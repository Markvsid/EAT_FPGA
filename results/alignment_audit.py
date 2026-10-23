"""Audit checkpoints, fixed numerical settings and all stored aligned results."""
import json
from pathlib import Path

import numpy as np
import torch

from model.alignment_study import ROOT, verify
from model.python_study import detailed_metrics, dump, sha, verify_plan


def main():
    plan = json.loads((ROOT / 'training_plan.json').read_text())
    verify(plan)
    # Establish that the original frozen test study remains reproducible.
    verify_plan(json.loads(Path('results/python_study/evaluation_plan.json').read_text()))
    plan_sha = sha(ROOT / 'training_plan.json')
    freeze = json.loads((ROOT / 'post_training_test_freeze.json').read_text())
    assert freeze['test_previously_observed'] and freeze['plan_sha256'] == plan_sha
    counts, examples = {'validation': 0, 'test': 0}, {'validation': 0, 'test': 0}
    labels = {}
    for dataset in ['har', 'speech']:
        for part in ['validation', 'test']:
            with np.load(f'data/{dataset}/{part}.npz') as data:
                labels[(dataset, part)] = data['y']
    selected_zero = 0
    for job in plan['jobs']:
        folder = ROOT / 'runs' / job['name']
        training = json.loads((folder / 'metrics.json').read_text())
        assert training['plan_sha256'] == plan_sha
        assert training['checkpoint_sha256'] == sha(folder / 'best.pt')
        history = [training['initial_validation']['accuracy']] + [r['validation']['accuracy'] for r in training['history']]
        assert len(history) == job['epochs'] + 1
        assert training['selected_epoch'] == int(np.argmax(history))
        checkpoint = torch.load(folder / 'best.pt', map_location='cpu', weights_only=True)
        assert checkpoint['epoch'] == training['selected_epoch']
        assert checkpoint['validation'] == training['validation']
        assert checkpoint['alignment_plan_sha256'] == plan_sha
        selected_zero += int(training['selected_epoch'] == 0)
        export = ROOT / 'exports' / job['name']
        m = json.loads((export / 'manifest.json').read_text())
        parent = json.loads((Path(job['initial_export']) / 'manifest.json').read_text())
        for field in ['spec', 'layers', 'input_q12_shift', 'attention_scale_multiplier_q20',
                      'attention_qkv_int8_shifts', 'calibration_indices', 'calibration_partition', 'calibration_samples']:
            assert m[field] == parent[field]
        assert m['constants_sha256'] == sha(export / 'constants.npz')
        assert m['checkpoint_sha256'] == training['checkpoint_sha256']
        assert freeze['export_manifests'][job['name']] == sha(export / 'manifest.json')
        with np.load(export / 'constants.npz') as arrays, np.load(Path(job['initial_export']) / 'constants.npz') as old:
            for key in old.files:
                if key.endswith('.multiplier') or key in ['rsqrt_table', 'exp_table', 'silu_knots']:
                    assert np.array_equal(arrays[key], old[key])
            if training['selected_epoch'] == 0:
                assert all(np.array_equal(arrays[key], old[key]) for key in old.files)
        for part in ['validation', 'test']:
            out = ROOT / part / job['name']
            result = json.loads((out / 'metrics.json').read_text())
            assert result['plan_sha256'] == plan_sha
            assert result['export_manifest_sha256'] == sha(export / 'manifest.json')
            assert result['predictions_sha256'] == sha(out / 'predictions.npz')
            assert result['maximum_integer_lsb_error'] == result['changed_predictions'] == result['changed_group_choices'] == 0
            if part == 'validation':
                assert freeze['validation_metrics'][job['name']] == sha(out / 'metrics.json')
            else:
                assert result['test_disclosure'] == 'subsequent evaluation on previously observed test sets'
            with np.load(out / 'predictions.npz') as arrays:
                assert np.array_equal(arrays['labels'], labels[(job['dataset'], part)])
                assert np.array_equal(arrays['integer_logits_q12'], arrays['aligned_logits_q12'])
                names = [c['label'] for c in result['integer']['per_class']]
                recomputed = detailed_metrics(arrays['labels'], arrays['integer_logits_q12'].argmax(-1), names)
                assert recomputed == result['integer'] == result['aligned']
            for point in result['trace_points'].values():
                assert point['maximum_integer_lsb_error'] == 0
                assert point['compared_examples'] == result['samples']
            counts[part] += 1
            examples[part] += result['samples']
    assert counts == {'validation': 18, 'test': 18}
    assert examples == {'validation': 102078, 'test': 125568}
    dump(ROOT / 'audit.json', {'status': 'passed', 'plan_sha256': plan_sha, 'comparisons': counts,
         'compared_examples_across_seeds': examples, 'selected_epoch0_models': selected_zero,
         'checks': ['original frozen study source/data/checkpoint/export hashes unchanged',
                    'new frozen sources/data/initial artifacts unchanged', 'full declared training history and earliest maximum validation selection',
                    'checkpoint/export/prediction checksums', 'unchanged scales, formats, lookup tables and multipliers',
                    'zero exact per-point error, group and prediction differences', 'labels and recomputed class metrics/confusion matrices',
                    'subsequent-test disclosure and post-training export freeze']})
    print('Alignment evidence audit passed', counts, examples, 'epoch0 selections', selected_zero)


if __name__ == '__main__':
    main()
