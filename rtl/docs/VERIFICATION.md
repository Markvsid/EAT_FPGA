# RTL implementation and verification plan

## Current evidence

All 48 entities are implemented; structural analysis/elaboration and the complete
hierarchy guard pass. Exact tests cover 2,622 primitive cases, 966 service cases,
64 routed arbiter responses, eight tensor cases, 30 vector cases, 11 attention
cases, eight token-gate cases, four QKV cases, all 27 exported images, four loaded
resident images, 83 AXI-Lite transactions and 32 framed stream/DMA cases. A
separate compact-RAM regression checks all three banks, byte writes, capacity and
region bounds, response stalls, rejected-write preservation and reset metadata.

Full encoder and platform tests are separate long-running suites. Current
source-fingerprinted reports belong in `rtl/validation/implementation_v2/`;
`phase1/` and `integration_v1/` are historical checkpoints. Consult the actual
case list before claiming a run. Full encoder tests compare every final integer
logit and MAC/saturation totals for the listed saved or stress inputs. They are
not full-dataset RTL evaluations.

GHDL synthesis-front-end checks pass for 13 primitive units and eight integration
tops, including the complete platform wrapper. The tensor engine uses shifted
fixed slices to avoid a GHDL 6 variable-slice internal error. No Vivado mapping, routed
timing, FPGA latency, power or board result is claimed.

## Implementation sequence

| Milestone | Implement | Exit evidence |
| --- | --- | --- |
| M0 established | Types, draft ports, inventory, build/CI and vector bridge | Structural checks and explicit stub guards only |
| M1 primitives implemented | FIFO/flush, nearest-even shift/divide, reduction, leading-one | Exact primitive tests and GHDL synthesis-front-end checks pass; broaden integration corner cases as units are connected |
| M2 dense building blocks | W8/W4 unpack, MAC lane/array, bias/requant, SRAM wrappers, positions, RMSNorm/PWL, residual/pool, host loopback | Every block matches exact integer arrays and counts; width/load/protocol tests |
| M3 dense W8 encoder | QKV, streaming attention, full four-block schedule, classifier and output framing | Dense full-layer/model traces match; actual cycle counts; same-RTL dense baseline |
| M4 adaptive Lite | Scoring, stable group selection, RTS/compaction, W4 mode and block 2 exit | All 3 modes/workloads,20/26/32 tokens, mode/bank switching and exact vectors |
| M5 integration | PS DMA/clock/reset, on-chip bank mapping, synthesis and routing | Recorded part/tool/clock, feasible resources, routed timing, board bit-exact tests |

Host/DMA bring-up can proceed independently with agreed interfaces. Algorithmic
changes, structured 2:4 weight sparsity, INT2, head gating and learned mode policies
are not introduced by this implementation. The template's G1/G2 conditions still
apply; do not treat this table as permission to bypass them.

## Test obligations by block

