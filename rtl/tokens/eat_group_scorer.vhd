-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Consume shared tensor OP_SCORE results, store token scores and sum exact groups of four.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_group_scorer is
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
    token_scores_valid_i : in std_logic;
    token_scores_ready_o : out std_logic;
    token_scores_i : in state_beat_t;
    scores_valid_o : out std_logic;
    scores_ready_i : in std_logic;
    score_o : out group_score_t;
    group_index_o : out natural range 0 to C_MAX_TOKENS/C_GROUP_SIZE-1;
    last_group_o : out std_logic;
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

architecture stub of eat_group_scorer is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_group_scorer" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  token_scores_ready_o <= '0';
  scores_valid_o <= '0';
  score_o <= (others => '0');
  group_index_o <= 0;
  last_group_o <= '0';
  mem_req_valid_o <= '0';
  mem_req_o <= C_MEM_REQ_IDLE;
  mem_rsp_ready_o <= '0';
  param_req_valid_o <= '0';
  param_req_o <= C_PARAM_REQ_IDLE;
  param_rsp_ready_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
