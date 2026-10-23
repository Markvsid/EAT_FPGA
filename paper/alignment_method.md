# Numerical alignment method and experiment protocol

## Purpose and authority

The current task is to align the training forward pass with the finite-width
integer simulator, identify the first numerical divergence, and evaluate
validation-selected fine-tuning over three seeds. The controlling Word plan
requires full-model numerical comparison and deterministic golden vectors in
Section 14.7, with G2 conditions in Section 14.8. The template has not been replaced
by a relaxed prediction-agreement threshold.

The previous test study is preserved. Its test sets have already been observed;
this experiment discloses any subsequent test evaluation. The new plan is
`results/alignment_study/training_plan.json`, created before fine-tuning. No
scale, format or checkpoint is selected using subsequent test results.

## Independent aligned forward implementation

`model/aligned.py` retains a trainable copy of the existing encoder parameters.
It independently implements fixed-scale inference using CPU PyTorch operations.
It does not invoke `IntegerEncoder`, NumPy golden arithmetic or the native
integer kernel. Those remain the separate verification implementation.

Each forward state uses the existing numerical contract: training-calibrated
power-of-two input/linear/QKV scales; fixed per-channel weight scales and Q24
multipliers; FP32 parameter/FP32 scale division followed by nearest-even weight
and bias quantization; Q14 gamma; signed24/Q12 state; Q30 rsqrt mantissa lookup;
rounded PWL knots; Q8 exponential addresses and Q20 table values; eight-key
online attention updates; stable integer group sums; weighted summaries and
mean pooling with nearest-even integer division. Residual addition and output
requantization follow the exported order.

`ExactForward` returns exact representable Q12 values and supplies a gradient
through a floating surrogate. An explicit custom autograd operation avoids
forward cancellation roundoff from x+(q−x).detach(). Gradients through quantizers
are straight-through; normalization, activation and attention derivatives use
floating operators. The gate uses the retained-feature straight-through scorer
surrogate; summary weights remain detached as in the previous model.

The gradient model is approximate. Forward alignment does not make the gradient
an exact derivative through discontinuous integer rounding. It does ensure
that each training minibatch sees the finite-width forward values that will be
exported, rather than the previous dynamic fake-quantized values.

## Exact matrix emulation bounds

Bounded matrix products use floating GEMM only with a proof of integer exactness.
INT8 products with at most 256 summands have absolute partial sums at most2^22,
below the FP32 exact-integer limit 2^24. Signed24 QK products over 32 elements
have at most51-bit partial sums, below the FP64 limit 2^53. Q20 probabilities
and signed24 values over eight-key tiles have at most46-bit partial sums.
The implementation checks operand ranges/shapes and requires highest FP32
matmul precision. Other arithmetic uses INT64 containers. This is an exact
numerical emulator; it is not an integer-only PyTorch runtime or a performance
proxy for hardware. The NumPy golden runtime remains integer-only.

## Initial checks and diagnosis

Initially, 34 local tests pass. New tests compare independent signed rounding, bounded
matrix multiplication, nonlinear functions and streamed attention against the
NumPy implementation. Complete HAR mode traces are checked on zeros, alternating
signed limits and random legal INT8 inputs, with multiple examples per batch.
Training/evaluation forward outputs match, and gradients reach embedding/scorer
parameters.

The pre-training diagnosis checks 32 evenly spaced validation examples for each
of 18 workload/mode/seed settings. Every aligned integer trace point matches the
reference exactly. Original dynamic fake quantization first exceeds one Q12 unit
of real error at embedding on 567/576 examples and first RMSNorm on 9. Giving
both models the same quantized host input moves the first Quality divergence to
RMSNorm on 192/192 examples; adaptive modes still first diverge at embedding on
384/384. This is a first-difference report, not additive causal attribution of
final prediction changes. Full raw findings are in `initial_diagnosis.json`.

During implementation, FP64 division was found to change parameter rounding
relative to the existing FP32 exporter. The aligned quantizer retains the
exporter's FP32 division boundary. This correction preceded the experiment
freeze and all fine-tuning. No original exporter, checkpoint or prior artifact
was edited to manufacture agreement.

## Fixed fine tuning budget

All modes start from their own existing checkpoints with seeds 17, 29, 43. HAR runs
three full epochs; speech runs one full epoch. AdamW uses learning rate 3e-5,
weight decay 0.01, batch 128, cosine decay and gradient clipping at 1. Training is on
CPU with one thread per worker and deterministic algorithms. The objective is
primary cross-entropy; no auxiliary-head loss is added. These are limited-budget
fine-tuning runs, not an optimizer sweep or a convergence claim.

Validation selection includes epoch 0. Strict accuracy improvement replaces the
current checkpoint and ties retain the earliest one. All later losses/metrics
are retained even if epoch 0 wins. The initial full-validation predictions must
reproduce the previously recorded integer predictions before training starts.

HAR Quality is trained and fully verified first. HAR adaptive modes follow;
speech starts after HAR verification. Full validation equivalence for all 18
settings is required before selected export hashes are fixed for a subsequent
full test evaluation. Every reference trace point must have exactly zero error,
including selected groups, summaries, linear accumulators, residuals and logits.
Any mismatch stops the pipeline and stores its first divergence.

## Interpretation boundaries

Agreement is measured against the new aligned training forward, not asserted
retroactively for the original dynamic fake-quantized model. Better agreement
alone does not establish better classification, sensor-noise robustness or
stability under perturbed inputs. Checkpoint selection may retain the initial
model if this fine-tuning budget hurts validation accuracy. The shared-weight HAR
family is not retrained here; all 18 settings are independent modes.

The global G2 gate also requires hardware feasibility, tensor/attention unit
verification and the HAR quality condition. Exact software agreement would
satisfy only the corresponding numerical comparison, not those hardware gates.
No RTL, board inference, timing closure or energy result is created by this study.
