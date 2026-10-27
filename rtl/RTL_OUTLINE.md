# VHDL implementation outline

Authority: the controlling Word plan, especially Sections 7.1–7.5, 8, 14.2 and
14.7–14.8. Integration ABI2 was approved by the user on 2026-10-26. Approval does
not establish remaining G1/G2 research, board or physical implementation evidence.

The design has 48 functional entities and five packages. Six original skeleton
boundaries were consolidated into their consumers; see [the mapping](docs/CONSOLIDATED_MODULES.md).
All logical operations remain implemented. [Verification](docs/VERIFICATION.md)
distinguishes unit, complete model, platform and physical hardware evidence.

## Connected hierarchy

`eat_platform_wrapper` synchronizes reset release and exposes one common clock.
`eat_fpga_top` connects AXI-Lite registers, transfer framing/descriptor checks,
constant loading/arming, compact model RAM, input RAM, parameter arbitration,
the encoder and logit serialization. Completion waits for the last AXIS output
acceptance. The generated PS/DMA/board block design is external to this peripheral.

`eat_encoder_core` sequences embedding, position addition, two RMSNorms per
block, QKV, streamed attention, projection/residual, FFN/PWL/residual, the block-1
token gate, global normalization/pooling and the appropriate classifier. A single
8×8 tensor engine serves every linear operator. Quality executes four blocks
with 32 tokens; Balanced has 26 tokens after the first block and four blocks;
Energy-Saver has 20 tokens after the first block and exits after block two.

Attention keeps one query state and eight-key tiles, without a full score matrix.
The compactor buffers the original rows before overwriting them with chronological
retained groups and one summary per dropped group. Registered readers feed row
operations and QKV quantization. State is signed Q12/24-bit; all other formats
and nearest-even rounding follow the immutable software numeric-v2 contract.

## Packages

| Package | File |
| --- | --- |
| eat_config_pkg | [eat_config_pkg.vhd](pkg/eat_config_pkg.vhd) |
| eat_types_pkg | [eat_types_pkg.vhd](pkg/eat_types_pkg.vhd) |
| eat_registers_pkg | [eat_registers_pkg.vhd](pkg/eat_registers_pkg.vhd) |
| eat_math_pkg | [eat_math_pkg.vhd](pkg/eat_math_pkg.vhd) |
| eat_image_pkg | [eat_image_pkg.vhd](pkg/eat_image_pkg.vhd) |

## Entity inventory

Roles and exact port/dependency contracts are machine-readable in
[design_inventory.json](design_inventory.json). All listed entities have one
functional architecture and named regression suites.

