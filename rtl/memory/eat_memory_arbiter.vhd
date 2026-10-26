-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Tagged logical memory requests; physical banking/ports remain a design decision.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

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

architecture stub of eat_memory_arbiter is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_memory_arbiter" severity failure;
  -- synthesis translate_on
  client_ready_o <= (others => '0');
  client_rsp_valid_o <= (others => '0');
  client_rsp_o <= (others => C_MEM_RSP_IDLE);
  mem_req_valid_o <= '0';
  mem_req_o <= C_MEM_REQ_IDLE;
  mem_rsp_ready_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
