import pytest

from host.analyze_measurements import analyze


def metadata():
    return {"batch_size": 1, "power_boundary": "whole_board", "clock_hz": 1,
            "git_commit": "test", "bitstream_sha256": "test", "configuration_sha256": "test",
            "instrument": "unit-test fixture", "instrument_resolution_w": 0.1, "warmup_inferences": 0}


def test_integrated_energy_includes_gaps_and_interpolated_boundaries():
    # A linear 2->6 W trace over two seconds. Window [.5, 1.5] integrates 4 J.
    result = analyze([0, 1, 2], [2, 4, 6], [.5, 1.2], [1., 1.5], metadata())
    assert result["integrated_whole_board_joules"] == pytest.approx(4)
    assert result["whole_board_joules_per_inference"] == pytest.approx(2)
    assert result["confidence_interval"] is None


def test_power_extrapolation_and_overlap_rejected():
    with pytest.raises(ValueError, match="cover"):
        analyze([0, 1], [3, 3], [0], [2], metadata())
    with pytest.raises(ValueError, match="nonoverlapping"):
        analyze([0, 3], [3, 3], [0, 1], [2, 3], metadata())
