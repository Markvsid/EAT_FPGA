-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Q24 to Q12 rounding followed by Q20 1/sqrt(head-width) multiplier and rounding.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_score_scale is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    qk_q24_i : in qk_acc_t;
    scale_multiplier_q20_i : in unsigned(31 downto 0);
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    score_q12_o : out score_t;
    overflow_o : out std_logic
  );
end entity;

architecture rtl of eat_score_scale is
  signal full : std_logic := '0';
begin
  s_ready_o <= (not full or m_ready_i) and not rst_i;
  m_valid_o <= full and not rst_i;
  process(clk_i)
    variable first : qk_acc_t;
    variable product : signed(C_QK_ACC_BITS+32 downto 0);
    variable result_value : signed(C_QK_ACC_BITS+32 downto 0);
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';
      elsif s_ready_o='1' then
        full<=s_valid_i;
        if s_valid_i='1' then
          first:=rshift_even(qk_q24_i,C_STATE_FRAC);
          product:=first*signed('0'&scale_multiplier_q20_i);
          result_value:=rshift_even(product,20);
          score_q12_o<=result_value(C_SCORE_BITS-1 downto 0);overflow_o<=flag(not fits(result_value,C_SCORE_BITS));
        end if;
      end if;
    end if;
  end process;
end architecture;
