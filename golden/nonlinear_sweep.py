"""Offline approximation error studies; resource cost remains unmeasured."""
import json
from pathlib import Path

import numpy as np

from golden.arithmetic import exp_negative, pwl_activation, rmsnorm, rmsnorm_lut


def main():
    spec = json.loads(Path("config/numerics.json").read_text())
    f = spec["state_fraction_bits"]
    unit = 1 << f
    grid = np.arange(-16 * unit, 1, dtype=np.int64)
    expected = np.exp(grid / unit)
    exp_rows = []
    for address_bits in [6, 8, 10]:
        for output_bits in [16, 20, 24]:
            candidate = {**spec, "exp_input_fraction_bits": address_bits, "exp_fraction_bits": output_bits}
            table = np.rint(np.exp(-np.arange(16 * (1 << address_bits) + 1) / (1 << address_bits)) * (1 << output_bits)).astype(np.int64)
            actual = exp_negative(grid, table, candidate) / (1 << output_bits)
            exp_rows.append({"address_fraction_bits": address_bits, "output_fraction_bits": output_bits,
                             "entries": len(table), "packed_table_bits": len(table) * (output_bits + 1),
                             "max_absolute_error": float(np.max(np.abs(actual - expected))),
                             "rms_error": float(np.sqrt(np.mean((actual - expected) ** 2)))})
    activation_input = np.arange(-8 * unit, 8 * unit + 1, dtype=np.int64)
    real = activation_input / unit
    knots = np.arange(-4, 5, dtype=float)
    knot_values = knots / (1 + np.exp(-knots))
    constants = np.rint(knot_values * unit).astype(np.int64)
    actual = pwl_activation(activation_input, constants, spec) / unit
    baseline = np.interp(real, knots, knot_values)
    baseline[real < -4] = 0
    baseline[real > 4] = real[real > 4]
    rng = np.random.default_rng(127)
    magnitudes = np.geomspace(0.001, 128, 2048)
    x = np.rint(rng.normal(size=(2048, 128)) * magnitudes[:, None] * unit).astype(np.int64)
    gamma = np.full(128, 1 << spec["norm_gamma_fraction_bits"])
    float_norm = (x / unit) / np.sqrt(np.mean((x / unit) ** 2, axis=1, keepdims=True) + spec["norm_epsilon_q24"] / unit ** 2)
    direct = rmsnorm(x, gamma, spec) / unit
    rsqrt_table = np.rint(1 / np.sqrt(np.arange(1024, 2048) / 1024) * (1 << 30)).astype(np.int64)
    lut = rmsnorm_lut(x, gamma, rsqrt_table, spec) / unit
    result = {"status": "software_error_sweep_no_synthesis_cost", "exp": exp_rows,
              "activation": {"domain": [-8, 8], "max_error_vs_exact_silu": float(np.max(np.abs(actual - real / (1 + np.exp(-real))))),
                             "max_error_vs_training_pwl": float(np.max(np.abs(actual - baseline)))},
              "rmsnorm": {"rows": len(x), "width": 128, "input_magnitude_range": [0.001, 128],
                          "sqrt_divide_max_absolute_error": float(np.max(np.abs(direct - float_norm))),
                          "lut_max_absolute_error": float(np.max(np.abs(lut - float_norm))),
                          "lut_entries": len(rsqrt_table), "lut_fraction_bits": 30},
              "limitations": ["sampled RMS inputs do not prove an error bound over all integer vectors",
                              "LUT accuracy does not establish FPGA area or timing", "task-level LUT replacement requires separate validation"]}
    Path("results/nonlinear_sweep.json").write_text(json.dumps(result, indent=2) + "\n")
    Path("exports/nonlinear_tables").mkdir(parents=True, exist_ok=True)
    np.savez_compressed("exports/nonlinear_tables/rsqrt.npz", table=rsqrt_table)
    print(json.dumps({"activation": result["activation"], "rmsnorm": result["rmsnorm"]}))


if __name__ == "__main__":
    main()
