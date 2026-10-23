# Software evidence summary

All values below are validation results. For the subsequent frozen held-out test study, see [Python test results](python_test_results.md). No FPGA measurements exist.

## Training and software validation

| Workload | Configuration | Seeds | Batched selection accuracy percent | Batch 1 accuracy percent |
| --- | --- | --- | --- | --- |
| UCI HAR raw inertial signals | balanced | 17,29,43 | 94.293 ± 1.877 | 94.195 |
| UCI HAR raw inertial signals | energy_saver | 17,29,43 | 93.216 ± 1.335 | 93.338 |
| UCI HAR raw inertial signals | fp32_control | 17,29,43 | 93.338 ± 1.363 | 93.338 |
| UCI HAR raw inertial signals | fp32 | 17,29,43 | 92.261 ± 0.153 | 92.261 |
| UCI HAR raw inertial signals | quality | 17,29,43 | 93.681 ± 0.583 | 93.436 |
| Google Speech Commands v2 35 words | balanced | 17,29,43 | 91.931 ± 0.245 | 91.985 |
| Google Speech Commands v2 35 words | energy_saver | 17,29,43 | 91.464 ± 0.205 | 91.467 |
| Google Speech Commands v2 35 words | fp32_control | 17,29,43 | 93.057 ± 0.099 | 93.057 |
| Google Speech Commands v2 35 words | fp32 | 17,29,43 | 92.856 ± 0.063 | 92.856 |
| Google Speech Commands v2 35 words | quality | 17,29,43 | 93.094 ± 0.176 | 93.063 |

## Fixed-scale integer validation

Integer modes use explicit finite-width arithmetic and offline-calibrated fixed scales. A changed prediction is measured against batch-1 dynamic fake quantization, not RTL.

| Workload | Mode or family | Seeds | Integer accuracy percent | Changed predictions / compared windows |
| --- | --- | --- | --- | --- |
| UCI HAR raw inertial signals | balanced | 17,29,43 | 94.024 ± 1.967 | 47 / 4083 |
| UCI HAR raw inertial signals | energy_saver | 17,29,43 | 93.216 ± 1.479 | 41 / 4083 |
| UCI HAR raw inertial signals | quality | 17,29,43 | 93.534 ± 0.409 | 43 / 4083 |
| Google Speech Commands v2 35 words | balanced | 17,29,43 | 91.928 ± 0.153 | 287 / 29943 |
| Google Speech Commands v2 35 words | energy_saver | 17,29,43 | 91.511 ± 0.250 | 393 / 29943 |
| Google Speech Commands v2 35 words | quality | 17,29,43 | 93.043 ± 0.199 | 279 / 29943 |
| UCI HAR raw inertial signals | joint_balanced | 17,29,43 | 94.269 ± 1.256 | 42 / 4083 |
| UCI HAR raw inertial signals | joint_energy_saver | 17,29,43 | 91.967 ± 1.339 | 53 / 4083 |
| UCI HAR raw inertial signals | joint_quality | 17,29,43 | 94.146 ± 1.508 | 53 / 4083 |

## HAR ablations

Positive deltas favor the destination. Seed variation is not a confidence interval or significance test.

| From | To | Paired seeds | Mean accuracy delta in percentage points | Seed SD |
| --- | --- | --- | --- | --- |
| fp32_control | quality | 17,29,43 | 0.098 | 1.122 |
| quality | dense_w4 | 17,29,43 | 0.171 | 1.692 |
| dense_w4 | drop_keep6 | 17,29,43 | -0.563 | 0.930 |
| drop_keep6 | balanced | 17,29,43 | 1.151 | 0.852 |
| drop_keep4 | rts_keep4 | 17,29,43 | 1.004 | 1.188 |
| drop_keep5_matched20 | rts_keep4 | 17,29,43 | 0.980 | 0.998 |
| rts_keep4 | energy_saver | 17,29,43 | -0.024 | 0.185 |

With a fixed RTS-trained checkpoint and identical group decisions, summaries change validation accuracy by 0.147 percentage points on average across 3 seeds while adding two tokens. This counterfactual is separate from independently trained, matched-token-budget comparisons.

## Interpretation and remaining gates

The 2024 FPGA simultaneous-pruning design already fuses discarded tokens. A standalone summary-on-FPGA novelty claim is unsupported. Preserve RTS as a measured ablation and position a narrower hardware contribution only after implementation evidence.

Speech Energy-Saver has a larger loss than the original one-percentage-point primary-workload target. Report this limitation; do not claim equal quality across all modes and tasks.

G1/G2 remain incomplete globally: board transfer and power bring-up, review of interfaces/formats, and the final novelty audit are outstanding. RTL, synthesis, routed timing/resources, board equivalence, Arm measurements, energy curves, and independent review are required before submission.
