library ieee;
use ieee.std_logic_1164.all;use ieee.numeric_std.all;use ieee.std_logic_textio.all;
use std.textio.all;use std.env.all;use work.eat_config_pkg.all;use work.eat_types_pkg.all;
entity tb_vector_units is
  generic(G_ROWS:positive:=32;G_FEATURES:positive:=128;G_PARAM_COUNT:positive:=128;G_OUTPUT_ROWS:positive:=G_ROWS;G_OPERATION:string:="rmsnorm";G_PATH:string:="./");
end;
architecture test of tb_vector_units is
  type words_t is array(natural range <>) of std_logic_vector(63 downto 0);
  impure function load(name:string;count:positive) return words_t is
    file f:text open read_mode is G_PATH&name;variable l:line;variable a:words_t(0 to count-1);
  begin for i in a'range loop readline(f,l);hread(l,a(i));end loop;assert endfile(f) severity failure;return a;end;
  constant INPUTS:words_t:=load("input.hex",G_ROWS*G_FEATURES);
  constant SECOND:words_t:=load("second.hex",G_ROWS*G_FEATURES);
  constant EXPECTED:words_t:=load("expected.hex",G_OUTPUT_ROWS*G_FEATURES);
  constant PARAMS:words_t:=load("param.hex",G_PARAM_COUNT);
  constant RSQRT:words_t:=load("rsqrt.hex",1024);
  signal clk:std_logic:='0';signal rst:std_logic:='1';signal cycle:natural:=0;
  signal cv,cr,dv,sv,sr,mv,mr,pv,pr,rv,rr:std_logic:='0';
  signal command:vector_cmd_t:=C_VECTOR_CMD_IDLE;signal status:status_t;
  signal input_beat,output_beat:state_beat_t:=C_STATE_BEAT_IDLE;
  signal bv,br:std_logic:='0';signal second_beat:state_beat_t:=C_STATE_BEAT_IDLE;
  signal p:param_req_t;signal r:param_rsp_t:=C_PARAM_RSP_IDLE;
