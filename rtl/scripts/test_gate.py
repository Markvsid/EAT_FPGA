"""Connected scorer/selector/RTS compactor against frozen and corner-case tensors."""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
import numpy as np
from test_tensor import write
ROOT=Path(__file__).resolve().parents[2];BUILD=ROOT/'rtl/build/gate'
def main():
 BUILD.mkdir(parents=True,exist_ok=True);ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
 def run(args,name):
  p=subprocess.run([ghdl,*args],cwd=BUILD,text=True,capture_output=True);(BUILD/(name+'.log')).write_text(p.stdout+p.stderr)
  if p.returncode:raise RuntimeError(p.stdout+p.stderr)
  return p.stdout+p.stderr
 sources=(ROOT/'rtl/sources.f').read_text().splitlines(); initial_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources};run(['-a','--std=08',*[str(ROOT/p) for p in sources],str(ROOT/'rtl/tb/tb_token_gate.vhd')],'analyze');run(['-e','--std=08','tb_token_gate'],'elaborate')
 cases=[]
 for case in ['har_balanced_seed17','har_energy_saver_seed17','speech_balanced_seed17','speech_energy_saver_seed17']:
  v=np.load(ROOT/'results/alignment_study/test'/case/'golden_vectors.npz');m=json.loads((ROOT/'results/alignment_study/exports'/case/'manifest.json').read_text())
  mask=sum(1<<int(i) for i in v['gate.selected_groups']);cases.append((case,v['blocks.0.residual2'],v['gate.scorer'].reshape(32),m['mode']['keep_groups'],True,v['gate.compacted'],mask))
 from golden.arithmetic import round_divide
 rng=np.random.default_rng(4253)
 for keep,rts,extreme in [(6,True,False),(4,True,True),(8,False,False),(6,False,False)]:
  x=rng.integers(-2**23,2**23,(32,128),dtype=np.int64);scores=np.full(32,-2**23 if extreme else 0,dtype=np.int64)
  mask=(1<<keep)-1;result=[]
  for g in range(8):
   group=x[g*4:g*4+4]
   if g<keep:result.extend(group)
   elif rts:
    importance=np.abs(scores[g*4:g*4+4])+4096;result.append(round_divide((group*importance[:,None]).sum(0),importance.sum()))
  cases.append((f'synthetic_keep{keep}_rts{int(rts)}',x,scores,keep,rts,np.asarray(result),mask))
 reports=[]
 for name,x,scores,keep,rts,expected,mask in cases:
  path=BUILD/name;path.mkdir(parents=True,exist_ok=True)
  for filename,a in [('input',x),('scores',scores),('expected',expected)]:write(path/(filename+'.hex'),a)
  args=[f'-gG_KEEP={keep}',f"-gG_RTS={'1' if rts else '0'}",f'-gG_OUTPUT_TOKENS={len(expected)}',f'-gG_MASK={mask}',f'-gG_PATH={path}/']
  # std_logic command-line generics require a VHDL character literal.
  args[1]="-gG_RTS="+("'1'" if rts else "'0'")
  log=run(['-r','--std=08','tb_token_gate',*args,'--assert-level=error','--max-stack-alloc=0'],name);m=re.search(r'TOKEN_GATE_PASS cycles=(\d+) values=(\d+)',log);assert m,log
  reports.append({'case':name,'cycles_simulated':int(m[1]),'exact_output_values':int(m[2]),'output_tokens':len(expected),'status':'passed'});print(name,'passed',flush=True)
 (BUILD/'gate_results.json').write_text(json.dumps({'status':'passed','seed':4253,'cases':reports,'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'limits':'Connected token-gate subsystem with simulated score memory; scorer linear projection is separately provided by the shared tensor engine.'},indent=2)+'\n')
if __name__=='__main__':main()
