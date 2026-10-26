-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Typed view of biases, multipliers, gamma, shifts, positions and nonlinear tables.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_parameter_store is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    req_valid_i : in std_logic;
    req_ready_o : out std_logic;
    req_i : in param_req_t;
    rsp_valid_o : out std_logic;
    rsp_ready_i : in std_logic;
    rsp_o : out param_rsp_t;
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t
  );
end entity;

architecture stub of eat_parameter_store is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_parameter_store" severity failure;
  -- synthesis translate_on
  req_ready_o <= '0';
  rsp_valid_o <= '0';
  rsp_o <= C_PARAM_RSP_IDLE;
  mem_req_valid_o <= '0';
  mem_req_o <= C_MEM_REQ_IDLE;
  mem_rsp_ready_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
