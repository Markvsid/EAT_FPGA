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
  signal check_61 : std_logic;
  signal check_62 : std_logic;
  signal check_63 : std_logic;
  signal check_64 : std_logic;
  signal check_65 : std_logic;
  signal check_66 : std_logic;
  signal check_67 : std_logic;
  signal check_68 : std_logic;
  signal check_69 : std_logic;
  signal check_70 : std_logic;
  signal check_71 : std_logic;
  signal check_72 : std_logic;
  signal check_73 : std_logic;
  signal check_74 : std_logic;
  signal check_75 : std_logic;
  signal check_76 : std_logic;
  signal check_77 : std_logic;
  signal check_78 : std_logic;
  signal check_79 : std_logic;
  signal check_80 : std_logic;
  signal check_81 : std_logic;
  signal check_82 : std_logic;
  signal check_83 : std_logic;
  signal check_84 : std_logic;
  signal check_85 : std_logic;
  signal check_86 : std_logic;
  signal check_87 : std_logic;
  signal check_88 : std_logic;
  signal check_89 : std_logic;
  signal check_90 : std_logic;
  signal check_91 : std_logic;
  signal check_92 : std_logic;
  signal check_93 : std_logic;
  signal check_94 : std_logic;
  signal check_95 : std_logic;
  signal check_96 : std_logic;
  signal check_97 : std_logic;
  signal check_98 : std_logic;
  signal check_99 : std_logic;
  signal check_100 : std_logic;
  signal check_101 : std_logic;
  signal check_102 : std_logic;
  signal check_103 : std_logic;
  signal check_104 : std_logic;
  signal check_105 : std_logic;
  signal check_106 : std_logic;
  signal check_107 : std_logic;
  signal check_108 : std_logic;
  signal check_109 : std_logic;
  signal check_110 : std_logic;
  signal check_111 : std_logic;
  signal check_112 : std_logic;
  signal check_113 : std_logic;
  signal check_114 : std_logic;
  signal check_115 : std_logic;
  signal check_116 : std_logic;
  signal check_117 : std_logic;
  signal check_118 : std_logic;
  signal check_119 : std_logic;
  signal check_120 : std_logic;
  signal check_121 : std_logic;
  signal check_122 : std_logic;
  signal check_123 : std_logic;
  signal check_124 : std_logic;
  signal check_125 : std_logic;
  signal check_126 : std_logic;
  signal check_127 : std_logic;
  signal check_128 : std_logic;
  signal check_129 : std_logic;
  signal check_130 : std_logic;
  signal check_131 : std_logic;
  signal check_132 : std_logic;
  signal check_133 : std_logic;
  signal check_134 : std_logic;
  signal check_135 : std_logic;
  signal check_136 : std_logic;
  signal check_137 : std_logic;
  signal check_138 : std_logic;
  signal check_139 : std_logic;
  signal check_140 : std_logic;
  signal check_141 : std_logic;
  signal check_142 : std_logic;
  signal check_143 : std_logic;
  signal check_144 : std_logic;
  signal check_145 : std_logic;
  signal check_146 : std_logic;
  signal check_147 : std_logic;
  signal check_148 : std_logic;
  signal check_149 : std_logic;
  signal check_150 : std_logic;
  signal check_151 : std_logic;
  signal check_152 : std_logic;
  signal check_153 : std_logic;
  signal check_154 : std_logic;
  signal check_155 : std_logic;
  signal check_156 : std_logic;
  signal check_157 : std_logic;
  signal check_158 : std_logic;
  signal check_159 : std_logic;
  signal check_160 : std_logic;
  signal check_161 : std_logic;
  signal check_162 : std_logic;
  signal check_163 : std_logic;
  signal check_164 : std_logic;
  signal check_165 : std_logic;
  signal check_166 : std_logic;
  signal check_167 : std_logic;
  signal check_168 : std_logic;
  signal check_169 : std_logic;
  signal check_170 : std_logic;
  signal check_171 : std_logic;
  signal check_172 : std_logic;
  signal check_173 : std_logic;
  signal check_174 : std_logic;
  signal check_175 : std_logic;
  signal check_176 : std_logic;
  signal check_177 : std_logic;
  signal check_178 : std_logic;
  signal check_179 : std_logic;
  signal check_180 : std_logic;
