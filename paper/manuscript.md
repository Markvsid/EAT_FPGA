# EAT FPGA Lite Adaptive Execution of Compact Edge Transformers

Manuscript under development. The experimental evidence currently covers HAR
software validation. FPGA implementation, integer-reference equivalence, the
secondary-workload results, and board measurements remain prerequisites for a
submission under the controlling research plan.

## Abstract

EAT FPGA Lite investigates whether a finite set of execution modes can reduce
the energy of compact edge Transformer inference while maintaining classification
quality. The proposed modes combine four-bit or eight-bit weights, temporal
token-group selection, summaries of discarded groups, and a registered depth
boundary. The model has four encoder blocks, feature width 128, four attention
heads, and feed-forward expansion two. The experimental software pipeline uses
raw UCI HAR inertial windows with subject-disjoint training and validation,
and preserves the official test partition. Across three independent training
seeds, the current floating-point baseline achieves validation accuracy of
92.26 percent with sample standard deviation 0.15 percentage points. These
validation results establish an initial software reference. They do not establish
FPGA energy savings, final test accuracy, or novelty of token summarization.
The final abstract will report the measured outcomes after implementation and
the required controlled ablations.

## 1 Introduction

Short sensor and keyword sequences are a useful setting for studying edge
Transformer execution because their full model weights may reside on an FPGA.
At these sequence lengths, linear projections and feed-forward layers account
for much of the arithmetic. Removing tokens can consequently reduce more than
the quadratic attention cost: it also shortens these linear layers. Selection,
compaction, and summaries introduce costs of their own. The useful research
question is whether their combined effect improves measured accuracy and energy
on the same device, with these costs included.

Paper 1 restricts the model family and hardware modes rather than implementing
the broader EAT FPGA architecture search or trained energy-budget controller.
The proposed investigation compares dense W8A8 execution, dense W4A8 execution,
group dropping, dropping with Residual Token Summary, and one early-exit
boundary. Contribution claims remain conditional on the novelty audit and
measured evidence specified by the research plan.

## 2 Background and related work

DynamicViT learns input-dependent token removal [1]. EViT retains attentive
tokens and fuses inattentive tokens [2]. Token Merging and Token Fusion further
establish merging and aggregation as acceleration techniques [3, 4]. Therefore,
producing a summary of discarded tokens is insufficient as an individual novelty
claim. The prospective distinction is a specific hardware-regular temporal-group
rule and its measured cost and quality in compact sensor and audio encoders.

FPGA pruning co-design has also combined static weight pruning and dynamic token
pruning [5]. TRINE uses a single-bitstream FPGA engine with runtime modes and
in-stream top-k pruning [6]. The final comparison must explain the technical
difference from these designs without claiming novelty for runtime mode selection
or top-k selection alone. `related_work.md` records the initial comparison and
the remaining full-text and patent checks.

## 3 Workload characterization

HAR inputs contain 128 time samples and nine inertial channels. Four-sample
nonoverlapping patches produce 32 tokens, each embedded from 36 input values
to width 128. The four encoder layers contain 524,288 matrix weights. The
current software model contains 539,533 parameters when biases, norms, position
embeddings, the scorer, and both classification heads are included.

For N tokens, width d, and feed-forward expansion r, one block executes
4Nd² projection MACs, 2N²d attention MACs, and 2rNd² feed-forward MACs.
At N = 32, d = 128, and r = 2, this is 4,456,448 MACs per block.
These counts exclude normalization, activation, score selection, division,
residual additions, and transfer overhead. The analytical report separately
counts embedding, scoring, summaries, and classification; it reports excluded
costs explicitly. Ideal MAC cycle bounds are not predicted FPGA latency.

The planned Speech Commands frontend converts 16 kHz mono clips to 40 log-mel
channels in 64 frame slots. Two-frame patches again produce 32 tokens. This
candidate uses the 35-word protocol and official validation and testing lists,
with no synthesized unknown or silence classes. The frontend runs on the host;
its cost must be included in end-to-end latency, separately from accelerator
latency. Audio quality and final frontend selection remain unvalidated.

## 4 Algorithm and hardware co-design

The experimental baseline uses pre-normalized blocks with RMSNorm and
piecewise-linear SiLU. Learned absolute position embeddings are added before
encoding. The final representation is mean pooled over actual tokens, then
classified by a linear head. A second classifier after block two receives an
auxiliary training loss weighted by 0.3. This head is present in every software
configuration to keep the model skeleton consistent.

Gating takes place after the first encoder block. A learned linear score for
each token is averaged within chronological groups of four. Highest-scoring
groups survive; stable ordering selects earlier groups on exact ties. A
straight-through surrogate supplies scorer gradients through retained features.
Compaction preserves chronological group order. Plain dropping emits four tokens
for each retained group. RTS emits those tokens and one weighted summary per
discarded group. The experimental importance weight is the absolute token score
plus one, applied to the group embeddings. Its integer cost and suitability
remain to be established before numerical freeze.

For eight groups and k retained groups, plain dropping processes 4k tokens after
the boundary. RTS processes 4k + (8 − k) tokens. An RTS setting with k = 4
therefore processes 20 tokens and can be compared with plain dropping at k = 5
at the same total token budget. The same-retention comparison separately
measures the cost and information contributed by summaries. Counts include
summaries as actual tokens in all later layers.

Candidate modes currently use full W8A8 inference, W4A8 with six groups plus
summaries, and W4A8 with four groups plus summaries and block-two exit.
The six-group summary setting produces 26 logical tokens and requires explicit
tail handling in a tiled architecture. These modes have not passed architecture
freeze. Mode-selected depth is implemented in software; confidence-driven
early exit and a trained energy-budget controller are not implemented.

