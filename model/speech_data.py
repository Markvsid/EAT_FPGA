"""Speech Commands v2 35-word protocol using the supplied official lists.

Host-side log-mel preprocessing is outside the proposed accelerator boundary.
Download is explicit because the archive is approximately 2.3 GB.
"""
import argparse
import hashlib
import json
import tarfile
import urllib.request
import wave
from pathlib import Path

import numpy as np
import torch

URL = "https://storage.googleapis.com/download.tensorflow.org/data/speech_commands_v0.02.tar.gz"
WORDS = "backward bed bird cat dog down eight five follow forward four go happy house learn left marvin nine no off on one right seven sheila six stop three tree two up visual wow yes zero".split()


def log_mel(path):
    with wave.open(str(path), "rb") as f:
        if (f.getnchannels(), f.getsampwidth(), f.getframerate()) != (1, 2, 16000):
            raise ValueError(f"Unsupported PCM format: {path}")
        signal = np.frombuffer(f.readframes(f.getnframes()), dtype="<i2").astype(np.float32) / 32768.
    audio = torch.zeros(16000)
    length = min(16000, len(signal))
    audio[:length] = torch.from_numpy(signal[:length].copy())
    spectrum = torch.stft(audio, n_fft=512, hop_length=250, win_length=480,
                          window=torch.hann_window(480), center=False, return_complex=True).abs().square()
    mel = lambda hz: 2595. * np.log10(1. + hz / 700.)
    hz = lambda m: 700. * (10. ** (m / 2595.) - 1.)
    edges = hz(np.linspace(mel(20), mel(7600), 42))
    frequencies = np.arange(257) * 16000 / 512
    filters = np.stack([np.maximum(0., np.minimum((frequencies - edges[i]) / (edges[i + 1] - edges[i]),
                                                 (edges[i + 2] - frequencies) / (edges[i + 2] - edges[i + 1]))) for i in range(40)])
    features = torch.log((torch.from_numpy(filters).float() @ spectrum).clamp_min(1e-8)).T
    # Fixed 64-frame capacity; pad silence in the same logarithmic power domain.
    padded = torch.full((64, 40), float(np.log(1e-8)))
    padded[:len(features)] = features
    return padded.numpy()


def prepare(source, destination):
    source, destination = Path(source), Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    validation = set((source / "validation_list.txt").read_text().splitlines())
    test = set((source / "testing_list.txt").read_text().splitlines())
    if validation & test:
        raise ValueError("Official validation/test overlap")
    splits = {key: [] for key in ["train", "validation", "test"]}
    for label, word in enumerate(WORDS):
        for path in sorted((source / word).glob("*.wav")):
            relative = path.relative_to(source).as_posix()
            key = "validation" if relative in validation else "test" if relative in test else "train"
            splits[key].append((relative, label))
    if any(not files for files in splits.values()):
        raise ValueError("Missing Speech Commands data partition")
    speakers = {key: {Path(path).stem.split("_nohash_")[0] for path, _ in files} for key, files in splits.items()}
    for first, second in [("train", "validation"), ("train", "test"), ("validation", "test")]:
        if speakers[first] & speakers[second]:
            raise ValueError("Speaker leakage between official lists")
    manifest = {"source": URL, "protocol": "35 words, no synthetic unknown/silence classes", "labels": WORDS,
                "frontend": {"sample_rate": 16000, "n_fft": 512, "hop": 250, "window": 480, "mel_bins": 40,
                             "low_hz": 20, "high_hz": 7600, "frames": 64, "padding_log_power": float(np.log(1e-8))},
                "splits": {key: {"files": [p for p, _ in files], "speakers": sorted(speakers[key])} for key, files in splits.items()}}
    mean = std = None
    torch.set_num_threads(1)
    for key, files in splits.items():
        x = np.stack([log_mel(source / path) for path, _ in files])
        y = np.array([label for _, label in files], dtype=np.int64)
        if key == "train":
            mean = x.mean((0, 1), dtype=np.float64).astype(np.float32)
            std = np.maximum(x.std((0, 1), dtype=np.float64).astype(np.float32), 1e-6)
        np.savez_compressed(destination / f"{key}.npz", x=(x - mean) / std, y=y)
        print(f"Prepared {key}: {len(y)} clips", flush=True)
    manifest["mean"], manifest["std"] = mean.tolist(), std.tolist()
    manifest["official_lists_sha256"] = {name: hashlib.sha256((source / name).read_bytes()).hexdigest()
                                         for name in ["validation_list.txt", "testing_list.txt"]}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--source", default="data/speech_commands_v0.02")
    p.add_argument("--output", default="data/speech")
    p.add_argument("--download", action="store_true")
    args = p.parse_args()
    if args.download:
        root = Path(args.source)
        root.mkdir(parents=True, exist_ok=True)
        archive = root.parent / "speech_commands_v0.02.tar.gz"
        if not archive.exists():
            tmp = archive.with_suffix(".download")
            urllib.request.urlretrieve(URL, tmp)
            tmp.replace(archive)
        with tarfile.open(archive) as t:
            t.extractall(root, filter="data")
    prepare(args.source, args.output)
