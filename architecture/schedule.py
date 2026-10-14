"""Operator-level schedule estimates with tails and explicit assumptions.

These estimates are uncalibrated. No synthesized Fmax, LUT/DSP mapping, physical
bank allocation, or measured energy is inferred from this model.
"""
import argparse
import json
import math
from pathlib import Path

from model.network import Encoder


def gemm(rows, reduction, columns, h, operand_bytes=1, weight_bits=8):
    pr, pc = h["array_rows"], h["array_columns"]
    row_tiles, column_tiles = math.ceil(rows / pr), math.ceil(columns / pc)
    tiles = row_tiles * column_tiles
    compute = tiles * (reduction + pr + pc - 2 + h["tensor_startup_cycles"])
    weight_bytes = row_tiles * reduction * columns * weight_bits // 8
    activation_bytes = column_tiles * rows * reduction * operand_bytes
    loads = max(math.ceil(weight_bytes / h["weight_read_bytes_per_cycle"]),
                math.ceil(activation_bytes / h["activation_read_bytes_per_cycle"]))
    requantize = math.ceil(rows * columns / h["requantize_values_per_cycle"])
    cycles = max(compute, loads) + requantize + h["control_cycles_per_operator"]
    macs = rows * reduction * columns
    return {"cycles": cycles, "macs": macs, "array_compute_cycles": compute, "onchip_load_cycles": loads,
            "requantize_cycles": requantize, "weight_bytes": weight_bytes, "activation_bytes": activation_bytes,
            "tail_occupancy": macs / (tiles * pr * pc * reduction)}


