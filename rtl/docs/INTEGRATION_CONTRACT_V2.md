# Integration contract proposed for review

Status: user agreed to use this contract on 2026-10-26. This agreement addresses
the integration contract, not the remaining research/board gates in the controlling report template's
G1 requirement, **“no RTL on unagreed interfaces.”** The request to implement the
existing skeleton is being used as authorization for its existing compute ports.
The additional host/profile/routing changes below are authorized for implementation.
No G1/G2 completion, resource fit or board readiness is asserted.

The implemented subsystems expose several gaps in the original skeleton contract:
there is no model-descriptor provider or vector-operation selector in the
sequencer, ingress has no raw byte address, and the loader cannot explicitly arm
a selected bank or query that bank's identity. Filling these gaps determines the
host image ABI and core wiring. This proposal makes the choices reviewable before
implementing those interfaces.

## Numerical and stream baseline

Retain the frozen software v2 arithmetic, dimensions, three runtime modes and
both workloads. Existing compute ports use VHDL-2008 ready/valid with synchronous
active-high reset; the platform synchronizes asynchronous reset release. Operands
and metadata stay stable under stalls. All products are formed at their full
width before checked narrowing. Only the specified state/activation boundaries
saturate. No INT2, structured weight sparsity or DSP subword packing is introduced.

The tensor engine emits **tile-major** output: output-column tile, eight token
rows, then subsequent column tiles for that row tile. Consumers scatter by
`token` and `feature_base`; they must not assume a row-major stream. The QKV router
has tested support for this order. Row-based vector units consume row-major
streams supplied by an explicit activation reader.

Attention stores quantized Q/K/V and one query's tile scores, maximum, denominator
and weighted-value state. It never materializes an N-by-N score matrix. Its
memory operands are one sign-extended INT8 value per logical word, in token-major
then head/feature order. The three recorded QKV shifts restore those values.
The fixed scale multiplier is 185364 for the current 32-wide heads.

## Proposed typed parameter image

Introduce `CONST_PROFILE` after the existing nine constant kinds and bump the
host ABI major version to 2. All addresses below are **logical 64-bit words**,
not a DDR byte address or a final physical SRAM allocation.

Bank B has logical base `B * 131072`, for IDs 0..7. Only the model images needed
for a deployment are loaded; eight resident models are not assumed. The active
bank is immutable during an inference.

| Kind | Offset within bank | Maximum words | Container meaning |
| --- | ---: | ---: | --- |
| WEIGHT | 0 | 98304 | Packed W8 bytes or W4 nibbles, output-channel rows first |
| BIAS | 98304 | 4096 | Sign-extended signed40 |
| MULTIPLIER | 102400 | 4096 | Positive signed32, Q24 |
| GAMMA | 106496 | 2048 | Sign-extended signed24, Q14 |
| POSITION | 108544 | 4096 | Sign-extended signed24, Q12 |
| SHIFT | 112640 | 128 | Sign-extended signed8, validated per consuming operation |
| EXP | 112768 | 4097 | Unsigned21, Q20; range 0..2^20 |
| RSQRT | 116865 | 1024 | Unsigned31, Q30; range 0..2^30 |
| PWL | 117889 | 9 | Sign-extended signed24, Q12 knots |
| PROFILE | 130048 | 1024 | Checked control/descriptor words below |

Unused address gaps reject accesses. A typed request carries an offset within
that kind's region. Check bank ID, kind, region length and addition overflow
before issuing a backing-memory request; a bad request returns an error with its
original tag. No wrapping/truncation of an invalid address is permitted.

The present functional RAM modules are 64-bit logical stores with configurable
word counts. They retain RAM contents across reset and flush response-valid state;
software initializes every location it reads. They do **not** establish physical
weight banking, a 24-bit activation SRAM, deduplication or K26 memory fit. The
physical implementation must compact/narrow the image using an audited mapping;
allocating all logical gaps as SRAM is not an accepted resource-fit result.

## Proposed model profile

A profile contains 164 defined words; unused upper bits and reserved words are
zero except signed fields, which are sign-extended. All bounds are checked before
execution. A profile must agree with the selected mode/workload and numeric v2.

| Profile word | Meaning |
| --- | --- |
| 0 | Magic 0x45415432 |
| 1 | Host ABI 0x00020000 |
| 2 | Numeric version 2 |
| 3, 4 | Workload 0 HAR / 1 Speech; mode 0 Quality / 1 Balanced / 2 Energy-Saver |
| 5..13 | Depth, input tokens, width, heads, FFN width, classes, keep groups, RTS flag, group size |
| 14, 15 | Host input Q12 shift; attention scale multiplier |
| 16..24 | Actual payload word counts for existing constant kinds 0..8 |
| 25..31 | Reserved zero |
| 32..39 | Eight 32-bit identity words, same ordering as EXPECTED_ID |
| 40..51 | Q/K/V shifts for each of four blocks, one signed8 shift per word |
| 52..63 | Reserved zero |
| 64+5*s .. 68+5*s | Linear slot s: weight offset, bias offset, multiplier offset, activation shift, weight bits |

