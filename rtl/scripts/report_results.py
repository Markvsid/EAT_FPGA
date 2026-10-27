"""Summarize archived exact simulation results without making board claims."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ARCHIVE = ROOT / 'rtl/validation/implementation_v2'


def main():
    core, system = [], []
    for path in sorted(ARCHIVE.glob('*_results.json')):
        report = json.loads(path.read_text())
        for source, expected in report.get('source_sha256', {}).items():
            assert hashlib.sha256((ROOT / source).read_bytes()).hexdigest() == expected, path
        cases = report.get('cases', [])
        if not isinstance(cases, list):
            continue
        for case in cases:
            if 'input_pattern' in case:
                core.append(case)
            elif 'inferences' in case:
                system.append(case)
    assert len({c['case'] for c in core}) == len(core), 'Duplicate core cases'
    assert len([c for c in core if c['input_pattern'] == 'golden']) == 6
    assert len(core) == 10, 'Expected six golden cases and four stress cases'
    assert len(system) == 3 and sum(c['inferences'] for c in system) == 4
    lines = [
        'All 48 entities analyze/elaborate. GHDL synthesis-front-end checks pass for',
        '13 primitive units and eight integration tops, including the complete platform.',
        'All 39 software tests pass. The final exact unit/protocol suites pass: 2,622',
        'primitive cases, 966 service cases, 64 arbiter responses, eight tensor cases,',
        '30 vector cases, 11 attention cases, eight gate cases, four QKV cases, 27',
        'image audits, four loader/resident-image cases each, 42 compact-bank access',
        'transactions, 83 AXI-Lite transactions and 32 stream/DMA frames.', '',
        'The final source runs ten complete encoder inferences: six saved examples',
        '(HAR/Speech × Quality/Balanced/Energy-Saver, seed 17) plus four directed',
        'stress examples. Every final integer logit matches the separate Python',
        'reference exactly; MAC/saturation counts and byte/token totals also match.',
        'The memory-wait event equals an independently counted handshake scoreboard.',
        'These are **176 checked core logits**, not a full-dataset RTL accuracy study.', '',
        '| Encoder case | Input | Simulated bench cycles | MAC products | Saturations |',
        '| --- | --- | ---: | ---: | ---: |'
    ]
    for c in core:
        label = c['model'].removesuffix('_seed17')
        lines.append(f"| {label} | {c['input_pattern']} | {c['cycles_simulated']:,} | {c['active_mac_products']:,} | {c['boundary_saturations']:,} |")
    lines += ['', 'Core cycles are the bench clock count through completion, including its',
              'short reset/start interval and deterministic input/parameter/output stalls.',
              'Parameter/input services in this bench are simulated. The platform below',
              'uses the actual loader, parameter store, arbiters, compact RAM and serializer.', '',
              '| Loaded platform case | Inferences | Exact logits each | Kernel cycles per inference |',
              '| --- | ---: | ---: | --- |']
    for c in system:
        lines.append(f"| {c['case'].removesuffix('_seed17')} | {c['inferences']} | {c['exact_logits_per_inference']} | " + ', '.join(f'{n:,}' for n in c['kernel_cycles_simulated']) + ' |')
    lines += ['', 'The four platform inferences check another **53 logits**. Protocol checks',
              'include malformed transfers, range errors, explicit arming/identity, busy',
              'write rejection, AXIS backpressure/TKEEP/TLAST, repeat input reuse, previous',
              'snapshot retention, coherent counter reads and reset-invalidated residency.', '',
              'Platform cycle counters cover accepted kernel start through final serialized',
              'output acceptance. They exclude parameter/raw DMA loading. The first integration',
              'checkpoint predates the final pipelines/counters; its cycles are historical.', '',
              'Reports, input/model identities, source hashes and full-inference logs are in',
              '[the final archive](../rtl/validation/implementation_v2/). GHDL 6 LLVM on macOS',
              'is recorded separately from Ubuntu CI; no target Fmax is inferred.', '']
    body = '\n'.join(lines)
    paper = ROOT / 'paper/rtl_results.md'
    text = paper.read_text()
    start = text.index('## Current verification checkpoint')
    end = text.index('## Findings and limits', start)
    paper.write_text(text[:start] + '## Final functional verification\n\n' + body + '\n' + text[end:])
    # Preserve the original analytical model; quantify the failure to predict this implementation.
    analytical = json.loads((ROOT / 'results/schedule_estimates.json').read_text())
    comparisons = []
    for c in core:
        if c['input_pattern'] == 'golden' and c['model'].startswith('har_'):
            mode = c['model'][4:].removesuffix('_seed17')
            comparisons.append({'case': c['case'], 'boundary': 'core_bench_with_simulated_services',
                                'analytical_cycles': analytical['candidate_modes'][mode]['estimated_cycles'],
                                'rtl_cycles': c['cycles_simulated']})
    for c in system:
        if c['case'].startswith('har_'):
            mode = c['case'][4:].removesuffix('_seed17')
            comparisons.append({'case': c['case'], 'boundary': 'actual_PL_kernel_counter_excluding_loading',
                                'analytical_cycles': analytical['candidate_modes'][mode]['estimated_cycles'],
                                'rtl_cycles': c['kernel_cycles_simulated'][0]})
    for c in comparisons:
        c['rtl_to_estimate_ratio'] = c['rtl_cycles'] / c['analytical_cycles']
        c['absolute_error_percent_of_rtl'] = abs(c['rtl_cycles'] - c['analytical_cycles']) / c['rtl_cycles'] * 100
    report = {'status': 'uncalibrated_model_fails_template_tolerance', 'comparisons': comparisons,
              'template_target_percent': 'approximately 10–15',
              'limits': 'Different explicit simulation boundaries; no achieved frequency, seconds, power or energy. Original estimates are preserved.'}
    (ROOT / 'results/rtl_schedule_comparison.json').write_text(json.dumps(report, indent=2) + '\n')
    table = ['## Cycle-model discrepancy', '',
             'The original HAR schedule materially underestimates this implementation.',
             'Its bandwidth/overlap assumptions do not match the serial request/response',
             'service and iterative divisions. It fails the template calibration target.',
             'A constant fitted to these examples would not establish predictive accuracy.', '',
             '| HAR mode | Boundary | Old estimate | RTL cycles | RTL/estimate | Error relative to RTL |',
             '| --- | --- | ---: | ---: | ---: | ---: |']
    for c in comparisons:
        boundary = 'Core bench' if c['boundary'].startswith('core') else 'Loaded PL kernel'
        table.append(f"| {c['case'][4:].removesuffix('_seed17')} | {boundary} | {c['analytical_cycles']:,} | {c['rtl_cycles']:,} | {c['rtl_to_estimate_ratio']:.2f}× | {c['absolute_error_percent_of_rtl']:.2f}% |")
    table += ['', 'The original estimates remain unchanged in `results/schedule_estimates.json`.',
              'The comparison is saved in `results/rtl_schedule_comparison.json`. Future',
              'calibration must model the actual transaction schedule and validate predictions',
              'on held-out configurations. These cycle counts establish no board latency or',
              'energy advantage.', '']
    text = paper.read_text()
    marker = '## Cycle-model discrepancy'
    if marker in text:
        text = text[:text.index(marker)]
    paper.write_text(text.rstrip() + '\n\n' + '\n'.join(table))
    print('Reported', len(core), 'core cases and', sum(c['inferences'] for c in system), 'platform inferences')


if __name__ == '__main__':
    main()
