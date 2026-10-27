"""Archive passing evidence only after checking its tested RTL fingerprints."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
REPORTS = {
    'functional/primitive_results.json': 'primitive_results.json',
    'services/service_results.json': 'service_results.json',
    'arbiter/arbiter_results.json': 'arbiter_results.json',
    'tensor/tensor_results.json': 'tensor_results.json',
    'vector/vector_results.json': 'vector_results.json',
    'attention/attention_results.json': 'attention_results.json',
    'gate/gate_results.json': 'gate_results.json',
    'qkv/qkv_results.json': 'qkv_results.json',
    'images/image_audit.json': 'image_audit.json',
    'loader/loader_results.json': 'loader_results.json',
    'resident_images/resident_image_results.json': 'resident_image_results.json',
    'registers/register_results.json': 'register_results.json',
    'streams/stream_results.json': 'stream_results.json',
    'synthesis_frontend/synthesis_frontend_results.json': 'primitive_synthesis_results.json',
    'integration_synthesis/synthesis_frontend_results.json': 'integration_synthesis_results.json',
    'structural_checks.json': 'structural_checks.json',
    'numeric_width_audit.json': 'numeric_width_audit.json',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--core-build', action='append', default=[])
    parser.add_argument('--system-build', action='append', default=[])
    parser.add_argument('--output', default='implementation_v2')
    args = parser.parse_args()
    names = [args.output, *args.core_build, *args.system_build]
    if any(not name or Path(name).name != name or name in ('.', '..') for name in names):
        raise ValueError('Use simple archive/build directory names')
    sources = dict(REPORTS)
    for name in args.core_build:
        sources[name + '/core_results.json'] = name + '_results.json'
    for name in args.system_build:
        sources[name + '/system_results.json'] = name + '_results.json'
    if not args.core_build or not args.system_build:
        raise ValueError('Select complete core and platform evidence explicitly')
    loaded = {}
    for source, target in sources.items():
        path = ROOT / 'rtl/build' / source
        report = json.loads(path.read_text())
        if report['status'] not in ('passed', 'analysis_elaboration_passed', 'export_boundary_width_checks_passed_not_rtl_equivalence'):
            raise ValueError('Unpassed evidence: ' + source)
        for tested, expected in report.get('source_sha256', {}).items():
            if digest(ROOT / tested) != expected:
                raise ValueError('Stale source fingerprint in ' + source + ': ' + tested)
        if 'schema_sha256' in report:
            assert digest(ROOT / 'rtl/config/image_schema.json') == report['schema_sha256']
            assert digest(ROOT / 'rtl/scripts/export_image.py') == report['exporter_sha256']
        loaded[target] = path
    output = ROOT / 'rtl/validation' / args.output
    output.mkdir(parents=True, exist_ok=True)
    for target, source in loaded.items():
        shutil.copyfile(source, output / target)
    for name in [*args.core_build, *args.system_build, 'integration_synthesis']:
        for path in (ROOT / 'rtl/build' / name).glob('*.log'):
            dest = output / 'logs' / name / path.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, dest)
    reproduction = [p for p in (ROOT / 'rtl').rglob('*') if p.is_file()
                    and not {'build', 'validation', '__pycache__'} & set(p.relative_to(ROOT / 'rtl').parts)]
    (output / 'evidence_index.json').write_text(json.dumps({
        'status': 'passed', 'captured_utc': datetime.now(timezone.utc).isoformat(),
        'reports': {name: digest(output / name) for name in sorted(loaded)},
        'rtl_and_test_source_sha256': {str(p.relative_to(ROOT)): digest(p) for p in sorted(reproduction)},
        'limits': 'Listed simulations and GHDL synthesis only; no Vivado, board, full-dataset RTL, latency or power result.'
    }, indent=2) + '\n')
    print('Archived', len(loaded), 'current passing reports:', output)


if __name__ == '__main__':
    main()