Linear slots: embedding 0; for layer l, QKV `1+4*l`, projection `2+4*l`,
FFN1 `3+4*l`, FFN2 `4+4*l`; scorer 17; final classifier 18; exit classifier 19.
A missing slot has all five words zero and must never be scheduled. Operation
shapes derive from the frozen workload/model; descriptors cannot change them.
All referenced payload spans must fit the declared region lengths.

Quality has no scorer schedule. Energy-Saver uses two blocks and slot 19;
other modes use four blocks and slot 18. Input tokens are 32, width 128, heads 4,
FFN width 256, group size 4 and classes 6/35. Keep groups are 8/6/4 and RTS flags
0/1/1. Hardware padding does not remove the speech frontend's valid silence frames.

The host exporter would convert the frozen arrays to this image, verify packing
and narrowing by round trip, and bind hashes to the profile and payload. The
existing golden exports are not rewritten or reinterpreted in place.

## Proposed load and identity lifecycle

Add an explicit idle-only arm request to the loader, carrying bank ID and identity;
add a selected-bank identity readback. Start a new load epoch by invalidating that
bank. Load the checked profile first, then sequential contiguous payload segments
for each region. Track next expected offset and accepted length per region.
Reject overlaps, skips, invalid width containers and early/late TLAST. Arm only
when every declared region is complete, all transfers succeeded and identity,
profile and requested mode/workload agree. Reset invalidates bank identity while
retaining SRAM contents. Interrupted loads never produce a valid bank.

Identity is host-verified SHA256 metadata, not an RTL SHA256 engine. The host must
verify payload integrity before arming; hardware compares tags and validates
lengths/ranges. For a shared parameter family, mode-specific calibration/images
remain distinct unless a later audited physical mapping shares identical blobs.

## Proposed ingress and error recovery

Preserve 128-bit AXI streams, low byte first. Replace the raw-input `act_beat_t`
output with explicit eight-byte word data/keep/last and a 32-bit packet byte offset.
This avoids encoding a 2560-byte packet in model-token metadata or crossing a
36-byte HAR patch inside one tagged activation beat. A separate patch reader
maps the stored raw window to model rows and adapts the host input exponent.

A transfer descriptor is accepted only at idle. Validate contiguous low TKEEP,
exact byte count and final TLAST. On malformed packets, mark the transfer failed,
discard remaining beats through TLAST and inhibit inference until error clear.
The driver resets/cancels its S2MM DMA on an error; hardware does not synthesize
a dummy successful output packet. Reset is the recovery path if TLAST never arrives.

Logits retain the tested signed24-to-signed32 packing: HAR two beats, final
TKEEP 0x00ff; speech nine beats, final TKEEP 0x0fff. Completion is the last actual
output beat accepted by the DMA stream.

## Proposed sequencing and scratch ownership

Add an explicit vector operation selector to the sequencer, covering position,
RMSNorm, PWL, residual and mean pool, plus source/destination/second-source buffer
selectors. Profiles supply parameters; fixed sequencer states determine tensor
shapes and operation order. No opaque inference result, precomputed logits or
Python call substitutes for an RTL operation.

The core owns all activation buffer lifetimes and ready/valid routing. It scatters
tile-major matrix results, reads vectors row-major and maintains an actual token
count after compaction. The connected token-gate implementation uses scratch
words 32768..32799 for signed Q12 token scores; one inference owns that scratch.
The scorer writes all scores with acknowledgements before compaction consumes them.
RTS is currently implemented directly inside the compactor, with exact per-group
importance, signed53 numerator checks and nearest-even division.

Only one request per memory service is outstanding initially. Arbitration locks
a stalled request and routes its response back to the saved owner and original
tag. A response error aborts the inference and flushes pending outputs; the PS
must acknowledge the failure before another start.

## Proposed registers and completion

Retain the draft offsets but report ABI major 2. MODE, MODEL, image loads and START
reject changes while busy with AXI-Lite SLVERR. AW and W are independently buffered;
WSTRB applies to writable bytes, and RO/unaligned/unknown addresses reject writes.
CONTROL clear-done also clears a sticky error at idle. DONE/ERROR drive a sticky
interrupt until acknowledged. LOADED_ID reads the bank selected in MODEL.

Counters count accepted events, include the completion cycle and retain a coherent
completed snapshot during the following inference. The integration must consume
the counter snapshot handshake before another completion; it cannot overwrite a
stalled snapshot. The CPU reads a stable snapshot rather than racing live halves.

## Review boundary

User agreement on this changed host/profile/routing contract was received on
2026-10-26. Existing block tests do not establish hardware G1/G2 completion.
The export audit found 3,724 bias/multiplier values in a full image, exceeding
the original draft 2,048-word capacities. Both regions were corrected to 4,096
words before any ABI2 image or RTL map was released; subsequent offsets follow
`rtl/config/image_schema.json`. This is a bounds correction within the agreed design.
The exact Vivado installation, FPGA part/board files, physical SRAM banking and
board connection are still needed for target synthesis and hardware validation.
The logical proposal provides no measured timing, utilization, latency or power.
