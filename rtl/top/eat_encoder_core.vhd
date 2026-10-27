-- Functional encoder integration. Profiles and buffers are owned for one inference.
-- Logical core integration boundary; child interconnect is not wired in this skeleton.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;
use work.eat_image_pkg.all;

entity eat_encoder_core is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    start_valid_i : in std_logic;
    start_ready_o : out std_logic;
    request_i : in control_request_t;
    logits_valid_o : out std_logic;
    logits_ready_i : in std_logic;
    logits_o : out state_beat_t;
    status_o : out status_t;
    event_valid_o : out std_logic;
    event_o : out counter_event_t;
    event_count_o : out unsigned(31 downto 0);
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
    param_rsp_i : in param_rsp_t
  );
end entity;

architecture rtl of eat_encoder_core is
  type phase_t is (IDLE,PROFILE_REQ,PROFILE_RSP,VALIDATE_PROFILE,RAW_REQ,RAW_RSP,START_SEQ,RUN,EMIT_STATS,SEND_LOGITS,WAIT_SEQ);
  signal phase : phase_t := IDLE;
  signal request : control_request_t := C_CONTROL_REQUEST_IDLE;
  signal ctx : context_t := C_CONTEXT_IDLE;
  signal profile_data : profile_t := (others=>(others=>'0'));
  signal profile_index : natural range 0 to C_IMAGE_PROFILE_WORDS-1 := 0;
  signal raw_word : natural range 0 to 319 := 0;
  type banked_t is array(natural range <>,natural range <>) of state_t;
  signal raw_mem : banked_t(0 to C_LANES-1,0 to 319);
  signal x_mem,n_mem,y_mem,att_mem : banked_t(0 to C_LANES-1,0 to 511);
  signal f_mem : banked_t(0 to C_LANES-1,0 to 1023);
  signal qkv_mem : banked_t(0 to C_LANES-1,0 to 1535);
  signal pool_mem : banked_t(0 to C_LANES-1,0 to 15);
  signal score_values,score_scratch : state_vec_t(0 to C_MAX_TOKENS-1);
  signal logit_values : state_vec_t(0 to C_MAX_CLASSES-1);
  signal unit_rst,seq_start_ready,seq_mvalid,seq_mready,seq_vvalid,seq_vready,seq_avalid,seq_aready,seq_gvalid,seq_gready : std_logic;
  signal seq_ack,unit_done,seq_output_accepted : std_logic;
  signal seq_status,unit_status : status_t;
  signal stage : encoder_stage_t := ST_EMBED;
  signal layer : layer_index_t;
  signal tokens : token_count_t;
  signal matrix_cmd : matrix_cmd_t;
  signal vector_cmd : vector_cmd_t;
  signal attention_cmd : attention_cmd_t;
  signal gate_cmd : gate_cmd_t;
  signal feed_a,feed_b,feed_scores : std_logic := '0';
  signal reader_a_valid,reader_b_valid:std_logic:='0';
  signal qkv_read_pending:std_logic:='0';
  signal qkv_read_data:state_t;signal qkv_read_shift:shift_t;signal qkv_read_tag:unsigned(15 downto 0);
  signal read_a_token,read_b_token,score_token : natural range 0 to C_MAX_TOKENS-1 := 0;
  signal read_a_feature,read_b_feature : natural range 0 to C_MAX_MATRIX_COLS-1 := 0;
  signal read_features : natural range 0 to C_MAX_MATRIX_COLS;
  signal reader_a,reader_b,scorer_input : state_beat_t;
  signal reader_a_ready,reader_b_ready : std_logic;
  signal gate_start,group_valid,group_ready,group_last,decision_valid,decision_ready : std_logic;
  signal group_score : group_score_t;
  signal group_index : natural range 0 to C_MAX_TOKENS/C_GROUP_SIZE-1;
  signal decision : group_decision_t;
  signal tensor_products,attention_products,tensor_sat,attention_sat,norm_sat,position_sat,pwl_sat,residual_sat,qkv_sat : unsigned(15 downto 0);
  signal bubble_count,memory_wait_count,nonlinear_wait_count:unsigned(31 downto 0):=(others=>'0');
  signal mac_count,saturation_count : unsigned(31 downto 0) := (others=>'0');
  signal stat_index : natural range 0 to 8 := 0;
  signal logit_base : natural range 0 to C_MAX_CLASSES-1 := 0;
  function matrix_stage(s:encoder_stage_t) return boolean is
  begin return s=ST_EMBED or s=ST_QKV or s=ST_PROJECTION or s=ST_FFN1 or s=ST_FFN2 or s=ST_SCORER or s=ST_CLASSIFIER;end;
  function norm_stage(s:encoder_stage_t) return boolean is
  begin return s=ST_NORM1 or s=ST_NORM2 or s=ST_FINAL_NORM;end;
  function residual_stage(s:encoder_stage_t) return boolean is
  begin return s=ST_RESIDUAL1 or s=ST_RESIDUAL2;end;
  function read_beat(memory:banked_t;token,base,features,count:natural;context_value:context_t) return state_beat_t is
    variable beat:state_beat_t;variable address:natural;
  begin
    beat:=C_STATE_BEAT_IDLE;beat.token:=token;beat.feature_base:=base;beat.ctx:=context_value;
    beat.last:=flag(token+1=count and base+C_LANES>=features);
    address:=token*(features/C_LANES)+base/C_LANES;
    for i in 0 to C_LANES-1 loop
      if base+i<features then beat.keep(i):='1';beat.data(i):=memory(i,address);end if;
    end loop;
    return beat;
  end;
  signal t_cr,t_dv,t_mv,t_sr : std_logic;
  signal t_status : status_t;
  signal t_data : state_beat_t;
  signal a_cr,a_dv,a_mv,a_sr : std_logic;
  signal a_status : status_t;
  signal a_data : state_beat_t;
  signal n_cr,n_dv,n_mv,n_sr : std_logic;
  signal n_status : status_t;
  signal n_data : state_beat_t;
  signal p_cr,p_dv,p_mv,p_sr : std_logic;
  signal p_status : status_t;
  signal p_data : state_beat_t;
  signal f_cr,f_dv,f_mv,f_sr : std_logic;
  signal f_status : status_t;
  signal f_data : state_beat_t;
  signal r_cr,r_dv,r_mv,r_sr : std_logic;
  signal r_status : status_t;
  signal r_data : state_beat_t;
  signal m_cr,m_dv,m_mv,m_sr : std_logic;
  signal m_status : status_t;
  signal m_data : state_beat_t;
  signal s_cr,s_dv,s_mv,s_sr : std_logic;
  signal s_status : status_t;
  signal s_data : state_beat_t;
  signal g_cr,g_dv,g_mv,g_sr : std_logic;
  signal g_status : status_t;
  signal g_data : state_beat_t;
  signal c_cr,c_dv,c_mv,c_sr : std_logic;
  signal c_status : status_t;
  signal c_data : state_beat_t;
  signal t_pv,t_pr,t_psv,t_psr : std_logic;
  signal t_pq : param_req_t;
  signal a_pv,a_pr,a_psv,a_psr : std_logic;
  signal a_pq : param_req_t;
  signal n_pv,n_pr,n_psv,n_psr : std_logic;
  signal n_pq : param_req_t;
  signal p_pv,p_pr,p_psv,p_psr : std_logic;
  signal p_pq : param_req_t;
  signal f_pv,f_pr,f_psv,f_psr : std_logic;
  signal f_pq : param_req_t;
  signal t_qv,t_qr,t_rv,t_rr : std_logic := '0';
  signal t_q : mem_req_t;
  signal t_rsp : mem_rsp_t := C_MEM_RSP_IDLE;
  signal a_qv,a_qr,a_rv,a_rr : std_logic := '0';
  signal a_q : mem_req_t;
  signal a_rsp : mem_rsp_t := C_MEM_RSP_IDLE;
  signal s_qv,s_qr,s_rv,s_rr : std_logic := '0';
  signal s_q : mem_req_t;
  signal s_rsp : mem_rsp_t := C_MEM_RSP_IDLE;
  signal c_qv,c_qr,c_rv,c_rr : std_logic := '0';
  signal c_q : mem_req_t;
  signal c_rsp : mem_rsp_t := C_MEM_RSP_IDLE;
  signal residual_b_ready:std_logic;
