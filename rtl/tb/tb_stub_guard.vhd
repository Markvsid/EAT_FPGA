-- Generated structural test only. This is not arithmetic/protocol verification.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity tb_stub_guard is end entity;
architecture structural_test of tb_stub_guard is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal check_0 : std_logic;
begin
  clk <= not clk after 5 ns;
  rst <= '0' after 20 ns;
  u_eat_fpga_top : entity work.eat_fpga_top(stub)
    generic map (G_ALLOW_STUB_SIM => false)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_axi_awaddr_i => (others => '0'),
      s_axi_awvalid_i => '0',
      s_axi_awready_o => open,
      s_axi_wdata_i => (others => '0'),
      s_axi_wstrb_i => (others => '0'),
      s_axi_wvalid_i => '0',
      s_axi_wready_o => open,
      s_axi_bresp_o => open,
      s_axi_bvalid_o => open,
      s_axi_bready_i => '0',
      s_axi_araddr_i => (others => '0'),
      s_axi_arvalid_i => '0',
      s_axi_arready_o => open,
      s_axi_rdata_o => open,
      s_axi_rresp_o => open,
      s_axi_rvalid_o => open,
      s_axi_rready_i => '0',
      s_axis_tdata_i => (others => '0'),
      s_axis_tkeep_i => (others => '0'),
      s_axis_tlast_i => '0',
      s_axis_tvalid_i => '0',
      s_axis_tready_o => open,
      m_axis_tdata_o => open,
      m_axis_tkeep_o => open,
      m_axis_tlast_o => open,
      m_axis_tvalid_o => open,
      m_axis_tready_i => '0',
      interrupt_o => check_0
    );
  process
  begin
    wait for 60 ns;
    assert false report "Default stub guard did not fire" severity failure;
    wait;
  end process;
end architecture;
