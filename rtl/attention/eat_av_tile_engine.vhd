-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Q20 coefficient times INT8 V with restored exponent; round each tile before state update.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_av_tile_engine is
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
    p_valid_i : in std_logic;
    p_ready_o : out std_logic;
    p_data_i : in exp_beat_t;
    v_valid_i : in std_logic;
    v_ready_o : out std_logic;
    v_data_i : in act_beat_t;
    previous_state_i : in av_vec_t(0 to C_LANES-1);
    alpha_i : in exp_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    weighted_state_o : out av_vec_t(0 to C_LANES-1);
    overflow_o : out std_logic
  );
end entity;

architecture stub of eat_av_tile_engine is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_av_tile_engine" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  p_ready_o <= '0';
  v_ready_o <= '0';
  m_valid_o <= '0';
  weighted_state_o <= (others => (others => '0'));
  overflow_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
