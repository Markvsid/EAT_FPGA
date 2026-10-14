import wave

import numpy as np

from model.speech_data import log_mel


def test_silence_and_short_clip(tmp_path):
    path = tmp_path / "silence.wav"
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(16000)
        f.writeframes(np.zeros(8000, dtype="<i2").tobytes())
    features = log_mel(path)
    assert features.shape == (64, 40)
    np.testing.assert_allclose(features, np.log(1e-8), atol=1e-6)
