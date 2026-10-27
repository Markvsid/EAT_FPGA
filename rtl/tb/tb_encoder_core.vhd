library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;use ieee.std_logic_textio.all;use std.textio.all;use std.env.all;
use work.eat_config_pkg.all;use work.eat_types_pkg.all;use work.eat_math_pkg.all;use work.eat_image_pkg.all;
entity tb_encoder_core is generic(G_MODE:natural:=0;G_WORKLOAD:natural:=0;G_BANK:natural:=2;G_INPUT_WORDS:positive:=144;G_CLASSES:positive:=6;G_EXPECTED_MAC:natural:=1;G_EXPECTED_SAT:natural:=0;G_PATH:string:="./");end;
architecture test of tb_encoder_core is
 type words_t is array(natural range <>) of std_logic_vector(63 downto 0);
 impure function load(name:string;count:positive) return words_t is
  file f:text open read_mode is G_PATH&name;variable l:line;variable a:words_t(0 to count-1);
 begin for i in a'range loop readline(f,l);hread(l,a(i));end loop;assert endfile(f) severity failure;return a;end;
 constant ROM:words_t:=load("memory.hex",C_IMAGE_BANK_WORDS);constant INPUTS:words_t:=load("input.hex",G_INPUT_WORDS);constant EXPECTED:words_t:=load("logits.hex",G_CLASSES);
 function image_identity return identity_t is variable id:identity_t;
 begin for i in 0 to 7 loop id(32*i+31 downto 32*i):=ROM(region_offset(CONST_PROFILE)+32+i)(31 downto 0);end loop;return id;end;
 signal clk:std_logic:='0';signal rst:std_logic:='1';signal cycle:natural:=0;
 signal start_valid,start_ready,lv,lr,ev,pv,pr,sv,sr,qv,qr,rv,rr:std_logic:='0';
 signal request:control_request_t:=C_CONTROL_REQUEST_IDLE;signal logits:state_beat_t;signal status:status_t;
 signal event:counter_event_t;signal event_count:unsigned(31 downto 0);
 signal p:param_req_t;signal s:param_rsp_t:=C_PARAM_RSP_IDLE;signal q:mem_req_t;signal r:mem_rsp_t:=C_MEM_RSP_IDLE;
