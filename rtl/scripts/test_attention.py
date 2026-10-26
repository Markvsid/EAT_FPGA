"""Exact streamed-attention RTL tests against saved and synthetic integer tensors."""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
import numpy as np
from test_tensor import write
ROOT=Path(__file__).resolve().parents[2];BUILD=ROOT/'rtl/build/attention'
def main():
    BUILD.mkdir(parents=True,exist_ok=True)
    ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
    def run(args,name):
        p=subprocess.run([ghdl,*args],cwd=BUILD,text=True,capture_output=True);(BUILD/(name+'.log')).write_text(p.stdout+p.stderr)
        if p.returncode:raise RuntimeError(p.stdout+p.stderr)
        return p.stdout+p.stderr
    sources=(ROOT/'rtl/sources.f').read_text().splitlines(); initial_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
    run(['-a','--std=08',*[str(ROOT/p) for p in sources],str(ROOT/'rtl/tb/tb_attention.vhd')],'analyze')
    cases=[];rng=np.random.default_rng(4252)
    manifest=json.loads((ROOT/'results/alignment_study/exports/har_quality_seed17/manifest.json').read_text())
    table=np.load(ROOT/'results/alignment_study/exports/har_quality_seed17/constants.npz')['exp_table']
    from golden.arithmetic import online_attention,saturate
    for n in [1,17,20,26,32]:
        shifts=[7,7,8];raw=[rng.integers(-32,33,(4,n,32),dtype=np.int64) for _ in range(3)]
        restored=[x<<s for x,s in zip(raw,shifts)]
        expected=saturate(online_attention(*restored,table,manifest['spec'],manifest['attention_scale_multiplier_q20']),24).transpose(1,0,2).reshape(n,128)
        cases.append((f'synthetic_{n}',raw,shifts,expected,table))
    for case,block in [('har_quality_seed17',0),('har_balanced_seed17',0),('har_energy_saver_seed17',0),('speech_quality_seed17',0),('har_balanced_seed17',1),('har_energy_saver_seed17',1)]:
        export=ROOT/'results/alignment_study/exports'/case
        m=json.loads((export/'manifest.json').read_text());c=np.load(export/'constants.npz');v=np.load(ROOT/'results/alignment_study/test'/case/'golden_vectors.npz')
        prefix=f'blocks.{block}';shifts=m['attention_qkv_int8_shifts'][prefix];raw=[]
        assert m['attention_scale_multiplier_q20']==185364
        for kind,shift in zip(['q','k','v'],shifts):
            x=v[prefix+'.'+kind];assert np.all(x%(1<<shift)==0);raw.append(x>>shift)
        cases.append((case+'_'+str(block),raw,shifts,v[prefix+'.attention'],c['exp_table']))
    reports=[]
    for name,raw,shifts,expected,table in cases:
        path=BUILD/name;path.mkdir(parents=True,exist_ok=True);n=expected.shape[0]
        words=np.concatenate([x.transpose(1,0,2).reshape(n,128).ravel() for x in raw])
        for filename,values in [('input',words),('expected',expected),('exp',table)]:write(path/(filename+'.hex'),values)
        args=[f'-gG_TOKENS={n}',f'-gG_Q_SHIFT={shifts[0]}',f'-gG_K_SHIFT={shifts[1]}',f'-gG_V_SHIFT={shifts[2]}',f'-gG_PATH={path}/']
        log=run(['--elab-run','--std=08','tb_attention',*args,'--assert-level=error','--max-stack-alloc=0'],name)
        match=re.search(r'ATTENTION_PASS cycles=(\d+) values=(\d+)',log);assert match,log
        reports.append({'case':name,'tokens':n,'cycles_simulated':int(match[1]),'exact_output_values':int(match[2]),'status':'passed'});print(name,'passed',flush=True)
    assert initial_hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'RTL changed during regression'
    report={'status':'passed','seed':4252,'cases':reports,'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'limits':'Attention block with simulated memory and exponential table; no full encoder, timing or board result.'}
    (BUILD/'attention_results.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
