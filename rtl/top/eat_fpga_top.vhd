-- ABI2 single-clock PL peripheral. Physical target mapping and board checks are separate.
-- Single-clock PL peripheral: control, transfer/storage and encoder/output boundaries; not connected yet.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;
use work.eat_image_pkg.all;

entity eat_fpga_top is
  generic (
    G_ALLOW_STUB_SIM : boolean := false;
    G_RESIDENT_BANKS : positive := 3;
    G_WORDS_PER_BANK : positive := 90112
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_axi_awaddr_i : in std_logic_vector(C_AXIL_ADDR_BITS-1 downto 0);
    s_axi_awvalid_i : in std_logic;
    s_axi_awready_o : out std_logic;
    s_axi_wdata_i : in std_logic_vector(C_AXIL_DATA_BITS-1 downto 0);
    s_axi_wstrb_i : in std_logic_vector(C_AXIL_DATA_BITS/8-1 downto 0);
    s_axi_wvalid_i : in std_logic;
    s_axi_wready_o : out std_logic;
    s_axi_bresp_o : out std_logic_vector(1 downto 0);
    s_axi_bvalid_o : out std_logic;
    s_axi_bready_i : in std_logic;
    s_axi_araddr_i : in std_logic_vector(C_AXIL_ADDR_BITS-1 downto 0);
    s_axi_arvalid_i : in std_logic;
    s_axi_arready_o : out std_logic;
    s_axi_rdata_o : out std_logic_vector(C_AXIL_DATA_BITS-1 downto 0);
    s_axi_rresp_o : out std_logic_vector(1 downto 0);
    s_axi_rvalid_o : out std_logic;
    s_axi_rready_i : in std_logic;
    s_axis_tdata_i : in std_logic_vector(C_AXIS_BITS-1 downto 0);
    s_axis_tkeep_i : in std_logic_vector(C_AXIS_BITS/8-1 downto 0);
    s_axis_tlast_i : in std_logic;
    s_axis_tvalid_i : in std_logic;
    s_axis_tready_o : out std_logic;
    m_axis_tdata_o : out std_logic_vector(C_AXIS_BITS-1 downto 0);
    m_axis_tkeep_o : out std_logic_vector(C_AXIS_BITS/8-1 downto 0);
    m_axis_tlast_o : out std_logic;
    m_axis_tvalid_o : out std_logic;
    m_axis_tready_i : in std_logic;
    interrupt_o : out std_logic
  );
end entity;

