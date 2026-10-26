-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Rescale previous Q20 denominator and add valid exponentials; checked signed32.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_running_normalizer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    previous_i : in normalizer_t;
    alpha_i : in exp_t;
    probabilities_i : in exp_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    normalizer_o : out normalizer_t;
    overflow_o : out std_logic
  );
end entity;

architecture rtl of eat_running_normalizer is
  signal full : std_logic := '0';
begin
  s_ready_o <= (not full or m_ready_i) and not rst_i;
  m_valid_o <= full and not rst_i;
  process(clk_i)
    variable product : signed(53 downto 0);
    variable total : signed(63 downto 0);
    variable bad : boolean;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';
      elsif s_ready_o='1' then
        full<=s_valid_i;
        if s_valid_i='1' then
          product:=previous_i*signed('0'&alpha_i);
          total:=resize(rshift_even(product,C_EXP_FRAC),64);
          bad:=previous_i<0 or alpha_i>2**C_EXP_FRAC;
          for i in 0 to C_LANES-1 loop
            if probabilities_i.keep(i)='1' then
              bad:=bad or probabilities_i.data(i)>2**C_EXP_FRAC;
              total:=total+signed(resize(probabilities_i.data(i),64));
            end if;
          end loop;
          normalizer_o<=resize(total,C_NORMALIZER_BITS);
          overflow_o<=flag(bad or total<0 or not fits(total,C_NORMALIZER_BITS));
        end if;
      end if;
    end if;
  end process;
end architecture;
