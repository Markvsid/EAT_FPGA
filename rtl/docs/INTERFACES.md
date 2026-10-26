# Proposed RTL interfaces and host ABI

This is draft ABI 1, not an agreed hardware contract. Constants and records are
in `eat_config_pkg`, `eat_types_pkg` and `eat_registers_pkg`. The exact per-entity
ports are in VHDL and `design_inventory.json`; the checker keeps them consistent.

## Clock, transactions and reset

- One common PL clock is proposed. `rst_i` is synchronous active-high in the core.
  The platform adapter receives active-low asynchronous reset and will synchronize
  its release. A separate AXI clock would require an explicit CDC redesign.
- Every transaction transfers only on `valid and ready`. A stalled producer holds
  data, masks, indices, identity and `last` stable. Counters advance on accepted
  work, not on asserted valid alone.
- Commands carry an inference ID, workload, mode and model-bank context. Mode and
  parameter-bank selection remain constant until the inference completes or aborts.
- Proposed busy behavior is rejection of new start/mode/load operations, not
  deferred execution. AXI writes may need `SLVERR`; this must be agreed before
  implementing registers and the mode controller.
- Reset/abort clears valid state, partial reductions, FIFOs and outstanding tags.
  Proposed SRAM policy retains data but invalidates bank identity until the host
  re-arms it. No pre-reset partial inference can become a successful output.
- Module completion refers to the last actual output being accepted. Top-level
  completion follows the last serialized logit beat, not just classifier compute.

## Stream records and numeric boundaries

`state_beat_t` and `act_beat_t` carry eight lanes, per-lane keep bits, token index,
feature base, context and tensor-last. `last` ends the current tensor/command;
row boundaries follow feature counts, not a fixed 32-token assumption. Lane zero
is the earliest feature and maps to the lowest packed bits. Masks exclude only
hardware padding. Speech frontend silence padding is valid model input, as in
the golden model; it must not be masked away.

| Value | Draft boundary representation | Required behavior |
| --- | --- | --- |
| Host and tensor activations | signed 8 | Fixed calibrated exponents; saturation counted |
| W4/W8 weights | signed 4 packed or signed 8 | INT4 low nibble first, sign-extended to a MAC operand |
| State, positions, residuals, summaries, logits | signed 24 Q12 | Saturate at exactly the golden boundaries |
| Linear dot plus bias | signed 40 | Overflow is an error; bias is in accumulator units |
| Multiplier | positive signed 32 Q24 candidate | All 27 current exports fit; future loads outside this ABI rejected |
| Gamma | signed 24 Q14 | Keep the declared reference envelope, not just observed 16-bit values |
| QK restored dot | signed 47 Q24 | Restore Q/K exponents before the golden two-round scaling sequence |
| Attention score | signed 40 Q12 candidate | Carries scaled score/differences, not a signed 24 state clamp |
| Exponential | unsigned 21 Q20 | `exp(0)=2^20` requires21 nonnegative bits |
| Attention denominator | signed 32, nonnegative | Preserve the reference's signed 32 overflow limit |
| Weighted attention state | signed 40 Q12 | Round previous-state rescaling and tile contribution separately |
| Group sum | signed 26 Q12 | Sum four signed 24 token scores without mean rounding |
| RTS numerator | signed 53 | Importance is `abs(score)+4096`; denominator is positive |
| Generic internal container | signed64 | Port convenience, not a claim that every datapath needs64 physical bits |

The 40x32 requantization multiplication produces72 mathematical bits. Form the
full product or prove a safe implementation, check the reference's conservative
`max_abs_accumulator * max_abs_multiplier <= 2^62-1` bound, then round and narrow.
Do not silently wrap a product into64 bits. `audit_numerics.py` validates the
current parameters and a conservative accumulator/product bound for every legal
INT8 activation vector, not merely the calibration set. It does not prove all
nonlinear internal widths or physical feasibility.