architecture rtl of eat_fpga_top is
  type operation_t_local is (IDLE,TRANSFER,ARM_BANK,START_CORE,INFERENCE);
  signal operation:operation_t_local:=IDLE;
  signal cfg,requested,saved_request,frame_request,transfer_request:control_request_t:=C_CONTROL_REQUEST_IDLE;
  signal configured_transfer,transfer_command,active_transfer:transfer_cmd_t:=C_TRANSFER_CMD_IDLE;
  signal held_status,register_status,mode_status,loader_status,dma_status,core_status:status_t:=C_STATUS_IDLE;
  signal frame_valid,transfer_error_seen,raw_last_seen,core_done_seen,output_done_seen:std_logic:='0';
  signal service_abort,ingress_abort,output_abort:std_logic:='0';
  signal service_rst,core_rst,output_rst:std_logic;
  signal clear_status,clear_counters,selected_valid:std_logic;
  signal reg_request_valid,reg_request_ready,reg_transfer_valid,reg_transfer_ready,reg_arm_valid,reg_arm_ready:std_logic;
  signal reg_arm_bank:bank_id_t;signal reg_arm_identity,loaded_identity,transfer_identity:identity_t;
  signal bank_valid:std_logic_vector(C_MODEL_BANKS-1 downto 0);
  signal eligible_start,eligible_transfer,eligible_arm:std_logic;
  signal mode_request_ready,mode_active_valid,mode_active_ready:std_logic;signal mode_context:context_t;
  signal core_start_ready,core_logit_valid,core_logit_ready,core_event_valid:std_logic;
  signal core_logits:state_beat_t;signal core_event:counter_event_t;signal core_event_count:unsigned(31 downto 0);
  signal core_pv,core_pr,core_psv,core_psr:std_logic;signal core_pq:param_req_t;signal core_ps:param_rsp_t;
  signal core_qv,core_qr,core_rv,core_rr:std_logic;signal core_q:mem_req_t;signal core_rsp:mem_rsp_t;
  signal serializer_ready,serializer_done:std_logic;
  signal dma_cr,dma_dv,dma_active,dma_done_ready:std_logic;
  signal stream_bytes:unsigned(15 downto 0);signal stream_last,stream_error:std_logic;
  signal ingress_ready,ingress_busy,ingress_error,raw_valid,raw_ready,raw_last,const_valid,const_ready,const_last:std_logic;
  signal raw_data,const_data:std_logic_vector(63 downto 0);signal raw_keep,const_keep:std_logic_vector(7 downto 0);signal raw_offset:unsigned(31 downto 0);
  signal loader_cr,loader_dv,loader_done_ready,loader_arm_ready:std_logic;
  signal loader_qv,loader_qr,loader_rv,loader_rr:std_logic;signal loader_q:mem_req_t;signal loader_rsp:mem_rsp_t;
  signal store_qv,store_qr,store_rv,store_rr:std_logic;signal store_q:mem_req_t;signal store_rsp:mem_rsp_t;
  signal model_cv,model_cr,model_rv,model_rr:std_logic_vector(1 downto 0);
  signal model_requests:mem_req_array_t(0 to 1);signal model_responses:mem_rsp_array_t(0 to 1);
  signal model_qv,model_qr,model_sv,model_sr:std_logic;signal model_q:mem_req_t;signal model_rsp:mem_rsp_t;
  signal input_cv,input_cr,input_rv,input_rr:std_logic_vector(1 downto 0);
  signal input_requests:mem_req_array_t(0 to 1);signal input_responses:mem_rsp_array_t(0 to 1);
  signal input_qv,input_qr,input_sv,input_sr:std_logic;signal input_q:mem_req_t;signal input_rsp:mem_rsp_t;
  signal transfer_fault,transfer_finish,kernel_finish:std_logic;
  signal snapshots:counter_snapshot_t;signal snapshot_valid:std_logic;
  signal snapshot_id:unsigned(31 downto 0):=(others=>'0');
  function same_model(a,b:control_request_t) return boolean is
  begin return a.mode=b.mode and a.workload=b.workload and a.model_bank=b.model_bank and a.expected_identity=b.expected_identity;end;
  signal loader_s_ready:std_logic;
  signal store_req_ready,store_rsp_valid:std_logic;
