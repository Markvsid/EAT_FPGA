-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Elastic buffering and flush; no data accepted by the stub.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_rv_fifo is
  generic (
    G_ALLOW_STUB_SIM : boolean := false;
    G_DATA_BITS : positive := 256;
    G_DEPTH : positive := 4
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    flush_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in std_logic_vector(G_DATA_BITS-1 downto 0);
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out std_logic_vector(G_DATA_BITS-1 downto 0);
    occupancy_o : out natural range 0 to G_DEPTH
  );
end entity;

architecture rtl of eat_rv_fifo is
  type storage_t is array(0 to G_DEPTH-1) of std_logic_vector(G_DATA_BITS-1 downto 0);
  signal ram : storage_t;
  signal rd,wr : natural range 0 to G_DEPTH-1 := 0;
  signal count : natural range 0 to G_DEPTH := 0;
  function next_ptr(p : natural) return natural is
  begin if p=G_DEPTH-1 then return 0; else return p+1; end if; end;
begin
  m_valid_o<=flag(count>0) and not rst_i and not flush_i;
  s_ready_o<=(flag(count<G_DEPTH) or (m_ready_i and flag(count>0))) and not rst_i and not flush_i;
  m_data_o<=ram(rd);
  occupancy_o<=count;
  process(clk_i)
    variable push,pop : boolean;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' or flush_i='1' then count<=0;rd<=0;wr<=0;
      else
        push:=s_valid_i='1' and s_ready_o='1'; pop:=m_valid_o='1' and m_ready_i='1';
        if push then ram(wr)<=s_data_i;wr<=next_ptr(wr);end if;
        if pop then rd<=next_ptr(rd);end if;
        if push and not pop then count<=count+1;elsif pop and not push then count<=count-1;end if;
      end if;
    end if;
  end process;
end architecture;
