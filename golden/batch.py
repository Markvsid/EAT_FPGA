"""Export/evaluate completed quantized modes once their checkpoints are ready."""
import argparse
import json
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", choices=["har", "speech", "all"], default="all")
    parser.add_argument("--calibration-samples", type=int, default=1024)
    args = parser.parse_args()
    for dataset in ["har", "speech"]:
        if args.dataset != "all" and dataset != args.dataset:
            continue
        for mode in ["quality", "balanced", "energy_saver"]:
            for seed in [17, 29, 43]:
                name = f"{dataset}_{mode}_seed{seed}"
                checkpoint = Path("results/runs") / name / "best.pt"
                if not (checkpoint.parent / "metrics.json").exists():
                    print(f"Pending checkpoint {name}", flush=True)
                    continue
                export = Path("exports/calibrated") / name
                output = Path("results/integer/calibrated") / name
                export.parent.mkdir(parents=True, exist_ok=True)
                output.parent.mkdir(parents=True, exist_ok=True)
                if not export.exists():
                    subprocess.run([sys.executable, "-m", "golden.export", "--checkpoint", str(checkpoint),
                                    "--data", f"data/{dataset}", "--output", str(export),
                                    "--samples", str(args.calibration_samples)], check=True)
                    subprocess.run([sys.executable, "-m", "golden.pack", "--export", str(export)], check=True)
                if not (output / "metrics.json").exists():
                    subprocess.run([sys.executable, "-m", "golden.evaluate", "--export", str(export),
                                    "--data", f"data/{dataset}", "--output", str(output)], check=True)
                print(f"Ready {name}", flush=True)


if __name__ == "__main__":
    main()
