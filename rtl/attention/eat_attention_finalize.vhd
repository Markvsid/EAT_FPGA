-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Round weighted-value numerator times2^20 divided by final normalizer to Q12.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_attention_finalize is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    weighted_state_i : in av_vec_t(0 to C_LANES-1);
    normalizer_i : in normalizer_t;
    keep_i : in lane_mask_t;
    token_i : in token_index_t;
    feature_base_i : in feature_index_t;
    ctx_i : in context_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_attention_finalize is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_attention_finalize" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  m_data_o <= C_STATE_BEAT_IDLE;
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
