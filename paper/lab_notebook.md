# Research log

## 2026 10 14 Initial intake snapshot

The active Git repository is `EAT_FPGA/`, inside the outer Research directory.
The outer directory is not a Git repository. Both copies of the controlling
Word document are byte-identical. The starting repository has planning documents
and no model, RTL, checkpoints, synthesis reports, or experimental results.

The user explicitly made the Word plan the controlling project document.
Its Paper 1 scope includes both HAR and Speech Commands, W8A8/W4A8 modes,
streaming attention, board comparisons, and the evidence package of Section 14.8.
The later Markdown plans reduce scope; that reduction is not adopted here.

Experimental implementation choices are recorded in `config/har.json`,
`config/speech.json`, and the root README. These choices have not passed G1/G2
and are not a frozen numeric or hardware specification. No supervisor approval,
board access, or toolchain pin has been recorded.

HAR FP32 runs use seeds 17, 29, and 43 with 30 epochs each. Seed-17 Quality,
Balanced, and Energy-Saver experiments fine-tune the same FP32 checkpoint for
30 epochs each. These extra training budgets mean their quality cannot be
attributed solely to quantization or token reduction. A dense FP32 fine-tuning
control and matched-budget dropping/summary experiments remain necessary.
Quality and all nonlinear functions still execute in floating point with fake
quantization; hardware equivalence is not established.

Speech Commands preparation uses the official lists for a 35-word protocol.
The dataset has 84,843 training, 9,981 validation, and 11,005 test clips.
Only a one-epoch pipeline smoke run has been performed; this is not a full
secondary-workload baseline. The raw archive and prepared files remain local
under ignored `data/`. Split indices and filenames live under `config/splits/`.

The initial primary-source review identifies EViT and TRINE as close prior work.
Token summarization and runtime FPGA pruning must not be claimed individually
as novel. Full-text verification and the required patent audit are outstanding.

The local machine provides Apple GPU training through MPS. It has no Vivado or
RTL simulator on PATH; no board endpoint, meter, or remote hardware workstation
has been supplied. Hardware G1 bring-up and later implemented measurements are
external dependencies. The user has been asked for access details.

Ten Python tests pass, covering dense/streamed attention agreement, token order,
tie behavior, summaries, scorer gradients, full-model modes, metrics,
subject separation, training-only normalization, operation counts, matched-token
budget accounting, and the speech frontend. These do not replace RTL tests.

## 2026 10 14 Local software continuation

Completed the declared 45-job matrix, reusing the three initial seed-17 mode
runs. Together with the original baselines/smoke run, 49 training runs are saved.
Both workloads have three-seed baselines and Quality/Balanced/Energy-Saver
experiments. HAR uses matched 30-epoch fine-tuning; Speech uses matched five-epoch
fine-tuning after its 30-epoch baseline. HAR also includes dense FP32/W4 controls,
plain dropping, retention-matched RTS comparisons, a 20-token matched-budget
comparison, and a shared-parameter family. Results are regenerated from logs.

The initial RMS square-root/divide method showed substantial low-variance error
in the sampled numerical sweep. The version-2 candidate uses a leading-one
reciprocal-square-root LUT. Fixed activation scales are calibrated on 1,024
training samples. Integer-only inference now covers embedding, positions, all
blocks, streaming attention, gating/summaries, pooling, and the chosen classifier.
18 independent-mode and nine shared-family checkpoint/mode combinations were
evaluated over complete validation sets. Changed predictions and clipping remain
visible; formats are not frozen and hardware equivalence is not established.

The full text of the 2024 simultaneous-pruning FPGA paper explicitly contains
fusion of discarded tokens in its hardware module. A standalone RTS-on-FPGA
novelty claim is therefore unsupported. The research matrix records this closer
overlap and an initial patent search. Further novelty positioning requires a
specific difference and implementation evidence.

Independent runtime parameter images consume 1,328,624 container bytes for
seed 17 before activation buffers. The shared-weight family has 997,056 unique
constant bytes when identical blobs are deduplicated. This is a payload study,
not a physical banking or timing proof.

