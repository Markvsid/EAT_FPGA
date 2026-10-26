"""QKV quantization/routing with tile-major input and independent backpressure."""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
import numpy as np
from test_tensor import write
ROOT=Path(__file__).resolve().parents[2];BUILD=ROOT/'rtl/build/qkv'
def main():
 BUILD.mkdir(parents=True,exist_ok=True);ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
 def run(args,name):
  p=subprocess.run([ghdl,*args],cwd=BUILD,text=True,capture_output=True);(BUILD/(name+'.log')).write_text(p.stdout+p.stderr)
  if p.returncode:raise RuntimeError(p.stdout+p.stderr)
  return p.stdout+p.stderr
 sources=(ROOT/'rtl/sources.f').read_text().splitlines(); initial_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources};run(['-a','--std=08',*[str(ROOT/p) for p in sources],str(ROOT/'rtl/tb/tb_qkv_quantizer.vhd')],'analyze')
 reports=[]
 for case in ['har_quality_seed17','har_balanced_seed17','har_energy_saver_seed17','speech_quality_seed17']:
  v=np.load(ROOT/'results/alignment_study/test'/case/'golden_vectors.npz');m=json.loads((ROOT/'results/alignment_study/exports'/case/'manifest.json').read_text());shifts=m['attention_qkv_int8_shifts']['blocks.0'];path=BUILD/case;path.mkdir(parents=True,exist_ok=True)
  write(path/'input.hex',v['blocks.0.qkv']);expected=[]
  for kind,shift in zip(['q','k','v'],shifts):expected.append((v['blocks.0.'+kind]>>shift).transpose(1,0,2).reshape(32,128).ravel())
  write(path/'expected.hex',np.concatenate(expected))
  log=run(['--elab-run','--std=08','tb_qkv_quantizer',f'-gG_Q_SHIFT={shifts[0]}',f'-gG_K_SHIFT={shifts[1]}',f'-gG_V_SHIFT={shifts[2]}',f'-gG_PATH={path}/','--assert-level=error','--max-stack-alloc=0'],case)
  match=re.search(r'QKV_PASS values=(\d+)',log);assert match,log;reports.append({'case':case,'exact_output_values':int(match[1]),'status':'passed'});print(case,'passed',flush=True)
 (BUILD/'qkv_results.json').write_text(json.dumps({'status':'passed','cases':reports,'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'limits':'QKV split/quantization with three independently stalled outputs; no full encoder.'},indent=2)+'\n')
if __name__=='__main__':main()
