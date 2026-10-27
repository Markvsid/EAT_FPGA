"""AXI4-Lite channel ordering, byte strobes, held responses and snapshot regression."""
import hashlib,json,random,shutil,subprocess
from pathlib import Path
import test_primitives as tp
from test_primitives import sig,u
ROOT=tp.ROOT;BUILD=ROOT/'rtl/build/registers';tp.NAMES=['eat_axi_ctrl_regs'];N=tp.NAMES[0]
def main():
 b=tp.Bench();rng=random.Random(4255)
 def setv(**v):b.set(N,**v)
 def check(port,value):b.check(N,port,value)
 def write(addr,data,strobe=15,resp='00',pending=False):
  b.cases[N]+=1
  setv(s_axi_awaddr_i=f'std_logic_vector({u(addr,16)})',s_axi_wdata_i=f'std_logic_vector({u(data,32)})',s_axi_wstrb_i=f'"{strobe:04b}"',s_axi_bready_i="'0'")
  order=rng.randrange(3)
  if order<2:
   a,c=('aw','w') if order==0 else ('w','aw')
   setv(**{'s_axi_'+a+'valid_i':"'1'"});b.add(f"loop wait until rising_edge(clk);exit when {sig(N,'s_axi_'+a+'ready_o')}='1';end loop;wait for 1 ns;");setv(**{'s_axi_'+a+'valid_i':"'0'"})
   for _ in range(rng.randrange(1,4)):b.add('tick;')
   setv(**{'s_axi_'+c+'valid_i':"'1'"});b.add(f"loop wait until rising_edge(clk);exit when {sig(N,'s_axi_'+c+'ready_o')}='1';end loop;wait for 1 ns;");setv(**{'s_axi_'+c+'valid_i':"'0'"})
  else:
   setv(s_axi_awvalid_i="'1'",s_axi_wvalid_i="'1'");b.add(f"wait until rising_edge(clk);assert {sig(N,'s_axi_awready_o')}='1' and {sig(N,'s_axi_wready_o')}='1' severity failure;wait for 1 ns;");setv(s_axi_awvalid_i="'0'",s_axi_wvalid_i="'0'")
  b.add(f"while {sig(N,'s_axi_bvalid_o')}/='1' loop tick;end loop;")
  if pending:setv(request_ready_i="'0'")
  for _ in range(3):check('s_axi_bvalid_o',"'1'");check('s_axi_bresp_o','"'+resp+'"');b.add('tick;')
  setv(s_axi_bready_i="'1'");b.add('tick;');setv(s_axi_bready_i="'0'")
 def read(addr,value=0,resp='00'):
  b.cases[N]+=1;setv(s_axi_araddr_i=f'std_logic_vector({u(addr,16)})',s_axi_arvalid_i="'1'",s_axi_rready_i="'0'")
  b.add(f"loop wait until rising_edge(clk);exit when {sig(N,'s_axi_arready_o')}='1';end loop;wait for 1 ns;");setv(s_axi_arvalid_i="'0'")
  b.add(f"while {sig(N,'s_axi_rvalid_o')}/='1' loop tick;end loop;")
  for _ in range(3):check('s_axi_rvalid_o',"'1'");check('s_axi_rresp_o','"'+resp+'"');check('s_axi_rdata_o',f'std_logic_vector({u(value,32)})');b.add('tick;')
  setv(s_axi_rready_i="'1'");b.add('tick;');setv(s_axi_rready_i="'0'")
 read(0x14,0x20000);read(0x18,2);write(4,1);read(4,1);write(4,3,resp='10');read(4,1)
 write(4,0xffffffff,strobe=0);read(4,1);write(4,0x100,strobe=2,resp='10');read(4,1)
 write(0x10,0x21);read(0x10,0x21);read(0x6c,35);write(0x10,0xf1,resp='10');read(0x10,0x21)
 write(0x1c,0x11223344);write(0x1c,0xaa00cc00,strobe=10);read(0x1c,0xaa22cc44)
 identity=[]
 for i in range(8):
  value=rng.getrandbits(32);identity.append(value);write(0x20+4*i,value);read(0x20+4*i,value)
 ident=sum(v<<(32*i) for i,v in enumerate(identity));cfg=f"control_request_t'(MODE_BALANCED,WORKLOAD_SPEECH,to_unsigned(2,4),std_logic_vector({u(ident,256)}),{u(0xaa22cc44,32)})"
 check('config_o',cfg)
 setv(selected_bank_valid_i="'1'",loaded_identity_i=f'std_logic_vector({u(ident,256)})')
 for i,v in enumerate(identity):read(0x40+i*4,v)
 read(8,8)
 # A rejected start has no hidden queued request.
 setv(request_ready_i="'0'");write(0,1,resp='10');b.add('assert observed_starts=0 severity failure;')
 setv(request_ready_i="'1'");write(0,1,pending=True);check('request_valid_o',"'1'");check('request_o',cfg)
 write(4,0,resp='10');read(8,9);check('request_o',cfg)
 setv(request_ready_i="'1'");b.add('tick;tick;');b.add('assert observed_starts=1 severity failure;');b.add('assert observed_request='+cfg+' severity failure;')
 write(0x60,7);write(0x64,32);write(0x68,9);read(0x68,9);read(0x74,1)
 setv(transfer_ready_i="'1'");write(0,2);b.add('assert observed_transfers=1 severity failure;')
 transfer=f"transfer_cmd_t'(TRANSFER_CONSTANTS,{u(32,32)},to_unsigned(7,C_MEM_ADDR_BITS),CONST_PROFILE,context_t'({u(0xaa22cc44,32)},MODE_BALANCED,WORKLOAD_SPEECH,to_unsigned(2,4)))"
 check('transfer_config_o',transfer)
 b.add('assert observed_transfer='+transfer+' severity failure;')
 write(0x74,0);read(0x74,0);write(0x74,2,resp='10');write(0,3,resp='10');write(0,32,resp='10')
 setv(arm_ready_i="'1'");write(0,16);b.add('assert observed_arms=1 and observed_arm_bank=2 and observed_arm_identity=std_logic_vector('+u(ident,256)+') severity failure;')
 # Sticky IRQ acknowledges once, even if the incoming completion stays high.
 setv(status_i="status_t'('0','1','0',ERR_NONE,C_CONTEXT_IDLE)");b.add('tick;tick;');check('interrupt_o',"'1'");read(8,10);write(0,4);check('interrupt_o',"'0'");b.add('tick;tick;');check('interrupt_o',"'0'")
 setv(status_i='C_STATUS_IDLE');b.add('tick;');setv(status_i="status_t'('0','1','1',ERR_FRAME,C_CONTEXT_IDLE)");b.add('tick;tick;');check('interrupt_o',"'1'");read(0xc,7);write(0,4);check('interrupt_o',"'0'");setv(status_i='C_STATUS_IDLE');b.add('tick;')
 # Snapshot ID read freezes all counter halves until another snapshot ID read.
 counters="counter_snapshot_t'(EV_CYCLE=>unsigned'(x\"0000000200000003\"),EV_ACTIVE_MAC=>unsigned'(x\"00000001ffffffff\"),others=>(others=>'0'))"
 setv(counters_i=counters,snapshot_id_i=u(42,32));read(0x70,42)
 newer="counter_snapshot_t'(EV_CYCLE=>unsigned'(x\"0000000800000009\"),EV_ACTIVE_MAC=>unsigned'(x\"0000000a0000000b\"),others=>(others=>'0'))"
 setv(counters_i=newer,snapshot_id_i=u(99,32));read(0x100,3);read(0x104,2);read(0x110,0xffffffff);read(0x114,1);read(0x70,99);read(0x100,9);read(0x104,8)
 setv(status_i="status_t'('1','0','0',ERR_NONE,C_CONTEXT_IDLE)");write(4,0,resp='10');write(0x64,16,resp='10');write(0,4,resp='10');read(8,9);setv(status_i='C_STATUS_IDLE');b.add('tick;')
 write(0x14,0,resp='10');write(0x60,1<<20,resp='10');write(0x68,10,resp='10');write(5,0,resp='10');read(5,0,'10');read(0x88,0,'10');write(0x88,1,resp='10')
 write(0,8);b.add('assert observed_counter_clears=1 severity failure;')
 # Paired channels buffered before reset must not produce a post-reset response.
 setv(s_axi_awaddr_i='x"0004"',s_axi_awvalid_i="'1'");b.add('tick;');setv(s_axi_awvalid_i="'0'");b.add("rst<='1';tick;rst<='0';tick;");check('s_axi_bvalid_o',"'0'");check('request_valid_o',"'0'");check('transfer_valid_o',"'0'");check('arm_valid_o',"'0'")
 text=b.render().replace('FUNCTIONAL_PRIMITIVES_PASS','AXIL_REGISTERS_PASS')
 decl='''signal observed_starts,observed_transfers,observed_arms,observed_counter_clears:natural:=0;
signal observed_request:control_request_t:=C_CONTROL_REQUEST_IDLE;signal observed_transfer:transfer_cmd_t:=C_TRANSFER_CMD_IDLE;
signal observed_arm_bank:bank_id_t;signal observed_arm_identity:identity_t;
'''
 monitor=f'''process(clk) begin if rising_edge(clk) then
 if {sig(N,'request_valid_o')}='1' and {sig(N,'request_ready_i')}='1' then observed_starts<=observed_starts+1;observed_request<={sig(N,'request_o')};end if;
 if {sig(N,'transfer_valid_o')}='1' and {sig(N,'transfer_ready_i')}='1' then observed_transfers<=observed_transfers+1;observed_transfer<={sig(N,'transfer_o')};end if;
 if {sig(N,'arm_valid_o')}='1' and {sig(N,'arm_ready_i')}='1' then observed_arms<=observed_arms+1;observed_arm_bank<={sig(N,'arm_bank_o')};observed_arm_identity<={sig(N,'arm_identity_o')};end if;
 if {sig(N,'clear_counters_o')}='1' then observed_counter_clears<=observed_counter_clears+1;end if;
end if;end process;
'''
 text=text.replace("begin\nclk<=not clk after 5 ns;",decl+'begin\n'+monitor+"clk<=not clk after 5 ns;")
 BUILD.mkdir(parents=True,exist_ok=True);path=BUILD/'tb_registers.vhd';path.write_text(text)
 ghdl=shutil.which('ghdl') or str(ROOT/'.tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl');sources=['rtl/pkg/eat_config_pkg.vhd','rtl/pkg/eat_types_pkg.vhd','rtl/pkg/eat_math_pkg.vhd','rtl/pkg/eat_registers_pkg.vhd','rtl/host/eat_axi_ctrl_regs.vhd'];hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
 for arguments in [['-a','--std=08',*[str(ROOT/p) for p in sources],str(path)],['--elab-run','--std=08','tb_functional','--assert-level=error']]:
  p=subprocess.run([ghdl,*arguments],cwd=BUILD,text=True,capture_output=True);(BUILD/('last_'+arguments[0].lstrip('-')+'.log')).write_text(p.stdout+p.stderr)
  if p.returncode:raise RuntimeError(p.stdout+p.stderr)
 assert 'AXIL_REGISTERS_PASS' in p.stdout
 assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'Register sources changed during regression'
 (BUILD/'register_results.json').write_text(json.dumps({'status':'passed','seed':4255,'axi_transactions':b.cases[N],'source_sha256':hashes,'limits':'AXI-Lite front end with controlled downstream services; top integration is tested separately.'},indent=2)+'\n');print('AXI-Lite register regression passed',b.cases[N],'transactions')
if __name__=='__main__':main()
