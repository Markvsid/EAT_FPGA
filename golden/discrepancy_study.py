"""Validation-only, sequential counterfactuals for export numerical differences.

These are floating-point diagnostic models, not a second bit-accurate model.
No parameter fitting, calibration, or model selection takes place here.
"""
import json
import types
from pathlib import Path

import numpy as np
import torch
from torch.nn import functional as F

from golden.reference import IntegerEncoder
from model.network import Encoder, Linear
from model.train import metrics


def diagnostic_model(reference, stage):
    checkpoint = torch.load(reference.manifest['checkpoint_path'], map_location='cpu', weights_only=True)
    model = Encoder(reference.config).eval()
    model.load_state_dict(checkpoint['model'])
    counts = {}
    if stage in ['fixed_linear', 'fixed_linear_qkv']:
        for name, module in model.named_modules():
            if not isinstance(module, Linear) or name not in reference.manifest['layers']:
                continue
            layer = reference.manifest['layers'][name]
            scale = 2. ** layer['activation_exponent']
            weights = torch.from_numpy(reference.constants[name + '.weight'].astype(np.float32))
            weights = weights * torch.tensor(layer['weight_scale'])[:, None]

            def forward(self, x, bits=None, scale=scale, weights=weights, name=name):
                raw = torch.round(x / scale)
                counts[name] = counts.get(name, 0) + int(((raw < -128) | (raw > 127)).sum())
                return F.linear(raw.clamp(-128, 127) * scale, weights, self.bias)
            module.forward = types.MethodType(forward, module)
    if stage == 'fixed_linear_qkv':
        for name, module in model.named_modules():
            if not name.endswith('.qkv'):
                continue
            shifts = reference.manifest['attention_qkv_int8_shifts'].get(name.removesuffix('.qkv'))
            if shifts is None:
                continue

            def quantize_qkv(_, inputs, output, shifts=shifts, name=name):
                shape = output.shape
                split = output.reshape(*shape[:-1], 3, reference.config['width'])
                scales = output.new_tensor([2. ** (s - 12) for s in shifts]).reshape(1, 1, 3, 1)
                raw = torch.round(split / scales)
                counts[name + '.qkv'] = counts.get(name + '.qkv', 0) + int(((raw < -128) | (raw > 127)).sum())
                return (raw.clamp(-128, 127) * scales).reshape(shape)
            module.register_forward_hook(quantize_qkv)
    return model, counts


def main():
    torch.set_num_threads(1)
    destination = Path('results/python_study/discrepancy_validation.json')
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        raise FileExistsError(destination)
    reports = []
    for dataset in ['har', 'speech']:
        with np.load(f'data/{dataset}/validation.npz') as data:
            indices = np.linspace(0, len(data['y']) - 1, 256, dtype=int)
            x, y = data['x'][indices], data['y'][indices]
        for mode in ['quality', 'balanced', 'energy_saver']:
            name = f'{dataset}_{mode}_seed17'
            reference = IntegerEncoder(Path('exports/calibrated') / name)
            scale = 2. ** (reference.manifest['input_q12_shift'] - 12)
            raw = np.rint(x / scale)
            quantized = np.clip(raw, -128, 127).astype(np.int8)
            stages, logits = {}, {}
            for stage in ['dynamic_original', 'input_only', 'fixed_linear', 'fixed_linear_qkv']:
                model, counts = diagnostic_model(reference, stage)
                values = []
                with torch.inference_mode():
                    for index, window in enumerate(x):
                        inp = window if stage == 'dynamic_original' else quantized[index].astype(np.float32) * scale
                        values.append(model(torch.from_numpy(inp[None]), reference.mode)[0].numpy())
                logits[stage] = np.stack(values)
                stages[stage] = {'metrics': metrics(y, logits[stage].argmax(-1), reference.config['classes']),
                                 'clipped_values': counts}
            values, saturation = [], {}
            for window in quantized:
                values.append(reference.predict(window).copy() / 4096.)
                for key, count in reference.saturations.items():
                    saturation[key] = saturation.get(key, 0) + count
            logits['integer'] = np.stack(values)
            stages['integer'] = {'metrics': metrics(y, logits['integer'].argmax(-1), reference.config['classes']),
                                 'saturations': saturation}
            previous = 'dynamic_original'
            for stage, row in stages.items():
                row['changed_vs_original'] = int(np.sum(logits[stage].argmax(-1) != logits['dynamic_original'].argmax(-1)))
                row['changed_vs_previous'] = int(np.sum(logits[stage].argmax(-1) != logits[previous].argmax(-1)))
                row['max_logit_error_vs_original'] = float(np.max(np.abs(logits[stage] - logits['dynamic_original'])))
                previous = stage
            reports.append({'name': name, 'partition': 'validation', 'indices': indices.tolist(), 'stages': stages,
                            'input_clipped_values': int(np.sum((raw < -128) | (raw > 127)))})
            print(name, {stage: row['changed_vs_original'] for stage, row in stages.items()}, flush=True)
    destination.write_text(json.dumps({'purpose': 'Sequential counterfactual diagnostics, not additive causal attribution or hardware equivalence',
                                      'selection': '256 evenly spaced validation examples; seed17 only; no changes to exports or weights',
                                      'rows': reports}, indent=2) + '\n')


if __name__ == '__main__':
    main()
