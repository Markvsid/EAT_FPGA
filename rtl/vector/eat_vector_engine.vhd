-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Two-pass row norm: mean square, epsilon168, rsqrt LUT/parity, Q14 gamma and saturation.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_vector_engine is
  generic (
    G_ALLOW_STUB_SIM : boolean := false;
    G_OPERATION : string := "rmsnorm"
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in vector_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    param_req_valid_o : out std_logic;
    param_req_ready_i : in std_logic;
    param_req_o : out param_req_t;
    param_rsp_valid_i : in std_logic;
    param_rsp_ready_o : out std_logic;
    param_rsp_i : in param_rsp_t;
    saturation_events_o : out unsigned(15 downto 0)
  );
end entity;

architecture rtl of eat_vector_engine is
  type phase_t is (IDLE,COLLECT,PREPARE_ROW,VAR_DIV_START,VAR_DIV_WAIT,RSQRT_REQ,RSQRT_RSP,VALUE_PREPARE,VALUE_REQ,VALUE_RSP,KNOT_REQ,KNOT_RSP,EMIT,DONE);
  signal phase : phase_t := IDLE;
  signal command : vector_cmd_t := C_VECTOR_CMD_IDLE;
  signal values,results : state_vec_t(0 to C_MAX_MATRIX_COLS-1);
  signal row : natural range 0 to C_MAX_TOKENS-1 := 0;
  signal input_base,feature,output_base : natural range 0 to C_MAX_MATRIX_COLS-1 := 0;
  signal sum_squares,coefficient : signed(63 downto 0) := (others=>'0');
  signal variance : unsigned(63 downto 0) := (others=>'0');
  signal power : integer range -24 to 39 := 0;
  signal request_reg : param_req_t := C_PARAM_REQ_IDLE;
  signal knot_index : natural range 0 to 7 := 0;
  signal first_knot : state_t;

  signal divide_ready,divide_valid,divide_zero,divide_overflow : std_logic;
  signal divide_result : wide_t;
