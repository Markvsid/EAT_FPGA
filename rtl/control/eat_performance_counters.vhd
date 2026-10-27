-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Per-inference active/stall/saturation/traffic counters with atomic completion snapshot.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

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
    abort_i : in std_logic;
    event_valid_i : in std_logic;
    event_i : in counter_event_t;
    event_count_i : in unsigned(31 downto 0);
    snapshot_valid_o : out std_logic;
    snapshot_ready_i : in std_logic;
    snapshot_o : out counter_snapshot_t
  );
end entity;

architecture rtl of eat_performance_counters is
  signal active : std_logic := '0';
  signal counters : counter_snapshot_t := C_COUNTERS_IDLE;
  signal full : std_logic := '0';

begin
  snapshot_valid_o<=full and not rst_i;
  process(clk_i)
    variable next_counters : counter_snapshot_t;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' or clear_i='1' then counters<=C_COUNTERS_IDLE;snapshot_o<=C_COUNTERS_IDLE;active<='0';full<='0';
      else
        next_counters:=counters;
        if full='1' and snapshot_ready_i='1' then full<='0';end if;
        if abort_i='1' then active<='0';
        else
        if start_i='1' then next_counters:=C_COUNTERS_IDLE;active<='1';end if;
        if active='1' or start_i='1' then
          next_counters(EV_CYCLE):=next_counters(EV_CYCLE)+1;
          if event_valid_i='1' and event_i/=EV_CYCLE and event_i/=EV_INFERENCE then
            next_counters(event_i):=next_counters(event_i)+resize(event_count_i,64);
          end if;
          if complete_i='1' then
            next_counters(EV_INFERENCE):=to_unsigned(1,64);active<='0';
            -- The sequencer must not complete another inference with an unread snapshot.
            assert full='0' or snapshot_ready_i='1' report "Unread performance snapshot overwritten" severity failure;
            snapshot_o<=next_counters;full<='1';
          end if;
        end if;
        end if;
        counters<=next_counters;
      end if;
    end if;
  end process;
end architecture;
