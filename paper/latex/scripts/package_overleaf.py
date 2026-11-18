"""Create a small uploadable project; do not export research data or build files."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile
from evidence import PROJECT


def main():
    subprocess.run([sys.executable, 'scripts/check_project.py'], cwd=PROJECT, check=True)
    build = PROJECT / 'build'
    build.mkdir(exist_ok=True)
    target = build / 'EAT_FPGA_Lite_TRETS_Overleaf.zip'
    paths = sorted(p for p in PROJECT.rglob('*') if p.is_file()
                   and not {'build', '__pycache__', '.DS_Store'} & set(p.relative_to(PROJECT).parts)
                   and not p.name.startswith('~$')
                   and not (p.parent == PROJECT and (p.suffix in ['.aux', '.bbl', '.blg', '.log', '.out', '.fls', '.xdv', '.toc', '.bcf'] or p.name in ['main.pdf', 'main.synctex.gz', 'main.fdb_latexmk', 'main.run.xml'])))
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in paths:
            info = zipfile.ZipInfo(path.relative_to(PROJECT).as_posix(), date_time=(2026, 11, 18, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes())
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert 'main.tex' in archive.namelist()
        assert all(not name.startswith('/') and '..' not in Path(name).parts for name in archive.namelist())
    (build / 'package_report.json').write_text(json.dumps({
        'status': 'packaged', 'files': len(paths), 'bytes': target.stat().st_size,
        'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
        'main_document': 'main.tex',
    }, indent=2) + '\n')
    print('Overleaf package:', target)


if __name__ == '__main__':
    main()
