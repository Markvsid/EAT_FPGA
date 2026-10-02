# FPGA Transformer Research Execution Plan

Scope, experiments, milestones and manuscript deliverables

Recommended first-paper scope: a compact Transformer for human activity recognition on one FPGA, testing whether regular token-group reduction and Residual Token Summary improve the measured accuracy–energy tradeoff. Establish dense INT8 execution first; add INT4 only after correctness is stable.

### The research question

Can tile-aligned token-group selection reduce board energy per inference while keeping classification accuracy close to a dense reference, and does a summary of dropped tokens improve that tradeoff after including its hardware overhead? Lower precision is a supporting experiment. Novelty remains a hypothesis until the nearest prior methods have been checked.

### Scope to freeze with the supervisor

| Required for this plan | Conditional or deferred |
| --- | --- |
| UCI HAR; documented subject-disjoint split; fixed preprocessing and tokenizer | Speech Commands as a second workload after primary results are stable |
| One encoder: four blocks, width 128, four heads, FFN ratio 2; RMSNorm and chosen activation | Model-size search, vision, NLP, LLM decoding and training on FPGA |
| One available FPGA; KV260 if confirmed; on-chip weights with a complete memory budget | Second device and DDR-streamed model weights |
| Dense W8A8 baseline; grouped token dropping; RTS comparison | W4A8 if it preserves accuracy; early exit only after core results |
| Complete numerical specification, verified RTL and measured board results | Head gating, 2:4 weight sparsity, INT2, learned energy controller |
| Fixed-point attention with one documented dataflow | Streaming-versus-materialized comparison may begin in the cycle model |

### Recommended contribution boundary

Claim a measured interaction between regular token reduction, summaries, and FPGA execution. Quantization, matrix multiplication and streaming attention are building blocks whose individual use is not sufficient novelty. Do not promise a trained input-difficulty controller: start with explicit operating modes and separately specify how token importance is computed.

Basis: Sections 14.2–14.8 of the supplied EAT-FPGA plan. This execution plan narrows the proposed first paper further; changes to scope and completion criteria require agreement with the supervisor. Performance targets below are experiment thresholds, not predicted results.

## Experiments and success criteria

### Freeze how tokens are selected

Define token grouping, the importance score, decision boundaries, keep ratios, mask propagation, compaction and positional information before RTL work. Use an inexpensive score or a trained gate evaluated in software; include its runtime cost. Fixed retention ratios can still select different groups for each input. Choose ratios on validation data and lock them before final testing.

For RTS, define whether each dropped group becomes one token or another statistic. Specify the averaging weights, numerical scales, rounding, position assignment and whether summaries may be dropped in later blocks. Count retained tokens plus summaries when calculating actual work.

| Build | Purpose |
| --- | --- |
| F0: FP32, all tokens | Reference quality and operator profile; software only |
| H0: dense W8A8 | Same-board hardware baseline; identical model skeleton and numerics |
| H1: W8A8 with grouped dropping | Isolate the effect of removing tokens |
| H2: W8A8 with dropping plus RTS | Isolate the accuracy benefit and hardware cost of summaries |
| H3: dense W4A8, optional | Isolate precision benefit before combining techniques |
| H4: W4A8 plus dropping and RTS, optional | Test whether precision and token reduction work well together |

### Acceptance criteria

Correctness: every implemented mode matches the bit-accurate reference at exported comparison points and at the output. Final board predictions match the integer reference over the full test set. FP32 and quantized models need not produce identical predictions; report their differences.

Quality: use a provisional accuracy-loss budget of at most 1 percentage point relative to FP32, agreed with the supervisor. Report accuracy and macro-F1 for each mode across three independent training seeds where feasible. Compare RTS and plain dropping at matched total processed-token budgets as well as matched group decisions.

Efficiency: select the final mode from validation results. Aim for a clearly measurable reduction in joules per inference relative to H0; do not assume a 2× improvement. Report latency and resource overhead even if energy improves. If the measurement interval cannot distinguish the effect from noise, repeat longer trials or state the result as inconclusive.

### Decision rules

If INT4 harms quality, keep INT8. If RTS does not improve the accuracy–energy frontier after overhead, remove the RTS contribution. If the nearest work already covers the proposed method, revise the contribution before committing the full RTL. If hardware is unavailable, agree a software/numerics study with the supervisor and revise the paper’s claims accordingly; modeled energy cannot support a measured-FPGA claim.

## Implementation steps and handoffs

