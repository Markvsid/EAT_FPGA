-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Unpack 128-bit TKEEP/TLAST framed input/constant transfers into byte streams.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_axi_stream_input is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_axis_tdata_i : in std_logic_vector(C_AXIS_BITS-1 downto 0);
    s_axis_tkeep_i : in std_logic_vector(C_AXIS_BITS/8-1 downto 0);
    s_axis_tlast_i : in std_logic;
    s_axis_tvalid_i : in std_logic;
    s_axis_tready_o : out std_logic;
    transfer_i : in transfer_cmd_t;
    transfer_valid_i : in std_logic;
    input_valid_o : out std_logic;
    input_ready_i : in std_logic;
    input_data_o : out act_beat_t;
    constant_valid_o : out std_logic;
    constant_ready_i : in std_logic;
    constant_data_o : out std_logic_vector(63 downto 0);
    constant_keep_o : out std_logic_vector(7 downto 0);
    constant_last_o : out std_logic;
    frame_error_o : out std_logic
  );
end entity;

architecture stub of eat_axi_stream_input is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_axi_stream_input" severity failure;
  -- synthesis translate_on
  s_axis_tready_o <= '0';
  input_valid_o <= '0';
  input_data_o <= C_ACT_BEAT_IDLE;
  constant_valid_o <= '0';
  constant_data_o <= (others => '0');
  constant_keep_o <= (others => '0');
  constant_last_o <= '0';
  frame_error_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