begin
  norm_divider:if G_OPERATION="rmsnorm" generate
    divider:entity work.eat_round_divide(rtl) port map(clk_i=>clk_i,rst_i=>rst_i,
      s_valid_i=>flag(phase=VAR_DIV_START),s_ready_o=>divide_ready,numerator_i=>sum_squares,denominator_i=>to_unsigned(command.features,64),
      m_valid_o=>divide_valid,m_ready_i=>flag(phase=VAR_DIV_WAIT),quotient_o=>divide_result,divide_by_zero_o=>divide_zero,overflow_o=>divide_overflow);
  end generate;
  assert G_OPERATION="rmsnorm" or G_OPERATION="position" or G_OPERATION="pwl" report "Invalid vector specialization" severity failure;
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;
  done_valid_o<=flag(phase=DONE) and not rst_i;
  s_ready_o<=flag(phase=COLLECT) and not rst_i;
  m_valid_o<=flag(phase=EMIT) and not rst_i;
  param_req_valid_o<=flag(phase=RSQRT_REQ or phase=VALUE_REQ or phase=KNOT_REQ) and not rst_i;
  param_req_o<=request_reg;
  param_rsp_ready_o<=flag(phase=RSQRT_RSP or phase=VALUE_RSP or phase=KNOT_RSP) and not rst_i;
  process(all)
    variable beat : state_beat_t;
  begin
    beat:=C_STATE_BEAT_IDLE;beat.token:=row;beat.feature_base:=output_base;beat.ctx:=command.ctx;
    beat.last:=flag(row+1=command.tokens and output_base+C_LANES>=command.features);
    for lane in 0 to C_LANES-1 loop
      if output_base+lane<command.features then beat.data(lane):=results(output_base+lane);beat.keep(lane):='1';end if;
    end loop;
    m_data_o<=beat;
  end process;
  process(clk_i)
    variable total,term,var_signed,coef,product,normalized,gamma_product,result_value : signed(63 downto 0);
    variable long_product : signed(127 downto 0);
    variable var_unsigned : unsigned(63 downto 0);
    variable exponent,shift_amount,half_power,index_value,frac : integer;
    variable bad,finished_value,saturation_occurred : boolean;
  begin
    if rising_edge(clk_i) then
      saturation_events_o<=(others=>'0');
      if rst_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;command<=C_VECTOR_CMD_IDLE;
      else
        finished_value:=false;saturation_occurred:=false;
        case phase is
          when IDLE => if cmd_valid_i='1' then
            command<=cmd_i;row<=0;input_base<=0;sum_squares<=(others=>'0');
            status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);
            if cmd_i.tokens=0 or cmd_i.features=0 or to_integer(cmd_i.ctx.model_bank)>=C_MODEL_BANKS or
               (G_OPERATION="position" and to_integer(cmd_i.gamma_addr)+cmd_i.tokens*cmd_i.features>2**C_MEM_ADDR_BITS) or
               (G_OPERATION="rmsnorm" and to_integer(cmd_i.gamma_addr)+cmd_i.features>2**C_MEM_ADDR_BITS) then
              phase<=DONE;status_o<=('0','1','1',ERR_DIMENSION,cmd_i.ctx);
            else phase<=COLLECT;end if;
          end if;
          when COLLECT => if s_valid_i='1' then
            bad:=s_data_i.ctx/=command.ctx or s_data_i.token/=row or s_data_i.feature_base/=input_base or
              s_data_i.last/=flag(row+1=command.tokens and input_base+C_LANES>=command.features);
            total:=sum_squares;
            for lane in 0 to C_LANES-1 loop
              if input_base+lane<command.features then
                if s_data_i.keep(lane)/='1' then bad:=true;end if;
                values(input_base+lane)<=s_data_i.data(lane);
                term:=resize(s_data_i.data(lane)*s_data_i.data(lane),64);total:=total+term;
              elsif s_data_i.keep(lane)/='0' then bad:=true;end if;
            end loop;
            sum_squares<=total;
            if bad or not fits(total,63) then status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            elsif input_base+C_LANES>=command.features then phase<=PREPARE_ROW;feature<=0;
            else input_base<=input_base+C_LANES;end if;
          end if;
          when PREPARE_ROW =>
            if G_OPERATION="rmsnorm" then phase<=VAR_DIV_START;else phase<=VALUE_PREPARE;end if;
          when VAR_DIV_START => if divide_ready='1' then phase<=VAR_DIV_WAIT;end if;
          when VAR_DIV_WAIT => if divide_valid='1' then
            if divide_zero='1' or divide_overflow='1' then status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else
              var_signed:=divide_result+C_NORM_EPSILON_Q24;
              var_unsigned:=unsigned(var_signed);variance<=var_unsigned;
              exponent:=0;for i in 0 to 63 loop if var_unsigned(i)='1' then exponent:=i;end if;end loop;
              power<=exponent-24;shift_amount:=exponent-10;
              if shift_amount>=0 then index_value:=to_integer(shift_right(var_unsigned,shift_amount))-1024;
              else index_value:=to_integer(shift_left(var_unsigned,-shift_amount))-1024;end if;
              request_reg<=(CONST_RSQRT,to_unsigned(index_value,C_MEM_ADDR_BITS),command.ctx.model_bank,(others=>'0'));phase<=RSQRT_REQ;
            end if;
          end if;
          when RSQRT_REQ => if param_req_ready_i='1' then phase<=RSQRT_RSP;end if;
          when RSQRT_RSP => if param_rsp_valid_i='1' then
            if param_rsp_i.error='1' or param_rsp_i.tag/=request_reg.tag or unsigned(param_rsp_i.data)>2**30 then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              coef:=signed(param_rsp_i.data);
              if power mod 2/=0 then
                long_product:=coef*to_signed(759250125,64);coef:=resize(rshift_even(long_product,30),64);
              end if;
              half_power:=power/2;if power<0 and power mod 2/=0 then half_power:=half_power-1;end if;
              coefficient<=shift_even(coef,half_power);phase<=VALUE_PREPARE;
            end if;
          end if;
          when VALUE_PREPARE =>
            request_reg.tag<=(others=>'0');request_reg.bank<=command.ctx.model_bank;
            if G_OPERATION="rmsnorm" then
              request_reg.kind<=CONST_GAMMA;request_reg.address<=command.gamma_addr+feature;phase<=VALUE_REQ;
            elsif G_OPERATION="position" then
              request_reg.kind<=CONST_POSITION;request_reg.address<=command.gamma_addr+row*command.features+feature;phase<=VALUE_REQ;
            else
              if values(feature)<-4*2**C_STATE_FRAC then results(feature)<=(others=>'0');finished_value:=true;
              elsif values(feature)>4*2**C_STATE_FRAC then results(feature)<=values(feature);finished_value:=true;
              else
                index_value:=to_integer(shift_right(values(feature),C_STATE_FRAC))+4;
                if index_value<0 then index_value:=0;elsif index_value>7 then index_value:=7;end if;
                knot_index<=index_value;request_reg.kind<=CONST_PWL;request_reg.address<=to_unsigned(index_value,C_MEM_ADDR_BITS);phase<=VALUE_REQ;
              end if;
            end if;
          when VALUE_REQ => if param_req_ready_i='1' then phase<=VALUE_RSP;end if;
          when VALUE_RSP => if param_rsp_valid_i='1' then
            if param_rsp_i.error='1' or param_rsp_i.tag/=request_reg.tag or not fits(signed(param_rsp_i.data),C_STATE_BITS) then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            elsif G_OPERATION="rmsnorm" then
              long_product:=resize(values(feature),64)*coefficient;
              product:=resize(long_product,64);normalized:=rshift_even(product,30);
              long_product:=normalized*signed(param_rsp_i.data);
              result_value:=resize(rshift_even(long_product,C_GAMMA_FRAC),64);
              if not fits(product,63) or not fits(long_product,63) then status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
              else results(feature)<=sat(result_value,C_STATE_BITS);finished_value:=true;saturation_occurred:=not fits(result_value,C_STATE_BITS);end if;
            elsif G_OPERATION="position" then
              result_value:=resize(values(feature),64)+signed(param_rsp_i.data);
              results(feature)<=sat(result_value,C_STATE_BITS);finished_value:=true;saturation_occurred:=not fits(result_value,C_STATE_BITS);
            else first_knot<=resize(signed(param_rsp_i.data),C_STATE_BITS);request_reg.address<=request_reg.address+1;phase<=KNOT_REQ;end if;
          end if;
          when KNOT_REQ => if param_req_ready_i='1' then phase<=KNOT_RSP;end if;
          when KNOT_RSP => if param_rsp_valid_i='1' then
            if param_rsp_i.error='1' or param_rsp_i.tag/=request_reg.tag or not fits(signed(param_rsp_i.data),C_STATE_BITS) then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              frac:=to_integer(values(feature))-(knot_index-4)*2**C_STATE_FRAC;
              term:=signed(param_rsp_i.data)-resize(first_knot,64);
              long_product:=term*to_signed(frac,64);
              result_value:=resize(first_knot,64)+resize(rshift_even(long_product,C_STATE_FRAC),64);
              results(feature)<=sat(result_value,C_STATE_BITS);finished_value:=true;saturation_occurred:=not fits(result_value,C_STATE_BITS);
            end if;
          end if;
          when EMIT => if m_ready_i='1' then
            if output_base+C_LANES<command.features then output_base<=output_base+C_LANES;
            elsif row+1<command.tokens then row<=row+1;input_base<=0;sum_squares<=(others=>'0');phase<=COLLECT;
            else status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;end if;
          end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
        if finished_value then
          saturation_events_o<=to_unsigned(boolean'pos(saturation_occurred),16);
          if feature+1=command.features then output_base<=0;phase<=EMIT;
          else feature<=feature+1;phase<=VALUE_PREPARE;end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
