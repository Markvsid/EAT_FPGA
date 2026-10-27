"""GHDL synthesis-front-end checks; not Vivado utilization, timing or routing."""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRIMITIVES = ['eat_reset_sync', 'eat_rv_fifo', 'eat_stream_register', 'eat_round_shift',
              'eat_round_divide', 'eat_reduction_tree', 'eat_leading_one', 'eat_weight_unpack',
              'eat_activation_quantizer', 'eat_mac_lane', 'eat_mac_array', 'eat_requantizer', 'eat_score_scale']
INTEGRATION = ['eat_model_memory', 'eat_tensor_engine', 'eat_vector_engine',
               'eat_streaming_attention_engine', 'eat_token_compactor', 'eat_encoder_core',
               'eat_fpga_top', 'eat_platform_wrapper']


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--integration', action='store_true', help='Check connected hierarchy; discard large netlists')
    parser.add_argument('--top', action='append', help='Override selected top entities')
    args = parser.parse_args()
    tops = args.top or (INTEGRATION if args.integration else PRIMITIVES)
    build = ROOT / 'rtl/build' / ('integration_synthesis' if args.integration else 'synthesis_frontend')
    build.mkdir(parents=True, exist_ok=True)
    ghdl = shutil.which('ghdl') or str(ROOT / '.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
    inv = json.loads((ROOT / 'rtl/design_inventory.json').read_text())
    modules = {m['name']: m for m in inv['modules']}
    used = set()

    def visit(name):
        if name in used:
            return
        used.add(name)
        for child in modules[name]['dependencies']:
            visit(child)

    for top in tops:
        visit(top)
    sources = inv['packages'] + [m['path'] for m in inv['modules'] if m['name'] in used]
    hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources}
    result = subprocess.run([ghdl, '-a', '--std=08', *[str(ROOT / p) for p in sources]],
                            cwd=build, text=True, capture_output=True, check=False)
    (build / 'analyze.log').write_text(result.stdout + result.stderr)
    result.check_returncode()
    results = []
    for top in tops:
        subprocess.run([sys.executable, str(ROOT / 'rtl/scripts/check_scaffold.py'),
                        '--require-implemented', top], cwd=ROOT, check=True, capture_output=True)
        netlist = Path('/dev/null') if args.integration else build / (top + '.netlist.vhd')
        with netlist.open('w') as output:
            result = subprocess.run([ghdl, '--synth', '--std=08', top], cwd=build, text=True,
                                    stdout=output, stderr=subprocess.PIPE, timeout=240)
        (build / (top + '.log')).write_text(result.stderr)
        results.append({'top': top, 'status': 'passed' if result.returncode == 0 else 'failed',
                        'netlist_retained': not args.integration})
        if result.returncode:
            raise RuntimeError(top + ': ' + result.stderr)
        print(top, 'synthesis frontend passed', flush=True)
    assert hashes == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources}, 'RTL changed during synthesis checks'
    (build / 'synthesis_frontend_results.json').write_text(json.dumps({
        'status': 'passed', 'tops': results,
        'tool': subprocess.check_output([ghdl, '--version'], text=True), 'source_sha256': hashes,
        'limits': 'GHDL netlist generation only. No Vivado target mapping, DSP/BRAM count, routed Fmax or board result.'
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
