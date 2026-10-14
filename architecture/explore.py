"""Analytical design-space exploration; no physical implementation feasibility claim."""
import copy
import json
from pathlib import Path

from architecture.schedule import schedule


def main():
    c = json.loads(Path("config/har.json").read_text())
    base = json.loads(Path("config/hardware_candidate.json").read_text())
    points = []
    for rows, columns in [(2, 8), (4, 8), (8, 8), (4, 16), (8, 16), (16, 16)]:
        for bandwidth in [8, 16, 32]:
            for nonlinear in [2, 4, 8]:
                h = copy.deepcopy(base)
                h.update(array_rows=rows, array_columns=columns, weight_read_bytes_per_cycle=bandwidth,
                         activation_read_bytes_per_cycle=bandwidth, nonlinear_values_per_cycle=nonlinear,
                         requantize_values_per_cycle=columns)
                modes = {name: schedule(c, mode, h) for name, mode in c["modes"].items()}
                points.append({"array_rows": rows, "array_columns": columns, "assumed_pe_multipliers": rows * columns,
                               "memory_read_bytes_per_cycle": bandwidth, "nonlinear_values_per_cycle": nonlinear,
                               "cycles": {name: data["estimated_cycles"] for name, data in modes.items()},
                               "memory_payload_bytes": {name: data["memory_payload_total_bytes"] for name, data in modes.items()}})
    result = {"status": "analytical_design_space_no_synthesis_validation", "points": points,
              "assumed_clock_hz": base["assumed_clock_hz"],
              "limitations": ["PE multiplier count is not total DSP use", "routing and memory banks not checked",
                              "ports and nonlinear throughput are independent assumptions, not synthesized configurations",
                              "no energy surrogate calibrated", "no configuration selected or frozen"]}
    Path("results/design_space.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"candidate_points": len(points)}))


if __name__ == "__main__":
    main()
