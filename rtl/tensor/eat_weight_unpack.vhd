-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Low nibble first INT4 sign extension or INT8 lanes; reject other precisions.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_weight_unpack is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    packed_i : in std_logic_vector(63 downto 0);
    half_i : in std_logic;
    weight_bits_i : in natural range 0 to 8;
    keep_i : in lane_mask_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    weights_o : out act_vec_t(0 to C_LANES-1);
    keep_o : out lane_mask_t;
    error_o : out std_logic
  );
end entity;

architecture rtl of eat_weight_unpack is
  signal full : std_logic := '0';
begin
  s_ready_o <= (not full or m_ready_i) and not rst_i;
  m_valid_o <= full and not rst_i;
  process(clk_i)
    variable nibble_word : std_logic_vector(31 downto 0);
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';
      elsif s_ready_o='1' then
        full<=s_valid_i;
        if s_valid_i='1' then
          weights_o<=(others=>(others=>'0'));keep_o<=keep_i;error_o<='0';
          if weight_bits_i=4 then
            nibble_word:=packed_i(31 downto 0);if half_i='1' then nibble_word:=packed_i(63 downto 32);end if;
            for i in 0 to C_LANES-1 loop
              if keep_i(i)='1' then weights_o(i)<=resize(signed(nibble_word(4*i+3 downto 4*i)),C_ACT_BITS);end if;
            end loop;
          elsif weight_bits_i=8 and half_i='0' then
            for i in 0 to C_LANES-1 loop
              if keep_i(i)='1' then weights_o(i)<=signed(packed_i(8*i+7 downto 8*i));end if;
            end loop;
          else error_o<='1';keep_o<=(others=>'0');end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
