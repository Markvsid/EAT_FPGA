-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Q12 state to fixed-scale INT8; nearest-even shift and counted saturation.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_activation_quantizer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    shift_i : in shift_t;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out act_beat_t;
    saturation_events_o : out unsigned(15 downto 0)
  );
end entity;

architecture rtl of eat_activation_quantizer is
  signal full : std_logic := '0';
begin
  s_ready_o <= (not full or m_ready_i) and not rst_i;
  m_valid_o <= full and not rst_i;
  process(clk_i)
    variable value : signed(74 downto 0);
    variable events : natural;
    variable beat : act_beat_t;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';
      elsif s_ready_o='1' then
        full<=s_valid_i;
        if s_valid_i='1' then
          beat:=C_ACT_BEAT_IDLE;beat.keep:=s_data_i.keep;beat.token:=s_data_i.token;
          beat.feature_base:=s_data_i.feature_base;beat.last:=s_data_i.last;beat.ctx:=s_data_i.ctx;
          events:=0;
          for i in 0 to C_LANES-1 loop
            if s_data_i.keep(i)='1' then
              value:=shift_even(resize(s_data_i.data(i),75),to_integer(shift_i));
              beat.data(i):=sat(value,C_ACT_BITS);
              if not fits(value,C_ACT_BITS) then events:=events+1;end if;
            end if;
          end loop;
          m_data_o<=beat;saturation_events_o<=to_unsigned(events,16);
        end if;
      end if;
    end if;
  end process;
end architecture;