begin
  clk <= not clk after 5 ns;
  rst <= '0' after 20 ns;
  u_eat_reset_sync : entity work.eat_reset_sync(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      arst_n_i => not rst,
      rst_o => open
    );
  u_eat_rv_fifo : entity work.eat_rv_fifo(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      flush_i => '0',
      s_valid_i => '1',
      s_ready_o => check_0,
      s_data_i => (others => '0'),
      m_valid_o => check_1,
      m_ready_i => '0',
      m_data_o => open,
      occupancy_o => open
    );
  u_eat_stream_register : entity work.eat_stream_register(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_2,
      s_data_i => C_STATE_BEAT_IDLE,
      m_valid_o => check_3,
      m_ready_i => '0',
      m_data_o => open
    );
  u_eat_round_shift : entity work.eat_round_shift(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_4,
      x_i => (others => '0'),
      shift_i => (others => '0'),
      m_valid_o => check_5,
      m_ready_i => '0',
      y_o => open,
      saturated_o => open,
      overflow_o => open
    );
  u_eat_round_divide : entity work.eat_round_divide(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_6,
      numerator_i => (others => '0'),
      denominator_i => (others => '0'),
      m_valid_o => check_7,
      m_ready_i => '0',
      quotient_o => open,
      divide_by_zero_o => open,
      overflow_o => open
    );
  u_eat_reduction_tree : entity work.eat_reduction_tree(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_8,
      values_i => (others => (others => '0')),
      keep_i => (others => '0'),
      m_valid_o => check_9,
      m_ready_i => '0',
      sum_o => open,
      overflow_o => open
    );
  u_eat_leading_one : entity work.eat_leading_one(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_10,
      value_i => (others => '0'),
      m_valid_o => check_11,
      m_ready_i => '0',
      exponent_o => open,
      zero_o => open
    );
  u_eat_exp_lut : entity work.eat_exp_lut(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_12,
      negative_argument_i => (others => '0'),
      table_base_i => (others => '0'),
      bank_i => (others => '0'),
      m_valid_o => check_13,
      m_ready_i => '0',
      exp_o => open,
      param_req_valid_o => check_14,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_15,
      param_rsp_i => C_PARAM_RSP_IDLE
    );
  u_eat_rsqrt_lut : entity work.eat_rsqrt_lut(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_16,
      address_i => (others => '0'),
      table_base_i => (others => '0'),
      bank_i => (others => '0'),
      m_valid_o => check_17,
      m_ready_i => '0',
      coefficient_q30_o => open,
      param_req_valid_o => check_18,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_19,
      param_rsp_i => C_PARAM_RSP_IDLE
    );
  u_eat_pwl_silu : entity work.eat_pwl_silu(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_20,
      cmd_i => C_VECTOR_CMD_IDLE,
      done_valid_o => check_21,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_22,
      s_data_i => C_STATE_BEAT_IDLE,
      m_valid_o => check_23,
      m_ready_i => '0',
      m_data_o => open,
      param_req_valid_o => check_24,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_25,
      param_rsp_i => C_PARAM_RSP_IDLE
    );
  u_eat_memory_arbiter : entity work.eat_memory_arbiter(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      client_valid_i => (others => '0'),
      client_ready_o => open,
      client_req_i => (others => C_MEM_REQ_IDLE),
      client_rsp_valid_o => open,
      client_rsp_ready_i => (others => '0'),
      client_rsp_o => open,
      mem_req_valid_o => check_26,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_27,
      mem_rsp_i => C_MEM_RSP_IDLE
    );
  u_eat_input_buffer : entity work.eat_input_buffer(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      req_valid_i => '1',
      req_ready_o => check_28,
      req_i => C_MEM_REQ_IDLE,
      rsp_valid_o => check_29,
      rsp_ready_i => '0',
      rsp_o => open
    );
  u_eat_weight_buffer_banked : entity work.eat_weight_buffer_banked(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      req_valid_i => '1',
      req_ready_o => check_30,
      req_i => C_MEM_REQ_IDLE,
      rsp_valid_o => check_31,
      rsp_ready_i => '0',
      rsp_o => open
    );
  u_eat_activation_buffer_pingpong : entity work.eat_activation_buffer_pingpong(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      req_valid_i => '1',
      req_ready_o => check_32,
      req_i => C_MEM_REQ_IDLE,
      rsp_valid_o => check_33,
      rsp_ready_i => '0',
      rsp_o => open
    );
  u_eat_attention_state_buffer : entity work.eat_attention_state_buffer(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      req_valid_i => '1',
      req_ready_o => check_34,
      req_i => C_MEM_REQ_IDLE,
      rsp_valid_o => check_35,
      rsp_ready_i => '0',
      rsp_o => open
    );
  u_eat_token_index_buffer : entity work.eat_token_index_buffer(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      req_valid_i => '1',
      req_ready_o => check_36,
      req_i => C_MEM_REQ_IDLE,
      rsp_valid_o => check_37,
      rsp_ready_i => '0',
      rsp_o => open
    );
  u_eat_parameter_store : entity work.eat_parameter_store(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      req_valid_i => '1',
      req_ready_o => check_38,
      req_i => C_PARAM_REQ_IDLE,
      rsp_valid_o => check_39,
      rsp_ready_i => '0',
      rsp_o => open,
      mem_req_valid_o => check_40,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_41,
      mem_rsp_i => C_MEM_RSP_IDLE
    );
  u_eat_constant_loader : entity work.eat_constant_loader(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_42,
      cmd_i => C_TRANSFER_CMD_IDLE,
      done_valid_o => check_43,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_44,
      s_data_i => (others => '0'),
      s_keep_i => (others => '0'),
      s_last_i => '0',
      identity_i => (others => '0'),
      loaded_identity_o => open,
      bank_valid_o => open,
      mem_req_valid_o => check_45,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_46,
      mem_rsp_i => C_MEM_RSP_IDLE
    );
  u_eat_address_generator : entity work.eat_address_generator(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_47,
      cmd_i => C_MATRIX_CMD_IDLE,
      done_valid_o => check_48,
      done_ready_i => '0',
      status_o => open,
      step_ready_i => '0',
      step_valid_o => check_49,
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
      cmd_ready_o => check_50,
      cmd_i => C_MATRIX_CMD_IDLE,
      done_valid_o => check_51,
      done_ready_i => '0',
      status_o => open,
      host_input_q12_shift_i => (others => '0'),
      m_valid_o => check_52,
      m_ready_i => '0',
      m_data_o => open,
      mem_req_valid_o => check_53,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_54,
      mem_rsp_i => C_MEM_RSP_IDLE
    );
  u_eat_activation_quantizer : entity work.eat_activation_quantizer(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      shift_i => (others => '0'),
      s_valid_i => '1',
      s_ready_o => check_55,
      s_data_i => C_STATE_BEAT_IDLE,
      m_valid_o => check_56,
      m_ready_i => '0',
      m_data_o => open,
      saturation_events_o => open
    );
  u_eat_weight_unpack : entity work.eat_weight_unpack(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_57,
      packed_i => (others => '0'),
      half_i => '0',
      weight_bits_i => 0,
      keep_i => (others => '0'),
      m_valid_o => check_58,
      m_ready_i => '0',
      weights_o => open,
      keep_o => open,
      error_o => open
    );
  u_eat_mac_lane : entity work.eat_mac_lane(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_59,
      activation_i => (others => '0'),
      weight_i => (others => '0'),
      enable_i => '0',
      first_k_i => '0',
      last_k_i => '0',
      m_valid_o => check_60,
      m_ready_i => '0',
      accumulator_o => open,
      overflow_o => open
    );
  u_eat_mac_array : entity work.eat_mac_array(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_61,
      activations_i => (others => (others => '0')),
      weights_i => (others => (others => '0')),
      row_mask_i => (others => '0'),
      column_mask_i => (others => '0'),
      first_k_i => '0',
      last_k_i => '0',
      m_valid_o => check_62,
      m_ready_i => '0',
      accumulators_o => open,
      active_products_o => open,
      overflow_o => open
    );
  u_eat_requantizer : entity work.eat_requantizer(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_63,
      accumulators_i => (others => (others => '0')),
      bias_i => (others => (others => '0')),
      multipliers_i => (others => (others => '0')),
      keep_i => (others => '0'),
      token_i => 0,
      feature_base_i => 0,
      last_i => '0',
      ctx_i => C_CONTEXT_IDLE,
      m_valid_o => check_64,
      m_ready_i => '0',
      m_data_o => open,
      saturation_events_o => open,
      overflow_o => open
    );
  u_eat_tensor_engine : entity work.eat_tensor_engine(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_65,
      cmd_i => C_MATRIX_CMD_IDLE,
      done_valid_o => check_66,
      done_ready_i => '0',
      status_o => open,
      m_valid_o => check_67,
      m_ready_i => '0',
      m_data_o => open,
      mem_req_valid_o => check_68,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_69,
      mem_rsp_i => C_MEM_RSP_IDLE,
      param_req_valid_o => check_70,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_71,
      param_rsp_i => C_PARAM_RSP_IDLE
    );
  u_eat_position_add : entity work.eat_position_add(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_72,
      cmd_i => C_VECTOR_CMD_IDLE,
      done_valid_o => check_73,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_74,
      s_data_i => C_STATE_BEAT_IDLE,
      m_valid_o => check_75,
      m_ready_i => '0',
      m_data_o => open,
      param_req_valid_o => check_76,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_77,
      param_rsp_i => C_PARAM_RSP_IDLE
    );
  u_eat_residual_add : entity work.eat_residual_add(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_78,
      cmd_i => C_VECTOR_CMD_IDLE,
      done_valid_o => check_79,
      done_ready_i => '0',
      status_o => open,
      a_valid_i => '1',
      a_ready_o => check_80,
      a_data_i => C_STATE_BEAT_IDLE,
      b_valid_i => '1',
      b_ready_o => check_81,
      b_data_i => C_STATE_BEAT_IDLE,
      m_valid_o => check_82,
      m_ready_i => '0',
      m_data_o => open,
      saturation_events_o => open
    );
  u_eat_mean_pool : entity work.eat_mean_pool(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_83,
      cmd_i => C_VECTOR_CMD_IDLE,
      done_valid_o => check_84,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_85,
      s_data_i => C_STATE_BEAT_IDLE,
      m_valid_o => check_86,
      m_ready_i => '0',
      m_data_o => open
    );
  u_eat_rmsnorm : entity work.eat_rmsnorm(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_87,
      cmd_i => C_VECTOR_CMD_IDLE,
      done_valid_o => check_88,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_89,
      s_data_i => C_STATE_BEAT_IDLE,
      m_valid_o => check_90,
      m_ready_i => '0',
      m_data_o => open,
      param_req_valid_o => check_91,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_92,
      param_rsp_i => C_PARAM_RSP_IDLE,
      mem_req_valid_o => check_93,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_94,
      mem_rsp_i => C_MEM_RSP_IDLE
    );
  u_eat_qkv_quantizer : entity work.eat_qkv_quantizer(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_95,
      cmd_i => C_ATTENTION_CMD_IDLE,
      done_valid_o => check_96,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_97,
      s_data_i => C_STATE_BEAT_IDLE,
      q_valid_o => check_98,
      q_ready_i => '0',
      q_data_o => open,
      k_valid_o => check_99,
      k_ready_i => '0',
      k_data_o => open,
      v_valid_o => check_100,
      v_ready_i => '0',
      v_data_o => open
    );
  u_eat_qk_tile_engine : entity work.eat_qk_tile_engine(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_101,
      cmd_i => C_ATTENTION_CMD_IDLE,
      done_valid_o => check_102,
      done_ready_i => '0',
      status_o => open,
      q_valid_i => '1',
      q_ready_o => check_103,
      q_data_i => C_ACT_BEAT_IDLE,
      k_valid_i => '1',
      k_ready_o => check_104,
      k_data_i => C_ACT_BEAT_IDLE,
      m_valid_o => check_105,
      m_ready_i => '0',
      qk_q24_o => open,
      query_token_o => open,
      key_token_o => open,
      head_o => open,
      last_tile_o => open,
      overflow_o => open
    );
  u_eat_score_scale : entity work.eat_score_scale(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_106,
      qk_q24_i => (others => '0'),
      scale_multiplier_q20_i => (others => '0'),
      m_valid_o => check_107,
      m_ready_i => '0',
      score_q12_o => open,
      overflow_o => open
    );
  u_eat_rowmax_exp : entity work.eat_rowmax_exp(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_108,
      cmd_i => C_ATTENTION_CMD_IDLE,
      done_valid_o => check_109,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_110,
      s_data_i => C_SCORE_BEAT_IDLE,
      previous_max_i => (others => '0'),
      previous_max_valid_i => '1',
      m_valid_o => check_111,
      m_ready_i => '0',
      m_data_o => open,
      new_max_o => open,
      alpha_o => open,
      param_req_valid_o => check_112,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_113,
      param_rsp_i => C_PARAM_RSP_IDLE
    );
  u_eat_running_normalizer : entity work.eat_running_normalizer(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_114,
      previous_i => (others => '0'),
      alpha_i => (others => '0'),
      probabilities_i => C_EXP_BEAT_IDLE,
      m_valid_o => check_115,
      m_ready_i => '0',
      normalizer_o => open,
      overflow_o => open
    );
  u_eat_av_tile_engine : entity work.eat_av_tile_engine(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_116,
      cmd_i => C_ATTENTION_CMD_IDLE,
      done_valid_o => check_117,
      done_ready_i => '0',
      status_o => open,
      p_valid_i => '1',
      p_ready_o => check_118,
      p_data_i => C_EXP_BEAT_IDLE,
      v_valid_i => '1',
      v_ready_o => check_119,
      v_data_i => C_ACT_BEAT_IDLE,
      previous_state_i => (others => (others => '0')),
      alpha_i => (others => '0'),
      m_valid_o => check_120,
      m_ready_i => '0',
      weighted_state_o => open,
      overflow_o => open
    );
  u_eat_attention_finalize : entity work.eat_attention_finalize(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_121,
      weighted_state_i => (others => (others => '0')),
      normalizer_i => (others => '0'),
      keep_i => (others => '0'),
      token_i => 0,
      feature_base_i => 0,
      ctx_i => C_CONTEXT_IDLE,
      m_valid_o => check_122,
      m_ready_i => '0',
      m_data_o => open,
      overflow_o => open
    );
  u_eat_streaming_attention_engine : entity work.eat_streaming_attention_engine(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_123,
      cmd_i => C_ATTENTION_CMD_IDLE,
      done_valid_o => check_124,
      done_ready_i => '0',
      status_o => open,
      m_valid_o => check_125,
      m_ready_i => '0',
      m_data_o => open,
      mem_req_valid_o => check_126,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_127,
      mem_rsp_i => C_MEM_RSP_IDLE,
      param_req_valid_o => check_128,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_129,
      param_rsp_i => C_PARAM_RSP_IDLE
    );
  u_eat_group_scorer : entity work.eat_group_scorer(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_130,
      cmd_i => C_GATE_CMD_IDLE,
      done_valid_o => check_131,
      done_ready_i => '0',
      status_o => open,
      token_scores_valid_i => '1',
      token_scores_ready_o => check_132,
      token_scores_i => C_STATE_BEAT_IDLE,
      scores_valid_o => check_133,
      scores_ready_i => '0',
      score_o => open,
      group_index_o => open,
      last_group_o => open,
      mem_req_valid_o => check_134,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_135,
      mem_rsp_i => C_MEM_RSP_IDLE,
      param_req_valid_o => check_136,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_137,
      param_rsp_i => C_PARAM_RSP_IDLE
    );
  u_eat_group_selector : entity work.eat_group_selector(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_138,
      cmd_i => C_GATE_CMD_IDLE,
      done_valid_o => check_139,
      done_ready_i => '0',
      status_o => open,
      scores_valid_i => '1',
      scores_ready_o => check_140,
      score_i => (others => '0'),
      group_index_i => 0,
      last_group_i => '0',
      decision_valid_o => check_141,
      decision_ready_i => '0',
      decision_o => open
    );
  u_eat_rts_summary : entity work.eat_rts_summary(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_142,
      cmd_i => C_GATE_CMD_IDLE,
      done_valid_o => check_143,
      done_ready_i => '0',
      status_o => open,
      s_valid_i => '1',
      s_ready_o => check_144,
      s_data_i => C_STATE_BEAT_IDLE,
      score_valid_i => '1',
      score_ready_o => check_145,
      token_score_i => (others => '0'),
      m_valid_o => check_146,
      m_ready_i => '0',
      m_data_o => open,
      overflow_o => open
    );
  u_eat_token_compactor : entity work.eat_token_compactor(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_147,
      cmd_i => C_GATE_CMD_IDLE,
      done_valid_o => check_148,
      done_ready_i => '0',
      status_o => open,
      decision_valid_i => '1',
      decision_ready_o => check_149,
      decision_i => C_GROUP_DECISION_IDLE,
      s_valid_i => '1',
      s_ready_o => check_150,
      s_data_i => C_STATE_BEAT_IDLE,
      m_valid_o => check_151,
      m_ready_i => '0',
      m_data_o => open,
      mem_req_valid_o => check_152,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_153,
      mem_rsp_i => C_MEM_RSP_IDLE
    );
  u_eat_mode_controller : entity work.eat_mode_controller(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      request_valid_i => '1',
      request_ready_o => check_154,
      request_i => C_CONTROL_REQUEST_IDLE,
      core_idle_i => '0',
      loaded_identity_i => (others => '0'),
      bank_valid_i => '1',
      active_context_o => open,
      active_valid_o => check_155,
      active_ready_i => '0',
      status_o => open
    );
  u_eat_encoder_sequencer : entity work.eat_encoder_sequencer(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      start_valid_i => '1',
      start_ready_o => check_156,
      ctx_i => C_CONTEXT_IDLE,
      matrix_valid_o => check_157,
      matrix_ready_i => '0',
      matrix_o => open,
      vector_valid_o => check_158,
      vector_ready_i => '0',
      vector_o => open,
      attention_valid_o => check_159,
      attention_ready_i => '0',
      attention_o => open,
      gate_valid_o => check_160,
      gate_ready_i => '0',
      gate_o => open,
      unit_status_i => C_STATUS_IDLE,
      unit_done_valid_i => '1',
      unit_done_ready_o => check_161,
      output_accepted_i => '0',
      status_o => open
    );
  u_eat_performance_counters : entity work.eat_performance_counters(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      start_i => '0',
      complete_i => '0',
      clear_i => '0',
      event_valid_i => '1',
      event_i => EV_CYCLE,
      event_count_i => (others => '0'),
      snapshot_valid_o => check_162,
      snapshot_ready_i => '0',
      snapshot_o => open
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
      request_valid_o => check_163,
      request_ready_i => '0',
      request_o => open,
      transfer_valid_o => check_164,
      transfer_ready_i => '0',
      transfer_o => open,
      status_i => C_STATUS_IDLE,
      loaded_identity_i => (others => '0'),
      counters_i => C_COUNTERS_IDLE,
      interrupt_o => check_165
    );
  u_eat_dma_descriptor_engine : entity work.eat_dma_descriptor_engine(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      cmd_valid_i => '1',
      cmd_ready_o => check_166,
      cmd_i => C_TRANSFER_CMD_IDLE,
      done_valid_o => check_167,
      done_ready_i => '0',
      status_o => open,
      stream_bytes_accepted_i => (others => '0'),
      stream_last_i => '0',
      frame_error_i => '0',
      active_transfer_o => open,
      active_valid_o => check_168
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
      input_valid_o => check_169,
      input_ready_i => '0',
      input_data_o => open,
      constant_valid_o => check_170,
      constant_ready_i => '0',
      constant_data_o => open,
      constant_keep_o => open,
      constant_last_o => open,
      frame_error_o => open
    );
  u_eat_axi_stream_output : entity work.eat_axi_stream_output(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      s_valid_i => '1',
      s_ready_o => check_171,
      s_data_i => C_STATE_BEAT_IDLE,
      classes_i => 0,
      output_accepted_o => open,
      m_axis_tdata_o => open,
      m_axis_tkeep_o => open,
      m_axis_tlast_o => open,
      m_axis_tvalid_o => open,
      m_axis_tready_i => '0'
    );
  u_eat_encoder_core : entity work.eat_encoder_core(stub)
    generic map (G_ALLOW_STUB_SIM => true)
    port map (
      clk_i => clk,
      rst_i => rst,
      start_valid_i => '1',
      start_ready_o => check_172,
      request_i => C_CONTROL_REQUEST_IDLE,
      logits_valid_o => check_173,
      logits_ready_i => '0',
      logits_o => open,
      status_o => open,
      event_valid_o => check_174,
      event_o => open,
      event_count_o => open,
      mem_req_valid_o => check_175,
      mem_req_ready_i => '0',
      mem_req_o => open,
      mem_rsp_valid_i => '1',
      mem_rsp_ready_o => check_176,
      mem_rsp_i => C_MEM_RSP_IDLE,
      param_req_valid_o => check_177,
      param_req_ready_i => '0',
      param_req_o => open,
      param_rsp_valid_i => '1',
      param_rsp_ready_o => check_178,
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
      interrupt_o => check_179
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
      interrupt_o => check_180
    );
  process
  begin
    wait for 60 ns;
    assert check_0 = '0' report "Stub accepted/emitted a transaction: eat_rv_fifo.s_ready_o" severity failure;
    assert check_1 = '0' report "Stub accepted/emitted a transaction: eat_rv_fifo.m_valid_o" severity failure;
    assert check_2 = '0' report "Stub accepted/emitted a transaction: eat_stream_register.s_ready_o" severity failure;
    assert check_3 = '0' report "Stub accepted/emitted a transaction: eat_stream_register.m_valid_o" severity failure;
    assert check_4 = '0' report "Stub accepted/emitted a transaction: eat_round_shift.s_ready_o" severity failure;
    assert check_5 = '0' report "Stub accepted/emitted a transaction: eat_round_shift.m_valid_o" severity failure;
    assert check_6 = '0' report "Stub accepted/emitted a transaction: eat_round_divide.s_ready_o" severity failure;
    assert check_7 = '0' report "Stub accepted/emitted a transaction: eat_round_divide.m_valid_o" severity failure;
    assert check_8 = '0' report "Stub accepted/emitted a transaction: eat_reduction_tree.s_ready_o" severity failure;
    assert check_9 = '0' report "Stub accepted/emitted a transaction: eat_reduction_tree.m_valid_o" severity failure;
    assert check_10 = '0' report "Stub accepted/emitted a transaction: eat_leading_one.s_ready_o" severity failure;
    assert check_11 = '0' report "Stub accepted/emitted a transaction: eat_leading_one.m_valid_o" severity failure;
    assert check_12 = '0' report "Stub accepted/emitted a transaction: eat_exp_lut.s_ready_o" severity failure;
    assert check_13 = '0' report "Stub accepted/emitted a transaction: eat_exp_lut.m_valid_o" severity failure;
    assert check_14 = '0' report "Stub accepted/emitted a transaction: eat_exp_lut.param_req_valid_o" severity failure;
    assert check_15 = '0' report "Stub accepted/emitted a transaction: eat_exp_lut.param_rsp_ready_o" severity failure;
    assert check_16 = '0' report "Stub accepted/emitted a transaction: eat_rsqrt_lut.s_ready_o" severity failure;
    assert check_17 = '0' report "Stub accepted/emitted a transaction: eat_rsqrt_lut.m_valid_o" severity failure;
    assert check_18 = '0' report "Stub accepted/emitted a transaction: eat_rsqrt_lut.param_req_valid_o" severity failure;
    assert check_19 = '0' report "Stub accepted/emitted a transaction: eat_rsqrt_lut.param_rsp_ready_o" severity failure;
    assert check_20 = '0' report "Stub accepted/emitted a transaction: eat_pwl_silu.cmd_ready_o" severity failure;
    assert check_21 = '0' report "Stub accepted/emitted a transaction: eat_pwl_silu.done_valid_o" severity failure;
    assert check_22 = '0' report "Stub accepted/emitted a transaction: eat_pwl_silu.s_ready_o" severity failure;
    assert check_23 = '0' report "Stub accepted/emitted a transaction: eat_pwl_silu.m_valid_o" severity failure;
    assert check_24 = '0' report "Stub accepted/emitted a transaction: eat_pwl_silu.param_req_valid_o" severity failure;
    assert check_25 = '0' report "Stub accepted/emitted a transaction: eat_pwl_silu.param_rsp_ready_o" severity failure;
    assert check_26 = '0' report "Stub accepted/emitted a transaction: eat_memory_arbiter.mem_req_valid_o" severity failure;
    assert check_27 = '0' report "Stub accepted/emitted a transaction: eat_memory_arbiter.mem_rsp_ready_o" severity failure;
    assert check_28 = '0' report "Stub accepted/emitted a transaction: eat_input_buffer.req_ready_o" severity failure;
    assert check_29 = '0' report "Stub accepted/emitted a transaction: eat_input_buffer.rsp_valid_o" severity failure;
    assert check_30 = '0' report "Stub accepted/emitted a transaction: eat_weight_buffer_banked.req_ready_o" severity failure;
    assert check_31 = '0' report "Stub accepted/emitted a transaction: eat_weight_buffer_banked.rsp_valid_o" severity failure;
    assert check_32 = '0' report "Stub accepted/emitted a transaction: eat_activation_buffer_pingpong.req_ready_o" severity failure;
    assert check_33 = '0' report "Stub accepted/emitted a transaction: eat_activation_buffer_pingpong.rsp_valid_o" severity failure;
    assert check_34 = '0' report "Stub accepted/emitted a transaction: eat_attention_state_buffer.req_ready_o" severity failure;
    assert check_35 = '0' report "Stub accepted/emitted a transaction: eat_attention_state_buffer.rsp_valid_o" severity failure;
    assert check_36 = '0' report "Stub accepted/emitted a transaction: eat_token_index_buffer.req_ready_o" severity failure;
    assert check_37 = '0' report "Stub accepted/emitted a transaction: eat_token_index_buffer.rsp_valid_o" severity failure;
    assert check_38 = '0' report "Stub accepted/emitted a transaction: eat_parameter_store.req_ready_o" severity failure;
    assert check_39 = '0' report "Stub accepted/emitted a transaction: eat_parameter_store.rsp_valid_o" severity failure;
    assert check_40 = '0' report "Stub accepted/emitted a transaction: eat_parameter_store.mem_req_valid_o" severity failure;
    assert check_41 = '0' report "Stub accepted/emitted a transaction: eat_parameter_store.mem_rsp_ready_o" severity failure;
    assert check_42 = '0' report "Stub accepted/emitted a transaction: eat_constant_loader.cmd_ready_o" severity failure;
    assert check_43 = '0' report "Stub accepted/emitted a transaction: eat_constant_loader.done_valid_o" severity failure;
    assert check_44 = '0' report "Stub accepted/emitted a transaction: eat_constant_loader.s_ready_o" severity failure;
    assert check_45 = '0' report "Stub accepted/emitted a transaction: eat_constant_loader.mem_req_valid_o" severity failure;
    assert check_46 = '0' report "Stub accepted/emitted a transaction: eat_constant_loader.mem_rsp_ready_o" severity failure;
    assert check_47 = '0' report "Stub accepted/emitted a transaction: eat_address_generator.cmd_ready_o" severity failure;
    assert check_48 = '0' report "Stub accepted/emitted a transaction: eat_address_generator.done_valid_o" severity failure;
    assert check_49 = '0' report "Stub accepted/emitted a transaction: eat_address_generator.step_valid_o" severity failure;
    assert check_50 = '0' report "Stub accepted/emitted a transaction: eat_patch_reader.cmd_ready_o" severity failure;
    assert check_51 = '0' report "Stub accepted/emitted a transaction: eat_patch_reader.done_valid_o" severity failure;
    assert check_52 = '0' report "Stub accepted/emitted a transaction: eat_patch_reader.m_valid_o" severity failure;
    assert check_53 = '0' report "Stub accepted/emitted a transaction: eat_patch_reader.mem_req_valid_o" severity failure;
    assert check_54 = '0' report "Stub accepted/emitted a transaction: eat_patch_reader.mem_rsp_ready_o" severity failure;
    assert check_55 = '0' report "Stub accepted/emitted a transaction: eat_activation_quantizer.s_ready_o" severity failure;
    assert check_56 = '0' report "Stub accepted/emitted a transaction: eat_activation_quantizer.m_valid_o" severity failure;
    assert check_57 = '0' report "Stub accepted/emitted a transaction: eat_weight_unpack.s_ready_o" severity failure;
    assert check_58 = '0' report "Stub accepted/emitted a transaction: eat_weight_unpack.m_valid_o" severity failure;
    assert check_59 = '0' report "Stub accepted/emitted a transaction: eat_mac_lane.s_ready_o" severity failure;
    assert check_60 = '0' report "Stub accepted/emitted a transaction: eat_mac_lane.m_valid_o" severity failure;
    assert check_61 = '0' report "Stub accepted/emitted a transaction: eat_mac_array.s_ready_o" severity failure;
    assert check_62 = '0' report "Stub accepted/emitted a transaction: eat_mac_array.m_valid_o" severity failure;
    assert check_63 = '0' report "Stub accepted/emitted a transaction: eat_requantizer.s_ready_o" severity failure;
    assert check_64 = '0' report "Stub accepted/emitted a transaction: eat_requantizer.m_valid_o" severity failure;
    assert check_65 = '0' report "Stub accepted/emitted a transaction: eat_tensor_engine.cmd_ready_o" severity failure;
    assert check_66 = '0' report "Stub accepted/emitted a transaction: eat_tensor_engine.done_valid_o" severity failure;
    assert check_67 = '0' report "Stub accepted/emitted a transaction: eat_tensor_engine.m_valid_o" severity failure;
    assert check_68 = '0' report "Stub accepted/emitted a transaction: eat_tensor_engine.mem_req_valid_o" severity failure;
    assert check_69 = '0' report "Stub accepted/emitted a transaction: eat_tensor_engine.mem_rsp_ready_o" severity failure;
    assert check_70 = '0' report "Stub accepted/emitted a transaction: eat_tensor_engine.param_req_valid_o" severity failure;
    assert check_71 = '0' report "Stub accepted/emitted a transaction: eat_tensor_engine.param_rsp_ready_o" severity failure;
    assert check_72 = '0' report "Stub accepted/emitted a transaction: eat_position_add.cmd_ready_o" severity failure;
    assert check_73 = '0' report "Stub accepted/emitted a transaction: eat_position_add.done_valid_o" severity failure;
    assert check_74 = '0' report "Stub accepted/emitted a transaction: eat_position_add.s_ready_o" severity failure;
    assert check_75 = '0' report "Stub accepted/emitted a transaction: eat_position_add.m_valid_o" severity failure;
    assert check_76 = '0' report "Stub accepted/emitted a transaction: eat_position_add.param_req_valid_o" severity failure;
    assert check_77 = '0' report "Stub accepted/emitted a transaction: eat_position_add.param_rsp_ready_o" severity failure;
    assert check_78 = '0' report "Stub accepted/emitted a transaction: eat_residual_add.cmd_ready_o" severity failure;
    assert check_79 = '0' report "Stub accepted/emitted a transaction: eat_residual_add.done_valid_o" severity failure;
    assert check_80 = '0' report "Stub accepted/emitted a transaction: eat_residual_add.a_ready_o" severity failure;
    assert check_81 = '0' report "Stub accepted/emitted a transaction: eat_residual_add.b_ready_o" severity failure;
    assert check_82 = '0' report "Stub accepted/emitted a transaction: eat_residual_add.m_valid_o" severity failure;
    assert check_83 = '0' report "Stub accepted/emitted a transaction: eat_mean_pool.cmd_ready_o" severity failure;
    assert check_84 = '0' report "Stub accepted/emitted a transaction: eat_mean_pool.done_valid_o" severity failure;
    assert check_85 = '0' report "Stub accepted/emitted a transaction: eat_mean_pool.s_ready_o" severity failure;
    assert check_86 = '0' report "Stub accepted/emitted a transaction: eat_mean_pool.m_valid_o" severity failure;
    assert check_87 = '0' report "Stub accepted/emitted a transaction: eat_rmsnorm.cmd_ready_o" severity failure;
    assert check_88 = '0' report "Stub accepted/emitted a transaction: eat_rmsnorm.done_valid_o" severity failure;
    assert check_89 = '0' report "Stub accepted/emitted a transaction: eat_rmsnorm.s_ready_o" severity failure;
    assert check_90 = '0' report "Stub accepted/emitted a transaction: eat_rmsnorm.m_valid_o" severity failure;
    assert check_91 = '0' report "Stub accepted/emitted a transaction: eat_rmsnorm.param_req_valid_o" severity failure;
    assert check_92 = '0' report "Stub accepted/emitted a transaction: eat_rmsnorm.param_rsp_ready_o" severity failure;
    assert check_93 = '0' report "Stub accepted/emitted a transaction: eat_rmsnorm.mem_req_valid_o" severity failure;
    assert check_94 = '0' report "Stub accepted/emitted a transaction: eat_rmsnorm.mem_rsp_ready_o" severity failure;
    assert check_95 = '0' report "Stub accepted/emitted a transaction: eat_qkv_quantizer.cmd_ready_o" severity failure;
    assert check_96 = '0' report "Stub accepted/emitted a transaction: eat_qkv_quantizer.done_valid_o" severity failure;
    assert check_97 = '0' report "Stub accepted/emitted a transaction: eat_qkv_quantizer.s_ready_o" severity failure;
    assert check_98 = '0' report "Stub accepted/emitted a transaction: eat_qkv_quantizer.q_valid_o" severity failure;
    assert check_99 = '0' report "Stub accepted/emitted a transaction: eat_qkv_quantizer.k_valid_o" severity failure;
    assert check_100 = '0' report "Stub accepted/emitted a transaction: eat_qkv_quantizer.v_valid_o" severity failure;
    assert check_101 = '0' report "Stub accepted/emitted a transaction: eat_qk_tile_engine.cmd_ready_o" severity failure;
    assert check_102 = '0' report "Stub accepted/emitted a transaction: eat_qk_tile_engine.done_valid_o" severity failure;
    assert check_103 = '0' report "Stub accepted/emitted a transaction: eat_qk_tile_engine.q_ready_o" severity failure;
    assert check_104 = '0' report "Stub accepted/emitted a transaction: eat_qk_tile_engine.k_ready_o" severity failure;
    assert check_105 = '0' report "Stub accepted/emitted a transaction: eat_qk_tile_engine.m_valid_o" severity failure;
    assert check_106 = '0' report "Stub accepted/emitted a transaction: eat_score_scale.s_ready_o" severity failure;
    assert check_107 = '0' report "Stub accepted/emitted a transaction: eat_score_scale.m_valid_o" severity failure;
    assert check_108 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.cmd_ready_o" severity failure;
    assert check_109 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.done_valid_o" severity failure;
    assert check_110 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.s_ready_o" severity failure;
    assert check_111 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.m_valid_o" severity failure;
    assert check_112 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.param_req_valid_o" severity failure;
    assert check_113 = '0' report "Stub accepted/emitted a transaction: eat_rowmax_exp.param_rsp_ready_o" severity failure;
    assert check_114 = '0' report "Stub accepted/emitted a transaction: eat_running_normalizer.s_ready_o" severity failure;
    assert check_115 = '0' report "Stub accepted/emitted a transaction: eat_running_normalizer.m_valid_o" severity failure;
    assert check_116 = '0' report "Stub accepted/emitted a transaction: eat_av_tile_engine.cmd_ready_o" severity failure;
    assert check_117 = '0' report "Stub accepted/emitted a transaction: eat_av_tile_engine.done_valid_o" severity failure;
    assert check_118 = '0' report "Stub accepted/emitted a transaction: eat_av_tile_engine.p_ready_o" severity failure;
    assert check_119 = '0' report "Stub accepted/emitted a transaction: eat_av_tile_engine.v_ready_o" severity failure;
    assert check_120 = '0' report "Stub accepted/emitted a transaction: eat_av_tile_engine.m_valid_o" severity failure;
    assert check_121 = '0' report "Stub accepted/emitted a transaction: eat_attention_finalize.s_ready_o" severity failure;
    assert check_122 = '0' report "Stub accepted/emitted a transaction: eat_attention_finalize.m_valid_o" severity failure;
    assert check_123 = '0' report "Stub accepted/emitted a transaction: eat_streaming_attention_engine.cmd_ready_o" severity failure;
    assert check_124 = '0' report "Stub accepted/emitted a transaction: eat_streaming_attention_engine.done_valid_o" severity failure;
    assert check_125 = '0' report "Stub accepted/emitted a transaction: eat_streaming_attention_engine.m_valid_o" severity failure;
    assert check_126 = '0' report "Stub accepted/emitted a transaction: eat_streaming_attention_engine.mem_req_valid_o" severity failure;
    assert check_127 = '0' report "Stub accepted/emitted a transaction: eat_streaming_attention_engine.mem_rsp_ready_o" severity failure;
    assert check_128 = '0' report "Stub accepted/emitted a transaction: eat_streaming_attention_engine.param_req_valid_o" severity failure;
    assert check_129 = '0' report "Stub accepted/emitted a transaction: eat_streaming_attention_engine.param_rsp_ready_o" severity failure;
    assert check_130 = '0' report "Stub accepted/emitted a transaction: eat_group_scorer.cmd_ready_o" severity failure;
    assert check_131 = '0' report "Stub accepted/emitted a transaction: eat_group_scorer.done_valid_o" severity failure;
    assert check_132 = '0' report "Stub accepted/emitted a transaction: eat_group_scorer.token_scores_ready_o" severity failure;
    assert check_133 = '0' report "Stub accepted/emitted a transaction: eat_group_scorer.scores_valid_o" severity failure;
    assert check_134 = '0' report "Stub accepted/emitted a transaction: eat_group_scorer.mem_req_valid_o" severity failure;
    assert check_135 = '0' report "Stub accepted/emitted a transaction: eat_group_scorer.mem_rsp_ready_o" severity failure;
    assert check_136 = '0' report "Stub accepted/emitted a transaction: eat_group_scorer.param_req_valid_o" severity failure;
    assert check_137 = '0' report "Stub accepted/emitted a transaction: eat_group_scorer.param_rsp_ready_o" severity failure;
    assert check_138 = '0' report "Stub accepted/emitted a transaction: eat_group_selector.cmd_ready_o" severity failure;
    assert check_139 = '0' report "Stub accepted/emitted a transaction: eat_group_selector.done_valid_o" severity failure;
    assert check_140 = '0' report "Stub accepted/emitted a transaction: eat_group_selector.scores_ready_o" severity failure;
    assert check_141 = '0' report "Stub accepted/emitted a transaction: eat_group_selector.decision_valid_o" severity failure;
    assert check_142 = '0' report "Stub accepted/emitted a transaction: eat_rts_summary.cmd_ready_o" severity failure;
    assert check_143 = '0' report "Stub accepted/emitted a transaction: eat_rts_summary.done_valid_o" severity failure;
    assert check_144 = '0' report "Stub accepted/emitted a transaction: eat_rts_summary.s_ready_o" severity failure;
    assert check_145 = '0' report "Stub accepted/emitted a transaction: eat_rts_summary.score_ready_o" severity failure;
    assert check_146 = '0' report "Stub accepted/emitted a transaction: eat_rts_summary.m_valid_o" severity failure;
    assert check_147 = '0' report "Stub accepted/emitted a transaction: eat_token_compactor.cmd_ready_o" severity failure;
    assert check_148 = '0' report "Stub accepted/emitted a transaction: eat_token_compactor.done_valid_o" severity failure;
    assert check_149 = '0' report "Stub accepted/emitted a transaction: eat_token_compactor.decision_ready_o" severity failure;
    assert check_150 = '0' report "Stub accepted/emitted a transaction: eat_token_compactor.s_ready_o" severity failure;
    assert check_151 = '0' report "Stub accepted/emitted a transaction: eat_token_compactor.m_valid_o" severity failure;
    assert check_152 = '0' report "Stub accepted/emitted a transaction: eat_token_compactor.mem_req_valid_o" severity failure;
    assert check_153 = '0' report "Stub accepted/emitted a transaction: eat_token_compactor.mem_rsp_ready_o" severity failure;
    assert check_154 = '0' report "Stub accepted/emitted a transaction: eat_mode_controller.request_ready_o" severity failure;
    assert check_155 = '0' report "Stub accepted/emitted a transaction: eat_mode_controller.active_valid_o" severity failure;
    assert check_156 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.start_ready_o" severity failure;
    assert check_157 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.matrix_valid_o" severity failure;
    assert check_158 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.vector_valid_o" severity failure;
    assert check_159 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.attention_valid_o" severity failure;
    assert check_160 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.gate_valid_o" severity failure;
    assert check_161 = '0' report "Stub accepted/emitted a transaction: eat_encoder_sequencer.unit_done_ready_o" severity failure;
    assert check_162 = '0' report "Stub accepted/emitted a transaction: eat_performance_counters.snapshot_valid_o" severity failure;
    assert check_163 = '0' report "Stub accepted/emitted a transaction: eat_axi_ctrl_regs.request_valid_o" severity failure;
    assert check_164 = '0' report "Stub accepted/emitted a transaction: eat_axi_ctrl_regs.transfer_valid_o" severity failure;
    assert check_165 = '0' report "Stub accepted/emitted a transaction: eat_axi_ctrl_regs.interrupt_o" severity failure;
    assert check_166 = '0' report "Stub accepted/emitted a transaction: eat_dma_descriptor_engine.cmd_ready_o" severity failure;
    assert check_167 = '0' report "Stub accepted/emitted a transaction: eat_dma_descriptor_engine.done_valid_o" severity failure;
    assert check_168 = '0' report "Stub accepted/emitted a transaction: eat_dma_descriptor_engine.active_valid_o" severity failure;
    assert check_169 = '0' report "Stub accepted/emitted a transaction: eat_axi_stream_input.input_valid_o" severity failure;
    assert check_170 = '0' report "Stub accepted/emitted a transaction: eat_axi_stream_input.constant_valid_o" severity failure;
    assert check_171 = '0' report "Stub accepted/emitted a transaction: eat_axi_stream_output.s_ready_o" severity failure;
    assert check_172 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.start_ready_o" severity failure;
    assert check_173 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.logits_valid_o" severity failure;
    assert check_174 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.event_valid_o" severity failure;
    assert check_175 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.mem_req_valid_o" severity failure;
    assert check_176 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.mem_rsp_ready_o" severity failure;
    assert check_177 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.param_req_valid_o" severity failure;
    assert check_178 = '0' report "Stub accepted/emitted a transaction: eat_encoder_core.param_rsp_ready_o" severity failure;
    assert check_179 = '0' report "Stub accepted/emitted a transaction: eat_fpga_top.interrupt_o" severity failure;
    assert check_180 = '0' report "Stub accepted/emitted a transaction: eat_platform_wrapper.interrupt_o" severity failure;
    report "STRUCTURAL_SMOKE_PASS: inert stubs only; no numerical verification" severity note;
    stop;
    wait;
  end process;
end architecture;
