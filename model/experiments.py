"""Run the declared software matrix sequentially on one training device.

Completed matching runs are reused; incomplete or mismatched runs cause an error.
No final test partition is used. Fine-tuning budgets match within each workload:
HAR 30 epochs; Speech Commands 5 epochs after its 30-epoch baseline.
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


def matrix():
    jobs = []
    for seed in [17, 29, 43]:
        jobs.append({"name": f"speech_fp32_seed{seed}", "dataset": "speech", "seed": seed,
                     "experiment": "fp32", "mode": "fp32", "arguments": []})
    definitions = [
        ("fp32_control", "fp32", []),
        ("quality", "quality", []),
        ("dense_w4", "quality", ["--weight-bits", "4"]),
        ("drop_keep6", "balanced", ["--rts", "off"]),
        ("balanced", "balanced", []),
        ("drop_keep4", "balanced", ["--keep-groups", "4", "--rts", "off"]),
        ("drop_keep5_matched20", "balanced", ["--keep-groups", "5", "--rts", "off"]),
        ("rts_keep4", "balanced", ["--keep-groups", "4"]),
        ("energy_saver", "energy_saver", [])
    ]
    for experiment, mode, arguments in definitions:
        for seed in [17, 29, 43]:
            jobs.append({"name": f"har_{experiment}_seed{seed}", "dataset": "har", "seed": seed,
                         "experiment": experiment, "mode": mode, "arguments": arguments,
                         "initialize": f"results/runs/har_fp32_seed{seed}/best.pt"})
    for seed in [17, 29, 43]:
        jobs.append({"name": f"har_joint_seed{seed}", "dataset": "har", "seed": seed,
                     "experiment": "joint", "mode": "fp32", "arguments": ["--joint-modes"],
                     "initialize": f"results/runs/har_fp32_seed{seed}/best.pt"})
    for experiment, mode in [("fp32_control", "fp32"), ("quality", "quality"), ("balanced", "balanced"), ("energy_saver", "energy_saver")]:
        for seed in [17, 29, 43]:
            jobs.append({"name": f"speech_{experiment}_seed{seed}", "dataset": "speech", "seed": seed,
                         "experiment": experiment, "mode": mode, "arguments": [], "epochs": 5,
                         "initialize": f"results/runs/speech_fp32_seed{seed}/best.pt"})
    return jobs


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--device", default="mps", choices=["cpu", "mps", "cuda"])
    p.add_argument("--only", choices=["har", "speech", "all"], default="all")
    args = p.parse_args()
    jobs = matrix()
    Path("results/experiment_matrix.json").write_text(json.dumps({"status": "validation_only", "jobs": jobs}, indent=2) + "\n")
    for number, job in enumerate(jobs, 1):
        if args.only != "all" and job["dataset"] != args.only:
            continue
        output = Path("results/runs") / job["name"]
        if (output / "metrics.json").exists():
            manifest = json.loads((output / "manifest.json").read_text())
            config = json.loads(Path(f"config/{job['dataset']}.json").read_text())
            expected_mode = None if job["mode"] == "fp32" else dict(config["modes"][job["mode"]])
            flags = dict(zip(job["arguments"][0::2], job["arguments"][1::2]))
            for flag, value in flags.items():
                key = flag.removeprefix("--").replace("-", "_")
                expected_mode[key] = value == "on" if key == "rts" else int(value)
            initial_hash = hashlib.sha256(Path(job["initialize"]).read_bytes()).hexdigest() if job.get("initialize") else None
            if (manifest["epochs"] != job.get("epochs", 30) or manifest["seed"] != job["seed"] or manifest["mode"] != job["mode"]
                    or manifest["config"] != config or manifest.get("execution_mode") != expected_mode
                    or bool(manifest.get("joint_modes")) != ("--joint-modes" in job["arguments"])
                    or manifest.get("initialize_sha256") != initial_hash):
                raise ValueError(f"Existing run does not match: {output}")
            print(f"Reuse {number}/{len(jobs)} {job['name']}", flush=True)
            continue
        if output.exists():
            raise ValueError(f"Incomplete run requires inspection: {output}")
        command = [sys.executable, "-m", "model.train", "--config", f"config/{job['dataset']}.json",
                   "--data", f"data/{job['dataset']}", "--output", str(output), "--seed", str(job["seed"]),
                   "--device", args.device, "--mode", job["mode"], "--experiment-id", job["experiment"], *job["arguments"]]
        if "epochs" in job:
            command.extend(["--epochs", str(job["epochs"])])
        if job.get("initialize"):
            command.extend(["--initialize", job["initialize"]])
        print(f"Start {number}/{len(jobs)} {job['name']}", flush=True)
        log = Path("results") / f"{job['name']}.log"
        with log.open("w") as f:
            subprocess.run(command, stdout=f, stderr=subprocess.STDOUT, check=True)
        print(f"Done {job['name']}", flush=True)
    subprocess.run([sys.executable, "-m", "results.update_manuscript"], check=True)


if __name__ == "__main__":
    main()
