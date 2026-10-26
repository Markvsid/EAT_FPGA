-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Candidate 8x8 PE array with row/column broadcast and disabled padded lanes.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_mac_array is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    activations_i : in act_vec_t(0 to C_ARRAY_ROWS-1);
    weights_i : in act_vec_t(0 to C_ARRAY_COLS-1);
    row_mask_i : in std_logic_vector(C_ARRAY_ROWS-1 downto 0);
    column_mask_i : in std_logic_vector(C_ARRAY_COLS-1 downto 0);
    first_k_i : in std_logic;
    last_k_i : in std_logic;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    accumulators_o : out acc_tile_t;
    active_products_o : out unsigned(15 downto 0);
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_mac_array is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_mac_array" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  accumulators_o <= (others => (others => (others => '0')));
  active_products_o <= (others => '0');
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
