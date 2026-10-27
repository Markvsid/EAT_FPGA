library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;use ieee.std_logic_textio.all;use std.textio.all;use std.env.all;
use work.eat_config_pkg.all;use work.eat_types_pkg.all;use work.eat_math_pkg.all;use work.eat_image_pkg.all;
entity tb_resident_images is generic(G_MODE:natural:=0;G_WORKLOAD:natural:=0;G_BANK:natural:=2;G_PATH:string:="./");end;
architecture test of tb_resident_images is
 type words_t is array(natural range <>) of std_logic_vector(63 downto 0);
 impure function load return words_t is
  file f:text open read_mode is G_PATH&"memory.hex";variable l:line;variable a:words_t(0 to C_IMAGE_BANK_WORDS-1);
 begin for i in a'range loop readline(f,l);hread(l,a(i));end loop;assert endfile(f) severity failure;return a;end;
 constant ROM:words_t:=load;
 function get_identity return identity_t is variable id:identity_t;
 begin for i in 0 to 7 loop id(32*i+31 downto 32*i):=ROM(region_offset(CONST_PROFILE)+32+i)(31 downto 0);end loop;return id;end;
 function get_profile return profile_t is variable p:profile_t;
 begin for i in p'range loop p(i):=signed(ROM(region_offset(CONST_PROFILE)+i));end loop;return p;end;
 constant ID:identity_t:=get_identity;constant PROFILE_IMAGE:profile_t:=get_profile;
 signal clk:std_logic:='0';signal rst:std_logic:='1';signal cycle:natural:=0;
 signal cv,cr,dv,dr,sv,sr,slast,av,ar:std_logic:='0';signal command:transfer_cmd_t:=C_TRANSFER_CMD_IDLE;signal status:status_t;
 signal data:std_logic_vector(63 downto 0):=(others=>'0');signal keep:std_logic_vector(7 downto 0):=x"ff";
 signal identity,arm_identity,loaded_identity:identity_t:=ID;signal valid_banks:std_logic_vector(C_MODEL_BANKS-1 downto 0);
 signal wqv,wqr,wrv,wrr,rqv,rqr,rrv,rrr,pv,pr,rv,rr:std_logic:='0';
 signal wq,rq:mem_req_t;signal wr,rsp:mem_rsp_t:=C_MEM_RSP_IDLE;signal p:param_req_t:=C_PARAM_REQ_IDLE;signal r:param_rsp_t;
 signal client_valid,client_ready,client_rvalid,client_rready:std_logic_vector(1 downto 0);
 signal client_requests:mem_req_array_t(0 to 1);signal client_responses:mem_rsp_array_t(0 to 1);
 signal mqv,mqr,mrv,mrr:std_logic;signal mq:mem_req_t;signal mr:mem_rsp_t;
 signal writes:natural:=0;signal allow_bad_data:std_logic:='0';
