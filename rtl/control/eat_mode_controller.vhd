-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Latch mode/bank/identity only at idle boundary; reject busy/invalid starts.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_mode_controller is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    request_valid_i : in std_logic;
    request_ready_o : out std_logic;
    request_i : in control_request_t;
    core_idle_i : in std_logic;
    loaded_identity_i : in identity_t;
    bank_valid_i : in std_logic;
    active_context_o : out context_t;
    active_valid_o : out std_logic;
    active_ready_i : in std_logic;
    status_o : out status_t
  );
end entity;

architecture stub of eat_mode_controller is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_mode_controller" severity failure;
  -- synthesis translate_on
  request_ready_o <= '0';
  active_context_o <= C_CONTEXT_IDLE;
  active_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
