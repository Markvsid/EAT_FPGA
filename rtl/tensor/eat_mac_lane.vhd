-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- One enabled INT8 product and checked 40-bit K accumulation; W4 is sign-extended.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_mac_lane is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    activation_i : in act_t;
    weight_i : in act_t;
    enable_i : in std_logic;
    first_k_i : in std_logic;
    last_k_i : in std_logic;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    accumulator_o : out acc_t;
    overflow_o : out std_logic
  );
end entity;

architecture rtl of eat_mac_lane is
  signal full : std_logic := '0';
  signal accumulator : acc_t := (others=>'0');
  signal accumulated_overflow : std_logic := '0';

begin
  s_ready_o<=(not full or m_ready_i) and not rst_i;
  m_valid_o<=full and not rst_i;
  process(clk_i)
    variable total : signed(C_ACC_BITS downto 0);
    variable bad : std_logic;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';accumulator<=(others=>'0');accumulated_overflow<='0';
      else
        if full='1' and m_ready_i='1' then full<='0';end if;
        if s_valid_i='1' and s_ready_o='1' then
          total:=resize(accumulator,total'length);bad:=accumulated_overflow;
          if first_k_i='1' then total:=(others=>'0');bad:='0';end if;
          if enable_i='1' then total:=total+resize(activation_i*weight_i,total'length);end if;
          bad:=bad or flag(not fits(total,C_ACC_BITS));
          accumulator<=resize(total,C_ACC_BITS);accumulated_overflow<=bad;
          if last_k_i='1' then full<='1';accumulator_o<=resize(total,C_ACC_BITS);overflow_o<=bad;end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
