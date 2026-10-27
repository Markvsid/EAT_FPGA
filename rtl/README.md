# EAT FPGA Lite VHDL implementation

There are 48 functional VHDL-2008 entities and five packages, with no remaining
stubs. The design connects a shared 8×8 tensor engine, row-vector operations,
tiled online attention, stable group selection/RTS compaction, encoder schedule,
compact model RAM and AXI host interface. No logits are supplied by software at
runtime. The testbench supplies input data and parameters and checks the results
against the separate integer reference.

The user approved [integration contract v2](docs/INTEGRATION_CONTRACT_V2.md) on
2026-10-26. Broader template G1/G2 gates and target hardware validation remain open.

- [Hierarchy and implementation outline](RTL_OUTLINE.md)
- [Implementation inventory](IMPLEMENTATION_STATUS.md)
- [Interfaces](docs/INTERFACES.md) and [host sequence](docs/HOST_PROGRAMMING.md)
- [Verification scope](docs/VERIFICATION.md) and [archived evidence](validation/README.md)
- [Consolidated skeleton boundaries](docs/CONSOLIDATED_MODULES.md)

## Reproduce

```sh
make -C rtl check                 # generated packages, inventory, numeric audit, analyze/elaborate
make -C rtl functional            # exact unit, subsystem, image and host protocol suites
make -C rtl integration           # full encoder + actual loaded AXI peripheral simulations
make -C rtl synthesis-frontend    # primitive GHDL netlist generation
make -C rtl synthesis-integration # connected hierarchy GHDL netlist generation
make -C rtl synth-check           # verify implemented hierarchy; does not invoke synthesis
```

Full inference simulations take substantially longer than unit tests. Run one case
with `.venv/bin/python rtl/scripts/test_core.py --case har_energy_saver_seed17`.
Use `--input-pattern maximum`, `minimum` or `checkerboard` for independent stress
inputs. `test_system.py --case har_energy_saver_seed17 --repeat 2` tests model
loading, inference, retained input reuse, snapshots and reset through the real
platform wrapper. Give concurrent system jobs different `--build-name` values.
Build products, generated stimuli and executables are ignored under `rtl/build/`.

`make functional` does not run full inference; `make integration` does. Report
claims must identify the selected cases and source hashes. Saved-example RTL
agreement does not establish full-dataset RTL accuracy or board equivalence.

Entity files are ordinary editable VHDL. Keep ports, dependencies, functional test
references and compile order synchronized in `design_inventory.json`/`sources.f`.
Generated configuration/image packages are checked with `make -C rtl generated`.
The original software numeric contract and frozen exports are preserved.

## Memory and pipeline choices

The top instantiates three compact resident banks, 90,112 64-bit words each:
2,162,688 bytes of allocated model RAM. Logical ABI region gaps consume no RAM.
The largest audited frozen payload including profile is 85,445 words. This is
an allocation calculation, not a placed BRAM/URAM utilization result. Per-bank
payload lengths define compact offsets; profile word zero/reset invalidates
mapping metadata. All payload reads require valid lengths and a loaded image.

Core activation reads and QKV reads are registered. Vector readers hold accepted
operands under stalls. RMS variance, pooling, RTS summaries and attention final
normalization reuse iterative division. Mutually exclusive stages arbitrate
activation writes. These choices require target synthesis and timing review.

## Toolchain

Local structural checks use GHDL 6.0.0, LLVM backend, on Apple Silicon. The
official portable archive was downloaded into ignored `.tools/ghdl/`; no global
tool installation was changed. `check_vhdl.py` finds a `ghdl` on PATH, accepts
`--ghdl /absolute/path`, or uses that local archive location. The verified archive
SHA256 is `9cb3ccc09ca95f37c88bb757b3da7415ce5efede51e136e0262c74f3f99c2245`.
See the [official release](https://github.com/ghdl/ghdl/releases/tag/v6.0.0) and
[installation documentation](https://ghdl.github.io/ghdl/getting.html).

GitHub CI separately installs GHDL on Ubuntu, records its version in the build
evidence, checks all implemented entities, and runs subsystem, full-model and
platform inference jobs. Local
check evidence is archived under `validation/`. Different compiler versions are
recorded rather than represented as one pinned cross-platform toolchain.

## Remaining target work

Confirm the exact Vivado tool/device/board setup, run target synthesis and inspect
banked activation RAM/DSP inference. GHDL netlist generation passes for the full
platform, but does not validate the intended target RAM mapping. Place and route,
calibrate the analytical schedule, connect the vendor PS/DMA design and validate
board outputs, latency and power. No board or energy result is claimed.
