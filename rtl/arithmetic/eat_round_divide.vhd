-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Nearest-even signed numerator/positive denominator division; no truncating divide.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_round_divide is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    numerator_i : in wide_t;
    denominator_i : in unsigned(63 downto 0);
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    quotient_o : out wide_t;
    divide_by_zero_o : out std_logic;
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_round_divide is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_round_divide" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  quotient_o <= (others => '0');
  divide_by_zero_o <= '0';
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
