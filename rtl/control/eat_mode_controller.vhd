-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Latch mode/bank/identity only at idle boundary; reject busy/invalid starts.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_mode_controller is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    request_valid_i : in std_logic;
    request_ready_o : out std_logic;
    request_i : in control_request_t;
    core_idle_i : in std_logic;
    loaded_identity_i : in identity_t;
    bank_valid_i : in std_logic;
    active_context_o : out context_t;
    active_valid_o : out std_logic;
    active_ready_i : in std_logic;
    status_o : out status_t
  );
end entity;

architecture rtl of eat_mode_controller is
  signal full : std_logic := '0';
begin
  request_ready_o<=not full and not rst_i;
  active_valid_o<=full and not rst_i;
  process(clk_i)
    variable ctx : context_t;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';status_o<=C_STATUS_IDLE;active_context_o<=C_CONTEXT_IDLE;
      else
        if full='1' and active_ready_i='1' then full<='0';end if;
        if request_valid_i='1' and request_ready_o='1' then
          ctx:=(request_i.inference_id,request_i.mode,request_i.workload,request_i.model_bank);
          status_o<=C_STATUS_IDLE;status_o.ctx<=ctx;
          if core_idle_i='0' then status_o.error<='1';status_o.code<=ERR_BUSY;
          elsif to_integer(request_i.model_bank)>=C_MODEL_BANKS or bank_valid_i='0' or request_i.expected_identity/=loaded_identity_i then
            status_o.error<='1';status_o.code<=ERR_IDENTITY;
          else full<='1';active_context_o<=ctx;end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
