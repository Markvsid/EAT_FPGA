"""Count all three runtime parameter banks; do not assume shared weights.

Use exact exported binary bytes as a conservative container budget. Identical
constant blobs may be deduplicated; physical bank/port feasibility is unproven.
"""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--exports", nargs=3, required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    banks, unique = [], {}
    for export in args.exports:
        root = Path(export)
        manifest = json.loads((root / "manifest.json").read_text())
        layout = json.loads((root / "binary/layout.json").read_text())
        banks.append({"path": str(root), "checkpoint_sha256": manifest["checkpoint_sha256"],
                      "mode": manifest["mode"], "binary_bytes": sum(e["bytes"] for e in layout["entries"].values())})
        for entry in layout["entries"].values():
            unique[(entry["sha256"], entry["encoding"])] = entry["bytes"]
    h = json.loads(Path("config/hardware_candidate.json").read_text())
    capacities = h["k26_capacities"]
    capacity = (capacities["bram36_blocks"] * 36 + capacities["uram288_blocks"] * 288) * 1024 // 8
    result = {"status": "export_container_budget_no_physical_bank_proof", "banks": banks,
              "shared_training_checkpoint": len({b["checkpoint_sha256"] for b in banks}) == 1,
              "all_banks_bytes": sum(b["binary_bytes"] for b in banks), "deduplicated_constant_bytes": sum(unique.values()),
              "combined_k26_memory_capacity_bytes": capacity, "activations_and_controller_memory_excluded": True,
              "physical_banking_fit_proven": False}
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: result[key] for key in ["shared_training_checkpoint", "all_banks_bytes", "deduplicated_constant_bytes"]}))


if __name__ == "__main__":
    main()
