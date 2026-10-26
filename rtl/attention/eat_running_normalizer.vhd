-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Rescale previous Q20 denominator and add valid exponentials; checked signed32.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_running_normalizer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    previous_i : in normalizer_t;
    alpha_i : in exp_t;
    probabilities_i : in exp_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    normalizer_o : out normalizer_t;
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_running_normalizer is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_running_normalizer" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  normalizer_o <= (others => '0');
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
