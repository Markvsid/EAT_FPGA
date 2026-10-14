import ctypes
import hashlib
import json
import platform
from pathlib import Path

import numpy as np


class NativeKernel:
    def __init__(self):
        root = Path(__file__).resolve().parent
        source = root / "dot_i8.c"
        metadata = json.loads((root / "build_metadata.json").read_text())
        library = root / ("libeat_dot.dylib" if platform.system() == "Darwin" else "libeat_dot.so")
        if metadata["source_sha256"] != hashlib.sha256(source.read_bytes()).hexdigest():
            raise ValueError("Native kernel source changed; rebuild before use")
        if metadata["library_sha256"] != hashlib.sha256(library.read_bytes()).hexdigest():
            raise ValueError("Native kernel binary checksum mismatch")
        self.metadata = metadata
        self.library = ctypes.CDLL(str(library))
        self.dot = self.library.eat_dot_i8
        i8 = np.ctypeslib.ndpointer(dtype=np.int8, flags="C_CONTIGUOUS")
        i64 = np.ctypeslib.ndpointer(dtype=np.int64, flags="C_CONTIGUOUS")
        self.dot.argtypes = [i8, i8, i64, ctypes.c_size_t, ctypes.c_size_t, ctypes.c_size_t]
        self.dot.restype = ctypes.c_int

    def matmul(self, x, weights):
        x, weights = np.asarray(x), np.asarray(weights)
        if x.ndim < 1 or weights.ndim != 2 or x.shape[-1] != weights.shape[-1]:
            raise ValueError("Invalid matrix shapes")
        if not np.issubdtype(x.dtype, np.integer) or not np.issubdtype(weights.dtype, np.integer):
            raise ValueError("Integer matrix operands required")
        if np.any(x < -128) or np.any(x > 127) or np.any(weights < -128) or np.any(weights > 127):
            raise ValueError("Signed INT8 operands required")
        reduction = x.shape[-1]
        a = np.ascontiguousarray(x.reshape(-1, reduction), dtype=np.int8)
        w = np.ascontiguousarray(weights, dtype=np.int8)
        output = np.empty((len(a), len(w)), dtype=np.int64)
        if self.dot(a, w, output, len(a), len(w), reduction) != 0:
            raise ValueError("Native kernel rejected matrix dimensions")
        return output.reshape(x.shape[:-1] + (len(w),))
