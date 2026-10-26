-- Generated structural test only. This is not arithmetic/protocol verification.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;

entity tb_skeleton_smoke is end entity;
architecture structural_test of tb_skeleton_smoke is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal check_0 : std_logic;
  signal check_1 : std_logic;
  signal check_2 : std_logic;
  signal check_3 : std_logic;
  signal check_4 : std_logic;
  signal check_5 : std_logic;
  signal check_6 : std_logic;
  signal check_7 : std_logic;
  signal check_8 : std_logic;
  signal check_9 : std_logic;
  signal check_10 : std_logic;
  signal check_11 : std_logic;
  signal check_12 : std_logic;
  signal check_13 : std_logic;
  signal check_14 : std_logic;
  signal check_15 : std_logic;
  signal check_16 : std_logic;
  signal check_17 : std_logic;
  signal check_18 : std_logic;
  signal check_19 : std_logic;
  signal check_20 : std_logic;
  signal check_21 : std_logic;
  signal check_22 : std_logic;
  signal check_23 : std_logic;
  signal check_24 : std_logic;
  signal check_25 : std_logic;
  signal check_26 : std_logic;
  signal check_27 : std_logic;
  signal check_28 : std_logic;
  signal check_29 : std_logic;
  signal check_30 : std_logic;
  signal check_31 : std_logic;
  signal check_32 : std_logic;
  signal check_33 : std_logic;
  signal check_34 : std_logic;
  signal check_35 : std_logic;
  signal check_36 : std_logic;
  signal check_37 : std_logic;
  signal check_38 : std_logic;
  signal check_39 : std_logic;
  signal check_40 : std_logic;
  signal check_41 : std_logic;
  signal check_42 : std_logic;
  signal check_43 : std_logic;
  signal check_44 : std_logic;
  signal check_45 : std_logic;
  signal check_46 : std_logic;
  signal check_47 : std_logic;
  signal check_48 : std_logic;
  signal check_49 : std_logic;
  signal check_50 : std_logic;
  signal check_51 : std_logic;
  signal check_52 : std_logic;
  signal check_53 : std_logic;
  signal check_54 : std_logic;
  signal check_55 : std_logic;
  signal check_56 : std_logic;
  signal check_57 : std_logic;
  signal check_58 : std_logic;
  signal check_59 : std_logic;
  signal check_60 : std_logic;
