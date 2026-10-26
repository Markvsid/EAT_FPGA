"""Round-robin service-routing and stalled-channel scoreboards."""
import hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BUILD=ROOT/'rtl/build/arbiter'
def main():
 BUILD.mkdir(parents=True,exist_ok=True);ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
 sources=(ROOT/'rtl/sources.f').read_text().splitlines(); initial_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
 for args in [['-a','--std=08',*[str(ROOT/p) for p in sources],str(ROOT/'rtl/tb/tb_memory_arbiter.vhd')],['-e','--std=08','tb_memory_arbiter'],['-r','--std=08','tb_memory_arbiter','--assert-level=error']]:
  result=subprocess.run([ghdl,*args],cwd=BUILD,text=True,capture_output=True);(BUILD/('last_'+args[0].lstrip('-')+'.log')).write_text(result.stdout+result.stderr)
  if result.returncode:raise RuntimeError(result.stdout+result.stderr)
 assert 'MEMORY_ARBITER_PASS' in result.stdout
 assert initial_hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'RTL changed during regression'
 report={'status':'passed','responses':64,'clients':8,'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'limits':'Single outstanding memory request; routing/fairness simulation only.'}
 (BUILD/'arbiter_results.json').write_text(json.dumps(report,indent=2)+'\n');print('Memory arbiter passed')
if __name__=='__main__':main()