| Step | Work and exit deliverable |
| --- | --- |
| 1. Feasibility and novelty | Confirm board, tools, team, hours and meter. Build a nearest-work matrix covering token pruning/merging, adaptive FPGA inference and integer attention. Deliver a one-page claim statement and bring-up report. |
| 2. Reference model | Train the fixed model on the subject-disjoint HAR split. Lock preprocessing and tokenizer. Export tensor shapes, MAC counts, activation ranges, accuracy and seed results. Deliver a reproducible checkpoint and profiler. |
| 3. Model experiments | Implement W8A8 QAT, grouped dropping and RTS. Sweep a small set of keep ratios; compare matched-budget configurations. Deliver validation Pareto curves, a fixed mode table and exported weights. |
| 4. Numerical contract | Specify signed widths, scales, zero points if used, accumulators, rounding, saturation, residual alignment and nonlinear approximations. Deliver exact integer code and intermediate golden vectors. |
| 5. Architecture budget | Estimate cycles, bank conflicts, buffer capacity and utilization. Include every weight, activation, summary, lookup table and metadata buffer. Deliver tile sizes, MAC-lane count and a feasible schedule. |
| 6. Dense hardware first | Implement MAC/requantization, buffers, norm/activation and attention. Verify units, then one block, then the full dense encoder. Deliver a timing-clean dense bitstream and board agreement. |
| 7. Adaptive hardware | Add masks, compaction, summaries and mode control incrementally. Verify tails, empty groups, saturation, backpressure and each mode. Deliver layer and full-model agreement plus overhead reports. |
| 8. Measurement and paper | Measure H0/H1/H2; optional H3/H4 only after core results. Generate plots and tables from logs. Finish limitations, related work and reproducibility instructions. Deliver a reviewed manuscript and artifact. |

### Integration contract

Keep a single versioned specification read by both software and RTL: tensor layouts, numeric formats, legal token counts, group sizes, weight ordering and mode identifiers. Every module also needs a port definition, ready/valid rules, reset behavior and golden-vector test. Freeze these interfaces before parallel implementation.

### Ownership

For a team, assign model/numerics, architecture/measurement and RTL/integration owners, with a named reviewer for each handoff. For a student-led effort, complete the same handoffs sequentially and arrange weekly supervisor review. Choose VHDL or SystemVerilog according to team proficiency and tool support; a language change is not a prerequisite.

## Schedule and decision gates

The original eight-week schedule assumes four to six experienced students at roughly 30–40 hours each per week. The student-led ranges below are planning estimates assuming about 15–20 hours per week, one available board, and regular technical support. They are not commitments; recalibrate after the first two weeks. Foundational learning or unavailable lab equipment extends the schedule.

| Milestone | Experienced team | Student-led estimate |
| --- | --- | --- |
| Feasibility, novelty and working baseline | Week 1; setup beforehand | Weeks 1–3 |
| Quantization, grouping and RTS validated | Weeks 2–3 | Weeks 4–6 |
| Integer specification and architecture frozen | Week 3 | Weeks 7–9 |
| Dense full model verified and running | Weeks 4–5 | Weeks 10–14 |
| Adaptive modes integrated | Weeks 5–6 | Weeks 15–17 |
| Board experiments and ablations complete | Weeks 6–7 | Weeks 18–20 |
| Manuscript reviewed and submission ready | Week 8 | Weeks 21–24 |

### Gate A before accelerator implementation

A reproducible FP32 baseline exists; board I/O and logging work; nearest prior methods are identified; one contribution has a defensible distinction. If any item fails, resolve it before implementing the complete accelerator.

### Gate B before formats and RTL are frozen

At least one token-reduced mode meets the agreed validation-quality budget. The integer model reproduces specified operations. The memory and cycle budgets fit the board with routing headroom. If RTS fails, decide whether the remaining method still supports a research contribution.

### Gate C before final measurements

Dense and selected adaptive modes pass integer-reference comparisons, meet implemented timing at the recorded clock, and produce correct board outputs. Use a lower feasible clock or smaller array if needed; report the actual implemented result.

### Gate D before writing headline claims

Required hardware ablations are measured; uncertainty is reported; each claimed mechanism has an attributable benefit and cost. Freeze results before the final writing pass. Drop unsupported claims instead of adding features late.

### Deadline fallback

If only eight weeks are available to one student, first inventory existing code and bitstreams. A feasible initial target may be baseline reproduction, token/RTS software experiments, an integer reference and one validated hardware kernel. Present that as a scoped study or progress milestone unless the supervisor confirms it supplies enough evidence for the intended paper.

