"""Deterministic GHDL regressions with Python big-integer numerical scoreboards.

Generated benches live only in rtl/build/functional. No result is calculated by
calling a DUT arithmetic helper. Fixed seed, explicit stalls and global timeout.
"""
import hashlib
import json
from pathlib import Path
import random
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
BUILD=ROOT/'rtl/build/functional'
SEED=4250
R=random.Random(SEED)
INV=json.loads((ROOT/'rtl/design_inventory.json').read_text())
NAMES=['eat_reset_sync','eat_rv_fifo','eat_stream_register','eat_round_shift','eat_round_divide','eat_reduction_tree','eat_leading_one','eat_weight_unpack','eat_activation_quantizer','eat_mac_lane','eat_mac_array','eat_requantizer','eat_score_scale']

def rounded(n,d):
    q,r=divmod(abs(n),d)
    q+=int(r>d-r or (r==d-r and q%2))
    return -q if n<0 else q

def shifted(n,s):
    return rounded(n,1<<s) if s>=0 else n<<-s

def clamp(n,b): return max(-(1<<(b-1)),min((1<<(b-1))-1,n))
def fits(n,b): return -(1<<(b-1))<=n<(1<<(b-1))
def s(n,b):return f"signed'(x\"{n % (1<<b):0{b//4}x}\")" if b%4==0 else f"to_signed({n},{b})"
def u(n,b):return f"unsigned'(x\"{n % (1<<b):0{b//4}x}\")" if b%4==0 else f"to_unsigned({n},{b})"
def sl(b):return "'1'" if b else "'0'"
def vec(values,b):return '('+', '.join(f'{i}=>{s(x,b)}' for i,x in enumerate(values))+')'
def sig(name,port):return name+'_'+port

class Bench:
    def __init__(self):
        self.code=[]; self.current=None; self.cases={n:0 for n in NAMES}
    def add(self,line):self.code.append('    '+line)
    def set(self,n,**values):
        if self.current!='reset_all' and self.current!=n:
            self.add("-- SECTION "+n);self.current=n
        for p,v in values.items():self.add(f'{sig(n,p)} <= {v};')
    def check(self,n,p,expected):
        self.add(f'assert {sig(n,p)}={expected} report "{n}.{p} case {self.cases[n]}" severity failure;')
    def tx(self,n,inputs,outputs,stall=None):
        self.cases[n]+=1
        self.set(n,**inputs,s_valid_i="'1'",m_ready_i="'0'")
        self.add(f"loop wait until rising_edge(clk); exit when {sig(n,'s_ready_o')}='1'; end loop;")
        self.add('wait for 1 ns;')
        self.set(n,s_valid_i="'0'")
        self.add(f"while {sig(n,'m_valid_o')} /='1' loop tick; end loop;")
        for _ in range(R.randrange(1,5) if stall is None else stall):
            self.check(n,'m_valid_o',"'1'")
            for p,v in outputs.items(): self.check(n,p,v)
            self.add('tick;')
        for p,v in outputs.items():self.check(n,p,v)
        self.set(n,m_ready_i="'1'");self.add('tick;');self.set(n,m_ready_i="'0'")
    def render(self):
        lines=['library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;use std.env.all;','use work.eat_config_pkg.all;use work.eat_types_pkg.all;','entity tb_functional is end;','architecture test of tb_functional is',"signal clk : std_logic := '0'; signal rst : std_logic := '1';"]
        mods=[m for m in INV['modules'] if m['name'] in NAMES]
        for m in mods:
            for p in m['ports']:
                if p['name'] in ['clk_i','rst_i']:continue
                init=' := '+p['idle'] if p['direction']=='in' else ''
                typ=p["type"]
                for key,value in {"G_DATA_BITS":"256","G_DEPTH":"4","G_IN_BITS":"72","G_OUT_BITS":"24"}.items():typ=typ.replace(key,value)
                lines.append(f"signal {sig(m['name'],p['name'])} : {typ}{init};")
        lines += ['begin',"clk<=not clk after 5 ns;",'process begin wait for 20 ms; assert false report "TIMEOUT" severity failure;end process;']
        for m in mods:
            maps=[p['name']+'=>'+('clk' if p['name']=='clk_i' else 'rst' if p['name']=='rst_i' else sig(m['name'],p['name'])) for p in m['ports']]
            lines.append(f"u_{m['name']}:entity work.{m['name']}(rtl) port map("+', '.join(maps)+');')
        lines += ['process','  procedure tick is begin wait until rising_edge(clk);wait for 1 ns;end;']
        groups=[]
        for line in self.code:
            if '-- SECTION ' in line: groups.append((line.split('-- SECTION ')[1],[]))
            else:groups[-1][1].append(line)
        for name,body in groups:
            lines += ['procedure check_'+name+' is begin',*body,'end procedure;']
        lines += ['begin',"tick;tick;rst<='0';tick;"]
        lines += ['check_'+name+';' for name,_ in groups]
        lines += ['report "FUNCTIONAL_PRIMITIVES_PASS" severity note;stop;wait;end process;end;']
        return '\n'.join(lines)+'\n'

