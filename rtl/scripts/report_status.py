"""Render actual implementation states; never infer completion from file presence."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 d=json.loads((ROOT/'rtl/design_inventory.json').read_text());done=[m for m in d['modules'] if m['status']=='implemented'];missing=[m for m in d['modules'] if m['status']=='stub']
 lines=['# RTL implementation status','',f"{len(done)} of {len(d['modules'])} entities have functional implementations and named regression suites. {len(missing)} remain explicit skeletons.",'','A module implementation is not evidence of complete accelerator integration, physical resource fit or timing. Full encoder and AXI platform simulations are recorded separately from unit regressions. User agreement covers integration contract v2; broader hardware G1/G2 remain open.','','| Entity | Status | Functional regression |','| --- | --- | --- |']
 for m in d['modules']:lines.append(f"| [{m['name']}]({Path(m['path']).relative_to('rtl')}) | {m['status']} | "+', '.join(Path(p).name for p in m.get('functional_tests',[]))+' |')
 lines += ['','Reproduce functional checks with `make -C rtl functional`. Current evidence is archived in `rtl/validation/implementation_v2/`; earlier checkpoints remain in `phase1/` and `integration_v1/`. Run full inference with `python rtl/scripts/test_rtl.py --suite core --suite system`. Full-model RTL simulation is distinct from Vivado implementation and FPGA inference, which remain unverified.','']
 (ROOT/'rtl/IMPLEMENTATION_STATUS.md').write_text('\n'.join(lines))
if __name__=='__main__':main()