def schedule(c, mode, h, sequence=None):
    n = sequence or c["window_samples"] // c["patch_samples"]
    d, g, heads = c["width"], c["group_size"], c["heads"]
    groups = n // g
    keep = mode["keep_groups"]
    if n % g or not 1 <= keep <= groups:
        raise ValueError("Invalid sequence or keep count")
    after = keep * g + ((groups - keep) if mode["rts"] else 0)
    operators = []
    def add(name, result):
        operators.append({"name": name, **result})
    def scalar(name, count, setup=0, throughput=None):
        rate = throughput or h["nonlinear_values_per_cycle"]
        add(name, {"cycles": math.ceil(count / rate) + setup + h["control_cycles_per_operator"], "macs": 0})
    add("embedding", gemm(n, c["patch_samples"] * len(c["channels"]), d, h, weight_bits=mode["weight_bits"]))
    scalar("position_add", n * d)
    active = n
    for index in range(1, mode["exit_block"] + 1):
        prefix = f"block{index}_"
        for suffix in ["norm1", "norm2"]:
            scalar(prefix + suffix, active * d, active * h["norm_row_setup_cycles"])
        add(prefix + "qkv", gemm(active, d, 3 * d, h, weight_bits=mode["weight_bits"]))
        qk = gemm(active, d // heads, active, h)
        av = gemm(active, active, d // heads, h, operand_bytes=3)
        add(prefix + "attention_qk", {key: value * heads if key != "tail_occupancy" else value for key, value in qk.items()})
        add(prefix + "attention_av", {key: value * heads if key != "tail_occupancy" else value for key, value in av.items()})
        tiles = math.ceil(active / 8)
        scalar(prefix + "online_softmax", heads * active * active,
               heads * active * tiles * h["softmax_tile_setup_cycles"], h["exp_values_per_cycle"])
        scalar(prefix + "attention_divide", heads * active * (d // heads) * h["divider_cycles_per_value"], throughput=1)
        add(prefix + "projection", gemm(active, d, d, h, weight_bits=mode["weight_bits"]))
        add(prefix + "fc1", gemm(active, d, c["ffn_ratio"] * d, h, weight_bits=mode["weight_bits"]))
        scalar(prefix + "activation", active * c["ffn_ratio"] * d)
        add(prefix + "fc2", gemm(active, c["ffn_ratio"] * d, d, h, weight_bits=mode["weight_bits"]))
        scalar(prefix + "residuals", 2 * active * d)
        if index == c["gate_after_block"] and keep < groups:
            add("group_scorer", gemm(active, d, 1, h, weight_bits=mode["weight_bits"]))
            scalar("group_score_reduction", active, throughput=1)
            scalar("group_selection", groups * groups, throughput=1)
            scalar("token_compaction", after * d)
            if mode["rts"]:
                scalar("summary_weighted_accumulation", (groups - keep) * g * d)
                scalar("summary_division", (groups - keep) * d * h["divider_cycles_per_value"], throughput=1)
            active = after
    scalar("final_norm", active * d, active * h["norm_row_setup_cycles"])
    scalar("pooling", active * d + d * h["divider_cycles_per_value"])
    add("classifier", gemm(1, d, c["classes"], h, weight_bits=mode["weight_bits"]))
    total = sum(operator["cycles"] for operator in operators)
    model = Encoder(c)
    matrix_weights = sum(module.weight.numel() for module in model.modules() if hasattr(module, "bias") and hasattr(module, "weight"))
    state_bytes = 3
    buffers = {"packed_linear_weights": math.ceil(matrix_weights * mode["weight_bits"] / 8),
               "bias_and_multiplier_arrays": sum(module.bias.numel() * 12 for module in model.modules() if getattr(module, "bias", None) is not None),
               "position_and_norm_weights": (n * d + (2 * c["layers"] + 1) * d) * state_bytes,
               "pingpong_state": 2 * n * d * state_bytes, "qkv_state": 3 * n * d * state_bytes,
               "ffn_state": n * c["ffn_ratio"] * d * state_bytes,
               "attention_running_state": heads * n * (d // heads + 2) * 8,
               "exp_and_activation_tables": 4097 * 4 + 1024 * 4 + 9 * 4,
               "token_metadata_and_scores": n * 8 + groups * 8,
               "input_output": (c["window_samples"] * len(c["channels"]) + c["classes"]) * state_bytes}
    capacities = h["k26_capacities"]
    capacity = capacities["bram36_blocks"] * 36 * 1024 // 8 + capacities["uram288_blocks"] * 288 * 1024 // 8
    payload = sum(buffers.values())
    return {"status": "uncalibrated_schedule_not_measured", "mode": mode, "sequence": n, "after_gate": after,
            "operators": operators, "estimated_cycles": total, "assumed_clock_hz": h["assumed_clock_hz"],
            "conditional_latency_ms": 1000 * total / h["assumed_clock_hz"], "memory_payload_bytes": buffers,
            "memory_payload_total_bytes": payload, "combined_k26_memory_bytes": capacity,
            "payload_fits_combined_capacity_with_reserve": payload <= capacity * (1 - h["reserved_memory_fraction"]),
            "physical_banking_fit_proven": False,
            "limitations": ["nonlinear rates and divider latency assumed", "no RTL calibration", "no measured clock or energy",
                            "no physical bank allocation", "activation ports count int8 tensor inputs after state requantization",
                            "streaming recurrence overhead simplified", "no additional W4 DSP throughput assumed",
                            "sequential operator schedule; intra-GEMM load overlap assumed"]}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--config", default="config/har.json")
    p.add_argument("--output", default="results/schedule_estimates.json")
    args = p.parse_args()
    c = json.loads(Path(args.config).read_text())
    h = json.loads(Path("config/hardware_candidate.json").read_text())
    dense = {"weight_bits": 8, "keep_groups": c["window_samples"] // c["patch_samples"] // c["group_size"], "rts": False, "exit_block": c["layers"]}
    report = {"hardware_assumptions": h, "dense": schedule(c, dense, h),
              "candidate_modes": {name: schedule(c, mode, h) for name, mode in c["modes"].items()},
              "dense_sequence_sweep": [schedule(c, {**dense, "keep_groups": n // c["group_size"]}, h, sequence=n)
                                       for n in [16, 32, 64, 128, 256]]}
    Path(args.output).write_text(json.dumps(report, indent=2) + "\n")
