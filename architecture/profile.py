import argparse
import json
import math
from pathlib import Path

from model.network import Encoder


def profile(c, mode=None, sequence=None, lanes=64):
    n = sequence or c["window_samples"] // c["patch_samples"]
    d, layers = c["width"], c["layers"]
    groups = n // c["group_size"]
    mode = mode or {"weight_bits": 8, "keep_groups": groups, "rts": False, "exit_block": layers}
    keep = mode["keep_groups"]
    if n % c["group_size"] or not 1 <= keep <= groups or lanes < 1:
        raise ValueError("Invalid sequence, retention, or lane count")
    reduced = keep * c["group_size"] + (groups - keep if mode["rts"] else 0)
    operators = [{"operator": "patch_embedding", "tokens": n,
                  "macs": n * c["patch_samples"] * len(c["channels"]) * d}]
    for layer in range(1, mode["exit_block"] + 1):
        active = n if layer <= c["gate_after_block"] else reduced
        operators.extend([
            {"operator": f"block{layer}_projections", "tokens": active, "macs": 4 * active * d * d},
            {"operator": f"block{layer}_attention_qk_av", "tokens": active, "macs": 2 * active * active * d},
            {"operator": f"block{layer}_ffn", "tokens": active, "macs": 2 * active * c["ffn_ratio"] * d * d}
        ])
    if keep != groups:
        operators.append({"operator": "group_scorer", "tokens": n, "macs": n * d})
        if mode["rts"]:
            operators.append({"operator": "weighted_summaries", "tokens": n - keep * c["group_size"],
                              "macs": (n - keep * c["group_size"]) * d})
    operators.append({"operator": "classifier", "tokens": 1, "macs": d * c["classes"]})
    macs = sum(o["macs"] for o in operators)
    # Buffers listed as payload only: banking, duplicate ports and allocation
    # fragmentation are deliberately not inferred from the model.
    buffers = {"encoder_matrix_weights": layers * (4 + 2 * c["ffn_ratio"]) * d * d * mode["weight_bits"] // 8,
               "pingpong_int8_activations": 2 * n * d,
               "qkv_int8": 3 * n * d,
               "ffn_int8": n * c["ffn_ratio"] * d,
               "online_attention_int32_state": c["heads"] * n * (d // c["heads"] + 2) * 4,
               "materialized_int16_scores_comparison": c["heads"] * n * n * 2}
    return {"status": "analytical_uncalibrated_not_measured", "sequence": n, "tokens_after_gate": reduced,
            "mode": mode, "operators": operators, "executed_macs": macs, "executed_ops_mac_equals_two": 2 * macs,
            "ideal_mac_cycle_lower_bound": sum(math.ceil(o["macs"] / lanes) for o in operators),
            "assumed_mac_lanes": lanes, "payload_bytes_only": buffers,
            "excluded_costs": ["normalization", "softmax", "activation", "residual additions", "pooling", "sorting and compaction", "summary division", "metadata", "scales and biases", "banking fragmentation", "pipeline and memory stalls", "DMA"]}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--config", default="config/har.json")
    p.add_argument("--output", default="results/workload_profile.json")
    args = p.parse_args()
    c = json.loads(Path(args.config).read_text())
    report = {"config_status": c["status"], "parameters_including_auxiliary_head": sum(p.numel() for p in Encoder(c).parameters()),
              "dense": profile(c), "candidate_modes": {k: profile(c, v) for k, v in c["modes"].items()},
              "dense_sequence_sweep": [profile(c, sequence=n) for n in [16, 32, 64, 128, 256]]}
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ["parameters_including_auxiliary_head", "config_status"]}))
