library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use std.env.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
entity tb_attention is
  generic(G_TOKENS:positive:=32;G_Q_SHIFT:integer:=8;G_K_SHIFT:integer:=8;G_V_SHIFT:integer:=8;G_PATH:string:="./");
end entity;
architecture test of tb_attention is
  type words_t is array(natural range <>) of std_logic_vector(63 downto 0);
  impure function load(name:string; count:positive) return words_t is
    file f:text open read_mode is G_PATH & name;
    variable l:line;variable words:words_t(0 to count-1);
  begin
    for i in words'range loop readline(f,l);hread(l,words(i));end loop;
    assert endfile(f) report "Extra image words" severity failure;
    return words;
  end;
  constant INPUTS:words_t:=load("input.hex",3*G_TOKENS*C_WIDTH);
  constant EXP_TABLE:words_t:=load("exp.hex",4097);
  constant EXPECTED:words_t:=load("expected.hex",G_TOKENS*C_WIDTH);
  signal clk:std_logic:='0';signal rst:std_logic:='1';
  signal cv,cr,dv,mv,mr:std_logic:='0';signal command:attention_cmd_t:=C_ATTENTION_CMD_IDLE;
  signal status:status_t;signal beat:state_beat_t;
  signal qv,qr,pv,pr,rv,rr,sv,sr:std_logic:='0';
  signal q:mem_req_t;signal p:param_req_t;signal r:mem_rsp_t:=C_MEM_RSP_IDLE;signal s:param_rsp_t:=C_PARAM_RSP_IDLE;
  signal cycle:natural:=0;
begin
  clk<=not clk after 5 ns;
  process begin wait for 100 ms;assert false report "Attention timeout" severity failure;end process;
  dut:entity work.eat_streaming_attention_engine(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr,cmd_i=>command,
    done_valid_o=>dv,done_ready_i=>'0',status_o=>status,m_valid_o=>mv,m_ready_i=>mr,m_data_o=>beat,
    mem_req_valid_o=>qv,mem_req_ready_i=>qr,mem_req_o=>q,mem_rsp_valid_i=>rv,mem_rsp_ready_o=>rr,mem_rsp_i=>r,
    param_req_valid_o=>pv,param_req_ready_i=>pr,param_req_o=>p,param_rsp_valid_i=>sv,param_rsp_ready_o=>sr,param_rsp_i=>s);
  qr<='1' when cycle mod 7<4 else '0';
  pr<='1' when cycle mod 11<7 else '0';
  mr<='1' when cycle mod 17<11 else '0';
  process(clk)
    variable mem_delay,param_delay:natural:=0;
    variable mem_pending,param_pending:boolean:=false;
    variable old_q:mem_req_t;variable old_p:param_req_t;
    variable old_beat:state_beat_t;
    variable q_stalled,p_stalled,m_stalled:boolean:=false;
  begin
    if rising_edge(clk) then
      cycle<=cycle+1;
      if rst='1' then rv<='0';sv<='0';mem_pending:=false;param_pending:=false;
      else
        if q_stalled then assert qv='1' and q=old_q report "Memory request changed under stall" severity failure;end if;
        if p_stalled then assert pv='1' and p=old_p report "Parameter request changed under stall" severity failure;end if;
        if m_stalled then assert mv='1' and beat=old_beat report "Attention output changed under stall" severity failure;end if;
        q_stalled:=qv='1' and qr='0';old_q:=q;p_stalled:=pv='1' and pr='0';old_p:=p;m_stalled:=mv='1' and mr='0';old_beat:=beat;
        if rv='1' and rr='1' then rv<='0';end if;
        if sv='1' and sr='1' then sv<='0';end if;
        if qv='1' and qr='1' then
          assert not mem_pending and rv='0' and q.write_enable='0' and to_integer(q.address)<INPUTS'length report "Invalid memory request" severity failure;
          r<=(INPUTS(to_integer(q.address)),q.tag,'0');mem_pending:=true;mem_delay:=cycle mod 5+1;
        end if;
        if pv='1' and pr='1' then
          assert not param_pending and sv='0' and p.bank=2 report "Invalid parameter request" severity failure;
          assert p.kind=CONST_EXP and to_integer(p.address)<EXP_TABLE'length report "Invalid exponential request" severity failure;
          s.data<=EXP_TABLE(to_integer(p.address));
          s.tag<=p.tag;s.error<='0';param_pending:=true;param_delay:=cycle mod 4+1;
        end if;
        if mem_pending then
          if mem_delay=0 then rv<='1';mem_pending:=false;else mem_delay:=mem_delay-1;end if;
        end if;
        if param_pending then
          if param_delay=0 then sv<='1';param_pending:=false;else param_delay:=param_delay-1;end if;
        end if;
      end if;
    end if;
  end process;
  process
    type seen_t is array(0 to G_TOKENS*C_WIDTH-1) of boolean;
    variable seen:seen_t:=(others=>false);
    variable index,count:natural:=0;
  begin
    wait until rising_edge(clk);wait until rising_edge(clk);wait for 1 ns;rst<='0';
    command.tokens<=G_TOKENS;command.q_shift<=to_signed(G_Q_SHIFT,8);command.k_shift<=to_signed(G_K_SHIFT,8);command.v_shift<=to_signed(G_V_SHIFT,8);
    command.q_addr<=to_unsigned(0,C_MEM_ADDR_BITS);command.k_addr<=to_unsigned(G_TOKENS*C_WIDTH,C_MEM_ADDR_BITS);command.v_addr<=to_unsigned(2*G_TOKENS*C_WIDTH,C_MEM_ADDR_BITS);
    command.ctx.model_bank<=to_unsigned(2,4);
    command.ctx.inference_id<=to_unsigned(4250,32);cv<='1';
    loop wait until rising_edge(clk);exit when cr='1';end loop;wait for 1 ns;cv<='0';
    loop
      wait until rising_edge(clk);
      if mv='1' and mr='1' then
        assert beat.ctx=command.ctx and beat.token<G_TOKENS and beat.feature_base<C_WIDTH report "Bad attention metadata" severity failure;
        assert beat.last=std_logic'val(boolean'pos(beat.token=G_TOKENS-1 and beat.feature_base+8>=C_WIDTH)+2) report "Bad last" severity failure;
        for lane in 0 to 7 loop
          if beat.feature_base+lane<C_WIDTH then
            assert beat.keep(lane)='1' severity failure;
            index:=beat.token*C_WIDTH+beat.feature_base+lane;
            assert not seen(index) report "Duplicate output" severity failure;
            assert resize(beat.data(lane),64)=signed(EXPECTED(index)) report "Attention integer mismatch at "&integer'image(index)&" got="&integer'image(to_integer(beat.data(lane)))&" expected="&integer'image(to_integer(signed(EXPECTED(index)))) severity failure;
            seen(index):=true;count:=count+1;
          else assert beat.keep(lane)='0' severity failure;end if;
        end loop;
      end if;
      if dv='1' then
        assert status.done='1' and status.error='0' and status.busy='0' report "Attention failed" severity failure;
        assert count=EXPECTED'length report "Missing attention outputs" severity failure;
        report "ATTENTION_PASS cycles="&integer'image(cycle)&" values="&integer'image(count) severity note;stop;wait;
      end if;
    end loop;
  end process;
end architecture;