begin
 clk<=not clk after 5 ns;pr<='1' when cycle mod 97/=0 else '0';qr<='1' when cycle mod 7<4 else '0';lr<='1' when cycle mod 41<13 else '0';
 process begin wait for 300 ms;assert false report "Core timeout" severity failure;end process;
 dut:entity work.eat_encoder_core(rtl) port map(clk_i=>clk,rst_i=>rst,start_valid_i=>start_valid,start_ready_o=>start_ready,request_i=>request,
  logits_valid_o=>lv,logits_ready_i=>lr,logits_o=>logits,status_o=>status,event_valid_o=>ev,event_o=>event,event_count_o=>event_count,
  mem_req_valid_o=>qv,mem_req_ready_i=>qr,mem_req_o=>q,mem_rsp_valid_i=>rv,mem_rsp_ready_o=>rr,mem_rsp_i=>r,
  param_req_valid_o=>pv,param_req_ready_i=>pr,param_req_o=>p,param_rsp_valid_i=>sv,param_rsp_ready_o=>sr,param_rsp_i=>s);
 process(clk)
  variable p_stall,q_stall,l_stall:boolean:=false;variable old_p:param_req_t;variable old_q:mem_req_t;variable old_l:state_beat_t;
 begin
  if rising_edge(clk) then
   cycle<=cycle+1;
   if cycle mod 1000000=0 then report "CORE_PROGRESS cycle="&integer'image(cycle) severity note;end if;
   if rst='1' then sv<='0';rv<='0';p_stall:=false;q_stall:=false;l_stall:=false;
   else
    if p_stall then assert pv='1' and p=old_p report "Core changed stalled parameter request" severity failure;end if;
    if q_stall then assert qv='1' and q=old_q report "Core changed stalled input request" severity failure;end if;
    if l_stall then assert lv='1' and logits=old_l report "Core changed stalled logits" severity failure;end if;
    p_stall:=pv='1' and pr='0';old_p:=p;q_stall:=qv='1' and qr='0';old_q:=q;l_stall:=lv='1' and lr='0';old_l:=logits;
    if sv='1' and sr='1' then sv<='0';end if;if rv='1' and rr='1' then rv<='0';end if;
    if pv='1' and pr='1' then
     assert sv='0' and p.bank=G_BANK and to_integer(p.address)<region_words(p.kind) report "Invalid core parameter transaction" severity failure;
     s<=(ROM(region_offset(p.kind)+to_integer(p.address)),p.tag,'0');sv<='1';
    end if;
    if qv='1' and qr='1' then
     assert rv='0' and q.write_enable='0' and to_integer(q.address)<INPUTS'length report "Invalid core input transaction" severity failure;
     r<=(INPUTS(to_integer(q.address)),q.tag,'0');rv<='1';
    end if;
   end if;
  end if;
 end process;
 process
 begin
  wait until rising_edge(clk);wait until rising_edge(clk);wait for 1 ns;rst<='0';
  request<=(mode_t'val(G_MODE),workload_t'val(G_WORKLOAD),to_unsigned(G_BANK,4),image_identity,to_unsigned(4250,32));start_valid<='1';
  loop wait until rising_edge(clk);exit when start_ready='1';end loop;wait for 1 ns;start_valid<='0';
  wait;
 end process;
 process(clk)
  variable count:natural:=0;variable expected_context:context_t;variable seen:std_logic_vector(8 downto 0):=(others=>'0');variable index:natural;
  variable observed_wait,bubbles,nonlinear_wait:natural:=0;
 begin
  if rising_edge(clk) and rst='0' then
   if (pv='1' and pr='0') or (sr='1' and sv='0') or (qv='1' and qr='0') or (rr='1' and rv='0') then observed_wait:=observed_wait+1;end if;
   expected_context:=(to_unsigned(4250,32),mode_t'val(G_MODE),workload_t'val(G_WORKLOAD),to_unsigned(G_BANK,4));
   if status.error='1' then assert false report "Core error "&error_t'image(status.code) severity failure;end if;
   if ev='1' then
    case event is
     when EV_ACTIVE_MAC => index:=0;assert event_count=G_EXPECTED_MAC report "Wrong MAC count got="&integer'image(to_integer(event_count))&" expected="&integer'image(G_EXPECTED_MAC) severity failure;
     when EV_SATURATION => index:=1;assert event_count=G_EXPECTED_SAT report "Wrong saturation count got="&integer'image(to_integer(event_count))&" expected="&integer'image(G_EXPECTED_SAT) severity failure;
     when EV_INPUT_BYTE => index:=2;assert event_count=G_INPUT_WORDS*8 severity failure;
     when EV_OUTPUT_BYTE => index:=3;assert event_count=G_CLASSES*4 severity failure;
     when EV_RETAINED_TOKEN => index:=4;if G_MODE=0 then assert event_count=32 severity failure;elsif G_MODE=1 then assert event_count=24 severity failure;else assert event_count=16 severity failure;end if;
     when EV_SUMMARY_TOKEN => index:=5;if G_MODE=0 then assert event_count=0 severity failure;elsif G_MODE=1 then assert event_count=2 severity failure;else assert event_count=4 severity failure;end if;
     when EV_BUBBLE => index:=6;bubbles:=to_integer(event_count);assert event_count>0 and event_count<cycle severity failure;
     when EV_MEMORY_STALL => index:=7;assert event_count=observed_wait report "Memory wait cycles mismatch" severity failure;
     when EV_NONLINEAR_STALL => index:=8;nonlinear_wait:=to_integer(event_count);assert event_count>0 and event_count<cycle severity failure;
     when others => assert false report "Unexpected core event" severity failure;index:=0;
    end case;
    assert seen(index)='0' report "Duplicate core event" severity failure;seen(index):='1';
   end if;
   if lv='1' and lr='1' then
    assert logits.ctx=expected_context and logits.token=0 and logits.feature_base=count report "Bad core logit metadata" severity failure;
    for i in 0 to C_LANES-1 loop
     if count<G_CLASSES then
      assert logits.keep(i)='1' and resize(logits.data(i),64)=signed(EXPECTED(count)) report "Core logit mismatch class="&integer'image(count)&" got="&integer'image(to_integer(logits.data(i)))&" expected="&integer'image(to_integer(signed(EXPECTED(count)))) severity failure;
      count:=count+1;
     else assert logits.keep(i)='0' severity failure;end if;
    end loop;
    assert logits.last=flag(count=G_CLASSES) severity failure;
   end if;
   if status.done='1' then
    assert status.ctx=expected_context and status.busy='0' and count=G_CLASSES and seen="111111111" report "Bad core completion" severity failure;
    report "CORE_COUNTERS bubble="&integer'image(bubbles)&" memory_wait="&integer'image(observed_wait)&" nonlinear_wait="&integer'image(nonlinear_wait) severity note;
    report "ENCODER_CORE_PASS cycles="&integer'image(cycle)&" logits="&integer'image(count) severity note;stop;
   end if;
  end if;
 end process;
end;
