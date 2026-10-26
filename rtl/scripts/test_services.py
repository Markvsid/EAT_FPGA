"""Memory, nonlinear, control and AXIS tests with independent Python expectations."""
import hashlib,json,random,shutil,subprocess
from pathlib import Path
import numpy as np
import test_primitives as tp
from test_primitives import s,u,sl,vec,shifted,rounded,clamp,fits,sig
ROOT=tp.ROOT;BUILD=ROOT/'rtl/build/services'
NAMES=['eat_exp_lut','eat_rsqrt_lut','eat_running_normalizer','eat_attention_finalize','eat_mode_controller','eat_performance_counters','eat_group_selector','eat_input_buffer','eat_weight_buffer_banked','eat_activation_buffer_pingpong','eat_attention_state_buffer','eat_token_index_buffer','eat_axi_stream_output']
tp.NAMES=NAMES
R=random.Random(4251)

def transaction(b,n,inputs,outputs,iv='s_valid_i',ir='s_ready_o',ov='m_valid_o',orr='m_ready_i'):
    b.cases[n]+=1;b.set(n,**inputs,**{iv:"'1'",orr:"'0'"})
    b.add(f"loop wait until rising_edge(clk);exit when {sig(n,ir)}='1';end loop;wait for 1 ns;")
    b.set(n,**{iv:"'0'"})
    b.add(f"while {sig(n,ov)}/='1' loop tick;end loop;")
    for _ in range(3):
        b.check(n,ov,"'1'")
        for p,v in outputs.items():b.check(n,p,v)
        b.add('tick;')
    b.set(n,**{orr:"'1'"});b.add('tick;');b.set(n,**{orr:"'0'"})

def param_lut(b,n,inputs,expected,kind,offset=None,response=0,error=False):
    b.cases[n]+=1
    b.set(n,**inputs,s_valid_i="'1'",m_ready_i="'0'",param_req_ready_i="'0'",param_rsp_valid_i="'0'")
    b.add(f"loop wait until rising_edge(clk);exit when {sig(n,'s_ready_o')}='1';end loop;wait for 1 ns;")
    b.set(n,s_valid_i="'0'")
    if offset is not None:
        req=f"param_req_t'({kind},to_unsigned({offset+7},C_MEM_ADDR_BITS),to_unsigned(2,4),to_unsigned(0,16))"
        b.add(f"while {sig(n,'param_req_valid_o')}/='1' loop tick;end loop;")
        for _ in range(3):b.check(n,'param_req_valid_o',"'1'");b.check(n,'param_req_o',req);b.add('tick;')
        b.set(n,param_req_ready_i="'1'");b.add('tick;');b.set(n,param_req_ready_i="'0'");b.add('tick;tick;')
        b.set(n,param_rsp_i=f"param_rsp_t'(std_logic_vector({u(response,64)}),to_unsigned(0,16),{sl(error)})",param_rsp_valid_i="'1'")
        b.add(f"loop wait until rising_edge(clk);exit when {sig(n,'param_rsp_ready_o')}='1';end loop;wait for 1 ns;")
        b.set(n,param_rsp_valid_i="'0'")
    b.add(f"while {sig(n,'m_valid_o')}/='1' loop tick;end loop;")
    for _ in range(3):
        b.check(n,'m_valid_o',"'1'")
        for p,v in expected.items():b.check(n,p,v)
        b.add('tick;')
    b.set(n,m_ready_i="'1'");b.add('tick;');b.set(n,m_ready_i="'0'")

