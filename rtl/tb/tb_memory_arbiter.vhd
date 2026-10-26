library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;use std.env.all;
use work.eat_config_pkg.all;use work.eat_types_pkg.all;
entity tb_memory_arbiter is end;
architecture test of tb_memory_arbiter is
 signal clk:std_logic:='0';signal rst:std_logic:='1';signal cycle:natural:=0;
 signal cv,cr,rv,rr:std_logic_vector(7 downto 0):=(others=>'0');
 signal cq:mem_req_array_t(0 to 7):=(others=>C_MEM_REQ_IDLE);signal cs:mem_rsp_array_t(0 to 7);
 signal qv,qr,sv,sr:std_logic:='0';signal q:mem_req_t;signal s:mem_rsp_t:=C_MEM_RSP_IDLE;
begin
 clk<=not clk after 5 ns;rst<='0' after 22 ns;cv<=(others=>'1');
 qr<='1' when cycle mod 7<3 else '0';
 g:for i in 0 to 7 generate
   cq(i).address<=to_unsigned(i,C_MEM_ADDR_BITS);cq(i).tag<=to_unsigned(i+100,16);
   rr(i)<='1' when (cycle+i) mod 13<4 else '0';
 end generate;
 dut:entity work.eat_memory_arbiter(rtl) port map(clk_i=>clk,rst_i=>rst,client_valid_i=>cv,client_ready_o=>cr,client_req_i=>cq,
  client_rsp_valid_o=>rv,client_rsp_ready_i=>rr,client_rsp_o=>cs,mem_req_valid_o=>qv,mem_req_ready_i=>qr,mem_req_o=>q,mem_rsp_valid_i=>sv,mem_rsp_ready_o=>sr,mem_rsp_i=>s);
 process(clk)
  type counts_t is array(0 to 7) of natural;
  variable requests,responses:counts_t:=(others=>0);
  variable pending:boolean:=false;variable delay:natural:=0;
  variable q_stall:boolean:=false;variable old_q:mem_req_t;
  variable stalled:std_logic_vector(7 downto 0):=(others=>'0');variable old_rs:mem_rsp_array_t(0 to 7);
  variable owner,total,ready_count:natural;
 begin
  if rising_edge(clk) then
   cycle<=cycle+1;
   assert cycle<5000 report "Arbiter starvation/timeout" severity failure;
   if rst='1' then sv<='0';pending:=false;
   else
    if q_stall then assert qv='1' and q=old_q severity failure;end if;
    q_stall:=qv='1' and qr='0';old_q:=q;ready_count:=0;
    for i in 0 to 7 loop
      if stalled(i)='1' then assert rv(i)='1' and cs(i)=old_rs(i) report "Client response changed under stall" severity failure;end if;
      stalled(i):=rv(i) and not rr(i);old_rs(i):=cs(i);
      if cr(i)='1' then requests(i):=requests(i)+1;ready_count:=ready_count+1;end if;
      if rv(i)='1' and rr(i)='1' then
       assert cs(i).tag=i+100 and cs(i).data=std_logic_vector(to_unsigned(i+500,64)) and cs(i).error='0' report "Arbiter misrouted response" severity failure;
       responses(i):=responses(i)+1;assert responses(i)<=requests(i) severity failure;
      end if;
    end loop;
    assert ready_count<=1 report "Multiple arbiter grants" severity failure;
    if sv='1' and sr='1' then sv<='0';end if;
    if qv='1' and qr='1' then
     assert not pending and sv='0' report "Multiple memory requests outstanding" severity failure;
     owner:=to_integer(q.address);assert owner<8 and q.tag=owner+100 severity failure;
     s<=(std_logic_vector(to_unsigned(owner+500,64)),q.tag,'0');pending:=true;delay:=cycle mod 5;
    end if;
    if pending then if delay=0 then sv<='1';pending:=false;else delay:=delay-1;end if;end if;
    total:=0;for i in 0 to 7 loop total:=total+responses(i);end loop;
    if total=64 then
      for i in 0 to 7 loop assert responses(i)=8 report "Round-robin fairness" severity failure;end loop;
      report "MEMORY_ARBITER_PASS responses=64" severity note;stop;
    end if;
   end if;
  end if;
 end process;
end;
