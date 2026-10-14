"""Integer-only arithmetic. Floating point belongs in offline table generation."""
import math

import numpy as np


def integer_array(x):
    raw = np.asarray(x)
    if not np.issubdtype(raw.dtype, np.integer):
        raise ValueError("Integer arithmetic inputs required")
    if np.issubdtype(raw.dtype, np.unsignedinteger) and np.any(raw > np.iinfo(np.int64).max):
        raise OverflowError("Unsigned value cannot be represented in signed INT64")
    return raw.astype(np.int64, copy=False)


def checked(x, bits, name="integer"):
    x = integer_array(x)
    if np.any(x < -(1 << (bits - 1))) or np.any(x > (1 << (bits - 1)) - 1):
        raise OverflowError(f"{name} exceeds signed {bits}-bit range")
    return x


def round_divide(numerator, denominator):
    """Exact signed division, nearest with ties to even; positive denominator."""
    n, d = np.broadcast_arrays(integer_array(numerator), integer_array(denominator))
    if np.any(d <= 0) or np.any(n == np.iinfo(np.int64).min):
        raise ValueError("Positive denominator and representable absolute numerator required")
    absolute = np.abs(n)
    quotient, remainder = absolute // d, absolute % d
    # Comparing remainder with d-remainder avoids doubling overflow.
    greater = remainder > d - remainder
    tie = remainder == d - remainder
    quotient = quotient + (greater | (tie & ((quotient & 1) != 0)))
    return np.where(n < 0, -quotient, quotient).astype(np.int64)


def shift_round(x, shift):
    if not isinstance(shift, int) or abs(shift) > 50:
        raise ValueError("Shift must be an integer in [-50, 50]")
    x = integer_array(x)
    if shift >= 0:
        return round_divide(x, 1 << shift)
    checked(x, 63 + shift, "left-shift input")
    return x << -shift


def saturate(x, bits):
    return np.clip(integer_array(x), -(1 << (bits - 1)), (1 << (bits - 1)) - 1)


def integer_sqrt(x):
    x = integer_array(x)
    if np.any(x < 0):
        raise ValueError("Square root input must be nonnegative")
    return np.fromiter((math.isqrt(int(v)) for v in x.flat), dtype=np.int64).reshape(x.shape)


def rmsnorm(x, gamma, spec):
    f = spec["state_fraction_bits"]
    x = checked(x, spec["state_signed_bits"], "norm input")
    checked(x, 30, "norm square input")
    sums = checked((x * x).sum(-1, keepdims=True), 63, "norm sum squares")
    variance = round_divide(sums, x.shape[-1]) + spec["norm_epsilon_q24"]
    denominator = np.maximum(integer_sqrt(variance), 1)
    normalized = round_divide(x * (1 << f), denominator)
    checked(normalized, 31, "normalized state")
    gamma = checked(gamma, 24, "norm gamma")
    return shift_round(normalized * gamma, spec["norm_gamma_fraction_bits"])


def rmsnorm_lut(x, gamma, table, spec):
    """Leading-one/mantissa reciprocal-square-root candidate; table is Q30."""
    x = checked(x, spec["state_signed_bits"], "LUT norm input")
    variance = round_divide((x * x).sum(-1, keepdims=True), x.shape[-1]) + spec["norm_epsilon_q24"]
    exponent = np.fromiter((int(v).bit_length() - 1 for v in variance.flat), dtype=np.int64).reshape(variance.shape)
    mantissa = np.empty_like(variance)
    for index in np.ndindex(variance.shape):
        difference = int(exponent[index]) - 10
        mantissa[index] = int(variance[index]) >> difference if difference >= 0 else int(variance[index]) << -difference
    coefficient = table[np.clip(mantissa - 1024, 0, 1023)].copy()
    power = exponent - 24
    # sqrt(2) parity correction in Q30; fixed literal generated offline.
    odd = (power & 1) != 0
    coefficient = np.where(odd, shift_round(coefficient * 759250125, 30), coefficient)
    for index in np.ndindex(coefficient.shape):
        coefficient[index] = shift_round(coefficient[index], int(power[index] // 2))
    product = x * coefficient
    checked(product, 63, "LUT norm product")
    normalized = shift_round(product, 30)
    return shift_round(normalized * gamma, spec["norm_gamma_fraction_bits"])


def pwl_activation(x, knots, spec):
    x, knots = integer_array(x), integer_array(knots)
    unit = 1 << spec["state_fraction_bits"]
    indices = np.clip(x // unit + 4, 0, 7)
    fraction = x - (indices - 4) * unit
    y = knots[indices] + round_divide((knots[indices + 1] - knots[indices]) * fraction, unit)
    return np.where(x < -4 * unit, 0, np.where(x > 4 * unit, x, y)).astype(np.int64)


def exp_negative(x, table, spec):
    """Exp of nonpositive Q-state values with nearest-even table addressing."""
    x, table = integer_array(x), integer_array(table)
    if np.any(x > 0):
        raise ValueError("Online Softmax exponential argument must be nonpositive")
    shift = spec["state_fraction_bits"] - spec["exp_input_fraction_bits"]
    address = shift_round(-np.asarray(x, dtype=np.int64), shift)
    clipped = np.clip(address, 0, len(table) - 1)
    return np.where(address >= len(table), 0, table[clipped])


def online_attention(q, k, v, exp_table, spec, scale_multiplier):
    """Q/K/V [head, token, head_width]; all runtime operations are integers."""
    f = spec["state_fraction_bits"]
    e = spec["exp_fraction_bits"]
    tile = spec["attention_tile"]
    q, k, v = checked(q, 24, "Q"), checked(k, 24, "K"), checked(v, 24, "V")
    if (q.ndim != 3 or k.ndim != 3 or v.ndim != 3 or tile < 1 or q.shape[0] != k.shape[0]
            or q.shape[-1] != k.shape[-1] or k.shape != v.shape or not k.shape[1] or not q.shape[1]):
        raise ValueError("Invalid attention shapes or tile")
    maximum = None
    normalizer = np.zeros(q.shape[:-1] + (1,), dtype=np.int64)
    output = np.zeros_like(q, dtype=np.int64)
    for start in range(0, k.shape[1], tile):
        scores_q24 = q @ k[:, start:start + tile].transpose(0, 2, 1)
        checked(scores_q24, 47, "QK accumulator")
        # Q24 -> Q12 -> scaled Q12. Avoid multiplying Q24 by Q20 directly.
        scores = shift_round(shift_round(scores_q24, f) * scale_multiplier, 20)
        local_max = scores.max(-1, keepdims=True)
        new_max = local_max if maximum is None else np.maximum(maximum, local_max)
        alpha = np.zeros_like(new_max) if maximum is None else exp_negative(maximum - new_max, exp_table, spec)
        p = exp_negative(scores - new_max, exp_table, spec)
        checked(normalizer * alpha, 62, "Softmax rescale")
        checked(output, 40, "attention output state before rescale")
        contribution = p @ v[:, start:start + tile]
        checked(contribution, 62, "attention tile weighted sum")
        output = shift_round(output * alpha, e) + shift_round(contribution, e)
        normalizer = shift_round(normalizer * alpha, e) + p.sum(-1, keepdims=True)
        checked(output, 40, "attention weighted-value state")
        checked(normalizer, 32, "attention normalizer")
        maximum = new_max
    checked(output * (1 << e), 62, "attention final numerator")
    return round_divide(output * (1 << e), normalizer)
