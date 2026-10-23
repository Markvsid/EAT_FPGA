import json
from pathlib import Path

import numpy as np
import pytest
import torch

from golden import arithmetic as golden
from golden.reference import IntegerEncoder
from model import aligned_arithmetic as aligned
from model.aligned import AlignedEncoder


def test_independent_rounding_and_bounded_matmul():
    rng = np.random.default_rng(91)
    x = rng.integers(-(1 << 48), 1 << 48, 1000, dtype=np.int64)
    for shift in [-2, 0, 1, 4, 24, 30]:
        np.testing.assert_array_equal(aligned.shift(torch.from_numpy(x), shift).numpy(), golden.shift_round(x, shift))
    for d in [3, 20, 26, 128]:
        np.testing.assert_array_equal(aligned.divide(torch.from_numpy(x), d).numpy(), golden.round_divide(x, d))
    x = rng.integers(-128, 128, (7, 32, 256), dtype=np.int64)
    w = rng.integers(-128, 128, (17, 256), dtype=np.int64)
    np.testing.assert_array_equal(aligned.dot_i8(torch.from_numpy(x), torch.from_numpy(w)).numpy(), x @ w.T)
    with pytest.raises(OverflowError):
        aligned.dot_i8(torch.tensor([[128]]), torch.tensor([[1]]))


def test_independent_nonlinear_and_attention_extremes():
    spec = json.loads(Path('config/numerics.json').read_text())
    rng = np.random.default_rng(9)
    x = rng.integers(-32768, 32768, (2, 17, 128), dtype=np.int64)
    x[0, 0] = 0
    gamma = rng.integers(12000, 20000, 128, dtype=np.int64)
    table = np.rint(1 / np.sqrt(np.arange(1024, 2048) / 1024) * (1 << 30)).astype(np.int64)
    np.testing.assert_array_equal(aligned.norm(torch.from_numpy(x), torch.from_numpy(gamma), torch.from_numpy(table), spec).numpy(), golden.rmsnorm_lut(x, gamma, table, spec))
    knots = np.arange(-4, 5, dtype=np.float64)
    knots = np.rint(knots / (1 + np.exp(-knots)) * 4096).astype(np.int64)
    np.testing.assert_array_equal(aligned.activation(torch.from_numpy(x), torch.from_numpy(knots), spec).numpy(), golden.pwl_activation(x, knots, spec))
    count = spec['exp_negative_limit'] * (1 << spec['exp_input_fraction_bits']) + 1
    exp = np.rint(np.exp(-np.arange(count) / 256) * (1 << 20)).astype(np.int64)
    for n in [1, 17, 32]:
        q, k, v = [rng.integers(-16384, 16384, (2, 4, n, 32), dtype=np.int64) for _ in range(3)]
        actual = aligned.attention(*map(torch.from_numpy, [q, k, v]), torch.from_numpy(exp), spec, 185364).numpy()
        for batch in range(2):
            np.testing.assert_array_equal(actual[batch], golden.online_attention(q[batch], k[batch], v[batch], exp, spec, 185364))


@pytest.mark.parametrize('mode', ['quality', 'balanced', 'energy_saver'])
def test_aligned_batch_independence_complete_trace_and_gradients(mode):
    torch.set_num_threads(1)
    path = Path(f'exports/calibrated/har_{mode}_seed17')
    if not path.exists():
        pytest.skip('Saved export required')
    m = AlignedEncoder(path).eval()
    m.trace_enabled = True
    ref = IntegerEncoder(path, use_native=False)
    rng = np.random.default_rng(42)
    scale = 2. ** (ref.manifest['input_q12_shift'] - 12)
    q = rng.integers(-128, 128, (3, 128, 9), dtype=np.int64)
    # Extreme legal host patterns in addition to arbitrary full-range inputs.
    q[0] = 0
    q[1, ::2], q[1, 1::2] = 127, -128
    with torch.no_grad():
        out = m(torch.from_numpy((q * scale).astype(np.float32)))
    for batch in range(3):
        expected = ref.predict(q[batch])
        np.testing.assert_array_equal(out[batch].numpy() * 4096, expected)
        for name, value in ref.trace.items():
            np.testing.assert_array_equal(m.trace[name][batch].numpy(), value, err_msg=name)
    m.train()
    out_train = m(torch.from_numpy((q * scale).astype(np.float32)))
    torch.testing.assert_close(out_train, out, atol=0, rtol=0)
    out_train.square().mean().backward()
    assert m.network.embedding.weight.grad.abs().sum() > 0
    if mode != 'quality':
        assert m.network.gate.scorer.weight.grad.abs().sum() > 0
