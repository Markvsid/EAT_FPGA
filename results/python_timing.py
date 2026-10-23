"""Run after evaluation workers finish; isolated CPU software timing only."""
import json
import platform
import subprocess
import time

import numpy as np
import torch

from golden.reference import IntegerEncoder
from model.python_study import ROOT, dump, load_job, sha, verify_plan


def benchmark(call, inputs):
    for i in range(20):
        call(inputs[i % len(inputs)])
    values = []
    for i in range(200):
        started = time.perf_counter_ns()
        call(inputs[i % len(inputs)])
        values.append((time.perf_counter_ns() - started) / 1e6)
    return {'warmup_calls': 20, 'timed_calls': 200, 'median_ms': float(np.median(values)),
            'p95_ms': float(np.percentile(values, 95)), 'samples_ms': values}


def main():
    torch.set_num_threads(1)
    torch.set_num_interop_threads(1)
    plan = json.loads((ROOT / 'evaluation_plan.json').read_text())
    verify_plan(plan)
    rows = []
    for job in plan['jobs']:
        model, _ = load_job(job)
        with np.load(f"data/{job['dataset']}/train.npz") as data:
            x = data['x'][:32]
        inputs = [torch.from_numpy(a[None]) for a in x]
        with torch.inference_mode():
            floating = benchmark(lambda a: model(a, job['mode']), inputs)
        row = {'name': job['name'], 'dataset': job['dataset'], 'mode_name': job['mode_name'], 'seed': job['seed'], 'pytorch': floating}
        if job['export']:
            ref = IntegerEncoder(job['export'])
            scale = 2. ** (ref.manifest['input_q12_shift'] - 12)
            inputs = np.clip(np.rint(x / scale), -128, 127).astype(np.int8)
            row['integer_reference'] = benchmark(ref.predict, inputs)
            row['native_kernel'] = ref.native.metadata if ref.native else None
        rows.append(row)
        print(job['name'], 'timed', flush=True)
    dump(ROOT / 'timing.json', {'evaluation_plan_sha256': sha(ROOT / 'evaluation_plan.json'),
         'platform': platform.platform(), 'machine': platform.machine(),
         'cpu': subprocess.check_output(['sysctl', '-n', 'machdep.cpu.brand_string'], text=True).strip(),
         'python': platform.python_version(), 'torch': torch.__version__, 'numpy': np.__version__,
         'threads': 1, 'batch_size': 1, 'input_partition': 'train_first32',
         'boundary': 'forward call on preprocessed, preloaded inputs; excludes frontend, input quantization, I/O and model loading; integer includes checks and trace copies',
         'limitations': 'single local timing session; no FPGA, Arm, energy, throughput or hardware speedup inference; CPU frequency/thermal state uncontrolled', 'rows': rows})


if __name__ == '__main__':
    main()
