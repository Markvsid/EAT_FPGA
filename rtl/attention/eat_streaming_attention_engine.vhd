-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Orchestrate head/query/key tiles and online state; never allocate a full score matrix.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_streaming_attention_engine is
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
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t;
    param_req_valid_o : out std_logic;
    param_req_ready_i : in std_logic;
    param_req_o : out param_req_t;
    param_rsp_valid_i : in std_logic;
    param_rsp_ready_o : out std_logic;
    param_rsp_i : in param_rsp_t
  );
end entity;

architecture stub of eat_streaming_attention_engine is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_streaming_attention_engine" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  m_valid_o <= '0';
  m_data_o <= C_STATE_BEAT_IDLE;
  mem_req_valid_o <= '0';
  mem_req_o <= C_MEM_REQ_IDLE;
  mem_rsp_ready_o <= '0';
  param_req_valid_o <= '0';
  param_req_o <= C_PARAM_REQ_IDLE;
  param_rsp_ready_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
