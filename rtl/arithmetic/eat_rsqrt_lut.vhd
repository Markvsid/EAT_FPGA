-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Read 1024 Q30 mantissa coefficients; exponent/parity correction belongs to RMSNorm.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

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
    param_rsp_i : in param_rsp_t;
    error_o : out std_logic
  );
end entity;

architecture rtl of eat_rsqrt_lut is
  type phase_t is (IDLE,REQUEST_PARAM,WAIT_PARAM,OUTPUT_RESULT);
  signal phase : phase_t := IDLE;
  signal request_reg : param_req_t := C_PARAM_REQ_IDLE;

begin
  s_ready_o<=flag(phase=IDLE) and not rst_i;
  m_valid_o<=flag(phase=OUTPUT_RESULT) and not rst_i;
  param_req_valid_o<=flag(phase=REQUEST_PARAM) and not rst_i;
  param_req_o<=request_reg;
  param_rsp_ready_o<=flag(phase=WAIT_PARAM) and not rst_i;
  process(clk_i)
    variable address_value : signed(63 downto 0);
    variable offset : natural;
    variable address_sum : unsigned(C_MEM_ADDR_BITS downto 0);
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;
      else
        case phase is
          when IDLE => if s_valid_i='1' then
            error_o<='0';coefficient_q30_o<=(others=>'0');
            offset:=to_integer(address_i);
              address_sum:=resize(table_base_i,C_MEM_ADDR_BITS+1)+offset;
              if address_sum(C_MEM_ADDR_BITS)='1' then error_o<='1';phase<=OUTPUT_RESULT;
              else request_reg<=(CONST_RSQRT,resize(address_sum,C_MEM_ADDR_BITS),bank_i,(others=>'0'));phase<=REQUEST_PARAM;end if;
          end if;
          when REQUEST_PARAM => if param_req_ready_i='1' then phase<=WAIT_PARAM;end if;
          when WAIT_PARAM => if param_rsp_valid_i='1' then
            if param_rsp_i.error='1' or param_rsp_i.tag/=request_reg.tag or
               unsigned(param_rsp_i.data)>shift_left(to_unsigned(1,64),30) then error_o<='1';
            else coefficient_q30_o<=resize(unsigned(param_rsp_i.data),31);end if;
            phase<=OUTPUT_RESULT;
          end if;
          when OUTPUT_RESULT => if m_ready_i='1' then phase<=IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
