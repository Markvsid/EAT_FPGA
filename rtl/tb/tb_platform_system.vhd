library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;use ieee.std_logic_textio.all;use std.textio.all;use std.env.all;
use work.eat_config_pkg.all;use work.eat_types_pkg.all;use work.eat_math_pkg.all;use work.eat_image_pkg.all;
entity tb_platform_system is generic(G_MODE:natural:=2;G_WORKLOAD:natural:=0;G_BANK:natural:=2;G_INPUT_WORDS:positive:=144;G_CLASSES:positive:=6;G_EXPECTED_MAC:natural:=1;G_EXPECTED_SAT:natural:=0;G_REPEAT:positive:=1;G_PATH:string:="./");end;
architecture test of tb_platform_system is
 type words_t is array(natural range <>) of std_logic_vector(63 downto 0);
 impure function load(name:string;count:positive) return words_t is
  file f:text open read_mode is G_PATH&name;variable l:line;variable a:words_t(0 to count-1);
 begin for i in a'range loop readline(f,l);hread(l,a(i));end loop;assert endfile(f) severity failure;return a;end;
 constant ROM:words_t:=load("memory.hex",C_IMAGE_BANK_WORDS);constant INPUTS:words_t:=load("input.hex",G_INPUT_WORDS);constant EXPECTED:words_t:=load("logits.hex",G_CLASSES);
 signal clk:std_logic:='0';signal arst_n:std_logic:='0';signal cycle:natural:=0;
 signal awaddr,araddr:std_logic_vector(15 downto 0):=(others=>'0');signal wdata,rdata:std_logic_vector(31 downto 0):=(others=>'0');signal wstrb:std_logic_vector(3 downto 0):=x"f";
 signal awv,awr,wv,wr,bv,br,arv,arr,rv,rr:std_logic:='0';signal bresp,rresp:std_logic_vector(1 downto 0);
 signal sd,md:std_logic_vector(127 downto 0):=(others=>'0');signal sk,mk:std_logic_vector(15 downto 0):=(others=>'0');signal sl,sv,sr,ml,mv,mr,irq:std_logic:='0';
 signal inference_active,begin_inference:std_logic:='0';signal observed_logits,observed_packets:natural:=0;
