"""Full AXI-Lite/AXIS/platform inference, including real model loading and reset."""
import argparse,hashlib,json,re,resource,shutil,subprocess,sys
from pathlib import Path
import numpy as np
from export_image import build,write_words
from test_core import expected_mac
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT));BUILD=ROOT/'rtl/build/system'
def main():
 global BUILD
 parser=argparse.ArgumentParser();parser.add_argument('--case',action='append');parser.add_argument('--repeat',type=int,default=1);parser.add_argument('--build-name',default='system');a=parser.parse_args()
 if not re.fullmatch(r'[A-Za-z0-9_-]+',a.build_name):raise ValueError('Invalid isolated build name')
 BUILD=ROOT/'rtl/build'/a.build_name;BUILD.mkdir(parents=True,exist_ok=True)
 soft,hard=resource.getrlimit(resource.RLIMIT_STACK);target=64*1024*1024 if hard==resource.RLIM_INFINITY else min(hard,64*1024*1024);resource.setrlimit(resource.RLIMIT_STACK,(max(soft,target),hard))
 ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl');flags=[] if 'mcode' in subprocess.check_output([ghdl,'--version'],text=True).lower() else ['-O2']
 def run(arguments,name):
  path=BUILD/(name+'.log')
  with path.open('w') as log:p=subprocess.run([ghdl,*arguments],cwd=BUILD,text=True,stdout=log,stderr=subprocess.STDOUT,timeout=7200)
  text=path.read_text()
  if p.returncode:raise RuntimeError(text[-16000:])
  return text
 sources=(ROOT/'rtl/sources.f').read_text().splitlines();hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
 run(['-a','--std=08',*flags,*[str(ROOT/p) for p in sources],str(ROOT/'rtl/tb/tb_platform_system.vhd')],'analyze')
 from golden.reference import IntegerEncoder
 reports=[]
 for case in a.case or ['har_energy_saver_seed17','speech_quality_seed17']:
  export=ROOT/'results/alignment_study/exports'/case;v=np.load(ROOT/'results/alignment_study/test'/case/'golden_vectors.npz');m,regions,memory,identity=build(export);path=BUILD/case;path.mkdir(parents=True,exist_ok=True);write_words(path/'memory.hex',memory)
  raw=[int(value) for value in v['input_int8'].flat];packed=[sum((x&255)<<(8*i) for i,x in enumerate(raw[base:base+8])) for base in range(0,len(raw),8)];write_words(path/'input.hex',packed);write_words(path/'logits.hex',v['logits'])
  reference=IntegerEncoder(export,use_native=False);logits=reference.predict(v['input_int8']);assert np.array_equal(logits,v['logits']);sat=sum(reference.saturations.values());mac=expected_mac(m)
  print('Running loaded AXI/platform system:',case,'repeat',a.repeat,flush=True)
  generics=[f'-gG_MODE={regions["PROFILE"][4]}',f'-gG_WORKLOAD={regions["PROFILE"][3]}',f'-gG_INPUT_WORDS={len(packed)}',f'-gG_CLASSES={len(logits)}',f'-gG_EXPECTED_MAC={mac}',f'-gG_EXPECTED_SAT={sat}',f'-gG_REPEAT={a.repeat}',f'-gG_PATH={path}/']
  log=run(['--elab-run','--std=08',*flags,'tb_platform_system',*generics,'--assert-level=error','--max-stack-alloc=0','--unbuffered'],case);match=re.search(r'PLATFORM_SYSTEM_PASS inferences=(\d+) logits_per_inference=(\d+)',log);assert match,log[-3000:]
  reports.append({'case':case,'status':'passed','image_identity':identity,'inferences':int(match[1]),'exact_logits_per_inference':int(match[2]),'diagnostic_counter_observations':[{'event':int(event),'count':int(count)} for event,count in re.findall(r'TOP_COUNTER event=(\d+) count=(\d+)',log)],'kernel_cycles_simulated':[int(value) for value in re.findall(r'TOP_INFERENCE_PASS run=\d+ cycles=(\d+)',log)],'active_mac_products':mac,'boundary_saturations':sat});print(case,'loaded platform system passed',flush=True)
 assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'RTL changed during system regression'
 (BUILD/'system_results.json').write_text(json.dumps({'status':'passed','cases':reports,'source_sha256':hashes,'limits':'Complete PL peripheral simulation with testbench AXI master/DMA streams. No vendor PS block design, target utilization, routed Fmax, board data or power measurement.'},indent=2)+'\n')
if __name__=='__main__':main()
