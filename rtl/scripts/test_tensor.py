"""Exercise actual 8x8 MAC RTL against synthetic and frozen linear golden tensors."""
import hashlib,json,random,re,shutil,subprocess
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0,str(ROOT))
BUILD=ROOT/'rtl/build/tensor'

def write(path,values):
    path.write_text(''.join(f'{int(x)%(1<<64):016x}\n' for x in (values.flat if isinstance(values,np.ndarray) else values)))
def prepare(path,x,w,b,m,expected,bits,shift):
    path.mkdir(parents=True,exist_ok=True)
    packed=[];flat=w.flatten();perword=64//bits
    for start in range(0,len(flat),perword):packed.append(sum((int(v)%2**bits)<<(i*bits) for i,v in enumerate(flat[start:start+perword])))
    for name,arr in [('input',x),('weights',packed),('bias',b),('mult',m),('expected',expected)]:write(path/(name+'.hex'),arr)
    return [f'-gG_ROWS={x.shape[0]}',f'-gG_COLS={w.shape[0]}',f'-gG_K={x.shape[1]}',f'-gG_BITS={bits}',f'-gG_SHIFT={shift}',f'-gG_PATH={path}/']
def main():
    BUILD.mkdir(parents=True,exist_ok=True)
    ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
    def run(args,name):
        p=subprocess.run([ghdl,*args],cwd=BUILD,text=True,capture_output=True)
        (BUILD/(name+'.log')).write_text(p.stdout+p.stderr)
        if p.returncode:raise RuntimeError(p.stdout+p.stderr)
        return p.stdout+p.stderr
    sources=(ROOT/'rtl/sources.f').read_text().splitlines(); initial_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
    run(['-a','--std=08',*[str(ROOT/p) for p in sources],str(ROOT/'rtl/tb/tb_tensor_engine.vhd')],'analyze')
    run(['-e','--std=08','tb_tensor_engine'],'elaborate')
    cases=[];rng=np.random.default_rng(4250)
    for rows,cols,k,bits in [(9,13,36,4),(26,35,80,8),(20,6,128,4),(1,9,256,8)]:
        x=rng.integers(-128,128,(rows,k),dtype=np.int64);w=rng.integers(-(1<<(bits-1)),1<<(bits-1),(cols,k),dtype=np.int64)
        b=rng.integers(-2000,2000,cols,dtype=np.int64);m=rng.integers(1,2**24,cols,dtype=np.int64)
        from golden.arithmetic import shift_round,saturate
        expected=saturate(shift_round((x@w.T+b)*m,24),24)
        name=f'synthetic_{rows}_{cols}_{k}_w{bits}';args=prepare(BUILD/name,x*32,w,b,m,expected,bits,5);cases.append((name,args))
    # Full exported embedding outputs; all rows and output columns, no prediction-only check.
    for case in ['har_quality_seed17','har_balanced_seed17','har_energy_saver_seed17','speech_quality_seed17']:
        export=ROOT/'results/alignment_study/exports'/case
        manifest=json.loads((export/'manifest.json').read_text());const=np.load(export/'constants.npz');v=np.load(ROOT/'results/alignment_study/test'/case/'golden_vectors.npz')
        layer='embedding';shift=manifest['layers'][layer]['q12_to_int8_shift'];bits=manifest['layers'][layer]['weight_bits']
        x=v[layer+'.input_int8'].astype(np.int64)<<shift
        args=prepare(BUILD/case,x,const[layer+'.weight'],const[layer+'.bias'],const[layer+'.multiplier'],v[layer],bits,shift);cases.append((case,args))
    reports=[]
    for name,args in cases:
        log=run(['-r','--std=08','tb_tensor_engine',*args,'--assert-level=error','--max-stack-alloc=0'],name)
        match=re.search(r'TENSOR_ENGINE_PASS cycles=(\d+) values=(\d+)',log);assert match,log
        reports.append({'case':name,'cycles_simulated':int(match[1]),'exact_output_values':int(match[2]),'status':'passed'})
        print(name,'passed',flush=True)
    assert initial_hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'RTL changed during regression'
    report={'status':'passed','seed':4250,'cases':reports,'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'limits':'Tensor engine only with simulated memory; no full encoder, physical bank bandwidth, synthesis or timing proof.'}
    (BUILD/'tensor_results.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