begin
  unit_rst<=rst_i or flag(phase/=START_SEQ and phase/=RUN and phase/=EMIT_STATS and phase/=SEND_LOGITS and phase/=WAIT_SEQ);
  start_ready_o<=flag(phase=IDLE) and not rst_i;
  mem_req_valid_o<=flag(phase=RAW_REQ) and not rst_i;
  mem_req_o<=(to_unsigned(raw_word,C_MEM_ADDR_BITS),(others=>'0'),x"00",'0',to_unsigned(raw_word,16));
  mem_rsp_ready_o<=flag(phase=RAW_RSP) and not rst_i;
  seq_output_accepted<=flag(phase=SEND_LOGITS) and logits_ready_i and flag(logit_base+C_LANES>=number(profile_data,10)) and not rst_i;
  logits_valid_o<=flag(phase=SEND_LOGITS) and not rst_i;
  process(all)
    variable beat:state_beat_t;
  begin
    beat:=C_STATE_BEAT_IDLE;beat.feature_base:=logit_base;beat.ctx:=ctx;
    beat.last:=flag(logit_base+C_LANES>=number(profile_data,10));
    for i in 0 to C_LANES-1 loop
      if logit_base+i<number(profile_data,10) and logit_base+i<C_MAX_CLASSES then beat.keep(i):='1';beat.data(i):=logit_values(logit_base+i);end if;
    end loop;
    logits_o<=beat;
  end process;
  process(all)
  begin
    event_valid_o<=flag(phase=EMIT_STATS) and not rst_i;event_o<=EV_ACTIVE_MAC;event_count_o<=mac_count;
    case stat_index is
      when 0 => event_o<=EV_ACTIVE_MAC;event_count_o<=mac_count;
      when 1 => event_o<=EV_SATURATION;event_count_o<=saturation_count;
      when 2 => event_o<=EV_INPUT_BYTE;if ctx.workload=WORKLOAD_HAR then event_count_o<=to_unsigned(1152,32);else event_count_o<=to_unsigned(2560,32);end if;
      when 3 => event_o<=EV_OUTPUT_BYTE;event_count_o<=to_unsigned(number(profile_data,10)*4,32);
      when 4 => event_o<=EV_RETAINED_TOKEN;event_count_o<=to_unsigned(number(profile_data,11)*C_GROUP_SIZE,32);
      when 5 => event_o<=EV_SUMMARY_TOKEN;
        if profile_data(12)=1 then event_count_o<=to_unsigned(C_MAX_TOKENS/C_GROUP_SIZE-number(profile_data,11),32);else event_count_o<=(others=>'0');end if;
      when 6 => event_o<=EV_BUBBLE;event_count_o<=bubble_count;
      when 7 => event_o<=EV_MEMORY_STALL;event_count_o<=memory_wait_count;
      when 8 => event_o<=EV_NONLINEAR_STALL;event_count_o<=nonlinear_wait_count;
    end case;
  end process;
  gate_start<=seq_gvalid and s_cr and g_cr and c_cr;
  seq_gready<=s_cr and g_cr and c_cr;
  seq_mready<=t_cr;seq_aready<=a_cr;
  process(all)
  begin
    seq_vready<='0';unit_done<='0';unit_status<=C_STATUS_IDLE;reader_a_ready<='0';reader_b_ready<='0';
    if matrix_stage(stage) then unit_done<=t_dv;unit_status<=t_status;
    elsif stage=ST_ATTENTION then unit_done<=a_dv;unit_status<=a_status;
    elsif norm_stage(stage) then seq_vready<=n_cr;unit_done<=n_dv;unit_status<=n_status;reader_a_ready<=n_sr;
    elsif stage=ST_POSITION then seq_vready<=p_cr;unit_done<=p_dv;unit_status<=p_status;reader_a_ready<=p_sr;
    elsif stage=ST_PWL then seq_vready<=f_cr;unit_done<=f_dv;unit_status<=f_status;reader_a_ready<=f_sr;
    elsif residual_stage(stage) then seq_vready<=r_cr;unit_done<=r_dv;unit_status<=r_status;reader_a_ready<=r_sr;reader_b_ready<=residual_b_ready;
    elsif stage=ST_POOL then seq_vready<=m_cr;unit_done<=m_dv;unit_status<=m_status;reader_a_ready<=m_sr;
    elsif stage=ST_GATE then
      reader_a_ready<=c_sr;unit_done<=s_dv and g_dv and c_dv;unit_status<=c_status;
      if s_dv='1' and s_status.error='1' then unit_done<='1';unit_status<=s_status;
      elsif g_dv='1' and g_status.error='1' then unit_done<='1';unit_status<=g_status;
      elsif c_dv='1' and c_status.error='1' then unit_done<='1';unit_status<=c_status;end if;
    end if;
  end process;
  read_features<=256 when stage=ST_PWL else 128;
  process(all)
    variable beat:state_beat_t;
  begin
    beat:=C_STATE_BEAT_IDLE;beat.ctx:=ctx;beat.token:=score_token;beat.keep:=x"01";beat.data(0):=score_values(score_token);beat.last:=flag(score_token+1=tokens);scorer_input<=beat;
  end process;
  sequencer:entity work.eat_encoder_sequencer(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    start_valid_i=>flag(phase=START_SEQ),
    start_ready_o=>seq_start_ready,
    ctx_i=>ctx,
    profile_i=>profile_data,
    stage_o=>stage,
    layer_o=>layer,
    tokens_o=>tokens,
    matrix_valid_o=>seq_mvalid,
    matrix_ready_i=>seq_mready,
    matrix_o=>matrix_cmd,
    vector_valid_o=>seq_vvalid,
    vector_ready_i=>seq_vready,
    vector_o=>vector_cmd,
    attention_valid_o=>seq_avalid,
    attention_ready_i=>seq_aready,
    attention_o=>attention_cmd,
    gate_valid_o=>seq_gvalid,
    gate_ready_i=>seq_gready,
    gate_o=>gate_cmd,
    unit_status_i=>unit_status,
    unit_done_valid_i=>unit_done,
    unit_done_ready_o=>seq_ack,
    output_accepted_i=>seq_output_accepted,
    status_o=>seq_status);
  unit_t:entity work.eat_tensor_engine(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    cmd_valid_i=>seq_mvalid,
    cmd_ready_o=>t_cr,
    cmd_i=>matrix_cmd,
    done_valid_o=>t_dv,
    done_ready_i=>seq_ack and flag(matrix_stage(stage)),
    status_o=>t_status,
    m_valid_o=>t_mv,
    m_ready_i=>flag(phase=RUN),
    m_data_o=>t_data,
    mem_req_valid_o=>t_qv,
    mem_req_ready_i=>t_qr,
    mem_req_o=>t_q,
    mem_rsp_valid_i=>t_rv,
    mem_rsp_ready_o=>t_rr,
    mem_rsp_i=>t_rsp,
    param_req_valid_o=>t_pv,
    param_req_ready_i=>t_pr,
    param_req_o=>t_pq,
    param_rsp_valid_i=>t_psv,
    param_rsp_ready_o=>t_psr,
    param_rsp_i=>param_rsp_i,
    active_products_o=>tensor_products,
    saturation_events_o=>tensor_sat);
  unit_a:entity work.eat_streaming_attention_engine(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    cmd_valid_i=>seq_avalid,
    cmd_ready_o=>a_cr,
    cmd_i=>attention_cmd,
    done_valid_o=>a_dv,
    done_ready_i=>seq_ack and flag(stage=ST_ATTENTION),
    status_o=>a_status,
    m_valid_o=>a_mv,
    m_ready_i=>flag(phase=RUN),
    m_data_o=>a_data,
    mem_req_valid_o=>a_qv,
    mem_req_ready_i=>a_qr,
    mem_req_o=>a_q,
    mem_rsp_valid_i=>a_rv,
    mem_rsp_ready_o=>a_rr,
    mem_rsp_i=>a_rsp,
    param_req_valid_o=>a_pv,
    param_req_ready_i=>a_pr,
    param_req_o=>a_pq,
    param_rsp_valid_i=>a_psv,
    param_rsp_ready_o=>a_psr,
    param_rsp_i=>param_rsp_i,
    active_products_o=>attention_products,
    saturation_events_o=>attention_sat);
  unit_n:entity work.eat_rmsnorm(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    cmd_valid_i=>seq_vvalid and flag(norm_stage(stage)),
    cmd_ready_o=>n_cr,
    cmd_i=>vector_cmd,
    done_valid_o=>n_dv,
    done_ready_i=>seq_ack and flag(norm_stage(stage)),
    status_o=>n_status,
    s_valid_i=>reader_a_valid and flag(norm_stage(stage)),
    s_ready_o=>n_sr,
    s_data_i=>reader_a,
    m_valid_o=>n_mv,
    m_ready_i=>flag(phase=RUN),
    m_data_o=>n_data,
    param_req_valid_o=>n_pv,
    param_req_ready_i=>n_pr,
    param_req_o=>n_pq,
    param_rsp_valid_i=>n_psv,
    param_rsp_ready_o=>n_psr,
    param_rsp_i=>param_rsp_i,
    mem_req_valid_o=>open,
    mem_req_ready_i=>'0',
    mem_req_o=>open,
    mem_rsp_valid_i=>'0',
    mem_rsp_ready_o=>open,
    mem_rsp_i=>C_MEM_RSP_IDLE,
    saturation_events_o=>norm_sat);
  unit_p:entity work.eat_position_add(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    cmd_valid_i=>seq_vvalid and flag(stage=ST_POSITION),
    cmd_ready_o=>p_cr,
    cmd_i=>vector_cmd,
    done_valid_o=>p_dv,
    done_ready_i=>seq_ack and flag(stage=ST_POSITION),
    status_o=>p_status,
    s_valid_i=>reader_a_valid and flag(stage=ST_POSITION),
    s_ready_o=>p_sr,
    s_data_i=>reader_a,
    m_valid_o=>p_mv,
    m_ready_i=>flag(phase=RUN),
    m_data_o=>p_data,
    param_req_valid_o=>p_pv,
    param_req_ready_i=>p_pr,
    param_req_o=>p_pq,
    param_rsp_valid_i=>p_psv,
    param_rsp_ready_o=>p_psr,
    param_rsp_i=>param_rsp_i,
    saturation_events_o=>position_sat);
  unit_f:entity work.eat_pwl_silu(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    cmd_valid_i=>seq_vvalid and flag(stage=ST_PWL),
    cmd_ready_o=>f_cr,
    cmd_i=>vector_cmd,
    done_valid_o=>f_dv,
    done_ready_i=>seq_ack and flag(stage=ST_PWL),
    status_o=>f_status,
    s_valid_i=>reader_a_valid and flag(stage=ST_PWL),
    s_ready_o=>f_sr,
    s_data_i=>reader_a,
    m_valid_o=>f_mv,
    m_ready_i=>flag(phase=RUN),
    m_data_o=>f_data,
    param_req_valid_o=>f_pv,
    param_req_ready_i=>f_pr,
    param_req_o=>f_pq,
    param_rsp_valid_i=>f_psv,
    param_rsp_ready_o=>f_psr,
    param_rsp_i=>param_rsp_i,
    saturation_events_o=>pwl_sat);
  unit_r:entity work.eat_residual_add(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    cmd_valid_i=>seq_vvalid and flag(residual_stage(stage)),
    cmd_ready_o=>r_cr,
    cmd_i=>vector_cmd,
    done_valid_o=>r_dv,
    done_ready_i=>seq_ack and flag(residual_stage(stage)),
    status_o=>r_status,
    a_valid_i=>reader_a_valid and flag(residual_stage(stage)),
    a_ready_o=>r_sr,
    a_data_i=>reader_a,
    b_valid_i=>reader_b_valid and flag(residual_stage(stage)),
    b_ready_o=>residual_b_ready,
    b_data_i=>reader_b,
    m_valid_o=>r_mv,
    m_ready_i=>flag(phase=RUN),
    m_data_o=>r_data,
    saturation_events_o=>residual_sat);
  unit_m:entity work.eat_mean_pool(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    cmd_valid_i=>seq_vvalid and flag(stage=ST_POOL),
    cmd_ready_o=>m_cr,
    cmd_i=>vector_cmd,
    done_valid_o=>m_dv,
    done_ready_i=>seq_ack and flag(stage=ST_POOL),
    status_o=>m_status,
    s_valid_i=>reader_a_valid and flag(stage=ST_POOL),
    s_ready_o=>m_sr,
    s_data_i=>reader_a,
    m_valid_o=>m_mv,
    m_ready_i=>flag(phase=RUN),
    m_data_o=>m_data);
  unit_s:entity work.eat_group_scorer(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    cmd_valid_i=>gate_start,
    cmd_ready_o=>s_cr,
    cmd_i=>gate_cmd,
    done_valid_o=>s_dv,
    done_ready_i=>seq_ack and flag(stage=ST_GATE) and unit_done,
    status_o=>s_status,
    token_scores_valid_i=>feed_scores and flag(stage=ST_GATE),
    token_scores_ready_o=>s_sr,
    token_scores_i=>scorer_input,
    scores_valid_o=>group_valid,
    scores_ready_i=>group_ready,
    score_o=>group_score,
    group_index_o=>group_index,
    last_group_o=>group_last,
    mem_req_valid_o=>s_qv,
    mem_req_ready_i=>s_qr,
    mem_req_o=>s_q,
    mem_rsp_valid_i=>s_rv,
    mem_rsp_ready_o=>s_rr,
    mem_rsp_i=>s_rsp,
    param_req_valid_o=>open,
    param_req_ready_i=>'0',
    param_req_o=>open,
    param_rsp_valid_i=>'0',
    param_rsp_ready_o=>open,
    param_rsp_i=>C_PARAM_RSP_IDLE);
  unit_g:entity work.eat_group_selector(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    cmd_valid_i=>gate_start,
    cmd_ready_o=>g_cr,
    cmd_i=>gate_cmd,
    done_valid_o=>g_dv,
    done_ready_i=>seq_ack and flag(stage=ST_GATE) and unit_done,
    status_o=>g_status,
    scores_valid_i=>group_valid,
    scores_ready_o=>group_ready,
    score_i=>group_score,
    group_index_i=>group_index,
    last_group_i=>group_last,
    decision_valid_o=>decision_valid,
    decision_ready_i=>decision_ready,
    decision_o=>decision);
  unit_c:entity work.eat_token_compactor(rtl) port map(
    clk_i=>clk_i,
    rst_i=>unit_rst,
    cmd_valid_i=>gate_start,
    cmd_ready_o=>c_cr,
    cmd_i=>gate_cmd,
    done_valid_o=>c_dv,
    done_ready_i=>seq_ack and flag(stage=ST_GATE) and unit_done,
    status_o=>c_status,
    decision_valid_i=>decision_valid,
    decision_ready_o=>decision_ready,
    decision_i=>decision,
    s_valid_i=>reader_a_valid and flag(stage=ST_GATE),
    s_ready_o=>c_sr,
    s_data_i=>reader_a,
    m_valid_o=>c_mv,
    m_ready_i=>flag(phase=RUN),
    m_data_o=>c_data,
    mem_req_valid_o=>c_qv,
    mem_req_ready_i=>c_qr,
    mem_req_o=>c_q,
    mem_rsp_valid_i=>c_rv,
    mem_rsp_ready_o=>c_rr,
    mem_rsp_i=>c_rsp);
  process(all)
  begin
    param_req_valid_o<='0';param_req_o<=C_PARAM_REQ_IDLE;param_rsp_ready_o<='0';
    t_pr<='0';t_psv<='0';
    a_pr<='0';a_psv<='0';
    n_pr<='0';n_psv<='0';
    p_pr<='0';p_psv<='0';
    f_pr<='0';f_psv<='0';
    if phase=PROFILE_REQ then param_req_valid_o<=not rst_i;param_req_o<=(CONST_PROFILE,to_unsigned(profile_index,C_MEM_ADDR_BITS),request.model_bank,to_unsigned(profile_index,16));
    elsif phase=PROFILE_RSP then param_rsp_ready_o<=not rst_i;
    elsif phase=RUN then
      if matrix_stage(stage) then param_req_valid_o<=t_pv;param_req_o<=t_pq;t_pr<=param_req_ready_i;t_psv<=param_rsp_valid_i;param_rsp_ready_o<=t_psr;
      elsif stage=ST_ATTENTION then param_req_valid_o<=a_pv;param_req_o<=a_pq;a_pr<=param_req_ready_i;a_psv<=param_rsp_valid_i;param_rsp_ready_o<=a_psr;
      elsif norm_stage(stage) then param_req_valid_o<=n_pv;param_req_o<=n_pq;n_pr<=param_req_ready_i;n_psv<=param_rsp_valid_i;param_rsp_ready_o<=n_psr;
      elsif stage=ST_POSITION then param_req_valid_o<=p_pv;param_req_o<=p_pq;p_pr<=param_req_ready_i;p_psv<=param_rsp_valid_i;param_rsp_ready_o<=p_psr;
      elsif stage=ST_PWL then param_req_valid_o<=f_pv;param_req_o<=f_pq;f_pr<=param_req_ready_i;f_psv<=param_rsp_valid_i;param_rsp_ready_o<=f_psr;
      end if;
    end if;
  end process;
  t_qr<=(not t_rv or t_rr) and flag(phase=RUN) and flag(matrix_stage(stage)) and not rst_i;
  a_qr<=not qkv_read_pending and (not a_rv or a_rr) and flag(phase=RUN and stage=ST_ATTENTION) and not rst_i;
  s_qr<=(not s_rv or s_rr) and flag(phase=RUN and stage=ST_GATE) and not rst_i;
  c_qr<=(not c_rv or c_rr) and flag(phase=RUN and stage=ST_GATE) and not rst_i;
  process(clk_i)
    variable address,bank,word_address,plane,token,feature,shift_amount:natural;
    variable value:wide_t;
    variable data_value:state_t;
  begin
    if rising_edge(clk_i) then
      qkv_sat<=(others=>'0');
      if unit_rst='1' then t_rv<='0';a_rv<='0';s_rv<='0';c_rv<='0';qkv_read_pending<='0';
      else
        if t_rv='1' and t_rr='1' then t_rv<='0';end if;
        if a_rv='1' and a_rr='1' then a_rv<='0';end if;
        if s_rv='1' and s_rr='1' then s_rv<='0';end if;
        if c_rv='1' and c_rr='1' then c_rv<='0';end if;
        if t_qv='1' and t_qr='1' then
          t_rv<='1';t_rsp<=((others=>'0'),t_q.tag,'0');address:=to_integer(t_q.address);bank:=address mod C_LANES;word_address:=address/C_LANES;
          if t_q.write_enable='1' or address>=matrix_cmd.rows*matrix_cmd.reduction then t_rsp.error<='1';
          else
            if stage=ST_EMBED then data_value:=raw_mem(bank,word_address);
            elsif stage=ST_PROJECTION then data_value:=att_mem(bank,word_address);
            elsif stage=ST_FFN2 then data_value:=f_mem(bank,word_address);
            elsif stage=ST_SCORER then data_value:=x_mem(bank,word_address);
            elsif stage=ST_CLASSIFIER then data_value:=pool_mem(bank,word_address);
            else data_value:=n_mem(bank,word_address);end if;
            t_rsp.data<=std_logic_vector(resize(data_value,64));
          end if;
        end if;
        if qkv_read_pending='1' then
          value:=rshift_even(resize(qkv_read_data,64),to_integer(qkv_read_shift));
          a_rsp<=(std_logic_vector(resize(sat(value,C_ACT_BITS),64)),qkv_read_tag,'0');a_rv<='1';qkv_read_pending<='0';
          if not fits(value,C_ACT_BITS) then qkv_sat<=to_unsigned(1,16);end if;
        end if;
        if a_qv='1' and a_qr='1' then
          address:=to_integer(a_q.address);plane:=address/(C_MAX_TOKENS*C_WIDTH);token:=(address mod (C_MAX_TOKENS*C_WIDTH))/C_WIDTH;feature:=address mod C_WIDTH;
          if plane>2 or token>=tokens or a_q.write_enable='1' then a_rsp<=((others=>'0'),a_q.tag,'1');a_rv<='1';
          else
            qkv_read_data<=qkv_mem(feature mod C_LANES,token*(3*C_WIDTH/C_LANES)+(plane*C_WIDTH+feature)/C_LANES);
            qkv_read_shift<=to_signed(number(profile_data,40+3*layer+plane),8);qkv_read_tag<=a_q.tag;qkv_read_pending<='1';
          end if;
        end if;
        if s_qv='1' and s_qr='1' then
          s_rv<='1';s_rsp<=((others=>'0'),s_q.tag,'0');address:=to_integer(s_q.address);
          if address<32768 or address>=32768+C_MAX_TOKENS or s_q.write_enable/='1' or s_q.write_strobe/=x"ff" or not fits(signed(s_q.write_data),C_STATE_BITS) then s_rsp.error<='1';
          else score_scratch(address-32768)<=resize(signed(s_q.write_data),C_STATE_BITS);end if;
        end if;
        if c_qv='1' and c_qr='1' then
          c_rv<='1';c_rsp<=((others=>'0'),c_q.tag,'0');address:=to_integer(c_q.address);
          if address<32768 or address>=32768+C_MAX_TOKENS or c_q.write_enable/='0' then c_rsp.error<='1';
          else c_rsp.data<=std_logic_vector(resize(score_scratch(address-32768),64));end if;
        end if;
      end if;
    end if;
  end process;
  process(clk_i)
    variable offset,features,classes,raw_words:natural;
    variable mac_next,sat_next:unsigned(32 downto 0);
    variable counter_error:boolean;
  begin
    if rising_edge(clk_i) then
      counter_error:=false;
      if rst_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;feed_a<='0';feed_b<='0';feed_scores<='0';reader_a_valid<='0';reader_b_valid<='0';
      else
        -- These cycle classes overlap: they are diagnostic observations, not a partition.
        if phase/=IDLE and ((param_req_valid_o='1' and param_req_ready_i='0') or
           (param_rsp_ready_o='1' and param_rsp_valid_i='0') or
           (mem_req_valid_o='1' and mem_req_ready_i='0') or
           (mem_rsp_ready_o='1' and mem_rsp_valid_i='0')) then
          if memory_wait_count=(memory_wait_count'range=>'1') then counter_error:=true;
          else memory_wait_count<=memory_wait_count+1;end if;
        end if;
        if phase=RUN then
          if matrix_stage(stage) and tensor_products=0 then
            if bubble_count=(bubble_count'range=>'1') then counter_error:=true;else bubble_count<=bubble_count+1;end if;
          end if;
          if (norm_stage(stage) and n_mv='0') or (stage=ST_PWL and f_mv='0') or
             (stage=ST_ATTENTION and a_mv='0') or (stage=ST_POOL and m_mv='0') then
            if nonlinear_wait_count=(nonlinear_wait_count'range=>'1') then counter_error:=true;else nonlinear_wait_count<=nonlinear_wait_count+1;end if;
          end if;
          mac_next:=resize(mac_count,33)+resize(tensor_products,33)+resize(attention_products,33);
          sat_next:=resize(saturation_count,33)+resize(tensor_sat,33)+resize(attention_sat,33)+resize(norm_sat,33)+resize(position_sat,33)+resize(pwl_sat,33)+resize(qkv_sat,33);
          if r_mv='1' then sat_next:=sat_next+resize(residual_sat,33);end if;
          counter_error:=counter_error or mac_next(32)='1' or sat_next(32)='1';mac_count<=mac_next(31 downto 0);saturation_count<=sat_next(31 downto 0);
          if (seq_vvalid='1' and seq_vready='1') or gate_start='1' then
            feed_a<='1';read_a_token<=0;read_a_feature<=0;feed_b<=flag(residual_stage(stage));read_b_token<=0;read_b_feature<=0;reader_a_valid<='0';reader_b_valid<='0';
            if gate_start='1' then feed_scores<='1';score_token<=0;end if;
          else
            if reader_a_valid='1' and reader_a_ready='1' then reader_a_valid<='0';end if;
            if reader_b_valid='1' and reader_b_ready='1' then reader_b_valid<='0';end if;
            if feed_a='1' and (reader_a_valid='0' or reader_a_ready='1') then
              if stage=ST_PWL then reader_a<=read_beat(f_mem,read_a_token,read_a_feature,256,tokens,ctx);
              elsif stage=ST_POOL then reader_a<=read_beat(n_mem,read_a_token,read_a_feature,128,tokens,ctx);
              else reader_a<=read_beat(x_mem,read_a_token,read_a_feature,128,tokens,ctx);end if;
              reader_a_valid<='1';
              if read_a_feature+C_LANES>=read_features then
                if read_a_token+1=tokens then feed_a<='0';else read_a_token<=read_a_token+1;read_a_feature<=0;end if;
              else read_a_feature<=read_a_feature+C_LANES;end if;
            end if;
            if feed_b='1' and (reader_b_valid='0' or reader_b_ready='1') then
              reader_b<=read_beat(y_mem,read_b_token,read_b_feature,128,tokens,ctx);reader_b_valid<='1';
              if read_b_feature+C_LANES>=C_WIDTH then
                if read_b_token+1=tokens then feed_b<='0';else read_b_token<=read_b_token+1;read_b_feature<=0;end if;
              else read_b_feature<=read_b_feature+C_LANES;end if;
            end if;
          end if;
          if feed_scores='1' and s_sr='1' then
            if score_token+1=tokens then feed_scores<='0';else score_token<=score_token+1;end if;
          end if;
          case stage is
            when ST_EMBED | ST_QKV | ST_PROJECTION | ST_FFN1 | ST_FFN2 | ST_SCORER | ST_CLASSIFIER =>
          if t_mv='1' then
            for lane in 0 to C_LANES-1 loop
              if t_data.keep(lane)='1' then
                if stage=ST_EMBED then x_mem(lane,t_data.token*(C_WIDTH/C_LANES)+t_data.feature_base/C_LANES)<=t_data.data(lane);
                elsif stage=ST_QKV then qkv_mem(lane,t_data.token*(3*C_WIDTH/C_LANES)+t_data.feature_base/C_LANES)<=t_data.data(lane);
                elsif stage=ST_PROJECTION or stage=ST_FFN2 then y_mem(lane,t_data.token*(C_WIDTH/C_LANES)+t_data.feature_base/C_LANES)<=t_data.data(lane);
                elsif stage=ST_FFN1 then f_mem(lane,t_data.token*(C_FFN_WIDTH/C_LANES)+t_data.feature_base/C_LANES)<=t_data.data(lane);
                elsif stage=ST_SCORER then score_values(t_data.token)<=t_data.data(lane);
                elsif stage=ST_CLASSIFIER then logit_values(t_data.feature_base+lane)<=t_data.data(lane);end if;
              end if;
            end loop;
          end if;

            when ST_ATTENTION =>
          if a_mv='1' then for lane in 0 to C_LANES-1 loop if a_data.keep(lane)='1' then att_mem(lane,a_data.token*(C_WIDTH/C_LANES)+a_data.feature_base/C_LANES)<=a_data.data(lane);end if;end loop;end if;
            when ST_NORM1 | ST_NORM2 | ST_FINAL_NORM =>
          if n_mv='1' then for lane in 0 to C_LANES-1 loop if n_data.keep(lane)='1' then n_mem(lane,n_data.token*(C_WIDTH/C_LANES)+n_data.feature_base/C_LANES)<=n_data.data(lane);end if;end loop;end if;
            when ST_POSITION =>
          if p_mv='1' then for lane in 0 to C_LANES-1 loop if p_data.keep(lane)='1' then x_mem(lane,p_data.token*(C_WIDTH/C_LANES)+p_data.feature_base/C_LANES)<=p_data.data(lane);end if;end loop;end if;
            when ST_PWL =>
          if f_mv='1' then for lane in 0 to C_LANES-1 loop if f_data.keep(lane)='1' then f_mem(lane,f_data.token*(C_FFN_WIDTH/C_LANES)+f_data.feature_base/C_LANES)<=f_data.data(lane);end if;end loop;end if;
            when ST_RESIDUAL1 | ST_RESIDUAL2 =>
          if r_mv='1' then for lane in 0 to C_LANES-1 loop if r_data.keep(lane)='1' then x_mem(lane,r_data.token*(C_WIDTH/C_LANES)+r_data.feature_base/C_LANES)<=r_data.data(lane);end if;end loop;end if;
            when ST_POOL =>
          if m_mv='1' then for lane in 0 to C_LANES-1 loop if m_data.keep(lane)='1' then pool_mem(lane,m_data.feature_base/C_LANES)<=m_data.data(lane);end if;end loop;end if;
            when ST_GATE =>
          if c_mv='1' then for lane in 0 to C_LANES-1 loop if c_data.keep(lane)='1' then x_mem(lane,c_data.token*(C_WIDTH/C_LANES)+c_data.feature_base/C_LANES)<=c_data.data(lane);end if;end loop;end if;
            when others => null;
          end case;
        end if;
        case phase is
          when IDLE => if start_valid_i='1' then
            request<=request_i;ctx<=(request_i.inference_id,request_i.mode,request_i.workload,request_i.model_bank);status_o<=('1','0','0',ERR_NONE,(request_i.inference_id,request_i.mode,request_i.workload,request_i.model_bank));
            stat_index<=0;profile_index<=0;profile_data<=(others=>(others=>'0'));feed_a<='0';feed_b<='0';feed_scores<='0';reader_a_valid<='0';reader_b_valid<='0';mac_count<=(others=>'0');saturation_count<=(others=>'0');bubble_count<=(others=>'0');memory_wait_count<=(others=>'0');nonlinear_wait_count<=(others=>'0');
            if to_integer(request_i.model_bank)>=C_MODEL_BANKS then status_o.busy<='0';status_o.done<='1';status_o.error<='1';status_o.code<=ERR_IDENTITY;
            else phase<=PROFILE_REQ;end if;
          end if;
          when PROFILE_REQ => if param_req_ready_i='1' then phase<=PROFILE_RSP;end if;
          when PROFILE_RSP => if param_rsp_valid_i='1' then
            if param_rsp_i.error='1' or param_rsp_i.tag/=profile_index then status_o<=('0','1','1',ERR_PROTOCOL,ctx);phase<=IDLE;
            else profile_data(profile_index)<=signed(param_rsp_i.data);
              if profile_index+1=C_IMAGE_PROFILE_WORDS then phase<=VALIDATE_PROFILE;else profile_index<=profile_index+1;phase<=PROFILE_REQ;end if;
            end if;
          end if;
          when VALIDATE_PROFILE =>
            if not valid_profile(profile_data,request.expected_identity) then status_o<=('0','1','1',ERR_IDENTITY,ctx);phase<=IDLE;
            elsif number(profile_data,3)/=workload_t'pos(ctx.workload) or number(profile_data,4)/=mode_t'pos(ctx.mode) then status_o<=('0','1','1',ERR_MODE,ctx);phase<=IDLE;
            else raw_word<=0;phase<=RAW_REQ;end if;
          when RAW_REQ => if mem_req_ready_i='1' then phase<=RAW_RSP;end if;
          when RAW_RSP => if mem_rsp_valid_i='1' then
            if mem_rsp_i.error='1' or mem_rsp_i.tag/=raw_word then status_o<=('0','1','1',ERR_PROTOCOL,ctx);phase<=IDLE;
            else
              for lane in 0 to C_LANES-1 loop raw_mem(lane,raw_word)<=shift_left(resize(signed(mem_rsp_i.data(8*lane+7 downto 8*lane)),C_STATE_BITS),number(profile_data,14));end loop;
              raw_words:=144;if ctx.workload=WORKLOAD_SPEECH then raw_words:=320;end if;
              if raw_word+1=raw_words then phase<=START_SEQ;else raw_word<=raw_word+1;phase<=RAW_REQ;end if;
            end if;
          end if;
          when START_SEQ => if seq_start_ready='1' then phase<=RUN;end if;
          when RUN =>
            if seq_status.error='1' then status_o<=seq_status;phase<=IDLE;
            elsif stage=ST_OUTPUT then stat_index<=0;phase<=EMIT_STATS;end if;
          when EMIT_STATS => if stat_index=8 then logit_base<=0;phase<=SEND_LOGITS;else stat_index<=stat_index+1;end if;
          when SEND_LOGITS => if logits_ready_i='1' then
            if logit_base+C_LANES>=number(profile_data,10) then phase<=WAIT_SEQ;else logit_base<=logit_base+C_LANES;end if;
          end if;
          when WAIT_SEQ => if seq_status.done='1' then status_o<=seq_status;phase<=IDLE;end if;
        end case;
        if counter_error then status_o<=('0','1','1',ERR_OVERFLOW,ctx);phase<=IDLE;end if;
      end if;
    end if;
  end process;
end architecture;
