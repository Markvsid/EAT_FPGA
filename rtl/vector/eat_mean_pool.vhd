-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Sum actual 20/26/32 token rows, then nearest-even division, independently per feature.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_mean_pool is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in vector_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t
  );
end entity;

architecture stub of eat_mean_pool is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_mean_pool" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  s_ready_o <= '0';
  m_valid_o <= '0';
  m_data_o <= C_STATE_BEAT_IDLE;
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
