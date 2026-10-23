"""New validation-selected aligned QAT experiment; preserves the original study."""
import argparse
from concurrent.futures import ProcessPoolExecutor
from datetime import datetime, timezone
import json
import random
import subprocess
import time
from pathlib import Path

import numpy as np
import torch
from torch.utils.data import DataLoader, TensorDataset

from golden.export_aligned import export
from model.aligned import AlignedEncoder
from model.python_study import dump, sha
from model.train import metrics

ROOT = Path('results/alignment_study')


def freeze():
    if (ROOT / 'training_plan.json').exists():
        raise FileExistsError('Do not overwrite the experiment plan')
    jobs = []
    for dataset in ['har', 'speech']:
        for mode in ['quality', 'balanced', 'energy_saver']:
            for seed in [17, 29, 43]:
                name = f'{dataset}_{mode}_seed{seed}'
                export_path = Path('exports/calibrated') / name
                m = json.loads((export_path / 'manifest.json').read_text())
                jobs.append({'name': name, 'dataset': dataset, 'mode': mode, 'seed': seed,
                             'epochs': 3 if dataset == 'har' else 1,
                             'initial_export': str(export_path), 'initial_checkpoint': m['checkpoint_path'],
                             'initial_checkpoint_sha256': sha(m['checkpoint_path']),
                             'initial_manifest_sha256': sha(export_path / 'manifest.json'),
                             'initial_constants_sha256': sha(export_path / 'constants.npz')})
    paths = [Path(p) for p in ['model/aligned.py', 'model/aligned_arithmetic.py', 'model/alignment_study.py',
                               'model/network.py', 'model/train.py', 'golden/export_aligned.py',
                               'golden/reference.py', 'golden/arithmetic.py', 'golden/alignment_evaluate.py']]
    plan = {'created_utc': datetime.now(timezone.utc).isoformat(), 'experiment': 'alignment_v1',
            'git_parent': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
            'template_sha256': sha('Report_Template/FPGA_Energy_Efficient_Transformer_Research_Plan_2-Month_Extended.docx'),
            'source_sha256': {str(p): sha(p) for p in paths},
            'data_sha256': {str(p): sha(p) for d in ['har', 'speech'] for p in
                            [Path(f'data/{d}/train.npz'), Path(f'data/{d}/validation.npz'), Path(f'data/{d}/test.npz'), Path(f'data/{d}/manifest.json')]},
            'training': {'batch_size': 128, 'learning_rate': .00003, 'weight_decay': .01, 'optimizer': 'AdamW',
                         'schedule': 'cosine over declared epochs', 'gradient_clip': 1., 'loss': 'primary cross entropy only, no auxiliary head',
                         'device': 'cpu', 'threads_per_worker': 1, 'deterministic_algorithms': True,
                         'selection': 'highest validation accuracy including epoch0; strict improvement; earliest wins ties',
                         'calibration': 'existing training-only input/linear/QKV exponents, weight channel scales and tables retained unchanged',
                         'gradient': 'exact forward custom autograd, identity straight-through quantization and float RMSNorm/PWL/materialized-attention surrogates; scorer STE on retained features',
                         'scope': 'independent modes, no new shared-weight family'},
            'evaluation': {'validation': 'complete partition for every checkpoint/mode; exact integer trace and group identity check after training',
                           'test': 'only after all full validation equivalence checks pass; unchanged protocol for all18 settings',
                           'test_disclosure': 'test sets were observed in study0633422; subsequent results are not untouched-test evidence',
                           'acceptance': 'zero integer LSB error at every reference trace point and zero changed predictions/groups',
                           'batch_independence': 'fixed scales; validation/test comparisons use aligned batches64 against per-example NumPy reference'},
            'jobs': jobs}
    dump(ROOT / 'training_plan.json', plan)
    print('Frozen18 jobs', sha(ROOT / 'training_plan.json'), flush=True)


def verify(plan):
    for path, checksum in {**plan['source_sha256'], **plan['data_sha256']}.items():
        if sha(path) != checksum:
            raise ValueError('Frozen source/data changed: ' + path)
    for job in plan['jobs']:
        for path, key in [(job['initial_checkpoint'], 'initial_checkpoint_sha256'),
                          (Path(job['initial_export']) / 'manifest.json', 'initial_manifest_sha256'),
                          (Path(job['initial_export']) / 'constants.npz', 'initial_constants_sha256')]:
            if sha(path) != job[key]:
                raise ValueError('Initial model changed: ' + job['name'])


def batches(dataset, partition, batch, shuffle, seed):
    with np.load(f'data/{dataset}/{partition}.npz') as data:
        tensors = TensorDataset(torch.from_numpy(data['x']), torch.from_numpy(data['y']))
    return DataLoader(tensors, batch_size=batch, shuffle=shuffle, num_workers=0,
                      generator=torch.Generator().manual_seed(seed))


@torch.no_grad()
def validation(model, loader):
    model.eval()
    y, pred = [], []
    for x, label in loader:
        y.extend(label.tolist())
        pred.extend(model(x).argmax(-1).tolist())
    return metrics(y, pred, model.config['classes']), np.array(pred, dtype=np.int64)


