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
