-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Reusable embedding/QKV/projection/FFN/scorer/classifier matrix core.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_tensor_engine is
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
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t;
    param_req_valid_o : out std_logic;
    param_req_ready_i : in std_logic;
    param_req_o : out param_req_t;
    param_rsp_valid_i : in std_logic;
    param_rsp_ready_o : out std_logic;
    param_rsp_i : in param_rsp_t;
    active_products_o : out unsigned(15 downto 0);
    saturation_events_o : out unsigned(15 downto 0)
  );
end entity;

architecture rtl of eat_tensor_engine is
  type phase_t is (IDLE,ACT_REQ,ACT_RSP,WEIGHT_REQ,WEIGHT_RSP,MAC_STEP,MAC_RESULT,BIAS_REQ,BIAS_RSP,MULT_REQ,MULT_RSP,EMIT,DONE);
  signal phase : phase_t := IDLE;
  signal command : matrix_cmd_t;
  signal row_base : natural range 0 to C_MAX_TOKENS-1 := 0;
  signal col_base : natural range 0 to C_MAX_MATRIX_COLS-1 := 0;
  signal k_index : natural range 0 to C_MAX_REDUCTION-1 := 0;
  signal lane,row_lane,out_lane : natural range 0 to C_LANES-1 := 0;
  signal acts : act_vec_t(0 to C_ARRAY_ROWS-1);
  signal weights : act_vec_t(0 to C_ARRAY_COLS-1);
  signal row_mask : std_logic_vector(C_ARRAY_ROWS-1 downto 0);
  signal col_mask : std_logic_vector(C_ARRAY_COLS-1 downto 0);
  signal tile : acc_tile_t;
  signal array_values : acc_tile_t;
  signal array_valid,array_ready,array_overflow,array_input_valid : std_logic;
  signal first_k,last_k : std_logic;
  signal bias : acc_t;
  signal result_beat : state_beat_t := C_STATE_BEAT_IDLE;
  signal mem_request : mem_req_t;
  signal param_request : param_req_t;

