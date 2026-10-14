# Initial nearest prior work audit

Updated search on 2026-10-14. TRINE and the 2024 simultaneous-pruning work have
been inspected in full-text HTML; other entries need the indicated full-text
checks before novelty claims are frozen. No
numerical cross-paper speedups are asserted. Patent search is still required.

| Work | Relevant established idea | Consequence for EAT FPGA Lite |
| --- | --- | --- |
| [EViT](https://arxiv.org/abs/2202.07800), 2022 | Retain attentive tokens and fuse inattentive tokens during ViT execution | Summarizing discarded tokens is already established. Test whether temporal fixed groups and measured FPGA overhead provide a specific useful difference. |
| [DynamicViT](https://arxiv.org/abs/2106.02034), 2021 | Learned dynamic token sparsification | Learned scoring and token removal alone are insufficient novelty. |
| [ToMe](https://arxiv.org/abs/2210.09461), 2022 | Token merging to accelerate ViTs | Compare summary quality and cost with merging; simple averages need no novelty claim. |
| [Token Fusion](https://arxiv.org/abs/2312.01026), 2023 | Combines token pruning and merging; studies norm-preserving aggregation | Evaluate aggregation accuracy and normalization effects, rather than asserting summary novelty. |
| [Static and dynamic FPGA ViT pruning](https://arxiv.org/html/2403.14047v1), 2024 | Section V-C3 explicitly fuses non-top-k tokens into one token inside the FPGA dropping module | RTS cannot be positioned as the first FPGA summary of discarded tokens. Per-temporal-group summaries require a narrower distinction and matched-budget evidence. |
| [TRINE](https://arxiv.org/abs/2603.22867), 2026 | Runtime mode changes, shared FPGA engine, in-stream top-k token pruning | Single-bitstream adaptive modes and a selector are established. Investigate on-chip edge inference, summary overhead, numeric guarantees, and controlled measurements as possible distinctions. |

Required next comparisons also include EdgeBERT, FAS-Trans, FNM-Trans, integer-only
ViT acceleration, FlashAttention, and the 2025–2026 FPGA papers listed in the Word
document. Verify publication metadata and original quantitative tables directly;
the proposal bibliography is a search starting point.

## Consequence of the full text check

The closest verified FPGA implementation already contains summary formation.
The candidate difference is one summary per chronological fixed-size group,
combined with restricted precision/depth modes on a compact sensor/audio model.
This is an engineering hypothesis, not an established novel algorithm. Retain
RTS as an ablation while the evidence is collected; remove a standalone novelty
claim unless further review supports a specific technical advance.

TRINE Section 5 and Table 2 also provide original implementation metadata:
Vivado 2022.1, U50 at 300 MHz and ZCU104 at 200 MHz, with INT8 arithmetic.
Its multimodal models and device sizes differ from the proposed HAR/KV260 study.
Do not transplant its energy or throughput values as comparable baselines.

## Patent search record

Queries used Google Patents indexing with combinations of transformer, token
pruning, merging, FPGA, and learned thresholds. Relevant primary records:

| Publication | Relevant subject | Research consequence |
| --- | --- | --- |
| [US20220374766A1](https://patents.google.com/patent/US20220374766A1/en) | Learned threshold token pruning in Transformer networks | Threshold-based learned selection is established prior art. |
| [US20240221375A1](https://patents.google.com/patent/US20240221375A1/en) | Swin token pruning, including merging inside spatial windows | Structured-window merging deserves explicit comparison with temporal groups. |
| [US20250124296A1](https://patents.google.com/patent/US20250124296A1/en) | Query-dependent token adaptation, including merging | Token-count adaptation under runtime requirements is already disclosed. |

This is an initial research search, not a complete novelty determination. Search
must be repeated when the architecture is frozen and before submission, as the
controlling Word plan requires. Patent-family and claim-level technical mapping
remain outstanding.
