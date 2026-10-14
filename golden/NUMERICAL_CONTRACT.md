# Candidate integer numerical contract

The current contract is experimental and has not passed G2 or hardware
validation. Each export embeds its own `config/numerics.json` snapshot. Older
exports retain their original arithmetic; do not infer a format from the
directory name alone.

## Stored values and tensor operands

Normalized host inputs are quantized to signed INT8 using a training-calibrated
power-of-two input scale. The integer runtime accepts one such window; dataset
normalization and floating-point host quantization are outside its boundary.
Every matrix projection uses signed INT8 activations and signed INT8 or INT4
weights. Weight scales are per output channel. Activation scales are fixed per
linear input and calibrated from training samples only.

Projection outputs, residuals, positions, nonlinear inputs/outputs, and summaries
use signed 24-bit Q12 state. This wider state is explicit: the design does not
claim that every buffer or nonlinear path is eight bits. Q/K/V can be quantized
to INT8 using separately calibrated power-of-two scales. Their integer reference
stores dequantized Q12 values for simplicity; the equivalent hardware may perform
INT8 dot products and restore the common exponent after accumulation. AV uses
extended exponential coefficients and INT8 values, so its datapath is distinct
from an INT8 weight projection.

Linear accumulators have signed 40-bit range. Bias is quantized into the same
accumulator domain. Per-channel Q24 output multipliers convert dot products
back to Q12. All divisions and right shifts round to nearest with ties to even.
Residual/state saturation is explicit and counted; other declared intermediate
overflows raise errors. NumPy INT64 is a container, not the hardware format.

## Nonlinear functions

Version 1 computes RMS normalization with integer square root followed by integer
division. Its low-variance error motivated the version 2 candidate: a leading-one
normalization and 1,024-entry Q30 reciprocal-square-root LUT with an integer
parity correction and scale shift. Gamma is Q14. The variance epsilon is 168 in
Q24. The LUT sweep measures numerical error, not FPGA resource savings.

PWL SiLU linearly interpolates the training model's knots at integers from -4
through 4. Below -4 it returns zero; above 4 it returns its input. The resulting
tail discontinuity is part of this candidate and is included in the approximation
error study. It must not be described as exact SiLU.

Softmax uses a table of exp(-x), with input step 1/256 over [0,16] and Q20 outputs.
Smaller contributions are truncated to zero. Online attention processes eight
keys per tile, maintains a running row maximum and Q20 normalizer, and rescales
the weighted value state at every tile. The weighted state remains Q12 so its
rescaling product fits the declared integer container. Tile contributions round
before accumulation; this differs from an infinite-precision recurrence and is
tested explicitly.

## Token selection and summaries

The scorer uses the same projection contract. Group ranking compares exact sums
of four Q12 token scores; division is unnecessary for ranking. Stable sorting
selects earlier chronological groups on ties. Selected tokens remain in order.
Each dropped group produces a weighted mean using `abs(score) + 4096`, the Q12
representation of the experimental floating weight `abs(score) + 1`. Summary
division uses the shared nearest-even rule. Every summary is included in later
attention, projections, and pooling.

## Export and verification

An export contains compressed integer constants, a manifest, calibration indices,
source and checkpoint hashes, numeric formats, and optional packed binary files.
Linear weights are row-major `[output_channel,input_channel]`. INT4 weights pack
the earlier element into the low nibble and encode negatives in two's complement;
an odd final weight count pads the unused high nibble with zero. Other binary
arrays currently use signed 64-bit little-endian containers; their payload must
be narrowed according to the manifest before FPGA memory allocation.

The validation harness stores input integers, every traced intermediate, logits,
predictions, changed-prediction counts against batch-1 fake quantization, and
saturation counts. Frozen scales, Q/K/V quantization, and integer nonlinear
rounding introduce discrepancies from the original training model. These must
be measured rather than described as exact PyTorch agreement. Final test and
RTL/board comparisons remain separate gates.
