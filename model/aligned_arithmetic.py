"""Independent CPU PyTorch implementation of the existing integer contract.

No golden arithmetic functions are called. Integer dot products may use FP32
GEMM only for bounded INT8 operands: K<=256 implies every product/partial sum
is exactly representable (absolute sum <=2**22 <2**24).
"""
import torch


def check(x, bits, name='integer'):
    if x.dtype != torch.int64:
        raise TypeError('INT64 container required')
    if bool(((x < -(1 << (bits - 1))) | (x >= (1 << (bits - 1)))).any()):
        raise OverflowError(f'{name} exceeds signed{bits}')
    return x


def divide(n, d):
    if isinstance(d, int) and d > 0 and d & (d - 1) == 0:
        return shift(n, d.bit_length() - 1)
    d = torch.as_tensor(d, dtype=torch.int64, device=n.device)
    if bool((d <= 0).any()) or bool((n == -(1 << 63)).any()):
        raise ValueError('Positive denominator and representable absolute value required')
    a = n.abs()
    q = torch.div(a, d, rounding_mode='floor')
    r = a.remainder(d)
    up = (r > d - r) | ((r == d - r) & ((q & 1) != 0))
    q = q + up.to(torch.int64)
    return torch.where(n < 0, -q, q)


def shift(x, amount):
    if isinstance(amount, int):
        if abs(amount) > 50:
            raise ValueError('Unsupported shift')
        if amount < 0:
            check(x, 63 + amount, 'left shift')
            return x << -amount
        if amount == 0:
            return x
        # Arithmetic right shift is floor division, including negative inputs.
        # The nonnegative low-bit remainder makes ties-to-even exact for both signs.
        quotient = x >> amount
        remainder = x & ((1 << amount) - 1)
        half = 1 << (amount - 1)
        up = (remainder > half) | ((remainder == half) & ((quotient & 1) != 0))
        return quotient + up.to(torch.int64)
    # Variable exponents are used only by the rsqrt mantissa reconstruction.
    if bool((amount.abs() > 50).any()):
        raise ValueError('Unsupported variable shift')
    positive = amount.clamp_min(1)
    quotient = x >> positive
    remainder = x & ((torch.ones_like(positive) << positive) - 1)
    half = torch.ones_like(positive) << (positive - 1)
    right = quotient + ((remainder > half) | ((remainder == half) & ((quotient & 1) != 0))).long()
    right = torch.where(amount == 0, x, right)
    left = x << (-amount).clamp_min(0)
    return torch.where(amount >= 0, right, left)


def clip(x, bits):
    return x.clamp(-(1 << (bits - 1)), (1 << (bits - 1)) - 1)


def dot_i8(x, weight):
    if torch.get_float32_matmul_precision() != 'highest':
        raise ValueError('Exact bounded GEMM requires highest FP32 matmul precision')
    check(x, 8, 'dot activation')
    check(weight, 8, 'dot weight')
    if weight.ndim != 2 or x.shape[-1] != weight.shape[-1] or x.shape[-1] > 256:
        raise ValueError('Unsupported bounded GEMM shape')
    return (x.float() @ weight.float().T).to(torch.int64)


def norm(x, gamma, table, spec):
    check(x, spec['state_signed_bits'], 'norm input')
    variance = divide((x * x).sum(-1, keepdim=True), x.shape[-1]) + spec['norm_epsilon_q24']
    # Exact leading-one search; no floating log2 at power-of-two boundaries.
    temp, exponent = variance.clone(), torch.zeros_like(variance)
    for bit in [32, 16, 8, 4, 2, 1]:
        take = temp >= (1 << bit)
        temp = torch.where(take, temp >> bit, temp)
        exponent = exponent + take.to(torch.int64) * bit
    delta = exponent - 10
    mantissa = torch.where(delta >= 0, variance >> delta.clamp_min(0), variance << (-delta).clamp_min(0))
    coefficient = table[(mantissa - 1024).clamp(0, 1023)]
    power = exponent - 24
    coefficient = torch.where((power & 1) != 0, shift(coefficient * 759250125, 30), coefficient)
    coefficient = shift(coefficient, torch.div(power, 2, rounding_mode='floor'))
    product = check(x * coefficient, 63, 'norm product')
    normalized = shift(product, 30)
    return shift(normalized * gamma, spec['norm_gamma_fraction_bits'])


def activation(x, knots, spec):
    unit = 1 << spec['state_fraction_bits']
    index = (torch.div(x, unit, rounding_mode='floor') + 4).clamp(0, 7)
    fraction = x - (index - 4) * unit
    y = knots[index] + divide((knots[index + 1] - knots[index]) * fraction, unit)
    return torch.where(x < -4 * unit, torch.zeros_like(x), torch.where(x > 4 * unit, x, y))


def exp_negative(x, table, spec):
    if bool((x > 0).any()):
        raise ValueError('Expected nonpositive exponential argument')
    address = shift(-x, spec['state_fraction_bits'] - spec['exp_input_fraction_bits'])
    value = table[address.clamp(0, len(table) - 1)]
    return torch.where(address >= len(table), torch.zeros_like(value), value)


def attention(q, k, v, table, spec, scale):
    # Tensors are [batch, head, token, head width].
    f, e, tile = spec['state_fraction_bits'], spec['exp_fraction_bits'], spec['attention_tile']
    for name, tensor in [('q', q), ('k', k), ('v', v)]:
        check(tensor, 24, name)
    if q.shape[-1] > 32 or tile > 8:
        raise ValueError('Exact FP64 attention GEMM proof requires head width<=32, tile<=8')
    maximum = None
    normalizer = torch.zeros_like(q[..., :1])
    output = torch.zeros_like(q)
    for start in range(0, k.shape[-2], tile):
        # Signed24 products have <=46 bits; 32 partials have <=51 bits,
        # so FP64 products and all partial sums are exact integers.
        scores = (q.double() @ k[..., start:start + tile, :].double().transpose(-2, -1)).long()
        scores = check(scores, 47, 'QK')
        scores = shift(shift(scores, f) * scale, 20)
        local = scores.amax(-1, keepdim=True)
        new_max = local if maximum is None else torch.maximum(maximum, local)
        alpha = torch.zeros_like(new_max) if maximum is None else exp_negative(maximum - new_max, table, spec)
        p = exp_negative(scores - new_max, table, spec)
        check(normalizer * alpha, 62, 'normalizer rescale')
        check(output, 40, 'attention state')
        # p<=2**20 and |v|<=2**23, with <=8 summands: <=46 bits.
        contribution = (p.double() @ v[..., start:start + tile, :].double()).long()
        contribution = check(contribution, 62, 'AV')
        output = shift(output * alpha, e) + shift(contribution, e)
        normalizer = shift(normalizer * alpha, e) + p.sum(-1, keepdim=True)
        check(output, 40, 'weighted value state')
        check(normalizer, 32, 'attention denominator')
        maximum = new_max
    return divide(check(output * (1 << e), 62, 'final attention numerator'), normalizer)


class ExactForward(torch.autograd.Function):
    """Exact forward values; explicit surrogate gradient through second input."""
    @staticmethod
    def forward(ctx, exact, surrogate):
        return exact.clone()

    @staticmethod
    def backward(ctx, gradient):
        return None, gradient


def attach(exact_real, surrogate):
    # Unlike x + (quantized-x).detach(), this never introduces cancellation
    # roundoff in the returned forward value.
    return ExactForward.apply(exact_real, surrogate)
