"""Integrate actual power samples over a fully covered inference window."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np


def analyze(power_times, watts, starts, finishes, metadata):
    t, p, start, end = [np.asarray(values, dtype=float) for values in [power_times, watts, starts, finishes]]
    if len(t) < 2 or t.shape != p.shape or not len(start) or start.shape != end.shape:
        raise ValueError("At least two power samples and one paired inference are required")
    if any(not np.isfinite(values).all() for values in [t, p, start, end]):
        raise ValueError("Nonfinite measurements")
    if np.any(np.diff(t) <= 0) or np.any(p < 0) or np.any(end <= start):
        raise ValueError("Power timestamps must increase; watts and latency must be valid")
    if np.any(np.diff(start) < 0) or np.any(start[1:] < end[:-1]):
        raise ValueError("This batch-1 harness requires nonoverlapping ordered inferences")
    if metadata.get("batch_size") != 1 or metadata.get("power_boundary") != "whole_board":
        raise ValueError("Primary protocol requires batch size 1 and whole-board power")
    for key in ["clock_hz", "git_commit", "bitstream_sha256", "configuration_sha256", "instrument", "instrument_resolution_w", "warmup_inferences"]:
        if key not in metadata:
            raise ValueError(f"Missing traceability metadata: {key}")
    left, right = float(start[0]), float(end[-1])
    if left < t[0] or right > t[-1]:
        raise ValueError("Power trace does not cover the inference window; extrapolation prohibited")
    interior = (t > left) & (t < right)
    samples = np.concatenate([[left], t[interior], [right]])
    powers = np.interp(samples, t, p)
    energy = float(np.trapezoid(powers, samples))
    duration = right - left
    latencies = end - start
    return {"status": "analysis_of_supplied_board_logs", "metadata": metadata, "completed_inferences": len(start),
            "measurement_window_seconds": duration, "integrated_whole_board_joules": energy,
            "whole_board_joules_per_inference": energy / len(start), "average_whole_board_watts": energy / duration,
            "samples_per_second_over_window": len(start) / duration,
            "accelerator_latency_median_seconds": float(np.median(latencies)),
            "accelerator_latency_p95_seconds": float(np.percentile(latencies, 95)),
            "latency_sample_std_seconds": float(np.std(latencies, ddof=1)) if len(start) > 1 else None,
            "maximum_power_sample_gap_seconds": float(np.diff(t).max()),
            "confidence_interval": None, "uncertainty_note": "A single run supplies no repeat-trial confidence interval; instrument resolution is metadata, not a statistical bound."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--power", required=True, help="CSV timestamp_seconds,watts")
    parser.add_argument("--timing", required=True, help="CSV start_seconds,finish_seconds")
    parser.add_argument("--metadata", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    with Path(args.power).open() as f:
        power = list(csv.DictReader(f))
    with Path(args.timing).open() as f:
        timing = list(csv.DictReader(f))
    metadata = json.loads(Path(args.metadata).read_text())
    result = analyze([r["timestamp_seconds"] for r in power], [r["watts"] for r in power],
                     [r["start_seconds"] for r in timing], [r["finish_seconds"] for r in timing], metadata)
    result["input_sha256"] = {name: hashlib.sha256(Path(getattr(args, name)).read_bytes()).hexdigest()
                              for name in ["power", "timing", "metadata"]}
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
