-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Typed view of biases, multipliers, gamma, shifts, positions and nonlinear tables.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;
use work.eat_image_pkg.all;

entity eat_parameter_store is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    req_valid_i : in std_logic;
    req_ready_o : out std_logic;
    req_i : in param_req_t;
    rsp_valid_o : out std_logic;
    rsp_ready_i : in std_logic;
    rsp_o : out param_rsp_t;
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t
  );
end entity;

architecture rtl of eat_parameter_store is
  type phase_t is (IDLE,REQUEST_MEMORY,RESPONSE_MEMORY,DELIVER);
  signal phase : phase_t := IDLE;
  signal request_reg : param_req_t := C_PARAM_REQ_IDLE;
  signal response_reg : param_rsp_t := C_PARAM_RSP_IDLE;

begin
  req_ready_o<=flag(phase=IDLE) and not rst_i;rsp_valid_o<=flag(phase=DELIVER) and not rst_i;rsp_o<=response_reg;
  mem_req_valid_o<=flag(phase=REQUEST_MEMORY) and not rst_i;
  process(all)
    variable request:mem_req_t;
  begin
    request:=C_MEM_REQ_IDLE;request.tag:=request_reg.tag;
    if to_integer(request_reg.bank)<C_MODEL_BANKS and to_integer(request_reg.address)<region_words(request_reg.kind) then
      request.address:=image_address(request_reg.kind,request_reg.bank,request_reg.address);
    end if;
    mem_req_o<=request;
  end process;
  mem_rsp_ready_o<=flag(phase=RESPONSE_MEMORY) and not rst_i;
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;request_reg<=C_PARAM_REQ_IDLE;response_reg<=C_PARAM_RSP_IDLE;
      else
        case phase is
          when IDLE => if req_valid_i='1' then
            request_reg<=req_i;response_reg<=((others=>'0'),req_i.tag,'0');
            if to_integer(req_i.bank)>=C_MODEL_BANKS or to_integer(req_i.address)>=region_words(req_i.kind) then response_reg.error<='1';phase<=DELIVER;
            else phase<=REQUEST_MEMORY;end if;
          end if;
          when REQUEST_MEMORY => if mem_req_ready_i='1' then phase<=RESPONSE_MEMORY;end if;
          when RESPONSE_MEMORY => if mem_rsp_valid_i='1' then
            response_reg.data<=mem_rsp_i.data;
            if mem_rsp_i.error='1' or mem_rsp_i.tag/=request_reg.tag or not valid_constant(request_reg.kind,signed(mem_rsp_i.data)) then response_reg.error<='1';end if;
            phase<=DELIVER;
          end if;
          when DELIVER => if rsp_ready_i='1' then phase<=IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
