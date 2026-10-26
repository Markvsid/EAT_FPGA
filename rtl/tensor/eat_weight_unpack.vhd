-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Low nibble first INT4 sign extension or INT8 lanes; reject other precisions.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_weight_unpack is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    packed_i : in std_logic_vector(63 downto 0);
    half_i : in std_logic;
    weight_bits_i : in natural range 0 to 8;
    keep_i : in lane_mask_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    weights_o : out act_vec_t(0 to C_LANES-1);
    keep_o : out lane_mask_t;
    error_o : out std_logic
  );
end entity;

architecture stub of eat_weight_unpack is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_weight_unpack" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  weights_o <= (others => (others => '0'));
  keep_o <= (others => '0');
  error_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
