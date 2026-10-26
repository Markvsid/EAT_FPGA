"""Exact vector RTL regressions on frozen traces and numerical/protocol boundaries."""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
import numpy as np
from test_tensor import write
ROOT=Path(__file__).resolve().parents[2];BUILD=ROOT/'rtl/build/vector'
def main():
 BUILD.mkdir(parents=True,exist_ok=True)
 ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
 def run(args,name):
  p=subprocess.run([ghdl,*args],cwd=BUILD,text=True,capture_output=True);(BUILD/(name+'.log')).write_text(p.stdout+p.stderr)
  if p.returncode:raise RuntimeError(p.stdout+p.stderr)
  return p.stdout+p.stderr
 sources=(ROOT/'rtl/sources.f').read_text().splitlines();hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
 run(['-a','--std=08',*[str(ROOT/p) for p in sources],str(ROOT/'rtl/tb/tb_vector_units.vhd')],'analyze');run(['-e','--std=08','tb_vector_units'],'elaborate')
 reports=[]
 def check(name,op,x,expected,params,rsqrt,second=None):
  expected=expected.reshape(-1,x.shape[1]);path=BUILD/name;path.mkdir(parents=True,exist_ok=True)
  write(path/'second.hex',np.zeros_like(x) if second is None else second)
  for f,a in [('input',x),('expected',expected),('param',params),('rsqrt',rsqrt)]:write(path/(f+'.hex'),a)
  args=[f'-gG_OUTPUT_ROWS={expected.shape[0]}',f'-gG_ROWS={x.shape[0]}',f'-gG_FEATURES={x.shape[1]}',f'-gG_PARAM_COUNT={params.size}',f'-gG_OPERATION={op}',f'-gG_PATH={path}/']
  log=run(['-r','--std=08','tb_vector_units',*args,'--assert-level=error','--max-stack-alloc=0'],name)
  m=re.search(r'VECTOR_UNITS_PASS cycles=(\d+) values=(\d+)',log);assert m,log
  reports.append({'case':name,'operation':op,'cycles_simulated':int(m[1]),'exact_output_values':int(m[2]),'status':'passed'});print(name,'passed',flush=True)
 for case in ['har_quality_seed17','har_balanced_seed17','har_energy_saver_seed17','speech_quality_seed17']:
  export=ROOT/'results/alignment_study/exports'/case;c=np.load(export/'constants.npz');v=np.load(ROOT/'results/alignment_study/test'/case/'golden_vectors.npz');manifest=json.loads((export/'manifest.json').read_text())
  depth=manifest['mode']['exit_block']
  tuples=[('position','embedding','position_added','position'),('rmsnorm','position_added','blocks.0.norm1','blocks.0.norm1.gamma'),('pwl','blocks.0.fc1','blocks.0.activation','silu_knots'),('residual','position_added','blocks.0.residual1','position'),('pool','norm','pooled','norm.gamma'),('rmsnorm',f'blocks.{depth-1}.residual2','norm','norm.gamma')]
  for op,ik,ok,pk in tuples:
   check(case+'_'+op+'_'+ok.replace('.','_'),op,v[ik],v[ok],c[pk],c['rsqrt_table'],v['blocks.0.projection'] if op=='residual' else None)
 # Directed tails, exact knot endpoints, saturation, zero variance, gamma signs,
 # non-power-of-two feature/token means, and full signed24 ranges.
 from golden.arithmetic import rmsnorm_lut,pwl_activation,saturate,round_divide
 rng=np.random.default_rng(4254);spec=manifest['spec'];rsqrt=c['rsqrt_table'];knots=c['silu_knots']
 for features,zero in [(128,True),(13,False)]:
  x=np.zeros((2,features),dtype=np.int64) if zero else rng.integers(-2**23,2**23,(2,features),dtype=np.int64)
  gamma=rng.integers(-30000,30000,features,dtype=np.int64);expected=saturate(rmsnorm_lut(x,gamma,rsqrt,spec),24)
  check(f'synthetic_norm_{features}_{int(zero)}','rmsnorm',x,expected,gamma,rsqrt)
 x=np.array([[-8388608,-16385,-16384,-16383,-12289,-12288,-8192,-4097,-4096,-4095,-1,0,1,4095,4096,8192,12288,16383,16384,16385,8388607]],dtype=np.int64)
 check('synthetic_pwl_knots_tails','pwl',x,saturate(pwl_activation(x,knots,spec),24),knots,rsqrt)
 x=rng.integers(-2**23,2**23,(2,13),dtype=np.int64);y=rng.integers(-2**23,2**23,(2,13),dtype=np.int64)
 check('synthetic_position_saturation_tail','position',x,saturate(x+y,24),y,rsqrt)
 check('synthetic_residual_saturation_tail','residual',x,saturate(x+y,24),y,rsqrt,y)
 x=rng.integers(-2**23,2**23,(26,13),dtype=np.int64)
 check('synthetic_pool_26_13','pool',x,round_divide(x.sum(0),26),c['norm.gamma'],rsqrt)
 assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'RTL changed during regression'
 report={'status':'passed','seed':4254,'cases':reports,'source_sha256':hashes,'limits':'Isolated command/stream units with simulated parameter memory; no full encoder or timing proof.'}
 (BUILD/'vector_results.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
