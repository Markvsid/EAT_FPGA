"""Typed profile/parameter loader, explicit arming, identity and bounds regression."""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
from export_image import build,write_words
ROOT=Path(__file__).resolve().parents[2];BUILD=ROOT/'rtl/build/resident_images'
def main():
 import resource
 soft,hard=resource.getrlimit(resource.RLIMIT_STACK)
 target=64*1024*1024 if hard==resource.RLIM_INFINITY else min(64*1024*1024,hard)
 resource.setrlimit(resource.RLIMIT_STACK,(max(soft,target),hard))
 BUILD.mkdir(parents=True,exist_ok=True);ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
 def run(args,name):
  p=subprocess.run([ghdl,*args],cwd=BUILD,text=True,capture_output=True);(BUILD/(name+'.log')).write_text(p.stdout+p.stderr)
  if p.returncode:raise RuntimeError(p.stdout+p.stderr)
  return p.stdout+p.stderr
 sources=(ROOT/'rtl/sources.f').read_text().splitlines();hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
 run(['-a','--std=08',*[str(ROOT/p) for p in sources],str(ROOT/'rtl/tb/tb_resident_images.vhd'),str(ROOT/'rtl/tb/tb_model_banks.vhd')],'analyze')
 bank_log=run(['--elab-run','--std=08','tb_model_banks','--assert-level=error'],'banks')
 bank_match=re.search(r'MODEL_BANKS_PASS transactions=(\d+)',bank_log);assert bank_match,bank_log
 reports=[]
 for case in ['har_quality_seed17','har_balanced_seed17','har_energy_saver_seed17','speech_quality_seed17']:
  m,regions,memory,identity=build(ROOT/'results/alignment_study/exports'/case);path=BUILD/case;path.mkdir(parents=True,exist_ok=True);write_words(path/'memory.hex',memory)
  mode=regions['PROFILE'][4];workload=regions['PROFILE'][3]
  log=run(['--elab-run','--std=08','tb_resident_images',f'-gG_MODE={mode}',f'-gG_WORKLOAD={workload}',f'-gG_PATH={path}/','--assert-level=error','--max-stack-alloc=0'],case)
  match=re.search(r'RESIDENT_IMAGES_PASS writes=(\d+) payload_words=(\d+)',log);assert match,log
  reports.append({'case':case,'image_identity':identity,'payload_words_verified':int(match[2]),'writes_including_negative_cases':int(match[1]),'status':'passed'});print(case,'compact resident image passed',flush=True)
 assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'RTL changed during regression'
 (BUILD/'resident_image_results.json').write_text(json.dumps({'status':'passed','cases':reports,'bank_isolation_bounds_and_stall_transactions':int(bank_match[1]),'source_sha256':hashes,'limits':'Loader, parameter store, arbiter and actual compact resident RAM RTL; no target placement or FPGA result.'},indent=2)+'\n')
if __name__=='__main__':main()