def generate():
    b=Bench()
    n='eat_reset_sync';b.cases[n]=3
    b.set(n,arst_n_i="'0'");b.add('wait for 1 ns;');b.check(n,'rst_o',"'1'");b.set(n,arst_n_i="'1'");b.add('tick;');b.check(n,'rst_o',"'1'");b.add('tick;');b.check(n,'rst_o',"'0'")
    # FIFO: full, concurrent pop/push, wrap, stalls and flush.
    n='eat_rv_fifo';queue=[]
    for i in range(600):
        flush=R.random()<.035; pop=bool(queue) and R.random()<.6;push=R.random()<.7
        ready=len(queue)<4 or pop
        b.set(n,flush_i=sl(flush),m_ready_i=sl(pop),s_valid_i=sl(push),s_data_i=f"std_logic_vector({u(i,256)})")
        b.add('wait for 1 ns;');b.check(n,'occupancy_o',str(len(queue)))
        b.check(n,'m_valid_o',sl(bool(queue) and not flush));b.check(n,'s_ready_o',sl(ready and not flush))
        if queue and not flush:b.check(n,'m_data_o',f'std_logic_vector({u(queue[0],256)})')
        if flush:queue=[]
        else:
            if pop:queue.pop(0)
            if push and ready:queue.append(i)
        b.add('tick;');b.cases[n]+=1
    b.set(n,s_valid_i="'0'",m_ready_i="'0'",flush_i="'1'");b.add('tick;');b.check(n,'occupancy_o','0');b.set(n,flush_i="'0'")
    # Whole state record is checked, including metadata and invalid lane content.
    n='eat_stream_register'
    for i in range(50):
        beat=f"state_beat_t'((others=>{s(i-25,24)}),x\"a5\",{i%32},{i%384},{sl(i%2)},C_CONTEXT_IDLE)"
        b.tx(n,{'s_data_i':beat},{'m_data_o':beat})
    n='eat_round_shift'
    tests=[(x,k) for x in [-2**71,-2**63,-8388609,-8388608,-7,-5,-3,-1,0,1,3,5,7,8388607,2**63-1,2**71-1] for k in [-50,-1,0,1,2,24,50]]
    tests += [(R.randrange(-2**70,2**70),R.randrange(-50,51)) for _ in range(250)]
    for x,k in tests:
        y=shifted(x,k)
        b.tx(n,{'x_i':s(x,72),'shift_i':s(k,8)},{'y_o':s(clamp(y,24),24),'saturated_o':sl(not fits(y,24)),'overflow_o':sl(k<0 and not fits(y,63))})
    n='eat_round_divide'
    tests=[(x,d) for x in [-2**63,-2**63+1,-15,-7,-5,-3,-1,0,1,3,5,7,15,2**63-1] for d in [0,1,2,3,4,7,2**63,2**64-1]]
    tests +=[(R.randrange(-2**63+1,2**63),R.randrange(1,2**64)) for _ in range(200)]
    for x,d in tests:b.tx(n,{'numerator_i':s(x,64),'denominator_i':u(d,64)},{'quotient_o':s(rounded(x,d) if d else 0,64),'divide_by_zero_o':sl(d==0),'overflow_o':sl(d!=0 and x==-2**63)})
    n='eat_reduction_tree'
    for _ in range(200):
        xs=[R.randrange(-2**63,2**63) for _ in range(8)];mask=R.randrange(256);total=sum(x for i,x in enumerate(xs) if mask>>i&1)
        b.tx(n,{'values_i':vec(xs,64),'keep_i':f'x"{mask:02x}"'},{'sum_o':s(total,64),'overflow_o':sl(not fits(total,64))})
    n='eat_leading_one'
    for v in [0,*[1<<i for i in range(64)],2**64-1,*[R.randrange(2**64) for _ in range(100)]]:
        b.tx(n,{'value_i':u(v,64)},{'exponent_o':u(max(0,v.bit_length()-1),6),'zero_o':sl(v==0)})
    n='eat_weight_unpack'
    for _ in range(200):
        bits=R.choice([4,4,8,8,0,2]);half=R.randrange(2);mask=R.randrange(256);word=R.getrandbits(64);ok=bits==4 or(bits==8 and half==0)
        xs=[]
        for i in range(8):
            v=(word>>((32*half+4*i) if bits==4 else 8*i))&((1<<(4 if bits==4 else 8))-1)
            if v>>(3 if bits==4 else 7):v-=1<<(4 if bits==4 else 8)
            xs.append(v if ok and mask>>i&1 else 0)
        b.tx(n,{'packed_i':f'std_logic_vector({u(word,64)})','half_i':sl(half),'weight_bits_i':str(bits),'keep_i':f'x"{mask:02x}"'},{'weights_o':vec(xs,8),'keep_o':f'x"{mask if ok else 0:02x}"','error_o':sl(not ok)})
    n='eat_activation_quantizer'
    for _ in range(200):
        xs=[R.randrange(-2**23,2**23) for _ in range(8)];mask=R.randrange(256);k=R.randrange(-20,25)
        beat=f"state_beat_t'({vec(xs,24)},x\"{mask:02x}\",7,16,'1',C_CONTEXT_IDLE)"
        ys=[clamp(shifted(x,k),8) if mask>>i&1 else 0 for i,x in enumerate(xs)]
        out=f"act_beat_t'({vec(ys,8)},x\"{mask:02x}\",7,16,'1',C_CONTEXT_IDLE)"
        b.tx(n,{'s_data_i':beat,'shift_i':s(k,8)},{'m_data_o':out,'saturation_events_o':u(sum(not fits(shifted(x,k),8) for i,x in enumerate(xs) if mask>>i&1),16)})
    # Multi-step accumulation: first/last resets, disabled lanes and 36/80/128/256 tails.
    n='eat_mac_lane'
    for length in [1,2,36,80,128,256]*4:
        total=0
        for k in range(length):
            a,w=R.randrange(-128,128),R.randrange(-128,128);en=R.random()<.8
            b.set(n,s_valid_i="'1'",m_ready_i="'0'",activation_i=s(a,8),weight_i=s(w,8),enable_i=sl(en),first_k_i=sl(k==0),last_k_i=sl(k==length-1))
            b.add('tick;');total+=a*w*en
            if k!=length-1:b.check(n,'m_valid_o',"'0'")
        b.set(n,s_valid_i="'0'")
        for _ in range(3):b.check(n,'m_valid_o',"'1'");b.check(n,'accumulator_o',s(total,40));b.check(n,'overflow_o',"'0'");b.add('tick;')
        b.set(n,m_ready_i="'1'");b.add('tick;');b.cases[n]+=1
    n='eat_mac_array'
    for length in [1,36,80,128,256]:
        totals=[[0]*8 for _ in range(8)]
        for k in range(length):
            aa=[R.randrange(-128,128) for _ in range(8)];ww=[R.randrange(-128,128) for _ in range(8)];rm,cm=R.randrange(256),R.randrange(256)
            b.set(n,s_valid_i="'1'",m_ready_i="'0'",activations_i=vec(aa,8),weights_i=vec(ww,8),row_mask_i=f'x"{rm:02x}"',column_mask_i=f'x"{cm:02x}"',first_k_i=sl(k==0),last_k_i=sl(k==length-1))
            b.add('tick;');b.check(n,'active_products_o',u(rm.bit_count()*cm.bit_count(),16))
            for i in range(8):
                for j in range(8):totals[i][j]+=aa[i]*ww[j]*bool(rm>>i&1)*bool(cm>>j&1)
        b.set(n,s_valid_i="'0'")
        expected='('+','.join(f'{i}=>{vec(row,40)}' for i,row in enumerate(totals))+')'
        for _ in range(3):b.check(n,'accumulators_o',expected);b.check(n,'m_valid_o',"'1'");b.check(n,'overflow_o',"'0'");b.add('tick;')
        b.set(n,m_ready_i="'1'");b.add('tick;');b.cases[n]+=1
    n='eat_requantizer'
    for _ in range(250):
        xs=[R.randrange(-2**39,2**39) for _ in range(8)];bs=[R.randrange(-2**39,2**39) for _ in range(8)];ms=[R.randrange(-10,2**31) for _ in range(8)];mask=R.randrange(256)
        vals=[rounded((x+y)*m,2**24) for x,y,m in zip(xs,bs,ms)];ys=[clamp(v,24) if mask>>i&1 else 0 for i,v in enumerate(vals)]
        bad=any(not fits(x+y,40) or not fits((x+y)*m,63) or m<=0 for i,(x,y,m) in enumerate(zip(xs,bs,ms)) if mask>>i&1)
        out=f"state_beat_t'({vec(ys,24)},x\"{mask:02x}\",3,8,'1',C_CONTEXT_IDLE)"
        b.tx(n,{'accumulators_i':vec(xs,40),'bias_i':vec(bs,40),'multipliers_i':vec(ms,32),'keep_i':f'x"{mask:02x}"','token_i':'3','feature_base_i':'8','last_i':"'1'",'ctx_i':'C_CONTEXT_IDLE'},{'m_data_o':out,'saturation_events_o':u(sum(not fits(v,24) for i,v in enumerate(vals) if mask>>i&1),16),'overflow_o':sl(bad)})
    n='eat_score_scale'
    for x,m in [(R.randrange(-2**46,2**46),R.randrange(2**32)) for _ in range(250)]:
        value=rounded(rounded(x,4096)*m,2**20)
        b.tx(n,{'qk_q24_i':s(x,47) if abs(x)<2**31 else 'resize('+s(x,48)+',47)','scale_multiplier_q20_i':u(m,32)},{'score_q12_o':s(value,40),'overflow_o':sl(not fits(value,40))})
    b.current='reset_all'
    b.add('-- SECTION reset_all')
    # Put each output into a real stall before asserting reset. Division is multicycle.
    for name in NAMES:
        if name not in ['eat_reset_sync','eat_rv_fifo']:
            b.set(name,s_valid_i="'1'",m_ready_i="'0'")
    b.set('eat_mac_lane',first_k_i="'1'",last_k_i="'1'")
    b.set('eat_mac_array',first_k_i="'1'",last_k_i="'1'")
    b.add('for i in 0 to 80 loop tick;end loop;')
    for name in NAMES:
        if name not in ['eat_reset_sync','eat_rv_fifo']:
            b.check(name,'m_valid_o',"'1'");b.set(name,s_valid_i="'0'")
    b.add("rst<='1';tick;")
    for name in NAMES:
        if name not in ['eat_reset_sync','eat_rv_fifo']:b.check(name,'m_valid_o',"'0'")
    b.add("rst<='0';tick;")
    for name in NAMES:
        if name not in ['eat_reset_sync','eat_rv_fifo']:b.check(name,'m_valid_o',"'0'")
    return b