## 5 Microarchitecture

The controlling design specifies a shared W8A8/W4A8 tensor engine, tile-streaming
attention, an RMSNorm and activation unit, banked on-chip weights, ping-pong
activations, token compaction and summary logic, runtime mode control, and
performance counters. This section describes the required design, not an existing
implemented accelerator.

The floating-point attention reference processes key/value tiles while maintaining
each query's running maximum, normalizer, and weighted value accumulator. Each
new tile rescales the prior state to the updated maximum before adding its
contributions. Division by the final normalizer produces the attention result.
Tests compare this recurrence with dense attention for sequence length one,
partial final tiles, and the complete encoder. Fixed-point exp approximation,
finite-width recurrence behavior, RTL buffering, and backpressure verification
remain outstanding.

## 6 Analytical model

`architecture/profile.py` generates MAC counts for every implemented software
mode and a dense sequence sweep from 16 to 256 tokens. It also reports payload
sizes for encoder matrix weights, ping-pong activations, Q/K/V, feed-forward
activations, online attention state, and a materialized-score comparison.
These are partial budgets: they exclude scales, metadata, physical allocation
fragmentation, and memory banking overhead. Resource feasibility must be checked
against the confirmed device and synthesized design.

The current cycle output is a lower bound assuming a specified number of MAC
lanes. It does not include memory stalls or nonlinear-unit timing. Calibration
against RTL is necessary before it becomes the approximately 10–15 percent
accurate cycle model required by the plan.

## 7 Implementation and reproducibility

The implementation currently uses Python 3.12, PyTorch 2.14.1, and NumPy 2.5.4.
HAR training uses AdamW, learning rate 0.0003, weight decay 0.01, batch size 128,
30 epochs, cosine learning-rate decay, and gradient clipping at norm one.
Training seeds are 17, 29, and 43. Each run selects its best checkpoint using
validation accuracy. The test set remains separate from model selection.

Validation subjects are 5, 14, 19, and 27 from the official HAR training
partition. The remaining 17 training subjects supply normalization statistics.
Training, validation, and test contain 5,991, 1,361, and 2,947 windows,
respectively. Split index files are stored under `config/splits`. Manifests
record dataset hashes, configuration, software versions, source hashes, working
tree state, checkpoint initialization, and seed.

Fake quantization currently uses per-output-channel weight scales and
power-of-two activation scales. It retains floating-point nonlinear functions,
residual arithmetic, and biases. Runtime maxima determine the candidate
activation scales. This is an exploratory training model, not the frozen-scale
integer reference needed for FPGA equivalence. No tool version, implemented
clock, routed resource usage, or bitstream is available yet.

## 8 Evaluation

The initial HAR FP32 validation results are:

<!-- SOFTWARE_RESULTS_BEGIN -->
| Seed | Selected epoch | Accuracy percent | Macro F1 |
| --- | --- | --- | --- |
| 17 | 14 | 92.138 | 0.91701 |
| 29 | 20 | 92.432 | 0.92436 |
| 43 | 22 | 92.212 | 0.92101 |
| Mean and sample standard deviation | | 92.261 ± 0.153 | 0.92079 ± 0.00368 |
<!-- SOFTWARE_RESULTS_END -->

These are validation measurements of the software baseline, not final test
results or FPGA outcomes. `results/summarize.py` regenerates the supporting
summary from completed run logs. Quantized modes and controlled RTS ablations
must undergo the same three-seed comparison before final mode selection.

The final evaluation must add Speech Commands quality, bit-accurate and board
prediction agreement, routed timing and resources, measured power and energy,
median and p95 latency, the same-board Arm baseline, and board ablations a–e.
Each headline mechanism requires an attributable benefit and overhead. Whole-board
energy is the primary measure; modeled or idle-subtracted energy must be labeled
separately. FPGA performance numbers cannot be inferred from these software
training times or ideal MAC bounds.

## 9 Limitations and discussion

Current results use one short-sequence workload and software execution. The
secondary workload, fixed-point reference, accelerator, physical implementation,
and energy evaluation are incomplete. Novelty is unresolved because token
summaries, merging, and runtime FPGA pruning have close prior work.

The Paper 1 design assumes on-chip weights and one device. It consequently
cannot substantiate a major DDR weight-traffic reduction claim. Learned score
stability, RTS approximation, frozen-scale accuracy, partial tile utilization,
and early-exit quality require validation. The final publication must retain
negative or inconclusive results and disclose the relevant measurement boundary.

## 10 Conclusion

The software baseline and data partitioning are reproducible initial components
of EAT FPGA Lite. They establish a reference for evaluating precision, temporal
group selection, summaries, and depth. The central energy-efficiency hypothesis
remains open until the required controlled FPGA implementation and measurements
are complete.

## References

1. DynamicViT https://arxiv.org/abs/2106.02034
2. EViT https://arxiv.org/abs/2202.07800
3. Token Merging https://arxiv.org/abs/2210.09461
4. Token Fusion https://arxiv.org/abs/2312.01026
5. Accelerating ViT Inference on FPGA through Static and Dynamic Pruning https://arxiv.org/abs/2403.14047
6. TRINE https://arxiv.org/abs/2603.22867
7. UCI HAR https://doi.org/10.24432/C54S4K
8. Speech Commands https://arxiv.org/abs/1804.03209

Publication metadata and full-text quantitative comparisons must be verified
before the submission bibliography is finalized.
