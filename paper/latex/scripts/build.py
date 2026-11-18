"""Build the paper with a real LaTeX engine and retain diagnostics in build/."""
import argparse
import json
import shutil
import subprocess
from pathlib import Path
from evidence import PROJECT, REPOSITORY


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', choices=['auto', 'tectonic', 'latexmk'], default='auto')
    args = parser.parse_args()
    build = PROJECT / 'build'
    build.mkdir(exist_ok=True)
    subprocess.run([__import__('sys').executable, 'scripts/check_project.py'], cwd=PROJECT, check=True)
    local = REPOSITORY / '.tools/tectonic/0.17.0/tectonic'
    tectonic = shutil.which('tectonic') or (str(local) if local.is_file() else None)
    latexmk = shutil.which('latexmk')
    if args.engine == 'latexmk' or (args.engine == 'auto' and not tectonic and latexmk):
        if not latexmk:
            raise SystemExit('Install latexmk and a TeX distribution with acmart, or use Tectonic.')
        command = [latexmk, '-xelatex', '-interaction=nonstopmode', '-halt-on-error', '-outdir=build', 'main.tex']
    else:
        if not tectonic:
            raise SystemExit('Install Tectonic 0.17.0 or latexmk/TeX Live; see README.md.')
        command = [tectonic, 'main.tex', '--outdir', 'build', '--keep-logs', '--keep-intermediates', '--synctex']
    with (build / 'compiler.log').open('w') as log:
        result = subprocess.run(command, cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        print((build / 'compiler.log').read_text()[-10000:])
        raise SystemExit(result.returncode)
    log = (build / 'main.log').read_text(errors='replace')
    for bad in ['There were undefined references', 'There were undefined citations', 'Citation `', 'LaTeX Error:']:
        if bad in log:
            raise SystemExit('Unresolved LaTeX diagnostic: ' + bad)
    pdf = build / 'main.pdf'
    assert pdf.is_file() and pdf.stat().st_size > 1000
    (build / 'build_report.json').write_text(json.dumps({
        'status': 'compiled', 'engine': subprocess.check_output([command[0], '--version'], text=True).splitlines()[0],
        'acmart': next((line.strip() for line in log.splitlines() if 'Document Class: acmart' in line), 'see main.log'),
        'intentional_draft_metadata': True, 'pdf': 'main.pdf',
        'overfull_boxes': log.count('Overfull \\hbox'),
    }, indent=2) + '\n')
    print('Built', pdf)


if __name__ == '__main__':
    main()
