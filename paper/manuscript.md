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

The Speech Commands frontend converts 16 kHz mono clips to 40 log-mel
channels in 64 frame slots. Two-frame patches again produce 32 tokens. This
candidate uses the 35-word protocol and official validation and testing lists,
with no synthesized unknown or silence classes. The frontend runs on the host;
its cost must be included in end-to-end latency, separately from accelerator
latency. Three-seed software validation is complete; frontend selection and
its treatment of two trailing log-silence frames remain provisional.

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
partial final tiles, and the complete encoder. The integer candidate now uses a
finite-width online recurrence with exponential lookup and per-tile rounding.
RTL buffering, backpressure, and fixed-point hardware equivalence remain outstanding.

## 6 Analytical model

`architecture/profile.py` generates MAC counts for every implemented software
mode and a dense sequence sweep from 16 to 256 tokens. It also reports payload
sizes for encoder matrix weights, ping-pong activations, Q/K/V, feed-forward
activations, online attention state, and a materialized-score comparison.
These are partial budgets: they exclude scales, metadata, physical allocation
fragmentation, and memory banking overhead. Resource feasibility must be checked
against the confirmed device and synthesized design.

The initial profiler reports a MAC cycle lower bound. A separate schedule candidate
now includes array tails, GEMM startup, requantization, on-chip transfer assumptions,
normalization, activation, online attention, division, selection, compaction,
summaries, and control. Its nonlinear rates and overlap assumptions are provisional.
Calibration against RTL is necessary before it becomes the approximately
10–15 percent accurate cycle model required by the plan.

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
residual arithmetic, and biases. Runtime maxima determine the training model's
activation scales. A separate integer-only candidate now calibrates fixed scales
on training data, exports finite-width weights/constants, and evaluates the full
validation partition. It uses Q12 residual/nonlinear state, INT8 tensor operands,
per-channel W4/W8 weights, and explicit nearest-even rounding. Candidate formats
and changed predictions are documented in the numerical contract;
FPGA equivalence remains untested. No tool version, implemented
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
results or FPGA outcomes. The complete local matrix now includes three-seed
mode comparisons on both workloads, matched fine-tuning controls, HAR precision
and token/depth ablations, and a shared-weight HAR family. HAR fine-tunes each
independent variant for 30 epochs; Speech fine-tunes each mode and its dense
control for five epochs after the 30-epoch baseline. Checkpoints are selected
using batched validation; deployment-boundary reevaluation uses batch one.

The candidate fixed-scale integer results are:

<!-- INTEGER_VALIDATION_BEGIN -->
| Workload | Mode | Integer validation accuracy percent | Changed predictions versus batch 1 fake quantization |
| --- | --- | --- | --- |
| HAR | balanced | 94.024 ± 1.967 | 47 / 4083 |
| HAR | energy_saver | 93.216 ± 1.479 | 41 / 4083 |
| HAR | quality | 93.534 ± 0.409 | 43 / 4083 |
| Speech Commands 35 words | balanced | 91.928 ± 0.153 | 287 / 29943 |
| Speech Commands 35 words | energy_saver | 91.511 ± 0.250 | 393 / 29943 |
| Speech Commands 35 words | quality | 93.043 ± 0.199 | 279 / 29943 |
<!-- INTEGER_VALIDATION_END -->

The differences from dynamic fake quantization include fixed activation scales,
INT8 Q/K/V operands, finite-width RMSNorm/PWL arithmetic, and per-tile attention
rounding. They are recorded as changed predictions and intermediate errors.
This comparison establishes a software numerical candidate, not FPGA equivalence.
The shared-family results and full per-run evidence are generated separately in
`software_evidence_summary.md` and `current_results.md`.

For HAR, the paired 20-token RTS-versus-dropping comparison improves mean
batch-one validation accuracy by about 0.98 percentage points with sample
standard deviation about 1.00 across three seeds. At a fixed RTS-trained
checkpoint and identical group decisions, adding the two Balanced summaries
changes accuracy by about 0.15 percentage points on average. These answer
different questions; neither establishes measured energy savings or standalone
algorithmic novelty. The nearest verified FPGA work already fuses dropped tokens.

Speech Energy-Saver loses about 1.39 percentage points relative to the original
floating baseline in batched validation, exceeding the one-point envelope used
for the primary HAR workload. This is a task-specific limitation of the current
mode family rather than evidence of equal quality across workloads.

### Held out Python study

The subsequent study fixes the existing checkpoints, preprocessing, mode settings
and training-calibrated scales before evaluating the official test partitions.
It includes 54 checkpoint/mode evaluations, 27 full-test integer comparisons,
30 robustness evaluations and local batch1 CPU timings. Full results, per-class
errors, HAR ablations, numerical agreement, perturbation definitions and timing
boundaries are documented in [Python test results](python_test_results.md).
[Numerical findings](python_numerical_findings.md) map the discrepancy analysis
to the controlling Word template. The software evaluation freeze does not declare
G2 passed, and the test results are not used to select new settings.

