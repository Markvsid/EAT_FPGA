# Paper 1 completion evidence

Authority: controlling Word document Sections 14.2, 14.7, 14.8, and 17.
Unchecked requirements prevent a claim of completed Paper 1. Software estimates
cannot replace board measurements.

| Requirement | Evidence location or current gap |
| --- | --- |
| Scope follows Word rather than narrower Markdown | Root README and this checklist |
| HAR raw-signal pipeline, subject-disjoint splits | `model/data.py`; generated `data/har/manifest.json` |
| HAR baseline across three seeds | Completed seeds 17, 29, 43; validation 92.261 ± 0.153 percentage points; checkpoints under `results/runs/` |
| Speech Commands v2 baseline across three seeds | Data pipeline and 35-word config implemented; full baseline training pending |
| Current nearest-work and patent audit | Initial matrix in `paper/related_work.md`; patent audit and full-text verification pending |
| Three validated and frozen modes | Candidate table only in `config/har.json` |
| W8A8 and W4A8 QAT quality | Experimental fake quantization and seed-17 mode training; full three-seed comparisons and frozen scales pending |
| RTS versus plain dropping at equal processed-token budgets | Candidate implementation; controlled experiments pending |
| Exact full-model integer reference | Not implemented |
| Frozen scales, widths, approximation sweeps, exports, vectors | Not implemented |
| RTL tensor engine and fixed-point streamed attention | Not implemented; G1 interface agreement pending |
| RTL controller, compactor, RTS, nonlinear units, buffers | Not implemented |
| Unit, layer, full-model RTL equivalence and backpressure | Not implemented |
| Calibrated cycle model within about 10–15 percent of RTL | Only analytical MAC lower bounds exist |
| KV260 dense and adaptive bitstreams; nonnegative routed slack | Board and Vivado access missing |
| Accuracy over three seeds per workload and numeric stage | Pending |
| LUT, FF, DSP, BRAM, URAM, routed Fmax, WNS and per-block costs | Pending implementation |
| Board outputs versus integer reference on full test set | Pending |
| Mode and dense/Arm CPU median and p95 latency, watts, joules | Board and power harness missing |
| Board ablations a–e, including precision, dropping, RTS, depth | Pending |
| Nonlinear exact/approximate and attention dataflow ablations | FP32 attention recurrence verified only; fixed-point sweeps pending |
| Pareto, waterfall, sequence sensitivity, utilization figures | Sequence MAC/payload sweep exists; measured figures pending |
| Raw and normalized prior-FPGA comparison with differences | Pending source verification and comparable results |
| Review by two people outside core team; Section 17 pass | Pending |
| Authorship, CRediT, venue, institutional/AI policy | Human information missing |

## Current gate

G1 is incomplete: the secondary-workload baselines, full novelty review,
board DMA/power bring-up, and interface agreement are outstanding. No architecture
or numerical contract is frozen. The authority requires evidence at these gates;
it does not authorize treating planned values as experimental results.
