-- NONFUNCTIONAL SKELETON. Proposed interfaces; no transactions accepted.
-- Read 1024 Q30 mantissa coefficients; exponent/parity correction belongs to RMSNorm.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity eat_rsqrt_lut is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    address_i : in unsigned(C_RSQRT_ADDR_BITS-1 downto 0);
    table_base_i : in mem_addr_t;
    bank_i : in bank_id_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    coefficient_q30_o : out unsigned(30 downto 0);
    param_req_valid_o : out std_logic;
    param_req_ready_i : in std_logic;
    param_req_o : out param_req_t;
    param_rsp_valid_i : in std_logic;
    param_rsp_ready_o : out std_logic;
    param_rsp_i : in param_rsp_t
  );
end entity;

architecture stub of eat_rsqrt_lut is
begin
  -- synthesis translate_off
  assert G_ALLOW_STUB_SIM report "UNIMPLEMENTED_STUB: eat_rsqrt_lut" severity failure;
  -- synthesis translate_on
  s_ready_o <= '0';
  m_valid_o <= '0';
  coefficient_q30_o <= (others => '0');
  param_req_valid_o <= '0';
  param_req_o <= C_PARAM_REQ_IDLE;
  param_rsp_ready_o <= '0';
  -- TODO: implement after interface review; replace this architecture and inventory status.
end architecture;
