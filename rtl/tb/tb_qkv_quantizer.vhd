library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;use ieee.std_logic_textio.all;use std.textio.all;use std.env.all;
use work.eat_config_pkg.all;use work.eat_types_pkg.all;
entity tb_qkv_quantizer is generic(G_Q_SHIFT:natural:=8;G_K_SHIFT:natural:=8;G_V_SHIFT:natural:=8;G_PATH:string:="./");end;
architecture test of tb_qkv_quantizer is
 type words_t is array(natural range <>) of std_logic_vector(63 downto 0);
 impure function load(name:string;count:positive) return words_t is
  file f:text open read_mode is G_PATH&name;variable l:line;variable a:words_t(0 to count-1);
 begin for i in a'range loop readline(f,l);hread(l,a(i));end loop;assert endfile(f) severity failure;return a;end;
 constant INPUTS:words_t:=load("input.hex",32*384);constant EXPECTED:words_t:=load("expected.hex",3*32*128);
 type beats_t is array(0 to 2) of act_beat_t;
 signal clk:std_logic:='0';signal rst:std_logic:='1';signal cycle:natural:=0;
 signal cv,cr,dv,sv,sr:std_logic:='0';signal command:attention_cmd_t:=C_ATTENTION_CMD_IDLE;
 signal data:state_beat_t:=C_STATE_BEAT_IDLE;signal status:status_t;
 signal ov,orr:std_logic_vector(0 to 2):=(others=>'0');signal outputs:beats_t;
begin
 clk<=not clk after 5 ns;g:for i in 0 to 2 generate orr(i)<='1' when (cycle+i*5) mod 17<7 else '0';end generate;
 process begin wait for 5 ms;assert false report "QKV timeout" severity failure;end process;
 dut:entity work.eat_qkv_quantizer(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr,cmd_i=>command,done_valid_o=>dv,done_ready_i=>'0',status_o=>status,
  s_valid_i=>sv,s_ready_o=>sr,s_data_i=>data,q_valid_o=>ov(0),q_ready_i=>orr(0),q_data_o=>outputs(0),k_valid_o=>ov(1),k_ready_i=>orr(1),k_data_o=>outputs(1),v_valid_o=>ov(2),v_ready_i=>orr(2),v_data_o=>outputs(2));
 process
  variable beat:state_beat_t;variable token,base:natural;
 begin
  wait until rising_edge(clk);wait until rising_edge(clk);wait for 1 ns;rst<='0';
  command.tokens<=32;command.q_shift<=to_signed(G_Q_SHIFT,8);command.k_shift<=to_signed(G_K_SHIFT,8);command.v_shift<=to_signed(G_V_SHIFT,8);command.ctx.inference_id<=to_unsigned(4250,32);cv<='1';
  wait until rising_edge(clk);assert cr='1' severity failure;wait for 1 ns;cv<='0';
  -- Same tile-major order emitted by the 8x8 tensor engine.
  for tile_row in 0 to 3 loop
   for tile_col in 0 to 47 loop
    for row_lane in 0 to 7 loop
     token:=tile_row*8+row_lane;base:=tile_col*8;beat:=C_STATE_BEAT_IDLE;beat.ctx:=command.ctx;beat.token:=token;beat.feature_base:=base;beat.keep:=x"ff";
     if token=31 and base=376 then beat.last:='1';end if;
     for i in 0 to 7 loop beat.data(i):=resize(signed(INPUTS(token*384+base+i)),24);end loop;
     data<=beat;sv<='1';loop wait until rising_edge(clk);exit when sr='1';end loop;wait for 1 ns;sv<='0';
    end loop;
   end loop;
  end loop;
  wait;
 end process;
 process(clk)
  type seen_t is array(0 to 3*32*128-1) of boolean;
  variable seen:seen_t:=(others=>false);variable count,index:natural:=0;
  variable previous:beats_t;variable stalled:std_logic_vector(0 to 2):=(others=>'0');variable expected_last:std_logic;
 begin
  if rising_edge(clk) then
   cycle<=cycle+1;
   if rst='0' then
    for stream in 0 to 2 loop
     if stalled(stream)='1' then assert ov(stream)='1' and outputs(stream)=previous(stream) report "QKV changed stalled output" severity failure;end if;
     stalled(stream):=ov(stream) and not orr(stream);previous(stream):=outputs(stream);
     if ov(stream)='1' and orr(stream)='1' then
      assert outputs(stream).ctx=command.ctx and outputs(stream).token<32 and outputs(stream).feature_base<128 and outputs(stream).feature_base mod 8=0 and outputs(stream).keep=x"ff" severity failure;
      expected_last:='0';if outputs(stream).token=31 and outputs(stream).feature_base=120 then expected_last:='1';end if;
      assert outputs(stream).last=expected_last severity failure;
      for lane in 0 to 7 loop
       index:=stream*32*128+outputs(stream).token*128+outputs(stream).feature_base+lane;
       assert not seen(index) and resize(outputs(stream).data(lane),64)=signed(EXPECTED(index)) report "QKV numeric/duplicate error" severity failure;
       seen(index):=true;count:=count+1;
      end loop;
     end if;
    end loop;
    if dv='1' then assert status.error='0' and count=EXPECTED'length report "QKV completion" severity failure;report "QKV_PASS values="&integer'image(count) severity note;stop;end if;
   end if;
  end if;
 end process;
end;
