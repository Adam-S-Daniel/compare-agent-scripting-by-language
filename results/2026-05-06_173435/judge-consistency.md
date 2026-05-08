# Judge Consistency Data

*Raw panel-of-judges data plus a rankings-focused Quality Analysis. Backs the merged Conclusions and Judge Consistency Summary in the corresponding [`results.md`](results.md).*

## Notes

- **Generated:** 2026-05-08 11:32:38 AM ET
- **Source:** `/home/passp/repos/compare-agent-scripting-by-language/results/2026-05-06_173435`
- **Judges present:** haiku45, gemini31pro
- **Score conventions:** Scores shown are the `overall` dimension from each judge (1-5). Δ column is the second judge minus the first; positive = second judge is more generous.

## Quality Analysis

opus47-1m at the xhigh effort tier produces the strongest output on both quality axes — it tops both judges' rankings for Tests Quality (haiku 3.29, gemini 4.91) and Workflow Craft (haiku 3.06, gemini 4.91). The default Python language is the best fit for Tests Quality across both judges (ρ = +0.90 on language ordering), while typescript-bun leads Workflow Craft for both judges.

- **Top performer**: opus47-1m at xhigh effort wins both axes from both judges with no pair-wise reversal touching the top slot, and the model ordering carries a Spearman of +0.83 on both Tests Quality and Workflow Craft.
- **Effort tier scaling**: Within opus47-1m, scores climb cleanly from medium → high → xhigh for both judges on both axes, with no reversals on that trio — the panel agrees more thinking yields better output.
- **Best by language**: default Python leads Tests Quality with both judges agreeing on the full ordering (ρ = +0.90); typescript-bun leads Workflow Craft for both, even though the broader Workflow Craft language ordering only reaches ρ = +0.30.
- **Workflow Craft ceiling**: even at the strongest model+effort, haiku rates Workflow Craft at 3.06 — both judges agree opus47-1m-xhigh is best, but the absolute means show meaningful headroom remains.
- **Where rankings diverge**: bash on Workflow Craft is the sharpest split — haiku ranks it #2, gemini ranks it #5 — and haiku45-self-judgment reversals cluster inside the haiku family without changing its last-place finish.

*Provenance:* `claude-opus-4-7[1m]` at effort `xhigh` via Claude CLI; 5 in / 2300 out tokens, $0.3738. Prompt: [`QUALITY_ANALYSIS_SYSTEM_PROMPT`](../../judge_consistency_report.py).

## Campaign summary

### Tests Quality

| Scope | n | haiku45 ovr | gemini31pro ovr | Δ(gemini31pro−haiku45) |
|---|---|---|---|---|
| all | 266 | 2.79 | 4.46 | +1.68 |

### Workflow Craft

| Scope | n | haiku45 ovr | gemini31pro ovr | Δ(gemini31pro−haiku45) |
|---|---|---|---|---|
| all | 269 | 2.22 | 4.58 | +2.36 |

## By task

### Tests Quality

| Task | n | haiku45 ovr | gemini31pro ovr | Δ(gemini31pro−haiku45) |
|---|---|---|---|---|
| 11-semantic-version-bumper | 38 | 2.68 | 4.16 | +1.47 |
| 12-pr-label-assigner | 32 | 2.59 | 3.94 | +1.34 |
| 13-dependency-license-checker | 40 | 3.00 | 4.60 | +1.60 |
| 15-test-results-aggregator | 38 | 2.82 | 4.55 | +1.74 |
| 16-environment-matrix-generator | 40 | 2.77 | 4.62 | +1.85 |
| 17-artifact-cleanup-script | 40 | 2.70 | 4.58 | +1.88 |
| 18-secret-rotation-validator | 38 | 2.89 | 4.68 | +1.79 |

### Workflow Craft

| Task | n | haiku45 ovr | gemini31pro ovr | Δ(gemini31pro−haiku45) |
|---|---|---|---|---|
| 11-semantic-version-bumper | 38 | 2.11 | 4.26 | +2.16 |
| 12-pr-label-assigner | 31 | 2.03 | 4.10 | +2.06 |
| 13-dependency-license-checker | 40 | 2.58 | 4.60 | +2.02 |
| 15-test-results-aggregator | 40 | 2.10 | 4.83 | +2.73 |
| 16-environment-matrix-generator | 40 | 2.27 | 4.70 | +2.43 |
| 17-artifact-cleanup-script | 40 | 2.00 | 4.70 | +2.70 |
| 18-secret-rotation-validator | 40 | 2.38 | 4.75 | +2.38 |

## By language mode

### Tests Quality

| Mode | n | haiku45 ovr | gemini31pro ovr | Δ(gemini31pro−haiku45) |
|---|---|---|---|---|
| bash | 55 | 2.42 | 4.09 | +1.67 |
| default | 51 | 2.96 | 4.61 | +1.65 |
| powershell | 50 | 2.96 | 4.54 | +1.58 |
| powershell-tool | 54 | 2.80 | 4.48 | +1.69 |
| typescript-bun | 56 | 2.82 | 4.61 | +1.79 |

### Workflow Craft

| Mode | n | haiku45 ovr | gemini31pro ovr | Δ(gemini31pro−haiku45) |
|---|---|---|---|---|
| bash | 56 | 2.21 | 4.36 | +2.14 |
| default | 52 | 2.15 | 4.60 | +2.44 |
| powershell | 52 | 2.23 | 4.63 | +2.40 |
| powershell-tool | 54 | 2.20 | 4.59 | +2.39 |
| typescript-bun | 55 | 2.27 | 4.73 | +2.45 |

## By model + effort

### Tests Quality

| Model-Effort | n | haiku45 ovr | gemini31pro ovr | Δ(gemini31pro−haiku45) |
|---|---|---|---|---|
| haiku45 | 30 | 1.93 | 2.33 | +0.40 |
| opus | 34 | 2.88 | 4.56 | +1.68 |
| opus47-1m-high | 34 | 3.09 | 4.79 | +1.71 |
| opus47-1m-medium | 34 | 2.74 | 4.82 | +2.09 |
| opus47-1m-xhigh | 34 | 3.29 | 4.91 | +1.62 |
| opus47-200k-medium | 34 | 2.74 | 4.82 | +2.09 |
| sonnet | 33 | 2.91 | 4.67 | +1.76 |
| sonnet46-1m-medium | 33 | 2.61 | 4.55 | +1.94 |

### Workflow Craft

| Model-Effort | n | haiku45 ovr | gemini31pro ovr | Δ(gemini31pro−haiku45) |
|---|---|---|---|---|
| haiku45 | 34 | 1.76 | 3.71 | +1.94 |
| opus | 34 | 1.85 | 4.59 | +2.74 |
| opus47-1m-high | 32 | 2.66 | 4.75 | +2.09 |
| opus47-1m-medium | 35 | 2.26 | 4.83 | +2.57 |
| opus47-1m-xhigh | 32 | 3.06 | 4.91 | +1.84 |
| opus47-200k-medium | 35 | 2.14 | 4.86 | +2.71 |
| sonnet | 33 | 2.24 | 4.61 | +2.36 |
| sonnet46-1m-medium | 34 | 1.82 | 4.41 | +2.59 |

## Disagreement hotspots (panel span ≥ 2 on overall)

### Tests Quality

