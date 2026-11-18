# Paper 1 documentation guide

The controlling research plan is
[the Word report template](../Report_Template/FPGA_Energy_Efficient_Transformer_Research_Plan_2-Month_Extended.docx).
It takes priority over summaries and execution notes.

## Start with the handoff

- [Markdown handoff](EAT_FPGA_Lite_KV260_Handoff.md): searchable instructions,
  commands, known issues, remaining work, and completion criteria.
- [Word handoff](EAT_FPGA_Lite_KV260_Handoff.docx): editable document.
- [PDF handoff](EAT_FPGA_Lite_KV260_Handoff.pdf): portable reading copy.

These versions describe the 12 November 2026 snapshot. The documented CI setup
failure and remaining physical-validation work must be checked against the
current repository before making readiness claims.

## Current evidence and remaining requirements

| Document | Purpose |
| --- | --- |
| [RTL results](rtl_results.md) | Exact local simulations, coverage limits, and the cycle-model discrepancy |
| [Completion checklist](completion_checklist.md) | Required evidence and remaining Paper 1 gates |
| [Software release results](software_release_results.md) | Frozen software results and model families |
| [Software evidence summary](software_evidence_summary.md) | Training, validation, numerical checks, and limitations |
| [Software release notes](software_release_notes.md) | Interpretation and comparison qualifications |
| [Lab notebook](lab_notebook.md) | Dated decisions, experiments, and historical checkpoints |

## Continue implementation

- [RTL overview](../rtl/README.md) and [implementation inventory](../rtl/IMPLEMENTATION_STATUS.md).
- [Confirmed KV260 target](../rtl/config/target_board.json).
- [Physical implementation handoff](../rtl/docs/TARGET_VALIDATION.md).
- [Host programming and error recovery](../rtl/docs/HOST_PROGRAMMING.md).
- [Archived functional RTL evidence](../rtl/validation/implementation_v2/README.md).
- [Frozen model catalog](../results/software_release_v1/catalog.json).
- [Board measurement protocol](../host/measurement_protocol.md).

## Prepare the manuscript

The canonical writing source is [latex/main.tex](latex/main.tex), with separate
section files and the shared [bibliography](latex/references.bib).
Read the [LaTeX project guide](latex/README.md),
[collaboration workflow](latex/CONTRIBUTING.md), and
[submission checklist](latex/SUBMISSION_CHECKLIST.md) before editing.
The ACM Small Standard Format scaffold targets TRETS, retains visible pending
work, and has a script-generated Overleaf upload package and compile workflow.

[manuscript.md](manuscript.md) is retained as historical drafting material, not
a second source to maintain in parallel. Supporting material includes
[datasets](datasets.md), [related work](related_work.md),
[numerical alignment](aligned_numerics_results.md),
[Python test results](python_test_results.md), and
the prior figures under `figures/`. New manuscript figures belong in
`latex/figures/`, with their provenance and accessibility descriptions.

Preserve earlier experiment reports as historical evidence. Functional RTL
simulation does not establish target resource fit, routed timing, board accuracy,
latency, or energy; consult the completion checklist before updating claims.
