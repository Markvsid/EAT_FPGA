"""Validate the inventory/HDL contract; optionally block stub synthesis."""
import argparse
import json
from pathlib import Path
import re

from emit_config import generate

ROOT = Path(__file__).resolve().parents[2]


def check():
    inventory = json.loads((ROOT / 'rtl/design_inventory.json').read_text())
    modules = {m['name']: m for m in inventory['modules']}
    if len(modules) != len(inventory['modules']):
        raise ValueError('Duplicate module name')
    expected = inventory['packages'] + [m['path'] for m in inventory['modules']]
    if (ROOT / 'rtl/sources.f').read_text().splitlines() != expected:
        raise ValueError('Compile manifest differs from inventory')
    if (ROOT / 'rtl/pkg/eat_config_pkg.vhd').read_text() != generate():
        raise ValueError('Generated constants are stale')
    for m in modules.values():
        text = (ROOT / m['path']).read_text()
        if not re.search(r'entity\s+' + m['name'] + r'\s+is', text, re.I):
            raise ValueError('Entity name mismatch: ' + m['path'])
        body = re.search(r'\bport\s*\((.*?)\);\s*end entity', text, re.S | re.I).group(1)
        ports = []
        for name, direction, typ in re.findall(r'^\s*(\w+)\s*:\s*(in|out)\s+(.+?)\s*;?\s*$', body, re.M):
            ports.append((name, direction, ' '.join(typ.rstrip(';').split())))
        wanted = [(p['name'], p['direction'], ' '.join(p['type'].split())) for p in m['ports']]
        if ports != wanted:
            raise ValueError('Port contract mismatch: ' + m['name'])
        if m['status'] == 'stub' and ('UNIMPLEMENTED_STUB' not in text or 'architecture stub' not in text):
            raise ValueError('Stub guard missing: ' + m['name'])
        if m['status'] not in ['stub', 'implemented']:
            raise ValueError('Unknown implementation status: ' + m['name'])
        if m['status'] == 'implemented' and ('UNIMPLEMENTED_STUB' in text or 'architecture stub' in text):
            raise ValueError('A status change cannot promote an unchanged stub: ' + m['name'])
        if any(d not in modules for d in m['dependencies']):
            raise ValueError('Unknown dependency: ' + m['name'])
    declared = set(expected)
    actual = {str(p.relative_to(ROOT)) for p in (ROOT / 'rtl').rglob('*.vhd') if 'build' not in p.parts and 'tb' not in p.parts}
    if actual != declared:
        raise ValueError('Unlisted/missing VHDL: ' + str(actual ^ declared))
    print(f'Inventory valid: {len(modules)} entities, {len(inventory["packages"])} packages; interfaces proposed')
    return modules


def require_implemented(modules, top):
    seen = set()
    def visit(name):
        if name in seen:
            return
        seen.add(name)
        if name not in modules:
            raise ValueError('Unknown synthesis top: ' + name)
        for child in modules[name]['dependencies']:
            visit(child)
    visit(top)
    missing = sorted(n for n in seen if modules[n]['status'] != 'implemented')
    if missing:
        raise ValueError('Synthesis blocked by unimplemented skeletons: ' + ', '.join(missing))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--require-implemented', metavar='TOP')
    args = p.parse_args()
    modules = check()
    if args.require_implemented:
        try:
            require_implemented(modules, args.require_implemented)
        except ValueError as error:
            raise SystemExit(str(error))


if __name__ == '__main__':
    main()