begin
  assert G_RESIDENT_BANKS<=C_MODEL_BANKS report "Resident bank count exceeds ABI" severity failure;
  service_rst<=rst_i or service_abort;core_rst<=rst_i or output_abort;output_rst<=rst_i or output_abort;
  selected_valid<=bank_valid(to_integer(cfg.model_bank)) when to_integer(cfg.model_bank)<C_MODEL_BANKS else '0';
  process(all)
    variable st:status_t;variable okay:boolean;variable expected_bytes:natural;
  begin
    st:=held_status;st.busy:=flag(operation/=IDLE);register_status<=st;
    eligible_start<=flag(operation=IDLE) and not held_status.error and not service_abort and frame_valid and selected_valid and core_start_ready and flag(to_integer(cfg.model_bank)<G_RESIDENT_BANKS) and flag(cfg.expected_identity=loaded_identity) and flag(same_model(cfg,frame_request));
    eligible_arm<=flag(operation=IDLE) and not held_status.error and not service_abort and flag(to_integer(cfg.model_bank)<G_RESIDENT_BANKS);
    okay:=false;expected_bytes:=1152;if cfg.workload=WORKLOAD_SPEECH then expected_bytes:=2560;end if;
    if operation=IDLE and held_status.error='0' and service_abort='0' and to_integer(cfg.model_bank)<G_RESIDENT_BANKS and configured_transfer.bytes/=0 then
      if configured_transfer.kind=TRANSFER_INPUT then
        okay:=configured_transfer.address=0 and configured_transfer.bytes=expected_bytes and selected_valid='1' and cfg.expected_identity=loaded_identity;
      elsif configured_transfer.bytes(2 downto 0)="000" and configured_transfer.bytes<=region_words(configured_transfer.constant_kind)*8 then
        okay:=to_integer(configured_transfer.address)+to_integer(shift_right(configured_transfer.bytes,3))<=region_words(configured_transfer.constant_kind);
        if configured_transfer.constant_kind=CONST_PROFILE then okay:=configured_transfer.address=0 and configured_transfer.bytes=C_IMAGE_PROFILE_WORDS*8;end if;
      end if;
    end if;
    eligible_transfer<=flag(okay);
  end process;
  reg_request_ready<=eligible_start and mode_request_ready;
  reg_transfer_ready<=eligible_transfer and dma_cr and ingress_ready and (loader_cr or flag(configured_transfer.kind=TRANSFER_INPUT));
  reg_arm_ready<=eligible_arm and loader_arm_ready;
  mode_active_ready<=core_start_ready and flag(operation=START_CORE);
  core_logit_ready<=serializer_ready and flag(operation=INFERENCE);
  raw_ready<=input_cr(0) and flag(operation=TRANSFER) and not service_rst;
  const_ready<=loader_s_ready and flag(operation=TRANSFER) and not service_rst;
  input_cv(0)<=raw_valid and flag(operation=TRANSFER) and not service_rst;
  input_cv(1)<=core_qv and flag(operation=INFERENCE) and not service_rst;
  process(all)
    variable q:mem_req_t;
  begin
    q:=C_MEM_REQ_IDLE;q.address:=resize(shift_right(raw_offset,3),C_MEM_ADDR_BITS);q.write_data:=raw_data;q.write_strobe:=raw_keep;q.write_enable:='1';
    q.tag:=resize(shift_right(raw_offset,3),16);q.tag(15):=raw_last;input_requests(0)<=q;input_requests(1)<=core_q;
  end process;
  input_rr(0)<='1';input_rr(1)<=core_rr and flag(operation=INFERENCE);
  core_qr<=input_cr(1) and flag(operation=INFERENCE) and not service_rst;core_rv<=input_rv(1) and flag(operation=INFERENCE);core_rsp<=input_responses(1);
  model_cv<=store_qv&loader_qv;model_requests(0)<=loader_q;model_requests(1)<=store_q;
  loader_qr<=model_cr(0);store_qr<=model_cr(1);loader_rv<=model_rv(0);store_rv<=model_rv(1);loader_rsp<=model_responses(0);store_rsp<=model_responses(1);model_rr<=store_rr&loader_rr;
  process(all)
    variable count:natural;
  begin
    count:=0;stream_last<='0';
    if raw_valid='1' and raw_ready='1' then for i in 0 to 7 loop if raw_keep(i)='1' then count:=count+1;end if;end loop;stream_last<=raw_last;
    elsif const_valid='1' and const_ready='1' then for i in 0 to 7 loop if const_keep(i)='1' then count:=count+1;end if;end loop;stream_last<=const_last;end if;
    stream_bytes<=to_unsigned(count,16);
  end process;
  transfer_fault<=ingress_error or dma_status.error or (loader_status.error and flag(active_transfer.kind=TRANSFER_CONSTANTS)) or (input_rv(0) and input_responses(0).error);
  stream_error<=ingress_error or loader_status.error or (input_rv(0) and input_responses(0).error);
  transfer_finish<=flag(operation=TRANSFER) and dma_dv and not ingress_busy and
    (transfer_error_seen or transfer_fault or (loader_dv and flag(active_transfer.kind=TRANSFER_CONSTANTS)) or (raw_last_seen and flag(active_transfer.kind=TRANSFER_INPUT)));
  dma_done_ready<=transfer_finish;
  loader_done_ready<=flag(operation=ARM_BANK) or (transfer_finish and flag(active_transfer.kind=TRANSFER_CONSTANTS));
  kernel_finish<=flag(operation=INFERENCE) and (core_done_seen or core_status.done) and (output_done_seen or serializer_done) and not core_status.error;
  registers:entity work.eat_axi_ctrl_regs(rtl) port map(
    clk_i=>clk_i,
    rst_i=>rst_i,
    s_axi_awaddr_i=>s_axi_awaddr_i,
    s_axi_awvalid_i=>s_axi_awvalid_i,
    s_axi_awready_o=>s_axi_awready_o,
    s_axi_wdata_i=>s_axi_wdata_i,
    s_axi_wstrb_i=>s_axi_wstrb_i,
    s_axi_wvalid_i=>s_axi_wvalid_i,
    s_axi_wready_o=>s_axi_wready_o,
    s_axi_bresp_o=>s_axi_bresp_o,
    s_axi_bvalid_o=>s_axi_bvalid_o,
    s_axi_bready_i=>s_axi_bready_i,
    s_axi_araddr_i=>s_axi_araddr_i,
    s_axi_arvalid_i=>s_axi_arvalid_i,
    s_axi_arready_o=>s_axi_arready_o,
    s_axi_rdata_o=>s_axi_rdata_o,
    s_axi_rresp_o=>s_axi_rresp_o,
    s_axi_rvalid_o=>s_axi_rvalid_o,
    s_axi_rready_i=>s_axi_rready_i,
    request_valid_o=>reg_request_valid,
    request_ready_i=>reg_request_ready,
    request_o=>requested,
    transfer_valid_o=>reg_transfer_valid,
    transfer_ready_i=>reg_transfer_ready,
    transfer_o=>transfer_command,
    status_i=>register_status,
    loaded_identity_i=>loaded_identity,
    counters_i=>snapshots,
    config_o=>cfg,
    transfer_config_o=>configured_transfer,
    arm_valid_o=>reg_arm_valid,
    arm_ready_i=>reg_arm_ready,
    arm_bank_o=>reg_arm_bank,
    arm_identity_o=>reg_arm_identity,
    clear_status_o=>clear_status,
    clear_counters_o=>clear_counters,
    selected_bank_valid_i=>selected_valid,
    snapshot_id_i=>snapshot_id,
    interrupt_o=>interrupt_o);
  mode_control:entity work.eat_mode_controller(rtl) port map(
    clk_i=>clk_i,
    rst_i=>rst_i,
    request_valid_i=>reg_request_valid and eligible_start,
    request_ready_o=>mode_request_ready,
    request_i=>requested,
    core_idle_i=>flag(operation=IDLE) and core_start_ready,
    loaded_identity_i=>loaded_identity,
    bank_valid_i=>selected_valid,
    active_context_o=>mode_context,
    active_valid_o=>mode_active_valid,
    active_ready_i=>mode_active_ready,
    status_o=>mode_status);
  encoder:entity work.eat_encoder_core(rtl) port map(
    clk_i=>clk_i,
    rst_i=>core_rst,
    start_valid_i=>mode_active_valid and flag(operation=START_CORE),
    start_ready_o=>core_start_ready,
    request_i=>saved_request,
    logits_valid_o=>core_logit_valid,
    logits_ready_i=>core_logit_ready,
    logits_o=>core_logits,
    status_o=>core_status,
    event_valid_o=>core_event_valid,
    event_o=>core_event,
    event_count_o=>core_event_count,
    mem_req_valid_o=>core_qv,
    mem_req_ready_i=>core_qr,
    mem_req_o=>core_q,
    mem_rsp_valid_i=>core_rv,
    mem_rsp_ready_o=>core_rr,
    mem_rsp_i=>core_rsp,
    param_req_valid_o=>core_pv,
    param_req_ready_i=>core_pr,
    param_req_o=>core_pq,
    param_rsp_valid_i=>core_psv,
    param_rsp_ready_o=>core_psr,
    param_rsp_i=>core_ps);
  output_pack:entity work.eat_axi_stream_output(rtl) port map(
    clk_i=>clk_i,
    rst_i=>output_rst,
    s_valid_i=>core_logit_valid and flag(operation=INFERENCE),
    s_ready_o=>serializer_ready,
    s_data_i=>core_logits,
    classes_i=>6+29*workload_t'pos(saved_request.workload),
    output_accepted_o=>serializer_done,
    m_axis_tdata_o=>m_axis_tdata_o,
    m_axis_tkeep_o=>m_axis_tkeep_o,
    m_axis_tlast_o=>m_axis_tlast_o,
    m_axis_tvalid_o=>m_axis_tvalid_o,
    m_axis_tready_i=>m_axis_tready_i);
  counters:entity work.eat_performance_counters(rtl) port map(
    clk_i=>clk_i,
    rst_i=>rst_i,
    start_i=>mode_active_valid and mode_active_ready,
    complete_i=>kernel_finish,
    clear_i=>clear_counters,
    abort_i=>flag(operation=INFERENCE) and core_status.error,
    event_valid_i=>core_event_valid and flag(operation=INFERENCE),
    event_i=>core_event,
    event_count_i=>core_event_count,
    snapshot_valid_o=>snapshot_valid,
    snapshot_ready_i=>'1',
    snapshot_o=>snapshots);
  descriptor:entity work.eat_dma_descriptor_engine(rtl) port map(
    clk_i=>clk_i,
    rst_i=>rst_i,
    cmd_valid_i=>reg_transfer_valid and eligible_transfer and ingress_ready and (loader_cr or flag(configured_transfer.kind=TRANSFER_INPUT)),
    cmd_ready_o=>dma_cr,
    cmd_i=>transfer_command,
    done_valid_o=>dma_dv,
    done_ready_i=>dma_done_ready,
    status_o=>dma_status,
    stream_bytes_accepted_i=>stream_bytes,
    stream_last_i=>stream_last,
    frame_error_i=>stream_error,
    active_transfer_o=>active_transfer,
    active_valid_o=>dma_active);
  ingress:entity work.eat_axi_stream_input(rtl) port map(
    clk_i=>clk_i,
    rst_i=>rst_i,
    s_axis_tdata_i=>s_axis_tdata_i,
    s_axis_tkeep_i=>s_axis_tkeep_i,
    s_axis_tlast_i=>s_axis_tlast_i,
    s_axis_tvalid_i=>s_axis_tvalid_i,
    s_axis_tready_o=>s_axis_tready_o,
    transfer_i=>active_transfer,
    transfer_valid_i=>dma_active,
    transfer_ready_o=>ingress_ready,
    clear_i=>clear_status,
    abort_i=>ingress_abort,
    busy_o=>ingress_busy,
    raw_valid_o=>raw_valid,
    raw_ready_i=>raw_ready,
    raw_data_o=>raw_data,
    raw_keep_o=>raw_keep,
    raw_last_o=>raw_last,
    raw_byte_offset_o=>raw_offset,
    constant_valid_o=>const_valid,
    constant_ready_i=>const_ready,
    constant_data_o=>const_data,
    constant_keep_o=>const_keep,
    constant_last_o=>const_last,
    frame_error_o=>ingress_error);
  loader:entity work.eat_constant_loader(rtl) port map(
    clk_i=>clk_i,
    rst_i=>service_rst,
    cmd_valid_i=>dma_active and flag(active_transfer.kind=TRANSFER_CONSTANTS),
    cmd_ready_o=>loader_cr,
    cmd_i=>active_transfer,
    done_valid_o=>loader_dv,
    done_ready_i=>loader_done_ready,
    status_o=>loader_status,
    s_valid_i=>const_valid and flag(operation=TRANSFER),
    s_ready_o=>loader_s_ready,
    s_data_i=>const_data,
    s_keep_i=>const_keep,
    s_last_i=>const_last,
    identity_i=>transfer_identity,
    arm_valid_i=>reg_arm_valid and eligible_arm,
    arm_ready_o=>loader_arm_ready,
    arm_bank_i=>reg_arm_bank,
    arm_identity_i=>reg_arm_identity,
    identity_bank_i=>cfg.model_bank,
    loaded_identity_o=>loaded_identity,
    bank_valid_o=>bank_valid,
    mem_req_valid_o=>loader_qv,
    mem_req_ready_i=>loader_qr,
    mem_req_o=>loader_q,
    mem_rsp_valid_i=>loader_rv,
    mem_rsp_ready_o=>loader_rr,
    mem_rsp_i=>loader_rsp);
  parameters:entity work.eat_parameter_store(rtl) port map(
    clk_i=>clk_i,
    rst_i=>service_rst,
    req_valid_i=>core_pv and flag(operation=INFERENCE),
    req_ready_o=>store_req_ready,
    req_i=>core_pq,
    rsp_valid_o=>store_rsp_valid,
    rsp_ready_i=>core_psr and flag(operation=INFERENCE),
    rsp_o=>core_ps,
    mem_req_valid_o=>store_qv,
    mem_req_ready_i=>store_qr,
    mem_req_o=>store_q,
    mem_rsp_valid_i=>store_rv,
    mem_rsp_ready_o=>store_rr,
    mem_rsp_i=>store_rsp);
  core_pr<=store_req_ready and flag(operation=INFERENCE) and not service_rst;core_psv<=store_rsp_valid and flag(operation=INFERENCE) and not service_rst;
  model_arbiter:entity work.eat_memory_arbiter(rtl) generic map(G_CLIENTS=>2) port map(
    clk_i=>clk_i,
    rst_i=>service_rst,
    client_valid_i=>model_cv,
    client_ready_o=>model_cr,
    client_req_i=>model_requests,
    client_rsp_valid_o=>model_rv,
    client_rsp_ready_i=>model_rr,
    client_rsp_o=>model_responses,
    mem_req_valid_o=>model_qv,
    mem_req_ready_i=>model_qr,
    mem_req_o=>model_q,
    mem_rsp_valid_i=>model_sv,
    mem_rsp_ready_o=>model_sr,
    mem_rsp_i=>model_rsp);
  input_arbiter:entity work.eat_memory_arbiter(rtl) generic map(G_CLIENTS=>2) port map(
    clk_i=>clk_i,
    rst_i=>service_rst,
    client_valid_i=>input_cv,
    client_ready_o=>input_cr,
    client_req_i=>input_requests,
    client_rsp_valid_o=>input_rv,
    client_rsp_ready_i=>input_rr,
    client_rsp_o=>input_responses,
    mem_req_valid_o=>input_qv,
    mem_req_ready_i=>input_qr,
    mem_req_o=>input_q,
    mem_rsp_valid_i=>input_sv,
    mem_rsp_ready_o=>input_sr,
    mem_rsp_i=>input_rsp);
  model_ram:entity work.eat_model_memory(rtl) generic map(G_BANKS=>G_RESIDENT_BANKS,G_WORDS_PER_BANK=>G_WORDS_PER_BANK) port map(
    clk_i=>clk_i,
    rst_i=>service_rst,
    req_valid_i=>model_qv,
    req_ready_o=>model_qr,
    req_i=>model_q,
    rsp_valid_o=>model_sv,
    rsp_ready_i=>model_sr,
    rsp_o=>model_rsp);
  input_ram:entity work.eat_input_buffer(rtl) generic map(G_WORDS=>320) port map(
    clk_i=>clk_i,
    rst_i=>service_rst,
    req_valid_i=>input_qv,
    req_ready_o=>input_qr,
    req_i=>input_q,
    rsp_valid_o=>input_sv,
    rsp_ready_i=>input_sr,
    rsp_o=>input_rsp);
  process(clk_i)
    variable status_value:status_t;
  begin
    if rising_edge(clk_i) then
      service_abort<='0';ingress_abort<='0';output_abort<='0';
      if rst_i='1' then
        operation<=IDLE;held_status<=C_STATUS_IDLE;frame_valid<='0';transfer_error_seen<='0';raw_last_seen<='0';core_done_seen<='0';output_done_seen<='0';snapshot_id<=(others=>'0');
      else
        if clear_status='1' and operation=IDLE then held_status<=C_STATUS_IDLE;end if;
        case operation is
          when IDLE =>
            if reg_transfer_valid='1' and reg_transfer_ready='1' then
              operation<=TRANSFER;held_status<=C_STATUS_IDLE;held_status.ctx<=transfer_command.ctx;frame_valid<='0';transfer_error_seen<='0';raw_last_seen<='0';transfer_identity<=cfg.expected_identity;transfer_request<=cfg;
            elsif reg_arm_valid='1' and reg_arm_ready='1' then
              operation<=ARM_BANK;held_status<=C_STATUS_IDLE;
            elsif reg_request_valid='1' and reg_request_ready='1' then
              saved_request<=requested;operation<=START_CORE;held_status<=C_STATUS_IDLE;held_status.ctx<=(requested.inference_id,requested.mode,requested.workload,requested.model_bank);core_done_seen<='0';output_done_seen<='0';
            end if;
          when TRANSFER =>
            if input_rv(0)='1' and input_responses(0).tag(15)='1' and input_responses(0).error='0' then raw_last_seen<='1';end if;
            if transfer_fault='1' and transfer_error_seen='0' then
              transfer_error_seen<='1';held_status.error<='1';held_status.code<=ERR_FRAME;held_status.done<='0';frame_valid<='0';service_abort<='1';
              if loader_status.error='1' then held_status.code<=loader_status.code;end if;
              if ingress_error='0' then ingress_abort<='1';end if;
            end if;
            if transfer_finish='1' then
              operation<=IDLE;held_status.done<='1';
              if transfer_error_seen='1' or transfer_fault='1' then
                held_status.error<='1';if transfer_error_seen='0' then held_status.code<=ERR_FRAME;if loader_status.error='1' then held_status.code<=loader_status.code;end if;end if;
              else
                held_status.error<='0';held_status.code<=ERR_NONE;
                if active_transfer.kind=TRANSFER_INPUT then frame_valid<='1';frame_request<=transfer_request;end if;
              end if;
            end if;
          when ARM_BANK => if loader_dv='1' then held_status<=loader_status;operation<=IDLE;end if;
          when START_CORE =>
            if mode_status.error='1' then held_status<=mode_status;held_status.done<='1';operation<=IDLE;
            elsif mode_active_valid='1' and core_start_ready='1' then operation<=INFERENCE;end if;
          when INFERENCE =>
            if core_status.done='1' then core_done_seen<='1';end if;if serializer_done='1' then output_done_seen<='1';end if;
            if core_status.error='1' then held_status<=core_status;operation<=IDLE;output_abort<='1';
            elsif kernel_finish='1' then
              held_status<=('0','1','0',ERR_NONE,(saved_request.inference_id,saved_request.mode,saved_request.workload,saved_request.model_bank));snapshot_id<=saved_request.inference_id;operation<=IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
