# Initial nearest prior work audit

Initial search on 2026-10-14. Entries below are based on primary-source abstracts
and must be checked against full texts before novelty claims are frozen. No
numerical cross-paper speedups are asserted. Patent search is still required.

| Work | Relevant established idea | Consequence for EAT FPGA Lite |
| --- | --- | --- |
| [EViT](https://arxiv.org/abs/2202.07800), 2022 | Retain attentive tokens and fuse inattentive tokens during ViT execution | Summarizing discarded tokens is already established. Test whether temporal fixed groups and measured FPGA overhead provide a specific useful difference. |
| [DynamicViT](https://arxiv.org/abs/2106.02034), 2021 | Learned dynamic token sparsification | Learned scoring and token removal alone are insufficient novelty. |
| [ToMe](https://arxiv.org/abs/2210.09461), 2022 | Token merging to accelerate ViTs | Compare summary quality and cost with merging; simple averages need no novelty claim. |
| [Token Fusion](https://arxiv.org/abs/2312.01026), 2023 | Combines token pruning and merging; studies norm-preserving aggregation | Evaluate aggregation accuracy and normalization effects, rather than asserting summary novelty. |
| [Static and dynamic FPGA ViT pruning](https://arxiv.org/abs/2403.14047), 2024 | FPGA co-design combining static weights and dynamic token pruning | Grouping plus FPGA acceleration requires a more specific distinction. |
| [TRINE](https://arxiv.org/abs/2603.22867), 2026 | Runtime mode changes, shared FPGA engine, in-stream top-k token pruning | Single-bitstream adaptive modes and a selector are established. Investigate on-chip edge inference, summary overhead, numeric guarantees, and controlled measurements as possible distinctions. |

Required next comparisons also include EdgeBERT, FAS-Trans, FNM-Trans, integer-only
ViT acceleration, FlashAttention, and the 2025–2026 FPGA papers listed in the Word
document. Verify publication metadata and original quantitative tables directly;
the proposal bibliography is a search starting point.