def train_job(job):
    plan = json.loads((ROOT / 'training_plan.json').read_text())
    plan_sha = sha(ROOT / 'training_plan.json')
    out = ROOT / 'runs' / job['name']
    if (out / 'metrics.json').exists():
        saved = json.loads((out / 'metrics.json').read_text())
        if saved['plan_sha256'] != plan_sha or saved['checkpoint_sha256'] != sha(out / 'best.pt'):
            raise ValueError('Existing training provenance mismatch')
        return job['name'] + ' reused'
    if out.exists():
        raise FileExistsError('Incomplete run requires explicit recovery: ' + str(out))
    out.mkdir(parents=True)
    random.seed(job['seed'])
    np.random.seed(job['seed'])
    torch.manual_seed(job['seed'])
    torch.set_num_threads(1)
    torch.set_float32_matmul_precision('highest')
    torch.use_deterministic_algorithms(True)
    model = AlignedEncoder(job['initial_export'])
    train = batches(job['dataset'], 'train', plan['training']['batch_size'], True, job['seed'])
    val = batches(job['dataset'], 'validation', 128, False, job['seed'])
    optimizer = torch.optim.AdamW(model.parameters(), lr=plan['training']['learning_rate'], weight_decay=plan['training']['weight_decay'])
    schedule = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=job['epochs'])
    initial, initial_pred = validation(model, val)
    previous = Path('results/integer/calibrated') / job['name'] / 'predictions.npz'
    with np.load(previous) as data:
        if not np.array_equal(initial_pred, data['integer']):
            raise ValueError('Epoch0 does not reproduce prior complete validation predictions')
    best, selected_epoch = initial['accuracy'], 0
    def save(epoch, score):
        torch.save({'model': model.network.state_dict(), 'config': model.config, 'seed': job['seed'],
                    'mode': job['mode'], 'execution_mode': model.mode, 'epoch': epoch, 'validation': score,
                    'numeric_status': 'aligned_forward_with_surrogate_gradients', 'alignment_plan_sha256': plan_sha}, out / 'best.tmp.pt')
        (out / 'best.tmp.pt').replace(out / 'best.pt')
    save(0, initial)
    dump(out / 'manifest.json', {'job': job, 'plan_sha256': plan_sha, 'initial_validation': initial,
                                'initial_full_validation_prediction_agreement_with_existing_integer': True,
                                'torch': torch.__version__, 'numpy': np.__version__})
    print(job['name'], 'epoch0', initial['accuracy'], flush=True)
    history = []
    for epoch in range(1, job['epochs'] + 1):
        model.train()
        started, total_loss = time.perf_counter(), 0.
        for index, (x, y) in enumerate(train):
            optimizer.zero_grad(set_to_none=True)
            loss = F_cross_entropy(model(x), y)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), plan['training']['gradient_clip'])
            optimizer.step()
            total_loss += float(loss.detach()) * len(y)
            if (index + 1) % 200 == 0:
                print(job['name'], 'epoch', epoch, 'batch', index + 1, '/', len(train), flush=True)
        schedule.step()
        score, pred = validation(model, val)
        history.append({'epoch': epoch, 'training_loss': total_loss / len(train.dataset), 'validation': score,
                        'seconds': time.perf_counter() - started})
        dump(out / 'history.json', history)
        if score['accuracy'] > best:
            best, selected_epoch = score['accuracy'], epoch
            save(epoch, score)
        print(job['name'], 'epoch', epoch, 'validation', score['accuracy'], 'seconds', history[-1]['seconds'], flush=True)
    checkpoint = torch.load(out / 'best.pt', map_location='cpu', weights_only=True)
    model.network.load_state_dict(checkpoint['model'])
    export_path = ROOT / 'exports' / job['name']
    export(model, out / 'best.pt', export_path, plan_sha)
    np.savez_compressed(out / 'initial_validation_predictions.npz', predictions=initial_pred)
    dump(out / 'metrics.json', {'name': job['name'], 'plan_sha256': plan_sha, 'checkpoint_sha256': sha(out / 'best.pt'),
                               'selected_epoch': selected_epoch, 'initial_validation': initial,
                               'validation': checkpoint['validation'], 'history': history,
                               'export_manifest_sha256': sha(export_path / 'manifest.json'),
                               'export_constants_sha256': sha(export_path / 'constants.npz')})
    return job['name'] + ' complete'


def F_cross_entropy(logits, labels):
    return torch.nn.functional.cross_entropy(logits, labels)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['freeze', 'train'])
    p.add_argument('--workers', type=int, default=3)
    p.add_argument('--dataset', choices=['har', 'speech', 'all'], default='all')
    p.add_argument('--mode', choices=['quality', 'balanced', 'energy_saver', 'all'], default='all')
    args = p.parse_args()
    if args.action == 'freeze':
        freeze()
        return
    plan = json.loads((ROOT / 'training_plan.json').read_text())
    verify(plan)
    jobs = [j for j in plan['jobs'] if args.dataset in ['all', j['dataset']] and args.mode in ['all', j['mode']]]
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        for value in pool.map(train_job, jobs):
            print(value, flush=True)


if __name__ == '__main__':
    main()
