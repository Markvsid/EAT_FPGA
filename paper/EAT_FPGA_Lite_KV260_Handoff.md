# EAT FPGA Lite implementation handoff

*Remaining work for the AMD SK KV260 G*

Prepared 12 November 2026 for the next integration engineer and research lead.

The functional VHDL is written and has passed the archived local simulations. The next work is to repair the hosted simulator setup, establish the Vivado environment, prove target resource and timing feasibility, integrate the board system, and collect the measurements required for Paper 1. Do not restart model training as a prerequisite for this work.

## Authority and baseline

The controlling Word plan takes priority over this handoff and other repository notes, especially Sections 14.2, 14.7, 14.8 and 17. Read the approved integration contract before changing ports, numerical formats or the host ABI.

```text
Report_Template/
  FPGA_Energy_Efficient_Transformer_Research_Plan_2-Month_Extended.docx
rtl/docs/INTEGRATION_CONTRACT_V2.md
```

Repository: github.com/Markvsid/EAT_FPGA. Code baseline HEAD at preparation: 0c97aedfea76d58f27fff105c3874f7370717835. Board-identification updates dated 12 November are also present in the working tree; capture git status before assuming a fresh clone contains them.

| Area | Verified status or remaining work |
| --- | --- |
| Target board | User confirmed AMD SK-KV260-G, Kria KV260 Vision AI Starter Kit. Device: xck26-sfvc784-2LV-c. |
| Functional RTL | 48 implemented entities and five packages; no remaining stubs. Encoder, token gate, RAM services and AXI peripheral are connected. |
| Local evidence | 10 full-core inferences plus 4 loaded-platform inferences; 229 integer logits exact. 39 Python tests passed at the archived checkpoint. |
| Physical implementation | Vivado synthesis, target RAM/DSP mapping, routed timing, bitstream and board execution remain unverified. |
| Research evidence | Cycle model is uncalibrated. Board latency, watts, joules, controlled ablations and final paper gates remain open. |

## First useful deliverable

Produce a reproducible Vivado synthesis run for the confirmed device, with tool/version metadata, hierarchical resource and RAM reports, a checkpoint, and a written assessment of fit and critical paths. Keep numerical results and previously reported failures traceable to their exact source versions.

## 1 Establish the environment and restore CI

### Capture the starting point

Work from the EAT_FPGA repository root. Preserve existing local changes and record the commit, operating system, Python, GHDL and Vivado versions. Confirm who has the board, how it boots, and how serial, network and power measurements will be accessed.

```bash
git status --short
git rev-parse HEAD
python --version
ghdl --version
vivado -version
```

Use a supported Windows or Linux Vivado environment with K26 device support and compatible KV260 SOM/carrier board files. Vivado was not found in the checked workspace environment. Do not treat the Mac simulation setup as a completed target toolchain. Select installed board definitions rather than copying a historical board-file revision.

### Repair the known hosted simulator failure

The latest VHDL workflow inspected for this handoff failed in simulator setup. It is not a green full-inference CI result. The software workflow succeeded. The failed run is 40430413695 for commit 0c97aed; its logs show these errors:

```text
libLLVM-18.so.18.1: cannot open shared object file
exec: /usr/bin/ghdl-mcode: not found
```

Inspect .github/workflows/vhdl-skeleton.yml. Its generated wrapper assumes backend paths and a working LLVM runtime. In an Ubuntu runner, locate the actual executables and inspect shared-library dependencies before selecting a backend:

```bash
command -v ghdl ghdl-llvm ghdl-mcode
dpkg -L ghdl-mcode
ldd /usr/lib/ghdl/llvm/ghdl1-llvm
```

Resolve the installed package/runtime combination or use a consistent pinned tool distribution. Make backend selection use verified paths. Run a tiny VHDL analyze, elaborate and simulate smoke case; a successful version command alone does not test the LLVM compiler library. Then rerun structural, functional and full-inference jobs and retain their artifacts.

