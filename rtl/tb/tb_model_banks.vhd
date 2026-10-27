library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;use std.env.all;
use work.eat_config_pkg.all;use work.eat_types_pkg.all;use work.eat_image_pkg.all;
entity tb_model_banks is end;
architecture test of tb_model_banks is
 signal clk:std_logic:='0';signal rst:std_logic:='1';
 signal qv,qr,rv,rr:std_logic:='0';signal q:mem_req_t:=C_MEM_REQ_IDLE;signal r:mem_rsp_t;
begin
 clk<=not clk after 5 ns;
 dut:entity work.eat_model_memory(rtl) generic map(G_BANKS=>3,G_WORDS_PER_BANK=>256)
 port map(clk_i=>clk,rst_i=>rst,req_valid_i=>qv,req_ready_o=>qr,req_i=>q,rsp_valid_o=>rv,rsp_ready_i=>rr,rsp_o=>r);
 process
  variable transactions:natural:=0;
  procedure tick is begin wait until rising_edge(clk);wait for 1 ns;end;
  procedure access_word(bank:natural;kind:constant_kind_t;offset:natural;wr:boolean;value:std_logic_vector(63 downto 0);strobe:std_logic_vector(7 downto 0):=x"ff";bad:boolean:=false) is
   variable held:mem_rsp_t;
  begin
   q<=C_MEM_REQ_IDLE;q.address<=to_unsigned(bank*C_IMAGE_BANK_WORDS+region_offset(kind)+offset,C_MEM_ADDR_BITS);
   if wr then q.write_enable<='1';end if;
   q.write_data<=value;q.write_strobe<=strobe;qv<='1';
   loop wait until rising_edge(clk);exit when qr='1';end loop;wait for 1 ns;qv<='0';
   while rv/='1' loop tick;end loop;
   if bad then assert r.error='1' report "Expected model RAM bounds/type error" severity failure;
   else assert r.error='0' report "Unexpected model RAM error" severity failure;
    if not wr then assert r.data=value report "Bank alias or byte write mismatch" severity failure;end if;
   end if;
   held:=r;for i in 1 to 3 loop tick;assert rv='1' and r=held report "Response changed under stall" severity failure;end loop;
   rr<='1';tick;rr<='0';transactions:=transactions+1;
  end;
 begin
  tick;tick;rst<='0';tick;
  for bank in 0 to 2 loop
   access_word(bank,CONST_PROFILE,0,true,x"0000000045415432");
   access_word(bank,CONST_PROFILE,16,true,x"0000000000000002");
   access_word(bank,CONST_PROFILE,17,true,x"0000000000000001");
   access_word(bank,CONST_WEIGHT,0,true,std_logic_vector(to_unsigned(100+bank,64)));
   access_word(bank,CONST_WEIGHT,1,true,x"1122334455667788");
   access_word(bank,CONST_BIAS,0,true,std_logic_vector(to_unsigned(200+bank,64)));
  end loop;
  for bank in 0 to 2 loop
   access_word(bank,CONST_WEIGHT,0,false,std_logic_vector(to_unsigned(100+bank,64)));
   access_word(bank,CONST_WEIGHT,1,true,x"00000000000000aa",x"01");
   access_word(bank,CONST_WEIGHT,1,false,x"11223344556677aa");
   access_word(bank,CONST_BIAS,0,false,std_logic_vector(to_unsigned(200+bank,64)));
  end loop;
  access_word(0,CONST_WEIGHT,2,false,x"0000000000000000",bad=>true);
  access_word(3,CONST_PROFILE,0,false,x"0000000000000000",bad=>true);
  access_word(0,CONST_PROFILE,164,false,x"0000000000000000",bad=>true);
  access_word(0,CONST_PROFILE,18,true,x"0000000000000064",bad=>true);
  access_word(0,CONST_PROFILE,16,true,x"000000000001ffff",bad=>true);
  access_word(0,CONST_PROFILE,16,true,x"0000000000000002",x"01",true);
  access_word(0,CONST_BIAS,0,true,x"0000000000000001",x"01",true);
  -- Rejected count updates must preserve both bank mapping and prior payload.
  access_word(0,CONST_BIAS,0,false,x"00000000000000c8");
  access_word(0,CONST_PROFILE,0,true,x"0000000045415432");
  access_word(0,CONST_WEIGHT,0,false,x"0000000000000000",bad=>true);
  access_word(1,CONST_WEIGHT,0,false,x"0000000000000065");
  rst<='1';tick;rst<='0';tick;
  access_word(1,CONST_WEIGHT,0,false,x"0000000000000000",bad=>true);
  report "MODEL_BANKS_PASS transactions="&natural'image(transactions);stop;
 end process;
 process begin wait for 1 ms;assert false report "Model bank regression timeout" severity failure;end process;
end;
