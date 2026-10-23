# Current software evidence

Generated from completed run logs. Validation only; no board measurements.

| Workload | Experiment | Seeds | Run epochs | Selection validation accuracy percent | Batch 1 validation accuracy percent | Macro F1 | Fine tuned |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UCI HAR raw inertial signals | balanced | 17,29,43 | 30 | 94.293 ± 1.877 | 94.195 (n=3 seeds) | 0.94297 | True |
| UCI HAR raw inertial signals | dense_w4 | 17,29,43 | 30 | 93.681 ± 1.695 | 93.608 (n=3 seeds) | 0.93724 | True |
| UCI HAR raw inertial signals | drop_keep4 | 17,29,43 | 30 | 92.579 ± 1.029 | 92.359 (n=3 seeds) | 0.92317 | True |
| UCI HAR raw inertial signals | drop_keep5_matched20 | 17,29,43 | 30 | 92.652 ± 1.306 | 92.383 (n=3 seeds) | 0.92391 | True |
| UCI HAR raw inertial signals | drop_keep6 | 17,29,43 | 30 | 93.265 ± 1.105 | 93.044 (n=3 seeds) | 0.93043 | True |
| UCI HAR raw inertial signals | energy_saver | 17,29,43 | 30 | 93.216 ± 1.335 | 93.338 (n=3 seeds) | 0.93056 | True |
| UCI HAR raw inertial signals | fp32_control | 17,29,43 | 30 | 93.338 ± 1.363 | 93.338 (n=3 seeds) | 0.93243 | True |
| UCI HAR raw inertial signals | fp32 | 17,29,43 | 30 | 92.261 ± 0.153 | 92.261 (n=3 seeds) | 0.92079 | False |
| UCI HAR raw inertial signals | joint_mean_over_modes | 17,29,43 | 30 | 93.444 ± 1.459 | Pending | 0.93458 | True |
| UCI HAR raw inertial signals | quality | 17,29,43 | 30 | 93.681 ± 0.583 | 93.436 (n=3 seeds) | 0.93568 | True |
| UCI HAR raw inertial signals | rts_keep4 | 17,29,43 | 30 | 93.681 ± 1.616 | 93.363 (n=3 seeds) | 0.93556 | True |
| Google Speech Commands v2 35 words | balanced | 17,29,43 | 5 | 91.931 ± 0.245 | 91.985 (n=3 seeds) | 0.91251 | True |
| Google Speech Commands v2 35 words | energy_saver | 17,29,43 | 5 | 91.464 ± 0.205 | 91.467 (n=3 seeds) | 0.90618 | True |
| Google Speech Commands v2 35 words | fp32_control | 17,29,43 | 5 | 93.057 ± 0.099 | 93.057 (n=3 seeds) | 0.92315 | True |
| Google Speech Commands v2 35 words | fp32 | 17,29,43 | 30 | 92.856 ± 0.063 | 92.856 (n=3 seeds) | 0.92052 | False |
| Google Speech Commands v2 35 words | fp32 (one-epoch smoke) | 17 | 1 | 82.226 | 82.226 (n=1 seeds) | 0.80032 | False |
| Google Speech Commands v2 35 words | quality | 17,29,43 | 5 | 93.094 ± 0.176 | 93.063 (n=3 seeds) | 0.92349 | True |

## Integer reference candidates

Each row is one exported checkpoint evaluated on validation inputs. Original fake quantization uses dynamic scales; the reference uses fixed calibration scales. Numerical differences are not RTL equivalence.