begin
  clk <= not clk after 5 ns;
  rst <= '0' after 20 ns;
  u_eat_parameter_store : entity work.eat_parameter_store(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      req_valid_i => '1',
      req_ready_o => check_0,
      req_i => C_PARAM_REQ_IDLE,
      rsp_valid_o => check_1,
      rsp_ready_i => '0',
      rsp_o => open,
      mem_req_valid_o => check_2,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_3,
      mem_rsp_i => C_MEM_RSP_IDLE
    );
  u_eat_constant_loader : entity work.eat_constant_loader(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_4,
      cmd_i => C_TRANSFER_CMD_IDLE,
      done_valid_o => check_5,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_6,
      s_data_i => (others => '0'),
      s_keep_i => (others => '0'),
      s_last_i => '0',
      identity_i => (others => '0'),
      loaded_identity_o => open,
      bank_valid_o => open,
      mem_req_valid_o => check_7,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_8,
      mem_rsp_i => C_MEM_RSP_IDLE
    );
  u_eat_address_generator : entity work.eat_address_generator(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_9,
      cmd_i => C_MATRIX_CMD_IDLE,
      done_valid_o => check_10,
      done_ready_i => '0',
      status_o => open,
      step_ready_i => '0',
      step_valid_o => check_11,
      activation_addr_o => open,
      weight_addr_o => open,
      row_mask_o => open,
      column_mask_o => open,
      first_k_o => open,
      last_k_o => open
    );
  u_eat_patch_reader : entity work.eat_patch_reader(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_12,
      cmd_i => C_MATRIX_CMD_IDLE,
      done_valid_o => check_13,
      done_ready_i => '0',
      status_o => open,
      host_input_q12_shift_i => (others => '0'),
      m_valid_o => check_14,
      m_ready_i => '0',
      m_data_o => open,
      mem_req_valid_o => check_15,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_16,
      mem_rsp_i => C_MEM_RSP_IDLE
    );
  u_eat_qk_tile_engine : entity work.eat_qk_tile_engine(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_17,
      cmd_i => C_ATTENTION_CMD_IDLE,
      done_valid_o => check_18,
      done_ready_i => '0',
      status_o => open,
      q_valid_i => '1',
      q_ready_o => check_19,
      q_data_i => C_ACT_BEAT_IDLE,
      k_valid_i => '1',
      k_ready_o => check_20,
      k_data_i => C_ACT_BEAT_IDLE,
      m_valid_o => check_21,
      m_ready_i => '0',
      qk_q24_o => open,
      query_token_o => open,
      key_token_o => open,
      head_o => open,
      last_tile_o => open,
      overflow_o => open
    );
  u_eat_rowmax_exp : entity work.eat_rowmax_exp(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_22,
      cmd_i => C_ATTENTION_CMD_IDLE,
      done_valid_o => check_23,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_24,
      s_data_i => C_SCORE_BEAT_IDLE,
      previous_max_i => (others => '0'),
      previous_max_valid_i => '1',
      m_valid_o => check_25,
      m_ready_i => '0',
      m_data_o => open,
      new_max_o => open,
      alpha_o => open,
      param_req_valid_o => check_26,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_27,
      param_rsp_i => C_PARAM_RSP_IDLE
    );
  u_eat_av_tile_engine : entity work.eat_av_tile_engine(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_28,
      cmd_i => C_ATTENTION_CMD_IDLE,
      done_valid_o => check_29,
      done_ready_i => '0',
      status_o => open,
      p_valid_i => '1',
      p_ready_o => check_30,
      p_data_i => C_EXP_BEAT_IDLE,
      v_valid_i => '1',
      v_ready_o => check_31,
      v_data_i => C_ACT_BEAT_IDLE,
      previous_state_i => (others => (others => '0')),
      alpha_i => (others => '0'),
      m_valid_o => check_32,
      m_ready_i => '0',
      weighted_state_o => open,
      overflow_o => open
    );
  u_eat_rts_summary : entity work.eat_rts_summary(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_33,
      cmd_i => C_GATE_CMD_IDLE,
      done_valid_o => check_34,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_35,
      s_data_i => C_STATE_BEAT_IDLE,
      score_valid_i => '1',
      score_ready_o => check_36,
      token_score_i => (others => '0'),
      m_valid_o => check_37,
      m_ready_i => '0',
      m_data_o => open,
      overflow_o => open
    );
  u_eat_encoder_sequencer : entity work.eat_encoder_sequencer(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      start_valid_i => '1',
      start_ready_o => check_38,
      ctx_i => C_CONTEXT_IDLE,
      matrix_valid_o => check_39,
      matrix_ready_i => '0',
      matrix_o => open,
      vector_valid_o => check_40,
      vector_ready_i => '0',
      vector_o => open,
      attention_valid_o => check_41,
      attention_ready_i => '0',
      attention_o => open,
      gate_valid_o => check_42,
      gate_ready_i => '0',
      gate_o => open,
      unit_status_i => C_STATUS_IDLE,
      unit_done_valid_i => '1',
      unit_done_ready_o => check_43,
      output_accepted_i => '0',
      status_o => open
    );
  u_eat_axi_ctrl_regs : entity work.eat_axi_ctrl_regs(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_axi_awaddr_i => (others => '0'),
      s_axi_awvalid_i => '0',
      s_axi_awready_o => open,
      s_axi_wdata_i => (others => '0'),
      s_axi_wstrb_i => (others => '0'),
      s_axi_wvalid_i => '0',
      s_axi_wready_o => open,
      s_axi_bresp_o => open,
      s_axi_bvalid_o => open,
      s_axi_bready_i => '0',
      s_axi_araddr_i => (others => '0'),
      s_axi_arvalid_i => '0',
      s_axi_arready_o => open,
      s_axi_rdata_o => open,
      s_axi_rresp_o => open,
      s_axi_rvalid_o => open,
      s_axi_rready_i => '0',
      request_valid_o => check_44,
      request_ready_i => '0',
      request_o => open,
      transfer_valid_o => check_45,
      transfer_ready_i => '0',
      transfer_o => open,
      status_i => C_STATUS_IDLE,
      loaded_identity_i => (others => '0'),
      counters_i => C_COUNTERS_IDLE,
      interrupt_o => check_46
    );
  u_eat_dma_descriptor_engine : entity work.eat_dma_descriptor_engine(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_47,
      cmd_i => C_TRANSFER_CMD_IDLE,
      done_valid_o => check_48,
      done_ready_i => '0',
      status_o => open,
      stream_bytes_accepted_i => (others => '0'),
      stream_last_i => '0',
      frame_error_i => '0',
      active_transfer_o => open,
      active_valid_o => check_49
    );
  u_eat_axi_stream_input : entity work.eat_axi_stream_input(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_axis_tdata_i => (others => '0'),
      s_axis_tkeep_i => (others => '0'),
      s_axis_tlast_i => '0',
      s_axis_tvalid_i => '0',
      s_axis_tready_o => open,
      transfer_i => C_TRANSFER_CMD_IDLE,
      transfer_valid_i => '1',
      input_valid_o => check_50,
      input_ready_i => '0',
      input_data_o => open,
      constant_valid_o => check_51,
      constant_ready_i => '0',
      constant_data_o => open,
      constant_keep_o => open,
      constant_last_o => open,
      frame_error_o => open
    );
  u_eat_encoder_core : entity work.eat_encoder_core(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      start_valid_i => '1',
      start_ready_o => check_52,
      request_i => C_CONTROL_REQUEST_IDLE,
      logits_valid_o => check_53,
      logits_ready_i => '0',
      logits_o => open,
      status_o => open,
      event_valid_o => check_54,
      event_o => open,
      event_count_o => open,
      mem_req_valid_o => check_55,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_56,
      mem_rsp_i => C_MEM_RSP_IDLE,
      param_req_valid_o => check_57,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_58,
      param_rsp_i => C_PARAM_RSP_IDLE
    );
  u_eat_fpga_top : entity work.eat_fpga_top(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_axi_awaddr_i => (others => '0'),
      s_axi_awvalid_i => '0',
      s_axi_awready_o => open,
      s_axi_wdata_i => (others => '0'),
      s_axi_wstrb_i => (others => '0'),
      s_axi_wvalid_i => '0',
      s_axi_wready_o => open,
      s_axi_bresp_o => open,
      s_axi_bvalid_o => open,
      s_axi_bready_i => '0',
      s_axi_araddr_i => (others => '0'),
      s_axi_arvalid_i => '0',
      s_axi_arready_o => open,
      s_axi_rdata_o => open,
      s_axi_rresp_o => open,
      s_axi_rvalid_o => open,
      s_axi_rready_i => '0',
      s_axis_tdata_i => (others => '0'),
      s_axis_tkeep_i => (others => '0'),
      s_axis_tlast_i => '0',
      s_axis_tvalid_i => '0',
      s_axis_tready_o => open,
      m_axis_tdata_o => open,
      m_axis_tkeep_o => open,
      m_axis_tlast_o => open,
      m_axis_tvalid_o => open,
      m_axis_tready_i => '0',
      interrupt_o => check_59
    );
  u_eat_platform_wrapper : entity work.eat_platform_wrapper(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      arst_n_i => not rst,
      s_axi_awaddr_i => (others => '0'),
      s_axi_awvalid_i => '0',
      s_axi_awready_o => open,
      s_axi_wdata_i => (others => '0'),
      s_axi_wstrb_i => (others => '0'),
      s_axi_wvalid_i => '0',
      s_axi_wready_o => open,
      s_axi_bresp_o => open,
      s_axi_bvalid_o => open,
      s_axi_bready_i => '0',
      s_axi_araddr_i => (others => '0'),
      s_axi_arvalid_i => '0',
      s_axi_arready_o => open,
      s_axi_rdata_o => open,
      s_axi_rresp_o => open,
      s_axi_rvalid_o => open,
      s_axi_rready_i => '0',
      s_axis_tdata_i => (others => '0'),
      s_axis_tkeep_i => (others => '0'),
      s_axis_tlast_i => '0',
      s_axis_tvalid_i => '0',
      s_axis_tready_o => open,
      m_axis_tdata_o => open,
      m_axis_tkeep_o => open,
      m_axis_tlast_o => open,
      m_axis_tvalid_o => open,
      m_axis_tready_i => '0',
      interrupt_o => check_60
    );
  process
  begin
    wait for 60 ns;
    assert check_0 = '0' report "Stub accepted/emitted a transaction: eat_parameter_store.req_ready_o" severity failure;
    assert check_1 = '0' report "Stub accepted/emitted a transaction: eat_parameter_store.rsp_valid_o" severity failure;
    assert check_2 = '0' report "Stub accepted/emitted a transaction: eat_parameter_store.mem_req_valid_o" severity failure;
    assert check_3 = '0' report "Stub accepted/emitted a transaction: eat_parameter_store.mem_rsp_ready_o" severity failure;
    assert check_4 = '0' report "Stub accepted/emitted a transaction: eat_constant_loader.cmd_ready_o" severity failure;
    assert check_5 = '0' report "Stub accepted/emitted a transaction: eat_constant_loader.done_valid_o" severity failure;
    assert check_6 = '0' report "Stub accepted/emitted a transaction: eat_constant_loader.s_ready_o" severity failure;
    assert check_7 = '0' report "Stub accepted/emitted a transaction: eat_constant_loader.mem_req_valid_o" severity failure;
    assert check_8 = '0' report "Stub accepted/emitted a transaction: eat_constant_loader.mem_rsp_ready_o" severity failure;
    assert check_9 = '0' report "Stub accepted/emitted a transaction: eat_address_generator.cmd_ready_o" severity failure;
    assert check_10 = '0' report "Stub accepted/emitted a transaction: eat_address_generator.done_valid_o" severity failure;
    assert check_11 = '0' report "Stub accepted/emitted a transaction: eat_address_generator.step_valid_o" severity failure;
    assert check_12 = '0' report "Stub accepted/emitted a transaction: eat_patch_reader.cmd_ready_o" severity failure;
    assert check_13 = '0' report "Stub accepted/emitted a transaction: eat_patch_reader.done_valid_o" severity failure;
    assert check_14 = '0' report "Stub accepted/emitted a transaction: eat_patch_reader.m_valid_o" severity failure;
    assert check_15 = '0' report "Stub accepted/emitted a transaction: eat_patch_reader.mem_req_valid_o" severity failure;
    assert check_16 = '0' report "Stub accepted/emitted a transaction: eat_patch_reader.mem_rsp_ready_o" severity failure;
    assert check_17 = '0' report "Stub accepted/emitted a transaction: eat_qk_tile_engine.cmd_ready_o" severity failure;
    assert check_18 = '0' report "Stub accepted/emitted a transaction: eat_qk_tile_engine.done_valid_o" severity failure;
    assert check_19 = '0' report "Stub accepted/emitted a transaction: eat_qk_tile_engine.q_ready_o" severity failure;
    assert check_20 = '0' report "Stub accepted/emitted a transaction: eat_qk_tile_engine.k_ready_o" severity failure;
    assert check_21 = '0' report "Stub accepted/emitted a transaction: eat_qk_tile_engine.m_valid_o" severity failure;
    assert check_22 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.cmd_ready_o" severity failure;
    assert check_23 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.done_valid_o" severity failure;
    assert check_24 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.s_ready_o" severity failure;
    assert check_25 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.m_valid_o" severity failure;
    assert check_26 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.param_req_valid_o" severity failure;
    assert check_27 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.param_rsp_ready_o" severity failure;
    assert check_28 = '0' report "Stub accepted/emitted a transaction: eat_av_tile_engine.cmd_ready_o" severity failure;
    assert check_29 = '0' report "Stub accepted/emitted a transaction: eat_av_tile_engine.done_valid_o" severity failure;
    assert check_30 = '0' report "Stub accepted/emitted a transaction: eat_av_tile_engine.p_ready_o" severity failure;
    assert check_31 = '0' report "Stub accepted/emitted a transaction: eat_av_tile_engine.v_ready_o" severity failure;
    assert check_32 = '0' report "Stub accepted/emitted a transaction: eat_av_tile_engine.m_valid_o" severity failure;
    assert check_33 = '0' report "Stub accepted/emitted a transaction: eat_rts_summary.cmd_ready_o" severity failure;
    assert check_34 = '0' report "Stub accepted/emitted a transaction: eat_rts_summary.done_valid_o" severity failure;
    assert check_35 = '0' report "Stub accepted/emitted a transaction: eat_rts_summary.s_ready_o" severity failure;
    assert check_36 = '0' report "Stub accepted/emitted a transaction: eat_rts_summary.score_ready_o" severity failure;
    assert check_37 = '0' report "Stub accepted/emitted a transaction: eat_rts_summary.m_valid_o" severity failure;
    assert check_38 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.start_ready_o" severity failure;
    assert check_39 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.matrix_valid_o" severity failure;
    assert check_40 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.vector_valid_o" severity failure;
    assert check_41 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.attention_valid_o" severity failure;
    assert check_42 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.gate_valid_o" severity failure;
    assert check_43 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.unit_done_ready_o" severity failure;
    assert check_44 = '0' report "Stub accepted/emitted a transaction: eat_axi_ctrl_regs.request_valid_o" severity failure;
    assert check_45 = '0' report "Stub accepted/emitted a transaction: eat_axi_ctrl_regs.transfer_valid_o" severity failure;
    assert check_46 = '0' report "Stub accepted/emitted a transaction: eat_axi_ctrl_regs.interrupt_o" severity failure;
    assert check_47 = '0' report "Stub accepted/emitted a transaction: eat_dma_descriptor_engine.cmd_ready_o" severity failure;
    assert check_48 = '0' report "Stub accepted/emitted a transaction: eat_dma_descriptor_engine.done_valid_o" severity failure;
    assert check_49 = '0' report "Stub accepted/emitted a transaction: eat_dma_descriptor_engine.active_valid_o" severity failure;
    assert check_50 = '0' report "Stub accepted/emitted a transaction: eat_axi_stream_input.input_valid_o" severity failure;
    assert check_51 = '0' report "Stub accepted/emitted a transaction: eat_axi_stream_input.constant_valid_o" severity failure;
    assert check_52 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.start_ready_o" severity failure;
    assert check_53 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.logits_valid_o" severity failure;
    assert check_54 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.event_valid_o" severity failure;
    assert check_55 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.mem_req_valid_o" severity failure;
    assert check_56 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.mem_rsp_ready_o" severity failure;
    assert check_57 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.param_req_valid_o" severity failure;
    assert check_58 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.param_rsp_ready_o" severity failure;
    assert check_59 = '0' report "Stub accepted/emitted a transaction: eat_fpga_top.interrupt_o" severity failure;
    assert check_60 = '0' report "Stub accepted/emitted a transaction: eat_platform_wrapper.interrupt_o" severity failure;
    report "STRUCTURAL_SMOKE_PASS: inert stubs only; no numerical verification" severity note;
    stop;
    wait;
  end process;
end architecture;
