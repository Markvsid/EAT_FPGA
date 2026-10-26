"""Replay a golden case, then emit scalar hex files for future VHDL test benches.

This verifies vector provenance/serialization, not any hardware implementation.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from golden.reference import IntegerEncoder


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--vectors', required=True)
    p.add_argument('--export', dest='export_path', required=True)
    p.add_argument('--output', required=True)
    args = p.parse_args()
    source, export_path, out = map(Path, [args.vectors, args.export_path, args.output])
    if out.exists():
        raise FileExistsError('Use a new vector-output directory')
    reference = IntegerEncoder(export_path, use_native=False)
    with np.load(source, allow_pickle=False) as data:
        arrays = {key: data[key] for key in data.files}
    logits = reference.predict(arrays['input_int8'])
    if not np.array_equal(logits, arrays['logits']):
        raise ValueError('Vectors do not match the selected export')
    for key, value in reference.trace.items():
        if key not in arrays or not np.array_equal(value, arrays[key]):
            raise ValueError('Golden trace mismatch: ' + key)
    out.mkdir(parents=True)
    entries = {}
    for key, array in arrays.items():
        if key == 'input_int8' or key.endswith('.input_int8'):
            bits, signed, frac = 8, True, None
        elif key.endswith('.accumulator'):
            bits, signed, frac = 40, True, None
        elif key == 'gate.group_sums':
            bits, signed, frac = 26, True, 12
        elif key == 'gate.selected_groups':
            bits, signed, frac = 3, False, None
        else:
            bits, signed, frac = 24, True, 12
        if not np.issubdtype(array.dtype, np.integer):
            raise ValueError('Integer vectors required: ' + key)
        low = -(1 << (bits - 1)) if signed else 0
        high = (1 << (bits - int(signed))) - 1
        if np.any(array < low) or np.any(array > high):
            raise ValueError('Narrowing would lose data: ' + key)
        name = key.replace('.', '_') + '.hex'
        values = [int(v) for v in array.reshape(-1)]
        lines = [format(v & ((1 << bits) - 1), f'0{(bits + 3) // 4}x') for v in values]
        path = out / name
        path.write_text('\n'.join(lines) + '\n')
        decoded = [int(v, 16) for v in path.read_text().splitlines()]
        if signed:
            decoded = [v - (1 << bits) if v & (1 << (bits - 1)) else v for v in decoded]
        if decoded != values:
            raise ValueError('Hex round trip failed: ' + key)
        entries[key] = {'file': name, 'shape': list(array.shape), 'order': 'C_row_major',
                        'signed': signed, 'bits': bits, 'fraction_bits': frac, 'sha256': digest(path)}
    layout = {'status': 'reference_replay_and_hex_roundtrip_passed_not_rtl_equivalence',
              'vectors_sha256': digest(source), 'export_manifest_sha256': digest(export_path / 'manifest.json'),
              'encoding': 'one integer per line, lowercase zero-padded hex, two_complement at declared width; unused high nibble bits zero',
              'entries': entries}
    (out / 'layout.json').write_text(json.dumps(layout, indent=2) + '\n')
    print('Replayed and exported', len(entries), 'golden boundary arrays to', out)


if __name__ == '__main__':
    main()
