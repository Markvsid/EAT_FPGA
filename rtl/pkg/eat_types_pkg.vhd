-- Proposed VHDL-2008 interface vocabulary. Counts include zero for idle only.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;

package eat_types_pkg is
  subtype act_t is signed(C_ACT_BITS-1 downto 0);
  subtype state_t is signed(C_STATE_BITS-1 downto 0);
  subtype acc_t is signed(C_ACC_BITS-1 downto 0);
  subtype multiplier_t is signed(C_MULT_BITS-1 downto 0);
  subtype gamma_t is signed(C_GAMMA_BITS-1 downto 0);
  subtype wide_t is signed(63 downto 0);
  subtype shift_t is signed(7 downto 0);
  subtype exp_t is unsigned(C_EXP_BITS-1 downto 0);
  subtype qk_acc_t is signed(C_QK_ACC_BITS-1 downto 0);
  subtype score_t is signed(C_SCORE_BITS-1 downto 0);
  subtype av_acc_t is signed(C_AV_ACC_BITS-1 downto 0);
  subtype normalizer_t is signed(C_NORMALIZER_BITS-1 downto 0);
  subtype group_score_t is signed(C_GROUP_SCORE_BITS-1 downto 0);
  subtype summary_num_t is signed(C_SUMMARY_NUM_BITS-1 downto 0);
  subtype lane_mask_t is std_logic_vector(C_LANES-1 downto 0);
  subtype mem_addr_t is unsigned(C_MEM_ADDR_BITS-1 downto 0);
  subtype bank_id_t is unsigned(3 downto 0);
  subtype identity_t is std_logic_vector(255 downto 0);
  subtype token_count_t is natural range 0 to C_MAX_TOKENS;
  subtype token_index_t is natural range 0 to C_MAX_TOKENS-1;
  subtype feature_index_t is natural range 0 to C_MAX_MATRIX_COLS-1;
  subtype layer_index_t is natural range 0 to C_LAYERS-1;
  type mode_t is (MODE_QUALITY, MODE_BALANCED, MODE_ENERGY_SAVER);
  type workload_t is (WORKLOAD_HAR, WORKLOAD_SPEECH);
  type error_t is (ERR_NONE, ERR_STUB, ERR_BUSY, ERR_DIMENSION, ERR_MODE,
                  ERR_IDENTITY, ERR_LOAD_RANGE, ERR_FRAME, ERR_OVERFLOW, ERR_PROTOCOL);
  type encoder_stage_t is (ST_EMBED,ST_POSITION,ST_NORM1,ST_QKV,ST_ATTENTION,
    ST_PROJECTION,ST_RESIDUAL1,ST_NORM2,ST_FFN1,ST_PWL,ST_FFN2,ST_RESIDUAL2,
    ST_SCORER,ST_GATE,ST_FINAL_NORM,ST_POOL,ST_CLASSIFIER,ST_OUTPUT);
  type operation_t is (OP_EMBED, OP_QKV, OP_PROJECTION, OP_FFN1, OP_FFN2,
                       OP_SCORE, OP_FINAL_CLASSIFIER, OP_EXIT_CLASSIFIER);
  type constant_kind_t is (CONST_WEIGHT, CONST_BIAS, CONST_MULTIPLIER, CONST_GAMMA,
                          CONST_POSITION, CONST_SHIFT, CONST_EXP, CONST_RSQRT, CONST_PWL, CONST_PROFILE);
  type transfer_kind_t is (TRANSFER_INPUT, TRANSFER_CONSTANTS);
  type activation_kind_t is (ACT_PWL_SILU);
  type counter_event_t is (EV_CYCLE, EV_INFERENCE, EV_ACTIVE_MAC, EV_BUBBLE,
                          EV_MEMORY_STALL, EV_NONLINEAR_STALL, EV_SATURATION,
                          EV_INPUT_BYTE, EV_OUTPUT_BYTE, EV_RETAINED_TOKEN, EV_SUMMARY_TOKEN);
  type context_t is record
    inference_id : unsigned(31 downto 0);
    mode : mode_t;
    workload : workload_t;
    model_bank : bank_id_t;
  end record;
  constant C_CONTEXT_IDLE : context_t := ((others => '0'), MODE_QUALITY, WORKLOAD_HAR, (others => '0'));
  type state_vec_t is array(natural range <>) of state_t;
  type act_vec_t is array(natural range <>) of act_t;
  type acc_vec_t is array(natural range <>) of acc_t;
  type wide_vec_t is array(natural range <>) of wide_t;
  type exp_vec_t is array(natural range <>) of exp_t;
  type score_vec_t is array(natural range <>) of score_t;
  type av_vec_t is array(natural range <>) of av_acc_t;
  type multiplier_vec_t is array(natural range <>) of multiplier_t;
  type gamma_vec_t is array(natural range <>) of gamma_t;
  type acc_tile_t is array(0 to C_ARRAY_ROWS-1) of acc_vec_t(0 to C_ARRAY_COLS-1);
  type state_tile_t is array(0 to C_ARRAY_ROWS-1) of state_vec_t(0 to C_ARRAY_COLS-1);
  type state_beat_t is record
    data : state_vec_t(0 to C_LANES-1);
    keep : lane_mask_t;
    token : token_index_t;
    feature_base : feature_index_t;
    last : std_logic;
    ctx : context_t;
  end record;
  constant C_STATE_BEAT_IDLE : state_beat_t :=
    ((others => (others => '0')), (others => '0'), 0, 0, '0', C_CONTEXT_IDLE);
  type act_beat_t is record
    data : act_vec_t(0 to C_LANES-1);
    keep : lane_mask_t;
    token : token_index_t;
    feature_base : feature_index_t;
    last : std_logic;
    ctx : context_t;
  end record;
  constant C_ACT_BEAT_IDLE : act_beat_t :=
    ((others => (others => '0')), (others => '0'), 0, 0, '0', C_CONTEXT_IDLE);
  type score_beat_t is record
    data : score_vec_t(0 to C_LANES-1);
    keep : lane_mask_t;
    query_token : token_index_t;
    key_base : token_index_t;
    head : natural range 0 to C_HEADS-1;
    last_tile : std_logic;
    ctx : context_t;
  end record;
  constant C_SCORE_BEAT_IDLE : score_beat_t :=
    ((others => (others => '0')), (others => '0'), 0, 0, 0, '0', C_CONTEXT_IDLE);
  type exp_beat_t is record
    data : exp_vec_t(0 to C_LANES-1);
    keep : lane_mask_t;
    last_tile : std_logic;
    ctx : context_t;
  end record;
  constant C_EXP_BEAT_IDLE : exp_beat_t := ((others => (others => '0')), (others => '0'), '0', C_CONTEXT_IDLE);
  type matrix_cmd_t is record
    rows : token_count_t;
    columns : natural range 0 to C_MAX_MATRIX_COLS;
    reduction : natural range 0 to C_MAX_REDUCTION;
    weight_bits : natural range 0 to 8;
    activation_shift : shift_t;
    source_addr, destination_addr, weight_addr, bias_addr, multiplier_addr : mem_addr_t;
    layer : layer_index_t;
    operation : operation_t;
    ctx : context_t;
  end record;
  constant C_MATRIX_CMD_IDLE : matrix_cmd_t := (0, 0, 0, 0, (others => '0'),
    (others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'), 0, OP_EMBED, C_CONTEXT_IDLE);
  type vector_cmd_t is record
    tokens : token_count_t;
    features : natural range 0 to C_MAX_MATRIX_COLS;
    gamma_addr : mem_addr_t;
    layer : layer_index_t;
    ctx : context_t;
  end record;
  constant C_VECTOR_CMD_IDLE : vector_cmd_t := (0, 0, (others => '0'), 0, C_CONTEXT_IDLE);
  type attention_cmd_t is record
    tokens : token_count_t;
    q_shift, k_shift, v_shift : shift_t;
    q_addr, k_addr, v_addr, destination_addr : mem_addr_t;
    layer : layer_index_t;
    ctx : context_t;
  end record;
  constant C_ATTENTION_CMD_IDLE : attention_cmd_t := (0, (others => '0'), (others => '0'), (others => '0'),
    (others => '0'), (others => '0'), (others => '0'), (others => '0'), 0, C_CONTEXT_IDLE);
  type gate_cmd_t is record
    tokens : token_count_t;
    keep_groups : natural range 0 to C_MAX_TOKENS/C_GROUP_SIZE;
    use_rts : std_logic;
    ctx : context_t;
  end record;
  constant C_GATE_CMD_IDLE : gate_cmd_t := (0, 0, '0', C_CONTEXT_IDLE);
  type group_decision_t is record
    retained : std_logic_vector(C_MAX_TOKENS/C_GROUP_SIZE-1 downto 0);
    output_tokens : token_count_t;
    ctx : context_t;
  end record;
  constant C_GROUP_DECISION_IDLE : group_decision_t := ((others => '0'), 0, C_CONTEXT_IDLE);
  type transfer_cmd_t is record
    kind : transfer_kind_t;
    bytes : unsigned(31 downto 0);
    address : mem_addr_t;
    constant_kind : constant_kind_t;
    ctx : context_t;
  end record;
  constant C_TRANSFER_CMD_IDLE : transfer_cmd_t := (TRANSFER_INPUT, (others => '0'), (others => '0'), CONST_WEIGHT, C_CONTEXT_IDLE);
  type param_req_t is record
    kind : constant_kind_t;
    address : mem_addr_t;
    bank : bank_id_t;
    tag : unsigned(15 downto 0);
  end record;
  constant C_PARAM_REQ_IDLE : param_req_t := (CONST_WEIGHT, (others => '0'), (others => '0'), (others => '0'));
  type param_rsp_t is record
    data : std_logic_vector(63 downto 0);
    tag : unsigned(15 downto 0);
    error : std_logic;
  end record;
  constant C_PARAM_RSP_IDLE : param_rsp_t := ((others => '0'), (others => '0'), '0');
  type mem_req_t is record
    address : mem_addr_t;
    write_data : std_logic_vector(63 downto 0);
    write_strobe : std_logic_vector(7 downto 0);
    write_enable : std_logic;
    tag : unsigned(15 downto 0);
  end record;
  constant C_MEM_REQ_IDLE : mem_req_t := ((others => '0'), (others => '0'), (others => '0'), '0', (others => '0'));
  type mem_rsp_t is record
    data : std_logic_vector(63 downto 0);
    tag : unsigned(15 downto 0);
    error : std_logic;
  end record;
  constant C_MEM_RSP_IDLE : mem_rsp_t := ((others => '0'), (others => '0'), '0');
  type mem_req_array_t is array(natural range <>) of mem_req_t;
  type mem_rsp_array_t is array(natural range <>) of mem_rsp_t;
  type control_request_t is record
    mode : mode_t;
    workload : workload_t;
    model_bank : bank_id_t;
    expected_identity : identity_t;
    inference_id : unsigned(31 downto 0);
  end record;
  constant C_CONTROL_REQUEST_IDLE : control_request_t :=
    (MODE_QUALITY, WORKLOAD_HAR, (others => '0'), (others => '0'), (others => '0'));
  type status_t is record
    busy, done, error : std_logic;
    code : error_t;
    ctx : context_t;
  end record;
  constant C_STATUS_IDLE : status_t := ('0', '0', '0', ERR_NONE, C_CONTEXT_IDLE);
  constant C_STATUS_STUB : status_t := ('0', '0', '1', ERR_STUB, C_CONTEXT_IDLE);
  type counter_snapshot_t is array(counter_event_t) of unsigned(63 downto 0);
  constant C_COUNTERS_IDLE : counter_snapshot_t := (others => (others => '0'));
end package;
