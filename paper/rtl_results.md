# Connected VHDL implementation and evidence

The controlling Word plan remains authoritative. The user approved integration
contract v2 on 2026-10-26; broader novelty, physical implementation and board gates
remain open. This report distinguishes simulation from measured FPGA results.

## Implemented design

The implementation contains 48 VHDL-2008 entities and five packages, with no
remaining stubs. Six initial service boundaries were consolidated into their
consumers, preserving every operation. The core connects one shared 8×8 tensor
engine, registered activation readers, tiled online attention, row-vector units,
block-1 group scoring/selection/RTS, the four-/two-block schedule and classifier.
The platform connects AXI-Lite control, input framing, checked parameter loading,
three compact resident banks, explicit image arming, input storage, logits,
completion interrupts and coherent counter snapshots.

Original numeric-v2 Python code, checkpoints, training data and frozen exports
are unchanged. No new training was required for the RTL work. Model weights and
input data are supplied to the RTL; computed logits are compared to a separate
integer Python reference. Predicted-label agreement alone is insufficient.

## Final functional verification

All 48 entities analyze/elaborate. GHDL synthesis-front-end checks pass for
13 primitive units and eight integration tops, including the complete platform.
All 39 software tests pass. The final exact unit/protocol suites pass: 2,622
primitive cases, 966 service cases, 64 arbiter responses, eight tensor cases,
30 vector cases, 11 attention cases, eight gate cases, four QKV cases, 27
image audits, four loader/resident-image cases each, 42 compact-bank access
transactions, 83 AXI-Lite transactions and 32 stream/DMA frames.

The final source runs ten complete encoder inferences: six saved examples
(HAR/Speech × Quality/Balanced/Energy-Saver, seed 17) plus four directed
stress examples. Every final integer logit matches the separate Python
reference exactly; MAC/saturation counts and byte/token totals also match.
The memory-wait event equals an independently counted handshake scoreboard.
These are **176 checked core logits**, not a full-dataset RTL accuracy study.

| Encoder case | Input | Simulated bench cycles | MAC products | Saturations |
| --- | --- | ---: | ---: | ---: |
| har_energy_saver | golden | 4,888,803 | 7,332,608 | 0 |
| har_balanced | golden | 10,478,003 | 15,351,552 | 0 |
| har_quality | golden | 11,485,824 | 17,974,016 | 0 |
| speech_balanced | golden | 10,580,427 | 15,535,488 | 0 |
| speech_energy_saver | golden | 4,991,305 | 7,516,544 | 0 |
| speech_quality | golden | 11,587,795 | 18,157,952 | 0 |
| har_energy_saver | checkerboard | 4,888,803 | 7,332,608 | 1,376 |
| har_energy_saver | maximum | 4,888,803 | 7,332,608 | 1,632 |
| har_energy_saver | minimum | 4,888,803 | 7,332,608 | 1,632 |
| speech_energy_saver | checkerboard | 4,991,510 | 7,516,544 | 320 |

Core cycles are the bench clock count through completion, including its
short reset/start interval and deterministic input/parameter/output stalls.
Parameter/input services in this bench are simulated. The platform below
uses the actual loader, parameter store, arbiters, compact RAM and serializer.

| Loaded platform case | Inferences | Exact logits each | Kernel cycles per inference |
| --- | ---: | ---: | --- |
| har_balanced | 1 | 6 | 20,178,232 |
| har_energy_saver | 2 | 6 | 9,249,768, 9,249,767 |
| speech_quality | 1 | 35 | 21,597,486 |

The four platform inferences check another **53 logits**. Protocol checks
include malformed transfers, range errors, explicit arming/identity, busy
write rejection, AXIS backpressure/TKEEP/TLAST, repeat input reuse, previous
snapshot retention, coherent counter reads and reset-invalidated residency.

Platform cycle counters cover accepted kernel start through final serialized
output acceptance. They exclude parameter/raw DMA loading. The first integration
checkpoint predates the final pipelines/counters; its cycles are historical.

Reports, input/model identities, source hashes and full-inference logs are in
[the final archive](../rtl/validation/implementation_v2/). GHDL 6 LLVM on macOS
is recorded separately from Ubuntu CI; no target Fmax is inferred.

## Findings and limits

- Profile bias/multiplier counts exceeded the original 2,048-word draft capacity.
  ABI2 corrected both to 4,096 before releasing the image map. All 27 frozen
  images pass exact host reconstruction audits.
- The logical address map has gaps; the implemented RAM stores only a 164-word
  profile plus actual concatenated payloads. Three banks of 90,112 64-bit words
  allocate 2,162,688 bytes. The largest audited image uses 85,445 words. Physical
  RAM inference, fragmentation and full target utilization remain unverified.
- RMS variance, pooling, RTS summaries and attention normalization use iterative
  division. Core operand and QKV reads are registered and preserve ready/valid
  data under stalls. These changes increase cycles relative to the first
  functional integration checkpoint while preserving arithmetic.
- Bubble, external memory-wait and nonlinear-wait counters now have explicit
  observations. Their categories overlap; they cannot be summed as a waterfall.
  Definitions and host recovery are in `rtl/docs/HOST_PROGRAMMING.md`.
- The original analytical schedule assumes bandwidth/overlap absent from the
  serialized functional memory service. It is not calibrated to this RTL and
  does not meet the template's approximately 10–15 percent agreement requirement.
  Preserve the original estimates and report the discrepancy explicitly.
- Saved/stress examples do not establish full-dataset RTL accuracy. All-seed
  software tests and all-image audits do not establish all-seed RTL execution.
- No achieved clock, board latency, power, joules, resource fit or energy advantage
  follows from GHDL simulation or netlist generation.

Next physical work requires the confirmed Vivado version, exact device/board
files and PS/DMA setup. The OOC script can synthesize and optionally route a
confirmed target, but has not been run with Vivado. Inspect activation RAM mapping,
route/timing/resource reports, calibrate the model, then run board equivalence,
latency/power measurements and the plan's controlled ablations.

## Cycle-model discrepancy

The original HAR schedule materially underestimates this implementation.
Its bandwidth/overlap assumptions do not match the serial request/response
service and iterative divisions. It fails the template calibration target.
A constant fitted to these examples would not establish predictive accuracy.

| HAR mode | Boundary | Old estimate | RTL cycles | RTL/estimate | Error relative to RTL |
| --- | --- | ---: | ---: | ---: | ---: |
| energy_saver | Core bench | 291,739 | 4,888,803 | 16.76× | 94.03% |
| balanced | Core bench | 619,003 | 10,478,003 | 16.93× | 94.09% |
| quality | Core bench | 666,439 | 11,485,824 | 17.23× | 94.20% |
| balanced | Loaded PL kernel | 619,003 | 20,178,232 | 32.60× | 96.93% |
| energy_saver | Loaded PL kernel | 291,739 | 9,249,768 | 31.71× | 96.85% |

The original estimates remain unchanged in `results/schedule_estimates.json`.
The comparison is saved in `results/rtl_schedule_comparison.json`. Future
calibration must model the actual transaction schedule and validate predictions
on held-out configurations. These cycle counts establish no board latency or
energy advantage.
