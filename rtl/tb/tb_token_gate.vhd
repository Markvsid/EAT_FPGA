library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;use ieee.std_logic_textio.all;use std.textio.all;use std.env.all;
use work.eat_config_pkg.all;use work.eat_types_pkg.all;
entity tb_token_gate is generic(G_KEEP:natural:=6;G_RTS:std_logic:='1';G_OUTPUT_TOKENS:positive:=26;G_MASK:natural:=63;G_PATH:string:="./");end;
architecture test of tb_token_gate is
 type words_t is array(natural range <>) of std_logic_vector(63 downto 0);
 impure function load(name:string;count:positive) return words_t is
  file f:text open read_mode is G_PATH&name;variable l:line;variable a:words_t(0 to count-1);
 begin for i in a'range loop readline(f,l);hread(l,a(i));end loop;assert endfile(f) severity failure;return a;end;
 constant INPUTS:words_t:=load("input.hex",32*128);constant SCORES:words_t:=load("scores.hex",32);
 constant EXPECTED:words_t:=load("expected.hex",G_OUTPUT_TOKENS*128);
 signal clk:std_logic:='0';signal rst:std_logic:='1';signal cycle:natural:=0;signal cv:std_logic:='0';signal cr1,cr2,cr3,d1,d2,d3:std_logic;
 signal cmd:gate_cmd_t:=C_GATE_CMD_IDLE;signal status1,status2,status3:status_t;
 signal tv,tr,iv,ir,ov,orr,gv,gr,gl,dv,dr:std_logic:='0';
 signal tokens_in,scores_in,output_beat:state_beat_t:=C_STATE_BEAT_IDLE;
 signal group_score:group_score_t;signal group_index:natural range 0 to 7;signal decision:group_decision_t;
 signal qw,qr:mem_req_t;signal qwv,qwr,qrv,qrr,rwv,rwr,rrv,rrr:std_logic:='0';signal rw,rr:mem_rsp_t:=C_MEM_RSP_IDLE;
 signal last_decision:group_decision_t:=C_GROUP_DECISION_IDLE;
