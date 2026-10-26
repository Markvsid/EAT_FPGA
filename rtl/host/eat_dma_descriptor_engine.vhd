-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- PL transfer counts/routing for PS AXI DMA; not a custom DDR AXI master.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_dma_descriptor_engine is
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
    stream_bytes_accepted_i : in unsigned(15 downto 0);
    stream_last_i : in std_logic;
    frame_error_i : in std_logic;
    active_transfer_o : out transfer_cmd_t;
    active_valid_o : out std_logic
  );
end entity;

architecture stub of eat_dma_descriptor_engine is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_dma_descriptor_engine" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  active_transfer_o <= C_TRANSFER_CMD_IDLE;
  active_valid_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
