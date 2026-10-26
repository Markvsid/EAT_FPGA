-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Per-inference active/stall/saturation/traffic counters with atomic completion snapshot.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_performance_counters is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    start_i : in std_logic;
    complete_i : in std_logic;
    clear_i : in std_logic;
    event_valid_i : in std_logic;
    event_i : in counter_event_t;
    event_count_i : in unsigned(31 downto 0);
    snapshot_valid_o : out std_logic;
    snapshot_ready_i : in std_logic;
    snapshot_o : out counter_snapshot_t
  );
end entity;

architecture stub of eat_performance_counters is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_performance_counters" severity failure;
  -- synthesis translate_on
  snapshot_valid_o <= '0';
  snapshot_o <= C_COUNTERS_IDLE;
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