All right shifts/divisions use nearest with ties to even, including negative
values. Keep the original two rounding points for QK scaling and each online
attention update. PWL tails and exp truncation are model operations, not generic
overflow saturation events. Only intended input/state clamping contributes to
the corresponding saturation counts.

## Tensor and shared-resource boundaries

One reusable tensor engine serves embedding, Q/K/V projection, output projection,
FFN1/FFN2, token scoring and both classifier heads. `eat_group_scorer` consumes
OP_SCORE results and persists token scores; it does not own another MAC array.
Inventory dependencies describe required services, not physical instance ownership.
RMSNorm, residual, position, PWL and pooling units are also reused across layers.

| Operation | Rows | Reduction K | Output columns |
| --- | --- | --- | --- |
| HAR embedding | 32 | 36 | 128 |
| Speech embedding | 32 | 80 | 128 |
| QKV projection | Actual tokens | 128 | 384 |
| Attention output projection | Actual tokens | 128 | 128 |
| FFN1 / FFN2 | Actual tokens | 128 / 256 | 256 / 128 |
| Scorer | 32 after block1 | 128 | 1 |
| Mean-pool classifier | 1 | 128 | 6 or35 |

The patch reader converts time-major raw bytes into patch rows and must adapt
the recorded host input exponent to the embedding input exponent; do not assume
those fields are always identical. Linear descriptors carry actual M/N/K,
operation, layer, fixed activation shift and parameter/address references.
Invalid sizes or unsupported precision must fail before arithmetic begins.

Quality is the dense W8,32-token,four-block baseline. Balanced uses W4, keeps six
groups and adds two summaries, producing26 tokens after block1. Energy-Saver
keeps four groups and adds four summaries, producing20 tokens and exits after
block 2. Both heads use final global RMSNorm and actual-count pooling. Quality
does not read absent scorer/RTS parameters.

The 26-token row tail, K36 reduction tail, scorer one-column tail and classifier
6/35-column tails must all be explicit. Padded lanes do not enter group sums,
softmax maxima/denominators, summaries or means.

## Memory and parameters

Requests use ready/valid responses and tags; fixed response latency is not assumed.
The proposed logical memory word is64 bits. Raw input words contain eight bytes;
state regions map one logical word to a narrowed24-bit physical element. Packed
weight words and parameter containers have typed address regions. These are
logical offsets, not PS virtual or physical DDR addresses.

Physical banking and image conversion are still a review decision. An8x8 MAC
array needs eight output-channel weights per K step, while the software image is
row-major `[output,input]`. Proposed approach: the host exporter produces audited
banked images from the frozen row-major tensors, with exact round-trip tests;
the loader then writes the agreed physical bank order. An RTL gather/transpose
alternative requires different address/control work. No bank-map choice is
implemented or hidden by the generic64-bit request port.

`eat_weight_unpack.half_i` selects low/high32 bits for a W4 vector of eight
nibbles; lane zero is the lowest nibble of that half. W8 uses all64 bits and
requires half zero. The controller owns reuse of the packed word and actual K
count; unpack does not invent extra valid elements from padding.

The parameter store supplies biases, multipliers, gamma, shifts, positions and
LUTs. Software64-bit containers require checked narrowing before storage. Model
tags are host-verified SHA256 metadata, not hashes computed by a hidden RTL SHA
engine. The host checks image integrity; the controller compares requested and
resident identities. Eight bank IDs are an address-space proposal, not evidence
that eight full models fit in the device. The release's27 settings need not all
reside simultaneously; select a workload/seed/family for deployment.

## AXI stream proposal

The PS uses vendor AXI DMA. `eat_dma_descriptor_engine` handles PL transfer
counts, framing and routing; it is not a custom DDR AXI master. The logical
accelerator peripheral has128-bit streams with16-bit TKEEP and TLAST. No TUSER
dependence is introduced. A preceding transfer descriptor determines whether
the ingress packet contains input data or constants.

