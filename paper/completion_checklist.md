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
| Three validated and frozen modes | Candidate table only in `config/har.json` |
| W8A8 and W4A8 QAT quality | Three seeds per mode/workload; fair fine-tuning controls; batch-1 reevaluation; still a provisional training/numeric contract |
| RTS versus plain dropping at equal processed-token budgets | Three-seed 20-token comparison, retention controls, and same-checkpoint counterfactual complete in software |
| Exact full-model integer reference | Candidate integer-only runtime complete; 27 full-validation and 27 full-test mode/checkpoint comparisons; numerical disagreement documented; no RTL/board equivalence |
| Frozen scales, widths, approximation sweeps, exports, vectors | Training-calibrated scales, version-2 candidate widths, LUT/PWL sweeps, packed images and traces exist; G2 freeze pending |
| RTL tensor engine and fixed-point streamed attention | Not implemented; G1 interface agreement pending |
| RTL controller, compactor, RTS, nonlinear units, buffers | Not implemented |
| Unit, layer, full-model RTL equivalence and backpressure | Not implemented |
| Calibrated cycle model within about 10–15 percent of RTL | Operator schedule with tails/nonlinear/memory assumptions and 54-point DSE exists; RTL calibration pending |
| KV260 dense and adaptive bitstreams; nonnegative routed slack | Board and Vivado access missing |
| Accuracy over three seeds per workload and numeric stage | FP32, fake-quantized and candidate integer full-test study in `python_test_results.md`; board stage pending |
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
board DMA/power bring-up, and interface agreement are outstanding. No architecture
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
29 local tests pass, and native versus NumPy full-model traces agree on stress
inputs. Whole-model INT8-limit stress tests count intentional saturations and
raise on checked accumulator overflow. These are software checks, not RTL gates.
