# Judge Consistency Data

*Raw panel-of-judges data plus a rankings-focused Quality Analysis. Backs the merged Conclusions and Judge Consistency Summary in the corresponding [`results.md`](results.md).*

## Notes

- **Generated:** 2026-04-21 09:00:36 AM ET
- **Source:** `/home/user/compare-agent-scripting-by-language/results/2026-04-09_152435`
- **Judges present:** haiku45, gemini31pro, sonnet-legacy
- **Score conventions:** Scores shown are the `overall` dimension from each judge (1-5). Δ column is the second judge minus the first; positive = second judge is more generous.

## Quality Analysis

Sonnet outperforms Opus on both code-quality axes, with both judges agreeing on every pairwise ordering (ρ = +1.00 on Tests Quality and Workflow Craft, zero reversals). On Workflow Craft specifically, the bash/sonnet combination sits at #1 for both judges, making it the single most agreed-upon top performer in the dataset.

- **Top Workflow Craft combo**: bash/sonnet leads the language×model table for both judges (Haiku 2.62, Gemini 5.00), with no reversal on this pairing.
- **Tests Quality top tier is sonnet-only**: All four sonnet language variants land in the upper half of the language×model table for both judges, consistent with the +1.00 model-ordering agreement.
- **Where rankings diverge**: Tests Quality language ordering reverses completely (ρ = -1.00) — one judge ranks typescript-bun first and bash last, the other flips that entirely, so language-level claims are judge-dependent.
- **Workflow Craft ceiling runs lower**: Aggregate scores on Workflow Craft (1.81 / 4.62) sit below Tests Quality (2.62 / 4.39), and both judges independently produce this gap.
- **No self-judgment bias detected**: Haiku's in-family runs show no rows exceeding the 1.0-point deviation threshold on either axis, so the model-ordering agreement holds without an own-family caveat.

*Provenance:* `claude-opus-4-7[1m]` at effort `max` via Claude CLI (from cache); 5 in / 6192 out tokens, $0.2440. Prompt: [`QUALITY_ANALYSIS_SYSTEM_PROMPT`](../../judge_consistency_report.py).

## Campaign summary

### Tests Quality

| Scope | n | haiku45 ovr | gemini31pro ovr | sonnet-legacy ovr |
|---|---|---|---|---|
| all | 64 | 2.62 | 4.39 | 3.39 |

### Workflow Craft

| Scope | n | haiku45 ovr | gemini31pro ovr | sonnet-legacy ovr |
|---|---|---|---|---|
| all | 16 | 1.81 | 4.62 | 2.94 |

## By task

### Tests Quality

| Task | n | haiku45 ovr | gemini31pro ovr | sonnet-legacy ovr |
|---|---|---|---|---|
| 11-semantic-version-bumper | 8 | 2.38 | 4.38 | 3.12 |
| 12-pr-label-assigner | 8 | 2.75 | 4.00 | 4.00 |
| 13-dependency-license-checker | 8 | 3.00 | 4.25 | 3.62 |
| 14-docker-image-tag-generator | 8 | 2.25 | 4.75 | 3.50 |
| 15-test-results-aggregator | 8 | 2.88 | 4.75 | 3.00 |
| 16-environment-matrix-generator | 8 | 2.38 | 4.75 | 3.12 |
| 17-artifact-cleanup-script | 8 | 2.75 | 3.25 | 3.62 |
| 18-secret-rotation-validator | 8 | 2.62 | 5.00 | 3.12 |

### Workflow Craft

| Task | n | haiku45 ovr | gemini31pro ovr | sonnet-legacy ovr |
|---|---|---|---|---|
| 11-semantic-version-bumper | 8 | 1.88 | 4.75 | 2.75 |
| 12-pr-label-assigner | 8 | 1.75 | 4.50 | 3.12 |

## By language mode

### Tests Quality

