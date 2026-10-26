-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Per dropped group: abs(Q12 score)+4096 weights, checked signed53 numerator, nearest-even divide.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_rts_summary is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in gate_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    score_valid_i : in std_logic;
    score_ready_o : out std_logic;
    token_score_i : in state_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_rts_summary is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_rts_summary" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  s_ready_o <= '0';
  score_ready_o <= '0';
  m_valid_o <= '0';
  m_data_o <= C_STATE_BEAT_IDLE;
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
