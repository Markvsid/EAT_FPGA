"""Exercise legal INT8 input limits through the entire exported reference."""
import argparse
import json
from pathlib import Path

import numpy as np

from golden.reference import IntegerEncoder


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    model = IntegerEncoder(args.export)
    shape = (model.config["window_samples"], len(model.config["channels"]))
    rng = np.random.default_rng(4250)
    inputs = {"zero": np.zeros(shape, dtype=np.int8), "maximum": np.full(shape, 127, dtype=np.int8),
              "minimum": np.full(shape, -128, dtype=np.int8),
              "alternating_limits": np.where(np.indices(shape).sum(0) % 2, 127, -128).astype(np.int8)}
    inputs.update({f"uniform_int8_{i}": rng.integers(-128, 128, size=shape, dtype=np.int16).astype(np.int8) for i in range(16)})
    results = []
    for name, values in inputs.items():
        logits = model.predict(values)
        repeated = model.predict(values)
        if not np.array_equal(logits, repeated):
            raise AssertionError("Integer output must be deterministic")
        results.append({"input": name, "logits_q12": logits.tolist(), "saturations": dict(model.saturations)})
    Path(args.output).write_text(json.dumps({"status": "finite_width_reference_stress_not_rtl_test", "cases": results,
                                            "export_manifest": model.manifest["constants_sha256"]}, indent=2) + "\n")
    print(json.dumps({"stress_cases_passed": len(results), "counted_saturations": sum(sum(r["saturations"].values()) for r in results)}))


if __name__ == "__main__":
    main()
