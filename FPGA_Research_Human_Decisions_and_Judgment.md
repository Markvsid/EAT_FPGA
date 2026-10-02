# FPGA Research Human Decisions and Judgment

Humans need to decide the research question, acceptable tradeoffs, and which claims the evidence supports. Python experiments and VHDL development produce evidence for those decisions, but they cannot determine what makes the project scientifically worthwhile.

This document identifies the decisions requiring human judgment in the FPGA Transformer project. Role names indicate responsibilities; one person may hold several roles in a small team.

## Decision points and ownership

| Decision | What humans must decide | Evidence needed | Primary owner |
| --- | --- | --- | --- |
| 1. Assignment and scope | Are you responsible for the whole system or one component? What must be completed by the deadline? | Available hours, teammates, existing code, board access and experience | You + supervisor |
| 2. Research contribution | What specific question makes this work worth investigating? Is the distinction from prior work meaningful? | Closest papers, technical comparison and preliminary experiments | Supervisor, with your analysis |
| 3. Minimum paper scope | Is one workload and one board sufficient for the intended contribution? Which features are optional? | Required evidence, implementation effort and publication expectations | You + supervisor |
| 4. Acceptable tradeoffs | How much accuracy loss is acceptable for lower energy or latency? Which metric has priority? | Application requirements and initial accuracy–energy results | You + supervisor |
| 5. Experimental fairness | Are the dataset splits, baselines and comparisons credible? Are improvements caused by the proposed mechanism? | Training protocol, preprocessing, comparison configurations and ablations | You, reviewed by supervisor |
| 6. Model method | Which token-scoring, dropping and summary approach deserves hardware implementation? | Validation accuracy, actual token counts and estimated overhead | You + model/research lead |
| 7. Numerical design | Which precision and approximations provide an acceptable balance of accuracy and hardware cost? | Integer-reference results, overflow analysis and synthesized arithmetic blocks | You + hardware lead |
| 8. Hardware architecture | How much parallelism, buffering and implementation complexity is justified? Where does host processing end? | Memory budget, cycle estimates, synthesis and timing results | You + hardware lead |
| 9. Measurement credibility | Do the power and latency measurements genuinely support the comparison? | Measurement boundaries, raw logs, repeated trials and uncertainty | You, independently reviewed |
| 10. Continue, simplify or stop | Should an unsuccessful feature be revised, dropped or retained as a negative result? | Milestone results, remaining time and contribution strength | You + supervisor |
| 11. Final claims and submission | What can the paper honestly claim, and is the evidence sufficient to submit? | Complete results, limitations, related-work comparison and reproducibility check | All authors; supervisor coordinates |

## Most important unresolved choices

1. **Whether Residual Token Summary (RTS) is the central research contribution.** The proposed arithmetic-mean summary is a starting experiment. Humans must judge whether it is sufficiently distinct from existing token-merging methods and useful enough to justify the paper.
2. **Whether the proposed simplifications preserve the original research objective.** One gating boundary, one workload and optional INT4 substantially narrow the broader proposal.
3. **Which accuracy–energy compromise counts as success.** The suggested one-percentage-point accuracy-loss budget is provisional.
4. **Whether the proposed model and hardware boundary are appropriate.** The current plan places preprocessing on the host and learned embedding, selection and inference on the FPGA. That choice affects implementation effort and the interpretation of end-to-end results.
5. **What the actual deadline can support.** The schedule needs to reflect your assigned role, available support and starting proficiency.

## When to make the decisions

Every technical choice does not need to be settled upfront. Make decisions when the relevant evidence exists.

| Checkpoint | Human judgment required |
| --- | --- |
| Before substantial implementation | Approve the question, scope, responsibilities and success criteria |
| After Python experiments | Select the method and operating modes worth implementing |
| Before full VHDL integration | Accept the numerical specification, architecture and interfaces |
| After board measurements | Decide which improvements are real and which claims to retain |
| Before submission | Approve the argument, limitations, authorship and evidence package |

## What can be delegated

AI can help compare papers, propose experiments, write scripts and RTL, diagnose failures, and draft explanations. Routine implementation choices can be delegated within agreed specifications.

Your responsibility is to understand the consequential choices, inspect the evidence behind them, and be able to defend the resulting design and claims.
