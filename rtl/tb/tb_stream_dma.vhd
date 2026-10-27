library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;use std.env.all;
use work.eat_config_pkg.all;use work.eat_types_pkg.all;use work.eat_math_pkg.all;
entity tb_stream_dma is end;
architecture test of tb_stream_dma is
 signal clk:std_logic:='0';signal rst:std_logic:='1';signal cycle:natural:=0;
 signal cv,cr,dv,dr,active,clear,abort_transfer,transfer_ready,busy,frame_error:std_logic:='0';signal command,active_command:transfer_cmd_t:=C_TRANSFER_CMD_IDLE;signal status:status_t;
 signal axis_data:std_logic_vector(127 downto 0):=(others=>'0');signal axis_keep:std_logic_vector(15 downto 0):=(others=>'0');signal axis_last,axis_valid,axis_ready:std_logic:='0';
 signal raw_valid,raw_ready,raw_last,const_valid,const_ready,const_last:std_logic;
 signal raw_data,const_data:std_logic_vector(63 downto 0);signal raw_keep,const_keep:std_logic_vector(7 downto 0);signal offset:unsigned(31 downto 0);
 signal accepted:unsigned(15 downto 0);signal accepted_last:std_logic;
 signal observed_bytes,frames:natural:=0;
begin
 clk<=not clk after 5 ns;raw_ready<='1' when cycle mod 11<4 else '0';const_ready<='1' when cycle mod 13<5 else '0';
 process begin wait for 10 ms;assert false report "Stream timeout" severity failure;end process;
 dma:entity work.eat_dma_descriptor_engine(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr,cmd_i=>command,done_valid_o=>dv,done_ready_i=>dr,status_o=>status,
  stream_bytes_accepted_i=>accepted,stream_last_i=>accepted_last,frame_error_i=>frame_error,active_transfer_o=>active_command,active_valid_o=>active);
 ingress:entity work.eat_axi_stream_input(rtl) port map(clk_i=>clk,rst_i=>rst,s_axis_tdata_i=>axis_data,s_axis_tkeep_i=>axis_keep,s_axis_tlast_i=>axis_last,s_axis_tvalid_i=>axis_valid,s_axis_tready_o=>axis_ready,
  transfer_i=>active_command,transfer_valid_i=>active,transfer_ready_o=>transfer_ready,clear_i=>clear,abort_i=>abort_transfer,busy_o=>busy,
  raw_valid_o=>raw_valid,raw_ready_i=>raw_ready,raw_data_o=>raw_data,raw_keep_o=>raw_keep,raw_last_o=>raw_last,raw_byte_offset_o=>offset,
  constant_valid_o=>const_valid,constant_ready_i=>const_ready,constant_data_o=>const_data,constant_keep_o=>const_keep,constant_last_o=>const_last,frame_error_o=>frame_error);
 process(all)
  variable count:natural;
 begin
  count:=0;accepted_last<='0';
  if raw_valid='1' and raw_ready='1' then for i in 0 to 7 loop if raw_keep(i)='1' then count:=count+1;end if;end loop;accepted_last<=raw_last;
  elsif const_valid='1' and const_ready='1' then for i in 0 to 7 loop if const_keep(i)='1' then count:=count+1;end if;end loop;accepted_last<=const_last;end if;
  accepted<=to_unsigned(count,16);
 end process;
 process(clk)
  variable raw_stalled,const_stalled:boolean:=false;
  variable previous_raw,previous_const:std_logic_vector(63 downto 0);variable previous_rk,previous_ck:std_logic_vector(7 downto 0);
  variable previous_rl,previous_cl:std_logic;variable previous_offset:unsigned(31 downto 0);
  variable data:std_logic_vector(63 downto 0);variable keep:std_logic_vector(7 downto 0);variable last:std_logic;variable count:natural;
 begin
  if rising_edge(clk) then
   cycle<=cycle+1;
   if rst='1' then raw_stalled:=false;const_stalled:=false;observed_bytes<=0;
   else
    if abort_transfer='1' then raw_stalled:=false;const_stalled:=false;end if;
    if raw_stalled then assert raw_valid='1' and raw_data=previous_raw and raw_keep=previous_rk and raw_last=previous_rl and offset=previous_offset report "Raw word changed under stall" severity failure;end if;
    if const_stalled then assert const_valid='1' and const_data=previous_const and const_keep=previous_ck and const_last=previous_cl report "Constant word changed under stall" severity failure;end if;
    raw_stalled:=raw_valid='1' and raw_ready='0';previous_raw:=raw_data;previous_rk:=raw_keep;previous_rl:=raw_last;previous_offset:=offset;
    const_stalled:=const_valid='1' and const_ready='0';previous_const:=const_data;previous_ck:=const_keep;previous_cl:=const_last;
    if cv='1' and cr='1' then observed_bytes<=0;frames<=frames+1;end if;
    if accepted/=0 then
     assert not(raw_valid='1' and const_valid='1') severity failure;
     if raw_valid='1' then assert active_command.kind=TRANSFER_INPUT and offset=observed_bytes severity failure;data:=raw_data;keep:=raw_keep;last:=raw_last;
     else assert active_command.kind=TRANSFER_CONSTANTS severity failure;data:=const_data;keep:=const_keep;last:=const_last;end if;
     count:=0;
     for i in 0 to 7 loop
      if keep(i)='1' then assert unsigned(data(8*i+7 downto 8*i))=((observed_bytes+count)*7+3) mod 256 report "Wrong packet byte order" severity failure;count:=count+1;end if;
     end loop;
     assert last=flag(observed_bytes+count=to_integer(active_command.bytes)) severity failure;observed_bytes<=observed_bytes+count;
    end if;
   end if;
  end if;
 end process;
 process
  procedure tick is begin wait until rising_edge(clk);wait for 1 ns;end;
  procedure begin_packet(bytes:natural;kind:transfer_kind_t) is
  begin
   assert transfer_ready='1' and cr='1' severity failure;
   command<=(kind,to_unsigned(bytes,32),(others=>'0'),CONST_WEIGHT,(to_unsigned(4255,32),MODE_QUALITY,WORKLOAD_HAR,(others=>'0')));cv<='1';tick;cv<='0';
  end;
  procedure beat(base,count:natural;last:std_logic;bad_keep:integer:=-1) is
   variable value:std_logic_vector(127 downto 0);variable keep:std_logic_vector(15 downto 0);
  begin
   value:=(others=>'1');keep:=(others=>'0');
   for i in 0 to 15 loop if i<count then value(8*i+7 downto 8*i):=std_logic_vector(to_unsigned(((base+i)*7+3) mod 256,8));keep(i):='1';end if;end loop;
   if bad_keep>=0 then keep:=std_logic_vector(to_unsigned(bad_keep,16));end if;
   axis_data<=value;axis_keep<=keep;axis_last<=last;axis_valid<='1';
   loop wait until rising_edge(clk);exit when axis_ready='1';end loop;wait for 1 ns;axis_valid<='0';
  end;
  procedure finish(error:std_logic;bytes:natural) is
  begin
   while dv/='1' loop tick;end loop;
   assert status.done='1' and status.error=error and status.ctx=command.ctx and observed_bytes=bytes report "DMA status/byte mismatch" severity failure;
   if error='1' then assert status.code=ERR_FRAME severity failure;else assert status.code=ERR_NONE severity failure;end if;
   while busy='1' loop tick;end loop;
   dr<='1';tick;dr<='0';clear<='1';tick;clear<='0';tick;
   assert frame_error='0' and raw_valid='0' and const_valid='0' severity failure;
  end;
  procedure good(bytes:natural;kind:transfer_kind_t) is variable base,count:natural;
  begin
   begin_packet(bytes,kind);base:=0;
   while base<bytes loop count:=minimum(16,bytes-base);beat(base,count,flag(base+count=bytes));base:=base+count;end loop;
   finish('0',bytes);
  end;
 begin
  tick;tick;rst<='0';tick;
  for kind in transfer_kind_t loop
   good(1,kind);good(7,kind);good(8,kind);good(9,kind);good(15,kind);good(16,kind);good(17,kind);good(24,kind);good(31,kind);good(32,kind);
  end loop;
  good(1152,TRANSFER_INPUT);good(2560,TRANSFER_INPUT);good(1312,TRANSFER_CONSTANTS);
  begin_packet(32,TRANSFER_INPUT);beat(0,16,'1');finish('1',0);
  begin_packet(16,TRANSFER_CONSTANTS);beat(0,16,'0');tick;clear<='1';tick;clear<='0';assert frame_error='1' and busy='1' severity failure;beat(16,16,'1');finish('1',0);
  begin_packet(16,TRANSFER_INPUT);beat(0,16,'1',16#f7ff#);finish('1',0);
  begin_packet(24,TRANSFER_CONSTANTS);beat(0,16,'0');beat(16,8,'1',15);finish('1',16);
  begin_packet(8,TRANSFER_INPUT);beat(0,8,'1',0);finish('1',0);
  begin_packet(32,TRANSFER_INPUT);beat(0,16,'0');abort_transfer<='1';tick;abort_transfer<='0';beat(16,16,'1');finish('1',0);
  begin_packet(0,TRANSFER_INPUT);finish('1',0);
  begin_packet(32,TRANSFER_INPUT);beat(0,16,'0');rst<='1';tick;axis_valid<='0';cv<='0';rst<='0';tick;
  assert raw_valid='0' and const_valid='0' and dv='0' and frame_error='0' severity failure;good(17,TRANSFER_CONSTANTS);
  report "AXIS_DMA_PASS frames="&integer'image(frames) severity note;stop;wait;
 end process;
end;
