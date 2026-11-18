"""Explicitly refresh small paper snapshots from the frozen repository evidence."""
import json
from evidence import PROJECT, REPOSITORY, ACCURACY_SOURCE, accuracy_table, rtl_summary, rtl_table, sha256


def main():
    source = REPOSITORY / ACCURACY_SOURCE
    content = source.read_text()
    summary = rtl_summary()
    (PROJECT / 'data/software_accuracy.csv').write_text(content)
    (PROJECT / 'data/rtl_validation.json').write_text(json.dumps(summary, indent=2) + '\n')
    (PROJECT / 'data/provenance.json').write_text(json.dumps({
        'status': 'frozen_software_and_archived_local_rtl_only',
        'accuracy_source': str(ACCURACY_SOURCE), 'accuracy_sha256': sha256(source),
        'training_seeds': [17, 29, 43],
        'test_sets_previously_observed': True,
        'board_results_available': False,
    }, indent=2) + '\n')
    (PROJECT / 'tables/software_accuracy.tex').write_text(accuracy_table(content))
    (PROJECT / 'tables/rtl_coverage.tex').write_text(rtl_table(summary))
    print('Refreshed two paper tables from frozen evidence; no experiments executed.')


if __name__ == '__main__':
    main()
