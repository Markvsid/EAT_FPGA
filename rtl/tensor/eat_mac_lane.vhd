-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- One enabled INT8 product and checked 40-bit K accumulation; W4 is sign-extended.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_mac_lane is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    activation_i : in act_t;
    weight_i : in act_t;
    enable_i : in std_logic;
    first_k_i : in std_logic;
    last_k_i : in std_logic;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    accumulator_o : out acc_t;
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_mac_lane is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_mac_lane" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  accumulator_o <= (others => '0');
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
