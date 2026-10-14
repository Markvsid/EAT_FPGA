# Dataset protocols and attribution

## Human activity recognition

UCI Human Activity Recognition Using Smartphones, by Jorge Reyes-Ortiz, Davide
Anguita, Alessandro Ghio, Luca Oneto, and Xavier Parra, 2013.
Primary dataset record: https://doi.org/10.24432/C54S4K
License: CC BY 4.0, recorded by the UCI dataset page.

The experiment uses the nine sequential inertial channels, not the 561-column
precomputed feature table. Official test subjects remain reserved. Subjects
5, 14, 19, and 27 from the official training set are validation only. The
remaining training subjects fit channel-wise normalization. Counts are 5,991
training, 1,361 validation, and 2,947 test windows. Labels retain the official
six-class order, converted from one-based to zero-based indices.

Four-sample nonoverlapping patches form 32 tokens from each 128-sample window.
All 32 are part of the input; only explicit group decisions reduce later work.
Split indices, source archive SHA256, channel order, and fitted statistics are
retained in the dataset manifest and `config/splits/har.json`.

## Speech Commands

Speech Commands v0.02, by Pete Warden, released April 11, 2018.
Primary paper: https://arxiv.org/abs/1804.03209
Primary archive: https://storage.googleapis.com/download.tensorflow.org/data/speech_commands_v0.02.tar.gz
License: CC BY 4.0, verified in the archive's README and LICENSE.

The protocol classifies all 35 named words. It does not synthesize unknown or
silence classes, so results must not be compared directly with a 12-class
keyword-spotting protocol. Official lists yield 84,843 training, 9,981 validation,
and 11,005 test clips. Speaker IDs are verified disjoint across partitions.
Word order and filenames are recorded in the preparation manifest and split file.

The host converts each mono 16 kHz clip to a 16,000-sample window, padding short
clips with silence. It computes a Hann-window STFT with 512 FFT points,
480-sample window, hop 250, and no centered input padding. Forty triangular
mel filters span 20–7,600 Hz. Power is floored at 1e-8 before natural logarithm.
This produces 62 frames; two trailing log-silence frames give the configured
64-frame tokenizer capacity. Two-frame patches form 32 tokens.

Those trailing frames are part of the current fixed frontend and are treated
as valid model inputs. They are included in all operation counts and training
statistics. They are distinct from hardware tile padding, which must be excluded
from attention and pooling. A padding-mask or alternate-STFT sensitivity study
has not been performed; preserve the frontend when comparing current modes.
Mel-channel normalization is fitted on training clips only.

## Reproduction boundary

Raw archives and prepared arrays remain local under ignored `data/`. The source
URLs, archive hashes, split records, preprocessing parameters, and scripts are
retained for regeneration. Any redistributed data must preserve the respective
attribution and license terms. No dataset test partition has been used for
model or mode selection in the current experiments.
