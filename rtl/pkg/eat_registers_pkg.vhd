-- Draft register offsets only. A Vivado/PS base address is not assigned.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;

package eat_registers_pkg is
  subtype reg_addr_t is unsigned(C_AXIL_ADDR_BITS-1 downto 0);
  constant C_REG_CONTROL       : reg_addr_t := x"0000";
  constant C_REG_MODE          : reg_addr_t := x"0004";
  constant C_REG_STATUS        : reg_addr_t := x"0008";
  constant C_REG_ERROR         : reg_addr_t := x"000C";
  constant C_REG_MODEL         : reg_addr_t := x"0010";
  constant C_REG_ABI_VERSION   : reg_addr_t := x"0014";
  constant C_REG_NUMERIC_VER   : reg_addr_t := x"0018";
  constant C_REG_INFERENCE_ID  : reg_addr_t := x"001C";
  constant C_REG_EXPECTED_ID   : reg_addr_t := x"0020"; -- eight 32-bit words
  constant C_REG_LOADED_ID     : reg_addr_t := x"0040"; -- eight 32-bit words
  constant C_REG_LOAD_ADDRESS  : reg_addr_t := x"0060";
  constant C_REG_LOAD_BYTES    : reg_addr_t := x"0064";
  constant C_REG_LOAD_KIND     : reg_addr_t := x"0068";
  constant C_REG_OUTPUT_CLASSES: reg_addr_t := x"006C";
  constant C_REG_SNAPSHOT_ID   : reg_addr_t := x"0070";
  constant C_REG_TRANSFER_KIND : reg_addr_t := x"0074"; -- 0 raw input, 1 constants
  constant C_REG_COUNTER_BASE  : reg_addr_t := x"0100"; -- 8 bytes per counter event
  constant C_ABI_VERSION : std_logic_vector(31 downto 0) := x"00020000";
  constant C_ABI_VERSION_DRAFT : std_logic_vector(31 downto 0) := C_ABI_VERSION; -- compatibility alias
  constant C_CONTROL_START_BIT : natural := 0;
  constant C_CONTROL_LOAD_BIT  : natural := 1;
  constant C_CONTROL_CLEAR_DONE_BIT : natural := 2;
  constant C_CONTROL_CLEAR_COUNTERS_BIT : natural := 3;
  constant C_CONTROL_ARM_BANK_BIT : natural := 4;
end package;