| Mode | n | haiku45 ovr | gemini31pro ovr | sonnet-legacy ovr |
|---|---|---|---|---|
| bash | 16 | 2.38 | 4.62 | 3.44 |
| default | 16 | 2.69 | 4.31 | 3.44 |
| powershell | 16 | 2.62 | 4.38 | 3.31 |
| typescript-bun | 16 | 2.81 | 4.25 | 3.38 |

### Workflow Craft

| Mode | n | haiku45 ovr | gemini31pro ovr | sonnet-legacy ovr |
|---|---|---|---|---|
| bash | 4 | 2.00 | 4.50 | 3.00 |
| default | 4 | 1.50 | 4.25 | 2.75 |
| powershell | 4 | 2.25 | 5.00 | 3.25 |
| typescript-bun | 4 | 1.50 | 4.75 | 2.75 |

## By model + effort

### Tests Quality

| Model-Effort | n | haiku45 ovr | gemini31pro ovr | sonnet-legacy ovr |
|---|---|---|---|---|
| opus | 32 | 2.38 | 4.28 | 3.03 |
| sonnet | 32 | 2.88 | 4.50 | 3.75 |

### Workflow Craft

| Model-Effort | n | haiku45 ovr | gemini31pro ovr | sonnet-legacy ovr |
|---|---|---|---|---|
| opus | 8 | 1.75 | 4.50 | 2.75 |
| sonnet | 8 | 1.88 | 4.75 | 3.12 |

## Disagreement hotspots (panel span ≥ 2 on overall)

### Tests Quality

| Task | Mode | Model | Span | haiku45 ovr | gemini31pro ovr | sonnet-legacy ovr |
|---|---|---|---|---|---|---|
| 14-docker-image-tag-generator | default | opus | 4.0 | 1.0 | 5.0 | 3.0 |
| 16-environment-matrix-generato | bash | opus | 4.0 | 1.0 | 5.0 | 2.0 |
| 11-semantic-version-bumper | bash | opus | 3.0 | 2.0 | 5.0 | 4.0 |
| 11-semantic-version-bumper | bash | sonnet | 3.0 | 2.0 | 5.0 | 4.0 |
| 11-semantic-version-bumper | default | opus | 3.0 | 3.0 | 5.0 | 2.0 |
| 11-semantic-version-bumper | powershell | opus | 3.0 | 1.0 | 4.0 | 2.0 |
| 12-pr-label-assigner | default | sonnet | 3.0 | 2.0 | 5.0 | 4.0 |
| 14-docker-image-tag-generator | default | sonnet | 3.0 | 2.0 | 5.0 | 4.0 |
| 14-docker-image-tag-generator | powershell | opus | 3.0 | 2.0 | 5.0 | 3.0 |
| 14-docker-image-tag-generator | typescript-bun | opus | 3.0 | 2.0 | 5.0 | 2.0 |
| 15-test-results-aggregator | default | opus | 3.0 | 2.0 | 5.0 | 2.0 |
| 15-test-results-aggregator | powershell | opus | 3.0 | 2.0 | 5.0 | 2.0 |
| 15-test-results-aggregator | powershell | sonnet | 3.0 | 4.0 | 5.0 | 2.0 |
| 15-test-results-aggregator | typescript-bun | opus | 3.0 | 2.0 | 5.0 | 3.0 |
| 16-environment-matrix-generato | default | sonnet | 3.0 | 2.0 | 5.0 | 4.0 |
| 16-environment-matrix-generato | typescript-bun | opus | 3.0 | 2.0 | 5.0 | 2.0 |
| 17-artifact-cleanup-script | bash | opus | 3.0 | 2.0 | 5.0 | 3.0 |
| 18-secret-rotation-validator | bash | opus | 3.0 | 2.0 | 5.0 | 3.0 |
| 18-secret-rotation-validator | bash | sonnet | 3.0 | 2.0 | 5.0 | 3.0 |
| 18-secret-rotation-validator | powershell | opus | 3.0 | 2.0 | 5.0 | 3.0 |
| 11-semantic-version-bumper | default | sonnet | 2.0 | 3.0 | 2.0 | 4.0 |
| 11-semantic-version-bumper | powershell | sonnet | 2.0 | 3.0 | 5.0 | 4.0 |
| 11-semantic-version-bumper | typescript-bun | opus | 2.0 | 2.0 | 4.0 | 2.0 |
| 11-semantic-version-bumper | typescript-bun | sonnet | 2.0 | 3.0 | 5.0 | 3.0 |
| 12-pr-label-assigner | bash | opus | 2.0 | 1.0 | 3.0 | 2.0 |

