-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Mask padded keys, compute tile maximum, alpha and per-key Q20 exponentials.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_rowmax_exp is
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
    s_data_i : in score_beat_t;
    previous_max_i : in score_t;
    previous_max_valid_i : in std_logic;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out exp_beat_t;
    new_max_o : out score_t;
    alpha_o : out exp_t;
    param_req_valid_o : out std_logic;
    param_req_ready_i : in std_logic;
    param_req_o : out param_req_t;
    param_rsp_valid_i : in std_logic;
    param_rsp_ready_o : out std_logic;
    param_rsp_i : in param_rsp_t
  );
end entity;

architecture stub of eat_rowmax_exp is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_rowmax_exp" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  s_ready_o <= '0';
  m_valid_o <= '0';
  m_data_o <= C_EXP_BEAT_IDLE;
  new_max_o <= (others => '0');
  alpha_o <= (others => '0');
  param_req_valid_o <= '0';
  param_req_o <= C_PARAM_REQ_IDLE;
  param_rsp_ready_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
