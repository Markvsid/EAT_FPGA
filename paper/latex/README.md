# TRETS LaTeX writing project

**Main document: `main.tex`.** This directory is the canonical editable manuscript
source. It is a working scaffold, not a finished submission. The older
`paper/manuscript.md` remains historical drafting material; make new manuscript
edits here so the group does not maintain two competing papers.

The layout uses the standard ACM `acmart` class with `acmsmall,screen,review`,
matching the Small Standard Format in the supplied PDF. No class, margin,
font-size, or line-spacing overrides are used. `nonacm` is enabled for this
internal draft to suppress unassigned publication/copyright metadata; review
and remove that draft-only option before submission as appropriate. `TRETS` is
the journal identifier. Author names/affiliations, CCS classification, and the
unfinished hardware evidence are explicitly pending. No DOI, issue, acceptance
date, publication rights, funding, or author identities have been invented.

## Edit the paper

| File or directory | What the group edits |
| --- | --- |
| `main.tex` | Entry point, ACM class/options, journal and section order |
| `metadata.tex` | Agreed authors, affiliations, correspondence and ORCIDs |
| `sections/00_abstract.tex` | 150–200-word abstract; current draft has 180 words |
| `sections/01_*.tex` through `10_*.tex` | Section text following the research plan outline |
| `references.bib` | Shared bibliography, moved from `paper/references.bib` |
| `figures/` | Publication figures and accessibility descriptions |
| `data/` | Small frozen-evidence snapshots and provenance |
| `tables/` | Generated numerical tables; do not edit the reported numbers manually |

Visible **Writing task** paragraphs identify content still to be written and
suggest a role, not an assigned person. Replace them with evidence-backed text.
The current software table is generated from the final independent aligned
family, not the older dynamic fake-quantized forward. Test sets were previously
observed. Selected RTL results are simulations, not board measurements.

## Check and build locally

Use Python 3.12 and either **Tectonic 0.17.0** or `latexmk` plus a TeX distribution
containing the standard ACM class, fonts and bibliography style. Tectonic uses
the XeTeX engine family; XeLaTeX is the recommended Overleaf compiler for this
project. No custom class installation is required.

From repository root:

```sh
python3 paper/latex/scripts/check_project.py
python3 paper/latex/scripts/build.py
python3 paper/latex/scripts/package_overleaf.py
```

Or run `make -C paper/latex check`, `pdf`, and `package`. Build chooses Tectonic
when available, then latexmk. Use `--engine tectonic` or `--engine latexmk` to
select explicitly. Initial Tectonic builds download standard TeX resources.
The local `.tools/tectonic/0.17.0/tectonic` is detected if present; it is ignored
and is not a requirement for collaborators. Compiler downloads and checksums
are recorded in `toolchain.json`.

Outputs under ignored `build/`:

- `main.pdf`: compiled internal draft.
- `main.log`, `compiler.log`, `build_report.json`: compiler/version diagnostics.
- `EAT_FPGA_Lite_TRETS_Overleaf.zip`: portable source project, `main.tex` at ZIP root.
- `package_report.json`: file count and ZIP hash.

The standard `acmart` provided by each TeX distribution may differ in version.
The supplied reference PDF records acmart 2.19 with pdfTeX/TeX Live 2026;
`build_report.json` records the actual local/CI class and engine. Use the same
TeX Live release and compiler for the final group proof. Do not change class
fonts or margins to force a page count.

## Overleaf and Git

See [CONTRIBUTING.md](CONTRIBUTING.md) for group editing, ZIP import, manual
round trips, optional GitHub synchronization and merge ownership. Upload only
the paper ZIP, not the full research repository. A GitHub Actions workflow
builds the manuscript and uploads the PDF, logs and ZIP as an artifact.

The project has been prepared locally and versioned in this repository. No
live Overleaf project, sharing invitations, or account linkage is implied.
The project owner must import/share it using their Overleaf account.

## Refresh saved evidence intentionally

From a full research checkout:

```sh
python3 paper/latex/scripts/refresh_evidence.py
python3 paper/latex/scripts/check_project.py
```

This copies the existing frozen accuracy aggregates and summarizes archived
local RTL reports; it does not train or run inference. Review any data/table
change in Git. Provenance hashes are checked against the research sources when
available. The self-contained ZIP can check its own snapshots without datasets.

## Before submission

Use [SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md), then run:

```sh
python3 paper/latex/scripts/check_project.py --submission
```

This is intentionally expected to fail while authoring tasks/placeholders
remain. Automated checks are minimum source checks, not journal approval.
Use the controlling Word research plan and `paper/completion_checklist.md` for
scientific readiness. Read the current journal portal before submitting.

## Sources

- TRETS guide checked 18 November 2026: <https://trets.cse.sc.edu/tretsauthors.php>
- User reference and provenance: [Paper_Template](../../Paper_Template/README.md).
- ACM class maintainer: <https://github.com/borisveytsman/acmart>.
- Standard class distribution: <https://ctan.org/pkg/acmart>.
