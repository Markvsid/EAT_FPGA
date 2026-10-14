"""Deterministic binary images for candidate weights and constant arrays."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

from golden.reference import IntegerEncoder


def pack_signed_nibbles(values):
    x = np.asarray(values, dtype=np.int64).ravel()
    if np.any(x < -8) or np.any(x > 7):
        raise ValueError("INT4 weight outside [-8, 7]")
    nibbles = (x & 15).astype(np.uint8)
    if len(nibbles) % 2:
        nibbles = np.append(nibbles, np.uint8(0))
    return (nibbles[0::2] | (nibbles[1::2] << 4)).tobytes()


def unpack_signed_nibbles(blob, count):
    byte = np.frombuffer(blob, dtype=np.uint8)
    nibbles = np.empty(len(byte) * 2, dtype=np.int8)
    nibbles[0::2] = byte & 15
    nibbles[1::2] = byte >> 4
    signed = np.where(nibbles >= 8, nibbles.astype(np.int16) - 16, nibbles).astype(np.int8)
    return signed[:count]


def pack(export_path):
    reference = IntegerEncoder(export_path)
    destination = Path(export_path) / "binary"
    destination.mkdir(exist_ok=False)
    entries = {}
    for name, array in reference.constants.items():
        file_name = name.replace(".", "_") + ".bin"
        if name.endswith(".weight"):
            bits = reference.manifest["layers"][name.removesuffix(".weight")]["weight_bits"]
            blob = pack_signed_nibbles(array) if bits == 4 else array.astype(np.int8).tobytes()
            encoding = "signed_int4_low_nibble_first" if bits == 4 else "signed_int8"
        else:
            blob = array.astype("<i8").tobytes()
            encoding = "signed_int64_little_endian_container_for_declared_numeric_format"
        (destination / file_name).write_bytes(blob)
        entries[name] = {"file": file_name, "shape": list(array.shape), "order": "C_row_major",
                         "encoding": encoding, "bytes": len(blob), "sha256": hashlib.sha256(blob).hexdigest()}
    manifest = {"status": "candidate_images_no_bitstream", "entries": entries,
                "export_manifest_sha256": hashlib.sha256((Path(export_path) / "manifest.json").read_bytes()).hexdigest()}
    (destination / "layout.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", required=True)
    args = parser.parse_args()
    m = pack(args.export)
    print(json.dumps({"arrays": len(m["entries"]), "total_bytes": sum(e["bytes"] for e in m["entries"].values())}))
