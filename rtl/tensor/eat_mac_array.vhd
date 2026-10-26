-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Candidate 8x8 PE array with row/column broadcast and disabled padded lanes.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_mac_array is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    activations_i : in act_vec_t(0 to C_ARRAY_ROWS-1);
    weights_i : in act_vec_t(0 to C_ARRAY_COLS-1);
    row_mask_i : in std_logic_vector(C_ARRAY_ROWS-1 downto 0);
    column_mask_i : in std_logic_vector(C_ARRAY_COLS-1 downto 0);
    first_k_i : in std_logic;
    last_k_i : in std_logic;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    accumulators_o : out acc_tile_t;
    active_products_o : out unsigned(15 downto 0);
    overflow_o : out std_logic
  );
end entity;

architecture rtl of eat_mac_array is
  signal full : std_logic := '0';
  signal accum : acc_tile_t := (others=>(others=>(others=>'0')));
  signal bad_reg : std_logic := '0';

begin
  s_ready_o<=(not full or m_ready_i) and not rst_i;
  m_valid_o<=full and not rst_i;
  process(clk_i)
    variable total : signed(C_ACC_BITS downto 0);
    variable bad : std_logic;
    variable products : natural;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';bad_reg<='0';accum<=(others=>(others=>(others=>'0')));active_products_o<=(others=>'0');
      else
        active_products_o<=(others=>'0');
        if full='1' and m_ready_i='1' then full<='0';end if;
        if s_valid_i='1' and s_ready_o='1' then
          bad:=bad_reg;if first_k_i='1' then bad:='0';end if;products:=0;
          for row in 0 to C_ARRAY_ROWS-1 loop
            for col in 0 to C_ARRAY_COLS-1 loop
              total:=resize(accum(row)(col),total'length);
              if first_k_i='1' then total:=(others=>'0');end if;
              if row_mask_i(row)='1' and column_mask_i(col)='1' then
                total:=total+resize(activations_i(row)*weights_i(col),total'length);products:=products+1;
              end if;
              bad:=bad or flag(not fits(total,C_ACC_BITS));
              accum(row)(col)<=resize(total,C_ACC_BITS);
              if last_k_i='1' then accumulators_o(row)(col)<=resize(total,C_ACC_BITS);end if;
            end loop;
          end loop;
          active_products_o<=to_unsigned(products,16);bad_reg<=bad;
          if last_k_i='1' then full<='1';overflow_o<=bad;end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
