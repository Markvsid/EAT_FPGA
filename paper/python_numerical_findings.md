# Numerical discrepancy findings for the Python evaluation

## Controlling requirements

Authority is `Report_Template/FPGA_Energy_Efficient_Transformer_Research_Plan_2-Month_Extended.docx`. Its requirements take priority over narrower repository plans. Relevant sections are:

- Section 14.7, Week 3: freeze numerical formats, extend the integer model to the full encoder and confirm prediction agreement with the fake-quantized PyTorch model on the full test set.
- Section 14.7, Week 4: run every test input through the integer model and retain reference outputs.
- Section 14.7, Week 6: report per-layer numerical errors and changed predictions against FP32 and fake-quantized models.
- Section 14.8, G2: W4A8 Balanced within about one percentage point of FP32 on HAR, integer/fake agreement on essentially all test predictions, resource/latency feasibility and engine/attention unit tests.
- Section 8 verification: deterministic vectors, checked accumulator overflow and counted intentional saturations, followed by RTL-to-Python comparisons. The arithmetic specification additionally makes rounding explicit.

The template does not assign a percentage threshold to “essentially all.” This study reports counts and agreement rates and does not invent a passing threshold. G2 is not declared passed. The evaluation freeze records unchanged settings for reproducible testing; it does not approve a hardware numerical contract.

## Why the two existing models differ

The existing training model is fake quantization around linear inputs and per-channel weights. Activation exponents come from the current tensor maximum, including batch composition. Its inputs, biases, residual additions, RMSNorm, attention scores/softmax and pooling retain floating-point arithmetic. Q/K/V are not separately restricted to calibrated INT8 operands in training.

The integer export instead uses 1,024 deterministic training windows to calibrate fixed activation exponents, quantizes the host input, rounds bias in accumulator units and uses Q24 output multipliers. It rounds and saturates residuals to signed24/Q12 state. It quantizes Q/K/V operands, uses a Q30 reciprocal-square-root table, a rounded epsilon of168 in Q24, rounded Q12 PWL knots, Q8 exponential table addresses and Q20 exponential values. Online softmax rounds partial results after each eight-key tile. Summaries and mean pooling use integer nearest-even division. These operations do not have the same numerical contract as the existing training forward pass.

Consequently, disagreement is expected and is not by itself evidence of an arithmetic bug. Conversely, similar task accuracy does not establish equivalent predictions. We retain the original trained model and report both implementations honestly.

## Validation-only sequential counterfactual study

For each workload and mode, seed17 is evaluated on256 evenly spaced validation examples. No test examples were used in this diagnostic, and no weights, exponents or lookup tables were changed. Stages:

1. Original dynamic fake quantization.
2. Quantize/dequantize the host input, retaining the original dynamic fake quantization inside the network.
3. Additionally replace linear input quantization with existing fixed export scales and reconstruct weights from exported integer weights and recorded channel scales; biases and other arithmetic remain floating point.
4. Additionally quantize/dequantize attention Q/K/V using existing export exponents.
5. Existing full integer implementation.

Stages3–4 are floating-point diagnostic counterfactuals, not independently implemented bit-accurate models. Stage5 also differs in bias, multiplier, nonlinear, residual and pooling arithmetic. The effects interact, so changes between stages are not additive causal attribution.

| Checkpoint | Input only changed | Fixed linears changed | Fixed linears and QKV changed | Full integer changed |
| --- | --- | --- | --- | --- |
| har_quality_seed17 | 2 /256 | 1 /256 | 1 /256 | 1 /256 |
| har_balanced_seed17 | 3 /256 | 3 /256 | 4 /256 | 3 /256 |
| har_energy_saver_seed17 | 2 /256 | 1 /256 | 1 /256 | 2 /256 |
| speech_quality_seed17 | 2 /256 | 2 /256 | 3 /256 | 5 /256 |
| speech_balanced_seed17 | 1 /256 | 2 /256 | 3 /256 | 2 /256 |
| speech_energy_saver_seed17 | 3 /256 | 2 /256 | 2 /256 | 2 /256 |

All six diagnostic subsets have zero input clipping and zero counted internal saturations. Therefore saturation does not explain the prediction changes observed in these subsets. Input quantization alone changes1–3 predictions per256; the complete integer model changes1–5. Later stages can reverse earlier changes, which rules out treating these counts as independent error contributions. Findings are limited to seed17 and these validation subsets; the complete full-test comparison is reported separately.

## Full test numerical evidence

`paper/python_test_results.md` gives full-test agreement counts by mode and workload, aggregated over three seeds, and distinguishes original FP32 training, matched fine-tuning FP32 controls, fake quantization and integer inference. Every quantized test run also evaluates the same fine-tuned checkpoint with linear fake quantization disabled while retaining its token/depth mode. This precision counterfactual is explicitly labeled and must not be presented as an independently trained FP32 baseline.

