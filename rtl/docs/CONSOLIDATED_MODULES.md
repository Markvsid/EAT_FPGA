# Consolidated RTL service boundaries

The initial outline named 52 skeleton entities. The implemented design has 48
entities: two reusable implementation helpers were added and six unused skeleton
boundaries were consolidated into tested engines. No required computation is
replaced with a placeholder or software call.

| Initial boundary | Implemented location | Evidence |
| --- | --- | --- |
| eat_address_generator | address generation is part of eat_tensor_engine | Exact tensor/core regressions |
| eat_patch_reader | raw input unpacking and patch addressing are part of eat_encoder_core | Exact tensor/core regressions |
| eat_qk_tile_engine | DOT_PRODUCT/SCALE_SCORE phases of eat_streaming_attention_engine | Exact tensor/core regressions |
| eat_rowmax_exp | MAX_TILE/EXP phases of eat_streaming_attention_engine | Exact tensor/core regressions |
| eat_av_tile_engine | UPDATE_VALUES phases of eat_streaming_attention_engine | Exact tensor/core regressions |
| eat_rts_summary | SUMMARIZE/divider phases of eat_token_compactor | Exact tensor/core regressions |

The added helpers are `eat_vector_engine` (row-based specialization for position,
RMSNorm and PWL) and `eat_model_memory` (compact resident-bank parameter RAM).
The original proposal and skeleton evidence remain in Git history and the
validation archive. Only the implemented hierarchy is compiled and synthesized.
