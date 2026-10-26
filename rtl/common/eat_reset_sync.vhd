-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Convert platform active-low asynchronous reset to core reset; no other CDC is assumed.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_reset_sync is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    arst_n_i : in std_logic;
    rst_o : out std_logic
  );
end entity;

architecture rtl of eat_reset_sync is
  signal sync : std_logic_vector(1 downto 0) := (others=>'1');
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of sync : signal is "TRUE";
begin
  process(clk_i,arst_n_i)
  begin
    if arst_n_i='0' then sync<=(others=>'1');
    elsif rising_edge(clk_i) then sync<=sync(0)&'0'; end if;
  end process;
  rst_o<=sync(1);
end architecture;
