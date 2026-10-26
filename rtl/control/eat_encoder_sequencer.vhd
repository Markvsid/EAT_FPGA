-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Issue embedding/position, pre-norm attention/FFN/residuals, block-one gate, final norm/pool/head.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_encoder_sequencer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    start_valid_i : in std_logic;
    start_ready_o : out std_logic;
    ctx_i : in context_t;
    matrix_valid_o : out std_logic;
    matrix_ready_i : in std_logic;
    matrix_o : out matrix_cmd_t;
    vector_valid_o : out std_logic;
    vector_ready_i : in std_logic;
    vector_o : out vector_cmd_t;
    attention_valid_o : out std_logic;
    attention_ready_i : in std_logic;
    attention_o : out attention_cmd_t;
    gate_valid_o : out std_logic;
    gate_ready_i : in std_logic;
    gate_o : out gate_cmd_t;
    unit_status_i : in status_t;
    unit_done_valid_i : in std_logic;
    unit_done_ready_o : out std_logic;
    output_accepted_i : in std_logic;
    status_o : out status_t
  );
end entity;

architecture stub of eat_encoder_sequencer is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_encoder_sequencer" severity failure;
  -- synthesis translate_on
  start_ready_o <= '0';
  matrix_valid_o <= '0';
  matrix_o <= C_MATRIX_CMD_IDLE;
  vector_valid_o <= '0';
  vector_o <= C_VECTOR_CMD_IDLE;
  attention_valid_o <= '0';
  attention_o <= C_ATTENTION_CMD_IDLE;
  gate_valid_o <= '0';
  gate_o <= C_GATE_CMD_IDLE;
  unit_done_ready_o <= '0';
  status_o <= C_STATUS_STUB;
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
