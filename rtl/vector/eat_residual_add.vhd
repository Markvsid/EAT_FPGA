-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Rendezvous matching token/feature/context beats; saturating signed24 addition.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_residual_add is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in vector_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    a_valid_i : in std_logic;
    a_ready_o : out std_logic;
    a_data_i : in state_beat_t;
    b_valid_i : in std_logic;
    b_ready_o : out std_logic;
    b_data_i : in state_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    saturation_events_o : out unsigned(15 downto 0)
  );
end entity;

architecture stub of eat_residual_add is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_residual_add" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  a_ready_o <= '0';
  b_ready_o <= '0';
  m_valid_o <= '0';
  m_data_o <= C_STATE_BEAT_IDLE;
  saturation_events_o <= (others => '0');
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