| Task | Mode | Model | Span | haiku45 ovr | gemini31pro ovr |
|---|---|---|---|---|---|
| 12-pr-label-assigner | powershell-tool | sonnet46-1m-medium | 4.0 | 1.0 | 5.0 |
| 13-dependency-license-checker | bash | opus47-1m-xhigh | 4.0 | 1.0 | 5.0 |
| 11-semantic-version-bumper | powershell | opus | 3.0 | 2.0 | 5.0 |
| 11-semantic-version-bumper | powershell | opus47-200k-medium | 3.0 | 2.0 | 5.0 |
| 11-semantic-version-bumper | powershell-tool | opus | 3.0 | 2.0 | 5.0 |
| 11-semantic-version-bumper | powershell-tool | opus47-1m-high | 3.0 | 2.0 | 5.0 |
| 11-semantic-version-bumper | typescript-bun | opus | 3.0 | 2.0 | 5.0 |
| 11-semantic-version-bumper | typescript-bun | opus47-200k-medium | 3.0 | 2.0 | 5.0 |
| 12-pr-label-assigner | bash | opus47-1m-high | 3.0 | 2.0 | 5.0 |
| 12-pr-label-assigner | powershell-tool | opus47-1m-high | 3.0 | 2.0 | 5.0 |
| 12-pr-label-assigner | powershell-tool | opus47-1m-medium | 3.0 | 2.0 | 5.0 |
| 12-pr-label-assigner | typescript-bun | opus47-200k-medium | 3.0 | 2.0 | 5.0 |
| 12-pr-label-assigner | typescript-bun | sonnet46-1m-medium | 3.0 | 2.0 | 5.0 |
| 13-dependency-license-checker | bash | opus47-200k-medium | 3.0 | 2.0 | 5.0 |
| 13-dependency-license-checker | powershell | opus47-1m-medium | 3.0 | 2.0 | 5.0 |
| 13-dependency-license-checker | powershell | opus47-200k-medium | 3.0 | 2.0 | 5.0 |
| 15-test-results-aggregator | bash | opus | 3.0 | 2.0 | 5.0 |
| 15-test-results-aggregator | bash | opus47-1m-medium | 3.0 | 2.0 | 5.0 |
| 15-test-results-aggregator | bash | opus47-200k-medium | 3.0 | 2.0 | 5.0 |
| 15-test-results-aggregator | bash | sonnet46-1m-medium | 3.0 | 2.0 | 5.0 |
| 15-test-results-aggregator | default | opus | 3.0 | 2.0 | 5.0 |
| 15-test-results-aggregator | powershell | opus47-1m-high | 3.0 | 2.0 | 5.0 |
| 15-test-results-aggregator | powershell-tool | opus47-1m-medium | 3.0 | 2.0 | 5.0 |
| 15-test-results-aggregator | typescript-bun | sonnet46-1m-medium | 3.0 | 2.0 | 5.0 |
| 16-environment-matrix-generato | bash | opus47-1m-high | 3.0 | 2.0 | 5.0 |

### Workflow Craft

| Task | Mode | Model | Span | haiku45 ovr | gemini31pro ovr |
|---|---|---|---|---|---|
| 11-semantic-version-bumper | default | sonnet46-1m-medium | 4.0 | 1.0 | 5.0 |
| 11-semantic-version-bumper | typescript-bun | opus47-200k-medium | 4.0 | 1.0 | 5.0 |
| 12-pr-label-assigner | bash | opus47-1m-high | 4.0 | 1.0 | 5.0 |
| 12-pr-label-assigner | powershell-tool | opus47-1m-medium | 4.0 | 1.0 | 5.0 |
| 12-pr-label-assigner | typescript-bun | opus47-200k-medium | 4.0 | 1.0 | 5.0 |
| 12-pr-label-assigner | typescript-bun | sonnet46-1m-medium | 4.0 | 1.0 | 5.0 |
| 13-dependency-license-checker | powershell | opus | 4.0 | 1.0 | 5.0 |
| 15-test-results-aggregator | bash | opus | 4.0 | 1.0 | 5.0 |
| 15-test-results-aggregator | bash | opus47-1m-medium | 4.0 | 1.0 | 5.0 |
| 15-test-results-aggregator | bash | sonnet46-1m-medium | 4.0 | 1.0 | 5.0 |
| 15-test-results-aggregator | default | opus | 4.0 | 1.0 | 5.0 |
| 15-test-results-aggregator | default | opus47-200k-medium | 4.0 | 1.0 | 5.0 |
| 15-test-results-aggregator | default | sonnet | 4.0 | 1.0 | 5.0 |
| 15-test-results-aggregator | powershell | haiku45 | 4.0 | 1.0 | 5.0 |
| 15-test-results-aggregator | powershell | opus47-1m-high | 4.0 | 1.0 | 5.0 |
| 15-test-results-aggregator | powershell | opus47-1m-medium | 4.0 | 1.0 | 5.0 |
| 15-test-results-aggregator | typescript-bun | opus | 4.0 | 1.0 | 5.0 |
| 16-environment-matrix-generato | bash | opus47-1m-medium | 4.0 | 1.0 | 5.0 |
| 16-environment-matrix-generato | default | haiku45 | 4.0 | 1.0 | 5.0 |
| 16-environment-matrix-generato | powershell-tool | opus | 4.0 | 1.0 | 5.0 |
| 16-environment-matrix-generato | powershell-tool | opus47-1m-medium | 4.0 | 1.0 | 5.0 |
| 16-environment-matrix-generato | typescript-bun | sonnet | 4.0 | 1.0 | 5.0 |
| 17-artifact-cleanup-script | default | opus | 4.0 | 1.0 | 5.0 |
| 17-artifact-cleanup-script | default | opus47-200k-medium | 4.0 | 1.0 | 5.0 |
| 17-artifact-cleanup-script | powershell | opus | 4.0 | 1.0 | 5.0 |

## Model rankings by judge

*Agreement on model ordering tells us the panel agrees on which configurations produce better output on this axis. Absolute-score differences between judges are expected (different grading scales) and are not a bias concern.*

### Tests Quality

| Model | haiku45 rank (mean, n) | gemini31pro rank (mean, n) |
|---|---|---|
| opus47-1m | 1 (3.05, n=104) | 1 (4.84, n=102) |
| sonnet | 2 (2.91, n=35) | 3 (4.67, n=33) |
| opus | 3 (2.88, n=34) | 4 (4.56, n=34) |
| opus47-200k | 4 (2.74, n=35) | 2 (4.82, n=34) |
| sonnet46-1m | 5 (2.62, n=34) | 5 (4.55, n=33) |
| haiku45 | 6 (1.94, n=31) | 6 (2.33, n=30) |

*Spearman rank correlation between haiku45 and gemini31pro: **+0.83**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

**Pair-wise reversals** (where the two judges disagree on which model is better):

| Pair | haiku45 prefers | gemini31pro prefers | Own-family signal? |
|---|---|---|---|
| opus vs opus47-200k | opus | opus47-200k | — |
| opus47-200k vs sonnet | sonnet | opus47-200k | — |

### Workflow Craft

| Model | haiku45 rank (mean, n) | gemini31pro rank (mean, n) |
|---|---|---|
| opus47-1m | 1 (2.63, n=105) | 2 (4.83, n=99) |
| sonnet | 2 (2.26, n=35) | 3 (4.61, n=33) |
| opus47-200k | 3 (2.14, n=35) | 1 (4.86, n=35) |
| opus | 4 (1.86, n=35) | 4 (4.59, n=34) |
| sonnet46-1m | 5 (1.83, n=35) | 5 (4.41, n=34) |
| haiku45 | 6 (1.74, n=35) | 6 (3.71, n=34) |

*Spearman rank correlation between haiku45 and gemini31pro: **+0.83**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