begin
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;
  done_valid_o<=flag(phase=DONE) and not rst_i;
  m_valid_o<=flag(phase=EMIT) and not rst_i;
  m_data_o<=result_beat;
  mem_req_valid_o<=flag(phase=ACT_REQ) and not rst_i;
  mem_req_o<=mem_request;
  mem_rsp_ready_o<=flag(phase=ACT_RSP) and not rst_i;
  param_req_valid_o<=flag(phase=WEIGHT_REQ or phase=BIAS_REQ or phase=MULT_REQ) and not rst_i;
  param_req_o<=param_request;
  param_rsp_ready_o<=flag(phase=WEIGHT_RSP or phase=BIAS_RSP or phase=MULT_RSP) and not rst_i;
  array_input_valid<=flag(phase=MAC_STEP) and not rst_i;
  first_k<=flag(k_index=0);last_k<=flag(k_index=command.reduction-1);
  mac:entity work.eat_mac_array(rtl) port map(
    clk_i=>clk_i,rst_i=>rst_i,s_valid_i=>array_input_valid,s_ready_o=>array_ready,
    activations_i=>acts,weights_i=>weights,row_mask_i=>row_mask,column_mask_i=>col_mask,
    first_k_i=>first_k,last_k_i=>last_k,m_valid_o=>array_valid,
    m_ready_i=>flag(phase=MAC_RESULT),accumulators_o=>array_values,active_products_o=>active_products_o,overflow_o=>array_overflow);
  process(all)
    variable a : natural;
  begin
    row_mask<=(others=>'0');col_mask<=(others=>'0');
    for i in 0 to C_LANES-1 loop
      if row_base+i<command.rows then row_mask(i)<='1';end if;
      if col_base+i<command.columns then col_mask(i)<='1';end if;
    end loop;
    mem_request<=C_MEM_REQ_IDLE;
    mem_request.address<=command.source_addr+to_unsigned((row_base+lane)*command.reduction+k_index,C_MEM_ADDR_BITS);
    param_request<=C_PARAM_REQ_IDLE;param_request.bank<=command.ctx.model_bank;
    if phase=BIAS_REQ or phase=BIAS_RSP then
      param_request.kind<=CONST_BIAS;param_request.address<=command.bias_addr+to_unsigned(col_base+out_lane,C_MEM_ADDR_BITS);
    elsif phase=MULT_REQ or phase=MULT_RSP then
      param_request.kind<=CONST_MULTIPLIER;param_request.address<=command.multiplier_addr+to_unsigned(col_base+out_lane,C_MEM_ADDR_BITS);
    else
      param_request.kind<=CONST_WEIGHT;
      a:=(col_base+lane)*command.reduction+k_index;
      if command.weight_bits=4 then a:=a/16;else a:=a/8;end if;
      param_request.address<=command.weight_addr+to_unsigned(a,C_MEM_ADDR_BITS);
    end if;
  end process;
  process(clk_i)
    variable a,bits_per_word,nibble : natural;
    variable packed_weight : signed(63 downto 0);
    variable value : signed(74 downto 0);
    variable total : signed(C_ACC_BITS downto 0);
    variable product : signed(C_ACC_BITS+C_MULT_BITS downto 0);
    variable rounded_value : signed(C_ACC_BITS+C_MULT_BITS downto 0);
    variable end_source,end_weights : unsigned(C_MEM_ADDR_BITS downto 0);
  begin
    if rising_edge(clk_i) then
      saturation_events_o<=(others=>'0');
      if rst_i='1' then phase<=IDLE;command<=C_MATRIX_CMD_IDLE;status_o<=C_STATUS_IDLE;
      else
        case phase is
          when IDLE => if cmd_valid_i='1' then
            command<=cmd_i;row_base<=0;col_base<=0;k_index<=0;lane<=0;
            acts<=(others=>(others=>'0'));weights<=(others=>(others=>'0'));
            status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);
            end_source:=resize(cmd_i.source_addr,C_MEM_ADDR_BITS+1)+cmd_i.rows*cmd_i.reduction;
            bits_per_word:=8;if cmd_i.weight_bits=4 then bits_per_word:=16;end if;
            end_weights:=resize(cmd_i.weight_addr,C_MEM_ADDR_BITS+1)+(cmd_i.columns*cmd_i.reduction+bits_per_word-1)/bits_per_word;
            if cmd_i.rows=0 or cmd_i.columns=0 or cmd_i.reduction=0 or
               (cmd_i.weight_bits/=4 and cmd_i.weight_bits/=8) or (to_integer(cmd_i.activation_shift) < -50 or to_integer(cmd_i.activation_shift) > 50) or
               to_integer(cmd_i.ctx.model_bank)>=C_MODEL_BANKS or
               end_source>2**C_MEM_ADDR_BITS or end_weights>2**C_MEM_ADDR_BITS or
               to_integer(cmd_i.bias_addr)+cmd_i.columns>2**C_MEM_ADDR_BITS or to_integer(cmd_i.multiplier_addr)+cmd_i.columns>2**C_MEM_ADDR_BITS then
              status_o<=('0','1','1',ERR_DIMENSION,cmd_i.ctx);phase<=DONE;
            else phase<=ACT_REQ;end if;
          end if;
          when ACT_REQ => if mem_req_ready_i='1' then phase<=ACT_RSP;end if;
          when ACT_RSP => if mem_rsp_valid_i='1' then
            if mem_rsp_i.error='1' or mem_rsp_i.tag/=mem_request.tag or not fits(signed(mem_rsp_i.data),C_STATE_BITS) then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              value:=shift_even(resize(signed(mem_rsp_i.data),75),to_integer(command.activation_shift));
              acts(lane)<=sat(value,C_ACT_BITS);if col_base=0 and not fits(value,C_ACT_BITS) then saturation_events_o<=to_unsigned(1,16);end if;
              if lane=C_LANES-1 or row_base+lane+1=command.rows then lane<=0;phase<=WEIGHT_REQ;
              else lane<=lane+1;phase<=ACT_REQ;end if;
            end if;
          end if;
          when WEIGHT_REQ => if param_req_ready_i='1' then phase<=WEIGHT_RSP;end if;
          when WEIGHT_RSP => if param_rsp_valid_i='1' then
            if param_rsp_i.error='1' or param_rsp_i.tag/=param_request.tag then status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              -- Fixed slices after shifting avoid variable-slice synthesis tool failures.
              a:=(col_base+lane)*command.reduction+k_index;
              if command.weight_bits=4 then nibble:=a mod 16;packed_weight:=shift_right(signed(param_rsp_i.data),4*nibble);weights(lane)<=resize(packed_weight(3 downto 0),C_ACT_BITS);
              else nibble:=a mod 8;packed_weight:=shift_right(signed(param_rsp_i.data),8*nibble);weights(lane)<=packed_weight(7 downto 0);end if;
              if lane=C_LANES-1 or col_base+lane+1=command.columns then lane<=0;phase<=MAC_STEP;
              else lane<=lane+1;phase<=WEIGHT_REQ;end if;
            end if;
          end if;
          when MAC_STEP => if array_ready='1' then
            if k_index=command.reduction-1 then phase<=MAC_RESULT;
            else k_index<=k_index+1;phase<=ACT_REQ;end if;
          end if;
          when MAC_RESULT => if array_valid='1' then
            if array_overflow='1' then status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else tile<=array_values;row_lane<=0;out_lane<=0;phase<=BIAS_REQ;
              result_beat<=C_STATE_BEAT_IDLE;result_beat.keep<=col_mask;
              result_beat.token<=row_base;result_beat.feature_base<=col_base;result_beat.ctx<=command.ctx;
              result_beat.last<=flag(row_base=command.rows-1 and col_base+C_LANES>=command.columns);
            end if;
          end if;
          when BIAS_REQ => if param_req_ready_i='1' then phase<=BIAS_RSP;end if;
          when BIAS_RSP => if param_rsp_valid_i='1' then
            if param_rsp_i.error='1' or param_rsp_i.tag/=param_request.tag or not fits(signed(param_rsp_i.data),C_ACC_BITS) then
              status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else bias<=resize(signed(param_rsp_i.data),C_ACC_BITS);phase<=MULT_REQ;end if;
          end if;
          when MULT_REQ => if param_req_ready_i='1' then phase<=MULT_RSP;end if;
          when MULT_RSP => if param_rsp_valid_i='1' then
            total:=resize(tile(row_lane)(out_lane),total'length)+resize(bias,total'length);
            product:=total*resize(signed(param_rsp_i.data),C_MULT_BITS);
            rounded_value:=rshift_even(product,C_MULT_FRAC);
            if param_rsp_i.error='1' or param_rsp_i.tag/=param_request.tag or
               not fits(signed(param_rsp_i.data),C_MULT_BITS) or signed(param_rsp_i.data)<=0 or
               not fits(total,C_ACC_BITS) or not fits(product,63) then
              status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else
              result_beat.data(out_lane)<=sat(rounded_value,C_STATE_BITS);if not fits(rounded_value,C_STATE_BITS) then saturation_events_o<=to_unsigned(1,16);end if;
              if out_lane=C_LANES-1 or col_base+out_lane+1=command.columns then phase<=EMIT;
              else out_lane<=out_lane+1;phase<=BIAS_REQ;end if;
            end if;
          end if;
          when EMIT => if m_ready_i='1' then
            if row_lane<C_ARRAY_ROWS-1 and row_base+row_lane+1<command.rows then
              row_lane<=row_lane+1;out_lane<=0;phase<=BIAS_REQ;
              result_beat<=C_STATE_BEAT_IDLE;result_beat.keep<=col_mask;
              result_beat.token<=row_base+row_lane+1;result_beat.feature_base<=col_base;result_beat.ctx<=command.ctx;
              result_beat.last<=flag(row_base+row_lane+1=command.rows-1 and col_base+C_LANES>=command.columns);
            elsif col_base+C_LANES<command.columns then
              col_base<=col_base+C_LANES;k_index<=0;lane<=0;acts<=(others=>(others=>'0'));weights<=(others=>(others=>'0'));phase<=ACT_REQ;
            elsif row_base+C_ARRAY_ROWS<command.rows then
              row_base<=row_base+C_ARRAY_ROWS;col_base<=0;k_index<=0;lane<=0;acts<=(others=>(others=>'0'));weights<=(others=>(others=>'0'));phase<=ACT_REQ;
            else status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;end if;
          end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
