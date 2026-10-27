"""Run exact functional RTL suites; no synthesis or board result is implied."""
import argparse
import json
import subprocess
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FAST_SUITES=['primitives','services','arbiter','tensor','vectors','attention','gate','qkv','images','loader','model_memory','registers','streams']
SUITES=FAST_SUITES+['core','system']
def main():
 p=argparse.ArgumentParser();p.add_argument('--suite',choices=SUITES,action='append');args=p.parse_args()
 for suite in args.suite or FAST_SUITES:
  print('Running functional RTL suite:',suite,flush=True)
  subprocess.run([sys.executable,str(ROOT/'rtl/scripts'/('test_'+suite+'.py'))],cwd=ROOT,check=True)
 print(json.dumps({'status':'selected_functional_suites_passed','suites':args.suite or FAST_SUITES,'scope':'Only the selected suites are claimed; use --suite core and --suite system for full inference.'}))
if __name__=='__main__':main()