**Pair-wise reversals** (where the two judges disagree on which model is better):

| Pair | haiku45 prefers | gemini31pro prefers | Own-family signal? |
|---|---|---|---|
| opus47-1m vs opus47-200k | opus47-1m | opus47-200k | — |
| opus47-200k vs sonnet | sonnet | opus47-200k | — |

## Language rankings by judge

*Agreement on language ordering tells us the panel agrees on which configurations produce better output on this axis. Absolute-score differences between judges are expected (different grading scales) and are not a bias concern.*

### Tests Quality

| Language | haiku45 rank (mean, n) | gemini31pro rank (mean, n) |
|---|---|---|
| default | 1 (2.98, n=55) | 1 (4.61, n=51) |
| powershell | 2 (2.96, n=52) | 3 (4.54, n=50) |
| typescript-bun | 3 (2.82, n=56) | 2 (4.61, n=56) |
| powershell-tool | 4 (2.78, n=55) | 4 (4.48, n=54) |
| bash | 5 (2.42, n=55) | 5 (4.09, n=55) |

*Spearman rank correlation between haiku45 and gemini31pro: **+0.90**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

**Pair-wise reversals** (where the two judges disagree on which language is better):

| Pair | haiku45 prefers | gemini31pro prefers | Own-family signal? |
|---|---|---|---|
| powershell vs typescript-bun | powershell | typescript-bun | — |

### Workflow Craft

| Language | haiku45 rank (mean, n) | gemini31pro rank (mean, n) |
|---|---|---|
| typescript-bun | 1 (2.27, n=56) | 1 (4.73, n=55) |
| bash | 2 (2.21, n=56) | 5 (4.36, n=56) |
| powershell | 3 (2.21, n=56) | 2 (4.63, n=52) |
| powershell-tool | 4 (2.21, n=56) | 4 (4.59, n=54) |
| default | 5 (2.16, n=56) | 3 (4.60, n=52) |

*Spearman rank correlation between haiku45 and gemini31pro: **+0.30**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

**Pair-wise reversals** (where the two judges disagree on which language is better):

| Pair | haiku45 prefers | gemini31pro prefers | Own-family signal? |
|---|---|---|---|
| bash vs default | bash | default | — |
| bash vs powershell | bash | powershell | — |
| bash vs powershell-tool | bash | powershell-tool | — |
| default vs powershell-tool | powershell-tool | default | — |

## Language×Model rankings by judge

*Agreement on language×model ordering tells us the panel agrees on which configurations produce better output on this axis. Absolute-score differences between judges are expected (different grading scales) and are not a bias concern.*

### Tests Quality

| Language / Model | haiku45 rank (mean, n) | gemini31pro rank (mean, n) |
|---|---|---|
| powershell / sonnet46-1m | 1 (3.50, n=6) | 15 (4.83, n=6) |
| default / opus47-1m | 2 (3.48, n=21) | 12 (4.85, n=20) |
| powershell / sonnet | 3 (3.29, n=7) | 17 (4.57, n=7) |
| typescript-bun / opus47-1m | 4 (3.24, n=21) | 7 (5.00, n=21) |
| bash / opus | 5 (3.17, n=6) | 1 (5.00, n=6) |
| powershell / opus47-1m | 6 (3.15, n=20) | 13 (4.84, n=19) |
| powershell-tool / opus | 7 (3.14, n=7) | 20 (4.43, n=7) |
| powershell-tool / opus47-200k | 8 (3.14, n=7) | 6 (5.00, n=7) |
| default / sonnet | 9 (3.00, n=7) | 14 (4.83, n=6) |
| typescript-bun / opus47-200k | 10 (3.00, n=7) | 8 (5.00, n=7) |
| typescript-bun / sonnet | 11 (3.00, n=7) | 11 (4.86, n=7) |
| default / opus47-200k | 12 (2.86, n=7) | 2 (5.00, n=6) |
| default / sonnet46-1m | 13 (2.86, n=7) | 3 (5.00, n=6) |
| powershell / opus | 14 (2.86, n=7) | 24 (4.14, n=7) |
| powershell-tool / opus47-1m | 15 (2.86, n=21) | 5 (5.00, n=21) |
| default / opus | 16 (2.71, n=7) | 19 (4.43, n=7) |
| powershell / opus47-200k | 17 (2.71, n=7) | 4 (5.00, n=7) |
| powershell-tool / sonnet | 18 (2.71, n=7) | 21 (4.33, n=6) |
| bash / sonnet | 19 (2.57, n=7) | 16 (4.71, n=7) |
| typescript-bun / opus | 20 (2.57, n=7) | 10 (4.86, n=7) |
| typescript-bun / sonnet46-1m | 21 (2.57, n=7) | 9 (5.00, n=7) |
| bash / opus47-1m | 22 (2.52, n=21) | 18 (4.52, n=21) |
| powershell-tool / haiku45 | 23 (2.33, n=6) | 28 (2.50, n=6) |
| powershell-tool / sonnet46-1m | 24 (2.29, n=7) | 22 (4.29, n=7) |
| bash / haiku45 | 25 (2.14, n=7) | 30 (1.71, n=7) |
| bash / opus47-200k | 26 (2.00, n=7) | 23 (4.14, n=7) |
| bash / sonnet46-1m | 27 (2.00, n=7) | 25 (3.71, n=7) |
| default / haiku45 | 28 (1.83, n=6) | 26 (3.00, n=6) |
| typescript-bun / haiku45 | 29 (1.71, n=7) | 29 (2.14, n=7) |
| powershell / haiku45 | 30 (1.60, n=5) | 27 (2.50, n=4) |

*Spearman rank correlation between haiku45 and gemini31pro: **+0.62**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

**Pair-wise reversals** (where the two judges disagree on which language×model is better):

