# ABI2 host programming sequence

Authority: the user-approved [integration contract](INTEGRATION_CONTRACT_V2.md).
The peripheral has 32-bit AXI-Lite registers and 128-bit AXI streams on one clock.
A PS base address and vendor DMA/block design must be assigned in Vivado.
`tb_platform_system.vhd` is an executable example using the actual peripheral.

## Prepare and load a model

1. Build a typed image with `rtl/scripts/export_image.py` from a frozen export.
   Verify the export manifest/constants SHA and the generated image identity on
   the host. Hardware compares the opaque identity; it does not compute SHA-256.
2. Read ABI_VERSION at `0x14` (0x00020000) and NUMERIC_VERSION at `0x18` (2).
   Set MODE (`0x04`: 0 Quality, 1 Balanced, 2 Energy-Saver) and MODEL (`0x10`:
   workload in bit 0, bank in bits 7..4). The current top has banks 0..2.
3. Write EXPECTED_ID at `0x20..0x3c`, eight little-endian 32-bit digest words.
   Set INFERENCE_ID (`0x1c`). Configure only while idle.
4. Before each command, acknowledge sticky status/IRQ by writing CONTROL (`0x00`)
   bit 2. To load constants, set TRANSFER_KIND (`0x74`) to 1; LOAD_KIND (`0x68`)
   to the `constant_kind_t` ordinal; LOAD_ADDRESS (`0x60`) to the **word offset
   within that typed region**; LOAD_BYTES (`0x64`) to eight times the word count.
5. Load PROFILE first: kind 9, offset zero, exactly 164 words. Write CONTROL bit 1,
   then stream the data. The first 64-bit word occupies TDATA[63:0], the second
   TDATA[127:64]. Use TKEEP=0xffff for pairs or 0x00ff for a final single word;
   assert TLAST only on the final beat. Wait for IRQ and idle STATUS; check ERROR.
6. Load nonempty payload kinds 0..8 at offset zero using the profile's word counts
   (words 16..24). Each region is a separate command/packet. The loader checks
   order/length/typed values; a partial region does not arm a bank.
7. Clear status, write CONTROL bit 4 to arm the selected bank, wait for completion,
   and verify STATUS bit 3 plus LOADED_ID (`0x40..0x5c`) against EXPECTED_ID.

Logical bank/region address gaps are never streamed or allocated as RAM. The
compact resident memory reserves 164 words for the profile, then concatenates
actual payload counts. Payload lengths must fit the per-bank allocation. Reset
or a new profile word zero invalidates mapping metadata. Reloading a bank
invalidates its prior armed identity. No configuration or model mutation is
accepted while an inference is busy.

## Submit input and collect logits

1. Clear status. Set TRANSFER_KIND to 0, LOAD_ADDRESS to zero and LOAD_BYTES to
   1,152 for HAR or 2,560 for speech. LOAD_KIND is ignored for raw input. Write
   CONTROL bit 1 and send exactly one TLAST-framed packet of signed INT8 bytes.
   Earliest samples occupy the lowest byte lanes. Input preprocessing and exponent
   selection follow the chosen frozen export; the profile contains its Q12 shift.
2. Wait for successful transfer completion, clear status, set INFERENCE_ID, then
   write CONTROL bit 0. The model, workload, mode and raw-frame identity must agree.
3. Accept the output with AXIS ready/valid. It contains 6 HAR or 35 speech logits,
   in class order, sign-extended from signed 24-bit Q12 to 32 bits. Up to four
   logits occupy each 128-bit beat, low lanes first. TKEEP marks the valid bytes;
   TLAST marks the final beat. There is one packet per inference.
4. IRQ/done for inference occurs after the final output beat is accepted. A stalled
   output therefore delays completion. Wait for idle STATUS, check ERROR, then
   read SNAPSHOT_ID at `0x70` to freeze a coherent completed-inference snapshot.
   Counters are low/high 32-bit halves at `0x100+8*n`. Read SNAPSHOT_ID again to
   refresh the read snapshot. The previous completed snapshot survives a subsequent
   in-flight inference and aborted work does not replace it.
5. A successfully loaded raw frame may be reused with a new INFERENCE_ID and the
   same mode/workload/bank/identity. Change mode/bank only while idle and submit a
   matching input frame. Clear sticky status between commands.

STATUS bits are busy/done/error/bank-valid at 0/1/2/3. ERROR is the `error_t`
ordinal from `eat_types_pkg.vhd`. CONTROL bit 3 clears counters while idle.
Registers honor WSTRB; AW and W may arrive independently. Unsupported, unaligned,
read-only or busy writes receive SLVERR. Such rejected writes do not constitute
an accepted command or generate an inference result.

## Error and reset recovery

Malformed TKEEP, TLAST or transfer lengths produce errors; ingress drains a bad
packet through TLAST. Wait for draining to finish before clearing status and
sending a new command. If a source never sends TLAST after a malformed packet,
reset the peripheral and DMA path to recover framing. Load/framing errors flush
service state and invalidate bank metadata, so reload and arm the model before
retrying inference. Reset invalidates residency/input validity and pending
responses; RAM contents are retained but cannot be used as a valid model/frame.

The platform asynchronously asserts reset and releases it after two clocks.
The generated PS/DMA design must use a compatible reset/clock topology. Cross-clock
bridges, board pin assignments, Linux DMA allocation and cache maintenance are
platform integration responsibilities requiring the actual Vivado design.

## Counter definitions

Event ordinal is the counter index, with units in parentheses:

| Index | Event | Implemented observation |
| ---: | --- | --- |
| 0 | EV_CYCLE | Kernel-active clock cycles, including final output acceptance |
| 1 | EV_INFERENCE | Completed inferences in the snapshot (one) |
| 2 | EV_ACTIVE_MAC | Actual enabled tensor-array products plus attention dot/AV products |
| 3 | EV_BUBBLE | RUN cycles scheduled to the tensor engine with zero enabled tensor products |
| 4 | EV_MEMORY_STALL | Core input/parameter request blocked by ready, or response awaited without valid |
| 5 | EV_NONLINEAR_STALL | Scheduled norm/PWL/attention/pool RUN cycles without an output beat |
| 6 | EV_SATURATION | Saturated values at unique golden tensor/state boundaries |
| 7 | EV_INPUT_BYTE | Logical input bytes consumed by inference |
| 8 | EV_OUTPUT_BYTE | Logical logit bytes produced by inference |
| 9 | EV_RETAINED_TOKEN | Retained original tokens after the gate (32/24/16) |
| 10 | EV_SUMMARY_TOKEN | RTS summaries (0/2/4) |

Bubble, memory-wait and nonlinear-wait categories overlap and must not be summed
into a cycle waterfall. Nonlinear-wait includes setup, memory and iterative-divider
latency within the selected stage. Memory-wait excludes host DMA/model-loading
time and includes core profile/input reads. Input/output byte totals describe
the inference payload, including when a retained input frame is reused. Saturation
counts exclude recomputations of the same activation at multiple tensor tiles.
The core emits nine aggregate event records; cycle/completion are counted by the
peripheral counter service. Diagnostic counters use checked 32-bit aggregates;
the exposed completed snapshots are 64-bit.
