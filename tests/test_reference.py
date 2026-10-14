import json
from pathlib import Path

import numpy as np
import pytest
import torch
from torch.nn import functional as F

from model.network import Encoder, TokenGate, streaming_attention
from model.train import metrics


@pytest.mark.parametrize("n,tile", [(1, 1), (17, 8), (32, 4)])
def test_streamed_attention_matches_dense(n, tile):
    torch.manual_seed(7)
    q, k, v = [torch.randn(2, 4, n, 32) for _ in range(3)]
    actual = streaming_attention(q, k, v, tile)
    expected = F.scaled_dot_product_attention(q, k, v)
    torch.testing.assert_close(actual, expected, atol=2e-6, rtol=2e-5)


def test_gate_ties_order_summary_and_gradient():
    gate = TokenGate(2, 4)
    with torch.no_grad():
        gate.scorer.weight.zero_()
        gate.scorer.bias.zero_()
    x = torch.arange(24, dtype=torch.float32).reshape(1, 12, 2)
    gate.eval()
    torch.testing.assert_close(gate(x, 1, False), x[:, :4])
    expected = torch.cat([x[:, :4], x[:, 4:8].mean(1, keepdim=True), x[:, 8:12].mean(1, keepdim=True)], dim=1)
    torch.testing.assert_close(gate(x, 1, True), expected)
    gate.train()
    gate(x, 1, False).sum().backward()
    assert gate.scorer.weight.grad.abs().sum() > 0


def test_complete_encoder_and_runtime_modes():
    c = json.loads(Path("config/har.json").read_text())
    torch.manual_seed(9)
    model = Encoder(c).eval()
    x = torch.randn(2, 128, 9)
    with torch.no_grad():
        torch.testing.assert_close(model(x), model(x, stream=True), atol=3e-6, rtol=2e-5)
        for mode in c["modes"].values():
            output = model(x, mode)
            assert output.shape == (2, 6) and output.isfinite().all()


@pytest.mark.parametrize("override", [{"keep_groups": 9}, {"weight_bits": 2}, {"exit_block": 3}])
def test_invalid_modes_do_not_silently_run_dense(override):
    c = json.loads(Path("config/har.json").read_text())
    model = Encoder(c).eval()
    with pytest.raises(ValueError):
        model(torch.zeros(1, 128, 9), {**c["modes"]["quality"], **override})


def test_metric_includes_absent_classes():
    result = metrics([0, 0, 1], [0, 1, 1], 3)
    assert result["accuracy"] == pytest.approx(2 / 3)
    assert result["macro_f1"] == pytest.approx(4 / 9)


def test_real_dataset_subject_separation():
    path = Path("data/har/manifest.json")
    if not path.exists():
        pytest.skip("Run model.data to test the actual HAR partition")
    m = json.loads(path.read_text())
    subjects = [set(s["subjects"]) for s in m["splits"].values()]
    assert all(not a & b for i, a in enumerate(subjects) for b in subjects[i + 1:])
    with np.load("data/har/train.npz") as data:
        np.testing.assert_allclose(data["x"].mean((0, 1), dtype=np.float64), 0, atol=1e-6)