<!-- INTEGER_TEST_BEGIN -->
| Workload | Configuration | Test accuracy percent |
| --- | --- | --- |
| har | fp32 (pytorch) | 93.259 ± 0.363 |
| har | fp32_control (pytorch) | 93.881 ± 0.829 |
| har | quality (integer) | 93.474 ± 0.255 |
| har | balanced (integer) | 93.055 ± 0.553 |
| har | energy_saver (integer) | 93.360 ± 0.207 |
| speech | fp32 (pytorch) | 92.101 ± 0.274 |
| speech | fp32_control (pytorch) | 92.440 ± 0.244 |
| speech | quality (integer) | 92.379 ± 0.153 |
| speech | balanced (integer) | 90.986 ± 0.238 |
| speech | energy_saver (integer) | 90.616 ± 0.575 |
<!-- INTEGER_TEST_END -->

The validation RTS advantage is substantially smaller on held-out data. With
the same retained group count, the paired mean gain is 0.023 percentage points;
at a matched 20-token budget it is 0.238 points, with sample standard deviation
0.791 across three seeds. These results do not establish a significant accuracy
benefit. HAR token-group identities also change on about 39–45 percent of
independent adaptive-mode integer comparisons, despite about 98.5–98.9 percent
final-prediction agreement. Validation diagnosis finds small ranking margins
and few exact ties; numerical stability of the execution path remains open.

### Aligned numerical forward and subsequent evaluation

A separate CPU PyTorch encoder now models the existing integer contract during
training, including fixed scales, rounded parameters, nonlinear approximations,
residual states, online attention updates, summaries and pooling. Forward values
are exact under the declared finite-width arithmetic; gradients use explicit
floating surrogates. Bounded floating matrix products are used only where all
integer products and partial sums are exactly representable. This implementation
does not call the NumPy golden forward. It changes the training-forward contract
and does not assert retrospective equivalence for the original dynamic model.

The fixed experiment fine-tunes the independent modes over three seeds, with
three full HAR epochs and one full speech epoch. Existing training-only calibration
is retained. Validation selection includes the starting checkpoint. All nine HAR
settings retain it; four speech settings select updated parameters with small
validation gains. Selecting the maximum including epoch0 makes selected validation
accuracy nondecreasing by construction and is not independent evidence of improved
generalization. Subsequent test results are explicitly disclosed as using the
already-observed test sets. Full methods and evidence are in
[Aligned numerical results](aligned_numerics_results.md).

<!-- ALIGNED_NUMERICS_BEGIN -->
| Workload | Mode | Aligned integer test accuracy percent |
| --- | --- | --- |
| har | quality | 93.474 ± 0.255 |
| har | balanced | 93.055 ± 0.553 |
| har | energy_saver | 93.360 ± 0.207 |
| speech | quality | 92.328 ± 0.103 |
| speech | balanced | 90.998 ± 0.247 |
| speech | energy_saver | 90.586 ± 0.518 |

Across all 18 independent settings, full-validation comparisons cover 102,078
example evaluations and subsequent test comparisons cover 125,568. Maximum
integer error at every recorded point is zero, as are changed predictions and
group choices. The evidence audit independently recomputes parameter quantization
and classification metrics and verifies the frozen artifacts. HAR accuracy is
unchanged because all selected checkpoints are the starting models. Speech mean
test changes are −0.051/+0.012/−0.030 percentage points for
Quality/Balanced/Energy-Saver, providing no consistent accuracy benefit.
<!-- ALIGNED_NUMERICS_END -->

This stage checks implementation agreement on unchanged inputs. It does not
establish invariance of token choices under input noise, a new shared-weight
family, or hardware feasibility. The global G2 and board gates remain open.

### Shared family and final robustness release

The shared HAR checkpoint is now exposed through three aligned mode branches
that reference the same actual parameter objects. All nine shared settings pass
full validation and subsequent test comparisons with zero intermediate, logit,
prediction and group-choice differences. All 27 final aligned settings also pass
exact comparisons under the four predefined robustness conditions. No additional
training is performed for this release; data and subsets were previously observed.

Shared HAR test means are 93.360/92.919/92.444 percent for
Quality/Balanced/Energy-Saver. Deduplicated encoded constant containers average
997,056 bytes versus approximately 1,245,781 for the independent family, about
20 percent less. This is a payload comparison without physical banking or buffer
overhead. One FP32 checkpoint does not imply one identical quantized weight image
for every precision mode.

The families do not have matched per-mode training budgets: independent modes
received 30 fine-tuning epochs each, while the joint family received 30 total
epochs with modes sampled per minibatch and selection by mean mode validation
accuracy. Accuracy differences therefore cannot be attributed only to sharing.
On the fixed robustness subsets, missing gyro channels and 10 dB speech noise
still cause large losses. Exact implementation agreement does not establish
noise resilience. The default independent family is retained for continuity;
all three seeds and the shared option are published without new test-driven
selection. Complete evidence is in [the software release](software_release_results.md)
and [comparison notes](software_release_notes.md).

The final hardware evaluation must add board prediction agreement,
routed timing and resources, measured power and energy,
median and p95 latency, the same-board Arm baseline, and board ablations a–e.
Each headline mechanism requires an attributable benefit and overhead. Whole-board
energy is the primary measure; modeled or idle-subtracted energy must be labeled
separately. FPGA performance numbers cannot be inferred from these software
training times or ideal MAC bounds.

## 9 Limitations and discussion

Current results use software execution. Secondary-workload and controlled mode
training and the held-out Python study are complete locally; fixed-point formats
remain candidates with documented differences from the trained forward pass.
The accelerator, physical implementation, and energy evaluation are incomplete.
Novelty is unresolved: the closest verified 2024 FPGA pruning design already
fuses discarded tokens, so a standalone summary-on-FPGA claim is not supported.

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
