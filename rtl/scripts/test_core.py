"""Full inference through the connected VHDL encoder, compared with integer data."""
import argparse,hashlib,json,re,resource,shutil,subprocess,sys
from pathlib import Path
import numpy as np
from export_image import build,write_words
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT));BUILD=ROOT/'rtl/build/core'
DEFAULT=['har_quality_seed17','har_balanced_seed17','har_energy_saver_seed17','speech_quality_seed17','speech_balanced_seed17','speech_energy_saver_seed17']
def expected_mac(m):
 c=m['config'];mode=m['mode'];n=32;count=32*c['patch_samples']*len(c['channels'])*128
 for block in range(mode['exit_block']):
  count+=n*131072+2*n*n*128
  if block==0 and mode['keep_groups']<8:
   count+=n*128;n=mode['keep_groups']*4+(8-mode['keep_groups'] if mode['rts'] else 0)
 return count+128*c['classes']
def main():
 global BUILD
 parser=argparse.ArgumentParser();parser.add_argument('--case',action='append');parser.add_argument('--build-name',default='core');parser.add_argument('--input-pattern',choices=['golden','maximum','minimum','checkerboard'],default='golden');args=parser.parse_args();
 if not re.fullmatch(r'[A-Za-z0-9_-]+',args.build_name):raise ValueError('Invalid isolated build name')
 BUILD=ROOT/'rtl/build'/args.build_name;BUILD.mkdir(parents=True,exist_ok=True)
 soft,hard=resource.getrlimit(resource.RLIMIT_STACK);target=64*1024*1024 if hard==resource.RLIM_INFINITY else min(hard,64*1024*1024);resource.setrlimit(resource.RLIMIT_STACK,(max(soft,target),hard))
 ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
 def run(arguments,name):
  path=BUILD/(name+'.log')
  with path.open('w') as log:p=subprocess.run([ghdl,*arguments],cwd=BUILD,text=True,stdout=log,stderr=subprocess.STDOUT,timeout=3600)
  text=path.read_text()
  if p.returncode:raise RuntimeError(text[-12000:])
  return text
 sources=(ROOT/'rtl/sources.f').read_text().splitlines()
 modules={Path(p).stem:p for p in sources if '/pkg/' not in p};used=set()
 def visit(name):
  if name in used:return
  used.add(name)
  for child in re.findall(r'entity\s+work\.(\w+)',(ROOT/modules[name]).read_text(),re.I):visit(child)
 visit('eat_encoder_core')
 tested=[modules[name] for name in sorted(used)]+['rtl/pkg/eat_config_pkg.vhd','rtl/pkg/eat_types_pkg.vhd','rtl/pkg/eat_math_pkg.vhd','rtl/pkg/eat_image_pkg.vhd']
 hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in tested}
 flags=[] if 'mcode' in subprocess.check_output([ghdl,'--version'],text=True).lower() else ['-O2']
 run(['-a','--std=08',*flags,*[str(ROOT/p) for p in sources],str(ROOT/'rtl/tb/tb_encoder_core.vhd')],'analyze')
 from golden.reference import IntegerEncoder
 reports=[]
 previous=BUILD/'core_results.json'
 if previous.exists():
  old=json.loads(previous.read_text())
  if all(old['source_sha256'].get(p)==h for p,h in hashes.items()):reports=old['cases']
 work=[(case,args.input_pattern) for case in args.case or DEFAULT]
 if not args.case and args.input_pattern=='golden':work += [('har_energy_saver_seed17','maximum'),('har_energy_saver_seed17','checkerboard')]
 for case,pattern in work:
  export=ROOT/'results/alignment_study/exports'/case;vpath=ROOT/'results/alignment_study/test'/case/'golden_vectors.npz';v=np.load(vpath)
  label=case if pattern=='golden' else case+'_'+pattern
  m,regions,memory,identity=build(export);path=BUILD/label;path.mkdir(parents=True,exist_ok=True);write_words(path/'memory.hex',memory)
  input_array=v['input_int8'].copy()
  if pattern=='maximum':input_array=np.full_like(input_array,127)
  elif pattern=='minimum':input_array=np.full_like(input_array,-128)
  elif pattern=='checkerboard':input_array=np.where(np.indices(input_array.shape).sum(0)%2,127,-128).astype(np.int64)
  raw=[int(x) for x in input_array.flat];packed=[sum((x&255)<<(8*i) for i,x in enumerate(raw[base:base+8])) for base in range(0,len(raw),8)];write_words(path/'input.hex',packed)
  reference=IntegerEncoder(export,use_native=False);logits=reference.predict(input_array)
  if pattern=='golden':assert np.array_equal(logits,v['logits'])
  write_words(path/'logits.hex',logits);sat=sum(reference.saturations.values());mac=expected_mac(m)
  print('Running full VHDL encoder:',label,'expected MAC',mac,'saturation',sat,flush=True)
  generics=[f'-gG_MODE={regions["PROFILE"][4]}',f'-gG_WORKLOAD={regions["PROFILE"][3]}',f'-gG_INPUT_WORDS={len(packed)}',f'-gG_CLASSES={len(logits)}',f'-gG_EXPECTED_MAC={mac}',f'-gG_EXPECTED_SAT={sat}',f'-gG_PATH={path}/']
  log=run(['--elab-run','--std=08',*flags,'tb_encoder_core',*generics,'--assert-level=error','--max-stack-alloc=0','--unbuffered'],label);match=re.search(r'ENCODER_CORE_PASS cycles=(\d+) logits=(\d+)',log);assert match,log[-3000:]
  reports=[record for record in reports if record['case']!=label]
  reports.append({'case':label,'model':case,'input_pattern':pattern,'input_sha256':hashlib.sha256(input_array.astype(np.int8).tobytes()).hexdigest(),'status':'passed','identity':identity,'exact_logits':int(match[2]),'cycles_simulated':int(match[1]),'diagnostic_counters':dict(zip(['bubble','memory_wait','nonlinear_wait'],map(int,re.search(r'CORE_COUNTERS bubble=(\d+) memory_wait=(\d+) nonlinear_wait=(\d+)',log).groups()))),'active_mac_products':mac,'boundary_saturations':sat,'vectors_sha256':hashlib.sha256(vpath.read_bytes()).hexdigest() if pattern=='golden' else None});print(label,'full encoder passed',flush=True)
 assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in tested},'RTL changed during full encoder regression'
 (BUILD/'core_results.json').write_text(json.dumps({'status':'passed','cases':reports,'source_sha256':hashes,'limits':'Full model for the listed saved examples with simulated parameter/input services; not full dataset, physical memory, Vivado timing or board equivalence.'},indent=2)+'\n')
if __name__=='__main__':main()
