-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- One elastic state beat, stable under backpressure.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_stream_register is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t
  );
end entity;

architecture rtl of eat_stream_register is
  signal full : std_logic := '0';

begin
  s_ready_o <= (not full or m_ready_i) and not rst_i;
  m_valid_o <= full and not rst_i;
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';
      elsif s_ready_o='1' then
        full<=s_valid_i;
        if s_valid_i='1' then
          m_data_o<=s_data_i;
        end if;
      end if;
    end if;
  end process;
end architecture;
