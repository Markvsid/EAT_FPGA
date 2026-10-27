"""Connected AXIS ingress and descriptor tests, including malformed-frame drain."""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BUILD=ROOT/'rtl/build/streams'
def main():
 BUILD.mkdir(parents=True,exist_ok=True);ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
 sources=['rtl/pkg/eat_config_pkg.vhd','rtl/pkg/eat_types_pkg.vhd','rtl/pkg/eat_math_pkg.vhd','rtl/host/eat_dma_descriptor_engine.vhd','rtl/host/eat_axi_stream_input.vhd'];hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
 for arguments in [['-a','--std=08',*[str(ROOT/p) for p in sources],str(ROOT/'rtl/tb/tb_stream_dma.vhd')],['--elab-run','--std=08','tb_stream_dma','--assert-level=error']]:
  p=subprocess.run([ghdl,*arguments],cwd=BUILD,text=True,capture_output=True);(BUILD/('last_'+arguments[0].lstrip('-')+'.log')).write_text(p.stdout+p.stderr)
  if p.returncode:raise RuntimeError(p.stdout+p.stderr)
 m=re.search(r'AXIS_DMA_PASS frames=(\d+)',p.stdout);assert m,p.stdout
 assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'Streams changed during regression'
 (BUILD/'stream_results.json').write_text(json.dumps({'status':'passed','frames_including_reset_and_errors':int(m[1]),'source_sha256':hashes,'limits':'Ingress/descriptor protocol and byte ordering; PS DMA and board connections are external.'},indent=2)+'\n');print('Stream/DMA regression passed',m[1],'frames')
if __name__=='__main__':main()