def main():
    BUILD.mkdir(parents=True,exist_ok=True)
    bench=generate();path=BUILD/'tb_functional.vhd';path.write_text(bench.render())
    ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
    def run(args):
        result=subprocess.run([ghdl,*args],cwd=BUILD,text=True,capture_output=True)
        (BUILD/('last_'+args[0].lstrip('-')+'.log')).write_text(result.stdout+result.stderr)
        if result.returncode:raise RuntimeError(result.stdout+result.stderr)
        return result.stdout+result.stderr
    sources=(ROOT/'rtl/sources.f').read_text().splitlines(); initial_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
    run(['-a','--std=08',*[str(ROOT/p) for p in sources],str(path)])
    run(['-e','--std=08','tb_functional'])
    log=run(['-r','--std=08','tb_functional','--assert-level=error'])
    assert 'FUNCTIONAL_PRIMITIVES_PASS' in log
    hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources if Path(p).stem in NAMES or '/pkg/' in p}
    assert initial_hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'RTL changed during regression'
    report={'status':'passed','seed':SEED,'cases':bench.cases,'total_cases':sum(bench.cases.values()),'tool':subprocess.check_output([ghdl,'--version'],text=True),'source_sha256':hashes,'limits':'Primitive simulation only; no full-model RTL equivalence, synthesis or timing result.'}
    (BUILD/'primitive_results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'status':'passed','cases':report['total_cases'],'modules':len(NAMES)}))
if __name__=='__main__':main()
