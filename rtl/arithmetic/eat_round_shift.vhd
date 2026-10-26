-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Nearest-even signed right shift or checked left shift; explicit output saturation.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_round_shift is
  generic (
    G_ALLOW_STUB_SIM : boolean := false;
    G_IN_BITS : positive := 72;
    G_OUT_BITS : positive := 24
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    x_i : in signed(G_IN_BITS-1 downto 0);
    shift_i : in shift_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    y_o : out signed(G_OUT_BITS-1 downto 0);
    saturated_o : out std_logic;
    overflow_o : out std_logic
  );
end entity;

architecture rtl of eat_round_shift is
  signal full : std_logic := '0';
begin
  s_ready_o <= (not full or m_ready_i) and not rst_i;
  m_valid_o <= full and not rst_i;
  process(clk_i)
    variable shifted : signed(G_IN_BITS+50 downto 0);
    variable sh : integer;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';
      elsif s_ready_o='1' then
        full<=s_valid_i;
        if s_valid_i='1' then
          sh:=to_integer(shift_i);
          shifted:=shift_even(resize(x_i,shifted'length),sh);
          y_o<=sat(shifted,G_OUT_BITS);
          saturated_o<=flag(not fits(shifted,G_OUT_BITS));
          overflow_o<=flag((sh < -50 or sh > 50) or (sh<0 and not fits(shifted,63)));
        end if;
      end if;
    end if;
  end process;
end architecture;