| Pair | haiku45 prefers | gemini31pro prefers | Own-family signal? |
|---|---|---|---|
| bash / haiku45 vs bash / opus47-200k | bash / haiku45 | bash / opus47-200k | ⚠️ haiku45 |
| bash / haiku45 vs bash / sonnet46-1m | bash / haiku45 | bash / sonnet46-1m | ⚠️ haiku45 |
| bash / haiku45 vs default / haiku45 | bash / haiku45 | default / haiku45 | ⚠️ haiku45 |
| bash / haiku45 vs powershell / haiku45 | bash / haiku45 | powershell / haiku45 | ⚠️ haiku45 |
| bash / haiku45 vs typescript-bun / haiku45 | bash / haiku45 | typescript-bun / haiku45 | ⚠️ haiku45 |
| bash / opus vs default / opus47-1m | default / opus47-1m | bash / opus | — |
| bash / opus vs powershell / sonnet | powershell / sonnet | bash / opus | — |
| bash / opus vs powershell / sonnet46-1m | powershell / sonnet46-1m | bash / opus | — |
| bash / opus vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | bash / opus | — |
| bash / opus47-1m vs default / opus | default / opus | bash / opus47-1m | — |
| bash / opus47-1m vs powershell / opus | powershell / opus | bash / opus47-1m | — |
| bash / opus47-1m vs powershell-tool / opus | powershell-tool / opus | bash / opus47-1m | — |
| bash / opus47-1m vs powershell-tool / sonnet | powershell-tool / sonnet | bash / opus47-1m | — |
| bash / opus47-200k vs powershell / opus | powershell / opus | bash / opus47-200k | — |
| bash / opus47-200k vs powershell-tool / haiku45 | powershell-tool / haiku45 | bash / opus47-200k | ⚠️ haiku45 |
| bash / sonnet vs default / opus | default / opus | bash / sonnet | — |
| bash / sonnet vs powershell / opus | powershell / opus | bash / sonnet | — |
| bash / sonnet vs powershell / sonnet | powershell / sonnet | bash / sonnet | — |
| bash / sonnet vs powershell-tool / opus | powershell-tool / opus | bash / sonnet | — |
| bash / sonnet vs powershell-tool / sonnet | powershell-tool / sonnet | bash / sonnet | — |
| bash / sonnet vs typescript-bun / opus | bash / sonnet | typescript-bun / opus | — |
| bash / sonnet vs typescript-bun / sonnet46-1m | bash / sonnet | typescript-bun / sonnet46-1m | — |
| bash / sonnet46-1m vs powershell-tool / haiku45 | powershell-tool / haiku45 | bash / sonnet46-1m | ⚠️ haiku45 |
| default / haiku45 vs powershell-tool / haiku45 | powershell-tool / haiku45 | default / haiku45 | ⚠️ haiku45 |
| default / opus vs powershell / opus | powershell / opus | default / opus | — |
| default / opus vs powershell / opus47-200k | default / opus | powershell / opus47-200k | — |
| default / opus vs powershell-tool / opus | powershell-tool / opus | default / opus | — |
| default / opus vs typescript-bun / opus | default / opus | typescript-bun / opus | — |
| default / opus vs typescript-bun / sonnet46-1m | default / opus | typescript-bun / sonnet46-1m | — |
| default / opus47-1m vs default / opus47-200k | default / opus47-1m | default / opus47-200k | — |
| default / opus47-1m vs default / sonnet46-1m | default / opus47-1m | default / sonnet46-1m | — |
| default / opus47-1m vs powershell / opus47-200k | default / opus47-1m | powershell / opus47-200k | — |
| default / opus47-1m vs powershell / sonnet46-1m | powershell / sonnet46-1m | default / opus47-1m | — |
| default / opus47-1m vs powershell-tool / opus47-1m | default / opus47-1m | powershell-tool / opus47-1m | — |
| default / opus47-1m vs powershell-tool / opus47-200k | default / opus47-1m | powershell-tool / opus47-200k | — |
| default / opus47-1m vs typescript-bun / opus | default / opus47-1m | typescript-bun / opus | — |
| default / opus47-1m vs typescript-bun / opus47-1m | default / opus47-1m | typescript-bun / opus47-1m | — |
| default / opus47-1m vs typescript-bun / opus47-200k | default / opus47-1m | typescript-bun / opus47-200k | — |
| default / opus47-1m vs typescript-bun / sonnet | default / opus47-1m | typescript-bun / sonnet | — |
| default / opus47-1m vs typescript-bun / sonnet46-1m | default / opus47-1m | typescript-bun / sonnet46-1m | — |
| default / opus47-200k vs default / sonnet | default / sonnet | default / opus47-200k | — |
| default / opus47-200k vs powershell / opus47-1m | powershell / opus47-1m | default / opus47-200k | — |
| default / opus47-200k vs powershell / sonnet | powershell / sonnet | default / opus47-200k | — |
| default / opus47-200k vs powershell / sonnet46-1m | powershell / sonnet46-1m | default / opus47-200k | — |
| default / opus47-200k vs powershell-tool / opus | powershell-tool / opus | default / opus47-200k | — |
| default / opus47-200k vs powershell-tool / opus47-200k | powershell-tool / opus47-200k | default / opus47-200k | — |
| default / opus47-200k vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | default / opus47-200k | — |
| default / opus47-200k vs typescript-bun / opus47-200k | typescript-bun / opus47-200k | default / opus47-200k | — |
| default / opus47-200k vs typescript-bun / sonnet | typescript-bun / sonnet | default / opus47-200k | — |
| default / sonnet vs default / sonnet46-1m | default / sonnet | default / sonnet46-1m | — |
| default / sonnet vs powershell / opus47-200k | default / sonnet | powershell / opus47-200k | — |
| default / sonnet vs powershell / sonnet | powershell / sonnet | default / sonnet | — |
| default / sonnet vs powershell / sonnet46-1m | powershell / sonnet46-1m | default / sonnet | — |
| default / sonnet vs powershell-tool / opus | powershell-tool / opus | default / sonnet | — |
| default / sonnet vs powershell-tool / opus47-1m | default / sonnet | powershell-tool / opus47-1m | — |
| default / sonnet vs typescript-bun / opus | default / sonnet | typescript-bun / opus | — |
| default / sonnet vs typescript-bun / opus47-200k | default / sonnet | typescript-bun / opus47-200k | — |
| default / sonnet vs typescript-bun / sonnet | default / sonnet | typescript-bun / sonnet | — |
| default / sonnet vs typescript-bun / sonnet46-1m | default / sonnet | typescript-bun / sonnet46-1m | — |
| default / sonnet46-1m vs powershell / opus47-1m | powershell / opus47-1m | default / sonnet46-1m | — |
| default / sonnet46-1m vs powershell / sonnet | powershell / sonnet | default / sonnet46-1m | — |
| default / sonnet46-1m vs powershell / sonnet46-1m | powershell / sonnet46-1m | default / sonnet46-1m | — |
| default / sonnet46-1m vs powershell-tool / opus | powershell-tool / opus | default / sonnet46-1m | — |
| default / sonnet46-1m vs powershell-tool / opus47-200k | powershell-tool / opus47-200k | default / sonnet46-1m | — |
| default / sonnet46-1m vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | default / sonnet46-1m | — |
| default / sonnet46-1m vs typescript-bun / opus47-200k | typescript-bun / opus47-200k | default / sonnet46-1m | — |
| default / sonnet46-1m vs typescript-bun / sonnet | typescript-bun / sonnet | default / sonnet46-1m | — |
| powershell / haiku45 vs powershell-tool / haiku45 | powershell-tool / haiku45 | powershell / haiku45 | ⚠️ haiku45 |
| powershell / haiku45 vs typescript-bun / haiku45 | typescript-bun / haiku45 | powershell / haiku45 | ⚠️ haiku45 |
| powershell / opus vs powershell / opus47-200k | powershell / opus | powershell / opus47-200k | — |
| powershell / opus vs powershell-tool / opus47-1m | powershell / opus | powershell-tool / opus47-1m | — |
| powershell / opus vs powershell-tool / sonnet | powershell / opus | powershell-tool / sonnet | — |
| powershell / opus vs powershell-tool / sonnet46-1m | powershell / opus | powershell-tool / sonnet46-1m | — |
| powershell / opus vs typescript-bun / opus | powershell / opus | typescript-bun / opus | — |
| powershell / opus vs typescript-bun / sonnet46-1m | powershell / opus | typescript-bun / sonnet46-1m | — |
| powershell / opus47-1m vs powershell / opus47-200k | powershell / opus47-1m | powershell / opus47-200k | — |
| powershell / opus47-1m vs powershell / sonnet | powershell / sonnet | powershell / opus47-1m | — |
| powershell / opus47-1m vs powershell / sonnet46-1m | powershell / sonnet46-1m | powershell / opus47-1m | — |
| powershell / opus47-1m vs powershell-tool / opus47-1m | powershell / opus47-1m | powershell-tool / opus47-1m | — |
| powershell / opus47-1m vs powershell-tool / opus47-200k | powershell / opus47-1m | powershell-tool / opus47-200k | — |
| powershell / opus47-1m vs typescript-bun / opus | powershell / opus47-1m | typescript-bun / opus | — |
| powershell / opus47-1m vs typescript-bun / opus47-200k | powershell / opus47-1m | typescript-bun / opus47-200k | — |
| powershell / opus47-1m vs typescript-bun / sonnet | powershell / opus47-1m | typescript-bun / sonnet | — |
| powershell / opus47-1m vs typescript-bun / sonnet46-1m | powershell / opus47-1m | typescript-bun / sonnet46-1m | — |
| powershell / opus47-200k vs powershell / sonnet | powershell / sonnet | powershell / opus47-200k | — |
| powershell / opus47-200k vs powershell / sonnet46-1m | powershell / sonnet46-1m | powershell / opus47-200k | — |
| powershell / opus47-200k vs powershell-tool / opus | powershell-tool / opus | powershell / opus47-200k | — |
| powershell / opus47-200k vs powershell-tool / opus47-1m | powershell-tool / opus47-1m | powershell / opus47-200k | — |
| powershell / opus47-200k vs powershell-tool / opus47-200k | powershell-tool / opus47-200k | powershell / opus47-200k | — |
| powershell / opus47-200k vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | powershell / opus47-200k | — |
| powershell / opus47-200k vs typescript-bun / opus47-200k | typescript-bun / opus47-200k | powershell / opus47-200k | — |
| powershell / opus47-200k vs typescript-bun / sonnet | typescript-bun / sonnet | powershell / opus47-200k | — |
| powershell / sonnet vs powershell-tool / opus47-1m | powershell / sonnet | powershell-tool / opus47-1m | — |
| powershell / sonnet vs powershell-tool / opus47-200k | powershell / sonnet | powershell-tool / opus47-200k | — |
| powershell / sonnet vs typescript-bun / opus | powershell / sonnet | typescript-bun / opus | — |
| powershell / sonnet vs typescript-bun / opus47-1m | powershell / sonnet | typescript-bun / opus47-1m | — |
| powershell / sonnet vs typescript-bun / opus47-200k | powershell / sonnet | typescript-bun / opus47-200k | — |
| powershell / sonnet vs typescript-bun / sonnet | powershell / sonnet | typescript-bun / sonnet | — |
| powershell / sonnet vs typescript-bun / sonnet46-1m | powershell / sonnet | typescript-bun / sonnet46-1m | — |
| powershell / sonnet46-1m vs powershell-tool / opus47-1m | powershell / sonnet46-1m | powershell-tool / opus47-1m | — |
| powershell / sonnet46-1m vs powershell-tool / opus47-200k | powershell / sonnet46-1m | powershell-tool / opus47-200k | — |
| powershell / sonnet46-1m vs typescript-bun / opus | powershell / sonnet46-1m | typescript-bun / opus | — |
| powershell / sonnet46-1m vs typescript-bun / opus47-1m | powershell / sonnet46-1m | typescript-bun / opus47-1m | — |
| powershell / sonnet46-1m vs typescript-bun / opus47-200k | powershell / sonnet46-1m | typescript-bun / opus47-200k | — |
| powershell / sonnet46-1m vs typescript-bun / sonnet | powershell / sonnet46-1m | typescript-bun / sonnet | — |
| powershell / sonnet46-1m vs typescript-bun / sonnet46-1m | powershell / sonnet46-1m | typescript-bun / sonnet46-1m | — |
| powershell-tool / haiku45 vs powershell-tool / sonnet46-1m | powershell-tool / haiku45 | powershell-tool / sonnet46-1m | ⚠️ haiku45 |
| powershell-tool / opus vs powershell-tool / opus47-1m | powershell-tool / opus | powershell-tool / opus47-1m | — |
| powershell-tool / opus vs powershell-tool / opus47-200k | powershell-tool / opus | powershell-tool / opus47-200k | — |
| powershell-tool / opus vs typescript-bun / opus | powershell-tool / opus | typescript-bun / opus | — |
| powershell-tool / opus vs typescript-bun / opus47-200k | powershell-tool / opus | typescript-bun / opus47-200k | — |
| powershell-tool / opus vs typescript-bun / sonnet | powershell-tool / opus | typescript-bun / sonnet | — |
| powershell-tool / opus vs typescript-bun / sonnet46-1m | powershell-tool / opus | typescript-bun / sonnet46-1m | — |
| powershell-tool / opus47-1m vs powershell-tool / opus47-200k | powershell-tool / opus47-200k | powershell-tool / opus47-1m | — |
| powershell-tool / opus47-1m vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | powershell-tool / opus47-1m | — |
| powershell-tool / opus47-1m vs typescript-bun / opus47-200k | typescript-bun / opus47-200k | powershell-tool / opus47-1m | — |
| powershell-tool / opus47-1m vs typescript-bun / sonnet | typescript-bun / sonnet | powershell-tool / opus47-1m | — |
| powershell-tool / opus47-200k vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | powershell-tool / opus47-200k | — |
| powershell-tool / sonnet vs typescript-bun / opus | powershell-tool / sonnet | typescript-bun / opus | — |
| powershell-tool / sonnet vs typescript-bun / sonnet46-1m | powershell-tool / sonnet | typescript-bun / sonnet46-1m | — |
| typescript-bun / opus vs typescript-bun / sonnet | typescript-bun / sonnet | typescript-bun / opus | — |
| typescript-bun / opus vs typescript-bun / sonnet46-1m | typescript-bun / opus | typescript-bun / sonnet46-1m | — |
| typescript-bun / sonnet vs typescript-bun / sonnet46-1m | typescript-bun / sonnet | typescript-bun / sonnet46-1m | — |

