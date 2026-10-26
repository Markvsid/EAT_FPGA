-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Leading-one normalization for nonnegative variance; explicit zero flag.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_leading_one is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    value_i : in unsigned(63 downto 0);
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    exponent_o : out unsigned(5 downto 0);
    zero_o : out std_logic
  );
end entity;

architecture rtl of eat_leading_one is
  signal full : std_logic := '0';
begin
  s_ready_o <= (not full or m_ready_i) and not rst_i;
  m_valid_o <= full and not rst_i;
  process(clk_i)
    variable exponent : natural range 0 to 63;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';
      elsif s_ready_o='1' then
        full<=s_valid_i;
        if s_valid_i='1' then
          exponent:=0;
          for i in 0 to 63 loop if value_i(i)='1' then exponent:=i;end if;end loop;
          exponent_o<=to_unsigned(exponent,6);zero_o<=flag(value_i=0);
        end if;
      end if;
    end if;
  end process;
end architecture;
