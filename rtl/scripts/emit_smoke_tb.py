"""Generate structural-only test benches from the proposed port inventory."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEADER = '''-- Generated structural test only. This is not arithmetic/protocol verification.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
'''


def render(modules, guard=False):
    name = 'tb_stub_guard' if guard else 'tb_skeleton_smoke'
    stubs = [m for m in modules if m['status'] == 'stub']
    if not stubs:
        raise ValueError('Replace the skeleton-only benches with functional regression targets')
    selected = [next((m for m in stubs if m['name'] == 'eat_fpga_top'), stubs[0])] if guard else stubs
    monitors = [(m['name'], p['name']) for m in selected for p in m['ports']
                if p['direction'] == 'out' and p['type'] == 'std_logic'
                and (p['name'].endswith(('_valid_o', '_ready_o')) or p['name'] == 'interrupt_o')]
    names = {pair: f'check_{i}' for i, pair in enumerate(monitors)}
    lines = [HEADER, f'entity {name} is end entity;', f'architecture structural_test of {name} is',
             "  signal clk : std_logic := '0';", "  signal rst : std_logic := '1';"]
    lines += [f'  signal {n} : std_logic;' for n in names.values()]
    lines += ['begin', '  clk <= not clk after 5 ns;', "  rst <= '0' after 20 ns;"]
    for m in selected:
        lines += [f"  u_{m['name']} : entity work.{m['name']}(stub)",
                  '    generic map (G_ALLOW_STUB_SIM => ' + ('false' if guard else 'true') + ')', '    port map (']
        bindings = []
        for p in m['ports']:
            if p['direction'] == 'out':
                value = names.get((m['name'], p['name']), 'open')
            elif p['name'] == 'clk_i':
                value = 'clk'
            elif p['name'] == 'rst_i':
                value = 'rst'
            elif p['name'] == 'arst_n_i':
                value = 'not rst'
            elif p['type'] == 'std_logic' and p['name'].endswith('_valid_i'):
                value = "'1'"  # Deliberate requests must still not be accepted by stubs.
            else:
                value = p['idle']
            bindings.append(f"      {p['name']} => {value}")
        lines += [',\n'.join(bindings), '    );']
    lines += ['  process', '  begin', '    wait for 60 ns;']
    if guard:
        lines += ['    assert false report "Default stub guard did not fire" severity failure;']
    else:
        lines += [f'    assert {n} = \'0\' report "Stub accepted/emitted a transaction: {pair[0]}.{pair[1]}" severity failure;'
                  for pair, n in names.items()]
        lines += ['    report "STRUCTURAL_SMOKE_PASS: inert stubs only; no numerical verification" severity note;', '    stop;']
    lines += ['    wait;', '  end process;', 'end architecture;', '']
    return '\n'.join(lines)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--check', action='store_true')
    args = p.parse_args()
    modules = json.loads((ROOT / 'rtl/design_inventory.json').read_text())['modules']
    for guard, file in [(False, 'tb_skeleton_smoke.vhd'), (True, 'tb_stub_guard.vhd')]:
        path = ROOT / 'rtl/tb' / file
        text = render(modules, guard)
        if args.check:
            if not path.exists() or path.read_text() != text:
                raise SystemExit('Structural test bench is stale: ' + file)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)


if __name__ == '__main__':
    main()