begin
 clk<=not clk after 5 ns;
 process begin wait for 100 ms;assert false report "Loader timeout" severity failure;end process;
 loader:entity work.eat_constant_loader(rtl) port map(clk_i=>clk,rst_i=>rst,cmd_valid_i=>cv,cmd_ready_o=>cr,cmd_i=>command,done_valid_o=>dv,done_ready_i=>dr,status_o=>status,
  s_valid_i=>sv,s_ready_o=>sr,s_data_i=>data,s_keep_i=>keep,s_last_i=>slast,identity_i=>identity,arm_valid_i=>av,arm_ready_o=>ar,
  arm_bank_i=>to_unsigned(G_BANK,4),arm_identity_i=>arm_identity,identity_bank_i=>to_unsigned(G_BANK,4),loaded_identity_o=>loaded_identity,bank_valid_o=>valid_banks,
  mem_req_valid_o=>wqv,mem_req_ready_i=>wqr,mem_req_o=>wq,mem_rsp_valid_i=>wrv,mem_rsp_ready_o=>wrr,mem_rsp_i=>wr);
 store:entity work.eat_parameter_store(rtl) port map(clk_i=>clk,rst_i=>rst,req_valid_i=>pv,req_ready_o=>pr,req_i=>p,rsp_valid_o=>rv,rsp_ready_i=>rr,rsp_o=>r,
  mem_req_valid_o=>rqv,mem_req_ready_i=>rqr,mem_req_o=>rq,mem_rsp_valid_i=>rrv,mem_rsp_ready_o=>rrr,mem_rsp_i=>rsp);
 client_valid<=rqv&wqv;client_requests(0)<=wq;client_requests(1)<=rq;
 wqr<=client_ready(0);rqr<=client_ready(1);wrv<=client_rvalid(0);rrv<=client_rvalid(1);wr<=client_responses(0);rsp<=client_responses(1);client_rready<=rrr&wrr;
 arb:entity work.eat_memory_arbiter(rtl) generic map(G_CLIENTS=>2) port map(clk_i=>clk,rst_i=>rst,client_valid_i=>client_valid,client_ready_o=>client_ready,client_req_i=>client_requests,
  client_rsp_valid_o=>client_rvalid,client_rsp_ready_i=>client_rready,client_rsp_o=>client_responses,mem_req_valid_o=>mqv,mem_req_ready_i=>mqr,mem_req_o=>mq,mem_rsp_valid_i=>mrv,mem_rsp_ready_o=>mrr,mem_rsp_i=>mr);
 memory:entity work.eat_model_memory(rtl) port map(clk_i=>clk,rst_i=>rst,req_valid_i=>mqv,req_ready_o=>mqr,req_i=>mq,rsp_valid_o=>mrv,rsp_ready_i=>mrr,rsp_o=>mr);
 process(clk)
  variable address:natural;
 begin
  if rising_edge(clk) then
   cycle<=cycle+1;
   if rst='0' and wqv='1' and wqr='1' then
    address:=to_integer(wq.address);assert address/C_IMAGE_BANK_WORDS=G_BANK severity failure;address:=address mod C_IMAGE_BANK_WORDS;
    if allow_bad_data='0' then assert wq.write_data=ROM(address) report "Packed resident load source mismatch" severity failure;end if;writes<=writes+1;
   end if;
  end if;
 end process;
 process
  procedure tick is begin wait until rising_edge(clk);wait for 1 ns;end;
  procedure ack(expected:error_t) is
  begin
   while dv/='1' loop tick;end loop;
   assert status.done='1' and status.code=expected and status.error=flag(expected/=ERR_NONE) report "Load status mismatch expected "&error_t'image(expected)&" got "&error_t'image(status.code) severity failure;
   dr<='1';tick;dr<='0';
  end;
  procedure packet(kind:constant_kind_t;offset,count:natural;expected:error_t:=ERR_NONE;corrupt:integer:=-1;bad_value:std_logic_vector(63 downto 0):=(others=>'0')) is
  begin
   command<=(TRANSFER_CONSTANTS,to_unsigned(count*8,32),to_unsigned(offset,C_MEM_ADDR_BITS),kind,(to_unsigned(0,32),mode_t'val(G_MODE),workload_t'val(G_WORKLOAD),to_unsigned(G_BANK,4)));cv<='1';
   loop wait until rising_edge(clk);exit when cr='1';end loop;wait for 1 ns;cv<='0';
   if expected=ERR_NONE or corrupt>=0 then
    for i in 0 to count-1 loop
     if i=corrupt then data<=bad_value;else data<=ROM(region_offset(kind)+offset+i);end if;
     keep<=x"ff";slast<=flag(i+1=count);sv<='1';
     loop wait until rising_edge(clk);exit when sr='1' or dv='1';end loop;wait for 1 ns;sv<='0';
     exit when dv='1';
    end loop;
   end if;
   ack(expected);
  end;
  procedure arm(expected:error_t) is
  begin
   av<='1';loop wait until rising_edge(clk);exit when ar='1';end loop;wait for 1 ns;av<='0';ack(expected);
  end;
  procedure read_parameter(kind:constant_kind_t;offset:natural;bank:natural:=G_BANK;error:std_logic:='0') is
    variable expected:param_rsp_t;
  begin
   p<=(kind,to_unsigned(offset,C_MEM_ADDR_BITS),to_unsigned(bank,4),to_unsigned(4321,16));pv<='1';rr<='0';
   loop wait until rising_edge(clk);exit when pr='1';end loop;wait for 1 ns;pv<='0';
   while rv/='1' loop tick;end loop;
   expected:=((others=>'0'),to_unsigned(4321,16),error);if error='0' then expected.data:=ROM(region_offset(kind)+offset);end if;
   for i in 0 to 2 loop assert rv='1' and r=expected report "Parameter value/tag/range mismatch" severity failure;tick;end loop;
   rr<='1';tick;rr<='0';
  end;
  variable count,total:natural:=0;variable corrupt_profile:profile_t;
 begin
  assert valid_profile(PROFILE_IMAGE,ID) report "Exported profile rejected" severity failure;
  corrupt_profile:=PROFILE_IMAGE;corrupt_profile(0):=to_signed(0,64);assert not valid_profile(corrupt_profile,ID) severity failure;
  corrupt_profile:=PROFILE_IMAGE;corrupt_profile(64):=to_signed(C_IMAGE_BANK_WORDS,64);assert not valid_profile(corrupt_profile,ID) severity failure;
  corrupt_profile:=PROFILE_IMAGE;corrupt_profile(32):=corrupt_profile(32) xor to_signed(1,64);assert not valid_profile(corrupt_profile,ID) severity failure;
  tick;tick;rst<='0';tick;
  packet(CONST_WEIGHT,0,1,ERR_IDENTITY);arm(ERR_IDENTITY);
  packet(CONST_PROFILE,0,C_IMAGE_PROFILE_WORDS);arm(ERR_IDENTITY);
  for kind in constant_kind_t loop
   if kind/=CONST_PROFILE then count:=number(PROFILE_IMAGE,16+constant_kind_t'pos(kind));
    if count>0 then packet(kind,0,count);end if;total:=total+count;
   end if;
  end loop;
  arm(ERR_NONE);assert valid_banks(G_BANK)='1' and loaded_identity=ID severity failure;
  assert writes=total+C_IMAGE_PROFILE_WORDS report "Missing/extra image writes" severity failure;
  for kind in constant_kind_t loop
   count:=C_IMAGE_PROFILE_WORDS;if kind/=CONST_PROFILE then count:=number(PROFILE_IMAGE,16+constant_kind_t'pos(kind));end if;
   for offset in 0 to count-1 loop if offset mod 257=0 or offset+1=count then read_parameter(kind,offset);end if;end loop;
   read_parameter(kind,region_words(kind),G_BANK,'1');read_parameter(kind,0,15,'1');read_parameter(kind,0,7,'1');
   if count<region_words(kind) then read_parameter(kind,count,G_BANK,'1');end if;
  end loop;
  rst<='1';tick;rst<='0';tick;assert valid_banks=(valid_banks'range=>'0') severity failure;arm(ERR_IDENTITY);
  packet(CONST_PROFILE,0,C_IMAGE_PROFILE_WORDS);packet(CONST_GAMMA,0,1,ERR_LOAD_RANGE,0,x"0000010000000000");arm(ERR_IDENTITY);
  allow_bad_data<='1';packet(CONST_PROFILE,0,C_IMAGE_PROFILE_WORDS,ERR_PROTOCOL,0,x"0000000000000000");arm(ERR_IDENTITY);
  report "RESIDENT_IMAGES_PASS writes="&integer'image(writes)&" payload_words="&integer'image(total) severity note;stop;wait;
 end process;
end;
