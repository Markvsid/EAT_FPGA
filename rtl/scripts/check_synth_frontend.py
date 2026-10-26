"""GHDL synthesis-front-end checks; not Vivado utilization, timing or routing."""
import hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BUILD=ROOT/'rtl/build/synthesis_frontend'
TOPS=['eat_reset_sync','eat_rv_fifo','eat_stream_register','eat_round_shift','eat_round_divide','eat_reduction_tree','eat_leading_one','eat_weight_unpack','eat_activation_quantizer','eat_mac_lane','eat_mac_array','eat_requantizer','eat_score_scale']
def main():
 BUILD.mkdir(parents=True,exist_ok=True);ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
 inv=json.loads((ROOT/'rtl/design_inventory.json').read_text());sources=inv['packages']+[m['path'] for m in inv['modules'] if m['name'] in TOPS]
 p=subprocess.run([ghdl,'-a','--std=08',*[str(ROOT/p) for p in sources]],cwd=BUILD,text=True,capture_output=True)
 (BUILD/'analyze.log').write_text(p.stdout+p.stderr)
 if p.returncode:raise RuntimeError(p.stdout+p.stderr)
 results=[]
 for top in TOPS:
  subprocess.run([__import__('sys').executable,str(ROOT/'rtl/scripts/check_scaffold.py'),'--require-implemented',top],cwd=ROOT,check=True,capture_output=True)
  with (BUILD/(top+'.netlist.vhd')).open('w') as output:
   p=subprocess.run([ghdl,'--synth','--std=08',top],cwd=BUILD,text=True,stdout=output,stderr=subprocess.PIPE,timeout=120)
  (BUILD/(top+'.log')).write_text(p.stderr)
  if p.returncode:raise RuntimeError(top+': '+p.stderr)
  results.append({'top':top,'status':'passed'});print(top,'synthesis frontend passed',flush=True)
 (BUILD/'synthesis_frontend_results.json').write_text(json.dumps({'status':'passed','tops':results,'tool':subprocess.check_output([ghdl,'--version'],text=True),'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'limits':'GHDL netlist generation only. No Vivado target mapping, DSP/BRAM count, routed Fmax or board result.'},indent=2)+'\n')
if __name__=='__main__':main()