### Workflow Craft

| Task | Mode | Model | Span | haiku45 ovr | gemini31pro ovr | sonnet-legacy ovr |
|---|---|---|---|---|---|---|
| 11-semantic-version-bumper | bash | sonnet | 4.0 | 1.0 | 5.0 | 3.0 |
| 11-semantic-version-bumper | typescript-bun | opus | 4.0 | 1.0 | 5.0 | 2.0 |
| 12-pr-label-assigner | default | sonnet | 4.0 | 1.0 | 5.0 | 3.0 |
| 11-semantic-version-bumper | bash | opus | 3.0 | 2.0 | 5.0 | 3.0 |
| 11-semantic-version-bumper | powershell | opus | 3.0 | 2.0 | 5.0 | 3.0 |
| 11-semantic-version-bumper | typescript-bun | sonnet | 3.0 | 2.0 | 5.0 | 3.0 |
| 12-pr-label-assigner | default | opus | 3.0 | 1.0 | 4.0 | 3.0 |
| 12-pr-label-assigner | powershell | opus | 3.0 | 2.0 | 5.0 | 3.0 |
| 12-pr-label-assigner | powershell | sonnet | 3.0 | 2.0 | 5.0 | 4.0 |
| 12-pr-label-assigner | typescript-bun | opus | 3.0 | 2.0 | 5.0 | 3.0 |
| 12-pr-label-assigner | typescript-bun | sonnet | 3.0 | 1.0 | 4.0 | 3.0 |
| 11-semantic-version-bumper | default | opus | 2.0 | 2.0 | 4.0 | 2.0 |
| 11-semantic-version-bumper | default | sonnet | 2.0 | 2.0 | 4.0 | 3.0 |
| 11-semantic-version-bumper | powershell | sonnet | 2.0 | 3.0 | 5.0 | 3.0 |
| 12-pr-label-assigner | bash | sonnet | 2.0 | 3.0 | 5.0 | 3.0 |

## Model rankings by judge

*Agreement on model ordering tells us the panel agrees on which configurations produce better output on this axis. Absolute-score differences between judges are expected (different grading scales) and are not a bias concern.*

### Tests Quality

| Model | haiku45 rank (mean, n) | gemini31pro rank (mean, n) | sonnet-legacy rank (mean, n) |
|---|---|---|---|
| sonnet | 1 (2.88, n=32) | 1 (4.50, n=32) | 1 (3.75, n=32) |
| opus | 2 (2.38, n=32) | 2 (4.28, n=32) | 2 (3.03, n=32) |

*Spearman rank correlation between haiku45 and gemini31pro: **+1.00**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

*No pair-wise reversals — both judges agree on every model-vs-model ordering.*

### Workflow Craft

| Model | haiku45 rank (mean, n) | gemini31pro rank (mean, n) | sonnet-legacy rank (mean, n) |
|---|---|---|---|
| sonnet | 1 (2.38, n=32) | 1 (4.75, n=32) | 1 (3.12, n=8) |
| opus | 2 (2.09, n=32) | 2 (4.53, n=32) | 2 (2.75, n=8) |

*Spearman rank correlation between haiku45 and gemini31pro: **+1.00**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

*No pair-wise reversals — both judges agree on every model-vs-model ordering.*

## Language rankings by judge

*Agreement on language ordering tells us the panel agrees on which configurations produce better output on this axis. Absolute-score differences between judges are expected (different grading scales) and are not a bias concern.*

### Tests Quality

