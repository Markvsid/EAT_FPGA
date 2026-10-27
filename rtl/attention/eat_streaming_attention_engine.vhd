-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Orchestrate head/query/key tiles and online state; never allocate a full score matrix.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_streaming_attention_engine is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in attention_cmd_t;
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

architecture rtl of eat_streaming_attention_engine is
  constant HEAD_WIDTH : positive := C_WIDTH/C_HEADS;
  type tensor_t is array(0 to C_MAX_TOKENS-1) of act_vec_t(0 to C_WIDTH-1);
  type tile_scores_t is array(0 to C_ATTENTION_TILE-1) of score_t;
  type tile_probs_t is array(0 to C_ATTENTION_TILE-1) of exp_t;
  type row_state_t is array(0 to HEAD_WIDTH-1) of av_acc_t;
  type phase_t is (IDLE,LOAD_REQ,LOAD_RSP,INIT_ROW,DOT_PRODUCT,SCALE_SCORE,MAX_TILE,EXP_PREPARE,EXP_REQ,EXP_RSP,UPDATE_DENOMINATOR,UPDATE_VALUES,FINALIZE_VALUES,FINAL_DIV_START,FINAL_DIV_WAIT,EMIT,DONE);
  signal phase : phase_t := IDLE;
  signal command : attention_cmd_t := C_ATTENTION_CMD_IDLE;
  signal q,k,v : tensor_t;
  signal plane : natural range 0 to 2 := 0;
  signal load_token : natural range 0 to C_MAX_TOKENS-1 := 0;
  signal load_feature : natural range 0 to C_WIDTH-1 := 0;
  signal head : natural range 0 to C_HEADS-1 := 0;
  signal query_token,key_base : natural range 0 to C_MAX_TOKENS-1 := 0;
  signal key_lane : natural range 0 to C_ATTENTION_TILE-1 := 0;
  signal feature : natural range 0 to HEAD_WIDTH-1 := 0;
  signal output_base : natural range 0 to HEAD_WIDTH-1 := 0;
  signal dot : signed(63 downto 0) := (others=>'0');
  signal scores : tile_scores_t;
  signal probabilities : tile_probs_t;
  signal row_max,next_max : score_t;
  signal previous_max_valid : std_logic := '0';
  signal alpha : exp_t;
  signal exponential_index : natural range 0 to C_ATTENTION_TILE := 0;
  signal exp_address : mem_addr_t;
  signal denominator : normalizer_t := (others=>'0');
  signal weighted : row_state_t := (others=>(others=>'0'));
  signal output_row : state_vec_t(0 to HEAD_WIDTH-1);
  signal request : mem_req_t;

  signal divide_numerator:wide_t;
  signal divide_ready,divide_valid,divide_zero,divide_overflow:std_logic;
  signal divide_result:wide_t;
