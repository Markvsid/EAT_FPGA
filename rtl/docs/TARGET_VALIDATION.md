# Physical implementation handoff

The user-approved ABI2 and functional RTL are implemented. The controlling Word
plan's hardware evidence remains required. This handoff contains commands to run
once the actual Vivado version/device/board setup is supplied; none has been run
with Vivado in the current environment.

## Target synthesis and routing

From the repository root, using the confirmed Vivado part and Python environment:

```sh
vivado -mode batch -source rtl/platform/vivado_ooc_candidate.tcl \
  -tclargs eat_platform_wrapper CONFIRMED_PART ABSOLUTE_PYTHON_PATH route
```

The optional `route` argument runs optimization, placement, physical optimization
and routing after synthesis. Without it, the script reports synthesis only.
Outputs are isolated under `rtl/build/vivado/eat_platform_wrapper/` and include
metadata, hierarchical resources, RAM mapping, timing, DRC/methodology and DCPs.
The 6.667 ns clock is a candidate 150 MHz target. A generated OOC report is not
a completed board design and has no assigned PS base address, I/O timing or pins.
Check tool-version support for report commands on the actual installation.

Inspect the compact resident RAM, per-lane activation memories, port inference,
BRAM/URAM fragmentation, DSP mapping and combinational paths before accepting
resource fit. GHDL recognizes resident/input RAMs and emits a complete netlist;
it does not certify Vivado mapping of the two-dimensional banked activation
arrays. Count only instantiated hierarchy resources, rather than adding default
capacities from every standalone buffer entity in the inventory.

## Performance development

The functional service issues one scalar parameter request at a time. The shared
8×8 MAC array waits while activation and per-column weights are fetched; bias and
requantization also serialize. W4 reduces stored bytes but introduces no DSP
subword packing or guaranteed twofold throughput improvement. The current
analytical schedule assumes much greater bandwidth/overlap and is not calibrated.

Use the actual memory transaction schedule and measured counter definitions to
update prediction. Preserve the original estimates and compare against held-out
configurations to satisfy the template's approximately 10–15 percent requirement.
If cycle reduction is needed, investigate bank-wide operand fetch/caching and
overlap while maintaining the integer round/clamp boundaries. Re-run exact RTL
regressions after scheduling changes. Diagnostic stall categories overlap and
cannot be summed into a waterfall or interpreted as a complete bottleneck split.

## Board evidence

Connect the generated PS/AXI DMA design to the common-clock peripheral and reset
synchronizer. Assign the confirmed AXI-Lite base address and compatible clock/reset
relations. Use the [host sequence](HOST_PROGRAMMING.md) to load verified images,
arm banks and transfer preprocessed inputs; check every integer logit before
accuracy or energy measurement. Board recovery must reset the DMA path as well
as the peripheral when malformed input cannot be drained through TLAST.

Then collect the plan's full-test board agreement, same-device dense/adaptive
comparison, Arm baseline, median/p95 latency, whole-board watts and joules,
controlled precision/drop/RTS/depth ablations, resource and routed timing tables,
and required plots. The functional Quality mode is dense W8 execution in the
same adaptive RTL. Distinguish any separately synthesized dense-only baseline
from that runtime baseline. Keep loading versus steady inference and whole-board
versus idle-subtracted energy boundaries explicit.

Novelty/related-work/patent review, independent reviewers, authorship and venue
requirements remain separate paper gates. No simulated cycle count establishes
an energy-efficiency result.