def generate():
    b=tp.Bench()
    constants=np.load(ROOT/'results/alignment_study/exports/har_quality_seed17/constants.npz')
    exp=constants['exp_table'];rsqrt=constants['rsqrt_table']
    n='eat_exp_lut'
    for x in [0,-1,-8,-24,-65535,-65536,-65543,-65544,1,-2**39,*[-R.randrange(70000) for _ in range(60)]]:
        address=rounded(-x,16);req=x<=0 and address<=4096
        expected=int(exp[address]) if req else 0
        param_lut(b,n,{'negative_argument_i':s(x,40),'table_base_i':'to_unsigned(7,C_MEM_ADDR_BITS)','bank_i':'to_unsigned(2,4)'},{'exp_o':u(expected,21),'error_o':sl(x>0)},'CONST_EXP',address if req else None,expected)
    param_lut(b,n,{'negative_argument_i':s(-16,40),'table_base_i':'to_unsigned(7,C_MEM_ADDR_BITS)','bank_i':'to_unsigned(2,4)'},{'exp_o':u(0,21),'error_o':"'1'"},'CONST_EXP',1,0,True)
    n='eat_rsqrt_lut'
    for a in [0,1,511,1023,*[R.randrange(1024) for _ in range(30)]]:
        val=int(rsqrt[a]);param_lut(b,n,{'address_i':u(a,10),'table_base_i':'to_unsigned(7,C_MEM_ADDR_BITS)','bank_i':'to_unsigned(2,4)'},{'coefficient_q30_o':u(val,31),'error_o':"'0'"},'CONST_RSQRT',a,val)
    n='eat_running_normalizer'
    for _ in range(150):
        prev=R.randrange(2**31);alpha=R.randrange(2**20+1);ps=[R.randrange(2**20+1) for _ in range(8)];mask=R.randrange(256)
        total=rounded(prev*alpha,2**20)+sum(x for i,x in enumerate(ps) if mask>>i&1)
        probs="exp_beat_t'(("+','.join(f'{i}=>{u(x,21)}' for i,x in enumerate(ps))+f'),x"{mask:02x}",\'0\',C_CONTEXT_IDLE)'
        transaction(b,n,{'previous_i':s(prev,32),'alpha_i':u(alpha,21),'probabilities_i':probs},{'normalizer_o':s(total,32),'overflow_o':sl(not fits(total,32))})
    n='eat_attention_finalize'
    for _ in range(150):
        xs=[R.randrange(-2**39,2**39) for _ in range(8)];d=R.choice([0,1,2**20,2**30]);mask=R.randrange(256)
        ys=[rounded(x*2**20,d) if d else 0 for x in xs];ys=[clamp(x,24) if mask>>i&1 else 0 for i,x in enumerate(ys)]
        out=f"state_beat_t'({vec(ys,24)},x\"{mask:02x}\",5,24,'0',C_CONTEXT_IDLE)"
        bad=d<=0 or any(not fits(rounded(x*2**20,d),24) for i,x in enumerate(xs) if d and mask>>i&1)
        transaction(b,n,{'weighted_state_i':vec(xs,40),'normalizer_i':s(d,32),'keep_i':f'x"{mask:02x}"','token_i':'5','feature_base_i':'24','ctx_i':'C_CONTEXT_IDLE'},{'m_data_o':out,'overflow_o':sl(bad)})
    for n in ['eat_input_buffer','eat_weight_buffer_banked','eat_activation_buffer_pingpong','eat_attention_state_buffer','eat_token_index_buffer']:
        memory={}
        for index in range(45):
            address=index%16;word=R.getrandbits(64);mask=255 if address not in memory else R.randrange(256)
            old=memory.get(address,0);new=old
            for i in range(8):
                if mask>>i&1:new=(new&~(255<<(i*8)))|(word&(255<<(i*8)))
            memory[address]=new
            req=f"mem_req_t'(to_unsigned({address},C_MEM_ADDR_BITS),std_logic_vector({u(word,64)}),x\"{mask:02x}\",'1',to_unsigned({index},16))"
            rsp=f"mem_rsp_t'((others=>'0'),to_unsigned({index},16),'0')"
            transaction(b,n,{'req_i':req},{'rsp_o':rsp},'req_valid_i','req_ready_o','rsp_valid_o','rsp_ready_i')
            req=f"mem_req_t'(to_unsigned({address},C_MEM_ADDR_BITS),(others=>'0'),x\"00\",'0',to_unsigned({index+100},16))"
            rsp=f"mem_rsp_t'(std_logic_vector({u(new,64)}),to_unsigned({index+100},16),'0')"
            transaction(b,n,{'req_i':req},{'rsp_o':rsp},'req_valid_i','req_ready_o','rsp_valid_o','rsp_ready_i')
        req="mem_req_t'(to_unsigned(16,C_MEM_ADDR_BITS),(others=>'0'),x\"ff\",'1',to_unsigned(999,16))"
        rsp="mem_rsp_t'((others=>'0'),to_unsigned(999,16),'1')"
        transaction(b,n,{'req_i':req},{'rsp_o':rsp},'req_valid_i','req_ready_o','rsp_valid_o','rsp_ready_i')
    n='eat_group_selector'
    for case in range(40):
        groups=R.choice([1,4,8]);keep=R.randrange(groups+1);rts=R.randrange(2);scores=[R.randrange(-3,4) for _ in range(groups)];order=list(range(groups));R.shuffle(order)
        cmd=f"gate_cmd_t'({groups*4},{keep},{sl(rts)},C_CONTEXT_IDLE)"
        b.cases[n]+=1;b.set(n,cmd_i=cmd,cmd_valid_i="'1'",done_ready_i="'0'",decision_ready_i="'0'")
        b.add(f"loop wait until rising_edge(clk);exit when {sig(n,'cmd_ready_o')}='1';end loop;wait for 1 ns;");b.set(n,cmd_valid_i="'0'")
        for j,i in enumerate(order):
            b.set(n,scores_valid_i="'1'",score_i=s(scores[i],26),group_index_i=str(i),last_group_i=sl(j==groups-1))
            b.add(f"loop wait until rising_edge(clk);exit when {sig(n,'scores_ready_o')}='1';end loop;wait for 1 ns;")
        b.set(n,scores_valid_i="'0'")
        selected=sorted(range(groups),key=lambda i:(-scores[i],i))[:keep];mask=sum(1<<i for i in selected);tokens=4*keep+(groups-keep if rts else 0)
        decision=f"group_decision_t'(x\"{mask:02x}\",{tokens},C_CONTEXT_IDLE)"
        b.add(f"while {sig(n,'decision_valid_o')}/='1' loop tick;end loop;")
        for _ in range(3):b.check(n,'decision_o',decision);b.check(n,'decision_valid_o',"'1'");b.add('tick;')
        b.set(n,decision_ready_i="'1'");b.add('tick;');b.check(n,'done_valid_o',"'1'");b.check(n,'status_o',"status_t'('0','1','0',ERR_NONE,C_CONTEXT_IDLE)")
        b.set(n,done_ready_i="'1'");b.add('tick;');b.set(n,done_ready_i="'0'")
    n='eat_mode_controller'
    for idle,bankvalid,match,bank in [(0,1,1,1),(1,0,1,1),(1,1,0,1),(1,1,1,15),(1,1,1,2)]:
        req=f"control_request_t'(MODE_BALANCED,WORKLOAD_SPEECH,to_unsigned({bank},4),(others=>'0'),to_unsigned(42,32))"
        ctx=f"context_t'(to_unsigned(42,32),MODE_BALANCED,WORKLOAD_SPEECH,to_unsigned({bank},4))"
        b.cases[n]+=1;b.set(n,request_i=req,request_valid_i="'1'",core_idle_i=sl(idle),bank_valid_i=sl(bankvalid),loaded_identity_i="(others=>'0')" if match else "(others=>'1')",active_ready_i="'0'")
        b.add('tick;');b.set(n,request_valid_i="'0'");ok=idle and bankvalid and match and bank<8
        if ok:
            for _ in range(4):b.check(n,'active_valid_o',"'1'");b.check(n,'active_context_o',ctx);b.check(n,'request_ready_o',"'0'");b.add('tick;')
            b.set(n,active_ready_i="'1'");b.add('tick;')
        else:b.check(n,'active_valid_o',"'0'");b.check(n,'status_o',f"status_t'('0','0','1',{'ERR_BUSY' if not idle else 'ERR_IDENTITY'},{ctx})")
    n='eat_performance_counters';events=['EV_ACTIVE_MAC','EV_BUBBLE','EV_MEMORY_STALL','EV_NONLINEAR_STALL','EV_SATURATION','EV_INPUT_BYTE','EV_OUTPUT_BYTE','EV_RETAINED_TOKEN','EV_SUMMARY_TOKEN']
    for case in range(12):
        b.cases[n]+=1;b.set(n,start_i="'1'",snapshot_ready_i="'0'",complete_i="'0'",event_valid_i="'0'");b.add('tick;');b.set(n,start_i="'0'")
        counts={e:0 for e in events};length=R.randrange(1,30)
        for cycle in range(length):
            event=R.choice(events);amount=R.randrange(10000);counts[event]+=amount
            b.set(n,event_valid_i="'1'",event_i=event,event_count_i=u(amount,32),complete_i=sl(cycle==length-1));b.add('tick;')
        b.set(n,complete_i="'0'",event_valid_i="'0'")
        snap="counter_snapshot_t'(EV_CYCLE=>to_unsigned("+str(length+1)+",64),EV_INFERENCE=>to_unsigned(1,64),"+','.join(e+'=>'+u(v,64) for e,v in counts.items())+')'
        for _ in range(3):b.check(n,'snapshot_valid_o',"'1'");b.check(n,'snapshot_o',snap);b.add('tick;')
        b.set(n,snapshot_ready_i="'1'");b.add('tick;')
    n='eat_axi_stream_output'
    for classes in [6,35]*8:
        vals=[R.randrange(-2**23,2**23) for _ in range(classes)]
        for base in range(0,classes,8):
            xs=vals[base:base+8];mask=(1<<len(xs))-1;xs+=[0]*(8-len(xs))
            inp=f"state_beat_t'({vec(xs,24)},x\"{mask:02x}\",0,{base},{sl(base+8>=classes)},C_CONTEXT_IDLE)"
            b.cases[n]+=1;b.set(n,s_valid_i="'1'",s_data_i=inp,classes_i=str(classes),m_axis_tready_i="'0'")
            b.add(f"loop wait until rising_edge(clk);exit when {sig(n,'s_ready_o')}='1';end loop;wait for 1 ns;");b.set(n,s_valid_i="'0'")
            for part in range((min(8,classes-base)+3)//4):
                word=0;keep=0
                for i in range(4):
                    index=base+part*4+i
                    if index<classes:word|=(vals[index]%2**32)<<(32*i);keep|=15<<(4*i)
                for _ in range(3):
                    b.check(n,'m_axis_tvalid_o',"'1'");b.check(n,'m_axis_tdata_o',f'std_logic_vector({u(word,128)})');b.check(n,'m_axis_tkeep_o',f'x"{keep:04x}"');b.check(n,'m_axis_tlast_o',sl(base+part*4+4>=classes));b.check(n,'output_accepted_o',"'0'");b.add('tick;')
                b.set(n,m_axis_tready_i="'1'");b.add('tick;');b.set(n,m_axis_tready_i="'0'")
                b.check(n,'output_accepted_o',sl(base+part*4+4>=classes))
            b.add('tick;')
    return b

def main():
    BUILD.mkdir(parents=True,exist_ok=True);bench=generate();text=bench.render().replace('FUNCTIONAL_PRIMITIVES_PASS','FUNCTIONAL_SERVICES_PASS')
    for name in ['eat_input_buffer','eat_weight_buffer_banked','eat_activation_buffer_pingpong','eat_attention_state_buffer','eat_token_index_buffer']:
        text=text.replace(f'entity work.{name}(rtl) port map',f'entity work.{name}(rtl) generic map(G_WORDS=>16) port map')
    path=BUILD/'tb_services.vhd';path.write_text(text)
    ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl')
    def run(args):
        p=subprocess.run([ghdl,*args],cwd=BUILD,text=True,capture_output=True);(BUILD/('last_'+args[0].lstrip('-')+'.log')).write_text(p.stdout+p.stderr)
        if p.returncode:raise RuntimeError(p.stdout+p.stderr)
        return p.stdout+p.stderr
    sources=(ROOT/'rtl/sources.f').read_text().splitlines(); initial_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources};run(['-a','--std=08',*[str(ROOT/p) for p in sources],str(path)]);run(['-e','--std=08','tb_functional'])
    log=run(['-r','--std=08','tb_functional','--assert-level=error','--max-stack-alloc=0']);assert 'FUNCTIONAL_SERVICES_PASS' in log
    assert initial_hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'RTL changed during regression'
    report={'status':'passed','seed':4251,'cases':bench.cases,'total_cases':sum(bench.cases.values()),'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources if Path(p).stem in NAMES or '/pkg/' in p},'limits':'Isolated services only; RAM tests use 16 words; physical banking and full encoder remain unverified.'}
    (BUILD/'service_results.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'status':'passed','cases':report['total_cases'],'modules':len(NAMES)}))
if __name__=='__main__':main()
