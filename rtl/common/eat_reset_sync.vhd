-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Convert platform active-low asynchronous reset to core reset; no other CDC is assumed.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_reset_sync is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    arst_n_i : in std_logic;
    rst_o : out std_logic
  );
end entity;

architecture stub of eat_reset_sync is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_reset_sync" severity failure;
  -- synthesis translate_on
  rst_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
