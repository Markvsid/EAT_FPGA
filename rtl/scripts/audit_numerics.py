"""Check proposed HDL boundary widths against every frozen software export.

Observed ranges do not prove physical feasibility or all nonlinear arithmetic.
The linear bound is conservative for every possible signed-INT8 input vector.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', default=str(ROOT / 'rtl/build/numeric_width_audit.json'))
    args = p.parse_args()
    catalog_path = ROOT / 'results/software_release_v1/catalog.json'
    catalog = json.loads(catalog_path.read_text())
    cfg = json.loads((ROOT / 'rtl/config/rtl_candidate.json').read_text())
    numeric = json.loads((ROOT / 'config/numerics.json').read_text())
    ranges, rows = {}, []
    def record(name, array, bits, positive=False):
        low, high = int(np.min(array)), int(np.max(array))
        if low < (0 if positive else -(1 << (bits - 1))) or high > (1 << (bits - 1)) - 1:
            raise ValueError(name + ' does not fit the proposed signed width')
        old = ranges.setdefault(name, {'minimum': low, 'maximum': high, 'proposed_signed_bits': bits})
        old['minimum'], old['maximum'] = min(low, old['minimum']), max(high, old['maximum'])
    for job in catalog['models']:
        path = ROOT / job['export']
        m = json.loads((path / 'manifest.json').read_text())
        c = m['config']
        for key in ['state_signed_bits', 'state_fraction_bits', 'linear_accumulator_signed_bits',
                    'weight_multiplier_fraction_bits', 'norm_gamma_fraction_bits', 'norm_epsilon_q24',
                    'exp_fraction_bits', 'exp_input_fraction_bits', 'attention_tile', 'rmsnorm_implementation']:
            if m['spec'][key] != numeric[key]:
                raise ValueError('Unsupported arithmetic variant: ' + job['name'] + ' ' + key)
        if (c['width'], c['heads'], c['layers'], c['group_size']) != (128, 4, 4, 4):
            raise ValueError('Unsupported architecture')
        if c['window_samples'] // c['patch_samples'] > cfg['maximum_tokens']:
            raise ValueError('Unsupported token count')
        if not 0 <= m['input_q12_shift'] <= 50:
            raise ValueError('Unsupported host input shift')
        for shifts in m['attention_qkv_int8_shifts'].values():
            if any(not 0 <= shift <= 16 for shift in shifts):
                raise ValueError('QKV restoration is not guaranteed to fit signed24')
        with np.load(path / 'constants.npz', allow_pickle=False) as arrays:
            if hashlib.sha256((path / 'constants.npz').read_bytes()).hexdigest() != m['constants_sha256']:
                raise ValueError('Constant checksum mismatch')
            for name, layer in m['layers'].items():
                w = arrays[name + '.weight'].astype(np.int64)
                b, mult = arrays[name + '.bias'], arrays[name + '.multiplier']
                if w.shape[1] > cfg['maximum_reduction'] or w.shape[0] > cfg['maximum_matrix_columns']:
                    raise ValueError('Unsupported matrix dimensions')
                record('weight', w, layer['weight_bits'])
                record('bias', b, numeric['linear_accumulator_signed_bits'])
                record('multiplier', mult, cfg['multiplier_signed_bits_candidate'], positive=True)
                if np.any(mult <= 0):
                    raise ValueError('Multiplier must be positive')
                # Covers all legal A8 values, not just observed calibration data.
                bound = int(np.max(128 * np.abs(w).sum(1) + np.abs(b)))
                product_bound = bound * int(np.max(np.abs(mult)))
                if bound > (1 << 39) - 1 or product_bound > (1 << 62) - 1:
                    raise ValueError('Export exceeds the reference accumulator/product bound')
                rows.append({'model': job['name'], 'linear': name, 'max_abs_accumulator_bound_all_int8_inputs': bound,
                             'conservative_product_bound': product_bound})
            for name in arrays.files:
                if name.endswith('.gamma'):
                    record('gamma', arrays[name], cfg['gamma_signed_bits'])
            record('position', arrays['position'], numeric['state_signed_bits'])
            if arrays['exp_table'].shape != (4097,) or arrays['exp_table'].min() < 0 or arrays['exp_table'].max() > (1 << 20):
                raise ValueError('Unsupported exp table')
            if arrays['rsqrt_table'].shape != (1024,) or arrays['rsqrt_table'].max() > (1 << 30):
                raise ValueError('Unsupported rsqrt table')
    result = {'status': 'export_boundary_width_checks_passed_not_rtl_equivalence', 'models': len(catalog['models']),
              'catalog_sha256': hashlib.sha256(catalog_path.read_bytes()).hexdigest(), 'observed_ranges': ranges,
              'linear_bounds': rows, 'physical_fit_proven': False, 'all_nonlinear_internal_widths_proven': False}
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2) + '\n')
    print('Numeric boundary audit passed for', len(catalog['models']), 'exports')


if __name__ == '__main__':
    main()
