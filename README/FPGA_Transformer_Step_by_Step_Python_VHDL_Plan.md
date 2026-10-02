MasonU75196# FPGA Transformer Paper Step by Step Plan

This plan explains what to implement, which work belongs in Python or VHDL, and what must be verified before proceeding. The objective is a complete, measured FPGA inference system and a paper explaining whether token-group dropping and Residual Token Summary reduce energy while preserving classification accuracy.

The initial scope is one UCI HAR activity-classification model and one FPGA board. Train the model on a workstation. Execute the inference datapath on the FPGA. Python remains the reference and verification environment throughout the project.

## 1. Understand the division of work

| Workstream | Language or tool | Responsibility |
| --- | --- | --- |
| Dataset preparation and training | Python with PyTorch | Prepare sensor windows and learn model weights |
| Model experiments | Python with PyTorch | Test quantization, token dropping and summaries |
| Exact numerical reference | Python with NumPy or explicit integer operations | Define the outputs the FPGA must reproduce |
| Architecture estimates | Python | Estimate memory, cycles, parallelism and stalls |
| Inference hardware | VHDL | Implement arithmetic, buffers, token handling and control |
| Simulation verification | Python/cocotb with a VHDL simulator, or VHDL testbenches | Drive RTL inputs and compare outputs with the reference |
| FPGA implementation | Vivado and Tcl | Synthesize, place, route and generate the bitstream |
| Host software and result analysis | Python initially; C if the platform requires it | Transfer inputs, collect outputs and analyze measurements |
| Manuscript | Markdown or LaTeX | Explain the method and measured evidence |

Do not translate the PyTorch training script into VHDL. VHDL implements the operations used during inference after the weights and numerical rules have been fixed. Initial clocked MAC exercises and board bring-up can begin early; full-model integration depends on the numerical and interface specifications.

## 2. Freeze a manageable scope

### Required comparisons

| Identifier | Configuration | Where it runs |
| --- | --- | --- |
| F0 | Floating-point model using all tokens | Python; accuracy reference |
| H0 | Dense INT8 model using all tokens | Integer Python reference, then FPGA |
| H1 | INT8 with grouped token dropping | Integer Python reference, then FPGA |
| H2 | INT8 with dropping plus token summaries | Integer Python reference, then FPGA |

Use the same model skeleton and numerical conventions across hardware comparisons. Document any separate fine-tuning and use comparable training budgets. Include both matched selection decisions and matched total processed-token budgets when comparing H1 and H2, because summaries themselves add tokens.

Keep INT4, early exit, head gating, weight sparsity, a second workload and a second board optional. Add them only after H0/H1/H2 are correct and measured. Their omission changes the proposed contribution relative to the broader source plan and should be agreed with the supervisor.

### Recommended initial choices

- Four encoder blocks, model width 128, four heads, FFN hidden width 256.
- Pre-normalization using RMSNorm; one documented activation approximation.
- One token-group size, initially 4; one fixed reduction boundary, initially before the first encoder block.
- Host performs dataset preprocessing and temporal patch formation. FPGA performs learned patch embedding, positional addition, token scoring/selection, encoder inference and the classification head.
- Use a bounded maximum token count and an explicit active-token count. Bypass dropping in H0.
- Use mean pooling over valid final tokens followed by a linear classification head as the initial output design.

These are implementation starting points, not claims that this configuration is best. Validate them in software before freezing them. Record the exact temporal patch length and resulting sequence length rather than assuming token count equals the number of sensor samples.

For token scoring, start with one simple candidate, such as the sum of absolute embedded-feature values within each group. Select a fixed number of highest-scoring groups, preserve chronological order and define a deterministic tie rule. This is a feasibility candidate, not established novelty. Measure its accuracy first. If it fails, evaluate a small learned scorer before implementing the selector in VHDL.

For the first RTS candidate, replace each dropped group with its arithmetic-mean embedding. Construct the summary after positional information has been added, retain group order, and keep summaries valid through the encoder. State this rule explicitly in the paper. A group mean is a baseline RTS implementation; its distinction from existing token-merging methods must be established before claiming novelty.

## 3. Step 1 — Confirm feasibility and the research contribution

**Primary work: project setup and literature review. Small Python checks and board-tool work.**

1. Confirm the board model, available tools, power-measurement equipment, teammates, deadline and weekly hours.
2. Inventory existing training code, numerical models, RTL and bitstreams. Identify what can be reused.
3. Boot the board and demonstrate host-to-FPGA-to-host data transfer using a known-good loopback design. This checks the platform before adding the accelerator.
4. Read the closest work on token pruning/merging, adaptive FPGA Transformers and integer attention. Build a comparison table with method, hardware, evidence and the specific difference proposed here.
5. Write the hypothesis: grouped token reduction lowers measured energy; summaries recover enough accuracy to justify their cost.
6. Agree a provisional accuracy-loss limit, initially 1 percentage point relative to F0, and a latency requirement appropriate to the application.

