-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- INT8 QK dot, restore both exponents to checked Q24; no fused scaling-rounding shortcut.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_qk_tile_engine is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in attention_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    q_valid_i : in std_logic;
    q_ready_o : out std_logic;
    q_data_i : in act_beat_t;
    k_valid_i : in std_logic;
    k_ready_o : out std_logic;
    k_data_i : in act_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    qk_q24_o : out qk_acc_t;
    query_token_o : out token_index_t;
    key_token_o : out token_index_t;
    head_o : out natural range 0 to C_HEADS-1;
    last_tile_o : out std_logic;
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_qk_tile_engine is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_qk_tile_engine" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  q_ready_o <= '0';
  k_ready_o <= '0';
  m_valid_o <= '0';
  qk_q24_o <= (others => '0');
  query_token_o <= 0;
  key_token_o <= 0;
  head_o <= 0;
  last_tile_o <= '0';
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
