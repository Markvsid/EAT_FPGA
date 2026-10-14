from pathlib import Path

import numpy as np
import pytest

from native.kernel import NativeKernel


@pytest.mark.skipif(not Path("native/build_metadata.json").exists(), reason="Run python -m native.build")
def test_native_exact_signed_products_and_tails():
    kernel = NativeKernel()
    rng = np.random.default_rng(4250)
    for rows, outputs, reduction in [(1, 6, 128), (17, 35, 80), (32, 384, 128), (26, 128, 256), (2, 1, 36)]:
        x = rng.integers(-128, 128, size=(rows, reduction), dtype=np.int16)
        w = rng.integers(-128, 128, size=(outputs, reduction), dtype=np.int16)
        np.testing.assert_array_equal(kernel.matmul(x, w), x.astype(np.int64) @ w.astype(np.int64).T)
    x = np.full((1, 256), -128, dtype=np.int16)
    np.testing.assert_array_equal(kernel.matmul(x, x), [[256 * 128 * 128]])
