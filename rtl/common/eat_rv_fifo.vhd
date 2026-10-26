-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Elastic buffering and flush; no data accepted by the stub.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_rv_fifo is
  generic (
    G_ALLOW_STUB_SIM : boolean := false;
    G_DATA_BITS : positive := 256;
    G_DEPTH : positive := 4
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    flush_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in std_logic_vector(G_DATA_BITS-1 downto 0);
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out std_logic_vector(G_DATA_BITS-1 downto 0);
    occupancy_o : out natural range 0 to G_DEPTH
  );
end entity;

architecture stub of eat_rv_fifo is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_rv_fifo" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  m_data_o <= (others => '0');
  occupancy_o <= 0;
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