begin
  clk<=not clk after 5 ns;
  process begin wait for 30 ms;assert false report "Vector timeout" severity failure;end process;
  pr<='1' when cycle mod 7<4 else '0';mr<='1' when cycle mod 17<9 else '0';
  g_rmsnorm:if G_OPERATION="rmsnorm" generate
    dut:entity work.eat_rmsnorm(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr,cmd_i=>command,
      done_valid_o=>dv,done_ready_i=>'0',status_o=>status,s_valid_i=>sv,s_ready_o=>sr,s_data_i=>input_beat,
      m_valid_o=>mv,m_ready_i=>mr,m_data_o=>output_beat,param_req_valid_o=>pv,param_req_ready_i=>pr,param_req_o=>p,
      param_rsp_valid_i=>rv,param_rsp_ready_o=>rr,param_rsp_i=>r,mem_req_valid_o=>open,mem_req_ready_i=>'0',mem_req_o=>open,mem_rsp_valid_i=>'0',mem_rsp_ready_o=>open,mem_rsp_i=>C_MEM_RSP_IDLE);
  end generate;
  g_pwl:if G_OPERATION="pwl" generate
    dut:entity work.eat_pwl_silu(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr,cmd_i=>command,
      done_valid_o=>dv,done_ready_i=>'0',status_o=>status,s_valid_i=>sv,s_ready_o=>sr,s_data_i=>input_beat,
      m_valid_o=>mv,m_ready_i=>mr,m_data_o=>output_beat,param_req_valid_o=>pv,param_req_ready_i=>pr,param_req_o=>p,
      param_rsp_valid_i=>rv,param_rsp_ready_o=>rr,param_rsp_i=>r);
  end generate;
  g_position:if G_OPERATION="position" generate
    dut:entity work.eat_position_add(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr,cmd_i=>command,
      done_valid_o=>dv,done_ready_i=>'0',status_o=>status,s_valid_i=>sv,s_ready_o=>sr,s_data_i=>input_beat,
      m_valid_o=>mv,m_ready_i=>mr,m_data_o=>output_beat,param_req_valid_o=>pv,param_req_ready_i=>pr,param_req_o=>p,
      param_rsp_valid_i=>rv,param_rsp_ready_o=>rr,param_rsp_i=>r);
  end generate;
  g_residual:if G_OPERATION="residual" generate
    pv<='0';p<=C_PARAM_REQ_IDLE;rr<='0';
    dut:entity work.eat_residual_add(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr,cmd_i=>command,
      done_valid_o=>dv,done_ready_i=>'0',status_o=>status,a_valid_i=>sv,a_ready_o=>sr,a_data_i=>input_beat,
      b_valid_i=>bv,b_ready_o=>br,b_data_i=>second_beat,m_valid_o=>mv,m_ready_i=>mr,m_data_o=>output_beat,saturation_events_o=>open);
  end generate;
  g_pool:if G_OPERATION="pool" generate
    pv<='0';p<=C_PARAM_REQ_IDLE;rr<='0';
    dut:entity work.eat_mean_pool(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr,cmd_i=>command,
      done_valid_o=>dv,done_ready_i=>'0',status_o=>status,s_valid_i=>sv,s_ready_o=>sr,s_data_i=>input_beat,
      m_valid_o=>mv,m_ready_i=>mr,m_data_o=>output_beat);
  end generate;
  g_second:if G_OPERATION="residual" generate
    process
      variable beat:state_beat_t;variable base:natural;
    begin
      wait until cv='1';wait until rising_edge(clk);wait for 1 ns;
      for row in 0 to G_ROWS-1 loop
        base:=0;
        while base<G_FEATURES loop
          beat:=C_STATE_BEAT_IDLE;beat.token:=row;beat.feature_base:=base;beat.ctx:=command.ctx;
          if row=G_ROWS-1 and base+8>=G_FEATURES then beat.last:='1';end if;
          for i in 0 to 7 loop if base+i<G_FEATURES then beat.keep(i):='1';beat.data(i):=resize(signed(SECOND(row*G_FEATURES+base+i)),24);end if;end loop;
          wait until rising_edge(clk);wait for 1 ns;
          second_beat<=beat;bv<='1';
          loop wait until rising_edge(clk);exit when br='1';end loop;wait for 1 ns;bv<='0';
          base:=base+8;
        end loop;
      end loop;
      wait;
    end process;
  end generate;
  process(clk)
    variable pending:boolean:=false;variable delay:natural:=0;
    variable old_p:param_req_t;variable old_output:state_beat_t;
    variable p_stall,m_stall:boolean:=false;
  begin
    if rising_edge(clk) then
      cycle<=cycle+1;
      if rst='1' then pending:=false;rv<='0';
      else
        if p_stall then assert pv='1' and p=old_p report "Vector request changed while stalled" severity failure;end if;
        if m_stall then assert mv='1' and output_beat=old_output report "Vector output changed while stalled" severity failure;end if;
        p_stall:=pv='1' and pr='0';old_p:=p;m_stall:=mv='1' and mr='0';old_output:=output_beat;
        if rv='1' and rr='1' then rv<='0';end if;
        if pv='1' and pr='1' then
          assert not pending and rv='0' and p.bank=1 report "Vector request overlap/bank" severity failure;
          if p.kind=CONST_RSQRT then assert to_integer(p.address)<1024 severity failure;r.data<=RSQRT(to_integer(p.address));
          else
            assert (G_OPERATION="rmsnorm" and p.kind=CONST_GAMMA) or
                   (G_OPERATION="position" and p.kind=CONST_POSITION) or (G_OPERATION="pwl" and p.kind=CONST_PWL) severity failure;
            assert to_integer(p.address)<PARAMS'length severity failure;r.data<=PARAMS(to_integer(p.address));
          end if;
          r.tag<=p.tag;r.error<='0';pending:=true;delay:=cycle mod 5+1;
        end if;
        if pending then
          if delay=0 then rv<='1';pending:=false;else delay:=delay-1;end if;
        end if;
      end if;
    end if;
  end process;
  process
    variable beat:state_beat_t;
    variable base:natural;
  begin
    wait until rising_edge(clk);wait until rising_edge(clk);wait for 1 ns;rst<='0';
    command.tokens<=G_ROWS;command.features<=G_FEATURES;command.ctx.model_bank<=to_unsigned(1,4);
    command.ctx.inference_id<=to_unsigned(4250,32);cv<='1';
    loop wait until rising_edge(clk);exit when cr='1';end loop;wait for 1 ns;cv<='0';
    for row in 0 to G_ROWS-1 loop
      base:=0;
      while base<G_FEATURES loop
        beat:=C_STATE_BEAT_IDLE;beat.token:=row;beat.feature_base:=base;beat.ctx:=command.ctx;
        if row=G_ROWS-1 and base+8>=G_FEATURES then beat.last:='1';end if;
        for i in 0 to 7 loop if base+i<G_FEATURES then beat.keep(i):='1';beat.data(i):=resize(signed(INPUTS(row*G_FEATURES+base+i)),24);end if;end loop;
        input_beat<=beat;sv<='1';
        loop wait until rising_edge(clk);exit when sr='1';end loop;wait for 1 ns;sv<='0';
        base:=base+8;
      end loop;
    end loop;
    wait;
  end process;
  process(clk)
    variable count,index:natural:=0;
    variable expected_last:std_logic;
  begin
    if rising_edge(clk) and rst='0' then
      if mv='1' and mr='1' then
        assert output_beat.ctx=command.ctx and output_beat.token=count/G_FEATURES and output_beat.feature_base=count mod G_FEATURES report "Vector metadata/order" severity failure;
        expected_last:='0';if count+8>=EXPECTED'length then expected_last:='1';end if;
        assert output_beat.last=expected_last severity failure;
        for i in 0 to 7 loop
          if output_beat.feature_base+i<G_FEATURES then
            assert output_beat.keep(i)='1' severity failure;index:=count;
            assert resize(output_beat.data(i),64)=signed(EXPECTED(index)) report "Vector mismatch "&integer'image(index)&" got="&integer'image(to_integer(output_beat.data(i)))&" expected="&integer'image(to_integer(signed(EXPECTED(index)))) severity failure;
            count:=count+1;
          else assert output_beat.keep(i)='0' severity failure;end if;
        end loop;
      end if;
      if dv='1' then
        assert status.done='1' and status.error='0' and count=EXPECTED'length report "Vector completion" severity failure;
        report "VECTOR_UNITS_PASS cycles="&integer'image(cycle)&" values="&integer'image(count) severity note;stop;
      end if;
    end if;
  end process;
end;