| Export | Windows | Integer accuracy percent | Batch 1 fake accuracy percent | Changed predictions | Counted saturations |
| --- | --- | --- | --- | --- | --- |
| calibrated/har_balanced_seed17 | 1361 | 91.918 | 92.432 | 18 | 2 |
| calibrated/har_balanced_seed29 | 1361 | 95.812 | 95.885 | 16 | 2 |
| calibrated/har_balanced_seed43 | 1361 | 94.342 | 94.269 | 13 | 0 |
| calibrated/har_energy_saver_seed17 | 1361 | 91.844 | 91.991 | 16 | 1 |
| calibrated/har_energy_saver_seed29 | 1361 | 94.783 | 94.857 | 13 | 0 |
| calibrated/har_energy_saver_seed43 | 1361 | 93.020 | 93.167 | 12 | 2 |
| calibrated/har_quality_seed17 | 1361 | 93.167 | 93.240 | 11 | 0 |
| calibrated/har_quality_seed29 | 1361 | 93.975 | 93.755 | 15 | 0 |
| calibrated/har_quality_seed43 | 1361 | 93.461 | 93.314 | 17 | 0 |
| calibrated/speech_balanced_seed17 | 9981 | 91.985 | 92.135 | 105 | 8 |
| calibrated/speech_balanced_seed29 | 9981 | 92.045 | 91.995 | 88 | 0 |
| calibrated/speech_balanced_seed43 | 9981 | 91.754 | 91.824 | 94 | 34 |
| calibrated/speech_energy_saver_seed17 | 9981 | 91.784 | 91.734 | 127 | 2 |
| calibrated/speech_energy_saver_seed29 | 9981 | 91.454 | 91.404 | 127 | 1 |
| calibrated/speech_energy_saver_seed43 | 9981 | 91.293 | 91.263 | 139 | 8 |
| calibrated/speech_quality_seed17 | 9981 | 93.127 | 93.057 | 95 | 0 |
| calibrated/speech_quality_seed29 | 9981 | 93.187 | 93.237 | 92 | 0 |
| calibrated/speech_quality_seed43 | 9981 | 92.816 | 92.897 | 92 | 0 |
| ci_local_quality | 32 | 81.250 | 84.375 | 1 | 0 |
| har_balanced_seed17_lut_v3 | 1361 | 91.918 | 92.432 | 18 | 2 |
| har_balanced_seed17_v1 | 1361 | 92.065 | 92.432 | 18 | 2 |
| har_energy_saver_seed17_lut_v3 | 1361 | 91.844 | 91.991 | 16 | 1 |
| har_energy_saver_seed17_v1 | 1361 | 91.771 | 91.991 | 13 | 0 |
| har_quality_seed17_int8attention_v2 | 1361 | 93.167 | 93.240 | 11 | 0 |
| har_quality_seed17_lut_v3 | 1361 | 93.167 | 93.240 | 11 | 0 |
| har_quality_seed17_trace_study | 1361 | 93.167 | 93.240 | 11 | 0 |
| har_quality_seed17_v1 | 1361 | 93.020 | 93.240 | 11 | 0 |
| joint/har_joint_balanced_seed17 | 1361 | 93.093 | 93.240 | 14 | 0 |
| joint/har_joint_balanced_seed29 | 1361 | 95.591 | 95.371 | 13 | 15 |
| joint/har_joint_balanced_seed43 | 1361 | 94.122 | 94.048 | 15 | 1 |
| joint/har_joint_energy_saver_seed17 | 1361 | 90.522 | 90.669 | 13 | 0 |
| joint/har_joint_energy_saver_seed29 | 1361 | 93.167 | 93.681 | 26 | 0 |
| joint/har_joint_energy_saver_seed43 | 1361 | 92.212 | 91.771 | 14 | 0 |
| joint/har_joint_quality_seed17 | 1361 | 92.873 | 92.652 | 13 | 0 |
| joint/har_joint_quality_seed29 | 1361 | 95.812 | 95.665 | 12 | 0 |
| joint/har_joint_quality_seed43 | 1361 | 93.755 | 93.755 | 28 | 0 |
| sweeps/har_quality_seed17_exp16 | 1361 | 93.167 | 93.240 | 11 | 0 |

## Outstanding evidence

The subsequent frozen held-out evaluation is documented in [Python test results](python_test_results.md), separately from these validation tables. Hardware bring-up, RTL equivalence, synthesis, routed timing, resource utilization, measured latency/energy, and independent review are outstanding. Do not read software accuracy or schedule estimates as FPGA results.