begin
 clk<=not clk after 5 ns;orr<='1' when cycle mod 17<8 else '0';qwr<='1' when cycle mod 7<4 else '0';qrr<='1' when cycle mod 11<6 else '0';
 process begin wait for 20 ms;assert false report "Gate timeout" severity failure;end process;
 scorer:entity work.eat_group_scorer(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr1,cmd_i=>cmd,done_valid_o=>d1,done_ready_i=>'0',status_o=>status1,
  token_scores_valid_i=>tv,token_scores_ready_o=>tr,token_scores_i=>scores_in,scores_valid_o=>gv,scores_ready_i=>gr,score_o=>group_score,group_index_o=>group_index,last_group_o=>gl,
  mem_req_valid_o=>qwv,mem_req_ready_i=>qwr,mem_req_o=>qw,mem_rsp_valid_i=>rwv,mem_rsp_ready_o=>rwr,mem_rsp_i=>rw,
  param_req_valid_o=>open,param_req_ready_i=>'0',param_req_o=>open,param_rsp_valid_i=>'0',param_rsp_ready_o=>open,param_rsp_i=>C_PARAM_RSP_IDLE);
 selector:entity work.eat_group_selector(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr2,cmd_i=>cmd,done_valid_o=>d2,done_ready_i=>'0',status_o=>status2,
  scores_valid_i=>gv,scores_ready_o=>gr,score_i=>group_score,group_index_i=>group_index,last_group_i=>gl,decision_valid_o=>dv,decision_ready_i=>dr,decision_o=>decision);
 compactor:entity work.eat_token_compactor(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr3,cmd_i=>cmd,done_valid_o=>d3,done_ready_i=>'0',status_o=>status3,
  decision_valid_i=>dv,decision_ready_o=>dr,decision_i=>decision,s_valid_i=>iv,s_ready_o=>ir,s_data_i=>tokens_in,m_valid_o=>ov,m_ready_i=>orr,m_data_o=>output_beat,
  mem_req_valid_o=>qrv,mem_req_ready_i=>qrr,mem_req_o=>qr,mem_rsp_valid_i=>rrv,mem_rsp_ready_o=>rrr,mem_rsp_i=>rr);
 process(clk)
  variable memory:words_t(0 to 31);variable written:std_logic_vector(31 downto 0):=(others=>'0');
  variable wp,rp:boolean:=false;variable wd,rd:natural:=0;variable address:natural;
  variable old_output:state_beat_t;variable stalled:boolean:=false;
 begin
  if rising_edge(clk) then
   cycle<=cycle+1;
   if rst='1' then rwv<='0';rrv<='0';wp:=false;rp:=false;
   else
    if stalled then assert ov='1' and output_beat=old_output report "Gate changed stalled output" severity failure;end if;
    stalled:=ov='1' and orr='0';old_output:=output_beat;
    if dv='1' and dr='1' then last_decision<=decision;end if;
    if rwv='1' and rwr='1' then rwv<='0';end if;if rrv='1' and rrr='1' then rrv<='0';end if;
    if qwv='1' and qwr='1' then
     assert not wp and rwv='0' and qw.address>=32768 and qw.address<32800 and qw.write_enable='1' and qw.write_strobe=x"ff" severity failure;
     address:=to_integer(qw.address)-32768;assert qw.write_data=SCORES(address) severity failure;memory(address):=qw.write_data;written(address):='1';
     rw<=((others=>'0'),qw.tag,'0');wp:=true;wd:=cycle mod 5;
    end if;
    if qrv='1' and qrr='1' then
     assert not rp and rrv='0' and qr.address>=32768 and qr.address<32800 and qr.write_enable='0' severity failure;
     address:=to_integer(qr.address)-32768;assert written(address)='1' severity failure;rr<=(memory(address),qr.tag,'0');rp:=true;rd:=cycle mod 4;
    end if;
    if wp then if wd=0 then rwv<='1';wp:=false;else wd:=wd-1;end if;end if;
    if rp then if rd=0 then rrv<='1';rp:=false;else rd:=rd-1;end if;end if;
   end if;
  end if;
 end process;
 process
  variable beat:state_beat_t;
 begin
  wait until rising_edge(clk);wait until rising_edge(clk);wait for 1 ns;rst<='0';
  cmd<=(32,G_KEEP,G_RTS,(to_unsigned(4250,32),MODE_BALANCED,WORKLOAD_HAR,to_unsigned(1,4)));cv<='1';
  wait until rising_edge(clk);assert cr1='1' and cr2='1' and cr3='1' severity failure;wait for 1 ns;cv<='0';
  for token in 0 to 31 loop
   beat:=C_STATE_BEAT_IDLE;beat.ctx:=cmd.ctx;beat.token:=token;beat.keep:=x"01";beat.data(0):=resize(signed(SCORES(token)),24);
   if token=31 then beat.last:='1';end if;scores_in<=beat;tv<='1';
   loop wait until rising_edge(clk);exit when tr='1';end loop;wait for 1 ns;tv<='0';
  end loop;
  wait;
 end process;
 process
  variable beat:state_beat_t;
 begin
  wait until cv='1';wait until rising_edge(clk);wait for 1 ns;
  for token in 0 to 31 loop
   for feature in 0 to 15 loop
    beat:=C_STATE_BEAT_IDLE;beat.ctx:=cmd.ctx;beat.token:=token;beat.feature_base:=feature*8;beat.keep:=x"ff";
    if token=31 and feature=15 then beat.last:='1';end if;
    for i in 0 to 7 loop beat.data(i):=resize(signed(INPUTS(token*128+feature*8+i)),24);end loop;
    tokens_in<=beat;iv<='1';loop wait until rising_edge(clk);exit when ir='1';end loop;wait for 1 ns;iv<='0';
   end loop;
  end loop;
  wait;
 end process;
 process(clk)
  variable count:natural:=0;variable last:std_logic;
 begin
  if rising_edge(clk) and rst='0' then
   if ov='1' and orr='1' then
    assert output_beat.ctx=cmd.ctx and output_beat.token=count/128 and output_beat.feature_base=count mod 128 and output_beat.keep=x"ff" severity failure;
    last:='0';if count+8=EXPECTED'length then last:='1';end if;assert output_beat.last=last severity failure;
    for i in 0 to 7 loop assert resize(output_beat.data(i),64)=signed(EXPECTED(count)) report "Gate value mismatch "&integer'image(count) severity failure;count:=count+1;end loop;
   end if;
   if d3='1' then
    assert status3.error='0' and status2.error='0' and status1.error='0' and d1='1' and d2='1' and count=EXPECTED'length report "Gate completion error" severity failure;
    assert last_decision.retained=std_logic_vector(to_unsigned(G_MASK,8)) and last_decision.output_tokens=G_OUTPUT_TOKENS report "Wrong group selection" severity failure;
    report "TOKEN_GATE_PASS cycles="&integer'image(cycle)&" values="&integer'image(count) severity note;stop;
   end if;
  end if;
 end process;
end;