**Deliver:** setup notes, nearest-work comparison, scope statement and working board transfer demonstration.

**Proceed when:** equipment access is credible, one contribution can be distinguished from prior work, and the supervisor accepts the required comparisons. If novelty is unresolved, continue baseline learning while investigating it; avoid committing the complete accelerator to an unsupported claim.

## 4. Step 2 — Build and train the reference model

**Primary work: Python/PyTorch.**

1. Load UCI HAR sensor windows and labels. Use the raw sequential sensor inputs appropriate to tokenization, rather than silently substituting the dataset's precomputed feature table.
2. Preserve the official subject-disjoint test partition. Create a subject-disjoint validation subset from training subjects. Fit preprocessing statistics on training data only.
3. Form temporal patches. Define how incomplete patches are padded or rejected. Store the channel order, patch length, input shape and label mapping in configuration files.
4. Implement patch embedding, positional information, the four encoder blocks, valid-token pooling and the classifier.
5. Train F0. First debug with one seed; run three independent seeds for final quality comparisons where feasible.
6. Record validation accuracy, macro-F1, training curves, parameter count, tensor shapes and per-operator MAC counts. Keep the test set out of model selection.
7. Export one input and every intermediate tensor from an encoder block. Trace patch embedding, Q/K/V, attention, output projection, residual additions, normalization and FFN.

**Deliver:** reproducible baseline checkpoint, fixed dataset splits, preprocessing configuration and an operator profile.

**Proceed when:** retraining and inference are reproducible, tensor dimensions are understood, and baseline quality is satisfactory for the agreed task. Do not pick an arbitrary accuracy threshold without a valid reference.

## 5. Step 3 — Test the proposed model changes

**Primary work: Python/PyTorch. No full accelerator implementation yet.**

1. Add INT8 fake quantization and quantization-aware training. Export the chosen weight and activation scale rules.
2. Establish dense quantized H0 quality before adding token reduction.
3. Implement group scoring and selection. Try a small validation sweep, for example 100%, 75% and 50% retained groups where the group count permits. Define integer group counts for every mode.
4. Implement H1 by dropping unselected groups before encoder computation.
5. Implement H2 by inserting one summary token per dropped group at the same boundary.
6. Fine-tune as needed under a documented, comparable protocol. Evaluate quality against F0 and H0.
7. Count the actual tokens processed by H1 and H2. Compare quality at similar total token budgets, not only equal keep ratios.
8. Choose a small set of modes using validation data. Lock their settings before final test evaluation.

**Deliver:** validation comparison table, selected modes, scorer/RTS definitions and trained checkpoints.

**Proceed when:** at least one reduced-token configuration meets the agreed accuracy budget and has a plausible compute benefit. If summaries provide no useful tradeoff, remove the RTS claim and reassess the remaining paper contribution. Python operation counts do not establish board-energy savings.

## 6. Step 4 — Build the exact integer reference

**Primary work: Python with explicit integer arithmetic. This is the main numerical handoff to VHDL.**

1. Create a numeric-format specification for each tensor: signedness, width, scale, scale granularity and layout.
2. Specify multiplication widths, accumulator widths, bias representation, rounding, saturation and requantization.
3. Define residual-addition scale alignment. Define exact division/rounding for summaries and pooling.
4. Select fixed-point Softmax, RMSNorm and activation implementations. Implement their lookup tables or approximations in Python using the intended hardware operations.
5. Reproduce the full inference path, including group scoring, tie-breaking, token order and classifier output. Floating-point operations may be used to generate constants offline; runtime reference arithmetic must match the intended hardware rules.
6. Compare the integer model against the fake-quantized model. Locate discrepancies layer by layer; revise QAT emulation or formats if necessary. Report remaining prediction differences and quality effects.
7. Export weights, scales, lookup tables and golden vectors in documented byte/word order.

Use wider Python/NumPy intermediates deliberately and emulate the specified finite-width behavior. Python's arbitrary precision or NumPy's implicit overflow must not define hardware behavior by accident.

**Deliver:** exact integer inference code, numeric-format specification, export manifest and golden vectors.

**Proceed when:** numerical behavior is deterministic, errors relative to the training model are understood, and the integer model still meets the quality budget. FPGA results will be checked against this reference; they are not expected to match FP32 bit for bit.

## 7. Step 5 — Define the FPGA architecture and interfaces

