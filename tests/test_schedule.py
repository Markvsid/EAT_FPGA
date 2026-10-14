import json
from pathlib import Path

from architecture.schedule import gemm, schedule


def test_tail_occupancy_and_no_assumed_w4_packing_speedup():
    h = json.loads(Path("config/hardware_candidate.json").read_text())
    full = gemm(32, 128, 128, h)
    tail = gemm(26, 128, 128, h)
    low_precision = gemm(32, 128, 128, h, weight_bits=4)
    assert full["tail_occupancy"] == 1
    assert tail["tail_occupancy"] == 26 / 32
    assert full["array_compute_cycles"] == low_precision["array_compute_cycles"]
    assert low_precision["weight_bytes"] == full["weight_bytes"] // 2


def test_schedule_accounts_for_summary_and_extended_state():
    c = json.loads(Path("config/har.json").read_text())
    h = json.loads(Path("config/hardware_candidate.json").read_text())
    actual = schedule(c, c["modes"]["balanced"], h)
    assert actual["after_gate"] == 26
    assert any(o["name"] == "summary_division" for o in actual["operators"])
    assert actual["memory_payload_bytes"]["pingpong_state"] == 2 * 32 * 128 * 3
    assert actual["physical_banking_fit_proven"] is False
