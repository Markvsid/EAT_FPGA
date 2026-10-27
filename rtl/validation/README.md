# RTL evidence archive

Files directly in this directory record the original guarded skeleton at commit
80c18cb. They are historical structural evidence, not the current implementation.

`phase1/` records the first 38 functional implementations and ABI2 image audit.
Each regression report retains the exact tested source hashes. Functional checks
covered 222,964 scalar outputs across the reported tensor/vector/attention/gate/QKV
cases, plus primitive, service and routing scoreboards. Full encoder, target
Vivado mapping, timing and board equivalence were still incomplete at that checkpoint.

Generated stimuli, executables and netlists remain under ignored `rtl/build/`.
Reproduce checks with the tracked test drivers rather than treating an old pass
as proof for subsequently changed source.

`integration_v1/` is the first connected encoder/platform checkpoint. It predates
registered private reads, iterative-divider integration and complete diagnostic
counters. Its six golden encoder and repeated HAR Energy-Saver platform runs are
historical evidence; their cycle counts are not current-source results.

`implementation_v2/` records the final functional RTL checkpoint. The archive
script rejects stale tested-source fingerprints. Its full-model case lists,
explicit stress inputs, actual AXI/peripheral runs and diagnostic counts must be
read with the scope limits in [the RTL report](../../paper/rtl_results.md).
