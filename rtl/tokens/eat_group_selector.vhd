-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Stable top-k group selection; earlier group wins ties; no scores rounded to a mean.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_group_selector is
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
    scores_valid_i : in std_logic;
    scores_ready_o : out std_logic;
    score_i : in group_score_t;
    group_index_i : in natural range 0 to C_MAX_TOKENS/C_GROUP_SIZE-1;
    last_group_i : in std_logic;
    decision_valid_o : out std_logic;
    decision_ready_i : in std_logic;
    decision_o : out group_decision_t
  );
end entity;

architecture stub of eat_group_selector is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_group_selector" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  scores_ready_o <= '0';
  decision_valid_o <= '0';
  decision_o <= C_GROUP_DECISION_IDLE;
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