| Language | haiku45 rank (mean, n) | gemini31pro rank (mean, n) | sonnet-legacy rank (mean, n) |
|---|---|---|---|
| typescript-bun | 1 (2.81, n=16) | 4 (4.25, n=16) | 3 (3.38, n=16) |
| default | 2 (2.69, n=16) | 3 (4.31, n=16) | 2 (3.44, n=16) |
| powershell | 3 (2.62, n=16) | 2 (4.38, n=16) | 4 (3.31, n=16) |
| bash | 4 (2.38, n=16) | 1 (4.62, n=16) | 1 (3.44, n=16) |

*Spearman rank correlation between haiku45 and gemini31pro: **-1.00**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

**Pair-wise reversals** (where the two judges disagree on which language is better):

| Pair | haiku45 prefers | gemini31pro prefers | Own-family signal? |
|---|---|---|---|
| bash vs default | default | bash | — |
| bash vs powershell | powershell | bash | — |
| bash vs typescript-bun | typescript-bun | bash | — |
| default vs powershell | default | powershell | — |
| default vs typescript-bun | typescript-bun | default | — |
| powershell vs typescript-bun | typescript-bun | powershell | — |

### Workflow Craft

| Language | haiku45 rank (mean, n) | gemini31pro rank (mean, n) | sonnet-legacy rank (mean, n) |
|---|---|---|---|
| default | 1 (2.38, n=16) | 3 (4.62, n=16) | 3 (2.75, n=4) |
| bash | 2 (2.25, n=16) | 2 (4.62, n=16) | 2 (3.00, n=4) |
| powershell | 3 (2.19, n=16) | 4 (4.56, n=16) | 1 (3.25, n=4) |
| typescript-bun | 4 (2.12, n=16) | 1 (4.75, n=16) | 4 (2.75, n=4) |

*Spearman rank correlation between haiku45 and gemini31pro: **-0.40**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

**Pair-wise reversals** (where the two judges disagree on which language is better):

| Pair | haiku45 prefers | gemini31pro prefers | Own-family signal? |
|---|---|---|---|
| bash vs default | default | bash | — |
| bash vs typescript-bun | bash | typescript-bun | — |
| default vs typescript-bun | default | typescript-bun | — |
| powershell vs typescript-bun | powershell | typescript-bun | — |

## Language×Model rankings by judge

*Agreement on language×model ordering tells us the panel agrees on which configurations produce better output on this axis. Absolute-score differences between judges are expected (different grading scales) and are not a bias concern.*

### Tests Quality

| Language / Model | haiku45 rank (mean, n) | gemini31pro rank (mean, n) | sonnet-legacy rank (mean, n) |
|---|---|---|---|
| powershell / sonnet | 1 (3.00, n=8) | 2 (4.62, n=8) | 4 (3.50, n=8) |
| typescript-bun / sonnet | 2 (3.00, n=8) | 7 (4.25, n=8) | 2 (3.88, n=8) |
| bash / sonnet | 3 (2.75, n=8) | 1 (4.75, n=8) | 1 (3.88, n=8) |
| default / sonnet | 4 (2.75, n=8) | 4 (4.38, n=8) | 3 (3.75, n=8) |
| default / opus | 5 (2.62, n=8) | 5 (4.25, n=8) | 5 (3.12, n=8) |
| typescript-bun / opus | 6 (2.62, n=8) | 6 (4.25, n=8) | 8 (2.88, n=8) |
| powershell / opus | 7 (2.25, n=8) | 8 (4.12, n=8) | 6 (3.12, n=8) |
| bash / opus | 8 (2.00, n=8) | 3 (4.50, n=8) | 7 (3.00, n=8) |

*Spearman rank correlation between haiku45 and gemini31pro: **+0.33**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

**Pair-wise reversals** (where the two judges disagree on which language×model is better):

