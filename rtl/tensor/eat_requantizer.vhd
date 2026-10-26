-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Add bias in accumulator domain, check 40 bits, multiply Q24, round and saturate state.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_requantizer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    accumulators_i : in acc_vec_t(0 to C_LANES-1);
    bias_i : in acc_vec_t(0 to C_LANES-1);
    multipliers_i : in multiplier_vec_t(0 to C_LANES-1);
    keep_i : in lane_mask_t;
    token_i : in token_index_t;
    feature_base_i : in feature_index_t;
    last_i : in std_logic;
    ctx_i : in context_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    saturation_events_o : out unsigned(15 downto 0);
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_requantizer is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_requantizer" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  m_data_o <= C_STATE_BEAT_IDLE;
  saturation_events_o <= (others => '0');
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
