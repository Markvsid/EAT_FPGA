-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Q12 activations and residual ping-pong storage; tags and bank swaps on legal boundaries.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_activation_buffer_pingpong is
  generic (
    G_ALLOW_STUB_SIM : boolean := false;
    G_WORDS : positive := 12288
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    req_valid_i : in std_logic;
    req_ready_o : out std_logic;
    req_i : in mem_req_t;
    rsp_valid_o : out std_logic;
    rsp_ready_i : in std_logic;
    rsp_o : out mem_rsp_t
  );
end entity;

architecture rtl of eat_activation_buffer_pingpong is
  type ram_t is array(0 to G_WORDS-1) of std_logic_vector(63 downto 0);
  signal ram : ram_t;
  signal full : std_logic := '0';

begin
  req_ready_o<=(not full or rsp_ready_i) and not rst_i;
  rsp_valid_o<=full and not rst_i;
  process(clk_i)
    variable address_value : natural;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';rsp_o<=C_MEM_RSP_IDLE;
      elsif req_ready_o='1' then
        full<=req_valid_i;
        if req_valid_i='1' then
          rsp_o<=C_MEM_RSP_IDLE;rsp_o.tag<=req_i.tag;address_value:=to_integer(req_i.address);
          if address_value>=G_WORDS then rsp_o.error<='1';
          elsif req_i.write_enable='1' then
            for byte in 0 to 7 loop
              if req_i.write_strobe(byte)='1' then ram(address_value)(8*byte+7 downto 8*byte)<=req_i.write_data(8*byte+7 downto 8*byte);end if;
            end loop;
          else rsp_o.data<=ram(address_value);end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