| Pair | haiku45 prefers | gemini31pro prefers | Own-family signal? |
|---|---|---|---|
| bash / opus vs default / opus | default / opus | bash / opus | — |
| bash / opus vs default / sonnet | default / sonnet | bash / opus | — |
| bash / opus vs powershell / opus | powershell / opus | bash / opus | — |
| bash / opus vs typescript-bun / opus | typescript-bun / opus | bash / opus | — |
| bash / opus vs typescript-bun / sonnet | typescript-bun / sonnet | bash / opus | — |
| bash / sonnet vs powershell / sonnet | powershell / sonnet | bash / sonnet | — |
| bash / sonnet vs typescript-bun / sonnet | typescript-bun / sonnet | bash / sonnet | — |
| default / opus vs typescript-bun / sonnet | typescript-bun / sonnet | default / opus | — |
| default / sonnet vs typescript-bun / sonnet | typescript-bun / sonnet | default / sonnet | — |
| typescript-bun / opus vs typescript-bun / sonnet | typescript-bun / sonnet | typescript-bun / opus | — |

### Workflow Craft

| Language / Model | haiku45 rank (mean, n) | gemini31pro rank (mean, n) | sonnet-legacy rank (mean, n) |
|---|---|---|---|
| bash / sonnet | 1 (2.62, n=8) | 1 (5.00, n=8) | 3 (3.00, n=2) |
| default / opus | 2 (2.50, n=8) | 6 (4.50, n=8) | 7 (2.50, n=2) |
| powershell / sonnet | 3 (2.50, n=8) | 7 (4.50, n=8) | 1 (3.50, n=2) |
| default / sonnet | 4 (2.25, n=8) | 2 (4.75, n=8) | 4 (3.00, n=2) |
| typescript-bun / opus | 5 (2.12, n=8) | 3 (4.75, n=8) | 8 (2.50, n=2) |
| typescript-bun / sonnet | 6 (2.12, n=8) | 4 (4.75, n=8) | 6 (3.00, n=2) |
| bash / opus | 7 (1.88, n=8) | 8 (4.25, n=8) | 2 (3.00, n=2) |
| powershell / opus | 8 (1.88, n=8) | 5 (4.62, n=8) | 5 (3.00, n=2) |

*Spearman rank correlation between haiku45 and gemini31pro: **+0.36**. (+1.0 = judges agree perfectly on ordering; 0 = no correlation; -1.0 = reversed.)*

**Pair-wise reversals** (where the two judges disagree on which language×model is better):

| Pair | haiku45 prefers | gemini31pro prefers | Own-family signal? |
|---|---|---|---|
| bash / opus vs powershell / opus | bash / opus | powershell / opus | — |
| default / opus vs default / sonnet | default / opus | default / sonnet | — |
| default / opus vs powershell / opus | default / opus | powershell / opus | — |
| default / opus vs typescript-bun / opus | default / opus | typescript-bun / opus | — |
| default / opus vs typescript-bun / sonnet | default / opus | typescript-bun / sonnet | — |
| default / sonnet vs powershell / sonnet | powershell / sonnet | default / sonnet | — |
| powershell / opus vs powershell / sonnet | powershell / sonnet | powershell / opus | — |
| powershell / sonnet vs typescript-bun / opus | powershell / sonnet | typescript-bun / opus | — |
| powershell / sonnet vs typescript-bun / sonnet | powershell / sonnet | typescript-bun / sonnet | — |

## Per-run self-judgment rows (reference)

*Rows where a judge evaluated output from its own model family. These individual runs are kept as a sanity check — the actual bias test is the pair-wise ranking reversals in the table above. Filtered to rows whose inter-judge delta differs from the baseline delta by ≥1.0 point; such rows are plausibly interesting but don't by themselves indicate bias (absolute-score differences between judges are expected).*

### Tests Quality

*(no self-judgment rows exceed the 1.0-point deviation threshold — judges agree about in-family output roughly as much as about out-of-family output)*

### Workflow Craft

*(no self-judgment rows exceed the 1.0-point deviation threshold — judges agree about in-family output roughly as much as about out-of-family output)*