**Primary work: Python estimates plus hardware design notes. VHDL skeletons may begin.**

1. Choose a reusable tiled matrix-multiplication engine. Start with a small feasible MAC-lane count instead of maximizing parallelism immediately.
2. Write a complete memory budget: weights, scales, activations, Q/K/V tiles, attention state, summaries, metadata and lookup tables. Include banking and double buffering.
3. Estimate cycles for embedding, scoring, compaction, projections, attention, FFN, normalization, pooling and classification. Include stalls and partial tiles.
4. Choose attention dataflow. The source plan favors tile streaming with running Softmax statistics. If a simpler materialized implementation is used first, document its capacity limit and revise the contribution accordingly.
5. Define tensor layouts, memory addresses, tile traversal, weight packing and active-token counts.
6. Specify each module's clock/reset, input/output ports, valid/ready behavior and completion conditions. Define what happens under backpressure.
7. Add performance counters for elapsed cycles, useful MAC work, stalls and processed-token counts.

**Deliver:** architecture diagram, memory/cycle budget, interface specification and one shared configuration source.

**Proceed when:** the design fits the confirmed device with headroom and every block has a clear numerical and data-transfer contract. Calibrate estimates against synthesized kernels; modeled utilization and Fmax remain estimates.

## 8. Step 6 — Implement and verify the dense VHDL accelerator

**Primary work: VHDL and Vivado. Python generates tests and compares results.**

Implement in this order:

1. Signed MAC lane and accumulator.
2. Requantizer with the exact rounding and saturation rules.
3. Banked buffers and tiled matrix-multiplication engine.
4. RMSNorm and activation units.
5. Attention score generation, Softmax and weighted-value accumulation.
6. Residual addition and the FFN path.
7. A complete encoder block with its controller.
8. Reuse the block hardware across all four layers.
9. Add patch embedding, positional addition, pooling and classification.
10. Connect control registers and board transfer interfaces.

For each arithmetic block, test ordinary values, signed limits, zeros, saturation and partial tiles. For streaming interfaces, test stalls and reset behavior. Compare with Python golden vectors; matching final labels alone is insufficient to locate arithmetic bugs.

Synthesize blocks early to check resource use and timing. After integration, run full-model simulation, implementation and board inference for H0. Record the actual clock and timing reports.

**Deliver:** dense H0 bitstream, passing block/system tests, board-reference agreement and implementation reports.

**Proceed when:** the full dense path matches the integer reference and meets implemented timing. Fix dense-system errors before introducing adaptive execution.

## 9. Step 7 — Add grouped dropping and summaries in VHDL

**Primary work: VHDL. Python remains the expected-output reference.**

1. Implement the selected group scorer and selector, including exact tie-breaking.
2. Implement token compaction and index/order bookkeeping.
3. Implement summary accumulation, division and requantization for H2.
4. Pass the actual active-token count through attention and later operators. Exclude invalid padded positions from Softmax and pooling.
5. Ensure loops and memory transfers actually shorten for reduced-token modes. Processing every padded token would weaken the expected benefit.
6. Add mode registers for H0/H1/H2 and the legal retention settings. These select existing hardware behavior without FPGA reconfiguration.
7. Compare selector outputs, compacted tokens, summaries and full-model outputs with the integer reference.
8. Re-run implementation and report scorer/compactor/summary overhead separately.

Test full retention, minimum legal retention, equal scores, negative values, incomplete groups and repeated mode changes. Define behavior for zero retained groups or prohibit that mode explicitly. Process the final partial group according to the frozen specification.

**Deliver:** correct H1/H2 implementations, adaptive-module tests and resource/timing reports.

**Proceed when:** every supported mode matches the reference and synthesis confirms the intended reduction in executed work is represented by the architecture.

## 10. Step 8 — Collect board measurements

**Primary work: Python host scripts, board execution and a power meter or validated telemetry.**

1. Warm up the system and use the same test inputs, clock and timing boundaries across H0/H1/H2.
2. Check full-test-set predictions against the integer reference. Record quality against ground-truth labels separately.
3. Record accelerator latency and end-to-end latency separately. Include host preprocessing and transfer costs in the end-to-end result.
4. Repeat runs and report median/p95 latency, execution counters and variability.
5. Log board power over sustained inference windows long enough for the instrument's sampling rate. Compute integrated energy divided by completed inferences.
6. Report whole-board energy primarily. Label any idle-subtracted value separately; record measurement boundary, resolution, sampling rate and uncertainty.
7. Include token scoring and summaries in measured accelerator costs. Record the host boundary and avoid excluding selection overhead from adaptive-mode results.
8. Add the same-board CPU baseline if feasible; disclose differences in arithmetic, implementation and threading.

