-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Raw signed INT8 host window, separate from Q12 activation storage.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_input_buffer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    req_valid_i : in std_logic;
    req_ready_o : out std_logic;
    req_i : in mem_req_t;
    rsp_valid_o : out std_logic;
    rsp_ready_i : in std_logic;
    rsp_o : out mem_rsp_t
  );
end entity;

architecture stub of eat_input_buffer is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_input_buffer" severity failure;
  -- synthesis translate_on
  req_ready_o <= '0';
  rsp_valid_o <= '0';
  rsp_o <= C_MEM_RSP_IDLE;
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
