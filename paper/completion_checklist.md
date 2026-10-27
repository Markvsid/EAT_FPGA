# Paper 1 completion evidence

Authority: controlling Word document Sections 14.2, 14.7, 14.8, and 17.
Unchecked requirements prevent a claim of completed Paper 1. Software estimates
cannot replace board measurements.

| Requirement | Evidence location or current gap |
| --- | --- |
| Scope follows Word rather than narrower Markdown | Root README and this checklist |
| HAR raw-signal pipeline, subject-disjoint splits | `model/data.py`; generated `data/har/manifest.json` |
| HAR baseline across three seeds | Completed seeds 17, 29, 43; validation 92.261 ± 0.153 percentage points; checkpoints under `results/runs/` |
| Speech Commands v2 baseline across three seeds | Completed 30-epoch seeds 17, 29, 43; validation 92.856 ± 0.063 percentage points |
| Current nearest-work and patent audit | Full-text checks for TRINE and 2024 simultaneous pruning; initial patent search recorded; final architecture/submission audits pending |
| Three validated and frozen modes | Software catalog frozen in `results/software_release_v1/catalog.json`; hardware G2 approval pending |
| W8A8 and W4A8 QAT quality | Three seeds per mode/workload; fair fine-tuning controls; batch-1 reevaluation; still a provisional training/numeric contract |
| RTS versus plain dropping at equal processed-token budgets | Three-seed 20-token comparison, retention controls, and same-checkpoint counterfactual complete in software |
| Exact full-model integer reference | Independent and shared aligned families cover 27 settings per full partition with zero intermediate/logit/group errors; original comparisons preserved; saved-example RTL evidence is separate; full-dataset RTL/board equivalence pending |
| Frozen scales, widths, approximation sweeps, exports, vectors | Training-calibrated scales, version-2 candidate widths, LUT/PWL sweeps, packed images and traces exist; G2 freeze pending |
| RTL tensor engine and fixed-point streamed attention | Tensor and streaming-attention blocks pass exact functional regressions; full core integrated; target synthesis pending |
| RTL controller, compactor, RTS, nonlinear units, buffers | 48 functional entities, no remaining stubs; core and AXI platform integrated; see RTL evidence archive |
| Unit, layer, full-model RTL equivalence and backpressure | Exact primitive/subsystem and stall regressions pass; full-model saved/stress-example RTL suites implemented; full-dataset RTL and board equivalence pending |
| Calibrated cycle model within about 10–15 percent of RTL | Operator schedule with tails/nonlinear/memory assumptions and 54-point DSE exists; RTL calibration pending |
| KV260 dense and adaptive bitstreams; nonnegative routed slack | Board and Vivado access missing |
| Accuracy over three seeds per workload and numeric stage | Original full-test study in `python_test_results.md`; validation-selected aligned study in `aligned_numerics_results.md`, with previously observed test disclosure; board stage pending |
| LUT, FF, DSP, BRAM, URAM, routed Fmax, WNS and per-block costs | Pending implementation |
| Board outputs versus integer reference on full test set | Pending |
| Mode and dense/Arm CPU median and p95 latency, watts, joules | Board and power harness missing |
| Board ablations a–e, including precision, dropping, RTS, depth | Pending |
| Nonlinear exact/approximate and attention dataflow ablations | FP32 and integer attention tests, LUT/PWL sweeps, RMS candidates and Q16/Q20 sensitivity complete locally; synthesized/board comparisons pending |
| Pareto, waterfall, sequence sensitivity, utilization figures | Software accuracy, modeled sequence/memory and exponential-error figures exist; measured energy/waterfall/counter figures pending |
| Raw and normalized prior-FPGA comparison with differences | Pending source verification and comparable results |
| Review by two people outside core team; Section 17 pass | Pending |
| Authorship, CRediT, venue, institutional/AI policy | Human information missing |

## Current gate

G1 is incomplete: the final novelty/scope review,
board DMA/power bring-up remain outstanding. The user explicitly approved
integration contract v2 on 2026-10-26; that interface approval is complete. No architecture
or numerical contract is frozen. The authority requires evidence at these gates;
it does not authorize treating planned values as experimental results.

## Local evidence completed

49 completed training runs include the initial smoke/baselines and a 45-job
declared matrix, reusing three earlier runs. The matrix covers HAR controls,
precision, dropping, RTS, matched budgets, depth, a shared-weight family, and
Speech baselines plus matched five-epoch fine-tuning. There are 18 independent-mode
and nine shared-family integer validation comparisons. The subsequent frozen Python
study evaluates 54 checkpoint/mode settings on the official held-out test partitions,
including 27 integer comparisons. It includes 30 robustness evaluations and isolated
CPU timings; see `python_test_results.md` and `python_numerical_findings.md`.
At the initial software-study snapshot, 29 local tests passed, and native versus NumPy full-model traces agreed on stress
inputs. Whole-model INT8-limit stress tests count intentional saturations and
raise on checked accumulator overflow. These are software checks, not RTL gates.

## Subsequent numerical alignment

The aligned study completes 18 additional fine-tuning runs (three seeds for each
independent mode/workload), with three full HAR epochs and one full speech epoch.
Four speech settings select updated checkpoints; all nine HAR settings and five
speech settings retain epoch0. Fine-tuning does not provide a consistent test
accuracy improvement. Selected validation gains are subject to checkpoint selection.

An independently implemented PyTorch forward matches every NumPy reference trace
point on 102,078 validation and 125,568 subsequent test example evaluations across
seeds/modes. Prediction and group-choice changes are zero. The original dynamic
fake forward is unchanged and is not retrospectively declared equivalent.
All 37 local tests and the full evidence audit pass. This closes the corresponding
independent-mode software comparison; shared-weight alignment and the hardware
parts of G2 remained outstanding at that snapshot. See `aligned_numerics_results.md`
and the completed shared-family follow-up below.

## Frozen software release v1

Shared HAR alignment is complete for three seeds and all three modes, with one
actual parameter set per seed. Nine shared full-validation and nine subsequent
full-test comparisons pass exactly. All 27 final aligned settings also pass exact
comparisons under four predefined robustness conditions each. The release adds
60,012 example evaluations across modes/seeds, not independent unique samples.
All 39 local tests and the release evidence audit pass.

The shared family reduces deduplicated constant containers by about 20 percent
on average, while its HAR Energy-Saver test mean is about 0.92 points below the
independent mode. Initial training budgets and checkpoint-selection objectives
differ, so sharing alone is not isolated. Robustness remains limited under missing
gyro channels and strong speech noise. The independent aligned family remains
the frozen default; shared HAR is an additional option. No new training is added.

`python -m results.software_release run` verifies/reuses saved results and
regenerates the catalog, tables, figures and audit. See `software_release_results.md`
and `software_release_notes.md`. All test/subset reuse is disclosed. This closes
the declared software coverage, not hardware feasibility or the remaining paper
requirements.
