# Candidate accelerator interface contract

Status: proposed version 1, not agreed or frozen at G1/G2. This document enables
review of the software-to-hardware boundary; it does not describe an implemented
accelerator. The controlling plan prohibits RTL on unagreed interfaces.

## Host boundary

The host performs dataset preprocessing and temporal patch formation. It produces
one normalized, quantized signed-INT8 input window at the fixed input scale from
the export manifest. The accelerator performs embedding, positional addition,
the selected encoder path, scoring/compaction/RTS, normalization/activation,
pooling, and classification. End-to-end measurement includes host preprocessing,
input/output transfer, and accelerator work.

HAR input order is time-major then channel-major, 128 by 9 bytes. Speech input
order is frame-major then mel-channel-major, 64 by 40 bytes. The model/config and
export hashes select the matching channel, patch, scale, and label definitions.
The classifier emits six or 35 signed-Q12 logits in class order. A physical
AXI stream packing width and control-register addresses are not yet assigned.

## Logical block interfaces

Every block uses one clock, synchronous active-high reset, and ready/valid
transfer semantics. A producer must hold valid data and sideband metadata stable
while valid is high and ready is low. Reset clears valid state, partial sums,
inference state, and counters. It must not leave a partially completed inference
eligible for output. Whether weight memories persist through reset requires an
explicit final specification.

| Block | Logical inputs | Logical outputs | Completion boundary |
| --- | --- | --- | --- |
| Tensor engine | Matrix descriptor, activation stream, packed W4/W8 stream, bias/multiplier arrays | Q12 output stream and accumulator debug | Last actual output element accepted |
| Norm/activation | Q12 row stream, gamma or activation selector | Q12 row stream | Last feature of the row accepted |
| Online attention | Actual token count, Q/K/V scales, Q/K/V tiles | Q12 attention rows | Final tile and normalized value row accepted |
| Group scorer/selector | Contextualized Q12 tokens, retention count, group size | Selected group indices and scores | Complete group decision set registered |
| Compactor/RTS | Group decisions, token stream, scorer values | Chronological compacted stream and actual count | Last retained token or summary accepted |
| Residual/pooling | Actual-count Q12 streams | Q12 residual or pooled vector | Last valid element accepted |
| Mode controller | Idle-boundary mode request, export/config identity | Registered mode and layer/token bounds | Mode accepted only while inference is idle |
| Counters/output | Accepted inference events and stall events | Logits, completion status, counter snapshot | Snapshot committed with output completion |

## Tensor descriptors and tails

Descriptors carry actual rows, columns, reduction length, signed precision,
activation exponent, weight scale/multiplier identity, row-major layout, layer
identity, and inference identity. Padded lanes are disabled and never included
in Softmax, group scores, means, or classifier pooling. DMA alignment padding
must not alter actual counts. Invalid dimensions and unsupported modes produce
an error before execution rather than silently using dense work bounds.

At the current HAR/Speech token count, Quality retains 32 tokens; candidate
Balanced emits 26 after group summaries; Energy-Saver emits 20 and stops after
block two. The 26-token case has a partial tile for the proposed eight-row array.
Address generation and reduction validity must explicitly support that tail.

## Control and identity

A candidate logical control set contains model identity, numeric-format version,
configuration/export hash, loaded-weights identity, mode request, start, busy,
completion, error, actual input/output lengths, and counter reset/snapshot.
Mode changes during busy are rejected or deferred until idle; the final choice
must be uniform across reference, host, and RTL. An inference carries one
registered mode through completion.

Weight packing is defined by each export's `binary/layout.json`: output-channel
rows followed by input-channel columns; INT4 low nibble first. Other constants
currently use 64-bit containers and must be narrowed to the candidate numeric
formats before synthesis. Register/stream constants will be generated from the
versioned configuration after review rather than copied by hand.

## Verification obligations before implementation claims

Use the exported integer input, intermediate traces, and logits as golden data.
Test signed limits, zero inputs, equal group scores, one-token attention,
maximum dimensions, partial tiles, valid/ready stalls, reset during an inference,
and repeated idle-boundary mode changes. Check exact tensors and counters, not
just predicted labels. The cycle model must be calibrated against the resulting
RTL schedule. Physical bank conflicts, resource use, and timing remain unknown.
