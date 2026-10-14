import json
import math
from pathlib import Path

import numpy as np
import pytest

from golden.arithmetic import checked, exp_negative, integer_sqrt, online_attention, pwl_activation, rmsnorm, rmsnorm_lut, round_divide, shift_round


def spec_and_tables():
    spec = json.loads(Path("config/numerics.json").read_text())
    e = spec["exp_fraction_bits"]
    table = np.rint(np.exp(-np.arange(4097) / 256) * (1 << e)).astype(np.int64)
    return spec, table


def test_signed_rounding_ties_and_large_exact_integers():
    values = np.array([-7, -5, -3, -1, 1, 3, 5, 7])
    np.testing.assert_array_equal(round_divide(values, 2), [-4, -2, -2, 0, 0, 2, 2, 4])
    assert round_divide((1 << 60) + 1, 2) == 1 << 59
    assert shift_round(-3, -2) == -12
    with pytest.raises(ValueError):
        round_divide(1, 0)
    with pytest.raises(OverflowError):
        checked(128, 8)
    with pytest.raises(ValueError):
        checked(1.5, 8)
    with pytest.raises(OverflowError):
        checked(np.array([np.iinfo(np.uint64).max], dtype=np.uint64), 8)


def test_integer_sqrt_matches_exact_bounds():
    values = np.array([0, 1, 2, 15, 16, (1 << 60) - 1], dtype=np.int64)
    roots = integer_sqrt(values)
    for value, root in zip(values.tolist(), roots.tolist()):
        assert root * root <= value < (root + 1) ** 2


def test_norm_zero_and_constant():
    spec, _ = spec_and_tables()
    gamma = np.full(128, 1 << spec["norm_gamma_fraction_bits"])
    np.testing.assert_array_equal(rmsnorm(np.zeros((2, 128), dtype=np.int64), gamma, spec), 0)
    actual = rmsnorm(np.full((1, 128), 2 << 12), gamma, spec)
    np.testing.assert_allclose(actual, 1 << 12, atol=1)


def test_lut_norm_handles_low_variance_and_matches_float():
    spec, _ = spec_and_tables()
    table = np.rint(1 / np.sqrt(np.arange(1024, 2048) / 1024) * (1 << 30)).astype(np.int64)
    gamma = np.full(128, 1 << spec["norm_gamma_fraction_bits"])
    x = np.arange(-64, 64, dtype=np.int64)[None]
    actual = rmsnorm_lut(x, gamma, table, spec) / 4096
    expected = (x / 4096) / np.sqrt(np.mean((x / 4096) ** 2) + spec["norm_epsilon_q24"] / 4096 ** 2)
    np.testing.assert_allclose(actual, expected, atol=.002)
    np.testing.assert_array_equal(rmsnorm_lut(np.zeros_like(x), gamma, table, spec), 0)


@pytest.mark.parametrize("n", [1, 17, 256])
def test_online_integer_attention_equal_scores(n):
    spec, table = spec_and_tables()
    q = np.zeros((2, n, 8), dtype=np.int64)
    v = np.arange(2 * n * 8, dtype=np.int64).reshape(2, n, 8) - 100
    actual = online_attention(q, q, v, table, spec, round((1 / math.sqrt(8)) * (1 << 20)))
    expected = np.broadcast_to(round_divide(v.sum(1, keepdims=True), n), v.shape)
    np.testing.assert_array_equal(actual, expected)


def test_online_integer_attention_matches_float_recurrence():
    spec, table = spec_and_tables()
    rng = np.random.default_rng(5)
    q, k, v = [rng.integers(-8192, 8192, size=(2, 17, 8), dtype=np.int64) for _ in range(3)]
    actual = online_attention(q, k, v, table, spec, round((1 / math.sqrt(8)) * (1 << 20)))
    scores = q.astype(float) @ k.astype(float).transpose(0, 2, 1) / (4096 ** 2 * math.sqrt(8))
    probabilities = np.exp(scores - scores.max(-1, keepdims=True))
    probabilities /= probabilities.sum(-1, keepdims=True)
    expected = probabilities @ v
    np.testing.assert_allclose(actual, expected, atol=16, rtol=0.002)


def test_exp_limits_and_activation_knots():
    spec, table = spec_and_tables()
    np.testing.assert_array_equal(exp_negative(np.array([0, -17 * 4096]), table, spec), [1 << 20, 0])
    knots = np.arange(-4, 5, dtype=float)
    constants = np.rint(knots / (1 + np.exp(-knots)) * 4096).astype(np.int64)
    np.testing.assert_array_equal(pwl_activation((knots * 4096).astype(np.int64), constants, spec), constants)