### Workflow Craft

| Language / Model | haiku45 rank (mean, n) | gemini31pro rank (mean, n) |
|---|---|---|
| default / opus47-1m | 1 (2.76, n=21) | 5 (4.89, n=19) |
| typescript-bun / opus47-1m | 2 (2.71, n=21) | 10 (4.85, n=20) |
| powershell / opus47-1m | 3 (2.62, n=21) | 4 (4.95, n=19) |
| bash / opus47-200k | 4 (2.57, n=7) | 6 (4.86, n=7) |
| bash / opus47-1m | 5 (2.52, n=21) | 18 (4.48, n=21) |
| powershell-tool / opus47-1m | 6 (2.52, n=21) | 1 (5.00, n=20) |
| typescript-bun / sonnet | 7 (2.43, n=7) | 16 (4.57, n=7) |
| powershell / opus47-200k | 8 (2.29, n=7) | 8 (4.86, n=7) |
| powershell / sonnet | 9 (2.29, n=7) | 20 (4.43, n=7) |
| powershell-tool / opus47-200k | 10 (2.29, n=7) | 9 (4.86, n=7) |
| powershell-tool / sonnet | 11 (2.29, n=7) | 14 (4.67, n=6) |
| bash / sonnet | 12 (2.14, n=7) | 7 (4.86, n=7) |
| default / sonnet | 13 (2.14, n=7) | 17 (4.50, n=6) |
| powershell / sonnet46-1m | 14 (2.14, n=7) | 27 (4.14, n=7) |
| powershell-tool / opus | 15 (2.14, n=7) | 15 (4.57, n=7) |
| bash / opus | 16 (2.00, n=7) | 23 (4.29, n=7) |
| typescript-bun / haiku45 | 17 (2.00, n=7) | 25 (4.29, n=7) |
| bash / haiku45 | 18 (1.86, n=7) | 30 (3.14, n=7) |
| powershell-tool / sonnet46-1m | 19 (1.86, n=7) | 21 (4.43, n=7) |
| typescript-bun / opus | 20 (1.86, n=7) | 2 (5.00, n=7) |
| typescript-bun / opus47-200k | 21 (1.86, n=7) | 3 (5.00, n=7) |
| typescript-bun / sonnet46-1m | 22 (1.86, n=7) | 22 (4.43, n=7) |
| default / haiku45 | 23 (1.71, n=7) | 28 (3.71, n=7) |
| default / opus | 24 (1.71, n=7) | 19 (4.43, n=7) |
| default / opus47-200k | 25 (1.71, n=7) | 12 (4.71, n=7) |
| default / sonnet46-1m | 26 (1.71, n=7) | 11 (4.83, n=6) |
| bash / sonnet46-1m | 27 (1.57, n=7) | 24 (4.29, n=7) |
| powershell / haiku45 | 28 (1.57, n=7) | 26 (4.17, n=6) |
| powershell / opus | 29 (1.57, n=7) | 13 (4.67, n=6) |
| powershell-tool / haiku45 | 30 (1.57, n=7) | 29 (3.29, n=7) |

