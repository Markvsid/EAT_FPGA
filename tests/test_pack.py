import numpy as np
import pytest

from golden.pack import pack_signed_nibbles, unpack_signed_nibbles


def test_signed_nibble_layout_and_odd_tail():
    values = np.array([-8, 7, -1, 0, 3])
    blob = pack_signed_nibbles(values)
    assert blob == bytes([0x78, 0x0f, 0x03])
    np.testing.assert_array_equal(unpack_signed_nibbles(blob, len(values)), values)
    with pytest.raises(ValueError):
        pack_signed_nibbles([8])