Added a portable signed-INT8 C matrix kernel with ARMv8-A NEON support. It agrees
with NumPy on signed limits, tails, and complete-model stress traces on the local
Mac. It has not been benchmarked on Cortex-A53. The board measurement analysis
requires real covered power/timing logs and includes idle gaps in whole-board
energy. No board measurements were generated.

28 local tests pass. Software CI is configured but has not yet been verified
on the remote runner. All final test partitions remain reserved until mode and
format selection is locked. Board access, Vivado, power acquisition, interface
review, RTL, physical implementation, final novelty review, and independent
manuscript review remain outstanding.

## 2026 10 23 Frozen Python evaluation

The current task is software testing on data. Re-read the controlling Word
requirements for full-test numerical comparisons, error reporting and G2 before
opening the held-out partitions. The existing dynamic fake-quantized training
forward and calibrated integer forward have different contracts. A validation-only
sequential counterfactual study on 256 examples per workload/mode, seed17, found
changes from input quantization, fixed linear scales, QKV quantization and full
integer arithmetic. These interacting changes were documented rather than
silently presented as exact equivalence. No checkpoint or numerical export was
modified and no further training occurred.

Froze `results/python_study/evaluation_plan.json` at
2026-10-23T16:11:05.298339+00:00, SHA256
`2d1326e17103f00490601686bfe47689499b84afc33f344cc0fc013cedb535e0`.
The plan fingerprints the controlling template, source files, data, checkpoints
and exports. An older baseline manifest lacked `execution_mode`; its FP32 mode
fallback was corrected before the plan was created and before test inference.

Completed 54 full-test checkpoint/mode evaluations across all three seeds,
including 27 integer comparisons over 152,091 repeated-seed example evaluations.
Official test sets contain 2,947 HAR windows and 11,005 speech clips. The study
covers original FP32, matched fine-tuned FP32, independent modes, HAR ablations
and shared HAR modes. All test logits/labels are saved. No test-driven parameter,
scale, checkpoint or mode selection was performed.

Independent integer mean test accuracies are HAR 93.474/93.055/93.360 percent and
speech 92.379/90.986/90.616 percent for Quality/Balanced/Energy-Saver. Matched
fine-tuned FP32 controls average 93.881 and 92.440 percent. The strong validation
RTS benefit does not carry over clearly: the held-out equal-retained-group
comparison is +0.023 points and matched 20-token comparison +0.238 points, with
large seed variation. Do not infer significance from three seeds.

Full-test final-prediction agreement is about 98.5–98.9 percent, with larger HAR
group-selection disagreement. Per-layer errors, changed choices, input clipping,
saturation counts, first-input vectors and worst-final-logit-error vectors are
stored. A subsequent validation-only scorer sensitivity diagnosis is explicitly
labeled exploratory and post-test; it changes no frozen inference settings.
G2 is not declared passed.

Completed 30 robustness evaluations on the same 120 HAR and 350 speech examples
across configurations and seeds. Gyro removal and 10 dB white noise expose clear
weaknesses. Speech frontend reconstruction matches stored clean features exactly;
noise causes 213/333 PCM-clipped values at 20/10 dB respectively over 5,600,000
values per condition. The balanced subset is exploratory, not the full test set.

Measured isolated batch1 CPU timing on Apple M3 Pro, one PyTorch thread, 20 warmups
and 200 timed forward calls per implementation/checkpoint. Inputs are preloaded,
preprocessed first 32 training windows. The integer reference includes checks,
trace copies and native dot products; software timing is not an FPGA or A53
baseline. There is one timing session and no frequency or thermal control.

The evidence audit recomputes accuracy, F1, confusion matrices and per-class
metrics from saved predictions, verifies labels/indices, hashes and timing samples,
and passes all 54 test/27 integer/30 robustness evaluations. The 29 local unit tests
pass. Accuracy, robustness and all eight confusion plots were visually inspected.
Main report: `paper/python_test_results.md`; numerical findings:
`paper/python_numerical_findings.md`. The manuscript, dataset documentation and
completion checklist now distinguish held-out results from older validation
snapshots. The original hardware and submission requirements remain outstanding.