Input order is time/frame-major then channel-major, with the first byte in
TDATA[7:0]. HAR supplies1,152 bytes; speech2,560. Parameter load transfers use the
agreed image/region format, still pending review. Invalid length, TKEEP or TLAST
must be detected. Recovery/draining after a malformed frame must be specified
alongside the PS DMA driver before implementation.

Output is class-order logits in sign-extended32-bit words, lowest word first.
HAR returns24 bytes: two128-bit beats, final TKEEP0x00ff. Speech returns140 bytes:
nine beats, final TKEEP0x0fff. TLAST accompanies the final accepted beat. This
preserves the signed 24 Q12 value exactly. Inference identity/status are read via
control registers. Error completion and S2MM cancellation/reset behavior need
agreement; an error must never look like a successful dummy logit packet.

## Draft AXI4-Lite register map

Offsets are in `eat_registers_pkg`. The PS base address is not assigned. AW and W
must be buffered/accepted independently; simultaneous channel arrival cannot be
assumed. Byte strobes and delayed B/R acceptance need dedicated tests.

| Offset | Register | Proposed access/meaning |
| --- | --- | --- |
| 0x00 | CONTROL | Start, begin load, clear done, clear counters, arm bank bits0..4 |
| 0x04 | MODE | RW:0 Quality,1 Balanced,2 Energy-Saver; reject others |
| 0x08 | STATUS | RO busy/done/error/bank-valid; sticky completion proposal |
| 0x0c | ERROR | RO `error_t` ordinal; encoding review required |
| 0x10 | MODEL | RW workload bit0 (HAR0/speech1), bank bits7..4 |
| 0x14 | ABI_VERSION | RO draft1.0, not a hardware compatibility approval |
| 0x18 | NUMERIC_VERSION | RO2 |
| 0x1c | INFERENCE_ID | RW host-assigned 32-bit ID |
| 0x20..0x3c | EXPECTED_ID | RW eight32-bit host-verified identity words |
| 0x40..0x5c | LOADED_ID | RO resident identity words |
| 0x60 | LOAD_ADDRESS | RW logical word address, not a DDR address |
| 0x64 | LOAD_BYTES | RW exact incoming load byte count |
| 0x68 | LOAD_KIND | RW typed constant region |
| 0x6c | OUTPUT_CLASSES | RO6 or35 |
| 0x70 | SNAPSHOT_ID | RO completed inference ID |
| 0x100+8*n | COUNTER[n] | RO low/high32-bit words of a64-bit completed snapshot |

Snapshot data must remain coherent while the CPU reads both halves; proposal is
to retain the last completed snapshot during the next inference. Counter
definitions are in `counter_event_t`. Units, per-layer versus global granularity,
overflow behavior, interrupt acknowledgement and error-clear semantics need review.

## Decisions required before implementation

| Decision | Concrete current proposal | Still required |
| --- | --- | --- |
| Platform | KV260/K26, one PL clock | Confirm Vivado part/board files, PS clock/reset/DMA setup |
| Numeric ABI | Existing v2 arithmetic,32-bit multipliers,24-bit gamma | Approve width/range and overflow behavior with export tests |
| Tensor parallelism | 8x8, no unproven W4 DSP packing | Bank schedule, bandwidth and per-block synthesis feasibility |
| Image format | Host-generated banked weights, checked typed constants | Exact bank/address schema and loader/driver round trip |
| Core ownership | One shared tensor engine and explicit operand rendezvous | Detailed arbitration, buffer lifetimes and outstanding-request limits |
| Busy/reset/error | Reject busy changes; reset invalidates bank identity | Uniform host/RTL errors, DMA recovery and reset persistence tests |
| ABI |128-bit streams,32-bit logits, offsets above | Agree register fields, PS base address and completion/counter semantics |

These review items are not silently marked agreed by creating skeleton files.
