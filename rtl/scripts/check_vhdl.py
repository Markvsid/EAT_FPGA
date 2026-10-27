"""Analyze and elaborate the implemented RTL; functional proof is a separate suite."""
import argparse,copy,json,platform,resource,shutil,subprocess,sys
from pathlib import Path
from check_scaffold import check,require_implemented
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--ghdl');a=p.parse_args()
 local=ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl';ghdl=a.ghdl or shutil.which('ghdl') or(str(local) if local.exists() else None)
 if not ghdl:raise SystemExit('GHDL required; no HDL checks ran')
 soft,hard=resource.getrlimit(resource.RLIMIT_STACK);target=64*1024*1024 if hard==resource.RLIM_INFINITY else min(hard,64*1024*1024);resource.setrlimit(resource.RLIMIT_STACK,(max(soft,target),hard))
 build=ROOT/'rtl/build';build.mkdir(exist_ok=True)
 for script in ['emit_config.py','emit_image_pkg.py']:subprocess.run([sys.executable,str(ROOT/'rtl/scripts'/script),'--check'],check=True)
 modules=check();require_implemented(modules,'eat_platform_wrapper')
 # Test the guard without changing the real inventory or accepting constant stubs.
 negative=copy.deepcopy(modules);negative['eat_mac_array']['status']='stub'
 try:require_implemented(negative,'eat_platform_wrapper')
 except ValueError as e:
  if 'eat_mac_array' not in str(e):raise
 else:raise RuntimeError('Dependency guard accepted a reachable simulated stub')
 subprocess.run([sys.executable,str(ROOT/'rtl/scripts/audit_numerics.py')],check=True)
 sources=(ROOT/'rtl/sources.f').read_text().splitlines()
 def run(arguments):
  p=subprocess.run([ghdl,*arguments],cwd=build,text=True,capture_output=True);(build/'last_analysis.log').write_text(p.stdout+p.stderr)
  if p.returncode:raise RuntimeError(p.stdout+p.stderr)
 run(['-a','--std=08',*[str(ROOT/p) for p in sources]])
 for name in modules:
  # Portable across LLVM and mcode, including persistent model RAM declarations.
  run(['--elab-run','--std=08',name,'--no-run','--max-stack-alloc=0'])
 d=json.loads((ROOT/'rtl/design_inventory.json').read_text())
 result={'status':'analysis_elaboration_passed','ghdl':subprocess.check_output([ghdl,'--version'],text=True),'platform':platform.platform(),'entities_analyzed_elaborated':len(modules),'packages_analyzed':len(d['packages']),'remaining_stubs':sum(m['status']=='stub' for m in modules.values()),'implementation_guard':'passed_including_negative_in_memory_test','functional_equivalence':'see separately recorded functional core/system regressions','target_synthesis':'not_run'}
 (build/'structural_checks.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='ghdl'}))
if __name__=='__main__':main()
