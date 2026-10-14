# EAT FPGA Lite Paper 1

The controlling project instructions are in
`Report_Template/FPGA_Energy_Efficient_Transformer_Research_Plan_2-Month_Extended.docx`.
Paper 1 follows Section 14 and the mathematical reference in Sections 1–12.
The later execution plans propose a reduced scope; they do not supersede the Word plan.

## Current state

This repository began with planning documents only. The experimental implementation
now includes raw HAR and Speech Commands preparation, a four-block PyTorch encoder, candidate runtime
modes, floating-point streamed-attention verification, training, and an analytical
workload profile. This is not a complete FPGA accelerator or submission-ready paper.
See `paper/completion_checklist.md` for the required evidence and its status.

## Reproduce

From this directory, with Python 3.12 and uv:

```sh
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -r requirements.txt
.venv/bin/python -m model.data
.venv/bin/python -m pytest -q
.venv/bin/python -m architecture.profile
.venv/bin/python -m model.train --output results/runs/har_fp32_seed17 --seed 17
```

Run independent FP32 training with seeds 17, 29, and 43. CPU uses deterministic
algorithms. `--device mps` uses the local Apple GPU; exact determinism is not
claimed for that backend. The test set is evaluated only with explicit
`--final-test`, after validation has fixed the modes and protocol.

Candidate fake-quantized fine-tuning is available as:

```sh
.venv/bin/python -m model.train --mode balanced --initialize results/runs/har_fp32_seed17/best.pt --output results/runs/har_balanced_seed17 --seed 17
```

These quantized experiments still execute floating-point nonlinear functions,
residuals, scores, and biases. They are not the exact integer reference and cannot
establish FPGA prediction agreement. Activation scales currently derive from the
runtime tensor maximum; calibrated frozen scales must replace them for hardware.

Speech Commands v2 uses its official speaker-disjoint partitions and all 35 words:

```sh
.venv/bin/python -m model.speech_data --download
.venv/bin/python -m model.train --config config/speech.json --data data/speech --output results/runs/speech_fp32_seed17 --seed 17 --device mps
```

The audio archive is about 2.3 GB. Repeat training with seeds 29 and 43.
The one-epoch pipeline smoke run does not count as a completed baseline.
`requirements.lock` also pins the transitive packages in the current environment.

## Experimental architecture choices

HAR uses nine inertial channels, 128 samples per window, nonoverlapping patches
of four samples, and 32 tokens. Position embeddings are added before encoding.
The encoder has four blocks, width 128, four heads, FFN width 256, RMSNorm, and
piecewise-linear SiLU. Classification uses mean pooling over actual tokens.
An auxiliary classifier after block two receives a 0.3-weight training loss.

Token gating occurs after block one so the scorer sees contextualized features.
A learned linear score is averaged over groups of four; highest scores survive,
with chronological ties and chronological compaction. A straight-through
surrogate trains the retained-group scorer. RTS forms a weighted summary per
discarded group, using `abs(token_score) + 1` as the experimental importance.
Summaries retain the positional information already embedded in their inputs.

The candidate Quality/Balanced/Energy-Saver configurations are not frozen or
validated. Energy-Saver currently selects the second-block classifier by mode,
rather than by an input-dependent confidence threshold. Its accuracy and
hardware feasibility must be tested before claiming adaptive early exit.

## Data and provenance

Official HAR test subjects are preserved. Validation subjects 5, 14, 19, and 27
come only from the official training partition. Normalization is fitted on the
remaining training subjects. The dataset manifest records every split index,
channel order, statistics, archive SHA256, and source URL. HAR is CC BY 4.0:
https://archive.ics.uci.edu/dataset/240/humanactivityrecognitionusingsmartphones

Run manifests record source hashes, the Git commit and working-tree state,
dataset-manifest hash, initialization-checkpoint hash, package versions, seed,
device, config, and training protocol. The seven completed runs from the initial
session are checked in under `results/runs/`, including checkpoints, training
histories, manifests, and metrics. New run directories remain ignored by default;
archive selected runs and their manifests with a tagged commit before publication.
Downloaded datasets, prepared data, and the local virtual environment are
recreated using the commands above and are not included in Git.

## Hardware prerequisites

The current machine has no Vivado or RTL simulator on PATH. Board access, a pinned
Vivado toolchain, and power logging have not been supplied. The template's G1
requires a working board harness, novelty review, and agreed interfaces before
accelerator RTL. Hardware timing, utilization, power, energy, CPU baselines,
and bitstreams remain outstanding. Ideal MAC cycles are analytical lower bounds,
not a calibrated cycle model or measured latency.
