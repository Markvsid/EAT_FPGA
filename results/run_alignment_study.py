"""Ordered study phases; stops on training or exact-equivalence failure."""
from datetime import datetime, timezone
import subprocess
import sys

from model.alignment_study import ROOT
from model.python_study import dump, sha


def main():
    steps = [
        ['model.alignment_study', 'train', '--dataset', 'har', '--mode', 'quality'],
        ['golden.alignment_evaluate', '--partition', 'validation', '--dataset', 'har', '--mode', 'quality'],
        ['model.alignment_study', 'train', '--dataset', 'har'],
        ['golden.alignment_evaluate', '--partition', 'validation', '--dataset', 'har'],
        ['model.alignment_study', 'train', '--dataset', 'speech'],
        ['golden.alignment_evaluate', '--partition', 'validation', '--dataset', 'speech'],
        ['golden.alignment_evaluate', '--partition', 'test'],
    ]
    history = []
    for command in steps:
        row = {'command': command, 'started_utc': datetime.now(timezone.utc).isoformat()}
        print('PHASE', row, flush=True)
        subprocess.run([sys.executable, '-m', *command], check=True)
        row['finished_utc'] = datetime.now(timezone.utc).isoformat()
        history.append(row)
        dump(ROOT / 'phases.json', {'source_sha256': sha(__file__), 'steps': history})
    print('All aligned study phases complete', flush=True)


if __name__ == '__main__':
    main()
