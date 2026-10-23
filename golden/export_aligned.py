"""Export trained parameters with the exact existing scales and tables retained."""
import copy
from pathlib import Path

import numpy as np

from model.python_study import dump, sha


def export(model, checkpoint, output, plan_sha):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    np.savez_compressed(output / 'constants.npz', **model.export_constants())
    manifest = copy.deepcopy(model.manifest)
    manifest.update({'status': 'aligned_qat_candidate_not_hardware_validated',
                     'checkpoint_path': str(checkpoint), 'checkpoint_sha256': sha(checkpoint),
                     'constants_sha256': sha(output / 'constants.npz'),
                     'alignment_plan_sha256': plan_sha,
                     'parameter_quantization': 'FP32 parameter/FP32 frozen channel-scale division, nearest-even; fixed Q24 multiplier',
                     'calibration_policy': 'unchanged from initial training-only export; no recalibration'})
    dump(output / 'manifest.json', manifest)
    return manifest