| Group | Entity | Direct children |
| --- | --- | --- |
| common | [eat_reset_sync](common/eat_reset_sync.vhd) | — |
| common | [eat_rv_fifo](common/eat_rv_fifo.vhd) | — |
| common | [eat_stream_register](common/eat_stream_register.vhd) | — |
| arithmetic | [eat_round_shift](arithmetic/eat_round_shift.vhd) | — |
| arithmetic | [eat_round_divide](arithmetic/eat_round_divide.vhd) | — |
| arithmetic | [eat_reduction_tree](arithmetic/eat_reduction_tree.vhd) | — |
| arithmetic | [eat_leading_one](arithmetic/eat_leading_one.vhd) | — |
| arithmetic | [eat_exp_lut](arithmetic/eat_exp_lut.vhd) | — |
| arithmetic | [eat_rsqrt_lut](arithmetic/eat_rsqrt_lut.vhd) | — |
| vector | [eat_vector_engine](vector/eat_vector_engine.vhd) | eat_round_divide |
| arithmetic | [eat_pwl_silu](arithmetic/eat_pwl_silu.vhd) | eat_vector_engine |
| memory | [eat_memory_arbiter](memory/eat_memory_arbiter.vhd) | — |
| memory | [eat_input_buffer](memory/eat_input_buffer.vhd) | — |
| memory | [eat_weight_buffer_banked](memory/eat_weight_buffer_banked.vhd) | — |
| memory | [eat_activation_buffer_pingpong](memory/eat_activation_buffer_pingpong.vhd) | — |
| memory | [eat_attention_state_buffer](memory/eat_attention_state_buffer.vhd) | — |
| memory | [eat_token_index_buffer](memory/eat_token_index_buffer.vhd) | — |
| memory | [eat_model_memory](memory/eat_model_memory.vhd) | — |
| memory | [eat_parameter_store](memory/eat_parameter_store.vhd) | — |
| memory | [eat_constant_loader](memory/eat_constant_loader.vhd) | — |
| tensor | [eat_activation_quantizer](tensor/eat_activation_quantizer.vhd) | — |
| tensor | [eat_weight_unpack](tensor/eat_weight_unpack.vhd) | — |
| tensor | [eat_mac_lane](tensor/eat_mac_lane.vhd) | — |
| tensor | [eat_mac_array](tensor/eat_mac_array.vhd) | — |
| tensor | [eat_requantizer](tensor/eat_requantizer.vhd) | — |
| tensor | [eat_tensor_engine](tensor/eat_tensor_engine.vhd) | eat_mac_array |
| vector | [eat_position_add](vector/eat_position_add.vhd) | eat_vector_engine |
| vector | [eat_residual_add](vector/eat_residual_add.vhd) | — |
| vector | [eat_mean_pool](vector/eat_mean_pool.vhd) | eat_round_divide |
| vector | [eat_rmsnorm](vector/eat_rmsnorm.vhd) | eat_vector_engine |
| attention | [eat_qkv_quantizer](attention/eat_qkv_quantizer.vhd) | — |
| attention | [eat_score_scale](attention/eat_score_scale.vhd) | — |
| attention | [eat_running_normalizer](attention/eat_running_normalizer.vhd) | — |
| attention | [eat_attention_finalize](attention/eat_attention_finalize.vhd) | — |
| attention | [eat_streaming_attention_engine](attention/eat_streaming_attention_engine.vhd) | eat_round_divide |
| tokens | [eat_group_scorer](tokens/eat_group_scorer.vhd) | — |
| tokens | [eat_group_selector](tokens/eat_group_selector.vhd) | — |
| tokens | [eat_token_compactor](tokens/eat_token_compactor.vhd) | eat_round_divide |
| control | [eat_mode_controller](control/eat_mode_controller.vhd) | — |
| control | [eat_encoder_sequencer](control/eat_encoder_sequencer.vhd) | — |
| control | [eat_performance_counters](control/eat_performance_counters.vhd) | — |
| host | [eat_axi_ctrl_regs](host/eat_axi_ctrl_regs.vhd) | — |
| host | [eat_dma_descriptor_engine](host/eat_dma_descriptor_engine.vhd) | — |
| host | [eat_axi_stream_input](host/eat_axi_stream_input.vhd) | — |
| host | [eat_axi_stream_output](host/eat_axi_stream_output.vhd) | — |
| top | [eat_encoder_core](top/eat_encoder_core.vhd) | eat_encoder_sequencer, eat_group_scorer, eat_group_selector, eat_mean_pool, eat_position_add, eat_pwl_silu, eat_residual_add, eat_rmsnorm, eat_streaming_attention_engine, eat_tensor_engine, eat_token_compactor |
| top | [eat_fpga_top](top/eat_fpga_top.vhd) | eat_axi_ctrl_regs, eat_axi_stream_input, eat_axi_stream_output, eat_constant_loader, eat_dma_descriptor_engine, eat_encoder_core, eat_input_buffer, eat_memory_arbiter, eat_mode_controller, eat_model_memory, eat_parameter_store, eat_performance_counters |
| platform | [eat_platform_wrapper](platform/eat_platform_wrapper.vhd) | eat_fpga_top, eat_reset_sync |

## Remaining physical work

Confirm the exact Vivado version, device/board files and PS/DMA clock/reset
integration. Synthesize/map the full hierarchy, audit inferred RAM ports and DSPs,
route at a justified clock, calibrate the cycle model, then validate board outputs,
latency distributions, power/energy and required ablations. The candidate 150 MHz
constraint is a target. Simulated cycles are not measured seconds or energy.
