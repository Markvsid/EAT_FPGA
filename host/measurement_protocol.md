# Board measurement protocol

This is the acquisition contract for later KV260 execution. It does not imply
that a board driver or bitstream exists.

1. Record board/image identification, ambient conditions, fixed clocks, tool
   versions, Git commit, configuration hash, weights/export hash, and bitstream
   hash. Use the same test input order and batch size one for every comparison.
2. Verify every board output against the integer reference. Log ground-truth
   quality separately. Matching the final class alone does not establish
   numerical equivalence; retain logits and intermediate debug vectors.
3. Warm up, record the warm-up count, and acquire sustained inference windows.
   Record accelerator timing and host preprocessing/transfer/end-to-end timing
   separately. Use one monotonic timebase or a recorded synchronization mapping.
4. Log whole-board watts and timestamps at the instrument's native sampling
   rate. Include samples before and after the complete inference window.
   Record instrument identity, resolution, sampling settings, calibration, and
   the power boundary. Neither telemetry nor a meter is assumed available.
5. Analyze at least five independent windows per configuration. Choose duration
   from sampling resolution so many samples cover each window. Retain every
   raw trial, including negative or inconclusive savings. Estimate confidence
   intervals across independent windows; adjacent samples are not independent
   experimental repetitions.
6. Primary energy is integrated whole-board energy divided by completed
   inferences. Include controller, scoring, compaction, summaries, transfer
   pauses, and inactive-board costs inside the declared window. Report any
   idle-subtracted value separately, with the idle measurement and method.
7. Record useful MACs, processed tokens, elapsed cycles, active compute cycles,
   stalls, and transfers from verified hardware counters. Report effective
   operations for adaptive execution; do not substitute nominal dense counts.
8. Repeat the dense W8A8, W4A8, dropping, RTS, and early-exit ablations and the
   same-board Arm INT8 baseline. Disclose CPU threads, library, arithmetic, and
   host boundary. Do not compare local Mac training time with FPGA latency.

The analysis CLI consumes `timestamp_seconds,watts` in the power CSV and
`start_seconds,finish_seconds` in the timing CSV. Metadata must include
`batch_size`, `power_boundary`, `clock_hz`, `git_commit`, `bitstream_sha256`,
`configuration_sha256`, `instrument`, `instrument_resolution_w`, and
`warmup_inferences`. These fields must come from the actual run. A covered window
is mandatory; the script rejects extrapolated power and overlapping batch-1
timing records.
