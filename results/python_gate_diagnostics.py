"""Post-evaluation validation diagnosis; does not tune or change test models."""
import json
from pathlib import Path

import numpy as np
import torch

from golden.reference import IntegerEncoder
from model.python_study import ROOT, dump, load_job, sha, verify_plan


def main():
    torch.set_num_threads(1)
    plan = json.loads((ROOT / 'evaluation_plan.json').read_text())
    verify_plan(plan)
    rows = []
    for job in plan['jobs']:
        if job['mode_name'] not in ['balanced', 'energy_saver']:
            continue
        model, _ = load_job(job)
        ref = IntegerEncoder(job['export'])
        values = {}
        def capture(_, inputs, output):
            values['scores'] = output.detach().numpy().reshape(8, 4).sum(-1)
        hook = model.gate.scorer.register_forward_hook(capture)
        with np.load(f"data/{job['dataset']}/validation.npz") as data:
            indices = np.linspace(0, len(data['y']) - 1, 256, dtype=int)
            x = data['x'][indices]
        scale = 2. ** (ref.manifest['input_q12_shift'] - 12)
        changed, float_ties, integer_ties, all_equal = 0, 0, 0, 0
        gaps, score_errors, unique, selection = [], [], [], np.zeros(8, dtype=int)
        with torch.inference_mode():
            for window in x:
                model(torch.from_numpy(window[None]), job['mode'])
                ref.predict(np.clip(np.rint(window / scale), -128, 127).astype(np.int8))
                fs, ins = values['scores'], ref.trace['gate.group_sums']
                keep = job['mode']['keep_groups']
                fp = np.argsort(-fs, kind='stable')
                ip = np.argsort(-ins, kind='stable')
                changed += int(not np.array_equal(np.sort(fp[:keep]), np.sort(ip[:keep])))
                float_ties += int(fs[fp[keep - 1]] == fs[fp[keep]])
                integer_ties += int(ins[ip[keep - 1]] == ins[ip[keep]])
                all_equal += int(len(np.unique(ins)) == 1)
                gaps.append(float(fs[fp[keep - 1]] - fs[fp[keep]]))
                score_errors.append(float(np.max(np.abs(ins / 4096. - fs))))
                unique.append(len(np.unique(ins)))
                selection[ip[:keep]] += 1
        hook.remove()
        rows.append({'name': job['name'], 'partition': 'validation', 'indices': indices.tolist(),
                     'changed_group_selections': changed, 'float_cutoff_tie_windows': float_ties,
                     'integer_cutoff_tie_windows': integer_ties, 'integer_all_groups_equal_windows': all_equal,
                     'integer_unique_group_scores_mean': float(np.mean(unique)),
                     'floating_cutoff_gap_median': float(np.median(gaps)),
                     'group_score_max_absolute_error': max(score_errors),
                     'group_score_mean_of_window_max_absolute_error': float(np.mean(score_errors)),
                     'integer_selected_group_counts_chronological': selection.tolist()})
        print(job['name'], 'changed', changed, 'integer cutoff ties', integer_ties, 'all equal', all_equal, flush=True)
    dump(ROOT / 'gate_diagnostics_validation.json', {'evaluation_plan_sha256': sha(ROOT / 'evaluation_plan.json'),
         'status': 'post_test_exploratory_validation_diagnosis_no_tuning', 'source_sha256': sha(__file__),
         'protocol': '256 evenly spaced validation windows per workload; independent adaptive modes, all three seeds; scores are four-token sums',
         'rows': rows})


if __name__ == '__main__':
    main()
