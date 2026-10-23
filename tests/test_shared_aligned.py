from pathlib import Path

import pytest
import torch

from model.aligned import AlignedEncoder
from model.shared_aligned import MODES, SharedAlignedEncoder


def exports(seed=17):
    return {m: f'exports/joint/har_joint_{m}_seed{seed}' for m in MODES}


def test_shared_parameters_and_mode_switches():
    if not Path(exports()['quality']).exists():
        pytest.skip('Saved joint exports required')
    torch.set_num_threads(1)
    family = SharedAlignedEncoder(exports()).eval()
    assert len({id(family.branch(m).network) for m in MODES}) == 1
    assert sum(p.numel() for p in family.parameters()) == sum(p.numel() for p in family.network.parameters())
    assert set(family.shared_state_dict()) == set(family.network.state_dict())
    x = torch.randn(2, 128, 9)
    with torch.inference_mode():
        quality = family(x).clone()
        for mode in ['energy_saver', 'balanced', 'quality']:
            standalone = AlignedEncoder(exports()[mode]).eval()
            torch.testing.assert_close(family(x, mode), standalone(x), atol=0, rtol=0)
        torch.testing.assert_close(family(x), quality, atol=0, rtol=0)
    with pytest.raises(ValueError):
        family(x, 'unsupported')


def test_reject_independent_checkpoints_as_shared():
    paths = {m: f'exports/calibrated/har_{m}_seed17' for m in MODES}
    if not Path(paths['quality']).exists():
        pytest.skip('Saved exports required')
    with pytest.raises(ValueError, match='identical checkpoint'):
        SharedAlignedEncoder(paths)
