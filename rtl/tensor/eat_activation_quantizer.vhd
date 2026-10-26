-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Q12 state to fixed-scale INT8; nearest-even shift and counted saturation.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_activation_quantizer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    shift_i : in shift_t;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out act_beat_t;
    saturation_events_o : out unsigned(15 downto 0)
  );
end entity;

architecture stub of eat_activation_quantizer is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_activation_quantizer" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  m_data_o <= C_ACT_BEAT_IDLE;
  saturation_events_o <= (others => '0');
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
