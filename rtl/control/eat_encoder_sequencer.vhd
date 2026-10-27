-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Issue embedding/position, pre-norm attention/FFN/residuals, block-one gate, final norm/pool/head.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;
use work.eat_image_pkg.all;

entity eat_encoder_sequencer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    start_valid_i : in std_logic;
    start_ready_o : out std_logic;
    ctx_i : in context_t;
    profile_i : in profile_t;
    stage_o : out encoder_stage_t;
    layer_o : out layer_index_t;
    tokens_o : out token_count_t;
    matrix_valid_o : out std_logic;
    matrix_ready_i : in std_logic;
    matrix_o : out matrix_cmd_t;
    vector_valid_o : out std_logic;
    vector_ready_i : in std_logic;
    vector_o : out vector_cmd_t;
    attention_valid_o : out std_logic;
    attention_ready_i : in std_logic;
    attention_o : out attention_cmd_t;
    gate_valid_o : out std_logic;
    gate_ready_i : in std_logic;
    gate_o : out gate_cmd_t;
    unit_status_i : in status_t;
    unit_done_valid_i : in std_logic;
    unit_done_ready_o : out std_logic;
    output_accepted_i : in std_logic;
    status_o : out status_t
  );
end entity;

architecture rtl of eat_encoder_sequencer is
  type phase_t is (IDLE,ISSUE,WAIT_UNIT,WAIT_OUTPUT);
  signal phase : phase_t := IDLE;
  signal stage : encoder_stage_t := ST_EMBED;
  signal layer : layer_index_t := 0;
  signal tokens : token_count_t := 0;
  signal ctx : context_t := C_CONTEXT_IDLE;
  signal selected_ready : std_logic;

