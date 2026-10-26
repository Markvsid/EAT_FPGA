-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Q24 to Q12 rounding followed by Q20 1/sqrt(head-width) multiplier and rounding.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_score_scale is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    qk_q24_i : in qk_acc_t;
    scale_multiplier_q20_i : in unsigned(31 downto 0);
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    score_q12_o : out score_t;
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_score_scale is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_score_scale" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  score_q12_o <= (others => '0');
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
