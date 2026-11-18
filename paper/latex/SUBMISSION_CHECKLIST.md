# TRETS submission preparation

Journal guide checked 18 November 2026:
<https://trets.cse.sc.edu/tretsauthors.php>. Recheck the live portal before submission.
The controlling Word research plan remains authoritative for project evidence.

## Journal and format

- [ ] Keep the ACM small journal format and select TRETS. Review/remove draft-only
  `nonacm` and internal writing notes; retain standard class geometry and fonts.
- [ ] Supply the confirmed title, author names/affiliations and correspondence.
  Anonymous referees do not by themselves require anonymous author metadata.
- [ ] Keep the abstract between 150 and 200 words; rewrite around final results.
- [ ] Aim for no more than 22 published pages, including figures, tables and
  references. Decide on online supplementary material for lengthy appendices.
- [ ] Select author-approved CCS terms with ACM's classification tool. The linked
  guide mentions legacy primary/secondary categories; check the portal's current
  classification fields and use the `acmart` CCSXML/ccsdesc mechanism correctly.
  No sample/template concept IDs are supplied as real classifications.
- [ ] Verify references, standard metrics/test protocols and justified statistical
  comparisons. Seed SD alone is not a significance test.
- [ ] Resolve overlapping/prior publication disclosures and required permissions;
  document substantive extensions if applicable. Final rights/DOI/issue metadata
  must come from ACM rather than template demonstration values.

## Project evidence still required

- [ ] Complete the current novelty/nearest-work and patent review.
- [ ] Demonstrate target resource feasibility and post-route timing at a recorded
  clock; archive per-block costs, particularly RTS and mode control.
- [ ] Establish board correctness on the full test sets and report accuracy across
  three seeds per mode/workload with consistent numerical-stage comparisons.
- [ ] Measure all modes, dense static RTL and the same-board Cortex-A53 baseline.
- [ ] Measure board ablations (a)–(e) for precision, dropping, RTS and early exit.
- [ ] Report declared accelerator/end-to-end boundaries, median/p95 latency,
  whole-board watts/joules and repeat-window uncertainty with raw traces.
- [ ] Calibrate the cycle model; preserve its original approximately 17×/32×
  underestimate against the recorded core/peripheral simulation boundaries.
- [ ] Report effective operation counts and avoid summing overlapping stall classes.
- [ ] Retain limitations, negative results, previously observed-test disclosure and
  unmatched training-budget caveats. No energy-saving claim follows from MACs.
- [ ] Complete the research plan Section 17 checklist, two outside-team mock reviews,
  authorship/CRediT, institutional and venue policy requirements.

Run `python3 scripts/check_project.py --submission` from this directory after
removing placeholders. It intentionally fails today and does not replace human
scientific, accessibility, reference or policy review.
