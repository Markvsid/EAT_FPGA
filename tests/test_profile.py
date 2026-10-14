import json
from pathlib import Path

from architecture.profile import profile


def test_rts_counts_and_matched_budget():
    c = json.loads(Path("config/har.json").read_text())
    base = {"weight_bits": 4, "keep_groups": 4, "rts": True, "exit_block": 4}
    rts = profile(c, base)
    matched = profile(c, {**base, "keep_groups": 5, "rts": False})
    assert rts["tokens_after_gate"] == matched["tokens_after_gate"] == 20
    a = {o["operator"]: o["macs"] for o in rts["operators"]}
    b = {o["operator"]: o["macs"] for o in matched["operators"]}
    assert a["block2_projections"] == b["block2_projections"]
    assert rts["executed_macs"] > matched["executed_macs"]  # Summary overhead remains counted.


def test_dense_encoder_weight_count():
    c = json.loads(Path("config/har.json").read_text())
    p = profile(c)
    assert p["payload_bytes_only"]["encoder_matrix_weights"] == 524288
    assert p["executed_ops_mac_equals_two"] == 2 * p["executed_macs"]