begin
  divider:entity work.eat_round_divide(rtl) port map(clk_i=>clk_i,rst_i=>rst_i,s_valid_i=>flag(phase=FINAL_DIV_START),s_ready_o=>divide_ready,
    numerator_i=>divide_numerator,denominator_i=>resize(unsigned(denominator),64),m_valid_o=>divide_valid,m_ready_i=>flag(phase=FINAL_DIV_WAIT),
    quotient_o=>divide_result,divide_by_zero_o=>divide_zero,overflow_o=>divide_overflow);
  active_products_o<=to_unsigned(1,16) when phase=DOT_PRODUCT and rst_i='0' else
    to_unsigned(minimum(C_ATTENTION_TILE,command.tokens-key_base),16) when phase=UPDATE_VALUES and rst_i='0' else (others=>'0');
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;done_valid_o<=flag(phase=DONE) and not rst_i;
  m_valid_o<=flag(phase=EMIT) and not rst_i;
  mem_req_valid_o<=flag(phase=LOAD_REQ) and not rst_i;mem_req_o<=request;
  mem_rsp_ready_o<=flag(phase=LOAD_RSP) and not rst_i;
  param_req_valid_o<=flag(phase=EXP_REQ) and not rst_i;
  param_req_o<=(CONST_EXP,exp_address,command.ctx.model_bank,(others=>'0'));
  param_rsp_ready_o<=flag(phase=EXP_RSP) and not rst_i;
  process(all)
    variable base : mem_addr_t;
    variable beat : state_beat_t;
  begin
    base:=command.q_addr;if plane=1 then base:=command.k_addr;elsif plane=2 then base:=command.v_addr;end if;
    request<=C_MEM_REQ_IDLE;request.address<=base+load_token*C_WIDTH+load_feature;
    beat:=C_STATE_BEAT_IDLE;beat.ctx:=command.ctx;beat.token:=query_token;beat.feature_base:=head*HEAD_WIDTH+output_base;beat.keep:=(others=>'1');
    beat.last:=flag(query_token+1=command.tokens and head+1=C_HEADS and output_base+C_LANES=HEAD_WIDTH);
    for i in 0 to C_LANES-1 loop if output_base+i<HEAD_WIDTH then beat.data(i):=output_row(output_base+i);end if;end loop;
    m_data_o<=beat;
  end process;
  process(clk_i)
    variable total,restored,first_round,scaled,delta,address_value,contribution,previous_scaled,next_value,numerator,final_value : signed(63 downto 0);
    variable product : signed(127 downto 0);
    variable local_max : score_t;
    variable address,actual_keys : natural;
    variable value_exp : exp_t;
    variable bad : boolean;
  begin
    if rising_edge(clk_i) then
      saturation_events_o<=(others=>'0');
      if rst_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;command<=C_ATTENTION_CMD_IDLE;
      else
        case phase is
          when IDLE => if cmd_valid_i='1' then
            command<=cmd_i;plane<=0;load_token<=0;load_feature<=0;head<=0;query_token<=0;
            if cmd_i.tokens=0 or to_integer(cmd_i.q_shift)<0 or to_integer(cmd_i.q_shift)>16 or
               to_integer(cmd_i.k_shift)<0 or to_integer(cmd_i.k_shift)>16 or to_integer(cmd_i.v_shift)<0 or to_integer(cmd_i.v_shift)>16 or
               to_integer(cmd_i.ctx.model_bank)>=C_MODEL_BANKS or
               to_integer(cmd_i.q_addr)+cmd_i.tokens*C_WIDTH>2**C_MEM_ADDR_BITS or
               to_integer(cmd_i.k_addr)+cmd_i.tokens*C_WIDTH>2**C_MEM_ADDR_BITS or
               to_integer(cmd_i.v_addr)+cmd_i.tokens*C_WIDTH>2**C_MEM_ADDR_BITS then
              status_o<=('0','1','1',ERR_DIMENSION,cmd_i.ctx);phase<=DONE;
            else status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);phase<=LOAD_REQ;end if;
          end if;
          when LOAD_REQ => if mem_req_ready_i='1' then phase<=LOAD_RSP;end if;
          when LOAD_RSP => if mem_rsp_valid_i='1' then
            if mem_rsp_i.error='1' or mem_rsp_i.tag/=request.tag or not fits(signed(mem_rsp_i.data),C_ACT_BITS) then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              if plane=0 then q(load_token)(load_feature)<=resize(signed(mem_rsp_i.data),C_ACT_BITS);
              elsif plane=1 then k(load_token)(load_feature)<=resize(signed(mem_rsp_i.data),C_ACT_BITS);
              else v(load_token)(load_feature)<=resize(signed(mem_rsp_i.data),C_ACT_BITS);end if;
              if load_feature+1=C_WIDTH then
                load_feature<=0;
                if load_token+1=command.tokens then
                  load_token<=0;
                  if plane=2 then phase<=INIT_ROW;else plane<=plane+1;phase<=LOAD_REQ;end if;
                else load_token<=load_token+1;phase<=LOAD_REQ;end if;
              else load_feature<=load_feature+1;phase<=LOAD_REQ;end if;
            end if;
          end if;
          when INIT_ROW =>
            key_base<=0;key_lane<=0;feature<=0;dot<=(others=>'0');weighted<=(others=>(others=>'0'));denominator<=(others=>'0');previous_max_valid<='0';phase<=DOT_PRODUCT;
          when DOT_PRODUCT =>
            total:=dot+resize(q(query_token)(head*HEAD_WIDTH+feature)*k(key_base+key_lane)(head*HEAD_WIDTH+feature),64);
            dot<=total;
            if feature+1=HEAD_WIDTH then phase<=SCALE_SCORE;else feature<=feature+1;end if;
          when SCALE_SCORE =>
            restored:=shift_left(dot,to_integer(command.q_shift)+to_integer(command.k_shift));
            first_round:=rshift_even(restored,C_STATE_FRAC);
            product:=first_round*to_signed(185364,64);
            scaled:=resize(rshift_even(product,20),64);
            if not fits(restored,C_QK_ACC_BITS) or not fits(scaled,C_SCORE_BITS) then
              status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else
              scores(key_lane)<=resize(scaled,C_SCORE_BITS);
              if key_lane+1=C_ATTENTION_TILE or key_base+key_lane+1=command.tokens then phase<=MAX_TILE;
              else key_lane<=key_lane+1;feature<=0;dot<=(others=>'0');phase<=DOT_PRODUCT;end if;
            end if;
          when MAX_TILE =>
            local_max:=scores(0);
            for i in 1 to C_ATTENTION_TILE-1 loop if key_base+i<command.tokens and scores(i)>local_max then local_max:=scores(i);end if;end loop;
            if previous_max_valid='1' and row_max>local_max then local_max:=row_max;end if;
            next_max<=local_max;exponential_index<=0;probabilities<=(others=>(others=>'0'));phase<=EXP_PREPARE;
          when EXP_PREPARE =>
            value_exp:=(others=>'0');
            if exponential_index=0 then
              if previous_max_valid='0' then delta:=to_signed(-65552,64);
              else delta:=resize(row_max,64)-resize(next_max,64);end if;
            else delta:=resize(scores(exponential_index-1),64)-resize(next_max,64);end if;
            address_value:=rshift_even(-delta,C_STATE_FRAC-8);
            if address_value>4096 then
              if exponential_index=0 then alpha<=(others=>'0');else probabilities(exponential_index-1)<=(others=>'0');end if;
              if exponential_index=C_ATTENTION_TILE or key_base+exponential_index=command.tokens then phase<=UPDATE_DENOMINATOR;
              else exponential_index<=exponential_index+1;end if;
            else exp_address<=resize(unsigned(address_value),C_MEM_ADDR_BITS);phase<=EXP_REQ;end if;
          when EXP_REQ => if param_req_ready_i='1' then phase<=EXP_RSP;end if;
          when EXP_RSP => if param_rsp_valid_i='1' then
            if param_rsp_i.error='1' or param_rsp_i.tag/=0 or unsigned(param_rsp_i.data)>2**C_EXP_FRAC then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              value_exp:=resize(unsigned(param_rsp_i.data),C_EXP_BITS);
              if exponential_index=0 then alpha<=value_exp;else probabilities(exponential_index-1)<=value_exp;end if;
              if exponential_index=C_ATTENTION_TILE or key_base+exponential_index=command.tokens then phase<=UPDATE_DENOMINATOR;
              else exponential_index<=exponential_index+1;phase<=EXP_PREPARE;end if;
            end if;
          end if;
          when UPDATE_DENOMINATOR =>
            product:=resize(denominator,64)*signed(resize(alpha,64));total:=resize(rshift_even(product,C_EXP_FRAC),64);
            for i in 0 to C_ATTENTION_TILE-1 loop if key_base+i<command.tokens then total:=total+signed(resize(probabilities(i),64));end if;end loop;
            if not fits(total,C_NORMALIZER_BITS) or total<=0 then status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else denominator<=resize(total,C_NORMALIZER_BITS);feature<=0;row_max<=next_max;previous_max_valid<='1';phase<=UPDATE_VALUES;end if;
          when UPDATE_VALUES =>
            contribution:=(others=>'0');
            for i in 0 to C_ATTENTION_TILE-1 loop
              if key_base+i<command.tokens then
                product:=signed(resize(probabilities(i),64))*shift_left(resize(v(key_base+i)(head*HEAD_WIDTH+feature),64),to_integer(command.v_shift));
                contribution:=contribution+resize(product,64);
              end if;
            end loop;
            product:=resize(weighted(feature),64)*signed(resize(alpha,64));previous_scaled:=resize(rshift_even(product,C_EXP_FRAC),64);
            next_value:=previous_scaled+rshift_even(contribution,C_EXP_FRAC);
            if not fits(contribution,62) or not fits(next_value,C_AV_ACC_BITS) then status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else
              weighted(feature)<=resize(next_value,C_AV_ACC_BITS);
              if feature+1=HEAD_WIDTH then
                if key_base+C_ATTENTION_TILE>=command.tokens then feature<=0;phase<=FINALIZE_VALUES;
                else key_base<=key_base+C_ATTENTION_TILE;key_lane<=0;feature<=0;dot<=(others=>'0');phase<=DOT_PRODUCT;end if;
              else feature<=feature+1;end if;
            end if;
          when FINALIZE_VALUES =>
            numerator:=shift_left(resize(weighted(feature),64),C_EXP_FRAC);
            if not fits(numerator,62) or denominator<=0 then status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else divide_numerator<=numerator;phase<=FINAL_DIV_START;end if;
          when FINAL_DIV_START => if divide_ready='1' then phase<=FINAL_DIV_WAIT;end if;
          when FINAL_DIV_WAIT => if divide_valid='1' then
            if divide_zero='1' or divide_overflow='1' then status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else
              output_row(feature)<=sat(divide_result,C_STATE_BITS);
              if not fits(divide_result,C_STATE_BITS) then saturation_events_o<=to_unsigned(1,16);end if;
              if feature+1=HEAD_WIDTH then output_base<=0;phase<=EMIT;else feature<=feature+1;phase<=FINALIZE_VALUES;end if;
            end if;
          end if;
          when EMIT => if m_ready_i='1' then
            if output_base+C_LANES<HEAD_WIDTH then output_base<=output_base+C_LANES;
            elsif head+1<C_HEADS then head<=head+1;phase<=INIT_ROW;
            elsif query_token+1<command.tokens then head<=0;query_token<=query_token+1;phase<=INIT_ROW;
            else status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;end if;
          end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
