"""Analyze/elaborate every skeleton and check inert behavior + default guards."""
import argparse
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--ghdl')
    args = p.parse_args()
    local = ROOT / '.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl'
    executable = args.ghdl or shutil.which('ghdl') or (str(local) if local.exists() else None)
    if not executable:
        raise SystemExit('GHDL required; see rtl/README.md. No HDL checks were run.')
    build = ROOT / 'rtl/build'
    build.mkdir(parents=True, exist_ok=True)
    for script in ['emit_config.py', 'emit_smoke_tb.py']:
        subprocess.run([sys.executable, str(ROOT / 'rtl/scripts' / script), '--check'], check=True)
    subprocess.run([sys.executable, str(ROOT / 'rtl/scripts/check_scaffold.py')], check=True)
    subprocess.run([sys.executable, str(ROOT / 'rtl/scripts/audit_numerics.py')], check=True)
    sources = (ROOT / 'rtl/sources.f').read_text().splitlines()
    tests = ['rtl/tb/tb_skeleton_smoke.vhd', 'rtl/tb/tb_stub_guard.vhd']
    version = subprocess.check_output([executable, '--version'], text=True)
    def run(arguments, success=True):
        result = subprocess.run([executable, *arguments], cwd=build, text=True, capture_output=True)
        (build / ('last_' + arguments[0].lstrip('-') + '.log')).write_text(result.stdout + result.stderr)
        if success and result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return result
    run(['-a', '--std=08', *[str(ROOT / path) for path in sources + tests]])
    modules = json.loads((ROOT / 'rtl/design_inventory.json').read_text())['modules']
    for module in modules:
        run(['-e', '--std=08', module['name']])
    for name in ['tb_skeleton_smoke', 'tb_stub_guard']:
        run(['-e', '--std=08', name])
    smoke = run(['-r', '--std=08', 'tb_skeleton_smoke', '--assert-level=error'])
    if 'STRUCTURAL_SMOKE_PASS' not in smoke.stdout + smoke.stderr:
        raise RuntimeError('Structural smoke did not finish')
    guard = run(['-r', '--std=08', 'tb_stub_guard', '--assert-level=error'], success=False)
    if guard.returncode == 0 or 'UNIMPLEMENTED_STUB' not in guard.stdout + guard.stderr:
        raise RuntimeError('Unimplemented stub did not fail by default')
    synthesis = subprocess.run([sys.executable, str(ROOT / 'rtl/scripts/check_scaffold.py'),
                                '--require-implemented', 'eat_fpga_top'], text=True, capture_output=True)
    if synthesis.returncode == 0 or 'Synthesis blocked by unimplemented skeletons' not in synthesis.stdout + synthesis.stderr:
        raise RuntimeError('Stub synthesis guard did not reject the design for the expected reason')
    (build / 'synthesis_guard.log').write_text(synthesis.stdout + synthesis.stderr)
    (build / 'smoke.log').write_text(smoke.stdout + smoke.stderr)
    (build / 'expected_guard_failure.log').write_text(guard.stdout + guard.stderr)
    evidence = {'status': 'structural_checks_passed_not_functional_rtl', 'ghdl': version,
                'platform': platform.platform(), 'entities_analyzed_elaborated': len(modules),
                'packages_analyzed': len(json.loads((ROOT / 'rtl/design_inventory.json').read_text())['packages']),
                'inert_stub_smoke': 'passed', 'default_stub_failure': 'passed',
                'numerical_equivalence': 'not_implemented', 'synthesis': 'blocked_while_stubs_exist'}
    (build / 'structural_checks.json').write_text(json.dumps(evidence, indent=2) + '\n')
    print(json.dumps({k: v for k, v in evidence.items() if k != 'ghdl'}))


if __name__ == '__main__':
    main()