begin
 clk<=not clk after 5 ns;mr<='1' when cycle mod 29<11 else '0';
 process begin wait for 2 sec;assert false report "Top system timeout" severity failure;end process;
 dut:entity work.eat_platform_wrapper(rtl) port map(clk_i=>clk,arst_n_i=>arst_n,s_axi_awaddr_i=>awaddr,s_axi_awvalid_i=>awv,s_axi_awready_o=>awr,
  s_axi_wdata_i=>wdata,s_axi_wstrb_i=>wstrb,s_axi_wvalid_i=>wv,s_axi_wready_o=>wr,s_axi_bresp_o=>bresp,s_axi_bvalid_o=>bv,s_axi_bready_i=>br,
  s_axi_araddr_i=>araddr,s_axi_arvalid_i=>arv,s_axi_arready_o=>arr,s_axi_rdata_o=>rdata,s_axi_rresp_o=>rresp,s_axi_rvalid_o=>rv,s_axi_rready_i=>rr,
  s_axis_tdata_i=>sd,s_axis_tkeep_i=>sk,s_axis_tlast_i=>sl,s_axis_tvalid_i=>sv,s_axis_tready_o=>sr,
  m_axis_tdata_o=>md,m_axis_tkeep_o=>mk,m_axis_tlast_o=>ml,m_axis_tvalid_o=>mv,m_axis_tready_i=>mr,interrupt_o=>irq);
 process(clk)
  variable previous_data:std_logic_vector(127 downto 0);variable previous_keep:std_logic_vector(15 downto 0);variable previous_last:std_logic;variable stalled:boolean:=false;
  variable count,packets,valid_words:natural:=0;variable expected_keep:std_logic_vector(15 downto 0);
 begin
  if rising_edge(clk) then
   cycle<=cycle+1;
   if cycle mod 5000000=0 then report "PLATFORM_PROGRESS cycle="&integer'image(cycle) severity note;end if;
   if arst_n='0' then count:=0;packets:=0;observed_logits<=0;observed_packets<=0;stalled:=false;
   else
    if begin_inference='1' then count:=0;packets:=0;observed_logits<=0;observed_packets<=0;end if;
    if stalled then assert mv='1' and md=previous_data and mk=previous_keep and ml=previous_last report "Top changed stalled output" severity failure;end if;
    stalled:=mv='1' and mr='0';previous_data:=md;previous_keep:=mk;previous_last:=ml;
    if mv='1' then
     assert inference_active='1' report "Output before inference" severity failure;
     if mr='0' and ml='1' then assert irq='0' report "Completion before final output acceptance" severity failure;end if;
    end if;
    if mv='1' and mr='1' then
     expected_keep:=(others=>'0');valid_words:=minimum(4,G_CLASSES-count);
     for word in 0 to 3 loop
      if word<valid_words then
       expected_keep(4*word+3 downto 4*word):=x"f";
       assert resize(signed(md(32*word+31 downto 32*word)),64)=signed(EXPECTED(count+word)) report "Top logit mismatch class="&integer'image(count+word) severity failure;
      end if;
     end loop;
     assert mk=expected_keep and ml=flag(count+valid_words=G_CLASSES) report "Top output framing" severity failure;
     count:=count+valid_words;packets:=packets+1;observed_logits<=count;observed_packets<=packets;
    end if;
   end if;
  end if;
 end process;
 process
  procedure tick is begin wait until rising_edge(clk);wait for 1 ns;end;
  procedure write_reg(address:natural;value:std_logic_vector(31 downto 0);expected:std_logic_vector(1 downto 0):="00") is
  begin
   awaddr<=std_logic_vector(to_unsigned(address,16));wdata<=value;wstrb<=x"f";awv<='1';br<='0';
   loop wait until rising_edge(clk);exit when awr='1';end loop;wait for 1 ns;awv<='0';tick;wv<='1';
   loop wait until rising_edge(clk);exit when wr='1';end loop;wait for 1 ns;wv<='0';
   while bv/='1' loop tick;end loop;
   for i in 0 to 1 loop assert bv='1' and bresp=expected report "Top AXI write response address="&integer'image(address)&" got="&to_hstring(bresp) severity failure;tick;end loop;
   br<='1';tick;br<='0';
  end;
  procedure write_number(address,value:natural;expected:std_logic_vector(1 downto 0):="00") is
  begin write_reg(address,std_logic_vector(to_unsigned(value,32)),expected);end;
  procedure read_reg(address:natural;variable value:out std_logic_vector(31 downto 0)) is
  begin
   araddr<=std_logic_vector(to_unsigned(address,16));arv<='1';rr<='0';loop wait until rising_edge(clk);exit when arr='1';end loop;wait for 1 ns;arv<='0';
   while rv/='1' loop tick;end loop;value:=rdata;assert rresp="00" severity failure;tick;assert rv='1' and rdata=value severity failure;rr<='1';tick;rr<='0';
  end;
  procedure read_number(address,value:natural) is variable result:std_logic_vector(31 downto 0);
  begin read_reg(address,result);assert unsigned(result)=value report "Top read mismatch address="&integer'image(address)&" got="&to_hstring(result)&" expected="&integer'image(value) severity failure;end;
  procedure axis_beat(data:std_logic_vector(127 downto 0);keep:std_logic_vector(15 downto 0);last:std_logic) is
  begin
   sd<=data;sk<=keep;sl<=last;sv<='1';loop wait until rising_edge(clk);exit when sr='1';end loop;wait for 1 ns;sv<='0';
  end;
  procedure wait_command(expected_error:std_logic;expected_code:error_t:=ERR_NONE) is variable result:std_logic_vector(31 downto 0);
  begin
   while irq/='1' loop tick;end loop;
   loop read_reg(8,result);exit when result(0)='0';end loop;
   assert result(2)=expected_error report "Top command error flag status="&to_hstring(result) severity failure;
   read_number(12,error_t'pos(expected_code));
  end;
  procedure clear_done is begin write_number(0,4);tick;assert irq='0' report "IRQ did not clear" severity failure;end;
  procedure configure_transfer(kind:constant_kind_t;offset,count:natural;raw:boolean:=false) is
  begin
   clear_done;write_number(16#74#,boolean'pos(not raw));write_number(16#68#,constant_kind_t'pos(kind));write_number(16#60#,offset);write_number(16#64#,count*8);write_number(0,2);
  end;
  procedure load_region(kind:constant_kind_t;count:natural) is
   variable index:natural:=0;variable value:std_logic_vector(127 downto 0);variable keep:std_logic_vector(15 downto 0);
  begin
   configure_transfer(kind,0,count);
   while index<count loop
    value:=(others=>'0');value(63 downto 0):=ROM(region_offset(kind)+index);keep:=x"00ff";
    if index+1<count then value(127 downto 64):=ROM(region_offset(kind)+index+1);keep:=x"ffff";end if;
    axis_beat(value,keep,flag(index+2>=count));index:=index+2;
   end loop;
   wait_command('0');report "TOP_LOADED "&constant_kind_t'image(kind)&" words="&integer'image(count) severity note;
  end;
  variable result,old_cycle:std_logic_vector(31 downto 0);variable count:natural;variable value:std_logic_vector(127 downto 0);
 begin
  tick;tick;arst_n<='1';tick;tick;tick;
  read_number(16#14#,131072);read_number(16#18#,2);write_number(4,G_MODE);write_number(16#10#,16*G_BANK+G_WORKLOAD);
  for i in 0 to 7 loop write_reg(16#20#+i*4,ROM(region_offset(CONST_PROFILE)+32+i)(31 downto 0));end loop;
  write_number(16#1c#,4256);write_number(0,1,"10");assert irq='0' and mv='0' severity failure;
  configure_transfer(CONST_PROFILE,0,C_IMAGE_PROFILE_WORDS);value:=ROM(region_offset(CONST_PROFILE)+1)&ROM(region_offset(CONST_PROFILE));axis_beat(value,x"ffff",'1');wait_command('1',ERR_FRAME);clear_done;
  load_region(CONST_PROFILE,C_IMAGE_PROFILE_WORDS);configure_transfer(CONST_GAMMA,1,1);value:=(others=>'0');value(63 downto 0):=ROM(region_offset(CONST_GAMMA)+1);axis_beat(value,x"00ff",'1');wait_command('1',ERR_LOAD_RANGE);clear_done;
  load_region(CONST_PROFILE,C_IMAGE_PROFILE_WORDS);
  for kind in constant_kind_t loop
   if kind/=CONST_PROFILE then count:=to_integer(unsigned(ROM(region_offset(CONST_PROFILE)+16+constant_kind_t'pos(kind))));if count>0 then load_region(kind,count);end if;end if;
  end loop;
  clear_done;write_number(0,16);wait_command('0');read_reg(8,result);assert result(3)='1' severity failure;
  for i in 0 to 7 loop read_reg(16#40#+4*i,result);assert result=ROM(region_offset(CONST_PROFILE)+32+i)(31 downto 0) report "Resident identity mismatch" severity failure;end loop;
  clear_done;write_number(16#74#,0);write_number(16#60#,0);write_number(16#64#,G_INPUT_WORDS*8-8);write_number(0,2,"10");assert irq='0' severity failure;
  configure_transfer(CONST_WEIGHT,0,G_INPUT_WORDS,true);
  for pair in 0 to G_INPUT_WORDS/2-1 loop value:=INPUTS(pair*2+1)&INPUTS(pair*2);axis_beat(value,x"ffff",flag(pair+1=G_INPUT_WORDS/2));end loop;
  wait_command('0');clear_done;
  for run in 0 to G_REPEAT-1 loop
   write_number(16#1c#,4256+run);clear_done;begin_inference<='1';inference_active<='1';tick;begin_inference<='0';write_number(0,1);
   read_reg(8,result);assert result(0)='1' and result(2)='0' severity failure;
   if run>0 then read_number(16#70#,4255+run);read_reg(16#100#,result);assert result=old_cycle report "Completed snapshot changed during next inference" severity failure;end if;
   report "TOP_INFERENCE_START run="&integer'image(run) severity note;wait_command('0');
   assert observed_logits=G_CLASSES and observed_packets=(G_CLASSES+3)/4 report "Missing output words/packets" severity failure;inference_active<='0';
   read_number(16#70#,4256+run);read_reg(16#100#,old_cycle);assert unsigned(old_cycle)>0 severity failure;read_number(16#104#,0);
   read_number(16#108#,1);read_number(16#10c#,0);read_number(16#110#,G_EXPECTED_MAC);read_number(16#114#,0);read_number(16#130#,G_EXPECTED_SAT);
   for event_index in 3 to 5 loop
    read_reg(16#100#+8*event_index,result);assert unsigned(result)>0 and unsigned(result)<=unsigned(old_cycle) report "Missing diagnostic counter" severity failure;
    report "TOP_COUNTER event="&integer'image(event_index)&" count="&integer'image(to_integer(unsigned(result))) severity note;
   end loop;
   read_number(16#138#,G_INPUT_WORDS*8);read_number(16#140#,G_CLASSES*4);
   if G_MODE=0 then read_number(16#148#,32);read_number(16#150#,0);elsif G_MODE=1 then read_number(16#148#,24);read_number(16#150#,2);else read_number(16#148#,16);read_number(16#150#,4);end if;
   report "TOP_INFERENCE_PASS run="&integer'image(run)&" cycles="&integer'image(to_integer(unsigned(old_cycle))) severity note;
  end loop;
  clear_done;write_number(4,(G_MODE+1) mod 3);write_number(0,1,"10");assert mv='0' and irq='0' severity failure;
  arst_n<='0';tick;arst_n<='1';tick;tick;tick;tick;read_number(8,0);write_number(0,1,"10");assert irq='0' and mv='0' severity failure;
  report "PLATFORM_SYSTEM_PASS inferences="&integer'image(G_REPEAT)&" logits_per_inference="&integer'image(G_CLASSES) severity note;stop;wait;
 end process;
end;
