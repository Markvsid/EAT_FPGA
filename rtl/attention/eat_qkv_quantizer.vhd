-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Split QKV and quantize Q/K/V independently to INT8 with recorded exponents.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_qkv_quantizer is
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
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    q_valid_o : out std_logic;
    q_ready_i : in std_logic;
    q_data_o : out act_beat_t;
    k_valid_o : out std_logic;
    k_ready_i : in std_logic;
    k_data_o : out act_beat_t;
    v_valid_o : out std_logic;
    v_ready_i : in std_logic;
    v_data_o : out act_beat_t
  );
end entity;

architecture stub of eat_qkv_quantizer is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_qkv_quantizer" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  s_ready_o <= '0';
  q_valid_o <= '0';
  q_data_o <= C_ACT_BEAT_IDLE;
  k_valid_o <= '0';
  k_data_o <= C_ACT_BEAT_IDLE;
  v_valid_o <= '0';
  v_data_o <= C_ACT_BEAT_IDLE;
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
