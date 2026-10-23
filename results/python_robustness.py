"""Predetermined perturbations on a reproducible, stratified held-out subset."""
from concurrent.futures import ProcessPoolExecutor
import json
from pathlib import Path
import tempfile
import wave

import numpy as np
import torch

from golden.reference import IntegerEncoder
from model.python_study import ROOT, detailed_metrics, dump, load_job, sha, verify_plan
from model.speech_data import log_mel


def prepare(dataset):
    rng = np.random.default_rng(20261023)
    with np.load(f'data/{dataset}/test.npz') as data:
        x, y = data['x'], data['y']
    manifest = json.loads(Path(f'data/{dataset}/manifest.json').read_text())
    count = 20 if dataset == 'har' else 10
    indices = np.sort(np.concatenate([rng.choice(np.flatnonzero(y == label), min(count, int(np.sum(y == label))), replace=False)
                                      for label in np.unique(y)]))
    clean, labels = x[indices], y[indices]
    variants = {'clean': clean}
    metadata = {'partition': 'test_stratified_subset', 'indices': indices.tolist(), 'rng': 20261023,
                'samples': len(indices), 'not_full_test_accuracy': True}
    if dataset == 'har':
        noise = rng.standard_normal(clean.shape).astype(np.float32)
        variants['noise_sd0.1'] = clean + .1 * noise
        variants['noise_sd0.25'] = clean + .25 * noise
        variants['missing_gyro'] = clean.copy()
        variants['missing_gyro'][:, :, 3:6] = 0.
        metadata['missing_channel_semantics'] = 'zero after train normalization means training mean; not physical raw zero'
    else:
        mean, std = np.array(manifest['mean'], dtype=np.float32), np.array(manifest['std'], dtype=np.float32)
        clips = {k: [] for k in ['snr20', 'snr10', 'gain0.5']}
        clip_counts = {key: 0 for key in clips}
        clean_error = 0.
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'perturbed.wav'
            for index, stored in zip(indices, clean):
                source = Path('data/speech_commands_v0.02') / manifest['splits']['test']['files'][index]
                clean_error = max(clean_error, float(np.max(np.abs((log_mel(source) - mean) / std - stored))))
                with wave.open(str(source), 'rb') as audio:
                    signal = np.frombuffer(audio.readframes(audio.getnframes()), dtype='<i2').astype(np.float64) / 32768.
                padded = np.zeros(16000)
                padded[:min(len(signal), 16000)] = signal[:16000]
                noise = rng.standard_normal(16000)
                noise /= np.sqrt(np.mean(noise ** 2))
                rms = np.sqrt(np.mean(padded ** 2))
                conditions = {'snr20': padded + noise * rms / 10., 'snr10': padded + noise * rms / np.sqrt(10.),
                              'gain0.5': padded * .5}
                for key, values in conditions.items():
                    raw = np.rint(values * 32768.)
                    clip_counts[key] += int(np.sum((raw < -32768) | (raw > 32767)))
                    pcm = np.clip(raw, -32768, 32767).astype('<i2')
                    with wave.open(str(path), 'wb') as output:
                        output.setnchannels(1)
                        output.setsampwidth(2)
                        output.setframerate(16000)
                        output.writeframes(pcm.tobytes())
                    clips[key].append((log_mel(path) - mean) / std)
        if clean_error > 1e-5:
            raise ValueError(f'Recomputed clean frontend mismatch: {clean_error}')
        variants.update({key: np.stack(value) for key, value in clips.items()})
        metadata.update({'clean_frontend_max_error': clean_error, 'pcm_clipped_values': clip_counts,
                         'pcm_values_per_condition': len(indices) * 16000,
                         'noise_definition': 'white Gaussian noise normalized to exact RMS over padded 1s waveform; SNR before PCM clipping/rounding; same noise direction at both SNRs'})
    path = ROOT / 'robustness' / f'{dataset}_inputs.npz'
    path.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(path, labels=labels, indices=indices, **variants)
    metadata['inputs_sha256'] = sha(path)
    dump(path.with_suffix('.json'), metadata)


def run_job(job):
    torch.set_num_threads(1)
    output = ROOT / 'robustness' / (job['name'] + '.json')
    plan_sha = sha(ROOT / 'evaluation_plan.json')
    source = ROOT / 'robustness' / f"{job['dataset']}_inputs.npz"
    if output.exists():
        old = json.loads(output.read_text())
        if old['evaluation_plan_sha256'] != plan_sha or old['inputs_sha256'] != sha(source):
            raise ValueError('Robustness provenance mismatch')
        return job['name'] + ' reused'
    model, checkpoint = load_job(job)
    ref = IntegerEncoder(job['export']) if job['export'] else None
    if ref:
        scale = 2. ** (ref.manifest['input_q12_shift'] - 12)
    manifest = json.loads(Path(f"data/{job['dataset']}/manifest.json").read_text())
    names = manifest.get('labels', ['WALKING', 'WALKING_UPSTAIRS', 'WALKING_DOWNSTAIRS', 'SITTING', 'STANDING', 'LAYING'])
    rows, arrays = {}, {}
    with np.load(source) as inputs, torch.inference_mode():
        y = inputs['labels']
        arrays['labels'] = y
        arrays['indices'] = inputs['indices']
        for condition in inputs.files:
            if condition in ['labels', 'indices']:
                continue
            fp, ip, clipped = [], [], 0
            for window in inputs[condition]:
                fp.append(int(model(torch.from_numpy(window[None]), job['mode']).argmax(-1)[0]))
                if ref:
                    raw = np.rint(window / scale)
                    clipped += int(np.sum((raw < -128) | (raw > 127)))
                    ip.append(int(ref.predict(np.clip(raw, -128, 127).astype(np.int8)).argmax()))
            rows[condition] = {'pytorch': detailed_metrics(y, fp, names)}
            arrays[condition + '_pytorch'] = np.array(fp)
            if ref:
                arrays[condition + '_integer'] = np.array(ip)
                rows[condition].update({'integer': detailed_metrics(y, ip, names), 'input_clipped_values': clipped})
    np.savez_compressed(output.with_suffix('.npz'), **arrays)
    dump(output, {'name': job['name'], 'dataset': job['dataset'], 'mode_name': job['mode_name'], 'seed': job['seed'],
                  'evaluation_plan_sha256': plan_sha, 'inputs_sha256': sha(source),
                  'predictions_sha256': sha(output.with_suffix('.npz')), 'conditions': rows})
    return job['name'] + ' complete'


def main():
    plan = json.loads((ROOT / 'evaluation_plan.json').read_text())
    verify_plan(plan)
    for dataset in ['har', 'speech']:
        if not (ROOT / 'robustness' / f'{dataset}_inputs.npz').exists():
            prepare(dataset)
    jobs = [j for j in plan['jobs'] if j['mode_name'] in ['fp32', 'fp32_control', 'quality', 'balanced', 'energy_saver']]
    with ProcessPoolExecutor(max_workers=3) as pool:
        for result in pool.map(run_job, jobs):
            print(result, flush=True)


if __name__ == '__main__':
    main()