*Spearman rank correlation between haiku45 and gemini31pro: **+0.48**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

**Pair-wise reversals** (where the two judges disagree on which language×model is better):

| Pair | haiku45 prefers | gemini31pro prefers | Own-family signal? |
|---|---|---|---|
| bash / haiku45 vs bash / sonnet46-1m | bash / haiku45 | bash / sonnet46-1m | ⚠️ haiku45 |
| bash / haiku45 vs default / haiku45 | bash / haiku45 | default / haiku45 | ⚠️ haiku45 |
| bash / haiku45 vs default / opus | bash / haiku45 | default / opus | ⚠️ haiku45 |
| bash / haiku45 vs default / opus47-200k | bash / haiku45 | default / opus47-200k | ⚠️ haiku45 |
| bash / haiku45 vs default / sonnet46-1m | bash / haiku45 | default / sonnet46-1m | ⚠️ haiku45 |
| bash / haiku45 vs powershell / haiku45 | bash / haiku45 | powershell / haiku45 | ⚠️ haiku45 |
| bash / haiku45 vs powershell / opus | bash / haiku45 | powershell / opus | ⚠️ haiku45 |
| bash / haiku45 vs powershell-tool / haiku45 | bash / haiku45 | powershell-tool / haiku45 | ⚠️ haiku45 |
| bash / haiku45 vs powershell-tool / sonnet46-1m | bash / haiku45 | powershell-tool / sonnet46-1m | ⚠️ haiku45 |
| bash / haiku45 vs typescript-bun / opus | bash / haiku45 | typescript-bun / opus | ⚠️ haiku45 |
| bash / haiku45 vs typescript-bun / opus47-200k | bash / haiku45 | typescript-bun / opus47-200k | ⚠️ haiku45 |
| bash / haiku45 vs typescript-bun / sonnet46-1m | bash / haiku45 | typescript-bun / sonnet46-1m | ⚠️ haiku45 |
| bash / opus vs default / opus | bash / opus | default / opus | — |
| bash / opus vs default / opus47-200k | bash / opus | default / opus47-200k | — |
| bash / opus vs default / sonnet46-1m | bash / opus | default / sonnet46-1m | — |
| bash / opus vs powershell / opus | bash / opus | powershell / opus | — |
| bash / opus vs powershell / sonnet46-1m | powershell / sonnet46-1m | bash / opus | — |
| bash / opus vs powershell-tool / sonnet46-1m | bash / opus | powershell-tool / sonnet46-1m | — |
| bash / opus vs typescript-bun / opus | bash / opus | typescript-bun / opus | — |
| bash / opus vs typescript-bun / opus47-200k | bash / opus | typescript-bun / opus47-200k | — |
| bash / opus vs typescript-bun / sonnet46-1m | bash / opus | typescript-bun / sonnet46-1m | — |
| bash / opus47-1m vs bash / sonnet | bash / opus47-1m | bash / sonnet | — |
| bash / opus47-1m vs default / opus47-200k | bash / opus47-1m | default / opus47-200k | — |
| bash / opus47-1m vs default / sonnet | bash / opus47-1m | default / sonnet | — |
| bash / opus47-1m vs default / sonnet46-1m | bash / opus47-1m | default / sonnet46-1m | — |
| bash / opus47-1m vs powershell / opus | bash / opus47-1m | powershell / opus | — |
| bash / opus47-1m vs powershell / opus47-200k | bash / opus47-1m | powershell / opus47-200k | — |
| bash / opus47-1m vs powershell-tool / opus | bash / opus47-1m | powershell-tool / opus | — |
| bash / opus47-1m vs powershell-tool / opus47-1m | bash / opus47-1m | powershell-tool / opus47-1m | — |
| bash / opus47-1m vs powershell-tool / opus47-200k | bash / opus47-1m | powershell-tool / opus47-200k | — |
| bash / opus47-1m vs powershell-tool / sonnet | bash / opus47-1m | powershell-tool / sonnet | — |
| bash / opus47-1m vs typescript-bun / opus | bash / opus47-1m | typescript-bun / opus | — |
| bash / opus47-1m vs typescript-bun / opus47-200k | bash / opus47-1m | typescript-bun / opus47-200k | — |
| bash / opus47-1m vs typescript-bun / sonnet | bash / opus47-1m | typescript-bun / sonnet | — |
| bash / opus47-200k vs powershell-tool / opus47-1m | bash / opus47-200k | powershell-tool / opus47-1m | — |
| bash / opus47-200k vs typescript-bun / opus | bash / opus47-200k | typescript-bun / opus | — |
| bash / opus47-200k vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | bash / opus47-200k | — |
| bash / opus47-200k vs typescript-bun / opus47-200k | bash / opus47-200k | typescript-bun / opus47-200k | — |
| bash / sonnet vs powershell / opus47-200k | powershell / opus47-200k | bash / sonnet | — |
| bash / sonnet vs powershell / sonnet | powershell / sonnet | bash / sonnet | — |
| bash / sonnet vs powershell-tool / opus47-200k | powershell-tool / opus47-200k | bash / sonnet | — |
| bash / sonnet vs powershell-tool / sonnet | powershell-tool / sonnet | bash / sonnet | — |
| bash / sonnet vs typescript-bun / opus | bash / sonnet | typescript-bun / opus | — |
| bash / sonnet vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | bash / sonnet | — |
| bash / sonnet vs typescript-bun / opus47-200k | bash / sonnet | typescript-bun / opus47-200k | — |
| bash / sonnet vs typescript-bun / sonnet | typescript-bun / sonnet | bash / sonnet | — |
| bash / sonnet46-1m vs default / haiku45 | default / haiku45 | bash / sonnet46-1m | ⚠️ haiku45 |
| bash / sonnet46-1m vs powershell / opus | bash / sonnet46-1m | powershell / opus | — |
| bash / sonnet46-1m vs powershell / sonnet46-1m | powershell / sonnet46-1m | bash / sonnet46-1m | — |
| bash / sonnet46-1m vs typescript-bun / haiku45 | typescript-bun / haiku45 | bash / sonnet46-1m | ⚠️ haiku45 |
| default / haiku45 vs default / opus | default / haiku45 | default / opus | ⚠️ haiku45 |
| default / haiku45 vs default / opus47-200k | default / haiku45 | default / opus47-200k | ⚠️ haiku45 |
| default / haiku45 vs default / sonnet46-1m | default / haiku45 | default / sonnet46-1m | ⚠️ haiku45 |
| default / haiku45 vs powershell / haiku45 | default / haiku45 | powershell / haiku45 | ⚠️ haiku45 |
| default / haiku45 vs powershell / opus | default / haiku45 | powershell / opus | ⚠️ haiku45 |
| default / opus vs default / opus47-200k | default / opus | default / opus47-200k | — |
| default / opus vs default / sonnet46-1m | default / opus | default / sonnet46-1m | — |
| default / opus vs powershell / opus | default / opus | powershell / opus | — |
| default / opus vs powershell / sonnet | powershell / sonnet | default / opus | — |
| default / opus vs powershell / sonnet46-1m | powershell / sonnet46-1m | default / opus | — |
| default / opus vs powershell-tool / sonnet46-1m | powershell-tool / sonnet46-1m | default / opus | — |
| default / opus vs typescript-bun / haiku45 | typescript-bun / haiku45 | default / opus | ⚠️ haiku45 |
| default / opus vs typescript-bun / sonnet46-1m | typescript-bun / sonnet46-1m | default / opus | — |
| default / opus47-1m vs powershell / opus47-1m | default / opus47-1m | powershell / opus47-1m | — |
| default / opus47-1m vs powershell-tool / opus47-1m | default / opus47-1m | powershell-tool / opus47-1m | — |
| default / opus47-1m vs typescript-bun / opus | default / opus47-1m | typescript-bun / opus | — |
| default / opus47-1m vs typescript-bun / opus47-200k | default / opus47-1m | typescript-bun / opus47-200k | — |
| default / opus47-200k vs default / sonnet | default / sonnet | default / opus47-200k | — |
| default / opus47-200k vs default / sonnet46-1m | default / opus47-200k | default / sonnet46-1m | — |
| default / opus47-200k vs powershell / sonnet | powershell / sonnet | default / opus47-200k | — |
| default / opus47-200k vs powershell / sonnet46-1m | powershell / sonnet46-1m | default / opus47-200k | — |
| default / opus47-200k vs powershell-tool / opus | powershell-tool / opus | default / opus47-200k | — |
| default / opus47-200k vs powershell-tool / sonnet | powershell-tool / sonnet | default / opus47-200k | — |
| default / opus47-200k vs powershell-tool / sonnet46-1m | powershell-tool / sonnet46-1m | default / opus47-200k | — |
| default / opus47-200k vs typescript-bun / haiku45 | typescript-bun / haiku45 | default / opus47-200k | ⚠️ haiku45 |
| default / opus47-200k vs typescript-bun / sonnet | typescript-bun / sonnet | default / opus47-200k | — |
| default / opus47-200k vs typescript-bun / sonnet46-1m | typescript-bun / sonnet46-1m | default / opus47-200k | — |
| default / sonnet vs default / sonnet46-1m | default / sonnet | default / sonnet46-1m | — |
| default / sonnet vs powershell / opus | default / sonnet | powershell / opus | — |
| default / sonnet vs powershell / sonnet | powershell / sonnet | default / sonnet | — |
| default / sonnet vs powershell-tool / opus | default / sonnet | powershell-tool / opus | — |
| default / sonnet vs typescript-bun / opus | default / sonnet | typescript-bun / opus | — |
| default / sonnet vs typescript-bun / opus47-200k | default / sonnet | typescript-bun / opus47-200k | — |
| default / sonnet46-1m vs powershell / sonnet | powershell / sonnet | default / sonnet46-1m | — |
| default / sonnet46-1m vs powershell / sonnet46-1m | powershell / sonnet46-1m | default / sonnet46-1m | — |
| default / sonnet46-1m vs powershell-tool / opus | powershell-tool / opus | default / sonnet46-1m | — |
| default / sonnet46-1m vs powershell-tool / sonnet | powershell-tool / sonnet | default / sonnet46-1m | — |
| default / sonnet46-1m vs powershell-tool / sonnet46-1m | powershell-tool / sonnet46-1m | default / sonnet46-1m | — |
| default / sonnet46-1m vs typescript-bun / haiku45 | typescript-bun / haiku45 | default / sonnet46-1m | ⚠️ haiku45 |
| default / sonnet46-1m vs typescript-bun / sonnet | typescript-bun / sonnet | default / sonnet46-1m | — |
| default / sonnet46-1m vs typescript-bun / sonnet46-1m | typescript-bun / sonnet46-1m | default / sonnet46-1m | — |
| powershell / haiku45 vs powershell / opus | powershell / haiku45 | powershell / opus | ⚠️ haiku45 |
| powershell / haiku45 vs powershell / sonnet46-1m | powershell / sonnet46-1m | powershell / haiku45 | — |
| powershell / opus vs powershell / sonnet | powershell / sonnet | powershell / opus | — |
| powershell / opus vs powershell / sonnet46-1m | powershell / sonnet46-1m | powershell / opus | — |
| powershell / opus vs powershell-tool / opus | powershell-tool / opus | powershell / opus | — |
| powershell / opus vs powershell-tool / sonnet | powershell-tool / sonnet | powershell / opus | — |
| powershell / opus vs powershell-tool / sonnet46-1m | powershell-tool / sonnet46-1m | powershell / opus | — |
| powershell / opus vs typescript-bun / haiku45 | typescript-bun / haiku45 | powershell / opus | ⚠️ haiku45 |
| powershell / opus vs typescript-bun / sonnet | typescript-bun / sonnet | powershell / opus | — |
| powershell / opus vs typescript-bun / sonnet46-1m | typescript-bun / sonnet46-1m | powershell / opus | — |
| powershell / opus47-1m vs powershell-tool / opus47-1m | powershell / opus47-1m | powershell-tool / opus47-1m | — |
| powershell / opus47-1m vs typescript-bun / opus | powershell / opus47-1m | typescript-bun / opus | — |
| powershell / opus47-1m vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | powershell / opus47-1m | — |
| powershell / opus47-1m vs typescript-bun / opus47-200k | powershell / opus47-1m | typescript-bun / opus47-200k | — |
| powershell / opus47-200k vs typescript-bun / opus | powershell / opus47-200k | typescript-bun / opus | — |
| powershell / opus47-200k vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | powershell / opus47-200k | — |
| powershell / opus47-200k vs typescript-bun / opus47-200k | powershell / opus47-200k | typescript-bun / opus47-200k | — |
| powershell / opus47-200k vs typescript-bun / sonnet | typescript-bun / sonnet | powershell / opus47-200k | — |
| powershell / sonnet vs powershell-tool / opus | powershell / sonnet | powershell-tool / opus | — |
| powershell / sonnet vs powershell-tool / opus47-200k | powershell / sonnet | powershell-tool / opus47-200k | — |
| powershell / sonnet vs powershell-tool / sonnet | powershell / sonnet | powershell-tool / sonnet | — |
| powershell / sonnet vs typescript-bun / opus | powershell / sonnet | typescript-bun / opus | — |
| powershell / sonnet vs typescript-bun / opus47-200k | powershell / sonnet | typescript-bun / opus47-200k | — |
| powershell / sonnet46-1m vs powershell-tool / opus | powershell / sonnet46-1m | powershell-tool / opus | — |
| powershell / sonnet46-1m vs powershell-tool / sonnet46-1m | powershell / sonnet46-1m | powershell-tool / sonnet46-1m | — |
| powershell / sonnet46-1m vs typescript-bun / haiku45 | powershell / sonnet46-1m | typescript-bun / haiku45 | — |
| powershell / sonnet46-1m vs typescript-bun / opus | powershell / sonnet46-1m | typescript-bun / opus | — |
| powershell / sonnet46-1m vs typescript-bun / opus47-200k | powershell / sonnet46-1m | typescript-bun / opus47-200k | — |
| powershell / sonnet46-1m vs typescript-bun / sonnet46-1m | powershell / sonnet46-1m | typescript-bun / sonnet46-1m | — |
| powershell-tool / opus vs typescript-bun / opus | powershell-tool / opus | typescript-bun / opus | — |
| powershell-tool / opus vs typescript-bun / opus47-200k | powershell-tool / opus | typescript-bun / opus47-200k | — |
| powershell-tool / opus vs typescript-bun / sonnet | typescript-bun / sonnet | powershell-tool / opus | — |
| powershell-tool / opus47-1m vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | powershell-tool / opus47-1m | — |
| powershell-tool / opus47-200k vs typescript-bun / opus | powershell-tool / opus47-200k | typescript-bun / opus | — |
| powershell-tool / opus47-200k vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | powershell-tool / opus47-200k | — |
| powershell-tool / opus47-200k vs typescript-bun / opus47-200k | powershell-tool / opus47-200k | typescript-bun / opus47-200k | — |
| powershell-tool / opus47-200k vs typescript-bun / sonnet | typescript-bun / sonnet | powershell-tool / opus47-200k | — |
| powershell-tool / sonnet vs typescript-bun / opus | powershell-tool / sonnet | typescript-bun / opus | — |
| powershell-tool / sonnet vs typescript-bun / opus47-200k | powershell-tool / sonnet | typescript-bun / opus47-200k | — |
| powershell-tool / sonnet vs typescript-bun / sonnet | typescript-bun / sonnet | powershell-tool / sonnet | — |
| powershell-tool / sonnet46-1m vs typescript-bun / haiku45 | typescript-bun / haiku45 | powershell-tool / sonnet46-1m | ⚠️ haiku45 |
| powershell-tool / sonnet46-1m vs typescript-bun / opus | powershell-tool / sonnet46-1m | typescript-bun / opus | — |
| powershell-tool / sonnet46-1m vs typescript-bun / opus47-200k | powershell-tool / sonnet46-1m | typescript-bun / opus47-200k | — |
| typescript-bun / haiku45 vs typescript-bun / opus | typescript-bun / haiku45 | typescript-bun / opus | ⚠️ haiku45 |
| typescript-bun / haiku45 vs typescript-bun / opus47-200k | typescript-bun / haiku45 | typescript-bun / opus47-200k | ⚠️ haiku45 |
| typescript-bun / haiku45 vs typescript-bun / sonnet46-1m | typescript-bun / haiku45 | typescript-bun / sonnet46-1m | ⚠️ haiku45 |
| typescript-bun / opus vs typescript-bun / opus47-1m | typescript-bun / opus47-1m | typescript-bun / opus | — |
| typescript-bun / opus vs typescript-bun / sonnet | typescript-bun / sonnet | typescript-bun / opus | — |
| typescript-bun / opus47-1m vs typescript-bun / opus47-200k | typescript-bun / opus47-1m | typescript-bun / opus47-200k | — |
| typescript-bun / opus47-200k vs typescript-bun / sonnet | typescript-bun / sonnet | typescript-bun / opus47-200k | — |

