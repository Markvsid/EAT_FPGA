# Remaining Model Architecture Decisions

The proposal specifies the following foundation for the first-paper model:

- Four Transformer encoder blocks.
- Feature width of 128.
- Four attention heads.
- FFN expansion ratio of 2, giving a hidden width of 256.
- RMSNorm normalization.

Several model architecture decisions remain.

## 1. Tokenization and embedding

Decide how many sensor samples form each token, whether patches overlap, and how patches become feature vectors. These choices determine sequence length, temporal detail, and computation.

## 2. Positional information

Decide how the model represents token order so attention can distinguish when information occurred.

## 3. Classification output

Choose a classification token, mean pooling, or another method for combining final token representations into one activity prediction.

## 4. Token-gating locations

Decide whether token removal occurs before the encoder, between selected blocks, or at multiple boundaries. Earlier removal saves more computation but may discard information before its importance becomes clear.

## 5. Token-importance scoring

Choose a learned scorer or a defined statistic, and specify what information it uses. This determines which tokens survive and introduces additional computation.

## 6. Grouping and retention

Choose groups of 4 or 8 tokens and define how many groups each operating mode retains. These settings control the accuracy–computation tradeoff.

## 7. Residual Token Summary construction and handling

Define how summaries are formed, where they are inserted, how positional information is handled, and how later layers treat them. These choices determine what information survives token removal.

## 8. Activation function

Select the underlying activation and its piecewise-linear approximation. These affect FFN behavior and numerical requirements.

## 9. Early exit

Decide whether to include an early exit, where it occurs, and how its prediction and exit decision are produced. This determines whether some inputs can skip later blocks.

## 10. Execution-mode behavior

Define the precision, token retention, and depth settings for each operating mode. These settings establish the model variants that must be trained and evaluated.

## Decision order and status

Some decisions change the model architecture, while others specify its numerical or execution behavior. Both categories must be settled before the implementation is fully defined.

The first decisions needed for the dense baseline are tokenization, positional information, and the classification head. Token gating, summaries, and early exit then extend that baseline.

Mean pooling, gating before the first encoder block, magnitude-based token scoring, and arithmetic-mean summaries were suggested starting points in the later plan. They are not confirmed requirements from the original proposal or approved decisions from the supervisor.
