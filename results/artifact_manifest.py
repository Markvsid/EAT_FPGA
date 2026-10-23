"""Hash the local research package without datasets, environments or binaries."""
import hashlib
import json
import subprocess
from pathlib import Path


def main():
    paths = []
    for folder in ["model", "golden", "native", "architecture", "host", "config", "tests", "paper", "results", "exports", ".github"]:
        paths.extend(p for p in Path(folder).rglob("*") if p.is_file())
    paths.extend(Path(p) for p in ["README.md", "requirements.txt", "requirements.lock", ".gitignore", ".gitattributes",
                                "Report_Template/FPGA_Energy_Efficient_Transformer_Research_Plan_2-Month_Extended.docx"])
    files = {}
    for path in sorted(paths):
        if "__pycache__" in path.parts or path.suffix in [".pyc", ".dylib", ".so"] or path.name in ["artifact_manifest.json", ".DS_Store"]:
            continue
        with path.open("rb") as f:
            digest = hashlib.file_digest(f, "sha256").hexdigest()
        files[str(path)] = {"bytes": path.stat().st_size, "sha256": digest}
    manifest = {"status": "software_research_package_hardware_gates_incomplete",
                "parent_git_commit_at_capture": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
                "completed_training_runs": len(list(Path("results/runs").glob("*/metrics.json"))),
                "completed_independent_integer_comparisons": len(list(Path("results/integer/calibrated").glob("*/metrics.json"))),
                "completed_shared_family_integer_comparisons": len(list(Path("results/integer/joint").glob("*/metrics.json"))),
                "completed_heldout_checkpoint_mode_evaluations": len(list(Path("results/python_study/test").glob("*/metrics.json"))),
                "completed_robustness_evaluations": len(list(Path("results/python_study/robustness").glob("*seed*.json"))),
                "completed_aligned_training_runs": len(list(Path("results/alignment_study/runs").glob("*/metrics.json"))),
                "completed_aligned_validation_comparisons": len(list(Path("results/alignment_study/validation").glob("*/metrics.json"))),
                "completed_aligned_subsequent_test_comparisons": len(list(Path("results/alignment_study/test").glob("*/metrics.json"))),
                "files": files, "excluded": ["downloaded/prepared datasets", "virtual environment", "native compiled libraries", "Git internals"]}
    Path("results/artifact_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"files": len(files), "bytes": sum(p["bytes"] for p in files.values()),
                      "completed_training_runs": manifest["completed_training_runs"]}))


if __name__ == "__main__":
    main()