| Blocks | Numerical/functional oracle | Required edge cases and protocol checks |
| --- | --- | --- |
| round_shift | `golden.arithmetic.shift_round` | Positive/negative half ties, zero shift, checked left shift, extremes,72-bit product before narrowing |
| round_divide | `golden.arithmetic.round_divide` | Both numerator signs, odd/even ties, denominator 1/non-power-of-two, zero-denominator error |
| FIFO/register/reset | Accepted sequence scoreboard | Empty/full, simultaneous push/pop, every stall position, flush/reset while full, no stale valid |
| weight_unpack | `golden.pack` and raw constants | W4−8..7, W8−128..127, low/high half and nibble order, invalid precision, partial columns |
| MAC/requant/tensor | `*.input_int8`, `*.accumulator`, linear outputs | K36/80/128/256, tails, bias domain, positive Q24 coefficient, checked product, intentional state saturation |
| parameter/input/weight/activation stores | Exact image and request scoreboard | Checked narrowing, byte enables, read/write ordering, bank swap/identity, response stalls, reset validity |
| position/residual/pool | `position_added`, residuals, `pooled` | Independent source arrival, context mismatch, saturating adds, actual 20/26/32 counts, class 6/35 tails |
| RMSNorm/PWL | `golden.arithmetic` plus norm/activation traces | Zero rows, low variance/epsilon, powers of two, leading-one parity, gamma signs/range, knot/tail boundaries |
| QKV/QK/score | Q/K/V traces and arithmetic oracle | Per-tensor exponents, restored Q24 dot, two distinct rounding steps, signed score ranges |
| rowmax/exp/normalizer/AV/finalize | Direct arithmetic drivers plus complete attention output | Equal scores, extreme negative scores, exp address ties/truncation, N1/17/20/26/32, partial key tiles, first-tile alpha 0 |
| scorer/selector/RTS/compactor | `gate.scorer`, group sums/indices, compacted output | Stable ties, all retained, each keep/drop pattern, chronological order, abs(score)+4096, summary denominator and numerator bounds |
| sequencer/mode controller | Reference operation order and accepted commands | Four versus two layers, correct head/global norm, no Quality scorer fetch, reject busy mode changes, unsupported commands |
| AXI-Lite/streams/descriptor | Independent channel/packet scoreboards | AW/W reordering, strobes, delayed responses, TLAST early/late, TKEEP, sign-extended logits, rejected loads, DMA abort/recovery |
| counters | Accepted-event software scoreboard | Active/bubble/stall/saturation/bytes, last-output completion, atomic low/high read snapshot, clear/reset rules |
| top/platform | Full frozen model vectors | Long runs of mixed modes, reset/abort at every phase, all golden outputs, no stale context or parameter identity |

Each functional bench must fail on nonzero integer error; predicted-label equality
alone is insufficient. Record saturation counts and assert other overflow bounds.
Drive deterministic randomized backpressure with a reproducible seed and explicit timeouts.
For variable-latency units, queue metadata with the accepted operand and compare
it at output; do not advance a query/token counter because valid alone is high.

## Golden sources and serialization

The release catalog selects the exact checkpoint/export and workload. Independent
cases live under `results/alignment_study/{validation,test}/<case>/`; shared cases
under `results/software_release_v1/{validation,test}/<case>/`. Each has first-input
golden vectors, all final logits/labels, and full per-point error records. The
current Python comparisons are exact, including perturbed inputs.

`export_vectors.py` replays a selected NPZ case and exports one scalar per hex line
with declared width, sign, fraction bits, shape, row-major order and hashes. Hex
padding above the declared width is zero; interpret the sign at the declared bit.
Array axes are preserved: Q/K/V are head/token/head-feature; tensor activations
are token/feature. VHDL readers must not infer array shape or 64-bit formats from
NumPy containers. Input exponents and parameter identities come from the export.

The saved full-model trace does not expose every internal exp/rowmax/normalizer
state. Generate those unit cases with direct arithmetic drivers and verify the
assembled attention output against the existing reference. Do not claim full
primitive coverage merely because a boundary-vector conversion succeeds.

## Promotion and evidence

Replace a `stub` architecture only after reviewing the interface. Update inventory
status to `implemented` only when its functional tests exist and pass; retain
source/checkpoint/vector hashes, seed, tool version and cycle counts in reports.
The synthesis checker traverses declared service dependencies and rejects any
remaining stub. Raw Vivado invocation bypasses that protection: synthesis ignores
simulation assertions and could optimize an inert stub into constants. Use the
checked entry point, not stub utilization as evidence.

Out-of-context reports precede full integration. The Vivado part is deliberately
an explicit argument; board pin and PS constraints are not guessed. The supplied
6.667ns constraint is a candidate 150 MHz target, not measured Fmax. No false-path
or multicycle exceptions are supplied without justification. Later calibrate
the cycle model against RTL (template target about 10–15 percent agreement), then
route, verify exact board outputs and collect real latency/power/energy data.


## Current diagnostic-counter checks

Core regression independently counts stalled external requests and awaited
responses and requires exact EV_MEMORY_STALL agreement. It checks nine distinct
aggregate events, nonzero bounded bubble/nonlinear counts, MAC and saturation
counts against Python, and byte/token totals against the selected profile.
Platform tests verify nonzero diagnostic registers and coherent snapshots across
repeat inference. Counter categories and overlap are specified in
[HOST_PROGRAMMING.md](HOST_PROGRAMMING.md).
