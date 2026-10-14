# Research log

## 2026 10 14 Repository intake and software baseline

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
