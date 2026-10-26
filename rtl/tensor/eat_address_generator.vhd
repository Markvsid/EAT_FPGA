-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Generate actual row/column/reduction addresses and lane masks, including 26-token tails.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_address_generator is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in matrix_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    step_ready_i : in std_logic;
    step_valid_o : out std_logic;
    activation_addr_o : out mem_addr_t;
    weight_addr_o : out mem_addr_t;
    row_mask_o : out std_logic_vector(C_ARRAY_ROWS-1 downto 0);
    column_mask_o : out std_logic_vector(C_ARRAY_COLS-1 downto 0);
    first_k_o : out std_logic;
    last_k_o : out std_logic
  );
end entity;

architecture stub of eat_address_generator is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_address_generator" severity failure;
  -- synthesis translate_on
  cmd_ready_o <= '0';
  done_valid_o <= '0';
  status_o <= C_STATUS_STUB;
  step_valid_o <= '0';
  activation_addr_o <= (others => '0');
  weight_addr_o <= (others => '0');
  row_mask_o <= (others => '0');
  column_mask_o <= (others => '0');
  first_k_o <= '0';
  last_k_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