## Per-run self-judgment rows (reference)

*Rows where a judge evaluated output from its own model family. These individual runs are kept as a sanity check — the actual bias test is the pair-wise ranking reversals in the table above. Filtered to rows whose inter-judge delta differs from the baseline delta by ≥1.0 point; such rows are plausibly interesting but don't by themselves indicate bias (absolute-score differences between judges are expected).*

### Tests Quality

*Baseline delta (gemini31pro − haiku45) across the whole dataset: **+1.68**.*

| Task | Mode | Model | Self judge | Self score | Other judge | Other score | Row Δ | Deviation |
|---|---|---|---|---|---|---|---|---|
| 11-semantic-version-bumper | bash | haiku45 | haiku45 | 2.0 | gemini31pro | 1.0 | -1.0 | -2.7 |
| 11-semantic-version-bumper | powershell-tool | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 11-semantic-version-bumper | typescript-bun | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 12-pr-label-assigner | bash | haiku45 | haiku45 | 2.0 | gemini31pro | 1.0 | -1.0 | -2.7 |
| 12-pr-label-assigner | default | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 12-pr-label-assigner | powershell | haiku45 | haiku45 | 2.0 | — | — | — | — |
| 12-pr-label-assigner | powershell-tool | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 12-pr-label-assigner | typescript-bun | haiku45 | haiku45 | 2.0 | gemini31pro | 1.0 | -1.0 | -2.7 |
| 13-dependency-license-checker | bash | haiku45 | haiku45 | 3.0 | gemini31pro | 1.0 | -2.0 | -3.7 |
| 13-dependency-license-checker | powershell | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 13-dependency-license-checker | typescript-bun | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 15-test-results-aggregator | bash | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 15-test-results-aggregator | powershell-tool | haiku45 | haiku45 | 3.0 | gemini31pro | 3.0 | +0.0 | -1.7 |
| 15-test-results-aggregator | typescript-bun | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 16-environment-matrix-generato | bash | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 16-environment-matrix-generato | powershell | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 16-environment-matrix-generato | powershell-tool | haiku45 | haiku45 | 4.0 | gemini31pro | 3.0 | -1.0 | -2.7 |
| 17-artifact-cleanup-script | default | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |
| 17-artifact-cleanup-script | powershell | haiku45 | haiku45 | 1.0 | gemini31pro | 4.0 | +3.0 | +1.3 |
| 18-secret-rotation-validator | bash | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -1.7 |

