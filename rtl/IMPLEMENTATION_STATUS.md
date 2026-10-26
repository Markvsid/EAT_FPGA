# RTL implementation status

38 of 53 entities have functional implementations and named regression suites. 15 remain explicit skeletons.

A module implementation is not evidence of complete accelerator integration, physical resource fit or timing. The full encoder/top remain unavailable until their remaining dependencies are implemented and tested. User agreement covers integration contract v2; broader hardware G1/G2 remain open.

| Entity | Status | Functional regression |
| --- | --- | --- |
| [eat_reset_sync](common/eat_reset_sync.vhd) | implemented | test_primitives.py |
| [eat_rv_fifo](common/eat_rv_fifo.vhd) | implemented | test_primitives.py |
| [eat_stream_register](common/eat_stream_register.vhd) | implemented | test_primitives.py |
| [eat_round_shift](arithmetic/eat_round_shift.vhd) | implemented | test_primitives.py |
| [eat_round_divide](arithmetic/eat_round_divide.vhd) | implemented | test_primitives.py |
| [eat_reduction_tree](arithmetic/eat_reduction_tree.vhd) | implemented | test_primitives.py |
| [eat_leading_one](arithmetic/eat_leading_one.vhd) | implemented | test_primitives.py |
| [eat_exp_lut](arithmetic/eat_exp_lut.vhd) | implemented | test_services.py |
| [eat_rsqrt_lut](arithmetic/eat_rsqrt_lut.vhd) | implemented | test_services.py |
| [eat_vector_engine](vector/eat_vector_engine.vhd) | implemented | test_vectors.py |
| [eat_pwl_silu](arithmetic/eat_pwl_silu.vhd) | implemented | test_vectors.py |
| [eat_memory_arbiter](memory/eat_memory_arbiter.vhd) | implemented | test_arbiter.py |
| [eat_input_buffer](memory/eat_input_buffer.vhd) | implemented | test_services.py |
| [eat_weight_buffer_banked](memory/eat_weight_buffer_banked.vhd) | implemented | test_services.py |
| [eat_activation_buffer_pingpong](memory/eat_activation_buffer_pingpong.vhd) | implemented | test_services.py |
| [eat_attention_state_buffer](memory/eat_attention_state_buffer.vhd) | implemented | test_services.py |
| [eat_token_index_buffer](memory/eat_token_index_buffer.vhd) | implemented | test_services.py |
| [eat_parameter_store](memory/eat_parameter_store.vhd) | stub |  |
| [eat_constant_loader](memory/eat_constant_loader.vhd) | stub |  |
| [eat_address_generator](tensor/eat_address_generator.vhd) | stub |  |
| [eat_patch_reader](tensor/eat_patch_reader.vhd) | stub |  |
| [eat_activation_quantizer](tensor/eat_activation_quantizer.vhd) | implemented | test_primitives.py |
| [eat_weight_unpack](tensor/eat_weight_unpack.vhd) | implemented | test_primitives.py |
| [eat_mac_lane](tensor/eat_mac_lane.vhd) | implemented | test_primitives.py |
| [eat_mac_array](tensor/eat_mac_array.vhd) | implemented | test_primitives.py |
| [eat_requantizer](tensor/eat_requantizer.vhd) | implemented | test_primitives.py |
| [eat_tensor_engine](tensor/eat_tensor_engine.vhd) | implemented | test_tensor.py |
| [eat_position_add](vector/eat_position_add.vhd) | implemented | test_vectors.py |
| [eat_residual_add](vector/eat_residual_add.vhd) | implemented | test_vectors.py |
| [eat_mean_pool](vector/eat_mean_pool.vhd) | implemented | test_vectors.py |
| [eat_rmsnorm](vector/eat_rmsnorm.vhd) | implemented | test_vectors.py |
| [eat_qkv_quantizer](attention/eat_qkv_quantizer.vhd) | implemented | test_qkv.py |
| [eat_qk_tile_engine](attention/eat_qk_tile_engine.vhd) | stub |  |
| [eat_score_scale](attention/eat_score_scale.vhd) | implemented | test_primitives.py |
| [eat_rowmax_exp](attention/eat_rowmax_exp.vhd) | stub |  |
| [eat_running_normalizer](attention/eat_running_normalizer.vhd) | implemented | test_services.py |
| [eat_av_tile_engine](attention/eat_av_tile_engine.vhd) | stub |  |
| [eat_attention_finalize](attention/eat_attention_finalize.vhd) | implemented | test_services.py |
| [eat_streaming_attention_engine](attention/eat_streaming_attention_engine.vhd) | implemented | test_attention.py |
| [eat_group_scorer](tokens/eat_group_scorer.vhd) | implemented | test_gate.py |
| [eat_group_selector](tokens/eat_group_selector.vhd) | implemented | test_services.py, test_gate.py |
| [eat_rts_summary](tokens/eat_rts_summary.vhd) | stub |  |
| [eat_token_compactor](tokens/eat_token_compactor.vhd) | implemented | test_gate.py |
| [eat_mode_controller](control/eat_mode_controller.vhd) | implemented | test_services.py |
| [eat_encoder_sequencer](control/eat_encoder_sequencer.vhd) | stub |  |
| [eat_performance_counters](control/eat_performance_counters.vhd) | implemented | test_services.py |
| [eat_axi_ctrl_regs](host/eat_axi_ctrl_regs.vhd) | stub |  |
| [eat_dma_descriptor_engine](host/eat_dma_descriptor_engine.vhd) | stub |  |
| [eat_axi_stream_input](host/eat_axi_stream_input.vhd) | stub |  |
| [eat_axi_stream_output](host/eat_axi_stream_output.vhd) | implemented | test_services.py |
| [eat_encoder_core](top/eat_encoder_core.vhd) | stub |  |
| [eat_fpga_top](top/eat_fpga_top.vhd) | stub |  |
| [eat_platform_wrapper](platform/eat_platform_wrapper.vhd) | stub |  |

Reproduce functional checks with `make -C rtl functional`. Local evidence is archived in `rtl/validation/phase1/`. No full-model RTL, Vivado implementation or FPGA inference result is claimed.
