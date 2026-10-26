# EAT FPGA Lite VHDL outline and skeleton

**Status: functional subsystems; full accelerator integration remains incomplete.**
There are 38 implemented entities and 15 remaining skeletons, plus four packages.
The compute path has exact primitive, tensor, vector, streaming-attention, QKV
and connected RTS-gate regressions. No connected full encoder or FPGA inference
is claimed. See [current implementation status](IMPLEMENTATION_STATUS.md).

The user agreed to [integration contract v2](docs/INTEGRATION_CONTRACT_V2.md) on
2026-10-26. Its typed model images pass reconstruction audits for all 27 frozen
exports. Broader hardware G1/G2 requirements remain open.

## Review these first

- [RTL outline and full module inventory](RTL_OUTLINE.md)
- [Proposed interfaces and register map](docs/INTERFACES.md)
- [Verification and implementation milestones](docs/VERIFICATION.md)
- [Machine-readable module and port inventory](design_inventory.json)
- [Candidate RTL configuration](config/rtl_candidate.json)

Remaining skeletons have an explicitly named `stub` architecture.
Stubs hold ready/valid outputs low and report `ERR_STUB` where status is exposed.
They never accept a command or return dummy inference results. By default they
fail simulation at time zero. `G_ALLOW_STUB_SIM => true` is only for structural
inspection. The supplied synthesis entry point refuses any reachable stub.
Functional blocks are connected within tensor/vector/gate subsystems. The encoder
and host/platform hierarchy is not wired yet.

## Run structural and functional checks

With the repository Python environment and GHDL installed:

```sh
make -C rtl check
make -C rtl functional
make -C rtl synthesis-frontend
```

This checks generated constants, all port declarations, compile-order inventory,
export boundary widths, analysis and elaboration of every entity, inert stub
behavior, and expected failure when a stub is simulated without explicit opt-in.
The structural command does not establish arithmetic correctness. `functional`
runs exact numerical and stalled-channel scoreboards. `synthesis-frontend`
generates GHDL netlists for 13 primitive units; it does not run Vivado target
mapping, physical banking, routed timing or board tests.

```sh
# Expected to fail while the top or any dependency is still a skeleton:
make -C rtl synth-check

# Regenerate only constants or structural test benches after a reviewed change:
.venv/bin/python rtl/scripts/emit_config.py
.venv/bin/python rtl/scripts/emit_smoke_tb.py
```

Entity files are ordinary editable VHDL. Update their inventory entries when
changing ports; the checker rejects divergence. Do not mark a module implemented
merely to bypass a gate. The compile list is `sources.f`. Build products live in
ignored `rtl/build/`; no bitstream is produced.

## Use the software golden cases

```sh
.venv/bin/python rtl/scripts/export_vectors.py \
  --vectors results/alignment_study/test/har_balanced_seed17/golden_vectors.npz \
  --export results/alignment_study/exports/har_balanced_seed17 \
  --output rtl/build/vectors/har_balanced_seed17
```

The converter first replays the case using the separate integer reference, then
emits exact-width two's-complement scalar hex files, shapes and hashes. It checks
hex round trips and refuses lossy narrowing. These are boundary test vectors,
not proof that the skeleton computes anything. Fine-grained exp/rowmax/normalizer
unit vectors still need dedicated arithmetic drivers as implementation begins.

## Toolchain

Local structural checks use GHDL 6.0.0, LLVM backend, on Apple Silicon. The
official portable archive was downloaded into ignored `.tools/ghdl/`; no global
tool installation was changed. `check_vhdl.py` finds a `ghdl` on PATH, accepts
`--ghdl /absolute/path`, or uses that local archive location. The verified archive
SHA256 is `9cb3ccc09ca95f37c88bb757b3da7415ce5efede51e136e0262c74f3f99c2245`.
See the [official release](https://github.com/ghdl/ghdl/releases/tag/v6.0.0) and
[installation documentation](https://ghdl.github.io/ghdl/getting.html).

GitHub CI separately installs GHDL on Ubuntu, records its version in the build
evidence, checks the skeleton and replays four representative golden cases. Local
check evidence is archived under `validation/`. Different compiler versions are
recorded rather than represented as one pinned cross-platform toolchain.

## Remaining integration work

Implement the agreed profile provider/loader, host ingress/control, sequencer and
core interconnect, then prove full-model RTL equivalence. Existing exact block
results do not substitute for that final regression. Target memory/resource
feasibility, timing, DMA recovery and board measurements remain outstanding.
