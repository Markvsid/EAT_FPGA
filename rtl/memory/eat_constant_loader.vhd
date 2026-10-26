-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Range-check 64-bit containers, populate banks, attach host-verified identity; no SHA engine.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_constant_loader is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in transfer_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in std_logic_vector(63 downto 0);
    s_keep_i : in std_logic_vector(7 downto 0);
    s_last_i : in std_logic;
    identity_i : in identity_t;
    loaded_identity_o : out identity_t;
    bank_valid_o : out std_logic_vector(C_MODEL_BANKS-1 downto 0);
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t
  );
end entity;

architecture stub of eat_constant_loader is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_constant_loader" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  s_ready_o <= '0';
  loaded_identity_o <= (others => '0');
  bank_valid_o <= (others => '0');
  mem_req_valid_o <= '0';
  mem_req_o <= C_MEM_REQ_IDLE;
  mem_rsp_ready_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
