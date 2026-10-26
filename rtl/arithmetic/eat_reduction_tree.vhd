-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Masked wide sum with overflow check; used by norm/attention/vector reductions.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_reduction_tree is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    values_i : in wide_vec_t(0 to C_LANES-1);
    keep_i : in lane_mask_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    sum_o : out wide_t;
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_reduction_tree is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_reduction_tree" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  sum_o <= (others => '0');
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
