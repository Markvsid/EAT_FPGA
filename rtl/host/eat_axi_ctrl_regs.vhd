-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- AXI4-Lite register front end; independent AW/W buffering, identity and snapshots.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_axi_ctrl_regs is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_axi_awaddr_i : in std_logic_vector(C_AXIL_ADDR_BITS-1 downto 0);
    s_axi_awvalid_i : in std_logic;
    s_axi_awready_o : out std_logic;
    s_axi_wdata_i : in std_logic_vector(C_AXIL_DATA_BITS-1 downto 0);
    s_axi_wstrb_i : in std_logic_vector(C_AXIL_DATA_BITS/8-1 downto 0);
    s_axi_wvalid_i : in std_logic;
    s_axi_wready_o : out std_logic;
    s_axi_bresp_o : out std_logic_vector(1 downto 0);
    s_axi_bvalid_o : out std_logic;
    s_axi_bready_i : in std_logic;
    s_axi_araddr_i : in std_logic_vector(C_AXIL_ADDR_BITS-1 downto 0);
    s_axi_arvalid_i : in std_logic;
    s_axi_arready_o : out std_logic;
    s_axi_rdata_o : out std_logic_vector(C_AXIL_DATA_BITS-1 downto 0);
    s_axi_rresp_o : out std_logic_vector(1 downto 0);
    s_axi_rvalid_o : out std_logic;
    s_axi_rready_i : in std_logic;
    request_valid_o : out std_logic;
    request_ready_i : in std_logic;
    request_o : out control_request_t;
    transfer_valid_o : out std_logic;
    transfer_ready_i : in std_logic;
    transfer_o : out transfer_cmd_t;
    status_i : in status_t;
    loaded_identity_i : in identity_t;
    counters_i : in counter_snapshot_t;
    interrupt_o : out std_logic
  );
end entity;

architecture stub of eat_axi_ctrl_regs is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_axi_ctrl_regs" severity failure;
  -- synthesis translate_on
  s_axi_awready_o <= '0';
  s_axi_wready_o <= '0';
  s_axi_bresp_o <= (others => '0');
  s_axi_bvalid_o <= '0';
  s_axi_arready_o <= '0';
  s_axi_rdata_o <= (others => '0');
  s_axi_rresp_o <= (others => '0');
  s_axi_rvalid_o <= '0';
  request_valid_o <= '0';
  request_o <= C_CONTROL_REQUEST_IDLE;
  transfer_valid_o <= '0';
  transfer_o <= C_TRANSFER_CMD_IDLE;
  interrupt_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
