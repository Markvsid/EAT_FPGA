-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Logical core integration boundary; child interconnect is not wired in this skeleton.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_encoder_core is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    start_valid_i : in std_logic;
    start_ready_o : out std_logic;
    request_i : in control_request_t;
    logits_valid_o : out std_logic;
    logits_ready_i : in std_logic;
    logits_o : out state_beat_t;
    status_o : out status_t;
    event_valid_o : out std_logic;
    event_o : out counter_event_t;
    event_count_o : out unsigned(31 downto 0);
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

architecture stub of eat_encoder_core is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_encoder_core" severity failure;
  -- synthesis translate_on
  start_ready_o <= '0';
  logits_valid_o <= '0';
  logits_o <= C_STATE_BEAT_IDLE;
  status_o <= C_STATUS_STUB;
  event_valid_o <= '0';
  event_o <= EV_CYCLE;
  event_count_o <= (others => '0');
  mem_req_valid_o <= '0';
  mem_req_o <= C_MEM_REQ_IDLE;
  mem_rsp_ready_o <= '0';
  param_req_valid_o <= '0';
  param_req_o <= C_PARAM_REQ_IDLE;
  param_rsp_ready_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
