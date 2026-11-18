"""Check portable source, generated evidence and optional submission readiness."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from evidence import PROJECT, REPOSITORY, accuracy_table, rtl_table


def uncomment(text):
    return re.sub(r'(?<!\\)%[^\n]*', '', text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--submission', action='store_true', help='Also reject all authoring placeholders and draft-only options')
    args = parser.parse_args()
    source = {p.relative_to(PROJECT).as_posix(): p.read_text() for p in PROJECT.rglob('*.tex') if 'build' not in p.relative_to(PROJECT).parts}
    main = source['main.tex']
    class_options = re.search(r'\\documentclass\[([^]]+)\]\{acmart\}', main)
    assert class_options and 'acmsmall' in class_options[1].split(',')
    assert r'\acmJournal{TRETS}' in main
    for name, content in source.items():
        for target in re.findall(r'\\input\{([^}]+)\}', uncomment(content)):
            path = PROJECT / (target if Path(target).suffix else target + '.tex')
            assert path.is_file(), (name, target)
        assert not re.search(r'\\(?:usepackage(?:\[[^]]*\])?\{(?:geometry|fullpage|times)\}|setlength\{\\(?:textwidth|textheight|oddsidemargin))', uncomment(content)), name
    keys = re.findall(r'@\w+\s*\{\s*([^,]+),', (PROJECT / 'references.bib').read_text())
    assert len(keys) == len(set(keys)), 'Duplicate bibliography keys'
    for name, content in source.items():
        for cited in re.findall(r'\\cite(?:p|t|author|year|alp|alt)?\*?(?:\[[^]]*\])*\{([^}]+)\}', uncomment(content)):
            for key in cited.split(','):
                assert key.strip() in keys, (name, key)
    abstract = uncomment(source['sections/00_abstract.tex'])
    abstract = re.sub(r'\\(?:begin|end)\{abstract\}', '', abstract)
    words = re.findall(r"[A-Za-z0-9]+(?:[-'][A-Za-z0-9]+)*", abstract)
    assert 150 <= len(words) <= 200, f'Abstract has {len(words)} words, expected 150–200'
    accuracy = (PROJECT / 'data/software_accuracy.csv').read_text()
    summary = json.loads((PROJECT / 'data/rtl_validation.json').read_text())
    provenance = json.loads((PROJECT / 'data/provenance.json').read_text())
    assert hashlib.sha256((PROJECT / 'data/software_accuracy.csv').read_bytes()).hexdigest() == provenance['accuracy_sha256']
    assert (PROJECT / 'tables/software_accuracy.tex').read_text() == accuracy_table(accuracy), 'Stale accuracy table'
    assert (PROJECT / 'tables/rtl_coverage.tex').read_text() == rtl_table(summary), 'Stale RTL table'
    original = REPOSITORY / provenance['accuracy_source']
    if original.exists():
        assert hashlib.sha256(original.read_bytes()).hexdigest() == provenance['accuracy_sha256'], 'Snapshot differs from repository evidence'
        for path, expected in summary['source_report_sha256'].items():
            assert hashlib.sha256((REPOSITORY / path).read_bytes()).hexdigest() == expected, path
    if args.submission:
        editable = '\n'.join(uncomment(s) for s in source.values())
        assert r'\writingtask{' not in editable, 'Writing tasks remain'
        assert not re.search(r'pending|Internal working draft|nonacm', editable, re.I), 'Draft metadata/content remains'
        assert r'\begin{CCSXML}' in main and r'\ccsdesc' in main, 'Author-approved CCS classification missing'
    print(json.dumps({'status': 'passed', 'tex_files': len(source), 'abstract_words': len(words),
                      'bib_entries': len(keys), 'mode': 'submission' if args.submission else 'internal_draft'}))


if __name__ == '__main__':
    main()
