-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Masked wide sum with overflow check; used by norm/attention/vector reductions.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_reduction_tree is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    values_i : in wide_vec_t(0 to C_LANES-1);
    keep_i : in lane_mask_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    sum_o : out wide_t;
    overflow_o : out std_logic
  );
end entity;

architecture rtl of eat_reduction_tree is
  signal full : std_logic := '0';
begin
  s_ready_o <= (not full or m_ready_i) and not rst_i;
  m_valid_o <= full and not rst_i;
  process(clk_i)
    variable total : signed(66 downto 0);
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';
      elsif s_ready_o='1' then
        full<=s_valid_i;
        if s_valid_i='1' then
          total:=(others=>'0');
          for i in 0 to C_LANES-1 loop
            if keep_i(i)='1' then total:=total+resize(values_i(i),67);end if;
          end loop;
          sum_o<=total(63 downto 0);overflow_o<=flag(not fits(total,64));
        end if;
      end if;
    end if;
  end process;
end architecture;
