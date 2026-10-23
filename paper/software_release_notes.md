# Software release findings and comparison limits

The shared HAR family is numerically verified and reduces stored constant payload,
with a lower full-test mean for Energy-Saver than the independent family. Neither
family is robust to all tested perturbations. These are software results on
previously observed test data; hardware requirements remain open.

## Accuracy and storage

Three-seed mean accuracy on the previously observed full HAR test partition:

| Mode | Independent aligned | Shared aligned | Shared minus independent points |
| --- | --- | --- | --- |
| Quality | 93.474% | 93.360% | −0.113 |
| Balanced | 93.055% | 92.919% | −0.136 |
| Energy-Saver | 93.360% | 92.444% | −0.916 |

The shared model uses the same actual PyTorch parameter objects for all three
modes. FP32 parameter bytes per seed fall from 6,474,396 to 2,158,132: a two-thirds
reduction. This is a shadow-parameter count, not an FPGA memory measurement.
Distinct precision encodings and calibration constants remain necessary.

Deduplicated exported constant containers average approximately 1,245,781 bytes
for the independent HAR modes versus 997,056 for shared modes, about 20.0% less.
Weights are packed as W4/W8 and other constants retain signed64 containers. These
budgets exclude metadata, activation buffers, bank duplication, port constraints
and physical implementation overhead. They do not establish a physical fit,
clock frequency, energy reduction or external-memory traffic benefit.

## Training budget and selection differences

The comparison is not a controlled isolation of weight sharing. Both families
start from the earlier locally trained HAR baselines. Each independent mode then
received 30 fine-tuning epochs, whereas the shared family received 30 total
fine-tuning epochs with a uniformly sampled mode per minibatch. Thus the three
independent modes received 90 epochs in aggregate, and the shared modes did not
each receive 30 dedicated epochs. Independent checkpoints were selected by their
own validation scores; joint selection used mean validation accuracy across modes.

The later aligned fine-tuning study ran three additional HAR epochs per
independent mode but retained the starting checkpoint for all nine HAR settings.
This release adds no training to either family. Consequently, the table describes
the existing trained systems and their storage tradeoff; it does not prove that
sharing alone causes the observed accuracy differences. There are only three
seeds, and their standard deviations are reported in the generated release report.
No statistical significance claim is made.

## Robustness

All 27 final aligned settings were tested on the exact predefined inputs: 120
HAR windows and 350 speech clips, with four conditions per setting. Both aligned
PyTorch and the separate integer model match exactly at every recorded point
under all perturbations.

Agreement does not establish resilience. Under missing gyro channels, independent
HAR Quality/Balanced/Energy-Saver average 84.44%/83.89%/79.44%; shared modes average
83.89%/83.33%/83.61%. Under 10 dB waveform white noise, speech Quality/Balanced/
Energy-Saver average 67.24%/63.43%/61.90%, compared with clean subset accuracies
91.05%/88.95%/89.52%. The matched FP32 control also falls to 67.90% under 10 dB noise.

The small class-balanced subset can reverse rankings from the full test set.
For example, shared Energy-Saver has a higher clean HAR subset mean than the
independent mode despite a lower full-test mean. Do not select a family or claim
universal robustness from this subset. Real sensor/device shift, environmental
noise and recovery mechanisms have not been established. Weak-noise improvements
on a few HAR examples are descriptive, not proof of a denoising benefit.

## Frozen release scope

The catalog publishes all three seeds rather than selecting a favorable test seed.
The previously selected independent models remain the default for continuity;
shared HAR is an additional option. This choice was recorded in the release plan
before the new comparisons. Shared Speech Commands models are not included.

Full shared verification adds 12,249 validation and 26,523 subsequent test example
evaluations. Robustness adds 21,240 example evaluations over 108 conditions. All
60,012 comparisons have zero intermediate error and no prediction/group-choice
mismatches. Counts repeat samples across modes and seeds, not independent unique
observations. The original studies and their legacy numerical findings remain
preserved.

The software release is complete for this declared matrix. Further accuracy or
noise-aware training requires a separately declared, validation-driven experiment;
these already-observed test sets must retain that disclosure. Paper 1 still needs
RTL, implementation feasibility, physical timing/resources, board equivalence,
latency/power/energy and CPU baselines, fair prior-hardware comparison and review.

For the complete tables, artifact paths and reproduction command, see
[the generated release report](software_release_results.md). The frozen catalog
and evidence live under `results/software_release_v1/`.
