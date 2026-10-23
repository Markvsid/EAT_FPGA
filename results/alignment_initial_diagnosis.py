"""Validation-only first-divergence report before aligned fine-tuning."""
from collections import Counter
import json
from pathlib import Path

import numpy as np
import torch

from golden.reference import IntegerEncoder
from model.aligned import AlignedEncoder
from model.alignment_study import ROOT, verify
from model.network import Encoder, Linear, RMSNorm, Block
from model.python_study import dump, sha


def main():
    torch.set_num_threads(1)
    plan = json.loads((ROOT / 'training_plan.json').read_text())
    verify(plan)
    rows = []
    for job in plan['jobs']:
        aligned = AlignedEncoder(job['initial_export']).eval()
        aligned.trace_enabled = True
        ref = IntegerEncoder(job['initial_export'])
        legacy = Encoder(aligned.config).eval()
        legacy.load_state_dict(aligned.network.state_dict())
        trace, hooks = {}, []
        for name, module in legacy.named_modules():
            if isinstance(module, (Linear, RMSNorm, Block)):
                point = name + '.residual2' if isinstance(module, Block) else name
                def capture(_, inputs, output, name=point):
                    trace[name] = output.detach().numpy().squeeze(0)
                hooks.append(module.register_forward_hook(capture))
        with np.load(f"data/{job['dataset']}/validation.npz") as data:
            indices = np.linspace(0, len(data['y']) - 1, 32, dtype=int)
            x = data['x'][indices]
        first, first_same_input, point_errors = Counter(), Counter(), {}
        legacy_changed, aligned_max, group_changes, input_clips = 0, 0, 0, 0
        scale = 2. ** (ref.manifest['input_q12_shift'] - 12)
        with torch.inference_mode():
            for window in x:
                raw = np.rint(window / scale)
                input_clips += int(np.sum((raw < -128) | (raw > 127)))
                q = np.clip(raw, -128, 127).astype(np.int8)
                integer = ref.predict(q)
                result = aligned(torch.from_numpy(window[None]))[0].numpy() * 4096.
                for name, value in ref.trace.items():
                    other = aligned.trace[name][0].numpy()
                    error = int(np.abs(other - value).max(initial=0))
                    aligned_max = max(aligned_max, error)
                    if error:
                        raise AssertionError('Initial aligned divergence: ' + job['name'] + ' ' + name)
                if 'gate.selected_groups' in ref.trace:
                    group_changes += int(not np.array_equal(aligned.trace['gate.selected_groups'][0].numpy(), ref.trace['gate.selected_groups']))
                for input_kind, inp, counts in [('original', window, first), ('same_quantized_input', q.astype(np.float32) * scale, first_same_input)]:
                    trace.clear()
                    logits = legacy(torch.from_numpy(inp[None]), aligned.mode)[0].numpy()
                    selected_same = True
                    if 'gate.selected_groups' in ref.trace:
                        score = trace['gate.scorer'].reshape(8, 4).sum(-1)
                        selected_same = np.array_equal(np.sort(np.argsort(-score, kind='stable')[:aligned.mode['keep_groups']]), ref.trace['gate.selected_groups'])
                    found = False
                    for name, value in ref.trace.items():
                        if name not in trace or value.shape != trace[name].shape:
                            continue
                        if not selected_same and (name == 'norm' or name.startswith(('blocks.1', 'blocks.2', 'blocks.3'))):
                            continue
                        error = float(np.abs(value / 4096. - trace[name]).max())
                        if input_kind == 'original':
                            point_errors[name] = max(point_errors.get(name, 0.), error)
                        if error > 1 / 4096. and not found:
                            counts[name] += 1
                            found = True
                    if input_kind == 'original':
                        legacy_changed += int(logits.argmax() != integer.argmax())
        rows.append({'name': job['name'], 'indices': indices.tolist(), 'partition': 'validation',
                     'legacy_first_common_trace_error_over_one_q12_lsb': dict(first),
                     'legacy_first_error_same_quantized_input': dict(first_same_input),
                     'legacy_maximum_real_error_by_point': point_errors,
                     'legacy_changed_predictions': legacy_changed,
                     'aligned_maximum_integer_trace_error': aligned_max,
                     'aligned_changed_group_choices': group_changes, 'input_clipped_values': input_clips})
        for hook in hooks:
            hook.remove()
        print(job['name'], 'first legacy divergence', dict(first), 'aligned max error', aligned_max, flush=True)
    dump(ROOT / 'initial_diagnosis.json', {'plan_sha256': sha(ROOT / 'training_plan.json'),
         'source_sha256': sha(__file__), 'selection': '32 evenly spaced validation examples per workload, all18 settings',
         'legacy_threshold': 'one Q12 LSB real error at first common, semantically aligned trace point; diagnostic only',
         'aligned_requirement': 'zero exact integer error at every NumPy reference trace point', 'rows': rows})


if __name__ == '__main__':
    main()