### Workflow Craft

*Baseline delta (gemini31pro − haiku45) across the whole dataset: **+2.36**.*

| Task | Mode | Model | Self judge | Self score | Other judge | Other score | Row Δ | Deviation |
|---|---|---|---|---|---|---|---|---|
| 11-semantic-version-bumper | default | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -2.4 |
| 11-semantic-version-bumper | powershell-tool | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -2.4 |
| 11-semantic-version-bumper | typescript-bun | haiku45 | haiku45 | 2.0 | gemini31pro | 3.0 | +1.0 | -1.4 |
| 12-pr-label-assigner | bash | haiku45 | haiku45 | 2.0 | gemini31pro | 1.0 | -1.0 | -3.4 |
| 12-pr-label-assigner | default | haiku45 | haiku45 | 2.0 | gemini31pro | 2.0 | +0.0 | -2.4 |
| 12-pr-label-assigner | powershell | haiku45 | haiku45 | 1.0 | — | — | — | — |
| 13-dependency-license-checker | bash | haiku45 | haiku45 | 2.0 | gemini31pro | 3.0 | +1.0 | -1.4 |
| 15-test-results-aggregator | default | haiku45 | haiku45 | 3.0 | gemini31pro | 4.0 | +1.0 | -1.4 |
| 15-test-results-aggregator | powershell | haiku45 | haiku45 | 1.0 | gemini31pro | 5.0 | +4.0 | +1.6 |
| 16-environment-matrix-generato | default | haiku45 | haiku45 | 1.0 | gemini31pro | 5.0 | +4.0 | +1.6 |
| 16-environment-matrix-generato | powershell-tool | haiku45 | haiku45 | 2.0 | gemini31pro | 3.0 | +1.0 | -1.4 |
| 17-artifact-cleanup-script | bash | haiku45 | haiku45 | 3.0 | gemini31pro | 4.0 | +1.0 | -1.4 |
| 17-artifact-cleanup-script | powershell-tool | haiku45 | haiku45 | 1.0 | gemini31pro | 2.0 | +1.0 | -1.4 |

