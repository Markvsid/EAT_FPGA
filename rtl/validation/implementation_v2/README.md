# Final functional RTL evidence

This checkpoint contains 48 implemented entities and five packages. Reports retain
tested-source hashes; `evidence_index.json` fingerprints the archived reports and
current RTL/test sources. Complete core/platform logs are under `logs/`.
Historical `phase1/` and `integration_v1/` passes apply to their recorded versions.

The ten core cases cover six independent-family saved examples (seed 17,
HAR/Speech × all three modes), HAR Energy-Saver maximum/minimum/checkerboard
inputs, and Speech Energy-Saver checkerboard input. There are 176 exact checked
core logits. Platform cases run HAR Energy-Saver twice, HAR Balanced once and
Speech Quality once, checking 53 additional logits through actual AXI loading,
resident memory, control, framing and output serialization. No full-dataset RTL
or FPGA inference accuracy is implied by these selected cases.

## Reproduce the final coverage

From the repository root, with its Python environment and GHDL available:

```sh
make -C rtl check
make -C rtl functional
make -C rtl synthesis-frontend
make -C rtl synthesis-integration
.venv/bin/python -m pytest -q
# Default core coverage: six golden examples plus HAR maximum/checkerboard.
.venv/bin/python rtl/scripts/test_core.py
.venv/bin/python rtl/scripts/test_core.py --case har_energy_saver_seed17 \
  --input-pattern minimum --build-name core_minimum
.venv/bin/python rtl/scripts/test_core.py --case speech_energy_saver_seed17 \
  --input-pattern checkerboard --build-name core_speech_stress
.venv/bin/python rtl/scripts/test_system.py --case har_energy_saver_seed17 \
  --repeat 2 --build-name system_energy
.venv/bin/python rtl/scripts/test_system.py --case har_balanced_seed17 \
  --build-name system_balanced
.venv/bin/python rtl/scripts/test_system.py --case speech_quality_seed17 \
  --build-name system_speech
```

The archived local run isolated each core case in its own build directory for
concurrent execution; numerical coverage is the same. To refresh this archive
from the default/reproduction directory names above:

```sh
.venv/bin/python rtl/scripts/archive_validation.py \
  --core-build core --core-build core_minimum --core-build core_speech_stress \
  --system-build system_energy --system-build system_balanced --system-build system_speech
.venv/bin/python rtl/scripts/report_results.py
```

The archive command rejects stale tested-source fingerprints. Check that build
directories contain only the desired cases before publishing a refreshed report.
GHDL primitive/integration netlist generation is distinct from Vivado resource
mapping, routed timing and board evidence. Bench clock periods are simulation
stimulus, not measured Fmax. Counter categories overlap; see the
[host counter definitions](../../docs/HOST_PROGRAMMING.md).

The original schedule estimates are preserved. Their discrepancy against RTL is
reported in [the paper evidence](../../../paper/rtl_results.md) and
`results/rtl_schedule_comparison.json`. No calibrated timing or energy claim is
made. See [the physical handoff](../../docs/TARGET_VALIDATION.md) for remaining
Vivado/board work.