begin
  start_ready_o<=flag(phase=IDLE) and not rst_i;stage_o<=stage;layer_o<=layer;tokens_o<=tokens;
  unit_done_ready_o<=flag(phase=WAIT_UNIT) and not rst_i;
  process(all)
    variable matrix:matrix_cmd_t;variable vector:vector_cmd_t;variable attention:attention_cmd_t;variable gate:gate_cmd_t;
    variable slot,base : natural;
  begin
    matrix:=C_MATRIX_CMD_IDLE;vector:=C_VECTOR_CMD_IDLE;attention:=C_ATTENTION_CMD_IDLE;gate:=C_GATE_CMD_IDLE;
    matrix.ctx:=ctx;matrix.layer:=layer;matrix.rows:=tokens;matrix.columns:=128;matrix.reduction:=128;
    vector.ctx:=ctx;vector.layer:=layer;vector.tokens:=tokens;vector.features:=128;
    attention.ctx:=ctx;attention.layer:=layer;attention.tokens:=tokens;
    attention.q_addr:=to_unsigned(0,C_MEM_ADDR_BITS);
    attention.k_addr:=to_unsigned(C_MAX_TOKENS*C_WIDTH,C_MEM_ADDR_BITS);attention.v_addr:=to_unsigned(2*C_MAX_TOKENS*C_WIDTH,C_MEM_ADDR_BITS);
    attention.q_shift:=resize(profile_i(40+3*layer),8);attention.k_shift:=resize(profile_i(41+3*layer),8);attention.v_shift:=resize(profile_i(42+3*layer),8);
    gate.ctx:=ctx;gate.tokens:=tokens;
    if number(profile_i,11)<=8 then gate.keep_groups:=number(profile_i,11);end if;gate.use_rts:=flag(profile_i(12)=1);
    slot:=0;matrix_valid_o<='0';vector_valid_o<='0';attention_valid_o<='0';gate_valid_o<='0';selected_ready<='0';
    case stage is
      when ST_EMBED =>
        matrix.operation:=OP_EMBED;matrix.reduction:=36;if ctx.workload=WORKLOAD_SPEECH then matrix.reduction:=80;end if;
        matrix_valid_o<=flag(phase=ISSUE) and not rst_i;selected_ready<=matrix_ready_i;
      when ST_QKV => slot:=1+4*layer;matrix.operation:=OP_QKV;matrix.columns:=384;matrix_valid_o<=flag(phase=ISSUE) and not rst_i;selected_ready<=matrix_ready_i;
      when ST_PROJECTION => slot:=2+4*layer;matrix.operation:=OP_PROJECTION;matrix_valid_o<=flag(phase=ISSUE) and not rst_i;selected_ready<=matrix_ready_i;
      when ST_FFN1 => slot:=3+4*layer;matrix.operation:=OP_FFN1;matrix.columns:=256;matrix_valid_o<=flag(phase=ISSUE) and not rst_i;selected_ready<=matrix_ready_i;
      when ST_FFN2 => slot:=4+4*layer;matrix.operation:=OP_FFN2;matrix.reduction:=256;matrix_valid_o<=flag(phase=ISSUE) and not rst_i;selected_ready<=matrix_ready_i;
      when ST_SCORER => slot:=17;matrix.operation:=OP_SCORE;matrix.columns:=1;matrix_valid_o<=flag(phase=ISSUE) and not rst_i;selected_ready<=matrix_ready_i;
      when ST_CLASSIFIER =>
        slot:=18;matrix.operation:=OP_FINAL_CLASSIFIER;if ctx.mode=MODE_ENERGY_SAVER then slot:=19;matrix.operation:=OP_EXIT_CLASSIFIER;end if;
        matrix.rows:=1;matrix.columns:=6;if ctx.workload=WORKLOAD_SPEECH then matrix.columns:=35;end if;
        matrix_valid_o<=flag(phase=ISSUE) and not rst_i;selected_ready<=matrix_ready_i;
      when ST_ATTENTION => attention_valid_o<=flag(phase=ISSUE) and not rst_i;selected_ready<=attention_ready_i;
      when ST_GATE => gate_valid_o<=flag(phase=ISSUE) and not rst_i;selected_ready<=gate_ready_i;
      when ST_POSITION | ST_NORM1 | ST_RESIDUAL1 | ST_NORM2 | ST_PWL | ST_RESIDUAL2 | ST_FINAL_NORM | ST_POOL =>
        if stage=ST_NORM1 then vector.gamma_addr:=to_unsigned(layer*256,C_MEM_ADDR_BITS);
        elsif stage=ST_NORM2 then vector.gamma_addr:=to_unsigned(layer*256+128,C_MEM_ADDR_BITS);
        elsif stage=ST_FINAL_NORM then vector.gamma_addr:=to_unsigned(number(profile_i,5)*256,C_MEM_ADDR_BITS);
        elsif stage=ST_PWL then vector.features:=256;end if;
        vector_valid_o<=flag(phase=ISSUE) and not rst_i;selected_ready<=vector_ready_i;
      when ST_OUTPUT => null;
    end case;
    base:=64+5*slot;matrix.weight_addr:=resize(unsigned(profile_i(base)),C_MEM_ADDR_BITS);matrix.bias_addr:=resize(unsigned(profile_i(base+1)),C_MEM_ADDR_BITS);matrix.multiplier_addr:=resize(unsigned(profile_i(base+2)),C_MEM_ADDR_BITS);
    matrix.activation_shift:=resize(profile_i(base+3),8);if number(profile_i,base+4)<=8 then matrix.weight_bits:=number(profile_i,base+4);end if;
    matrix_o<=matrix;vector_o<=vector;attention_o<=attention;gate_o<=gate;
  end process;
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;stage<=ST_EMBED;layer<=0;tokens<=0;ctx<=C_CONTEXT_IDLE;status_o<=C_STATUS_IDLE;
      else
        case phase is
          when IDLE => if start_valid_i='1' then
            ctx<=ctx_i;layer<=0;tokens<=32;stage<=ST_EMBED;phase<=ISSUE;status_o<=('1','0','0',ERR_NONE,ctx_i);
          end if;
          when ISSUE => if selected_ready='1' then phase<=WAIT_UNIT;end if;
          when WAIT_UNIT => if unit_done_valid_i='1' then
            if unit_status_i.error='1' or unit_status_i.ctx/=ctx or unit_status_i.done/='1' then
              status_o<=('0','1','1',unit_status_i.code,ctx);if unit_status_i.error/='1' then status_o.code<=ERR_PROTOCOL;end if;phase<=IDLE;
            else
              phase<=ISSUE;
              case stage is
                when ST_EMBED => stage<=ST_POSITION;
                when ST_POSITION => stage<=ST_NORM1;
                when ST_NORM1 => stage<=ST_QKV;
                when ST_QKV => stage<=ST_ATTENTION;
                when ST_ATTENTION => stage<=ST_PROJECTION;
                when ST_PROJECTION => stage<=ST_RESIDUAL1;
                when ST_RESIDUAL1 => stage<=ST_NORM2;
                when ST_NORM2 => stage<=ST_FFN1;
                when ST_FFN1 => stage<=ST_PWL;
                when ST_PWL => stage<=ST_FFN2;
                when ST_FFN2 => stage<=ST_RESIDUAL2;
                when ST_RESIDUAL2 =>
                  if layer=0 and ctx.mode/=MODE_QUALITY then stage<=ST_SCORER;
                  elsif layer+1=number(profile_i,5) then stage<=ST_FINAL_NORM;
                  else layer<=layer+1;stage<=ST_NORM1;end if;
                when ST_SCORER => stage<=ST_GATE;
                when ST_GATE =>
                  tokens<=number(profile_i,11)*C_GROUP_SIZE+C_MAX_TOKENS/C_GROUP_SIZE-number(profile_i,11);layer<=layer+1;stage<=ST_NORM1;
                when ST_FINAL_NORM => stage<=ST_POOL;
                when ST_POOL => stage<=ST_CLASSIFIER;
                when ST_CLASSIFIER => stage<=ST_OUTPUT;phase<=WAIT_OUTPUT;
                when others => status_o<=('0','1','1',ERR_PROTOCOL,ctx);phase<=IDLE;
              end case;
            end if;
          end if;
          when WAIT_OUTPUT => if output_accepted_i='1' then status_o<=('0','1','0',ERR_NONE,ctx);phase<=IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