## Measurement and manuscript evidence

### A fair measurement protocol

Use identical input sets, batch size 1, clock settings and host boundaries for comparisons. Report accelerator-only latency separately from preprocessing and end-to-end latency. Measure median and p95 after warm-up; repeat timed runs and record active cycles, stalls and processed tokens.

Define the power boundary: whole-board input or named rails. Log idle and active power, instrument resolution and sampling rate. For short inferences, run sustained repeated batches over a window long enough for the meter; compute energy per inference as integrated window energy divided by completed inferences. Report whole-board energy primarily, and clearly label any idle-subtracted estimate. Include controller, compactor and summary overhead.

The optional CPU baseline uses the same task, preprocessing, model and precision where supported. Record implementation, thread count and timing boundary. Different low-level kernels or arithmetic behavior must be disclosed. The dense FPGA build is the most controlled baseline for isolating accelerator changes.

| Paper evidence | What it supports |
| --- | --- |
| Quality table over seeds and modes | Accuracy budget; FP32 versus integer effects; RTS comparison |
| Latency, energy and uncertainty table | Measured benefit against the same-board dense baseline |
| Resource and post-route timing table | Feasibility; LUT/FF/DSP/BRAM/URAM use; controller/RTS cost |
| Accuracy versus energy plot | Tradeoffs among legal modes and the baseline |
| H0/H1/H2 ablation plot | Separate effects of dropping and summarization |
| Cycle/utilization and token-count breakdown | Explanation of speedups, stalls and summary overhead |
| Sequence-length sweep, labeled measured or modeled | Where attention streaming matters and where it does not |
| Nearest-work comparison and limitations | Specific contribution and honest scope |

### Keep claims proportional to the evidence

On-chip weights and short sequences make major off-chip traffic savings a weak headline for this first paper. Report measured board energy and latency, and any exactly counted transfers. State limits: one task, one model family, one board, chosen group sizes and selected precision. Use real executed operations when reporting sparse/adaptive efficiency; also provide dense-equivalent counts with an explicit label.

### Reproducibility package

Store dataset split indices, preprocessing, checkpoints, mode definitions, integer code, RTL, test-vector generator, tool versions, build scripts, raw logs and figure scripts. Tag the exact commit for each bitstream and result. A new user should be able to regenerate the principal tables using documented commands.

## Writing workflow and immediate actions

### Write alongside the experiments

| Manuscript part | Draft timing and source |
| --- | --- |
| Introduction and related work | After novelty review: problem, nearest methods and provisional hypothesis |
| Workload and method | After baseline/model experiments: preprocessing, shapes, gates and RTS definition |
| Numerics and architecture | After design freeze: formats, approximation error, memory and pipeline schedule |
| Implementation | After working bitstream: device, tools, constraints, actual timing and resources |
| Evaluation | After results freeze: scripted figures, comparisons, uncertainty and negative results |
| Abstract and conclusion | Last: describe the final measured contribution, not initial ambitions |

### First five working days

Day 1: Meet the supervisor to confirm your responsibility, available hours, teammates, deadline, board and required paper type. Agree the core H0/H1/H2 scope and provisional accuracy budget. Create an issue list with owners.

Day 2: Inspect existing code, datasets and hardware. Run a minimal PyTorch training/inference example and board DMA loopback if equipment is ready. Record missing prerequisites and lead times.

Day 3: Trace one encoder block and record tensor shapes, parameters and MAC counts. Lock subject-disjoint dataset splits. Draft the tokenization and numerical-interface specification.

Day 4: Build the related-work matrix. Read the closest token-pruning/merging and FPGA-adaptivity methods directly; record exactly how the proposed experiment differs. Do not rely on reference titles alone.

Day 5: Demonstrate a reproducible baseline or a documented training run, show the bring-up status, and review the scope with the supervisor. Update schedule estimates from actual progress.

### Completion checklist

The paper is ready for submission when the core hardware comparisons are complete; outputs agree with the integer reference; implemented timing is valid; accuracy and energy methodology are reproducible; every contribution has direct evidence; nearest prior work is compared; limitations and negative results are included; and an independent reviewer can follow the argument and reproduce the main table.

Select the venue after the contribution and evidence are clear. Check current submission rules, length limits and disclosure requirements before formatting. Supervisor approval and institutional policies govern submission; manuscript completion does not imply acceptance.