Per-run metrics include input clipping, internal saturations, final logit errors, group-selection changes and per-layer maximum absolute real-valued error. Q12 integers are divided by4096 for comparison to floating activations. This is not an absolute integer LSB comparison against a floating-point model. Later token rows are excluded from intermediate comparisons when retained group identities differ, because positional row comparison would be semantically invalid. First-input and worst-final-logit-error integer vectors are retained. All final test logits and labels are saved, enabling reconstruction of outputs and confusion matrices.

## Token selection sensitivity after the full test comparison

The full-test report revealed much more frequent changes in selected HAR groups than in final predictions. For independent HAR modes, Balanced changes group identities on3,424/8,841 evaluations (38.7 percent), and Energy-Saver on3,939/8,841 (44.6 percent). Speech changes are498/33,015 (1.5 percent) and2,660/33,015 (8.1 percent), respectively. A selected-group change means at least one retained group differs; it is not a count of individual tokens.

This prompted an additional exploratory validation-only diagnosis after test evaluation, with256 evenly spaced validation windows per workload, both independent adaptive modes, and all three seeds. It does not change any frozen model or reported test result. `results/python_gate_diagnostics.py` and `results/python_study/gate_diagnostics_validation.json` preserve its protocol and source checksum.

| Checkpoint | Group choices changed /256 | Integer cutoff ties /256 | Median floating cutoff gap | Mean maximum group-score error |
| --- | --- | --- | --- | --- |
| har_balanced_seed17 | 109 | 1 | 0.02522 | 0.09928 |
| har_balanced_seed29 | 82 | 4 | 0.03817 | 0.12313 |
| har_balanced_seed43 | 101 | 1 | 0.03396 | 0.10427 |
| har_energy_saver_seed17 | 132 | 0 | 0.01923 | 0.09933 |
| har_energy_saver_seed29 | 96 | 0 | 0.03471 | 0.10838 |
| har_energy_saver_seed43 | 126 | 2 | 0.02308 | 0.10737 |
| speech_balanced_seed17 | 2 | 0 | 1.90206 | 0.13793 |
| speech_balanced_seed29 | 2 | 0 | 1.67979 | 0.16473 |
| speech_balanced_seed43 | 2 | 0 | 1.78277 | 0.15628 |
| speech_energy_saver_seed17 | 35 | 0 | 0.20705 | 0.10825 |
| speech_energy_saver_seed29 | 16 | 0 | 0.33570 | 0.11473 |
| speech_energy_saver_seed43 | 22 | 0 | 0.23883 | 0.10611 |

No diagnostic example has all eight integer group scores equal. Integer cutoff ties occur on only0–4/256 examples in each HAR run and zero speech examples. Tie handling therefore does not explain most observed group changes. HAR floating cutoff margins are small relative to the observed group-score perturbations, consistent with sensitive top-k decisions. Speech Balanced has much larger cutoff margins and fewer changed choices. These observations combine numerical changes upstream of and inside the scorer; they do not isolate a single arithmetic operation as the cause.

Final classification agreement alone therefore understates changes in the adaptive execution path. Future numerical closure should check selected group identities and summary outputs as well as logits. Scorer sensitivity should be assessed during training/validation when aligning the quantization contract. The present study preserves stable chronological tie handling and reports the instability without tuning on the observed test results.

## Resolution and remaining work

This evaluation documents the discrepancy rather than silently replacing the trained forward pass or claiming exact agreement. Existing weights, training history, training-only calibration and numeric exports remain unchanged. No test-driven numerical tuning is performed.

Before a future G2 freeze, the training forward path should model the intended fixed-scale input/linear and QKV quantization, bias and requantization rounding, nonlinear approximations, residual precision and pooling/summary arithmetic. Any additional QAT should use training data and select checkpoints on validation data. An independent implementation should then check module and layer outputs against the integer reference. New results on the now-observed test sets must be disclosed as subsequent evaluations, not another untouched-test claim. The hardware portions of G2 and RTL/board equivalence remain separate outstanding requirements.

## Reproduction and provenance

`golden/discrepancy_study.py` created `results/python_study/discrepancy_validation.json` before the test plan freeze. The frozen plan records its checksum plus the controlling template, checkpoint, export, prepared test data and inference-source checksums. No downloaded pretrained weights were used. All existing models were trained locally and then fine-tuned as documented in the training manifests.

## Subsequent aligned training study

The proposed alignment work is implemented separately in `model/aligned.py` and
`model/aligned_arithmetic.py`, with independent PyTorch arithmetic and explicit
surrogate gradients. The original dynamic fake-quantized forward and this
diagnostic history are preserved. Full results are in
[Aligned numerical results](aligned_numerics_results.md).

The new study completes 18 fine-tuning settings and exact comparisons over all
validation and subsequent test examples, with zero error at every recorded
intermediate, logit and group choice. This agreement applies to the new training
contract; it does not retroactively change the legacy discrepancy counts above.
Four speech settings select updated weights, while 14 retain their starting
checkpoints. No consistent test accuracy improvement is observed. Test sets were
previously observed and are disclosed as such. Global G2 still requires hardware
feasibility/verification, and shared-weight alignment is outside this study.
