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

## Current verification checkpoint

All 48 entities analyze/elaborate. GHDL synthesis-front-end checks pass for 13
primitive units and eight integration tops, including the complete platform.
The tensor engine originally triggered a GHDL 6 internal error on variable slices;
shifting to a fixed slice resolves it. This is not a Vivado resource/timing result.
All 39 software tests pass. Exact primitive tests pass 2,622 directed/random cases.

The final full-inference suites are running after diagnostic-counter integration.
Their results will be archived with source fingerprints under
`rtl/validation/implementation_v2/`. Historical reports in `integration_v1/`
passed six saved-example encoder cases and repeated HAR Energy-Saver platform
inference before the final pipeline/counter changes; their cycle counts must not
be presented as current-source measurements.

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
