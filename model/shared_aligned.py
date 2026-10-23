"""Three aligned modes backed by one actual PyTorch parameter set.

Calibration and quantized constant images remain mode-specific. Sharing FP32
parameters does not imply that every deployed weight byte can be shared.
"""
import json
from pathlib import Path

import torch
from torch import nn

from model.aligned import AlignedEncoder
from model.python_study import sha


MODES = ('quality', 'balanced', 'energy_saver')


class SharedAlignedEncoder(nn.Module):
    def __init__(self, exports):
        super().__init__()
        if set(exports) != set(MODES):
            raise ValueError('Exactly Quality, Balanced and Energy-Saver exports required')
        manifests = {k: json.loads((Path(v) / 'manifest.json').read_text()) for k, v in exports.items()}
        checkpoints = {m['checkpoint_sha256'] for m in manifests.values()}
        if len(checkpoints) != 1:
            raise ValueError('A shared family requires one identical checkpoint')
        self.branches = nn.ModuleDict()
        shared = None
        for mode in MODES:
            manifest = manifests[mode]
            if manifest['mode'] != manifest['config']['modes'][mode]:
                raise ValueError('Mode/export mismatch')
            if sha(manifest['checkpoint_path']) != manifest['checkpoint_sha256']:
                raise ValueError('Checkpoint checksum mismatch')
            branch = AlignedEncoder(exports[mode])
            if shared is None:
                shared = branch.network
                self.config = branch.config
            else:
                if branch.config != self.config:
                    raise ValueError('Shared family configuration mismatch')
                for key, tensor in shared.state_dict().items():
                    if not torch.equal(tensor, branch.network.state_dict()[key]):
                        raise ValueError('Checkpoint tensors differ: ' + key)
                branch.network = shared
            self.branches[mode] = branch
        self.checkpoint_sha256 = next(iter(checkpoints))

    @property
    def network(self):
        return self.branches['quality'].network

    def branch(self, mode):
        if mode not in MODES:
            raise ValueError('Unsupported runtime mode: ' + str(mode))
        return self.branches[mode]

    def forward(self, x, mode='quality'):
        return self.branch(mode)(x)

    def shared_state_dict(self):
        """Serialize parameters once; nn.Module.state_dict includes alias paths."""
        return self.network.state_dict()
