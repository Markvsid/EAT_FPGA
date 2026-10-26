-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Pack class-order signed24 logits into sign-extended 32-bit words; TLAST on final word.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_axi_stream_output is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    classes_i : in natural range 0 to C_MAX_CLASSES;
    output_accepted_o : out std_logic;
    m_axis_tdata_o : out std_logic_vector(C_AXIS_BITS-1 downto 0);
    m_axis_tkeep_o : out std_logic_vector(C_AXIS_BITS/8-1 downto 0);
    m_axis_tlast_o : out std_logic;
    m_axis_tvalid_o : out std_logic;
    m_axis_tready_i : in std_logic
  );
end entity;

architecture stub of eat_axi_stream_output is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_axi_stream_output" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  output_accepted_o <= '0';
  m_axis_tdata_o <= (others => '0');
  m_axis_tkeep_o <= (others => '0');
  m_axis_tlast_o <= '0';
  m_axis_tvalid_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