**Deliver:** raw prediction, timing, counter and power logs, with configuration and commit identifiers.

**Proceed when:** differences are larger than measurement uncertainty or explicitly reported as inconclusive. A lack of savings is a valid result and should trigger narrower claims.

## 11. Step 9 — Analyze results and write the paper

**Primary work: Python analysis and manuscript writing.**

Generate the following directly from recorded results:

- Accuracy and macro-F1 by configuration and training seed.
- Latency, measured power and joules per inference with uncertainty.
- Post-route timing and LUT/FF/DSP/BRAM/URAM use.
- Accuracy-versus-energy tradeoff plot.
- H0/H1/H2 comparisons attributing changes to dropping and summaries.
- Token counts, useful compute and stall breakdown explaining the results.
- Sequence-length sweep where feasible, clearly identifying measured and modeled points.
- Nearest-prior-work table with explicit workload/device differences.

Draft background and related work during Steps 1–2. Draft model/method during Steps 3–4. Draft architecture during Steps 5–7. Finish evaluation after Step 8. Write the final abstract and conclusion last so they match the evidence.

State limitations: one workload, one board, short sequences, on-chip weights, one gating boundary and selected precision. Avoid major off-chip-traffic claims unless transfers are actually reduced and measured or exactly counted. Verify novelty again before submission and check current venue requirements.

**Deliver:** reviewed manuscript plus checkpoints, source code, test vectors, build instructions, raw logs and figure scripts sufficient to reproduce the main comparisons.

## 12. The Python to VHDL handoff checklist

Before full-model VHDL integration, have all of these:

- [ ] Fixed model structure, tokenizer, position rules, pooling and classifier.
- [ ] Trained checkpoints and documented dataset partitions.
- [ ] Selected token scorer, grouping, retention modes and RTS rules.
- [ ] Exact integer reference for every supported mode.
- [ ] Frozen widths, scales, rounding, saturation and lookup tables.
- [ ] Exported weights/constants in a documented layout.
- [ ] Golden vectors at block boundaries and final outputs.
- [ ] Complete memory budget, cycle estimate and module interfaces.

Small VHDL arithmetic modules can be developed once their individual contracts are ready. Python model work and board bring-up can overlap. A change to formats or layouts after integration starts must update the reference, exports, RTL and tests together.

## 13. Suggested repository structure

| Directory | Main contents |
| --- | --- |
| `config/` | Model, modes, formats, board parameters and splits |
| `model/` | Python data preparation, PyTorch training and model evaluation |
| `golden/` | Exact integer Python inference and vector generation |
| `architecture/` | Python cycle/resource estimates and design notes |
| `rtl/` | VHDL inference modules and controllers |
| `tb/` | Python/cocotb or VHDL simulation tests |
| `exports/` | Weight images, scales, tables and expected outputs |
| `impl/` | Vivado/Tcl builds, constraints and implementation reports |
| `host/` | Input transfer, output capture and measurement scripts |
| `results/` | Raw logs, metadata, result tables and plot scripts |
| `paper/` | Manuscript, related-work matrix and figures |

Generate software and VHDL constants from the same configuration. Record the configuration hash with exports and bitstreams to avoid loading mismatched weights or formats.

## 14. Milestones and first actions

| Milestone | Evidence that it is complete |
| --- | --- |
| M1: Baseline ready | Reproducible F0, fixed data pipeline, working board transfer |
| M2: Model changes justified | H0/H1/H2 validation results and locked modes |
| M3: Hardware contract ready | Exact integer model, exports, interfaces and feasible budget |
| M4: Dense FPGA ready | H0 simulation/board agreement and valid implemented timing |
| M5: Adaptive FPGA ready | H1/H2 agreement and overhead reports |
| M6: Results frozen | Required board comparisons, uncertainty and scripted figures |
| M7: Paper ready | Evidence-backed claims, review and reproducibility package |

Keep the previous student-led 21–24-week schedule as a provisional estimate at roughly 15–20 hours per week with technical support. Re-estimate after M1 from actual progress. The source plan's eight-week schedule assumes a much larger experienced team; the new sequence is not an eight-week guarantee.

Start with three concrete actions: confirm the hardware and your assigned responsibilities; create the data/training pipeline for F0; and trace one encoder block's tensor shapes and arithmetic. In parallel, establish whether grouped summaries plus FPGA execution provide a defensible research contribution.

Source basis: the supplied EAT-FPGA research proposal and the preceding execution plan. The simple scorer, initial summary definition, gating boundary, pooling choice and explicit host/FPGA split are recommended starting decisions in this plan and must be validated before design freeze.