[Inspect the failed VHDL workflow and logs](https://github.com/Markvsid/EAT_FPGA/actions/runs/40430413695)

### Prepare the research Python environment

Use Python 3.12 and the pinned requirements.lock. Create a virtual environment if needed and install the recorded dependencies. The historical local GHDL is version 6 LLVM on macOS; its ignored .tools installation is not guaranteed to exist on another machine. Put a verified GHDL on PATH. Read README.md and paper/datasets.md for dataset acquisition; raw datasets, local tools and build outputs are excluded from the artifact.

**Done when: the environment is recorded, the selected GHDL actually compiles and runs, the CI setup errors are resolved, and Vivado recognizes the target device.**

## 2 Reproduce the numerical reference and RTL tests

Read paper/rtl_results.md and rtl/validation/implementation_v2/README.md first. The archive contains 30 passing reports with tested-source fingerprints and complete inference logs. Earlier phase1 and integration_v1 results are historical and have different cycle counts. These instructions reproduce archived coverage; they do not claim that the tests were rerun on the date of this document.

### Run the baseline checks

Commands below assume a POSIX shell and the repository .venv. On Windows, use the equivalent Python and shell paths without changing the intended tests. Run at repository root; long inference suites take much longer than unit tests.

```bash
make -C rtl check
make -C rtl functional
make -C rtl synthesis-frontend
make -C rtl synthesis-integration
.venv/bin/python -m pytest -q
```

GHDL synthesis-front-end checks generate a netlist; they do not establish Vivado device fit or routed timing. make functional runs units, subsystems, images and host protocols. It does not run complete inference.

### Repeat the full archived coverage

```bash
.venv/bin/python rtl/scripts/test_core.py
.venv/bin/python rtl/scripts/test_core.py \
  --case har_energy_saver_seed17 --input-pattern minimum \
  --build-name core_minimum
.venv/bin/python rtl/scripts/test_core.py \
  --case speech_energy_saver_seed17 --input-pattern checkerboard \
  --build-name core_speech_stress
.venv/bin/python rtl/scripts/test_system.py \
  --case har_energy_saver_seed17 --repeat 2 --build-name system_energy
.venv/bin/python rtl/scripts/test_system.py \
  --case har_balanced_seed17 --build-name system_balanced
.venv/bin/python rtl/scripts/test_system.py \
  --case speech_quality_seed17 --build-name system_speech
```

The default core command covers six seed-17 HAR/Speech × mode examples and HAR maximum/checkerboard stress. The two extra core commands bring coverage to ten. Platform commands cover all three runtime modes at the peripheral boundary. Give concurrent jobs distinct build names; preserve reports and logs.

Require exact signed integer logits, metadata, MAC/saturation counts, byte/token totals and protocol checks. Keep per-layer error and changed-prediction analysis as a separate remaining verification task. Saved-example agreement is not full-dataset or all-seed board equivalence.

Use results/software_release_v1/catalog.json to select the frozen exports. Export/checksum validation and all 27 image audits already exist. Retraining or numerical changes require a documented reason and renewed evidence; do not silently alter the golden reference to make hardware pass.

**Done when: failures are resolved, selected cases pass on the new environment, and new reports retain source, input and model identities.**

## 3 Synthesize the design for the KV260

### Select the actual target

Use AMD SK-KV260-G with Vivado part xck26-sfvc784-2LV-c. The machine-readable record is rtl/config/target_board.json. Confirm device support in Vivado and query get_board_parts *kv260* for the installed SOM/carrier definitions. The board SKU does not determine the installed board-file revision, Linux image or Vivado release.

### Run out of context synthesis first

Run from repository root after making the project Python available to Vivado. Replace ABSOLUTE_PYTHON_PATH with the environment executable. Start with synthesis only so memory inference and resource problems can be diagnosed before placement.

```bash
vivado -mode batch \
  -source rtl/platform/vivado_ooc_candidate.tcl \
  -tclargs eat_platform_wrapper xck26-sfvc784-2LV-c \
  ABSOLUTE_PYTHON_PATH
```

The script checks the implementation inventory, reads rtl/sources.f and the candidate XDC, synthesizes the top and writes reports under rtl/build/vivado/eat_platform_wrapper/. Check report-command availability in the selected Vivado version. The script has not been validated with a real Vivado run in this project.

### Inspect mapping rather than accepting a successful command

- Inspect synthesized_utilization.rpt, synthesized_ram.rpt, synthesized_timing.rpt, run_metadata.txt and synthesized.dcp. Archive the tool log and all warnings with the commit and constraints.

- Check BRAM/URAM inference, port counts, banking and fragmentation, especially the two-dimensional activation arrays. Check DSP inference and large arithmetic/reduction paths. GHDL netlist generation does not certify these mappings.

- The current model allocation is three banks × 90,112 64-bit words = 2,162,688 bytes, before other state and physical overhead. The largest audited image uses 85,445 words. Logical region gaps are compacted; do not allocate the full virtual address space as RAM.

### Resolve the clock target explicitly

The Word plan Week 5 says to start near 200 MHz and record any relaxation. G3 targets nonnegative slack at a recorded clock of at least about 150 MHz, with a disclosed fallback if closure fails. The current core_clock_candidate.xdc is 6.667 ns, approximately 150 MHz. Record why this candidate is used or make a separate reviewed 5 ns experiment. Neither value is achieved Fmax. Keep comparisons on declared, fair clock settings.

**Done when: resources plausibly fit, intended memories and multipliers map correctly, major warnings and critical paths are understood, and the synthesis checkpoint and reports are archived.**

## 4 Improve throughput calibrate cycles and close timing

The functional engine fetches scalar operands/parameters serially. The 8 × 8 MAC array waits while these arrive, and several divisions are iterative. W4 reduces stored bytes; no DSP subword packing or automatic twofold speedup is implemented. Treat this implementation as the verified numerical starting point for performance work.

### Use the observed discrepancy as a starting point

| HAR mode | Old estimate | Core bench cycles | Loaded PL cycles |
| --- | --- | --- | --- |
| Quality | 666,439 | 11,485,824 | Not archived for HAR |
| Balanced | 619,003 | 10,478,003 | 20,178,232 |
| Energy Saver | 291,739 | 4,888,803 | 9,249,768 |

Core benches include simulated parameter/input services and deterministic stalls. Loaded PL kernel counters include actual loader/store/arbiter/RAM services through final output acceptance, excluding loading time. HAR estimates underpredict by about 17× for core benches and 32× for the loaded peripheral, with about 94–97% relative error. Preserve the original estimates and read results/rtl_schedule_comparison.json.

### Iterate on the limiting paths

Use transaction traces and synthesis reports to prioritize bank-wide fetches, packed-word reuse/caching, operand buffering and overlapped transfer/compute. Pipeline critical arithmetic and localize reductions where reports justify it. Preserve frozen rounding, saturation, tile masks, operation order and externally visible ABI semantics. Rerun exact regressions after scheduling or arithmetic changes.

Update architecture/schedule.py or a separately versioned model to describe actual request latency, overlap, array tails, nonlinear/divider latency, compaction and control. Predict held-out configurations; demonstrate approximately 10–15% agreement required by the plan. Multiplying all old estimates by a fitted constant is not independent validation. Current bubble, memory-wait and nonlinear-wait counts overlap and must not be summed into a waterfall.

### Place and route the revised candidate

```bash
vivado -mode batch \
  -source rtl/platform/vivado_ooc_candidate.tcl \
  -tclargs eat_platform_wrapper xck26-sfvc784-2LV-c \
  ABSOLUTE_PYTHON_PATH route
```

Retain routed_utilization.rpt, routed_timing.rpt, route_status.rpt, routed_drc.rpt, routed_methodology.rpt and routed.dcp. Inspect setup/hold slack, unconstrained paths, clock relationships and DRC findings. Out-of-context closure still excludes final PS/DMA/board integration.

**Done when: prediction error meets the declared tolerance, timing closes at the recorded clock, resource costs are attributable by block, and exact numerical tests remain green. If a gate fails, use the Word plan fallback and disclose it.**

## 5 Build the board system and host driver

eat_platform_wrapper is the implemented single-clock PL peripheral. It does not supply a generated Zynq PS/DDR/MIO board design or a production board driver. Create and retain the Vivado block design, platform wrapper, constraints and host software needed for actual execution.

### Connect and validate the system

Connect the PS AXI control master to the peripheral AXI-Lite interface. Connect the DMA MM2S stream to its 128-bit input and the output stream to DMA S2MM. Connect completion interrupt, PS memory paths, clock and reset consistently. Generate and validate the block design and wrapper, assign the AXI base address, and implement the complete system before generating the bitstream and exporting hardware/software handoff files.

The peripheral assumes one common clock and synchronizes reset release. If integration introduces clock crossings, add and verify the appropriate bridges. For the selected host software, implement DMA allocation, cache maintenance/coherency, transfer lengths, timeout handling, interrupt/polling and reset recovery. Record OS, boot image and tool compatibility. Validate a simple transfer/control transaction before complete inference.

### Implement ABI2 using the existing executable example

Read rtl/docs/HOST_PROGRAMMING.md and rtl/tb/tb_platform_system.vhd. The bench is a protocol example, not a deployed driver. A minimal host transaction is:

1. Read ABI_VERSION 0x14 = 0x00020000 and NUMERIC_VERSION 0x18 = 2. Configure idle MODE, workload/bank and the expected image identity.

2. Use rtl/scripts/export_image.py with a catalog-selected frozen export. Verify file hashes on the host; hardware compares an opaque identity and does not calculate SHA-256.

3. Load the 164-word PROFILE first, then nonempty constant regions with exact lengths and final TLAST. Arm the bank and check resident identity. The top implements banks 0–2.

4. Load 1,152 signed INT8 bytes for HAR or 2,560 for speech, using the export preprocessing and exponent. Set a fresh inference ID and start only with a matching armed model/frame.

5. Receive 6 HAR or 35 speech logits. Values are signed 24-bit Q12 sign-extended into 32-bit words, packed low lanes first into the 128-bit output stream.

6. Check every integer logit, TKEEP/TLAST, error status and final-output completion. Read SNAPSHOT_ID before low/high counter halves to obtain a coherent completed snapshot.

On a malformed packet, allow ingress to drain through TLAST. If TLAST never arrives, reset the peripheral and DMA path. Load/framing errors invalidate bank metadata; reload and arm before retrying. Reset retains RAM bits but invalidates model/input validity. Never infer valid residency from retained bits.

**Done when: a complete board build boots, a frozen saved example matches every golden logit, repeated inference and reset recovery work, and the build/driver procedure is reproducible.**

## 6 Validate on board and measure controlled results

### Expand beyond the saved examples

Run both workloads and all three modes on the official test partitions. Preserve preprocessing, input order, model/seed selection and integer reference. The default independent family has 18 exported settings across two workloads, three modes and three seeds. Include the shared HAR family only when its claims are evaluated. Record logits and per-layer debug errors where available, maximum integer errors and changed predictions separately from task accuracy.

### Build and measure the required board ablations

| Configuration | Controlled change |
| --- | --- |
| a | Dense static W8A8 build from the same RTL |
| b | Static W4A8 |
| c | W4A8 plus token-group dropping |
| d | Configuration c plus RTS |
| e | Configuration d plus early exit |

These five configurations are required on hardware by Section 14.8. They are not all provided as independent board builds today; define exports/build controls and verify each. Runtime Quality mode is dense execution inside adaptive hardware and is not sufficient evidence of a separately built static baseline. Also run the same-board Cortex-A53 INT8 baseline. Evaluate exact/approximate nonlinear functions in the integer model and streaming/materialized attention in the cycle model, in RTL where feasible.

### Collect actual measurement traces

Follow host/measurement_protocol.md. Warm up and record the count. Use batch one, identical input ordering and declared clocks. Record accelerator-only, transfer/preprocessing and end-to-end timing boundaries separately. Acquire timestamped whole-board power covering the complete inference window, with instrument identity, sampling rate, resolution and calibration. Use at least five independent windows per configuration and retain inconclusive trials. Measure rather than assume a power sensor is available.

Primary joules per inference are integrated whole-board energy divided by completed inferences. Report median and p95 latency, average watts, confidence intervals from independent windows and measurement limitations. Keep idle-subtracted figures separate. Record useful executed operations, not nominal dense operations for every adaptive run.

```bash
.venv/bin/python -m host.analyze_measurements \
  --power POWER.csv --timing TIMING.csv \
  --metadata METADATA.json --output ANALYSIS.json
```

POWER.csv uses timestamp_seconds,watts; TIMING.csv uses start_seconds,finish_seconds. Metadata includes batch_size, power_boundary, clock_hz, git_commit, bitstream_sha256, configuration_sha256, instrument, instrument_resolution_w and warmup_inferences. The parser rejects uncovered windows; a single run does not supply repeat-trial confidence intervals.

**Done when: full-test board agreement, all required baselines/ablations, raw traces, repeat-run uncertainty and traceable analysis outputs exist.**

## 7 Finish the paper and transfer reproducible evidence

### Close the plan gates with evidence

Interface agreement is complete under ABI2; broad G1/G2 completion has not been established. The lead must review novelty, scope, accuracy/numerical alignment, board/power bring-up and feasible latency/resources against Section 14.7. G3 needs a timed implemented design; G4 needs full-test board correctness and measurements; G5 freezes supported results; G6 requires review and the Section 17 checklist. Record explicit decisions and any fallback instead of treating elapsed weeks as gate passage.

Refresh the nearest-work and patent/novelty matrix before claiming RTS novelty. The repository already records a close FPGA pruning/fusion precedent. Paper 1 uses short sequences and on-chip weights, so DDR traffic reduction should not be a headline claim. Keep trained HC-ACP, head gating, INT2/W4A4 and broader sparsity/vision extensions in their deferred scope unless the plan is deliberately revised.

### Produce the minimum evidence package

- Accuracy mean and standard deviation over three seeds, per workload/mode and numerical stage, including on-board results.

- Post-route LUT, FF, DSP, BRAM, URAM, Fmax and WNS, with RTS/controller and other block costs identified.

- Median/p95 latency, whole-board watts and joules for every mode, static dense and Cortex-A53 baselines; controlled ablation costs and benefits.

- Script-generated accuracy–energy Pareto, mechanism ablation, sequence sensitivity and utilization figures. Overlapping stall counters need an appropriate analysis, not a summed breakdown.

- Prior-FPGA comparisons with raw/normalized values and disclosed differences; limitations and negative results; two external-to-team mock reviews, authorship/CRediT and venue/institutional requirements.

### Keep the package reproducible

Archive each run with Git commit and dirty-state record, RTL/config/export/input hashes, tool versions, constraints, actual clock, reports/checkpoints/bitstream, host software and raw measurements. Preserve historical reports. Update paper/completion_checklist.md, paper/lab_notebook.md and the artifact manifest after accepted work; regenerate result tables with scripts. Reconcile all claims with the controlling Word plan before submission.

| Read next | Purpose |
| --- | --- |
| rtl/README.md and rtl/RTL_OUTLINE.md | Architecture, hierarchy and commands |
| rtl/docs/HOST_PROGRAMMING.md | Register ABI, packet order, counters and recovery |
| rtl/docs/TARGET_VALIDATION.md | Vivado and board handoff details |
| paper/rtl_results.md | Current numerical evidence and cycle-model failure |
| rtl/validation/implementation_v2/README.md | Exact archived coverage and reproduction commands |
| results/software_release_v1/catalog.json | Frozen model/export selection |
| paper/completion_checklist.md | Full remaining Paper 1 evidence requirements |

Transfer a documented snapshot, reproducible commands, raw measurements and analysis, unresolved issues with owners, and evidence-backed paper claims. AMD device confirmation is linked below.

[AMD KV260 platform tutorial and device identity](https://xilinx.github.io/Vitis-Tutorials/2022-1/build/html/docs/Vitis_Platform_Creation/Design_Tutorials/01-Edge-KV260/step4.html)
