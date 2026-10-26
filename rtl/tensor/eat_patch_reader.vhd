-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Read 32 patch rows (HAR K36, speech K80), adapting host scale to embedding input scale.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_patch_reader is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in matrix_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    host_input_q12_shift_i : in shift_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out act_beat_t;
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t
  );
end entity;

architecture stub of eat_patch_reader is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_patch_reader" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  m_valid_o <= '0';
  m_data_o <= C_ACT_BEAT_IDLE;
  mem_req_valid_o <= '0';
  mem_req_o <= C_MEM_REQ_IDLE;
  mem_rsp_ready_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
