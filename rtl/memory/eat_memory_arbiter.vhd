-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Tagged logical memory requests; physical banking/ports remain a design decision.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_memory_arbiter is
  generic (
    G_ALLOW_STUB_SIM : boolean := false;
    G_CLIENTS : positive := 8
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    client_valid_i : in std_logic_vector(G_CLIENTS-1 downto 0);
    client_ready_o : out std_logic_vector(G_CLIENTS-1 downto 0);
    client_req_i : in mem_req_array_t(0 to G_CLIENTS-1);
    client_rsp_valid_o : out std_logic_vector(G_CLIENTS-1 downto 0);
    client_rsp_ready_i : in std_logic_vector(G_CLIENTS-1 downto 0);
    client_rsp_o : out mem_rsp_array_t(0 to G_CLIENTS-1);
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t
  );
end entity;

architecture rtl of eat_memory_arbiter is
  type phase_t is (IDLE,REQUEST_MEMORY,RESPONSE_MEMORY,DELIVER);
  signal phase : phase_t := IDLE;
  signal next_client,owner : natural range 0 to G_CLIENTS-1 := 0;
  signal request_reg : mem_req_t := C_MEM_REQ_IDLE;
  signal response_reg : mem_rsp_t := C_MEM_RSP_IDLE;
  signal selected : natural range 0 to G_CLIENTS-1 := 0;
  signal found : std_logic;

begin
  process(all)
    variable index : natural;
    variable have_client : boolean;
  begin
    have_client:=false;selected<=next_client;found<='0';client_ready_o<=(others=>'0');
    client_rsp_valid_o<=(others=>'0');client_rsp_o<=(others=>response_reg);
    for step in 0 to G_CLIENTS-1 loop
      index:=(next_client+step) mod G_CLIENTS;
      if not have_client and client_valid_i(index)='1' then
        selected<=index;have_client:=true;found<='1';
        if phase=IDLE and rst_i='0' then client_ready_o(index)<='1';end if;
      end if;
    end loop;
    if phase=DELIVER and rst_i='0' then client_rsp_valid_o(owner)<='1';end if;
  end process;
  mem_req_valid_o<=flag(phase=REQUEST_MEMORY) and not rst_i;mem_req_o<=request_reg;
  mem_rsp_ready_o<=flag(phase=RESPONSE_MEMORY) and not rst_i;
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;owner<=0;next_client<=0;
      else
        case phase is
          when IDLE => if found='1' then owner<=selected;request_reg<=client_req_i(selected);phase<=REQUEST_MEMORY;end if;
          when REQUEST_MEMORY => if mem_req_ready_i='1' then phase<=RESPONSE_MEMORY;end if;
          when RESPONSE_MEMORY => if mem_rsp_valid_i='1' then
            response_reg<=mem_rsp_i;
            if mem_rsp_i.tag/=request_reg.tag then response_reg.error<='1';response_reg.tag<=request_reg.tag;end if;
            phase<=DELIVER;
          end if;
          when DELIVER => if client_rsp_ready_i(owner)='1' then
            if owner=G_CLIENTS-1 then next_client<=0;else next_client<=owner+1;end if;
            phase<=IDLE;
          end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
