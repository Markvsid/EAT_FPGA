"""Raw HAR data with subject-disjoint validation and training-only statistics."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

import numpy as np

URL = "https://archive.ics.uci.edu/static/public/240/human+activity+recognition+using+smartphones.zip"


def prepare(config, destination=Path("data/har")):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    archive = destination / "uci_har.zip"
    if not archive.exists():
        temporary = archive.with_suffix(".download")
        urllib.request.urlretrieve(URL, temporary)
        temporary.replace(archive)
    with zipfile.ZipFile(archive) as outer:
        payload = io.BytesIO(outer.read("UCI HAR Dataset.zip")) if "UCI HAR Dataset.zip" in outer.namelist() else archive
    with zipfile.ZipFile(payload) as z:
        names = z.namelist()
        def read(suffix, dtype=float):
            matches = [n for n in names if n.endswith(suffix)]
            if len(matches) != 1:
                raise ValueError(f"Expected one archive member for {suffix}: {matches}")
            with z.open(matches[0]) as f:
                return np.loadtxt(f, dtype=dtype)
        def partition(name):
            x = np.stack([read(f"/{name}/Inertial Signals/{c}_{name}.txt")
                          for c in config["channels"]], axis=-1).astype(np.float32)
            y = read(f"/{name}/y_{name}.txt", np.int64) - 1
            subjects = read(f"/{name}/subject_{name}.txt", np.int64)
            return x, y, subjects
        train_x, train_y, train_s = partition("train")
        test_x, test_y, test_s = partition("test")
    validation = np.isin(train_s, config["validation_subjects"])
    if not validation.any() or validation.all():
        raise ValueError("Invalid validation subject selection")
    if set(train_s) & set(test_s):
        raise ValueError("Official train/test subject overlap")
    mean = train_x[~validation].mean(axis=(0, 1), dtype=np.float64).astype(np.float32)
    std = train_x[~validation].std(axis=(0, 1), dtype=np.float64).astype(np.float32)
    std = np.maximum(std, 1e-6)
    partitions = {
        "train": (train_x[~validation], train_y[~validation], train_s[~validation], np.flatnonzero(~validation)),
        "validation": (train_x[validation], train_y[validation], train_s[validation], np.flatnonzero(validation)),
        "test": (test_x, test_y, test_s, np.arange(len(test_y)))
    }
    manifest = {"source": URL, "license": "CC BY 4.0", "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
                "config": config, "mean": mean.tolist(), "std": std.tolist(), "splits": {}}
    for name, (x, y, subjects, indices) in partitions.items():
        np.savez_compressed(destination / f"{name}.npz", x=(x - mean) / std, y=y, subjects=subjects)
        manifest["splits"][name] = {"samples": len(y), "subjects": sorted(set(subjects.tolist())),
                                    "official_partition": "test" if name == "test" else "train", "indices": indices.tolist()}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    splits = Path("config/splits")
    splits.mkdir(parents=True, exist_ok=True)
    (splits / "har.json").write_text(json.dumps({"archive_sha256": manifest["archive_sha256"],
                                                "splits": manifest["splits"]}, indent=2) + "\n")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="config/har.json")
    parser.add_argument("--output", default="data/har")
    args = parser.parse_args()
    m = prepare(json.loads(Path(args.config).read_text()), Path(args.output))
    print(json.dumps({k: {n: v for n, v in s.items() if n != "indices"} for k, s in m["splits"].items()}, indent=2))
