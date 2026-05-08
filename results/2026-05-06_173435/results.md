# Benchmark Results: Language Comparison

**Last updated:** 2026-05-07 10:20:20 PM ET — 201/210 runs completed, 9 remaining; total cost $364.89; total agent time 1720.9 min.

## Table of Contents

- [Scoring](#scoring)
- [Tiers by Language/Model/Effort](#tiers-by-languagemodeleffort)
- [Failed / Timed-Out Runs](#failed-timed-out-runs)
- [Comparison by Language/Model/Effort](#comparison-by-languagemodeleffort)
- [Savings Analysis](#savings-analysis)
  - [Hook Savings by Language/Model/Effort](#hook-savings-by-languagemodeleffort)
  - [Trap Analysis by Language/Model/Effort/Category](#trap-analysis-by-languagemodeleffortcategory)
  - [Traps by Language/Model/Effort](#traps-by-languagemodeleffort)
  - [Prompt Cache Savings](#prompt-cache-savings)
- [Test Quality Evaluation](#test-quality-evaluation)
  - [Structural Metrics by Language/Model/Effort](#structural-metrics-by-languagemodeleffort)
- [Per-Run Results](#per-run-results)
- [Notes](#notes)
  - [Tiers](#tiers)
  - [CLI Version Legend](#cli-version-legend)

## Scoring

Judges: panel of LLM-as-judge models — `haiku-4-5` (via Claude CLI) and `gemini-3.1-pro-preview` (via Gemini CLI). Each run's quality score is the mean of both judges, cached per-run so numbers are deterministic across regenerations. Known bias caveats live in the [Judge Consistency Summary](#judge-consistency-summary).

**Tests Quality** = Overall score (1-5) for the generated **test code**.

Dimensions:
- **coverage** — requirements tested
- **rigor** — edge cases + error paths
- **design** — fixture quality + independence
- **overall** — holistic

**Workflow Craft** = Overall score (1-5) for the produced **deliverable** (workflow YAML + scripts, excluding tests).

Dimensions:
- **best_practices** — language-appropriate conventions
- **conciseness** — penalizes dead code AND repetition that should be factored
- **readability** — clarity for a reader encountering it cold
- **maintainability** — modularity, error-handling, testability
- **overall** — holistic

**Duration / Cost** = ratio of each combo's average to the best combo's average on the same axis (lower is better).

Properties:
- **Scale:** ratios, not raw seconds or dollars
- **Band calibration:** auto-calibrated to the data's best-to-worst spread via log-equal division (`boundary_i = max_ratio^(i/12)`), so the best observed ratio lands at A+ and the worst at D-
- **F band:** reserved for ratios beyond the observed worst
## Tiers by Language/Model/Effort

*Default sort: weighted composite of tiers (40% Tests, 25% Workflow Craft, 35% split between Duration & Cost). See [Notes](#notes) for tier-band definitions and scoring rubric.*
*`*` after a Model label = this combo's aggregates exclude one or more failed/timed-out runs (see the Failed / Timed-Out Runs table).*

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | A- (5.5min) | A ($0.48) | — | — |
| bash | opus47-1m-medium | A+ (4.4min) | B- ($1.16) | — | — |
| powershell | haiku45-200k* | B (6.4min) | A ($0.54) | — | — |
| default | opus47-1m-medium | A+ (4.6min) | C+ ($1.18) | — | — |
| powershell-tool | haiku45-200k | B- (7.2min) | A ($0.48) | — | — |
| typescript-bun | opus47-1m-medium | A- (5.5min) | C+ ($1.33) | — | — |
| bash | haiku45-200k | C+ (7.6min) | B+ ($0.70) | — | — |
| typescript-bun | opus46-200k | B+ (6.2min) | C+ ($1.30) | — | — |
| default | opus46-200k | B (6.4min) | C+ ($1.37) | — | — |
| powershell-tool | opus47-1m-medium | B+ (5.9min) | C ($1.54) | — | — |
| powershell | opus47-1m-medium | B- (7.1min) | C- ($1.70) | — | — |
| bash | opus46-200k | C (8.3min) | C ($1.63) | — | — |
| powershell-tool | opus46-200k | C (8.1min) | C ($1.56) | — | — |
| default | opus47-1m-high | C+ (8.0min) | D+ ($2.20) | — | — |
| typescript-bun | sonnet46-200k | C- (9.0min) | C ($1.50) | — | — |
| default | sonnet46-200k | D+ (9.9min) | C ($1.47) | — | — |
| powershell | opus46-200k | C- (8.8min) | C- ($1.79) | — | — |
| powershell | sonnet46-200k | D (11.2min) | C ($1.63) | — | — |
| powershell-tool | sonnet46-200k | D (10.7min) | C ($1.47) | — | — |
| bash | sonnet46-200k | D- (11.3min) | C ($1.62) | — | — |
| typescript-bun | opus47-1m-high | C- (8.9min) | D ($2.75) | — | — |
| powershell | opus47-1m-high | D+ (10.3min) | D ($2.80) | — | — |
| bash | opus47-1m-high | D (10.5min) | D ($2.56) | — | — |
| bash | opus47-1m-xhigh | D+ (10.3min) | D- ($3.09) | — | — |
| default | opus47-1m-xhigh | D (10.9min) | D- ($3.46) | — | — |
| powershell-tool | opus47-1m-xhigh* | D (11.0min) | D- ($3.43) | — | — |
| powershell | opus47-1m-xhigh | D- (11.9min) | D- ($3.51) | — | — |
| powershell-tool | opus47-1m-high | D- (11.8min) | D- ($3.55) | — | — |
| typescript-bun | opus47-1m-xhigh | D- (12.3min) | D- ($3.48) | — | — |


<details>
<summary>Sorted by Duration tier (best-first), then avg of Cost/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.38) | — | — |
| bash | opus47-1m-medium | A+ (4.4min) | B- ($1.16) | — | — |
| default | opus47-1m-medium | A+ (4.6min) | C+ ($1.18) | — | — |
| typescript-bun | haiku45-200k | A- (5.5min) | A ($0.48) | — | — |
| typescript-bun | opus47-1m-medium | A- (5.5min) | C+ ($1.33) | — | — |
| typescript-bun | opus46-200k | B+ (6.2min) | C+ ($1.30) | — | — |
| powershell-tool | opus47-1m-medium | B+ (5.9min) | C ($1.54) | — | — |
| powershell | haiku45-200k* | B (6.4min) | A ($0.54) | — | — |
| default | opus46-200k | B (6.4min) | C+ ($1.37) | — | — |
| powershell-tool | haiku45-200k | B- (7.2min) | A ($0.48) | — | — |
| powershell | opus47-1m-medium | B- (7.1min) | C- ($1.70) | — | — |
| bash | haiku45-200k | C+ (7.6min) | B+ ($0.70) | — | — |
| default | opus47-1m-high | C+ (8.0min) | D+ ($2.20) | — | — |
| bash | opus46-200k | C (8.3min) | C ($1.63) | — | — |
| powershell-tool | opus46-200k | C (8.1min) | C ($1.56) | — | — |
| typescript-bun | sonnet46-200k | C- (9.0min) | C ($1.50) | — | — |
| powershell | opus46-200k | C- (8.8min) | C- ($1.79) | — | — |
| typescript-bun | opus47-1m-high | C- (8.9min) | D ($2.75) | — | — |
| default | sonnet46-200k | D+ (9.9min) | C ($1.47) | — | — |
| powershell | opus47-1m-high | D+ (10.3min) | D ($2.80) | — | — |
| bash | opus47-1m-xhigh | D+ (10.3min) | D- ($3.09) | — | — |
| powershell | sonnet46-200k | D (11.2min) | C ($1.63) | — | — |
| powershell-tool | sonnet46-200k | D (10.7min) | C ($1.47) | — | — |
| bash | opus47-1m-high | D (10.5min) | D ($2.56) | — | — |
| default | opus47-1m-xhigh | D (10.9min) | D- ($3.46) | — | — |
| powershell-tool | opus47-1m-xhigh* | D (11.0min) | D- ($3.43) | — | — |
| bash | sonnet46-200k | D- (11.3min) | C ($1.62) | — | — |
| powershell | opus47-1m-xhigh | D- (11.9min) | D- ($3.51) | — | — |
| powershell-tool | opus47-1m-high | D- (11.8min) | D- ($3.55) | — | — |
| typescript-bun | opus47-1m-xhigh | D- (12.3min) | D- ($3.48) | — | — |

</details>

<details>
<summary>Sorted by Cost tier (best-first), then avg of Duration/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | A- (5.5min) | A ($0.48) | — | — |
| powershell | haiku45-200k* | B (6.4min) | A ($0.54) | — | — |
| powershell-tool | haiku45-200k | B- (7.2min) | A ($0.48) | — | — |
| bash | haiku45-200k | C+ (7.6min) | B+ ($0.70) | — | — |
| bash | opus47-1m-medium | A+ (4.4min) | B- ($1.16) | — | — |
| default | opus47-1m-medium | A+ (4.6min) | C+ ($1.18) | — | — |
| typescript-bun | opus47-1m-medium | A- (5.5min) | C+ ($1.33) | — | — |
| typescript-bun | opus46-200k | B+ (6.2min) | C+ ($1.30) | — | — |
| default | opus46-200k | B (6.4min) | C+ ($1.37) | — | — |
| powershell-tool | opus47-1m-medium | B+ (5.9min) | C ($1.54) | — | — |
| bash | opus46-200k | C (8.3min) | C ($1.63) | — | — |
| powershell-tool | opus46-200k | C (8.1min) | C ($1.56) | — | — |
| typescript-bun | sonnet46-200k | C- (9.0min) | C ($1.50) | — | — |
| default | sonnet46-200k | D+ (9.9min) | C ($1.47) | — | — |
| powershell | sonnet46-200k | D (11.2min) | C ($1.63) | — | — |
| powershell-tool | sonnet46-200k | D (10.7min) | C ($1.47) | — | — |
| bash | sonnet46-200k | D- (11.3min) | C ($1.62) | — | — |
| powershell | opus47-1m-medium | B- (7.1min) | C- ($1.70) | — | — |
| powershell | opus46-200k | C- (8.8min) | C- ($1.79) | — | — |
| default | opus47-1m-high | C+ (8.0min) | D+ ($2.20) | — | — |
| typescript-bun | opus47-1m-high | C- (8.9min) | D ($2.75) | — | — |
| powershell | opus47-1m-high | D+ (10.3min) | D ($2.80) | — | — |
| bash | opus47-1m-high | D (10.5min) | D ($2.56) | — | — |
| bash | opus47-1m-xhigh | D+ (10.3min) | D- ($3.09) | — | — |
| default | opus47-1m-xhigh | D (10.9min) | D- ($3.46) | — | — |
| powershell-tool | opus47-1m-xhigh* | D (11.0min) | D- ($3.43) | — | — |
| powershell | opus47-1m-xhigh | D- (11.9min) | D- ($3.51) | — | — |
| powershell-tool | opus47-1m-high | D- (11.8min) | D- ($3.55) | — | — |
| typescript-bun | opus47-1m-xhigh | D- (12.3min) | D- ($3.48) | — | — |

</details>

<details>
<summary>Sorted by Tests Quality tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | A- (5.5min) | A ($0.48) | — | — |
| bash | opus47-1m-medium | A+ (4.4min) | B- ($1.16) | — | — |
| powershell | haiku45-200k* | B (6.4min) | A ($0.54) | — | — |
| default | opus47-1m-medium | A+ (4.6min) | C+ ($1.18) | — | — |
| powershell-tool | haiku45-200k | B- (7.2min) | A ($0.48) | — | — |
| typescript-bun | opus47-1m-medium | A- (5.5min) | C+ ($1.33) | — | — |
| bash | haiku45-200k | C+ (7.6min) | B+ ($0.70) | — | — |
| typescript-bun | opus46-200k | B+ (6.2min) | C+ ($1.30) | — | — |
| default | opus46-200k | B (6.4min) | C+ ($1.37) | — | — |
| powershell-tool | opus47-1m-medium | B+ (5.9min) | C ($1.54) | — | — |
| powershell | opus47-1m-medium | B- (7.1min) | C- ($1.70) | — | — |
| bash | opus46-200k | C (8.3min) | C ($1.63) | — | — |
| powershell-tool | opus46-200k | C (8.1min) | C ($1.56) | — | — |
| default | opus47-1m-high | C+ (8.0min) | D+ ($2.20) | — | — |
| typescript-bun | sonnet46-200k | C- (9.0min) | C ($1.50) | — | — |
| default | sonnet46-200k | D+ (9.9min) | C ($1.47) | — | — |
| powershell | opus46-200k | C- (8.8min) | C- ($1.79) | — | — |
| powershell | sonnet46-200k | D (11.2min) | C ($1.63) | — | — |
| powershell-tool | sonnet46-200k | D (10.7min) | C ($1.47) | — | — |
| bash | sonnet46-200k | D- (11.3min) | C ($1.62) | — | — |
| typescript-bun | opus47-1m-high | C- (8.9min) | D ($2.75) | — | — |
| powershell | opus47-1m-high | D+ (10.3min) | D ($2.80) | — | — |
| bash | opus47-1m-high | D (10.5min) | D ($2.56) | — | — |
| bash | opus47-1m-xhigh | D+ (10.3min) | D- ($3.09) | — | — |
| default | opus47-1m-xhigh | D (10.9min) | D- ($3.46) | — | — |
| powershell-tool | opus47-1m-xhigh* | D (11.0min) | D- ($3.43) | — | — |
| powershell | opus47-1m-xhigh | D- (11.9min) | D- ($3.51) | — | — |
| powershell-tool | opus47-1m-high | D- (11.8min) | D- ($3.55) | — | — |
| typescript-bun | opus47-1m-xhigh | D- (12.3min) | D- ($3.48) | — | — |

</details>

<details>
<summary>Sorted by Workflow Craft tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | A- (5.5min) | A ($0.48) | — | — |
| bash | opus47-1m-medium | A+ (4.4min) | B- ($1.16) | — | — |
| powershell | haiku45-200k* | B (6.4min) | A ($0.54) | — | — |
| default | opus47-1m-medium | A+ (4.6min) | C+ ($1.18) | — | — |
| powershell-tool | haiku45-200k | B- (7.2min) | A ($0.48) | — | — |
| typescript-bun | opus47-1m-medium | A- (5.5min) | C+ ($1.33) | — | — |
| bash | haiku45-200k | C+ (7.6min) | B+ ($0.70) | — | — |
| typescript-bun | opus46-200k | B+ (6.2min) | C+ ($1.30) | — | — |
| default | opus46-200k | B (6.4min) | C+ ($1.37) | — | — |
| powershell-tool | opus47-1m-medium | B+ (5.9min) | C ($1.54) | — | — |
| powershell | opus47-1m-medium | B- (7.1min) | C- ($1.70) | — | — |
| bash | opus46-200k | C (8.3min) | C ($1.63) | — | — |
| powershell-tool | opus46-200k | C (8.1min) | C ($1.56) | — | — |
| default | opus47-1m-high | C+ (8.0min) | D+ ($2.20) | — | — |
| typescript-bun | sonnet46-200k | C- (9.0min) | C ($1.50) | — | — |
| default | sonnet46-200k | D+ (9.9min) | C ($1.47) | — | — |
| powershell | opus46-200k | C- (8.8min) | C- ($1.79) | — | — |
| powershell | sonnet46-200k | D (11.2min) | C ($1.63) | — | — |
| powershell-tool | sonnet46-200k | D (10.7min) | C ($1.47) | — | — |
| bash | sonnet46-200k | D- (11.3min) | C ($1.62) | — | — |
| typescript-bun | opus47-1m-high | C- (8.9min) | D ($2.75) | — | — |
| powershell | opus47-1m-high | D+ (10.3min) | D ($2.80) | — | — |
| bash | opus47-1m-high | D (10.5min) | D ($2.56) | — | — |
| bash | opus47-1m-xhigh | D+ (10.3min) | D- ($3.09) | — | — |
| default | opus47-1m-xhigh | D (10.9min) | D- ($3.46) | — | — |
| powershell-tool | opus47-1m-xhigh* | D (11.0min) | D- ($3.43) | — | — |
| powershell | opus47-1m-xhigh | D- (11.9min) | D- ($3.51) | — | — |
| powershell-tool | opus47-1m-high | D- (11.8min) | D- ($3.55) | — | — |
| typescript-bun | opus47-1m-xhigh | D- (12.3min) | D- ($3.48) | — | — |

</details>

- **Estimated time remaining:** 1575.3min
- **Estimated total cost:** $381.23

## Failed / Timed-Out Runs

| Task | Language | Model | Duration | Reason | Lines | actionlint | act-result.txt |
|------|------|-------|----------|--------|-------|------------|----------------|
| PR Label Assigner | powershell | haiku45-200k | 29.1min | timeout | 1141 | pass | yes |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 28.0min | timeout | 1649 | pass | yes |

*2 run(s) excluded from averages below.*

## Comparison by Language/Model/Effort
*(averages exclude failed/timed-out runs)*
*See [Notes](#notes) for scoring rubric and CLI version legend.*

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 7 | 8.3min | 6.4min | 5.4 | 53 | $1.63 | $11.41 | — | — |
| bash | opus47-1m-high | 7 | 10.5min | 10.4min | 1.6 | 45 | $2.56 | $17.89 | — | — |
| bash | opus47-1m-medium | 7 | 4.4min | 4.3min | 0.6 | 27 | $1.16 | $8.14 | — | — |
| bash | opus47-1m-xhigh | 5 | 10.3min | 9.3min | 1.4 | 50 | $3.09 | $15.43 | — | — |
| bash | sonnet46-200k | 7 | 11.3min | 10.1min | 4.0 | 43 | $1.62 | $11.33 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | opus46-200k | 7 | 6.4min | 6.1min | 2.9 | 34 | $1.37 | $9.59 | — | — |
| default | opus47-1m-high | 7 | 8.0min | 7.9min | 0.0 | 37 | $2.20 | $15.39 | — | — |
| default | opus47-1m-medium | 7 | 4.6min | 4.4min | 0.1 | 26 | $1.18 | $8.28 | — | — |
| default | opus47-1m-xhigh | 6 | 10.9min | 10.4min | 0.5 | 57 | $3.46 | $20.74 | — | — |
| default | sonnet46-200k | 7 | 9.9min | 9.6min | 3.6 | 42 | $1.47 | $10.26 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus46-200k | 7 | 8.8min | 8.6min | 1.0 | 33 | $1.79 | $12.50 | — | — |
| powershell | opus47-1m-high | 7 | 10.3min | 9.7min | 0.4 | 43 | $2.80 | $19.63 | — | — |
| powershell | opus47-1m-medium | 7 | 7.1min | 6.6min | 0.4 | 33 | $1.70 | $11.93 | — | — |
| powershell | opus47-1m-xhigh | 5 | 11.9min | 10.9min | 0.8 | 50 | $3.51 | $17.56 | — | — |
| powershell | sonnet46-200k | 7 | 11.2min | 11.0min | 2.3 | 33 | $1.63 | $11.41 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | opus46-200k | 7 | 8.1min | 8.1min | 1.3 | 28 | $1.56 | $10.91 | — | — |
| powershell-tool | opus47-1m-high | 7 | 11.8min | 11.1min | 0.7 | 54 | $3.55 | $24.84 | — | — |
| powershell-tool | opus47-1m-medium | 7 | 5.9min | 5.7min | 0.3 | 29 | $1.54 | $10.80 | — | — |
| powershell-tool | opus47-1m-xhigh* | 4 | 11.0min | 8.9min | 0.0 | 48 | $3.43 | $13.74 | — | — |
| powershell-tool | sonnet46-200k | 7 | 10.7min | 10.3min | 1.4 | 36 | $1.47 | $10.26 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus46-200k | 7 | 6.2min | 4.9min | 1.9 | 35 | $1.30 | $9.09 | — | — |
| typescript-bun | opus47-1m-high | 7 | 8.9min | 6.1min | 0.4 | 52 | $2.75 | $19.26 | — | — |
| typescript-bun | opus47-1m-medium | 7 | 5.5min | 4.2min | 0.3 | 32 | $1.33 | $9.30 | — | — |
| typescript-bun | opus47-1m-xhigh | 5 | 12.3min | 8.8min | 0.6 | 61 | $3.48 | $17.40 | — | — |
| typescript-bun | sonnet46-200k | 7 | 9.0min | 7.0min | 2.7 | 49 | $1.50 | $10.52 | — | — |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus47-1m-medium | 7 | 4.4min | 4.3min | 0.6 | 27 | $1.16 | $8.14 | — | — |
| default | opus47-1m-medium | 7 | 4.6min | 4.4min | 0.1 | 26 | $1.18 | $8.28 | — | — |
| typescript-bun | opus46-200k | 7 | 6.2min | 4.9min | 1.9 | 35 | $1.30 | $9.09 | — | — |
| typescript-bun | opus47-1m-medium | 7 | 5.5min | 4.2min | 0.3 | 32 | $1.33 | $9.30 | — | — |
| default | opus46-200k | 7 | 6.4min | 6.1min | 2.9 | 34 | $1.37 | $9.59 | — | — |
| default | sonnet46-200k | 7 | 9.9min | 9.6min | 3.6 | 42 | $1.47 | $10.26 | — | — |
| powershell-tool | sonnet46-200k | 7 | 10.7min | 10.3min | 1.4 | 36 | $1.47 | $10.26 | — | — |
| typescript-bun | sonnet46-200k | 7 | 9.0min | 7.0min | 2.7 | 49 | $1.50 | $10.52 | — | — |
| powershell-tool | opus47-1m-medium | 7 | 5.9min | 5.7min | 0.3 | 29 | $1.54 | $10.80 | — | — |
| powershell-tool | opus46-200k | 7 | 8.1min | 8.1min | 1.3 | 28 | $1.56 | $10.91 | — | — |
| bash | sonnet46-200k | 7 | 11.3min | 10.1min | 4.0 | 43 | $1.62 | $11.33 | — | — |
| powershell | sonnet46-200k | 7 | 11.2min | 11.0min | 2.3 | 33 | $1.63 | $11.41 | — | — |
| bash | opus46-200k | 7 | 8.3min | 6.4min | 5.4 | 53 | $1.63 | $11.41 | — | — |
| powershell | opus47-1m-medium | 7 | 7.1min | 6.6min | 0.4 | 33 | $1.70 | $11.93 | — | — |
| powershell | opus46-200k | 7 | 8.8min | 8.6min | 1.0 | 33 | $1.79 | $12.50 | — | — |
| default | opus47-1m-high | 7 | 8.0min | 7.9min | 0.0 | 37 | $2.20 | $15.39 | — | — |
| bash | opus47-1m-high | 7 | 10.5min | 10.4min | 1.6 | 45 | $2.56 | $17.89 | — | — |
| typescript-bun | opus47-1m-high | 7 | 8.9min | 6.1min | 0.4 | 52 | $2.75 | $19.26 | — | — |
| powershell | opus47-1m-high | 7 | 10.3min | 9.7min | 0.4 | 43 | $2.80 | $19.63 | — | — |
| bash | opus47-1m-xhigh | 5 | 10.3min | 9.3min | 1.4 | 50 | $3.09 | $15.43 | — | — |
| powershell-tool | opus47-1m-xhigh* | 4 | 11.0min | 8.9min | 0.0 | 48 | $3.43 | $13.74 | — | — |
| default | opus47-1m-xhigh | 6 | 10.9min | 10.4min | 0.5 | 57 | $3.46 | $20.74 | — | — |
| typescript-bun | opus47-1m-xhigh | 5 | 12.3min | 8.8min | 0.6 | 61 | $3.48 | $17.40 | — | — |
| powershell | opus47-1m-xhigh | 5 | 11.9min | 10.9min | 0.8 | 50 | $3.51 | $17.56 | — | — |
| powershell-tool | opus47-1m-high | 7 | 11.8min | 11.1min | 0.7 | 54 | $3.55 | $24.84 | — | — |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | opus47-1m-medium | 7 | 4.4min | 4.3min | 0.6 | 27 | $1.16 | $8.14 | — | — |
| default | opus47-1m-medium | 7 | 4.6min | 4.4min | 0.1 | 26 | $1.18 | $8.28 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| typescript-bun | opus47-1m-medium | 7 | 5.5min | 4.2min | 0.3 | 32 | $1.33 | $9.30 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| powershell-tool | opus47-1m-medium | 7 | 5.9min | 5.7min | 0.3 | 29 | $1.54 | $10.80 | — | — |
| typescript-bun | opus46-200k | 7 | 6.2min | 4.9min | 1.9 | 35 | $1.30 | $9.09 | — | — |
| default | opus46-200k | 7 | 6.4min | 6.1min | 2.9 | 34 | $1.37 | $9.59 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus47-1m-medium | 7 | 7.1min | 6.6min | 0.4 | 33 | $1.70 | $11.93 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| default | opus47-1m-high | 7 | 8.0min | 7.9min | 0.0 | 37 | $2.20 | $15.39 | — | — |
| powershell-tool | opus46-200k | 7 | 8.1min | 8.1min | 1.3 | 28 | $1.56 | $10.91 | — | — |
| bash | opus46-200k | 7 | 8.3min | 6.4min | 5.4 | 53 | $1.63 | $11.41 | — | — |
| powershell | opus46-200k | 7 | 8.8min | 8.6min | 1.0 | 33 | $1.79 | $12.50 | — | — |
| typescript-bun | opus47-1m-high | 7 | 8.9min | 6.1min | 0.4 | 52 | $2.75 | $19.26 | — | — |
| typescript-bun | sonnet46-200k | 7 | 9.0min | 7.0min | 2.7 | 49 | $1.50 | $10.52 | — | — |
| default | sonnet46-200k | 7 | 9.9min | 9.6min | 3.6 | 42 | $1.47 | $10.26 | — | — |
| powershell | opus47-1m-high | 7 | 10.3min | 9.7min | 0.4 | 43 | $2.80 | $19.63 | — | — |
| bash | opus47-1m-xhigh | 5 | 10.3min | 9.3min | 1.4 | 50 | $3.09 | $15.43 | — | — |
| bash | opus47-1m-high | 7 | 10.5min | 10.4min | 1.6 | 45 | $2.56 | $17.89 | — | — |
| powershell-tool | sonnet46-200k | 7 | 10.7min | 10.3min | 1.4 | 36 | $1.47 | $10.26 | — | — |
| default | opus47-1m-xhigh | 6 | 10.9min | 10.4min | 0.5 | 57 | $3.46 | $20.74 | — | — |
| powershell-tool | opus47-1m-xhigh* | 4 | 11.0min | 8.9min | 0.0 | 48 | $3.43 | $13.74 | — | — |
| powershell | sonnet46-200k | 7 | 11.2min | 11.0min | 2.3 | 33 | $1.63 | $11.41 | — | — |
| bash | sonnet46-200k | 7 | 11.3min | 10.1min | 4.0 | 43 | $1.62 | $11.33 | — | — |
| powershell-tool | opus47-1m-high | 7 | 11.8min | 11.1min | 0.7 | 54 | $3.55 | $24.84 | — | — |
| powershell | opus47-1m-xhigh | 5 | 11.9min | 10.9min | 0.8 | 50 | $3.51 | $17.56 | — | — |
| typescript-bun | opus47-1m-xhigh | 5 | 12.3min | 8.8min | 0.6 | 61 | $3.48 | $17.40 | — | — |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| typescript-bun | opus47-1m-medium | 7 | 5.5min | 4.2min | 0.3 | 32 | $1.33 | $9.30 | — | — |
| bash | opus47-1m-medium | 7 | 4.4min | 4.3min | 0.6 | 27 | $1.16 | $8.14 | — | — |
| default | opus47-1m-medium | 7 | 4.6min | 4.4min | 0.1 | 26 | $1.18 | $8.28 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| typescript-bun | opus46-200k | 7 | 6.2min | 4.9min | 1.9 | 35 | $1.30 | $9.09 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| powershell-tool | opus47-1m-medium | 7 | 5.9min | 5.7min | 0.3 | 29 | $1.54 | $10.80 | — | — |
| typescript-bun | opus47-1m-high | 7 | 8.9min | 6.1min | 0.4 | 52 | $2.75 | $19.26 | — | — |
| default | opus46-200k | 7 | 6.4min | 6.1min | 2.9 | 34 | $1.37 | $9.59 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| bash | opus46-200k | 7 | 8.3min | 6.4min | 5.4 | 53 | $1.63 | $11.41 | — | — |
| powershell | opus47-1m-medium | 7 | 7.1min | 6.6min | 0.4 | 33 | $1.70 | $11.93 | — | — |
| typescript-bun | sonnet46-200k | 7 | 9.0min | 7.0min | 2.7 | 49 | $1.50 | $10.52 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| default | opus47-1m-high | 7 | 8.0min | 7.9min | 0.0 | 37 | $2.20 | $15.39 | — | — |
| powershell-tool | opus46-200k | 7 | 8.1min | 8.1min | 1.3 | 28 | $1.56 | $10.91 | — | — |
| powershell | opus46-200k | 7 | 8.8min | 8.6min | 1.0 | 33 | $1.79 | $12.50 | — | — |
| typescript-bun | opus47-1m-xhigh | 5 | 12.3min | 8.8min | 0.6 | 61 | $3.48 | $17.40 | — | — |
| powershell-tool | opus47-1m-xhigh* | 4 | 11.0min | 8.9min | 0.0 | 48 | $3.43 | $13.74 | — | — |
| bash | opus47-1m-xhigh | 5 | 10.3min | 9.3min | 1.4 | 50 | $3.09 | $15.43 | — | — |
| default | sonnet46-200k | 7 | 9.9min | 9.6min | 3.6 | 42 | $1.47 | $10.26 | — | — |
| powershell | opus47-1m-high | 7 | 10.3min | 9.7min | 0.4 | 43 | $2.80 | $19.63 | — | — |
| bash | sonnet46-200k | 7 | 11.3min | 10.1min | 4.0 | 43 | $1.62 | $11.33 | — | — |
| powershell-tool | sonnet46-200k | 7 | 10.7min | 10.3min | 1.4 | 36 | $1.47 | $10.26 | — | — |
| bash | opus47-1m-high | 7 | 10.5min | 10.4min | 1.6 | 45 | $2.56 | $17.89 | — | — |
| default | opus47-1m-xhigh | 6 | 10.9min | 10.4min | 0.5 | 57 | $3.46 | $20.74 | — | — |
| powershell | opus47-1m-xhigh | 5 | 11.9min | 10.9min | 0.8 | 50 | $3.51 | $17.56 | — | — |
| powershell | sonnet46-200k | 7 | 11.2min | 11.0min | 2.3 | 33 | $1.63 | $11.41 | — | — |
| powershell-tool | opus47-1m-high | 7 | 11.8min | 11.1min | 0.7 | 54 | $3.55 | $24.84 | — | — |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | opus47-1m-high | 7 | 8.0min | 7.9min | 0.0 | 37 | $2.20 | $15.39 | — | — |
| powershell-tool | opus47-1m-xhigh* | 4 | 11.0min | 8.9min | 0.0 | 48 | $3.43 | $13.74 | — | — |
| default | opus47-1m-medium | 7 | 4.6min | 4.4min | 0.1 | 26 | $1.18 | $8.28 | — | — |
| powershell-tool | opus47-1m-medium | 7 | 5.9min | 5.7min | 0.3 | 29 | $1.54 | $10.80 | — | — |
| typescript-bun | opus47-1m-medium | 7 | 5.5min | 4.2min | 0.3 | 32 | $1.33 | $9.30 | — | — |
| powershell | opus47-1m-high | 7 | 10.3min | 9.7min | 0.4 | 43 | $2.80 | $19.63 | — | — |
| powershell | opus47-1m-medium | 7 | 7.1min | 6.6min | 0.4 | 33 | $1.70 | $11.93 | — | — |
| typescript-bun | opus47-1m-high | 7 | 8.9min | 6.1min | 0.4 | 52 | $2.75 | $19.26 | — | — |
| default | opus47-1m-xhigh | 6 | 10.9min | 10.4min | 0.5 | 57 | $3.46 | $20.74 | — | — |
| bash | opus47-1m-medium | 7 | 4.4min | 4.3min | 0.6 | 27 | $1.16 | $8.14 | — | — |
| typescript-bun | opus47-1m-xhigh | 5 | 12.3min | 8.8min | 0.6 | 61 | $3.48 | $17.40 | — | — |
| powershell-tool | opus47-1m-high | 7 | 11.8min | 11.1min | 0.7 | 54 | $3.55 | $24.84 | — | — |
| powershell | opus47-1m-xhigh | 5 | 11.9min | 10.9min | 0.8 | 50 | $3.51 | $17.56 | — | — |
| powershell | opus46-200k | 7 | 8.8min | 8.6min | 1.0 | 33 | $1.79 | $12.50 | — | — |
| powershell-tool | opus46-200k | 7 | 8.1min | 8.1min | 1.3 | 28 | $1.56 | $10.91 | — | — |
| bash | opus47-1m-xhigh | 5 | 10.3min | 9.3min | 1.4 | 50 | $3.09 | $15.43 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | sonnet46-200k | 7 | 10.7min | 10.3min | 1.4 | 36 | $1.47 | $10.26 | — | — |
| bash | opus47-1m-high | 7 | 10.5min | 10.4min | 1.6 | 45 | $2.56 | $17.89 | — | — |
| typescript-bun | opus46-200k | 7 | 6.2min | 4.9min | 1.9 | 35 | $1.30 | $9.09 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | sonnet46-200k | 7 | 11.2min | 11.0min | 2.3 | 33 | $1.63 | $11.41 | — | — |
| typescript-bun | sonnet46-200k | 7 | 9.0min | 7.0min | 2.7 | 49 | $1.50 | $10.52 | — | — |
| default | opus46-200k | 7 | 6.4min | 6.1min | 2.9 | 34 | $1.37 | $9.59 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | sonnet46-200k | 7 | 9.9min | 9.6min | 3.6 | 42 | $1.47 | $10.26 | — | — |
| bash | sonnet46-200k | 7 | 11.3min | 10.1min | 4.0 | 43 | $1.62 | $11.33 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 7 | 8.3min | 6.4min | 5.4 | 53 | $1.63 | $11.41 | — | — |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | opus47-1m-medium | 7 | 4.6min | 4.4min | 0.1 | 26 | $1.18 | $8.28 | — | — |
| bash | opus47-1m-medium | 7 | 4.4min | 4.3min | 0.6 | 27 | $1.16 | $8.14 | — | — |
| powershell-tool | opus46-200k | 7 | 8.1min | 8.1min | 1.3 | 28 | $1.56 | $10.91 | — | — |
| powershell-tool | opus47-1m-medium | 7 | 5.9min | 5.7min | 0.3 | 29 | $1.54 | $10.80 | — | — |
| typescript-bun | opus47-1m-medium | 7 | 5.5min | 4.2min | 0.3 | 32 | $1.33 | $9.30 | — | — |
| powershell | opus46-200k | 7 | 8.8min | 8.6min | 1.0 | 33 | $1.79 | $12.50 | — | — |
| powershell | opus47-1m-medium | 7 | 7.1min | 6.6min | 0.4 | 33 | $1.70 | $11.93 | — | — |
| powershell | sonnet46-200k | 7 | 11.2min | 11.0min | 2.3 | 33 | $1.63 | $11.41 | — | — |
| default | opus46-200k | 7 | 6.4min | 6.1min | 2.9 | 34 | $1.37 | $9.59 | — | — |
| typescript-bun | opus46-200k | 7 | 6.2min | 4.9min | 1.9 | 35 | $1.30 | $9.09 | — | — |
| powershell-tool | sonnet46-200k | 7 | 10.7min | 10.3min | 1.4 | 36 | $1.47 | $10.26 | — | — |
| default | opus47-1m-high | 7 | 8.0min | 7.9min | 0.0 | 37 | $2.20 | $15.39 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | sonnet46-200k | 7 | 9.9min | 9.6min | 3.6 | 42 | $1.47 | $10.26 | — | — |
| bash | sonnet46-200k | 7 | 11.3min | 10.1min | 4.0 | 43 | $1.62 | $11.33 | — | — |
| powershell | opus47-1m-high | 7 | 10.3min | 9.7min | 0.4 | 43 | $2.80 | $19.63 | — | — |
| bash | opus47-1m-high | 7 | 10.5min | 10.4min | 1.6 | 45 | $2.56 | $17.89 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | opus47-1m-xhigh* | 4 | 11.0min | 8.9min | 0.0 | 48 | $3.43 | $13.74 | — | — |
| typescript-bun | sonnet46-200k | 7 | 9.0min | 7.0min | 2.7 | 49 | $1.50 | $10.52 | — | — |
| bash | opus47-1m-xhigh | 5 | 10.3min | 9.3min | 1.4 | 50 | $3.09 | $15.43 | — | — |
| powershell | opus47-1m-xhigh | 5 | 11.9min | 10.9min | 0.8 | 50 | $3.51 | $17.56 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus47-1m-high | 7 | 8.9min | 6.1min | 0.4 | 52 | $2.75 | $19.26 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| bash | opus46-200k | 7 | 8.3min | 6.4min | 5.4 | 53 | $1.63 | $11.41 | — | — |
| powershell-tool | opus47-1m-high | 7 | 11.8min | 11.1min | 0.7 | 54 | $3.55 | $24.84 | — | — |
| default | opus47-1m-xhigh | 6 | 10.9min | 10.4min | 0.5 | 57 | $3.46 | $20.74 | — | — |
| typescript-bun | opus47-1m-xhigh | 5 | 12.3min | 8.8min | 0.6 | 61 | $3.48 | $17.40 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 7 | 8.3min | 6.4min | 5.4 | 53 | $1.63 | $11.41 | — | — |
| bash | opus47-1m-high | 7 | 10.5min | 10.4min | 1.6 | 45 | $2.56 | $17.89 | — | — |
| bash | opus47-1m-medium | 7 | 4.4min | 4.3min | 0.6 | 27 | $1.16 | $8.14 | — | — |
| bash | opus47-1m-xhigh | 5 | 10.3min | 9.3min | 1.4 | 50 | $3.09 | $15.43 | — | — |
| bash | sonnet46-200k | 7 | 11.3min | 10.1min | 4.0 | 43 | $1.62 | $11.33 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | opus46-200k | 7 | 6.4min | 6.1min | 2.9 | 34 | $1.37 | $9.59 | — | — |
| default | opus47-1m-high | 7 | 8.0min | 7.9min | 0.0 | 37 | $2.20 | $15.39 | — | — |
| default | opus47-1m-medium | 7 | 4.6min | 4.4min | 0.1 | 26 | $1.18 | $8.28 | — | — |
| default | opus47-1m-xhigh | 6 | 10.9min | 10.4min | 0.5 | 57 | $3.46 | $20.74 | — | — |
| default | sonnet46-200k | 7 | 9.9min | 9.6min | 3.6 | 42 | $1.47 | $10.26 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus46-200k | 7 | 8.8min | 8.6min | 1.0 | 33 | $1.79 | $12.50 | — | — |
| powershell | opus47-1m-high | 7 | 10.3min | 9.7min | 0.4 | 43 | $2.80 | $19.63 | — | — |
| powershell | opus47-1m-medium | 7 | 7.1min | 6.6min | 0.4 | 33 | $1.70 | $11.93 | — | — |
| powershell | opus47-1m-xhigh | 5 | 11.9min | 10.9min | 0.8 | 50 | $3.51 | $17.56 | — | — |
| powershell | sonnet46-200k | 7 | 11.2min | 11.0min | 2.3 | 33 | $1.63 | $11.41 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | opus46-200k | 7 | 8.1min | 8.1min | 1.3 | 28 | $1.56 | $10.91 | — | — |
| powershell-tool | opus47-1m-high | 7 | 11.8min | 11.1min | 0.7 | 54 | $3.55 | $24.84 | — | — |
| powershell-tool | opus47-1m-medium | 7 | 5.9min | 5.7min | 0.3 | 29 | $1.54 | $10.80 | — | — |
| powershell-tool | opus47-1m-xhigh* | 4 | 11.0min | 8.9min | 0.0 | 48 | $3.43 | $13.74 | — | — |
| powershell-tool | sonnet46-200k | 7 | 10.7min | 10.3min | 1.4 | 36 | $1.47 | $10.26 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus46-200k | 7 | 6.2min | 4.9min | 1.9 | 35 | $1.30 | $9.09 | — | — |
| typescript-bun | opus47-1m-high | 7 | 8.9min | 6.1min | 0.4 | 52 | $2.75 | $19.26 | — | — |
| typescript-bun | opus47-1m-medium | 7 | 5.5min | 4.2min | 0.3 | 32 | $1.33 | $9.30 | — | — |
| typescript-bun | opus47-1m-xhigh | 5 | 12.3min | 8.8min | 0.6 | 61 | $3.48 | $17.40 | — | — |
| typescript-bun | sonnet46-200k | 7 | 9.0min | 7.0min | 2.7 | 49 | $1.50 | $10.52 | — | — |

</details>

<details>
<summary>Sorted by deliverable-quality score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 7 | 8.3min | 6.4min | 5.4 | 53 | $1.63 | $11.41 | — | — |
| bash | opus47-1m-high | 7 | 10.5min | 10.4min | 1.6 | 45 | $2.56 | $17.89 | — | — |
| bash | opus47-1m-medium | 7 | 4.4min | 4.3min | 0.6 | 27 | $1.16 | $8.14 | — | — |
| bash | opus47-1m-xhigh | 5 | 10.3min | 9.3min | 1.4 | 50 | $3.09 | $15.43 | — | — |
| bash | sonnet46-200k | 7 | 11.3min | 10.1min | 4.0 | 43 | $1.62 | $11.33 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | opus46-200k | 7 | 6.4min | 6.1min | 2.9 | 34 | $1.37 | $9.59 | — | — |
| default | opus47-1m-high | 7 | 8.0min | 7.9min | 0.0 | 37 | $2.20 | $15.39 | — | — |
| default | opus47-1m-medium | 7 | 4.6min | 4.4min | 0.1 | 26 | $1.18 | $8.28 | — | — |
| default | opus47-1m-xhigh | 6 | 10.9min | 10.4min | 0.5 | 57 | $3.46 | $20.74 | — | — |
| default | sonnet46-200k | 7 | 9.9min | 9.6min | 3.6 | 42 | $1.47 | $10.26 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus46-200k | 7 | 8.8min | 8.6min | 1.0 | 33 | $1.79 | $12.50 | — | — |
| powershell | opus47-1m-high | 7 | 10.3min | 9.7min | 0.4 | 43 | $2.80 | $19.63 | — | — |
| powershell | opus47-1m-medium | 7 | 7.1min | 6.6min | 0.4 | 33 | $1.70 | $11.93 | — | — |
| powershell | opus47-1m-xhigh | 5 | 11.9min | 10.9min | 0.8 | 50 | $3.51 | $17.56 | — | — |
| powershell | sonnet46-200k | 7 | 11.2min | 11.0min | 2.3 | 33 | $1.63 | $11.41 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | opus46-200k | 7 | 8.1min | 8.1min | 1.3 | 28 | $1.56 | $10.91 | — | — |
| powershell-tool | opus47-1m-high | 7 | 11.8min | 11.1min | 0.7 | 54 | $3.55 | $24.84 | — | — |
| powershell-tool | opus47-1m-medium | 7 | 5.9min | 5.7min | 0.3 | 29 | $1.54 | $10.80 | — | — |
| powershell-tool | opus47-1m-xhigh* | 4 | 11.0min | 8.9min | 0.0 | 48 | $3.43 | $13.74 | — | — |
| powershell-tool | sonnet46-200k | 7 | 10.7min | 10.3min | 1.4 | 36 | $1.47 | $10.26 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus46-200k | 7 | 6.2min | 4.9min | 1.9 | 35 | $1.30 | $9.09 | — | — |
| typescript-bun | opus47-1m-high | 7 | 8.9min | 6.1min | 0.4 | 52 | $2.75 | $19.26 | — | — |
| typescript-bun | opus47-1m-medium | 7 | 5.5min | 4.2min | 0.3 | 32 | $1.33 | $9.30 | — | — |
| typescript-bun | opus47-1m-xhigh | 5 | 12.3min | 8.8min | 0.6 | 61 | $3.48 | $17.40 | — | — |
| typescript-bun | sonnet46-200k | 7 | 9.0min | 7.0min | 2.7 | 49 | $1.50 | $10.52 | — | — |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

*`% of Test Time Saved` = `net / (net + test_time) × 100` — the share of total (would-have-been + actually-spent) test time that hooks eliminated. Bounded in (-∞, 100%) without an artificial cap; near 100% means hooks substituted for almost all of the hypothetical test work.*

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | 0.4min | 28.2% |
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 0.4% | 0.2min | 0.0% | 7.4min | 0.4% | 3.5min | 67.9% |
| bash | opus46-200k-cli2.1.132 | 129 | 13 | 10.1% | 2.6min | 0.2% | 0.3min | 0.0% | 2.3min | 0.1% | 2.7min | 45.8% |
| bash | opus47-1m-high-cli2.1.132 | 116 | 7 | 6.0% | 1.4min | 0.1% | 0.2min | 0.0% | 1.2min | 0.1% | 10.9min | 9.5% |
| bash | opus47-1m-medium-cli2.1.132 | 80 | 2 | 2.5% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 5.3min | 5.2% |
| bash | opus47-1m-xhigh-cli2.1.132 | 98 | 2 | 2.0% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 5.6min | 4.9% |
| bash | sonnet46-200k-cli2.1.132 | 106 | 4 | 3.8% | 0.8min | 0.0% | 0.2min | 0.0% | 0.6min | 0.0% | 9.5min | 6.4% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 0.0min | 91.1% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.1% | 0.2min | 0.0% | 1.4min | 0.1% | 3.0min | 32.2% |
| default | opus46-200k-cli2.1.132 | 91 | 1 | 1.1% | 0.1min | 0.0% | 0.3min | 0.0% | -0.1min | -0.0% | 1.2min | -11.3% |
| default | opus47-1m-high-cli2.1.132 | 101 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 8.7min | -2.3% |
| default | opus47-1m-medium-cli2.1.132 | 77 | 1 | 1.3% | 0.1min | 0.0% | 0.1min | 0.0% | 0.0min | 0.0% | 6.9min | 0.4% |
| default | opus47-1m-xhigh-cli2.1.132 | 138 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.0% | -0.3min | -0.0% | 6.2min | -5.7% |
| default | sonnet46-200k-cli2.1.132 | 98 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 2.9min | -8.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.0% | 0.2min | 0.0% | 0.4min | 0.0% | 0.8min | 31.9% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.1% | 0.8min | 0.0% | 1.5min | 0.1% | 6.0min | 20.1% |
| powershell | opus46-200k-cli2.1.132 | 96 | 9 | 9.4% | 5.2min | 0.3% | 0.5min | 0.0% | 4.8min | 0.3% | 3.2min | 59.6% |
| powershell | opus47-1m-high-cli2.1.132 | 111 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.0% | -0.8min | -0.0% | 8.8min | -9.6% |
| powershell | opus47-1m-medium-cli2.1.132 | 107 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 10.0min | -6.6% |
| powershell | opus47-1m-xhigh-cli2.1.132 | 103 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 7.9min | -7.8% |
| powershell | sonnet46-200k-cli2.1.132 | 79 | 1 | 1.3% | 0.6min | 0.0% | 0.4min | 0.0% | 0.2min | 0.0% | 2.5min | 7.2% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.0% | -0.3min | -0.0% | 5.6min | -5.8% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.1% | 0.7min | 0.0% | 1.1min | 0.1% | 3.2min | 25.3% |
| powershell-tool | opus46-200k-cli2.1.132 | 71 | 2 | 2.8% | 1.2min | 0.1% | 0.4min | 0.0% | 0.7min | 0.0% | 1.8min | 29.7% |
| powershell-tool | opus47-1m-high-cli2.1.132 | 133 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.0% | -0.8min | -0.0% | 9.2min | -10.1% |
| powershell-tool | opus47-1m-medium-cli2.1.132 | 97 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 5.6min | -12.7% |
| powershell-tool | opus47-1m-xhigh-cli2.1.132 | 87 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.0% | -0.5min | -0.0% | 5.8min | -10.3% |
| powershell-tool | sonnet46-200k-cli2.1.132 | 82 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.0% | -0.4min | -0.0% | 4.5min | -9.8% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.1% | 1.5min | 0.1% | -0.2min | -0.0% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 0.3% | 5.2min | 0.3% | 0.7min | 0.0% | 1.7min | 29.1% |
| typescript-bun | opus46-200k-cli2.1.132 | 103 | 44 | 42.7% | 5.9min | 0.3% | 2.7min | 0.2% | 3.2min | 0.2% | 3.6min | 47.0% |
| typescript-bun | opus47-1m-high-cli2.1.132 | 140 | 79 | 56.4% | 10.5min | 0.6% | 1.8min | 0.1% | 8.7min | 0.5% | 7.3min | 54.4% |
| typescript-bun | opus47-1m-medium-cli2.1.132 | 92 | 36 | 39.1% | 4.8min | 0.3% | 3.1min | 0.2% | 1.7min | 0.1% | 5.7min | 23.2% |
| typescript-bun | opus47-1m-xhigh-cli2.1.132 | 112 | 52 | 46.4% | 6.9min | 0.4% | 2.0min | 0.1% | 5.0min | 0.3% | 7.3min | 40.5% |
| typescript-bun | sonnet46-200k-cli2.1.132 | 103 | 53 | 51.5% | 7.1min | 0.4% | 1.6min | 0.1% | 5.4min | 0.3% | 3.8min | 58.7% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m-high-cli2.1.132 | 140 | 79 | 56.4% | 10.5min | 0.6% | 1.8min | 0.1% | 8.7min | 0.5% | 7.3min | 54.4% |
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 0.4% | 0.2min | 0.0% | 7.4min | 0.4% | 3.5min | 67.9% |
| typescript-bun | sonnet46-200k-cli2.1.132 | 103 | 53 | 51.5% | 7.1min | 0.4% | 1.6min | 0.1% | 5.4min | 0.3% | 3.8min | 58.7% |
| typescript-bun | opus47-1m-xhigh-cli2.1.132 | 112 | 52 | 46.4% | 6.9min | 0.4% | 2.0min | 0.1% | 5.0min | 0.3% | 7.3min | 40.5% |
| powershell | opus46-200k-cli2.1.132 | 96 | 9 | 9.4% | 5.2min | 0.3% | 0.5min | 0.0% | 4.8min | 0.3% | 3.2min | 59.6% |
| typescript-bun | opus46-200k-cli2.1.132 | 103 | 44 | 42.7% | 5.9min | 0.3% | 2.7min | 0.2% | 3.2min | 0.2% | 3.6min | 47.0% |
| bash | opus46-200k-cli2.1.132 | 129 | 13 | 10.1% | 2.6min | 0.2% | 0.3min | 0.0% | 2.3min | 0.1% | 2.7min | 45.8% |
| typescript-bun | opus47-1m-medium-cli2.1.132 | 92 | 36 | 39.1% | 4.8min | 0.3% | 3.1min | 0.2% | 1.7min | 0.1% | 5.7min | 23.2% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.1% | 0.8min | 0.0% | 1.5min | 0.1% | 6.0min | 20.1% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.1% | 0.2min | 0.0% | 1.4min | 0.1% | 3.0min | 32.2% |
| bash | opus47-1m-high-cli2.1.132 | 116 | 7 | 6.0% | 1.4min | 0.1% | 0.2min | 0.0% | 1.2min | 0.1% | 10.9min | 9.5% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.1% | 0.7min | 0.0% | 1.1min | 0.1% | 3.2min | 25.3% |
| powershell-tool | opus46-200k-cli2.1.132 | 71 | 2 | 2.8% | 1.2min | 0.1% | 0.4min | 0.0% | 0.7min | 0.0% | 1.8min | 29.7% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 0.3% | 5.2min | 0.3% | 0.7min | 0.0% | 1.7min | 29.1% |
| bash | sonnet46-200k-cli2.1.132 | 106 | 4 | 3.8% | 0.8min | 0.0% | 0.2min | 0.0% | 0.6min | 0.0% | 9.5min | 6.4% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.0% | 0.2min | 0.0% | 0.4min | 0.0% | 0.8min | 31.9% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 0.0min | 91.1% |
| bash | opus47-1m-xhigh-cli2.1.132 | 98 | 2 | 2.0% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 5.6min | 4.9% |
| bash | opus47-1m-medium-cli2.1.132 | 80 | 2 | 2.5% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 5.3min | 5.2% |
| powershell | sonnet46-200k-cli2.1.132 | 79 | 1 | 1.3% | 0.6min | 0.0% | 0.4min | 0.0% | 0.2min | 0.0% | 2.5min | 7.2% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | 0.4min | 28.2% |
| default | opus47-1m-medium-cli2.1.132 | 77 | 1 | 1.3% | 0.1min | 0.0% | 0.1min | 0.0% | 0.0min | 0.0% | 6.9min | 0.4% |
| default | opus46-200k-cli2.1.132 | 91 | 1 | 1.1% | 0.1min | 0.0% | 0.3min | 0.0% | -0.1min | -0.0% | 1.2min | -11.3% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.1% | 1.5min | 0.1% | -0.2min | -0.0% | 0.5min | -57.5% |
| default | opus47-1m-high-cli2.1.132 | 101 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 8.7min | -2.3% |
| default | sonnet46-200k-cli2.1.132 | 98 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 2.9min | -8.2% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.0% | -0.3min | -0.0% | 5.6min | -5.8% |
| default | opus47-1m-xhigh-cli2.1.132 | 138 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.0% | -0.3min | -0.0% | 6.2min | -5.7% |
| powershell-tool | sonnet46-200k-cli2.1.132 | 82 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.0% | -0.4min | -0.0% | 4.5min | -9.8% |
| powershell-tool | opus47-1m-xhigh-cli2.1.132 | 87 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.0% | -0.5min | -0.0% | 5.8min | -10.3% |
| powershell | opus47-1m-xhigh-cli2.1.132 | 103 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 7.9min | -7.8% |
| powershell | opus47-1m-medium-cli2.1.132 | 107 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 10.0min | -6.6% |
| powershell-tool | opus47-1m-medium-cli2.1.132 | 97 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 5.6min | -12.7% |
| powershell | opus47-1m-high-cli2.1.132 | 111 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.0% | -0.8min | -0.0% | 8.8min | -9.6% |
| powershell-tool | opus47-1m-high-cli2.1.132 | 133 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.0% | -0.8min | -0.0% | 9.2min | -10.1% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 0.4% | 0.2min | 0.0% | 7.4min | 0.4% | 3.5min | 67.9% |
| powershell | opus46-200k-cli2.1.132 | 96 | 9 | 9.4% | 5.2min | 0.3% | 0.5min | 0.0% | 4.8min | 0.3% | 3.2min | 59.6% |
| typescript-bun | sonnet46-200k-cli2.1.132 | 103 | 53 | 51.5% | 7.1min | 0.4% | 1.6min | 0.1% | 5.4min | 0.3% | 3.8min | 58.7% |
| typescript-bun | opus47-1m-high-cli2.1.132 | 140 | 79 | 56.4% | 10.5min | 0.6% | 1.8min | 0.1% | 8.7min | 0.5% | 7.3min | 54.4% |
| typescript-bun | opus46-200k-cli2.1.132 | 103 | 44 | 42.7% | 5.9min | 0.3% | 2.7min | 0.2% | 3.2min | 0.2% | 3.6min | 47.0% |
| bash | opus46-200k-cli2.1.132 | 129 | 13 | 10.1% | 2.6min | 0.2% | 0.3min | 0.0% | 2.3min | 0.1% | 2.7min | 45.8% |
| typescript-bun | opus47-1m-xhigh-cli2.1.132 | 112 | 52 | 46.4% | 6.9min | 0.4% | 2.0min | 0.1% | 5.0min | 0.3% | 7.3min | 40.5% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.1% | 0.2min | 0.0% | 1.4min | 0.1% | 3.0min | 32.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.0% | 0.2min | 0.0% | 0.4min | 0.0% | 0.8min | 31.9% |
| powershell-tool | opus46-200k-cli2.1.132 | 71 | 2 | 2.8% | 1.2min | 0.1% | 0.4min | 0.0% | 0.7min | 0.0% | 1.8min | 29.7% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 0.3% | 5.2min | 0.3% | 0.7min | 0.0% | 1.7min | 29.1% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | 0.4min | 28.2% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.1% | 0.7min | 0.0% | 1.1min | 0.1% | 3.2min | 25.3% |
| typescript-bun | opus47-1m-medium-cli2.1.132 | 92 | 36 | 39.1% | 4.8min | 0.3% | 3.1min | 0.2% | 1.7min | 0.1% | 5.7min | 23.2% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.1% | 0.8min | 0.0% | 1.5min | 0.1% | 6.0min | 20.1% |
| bash | opus47-1m-high-cli2.1.132 | 116 | 7 | 6.0% | 1.4min | 0.1% | 0.2min | 0.0% | 1.2min | 0.1% | 10.9min | 9.5% |
| powershell | sonnet46-200k-cli2.1.132 | 79 | 1 | 1.3% | 0.6min | 0.0% | 0.4min | 0.0% | 0.2min | 0.0% | 2.5min | 7.2% |
| bash | sonnet46-200k-cli2.1.132 | 106 | 4 | 3.8% | 0.8min | 0.0% | 0.2min | 0.0% | 0.6min | 0.0% | 9.5min | 6.4% |
| bash | opus47-1m-medium-cli2.1.132 | 80 | 2 | 2.5% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 5.3min | 5.2% |
| bash | opus47-1m-xhigh-cli2.1.132 | 98 | 2 | 2.0% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 5.6min | 4.9% |
| default | opus47-1m-medium-cli2.1.132 | 77 | 1 | 1.3% | 0.1min | 0.0% | 0.1min | 0.0% | 0.0min | 0.0% | 6.9min | 0.4% |
| default | opus47-1m-high-cli2.1.132 | 101 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 8.7min | -2.3% |
| default | opus47-1m-xhigh-cli2.1.132 | 138 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.0% | -0.3min | -0.0% | 6.2min | -5.7% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.0% | -0.3min | -0.0% | 5.6min | -5.8% |
| powershell | opus47-1m-medium-cli2.1.132 | 107 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 10.0min | -6.6% |
| powershell | opus47-1m-xhigh-cli2.1.132 | 103 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 7.9min | -7.8% |
| default | sonnet46-200k-cli2.1.132 | 98 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 2.9min | -8.2% |
| powershell | opus47-1m-high-cli2.1.132 | 111 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.0% | -0.8min | -0.0% | 8.8min | -9.6% |
| powershell-tool | sonnet46-200k-cli2.1.132 | 82 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.0% | -0.4min | -0.0% | 4.5min | -9.8% |
| powershell-tool | opus47-1m-high-cli2.1.132 | 133 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.0% | -0.8min | -0.0% | 9.2min | -10.1% |
| powershell-tool | opus47-1m-xhigh-cli2.1.132 | 87 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.0% | -0.5min | -0.0% | 5.8min | -10.3% |
| default | opus46-200k-cli2.1.132 | 91 | 1 | 1.1% | 0.1min | 0.0% | 0.3min | 0.0% | -0.1min | -0.0% | 1.2min | -11.3% |
| powershell-tool | opus47-1m-medium-cli2.1.132 | 97 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 5.6min | -12.7% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.1% | 1.5min | 0.1% | -0.2min | -0.0% | 0.5min | -57.5% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m-high-cli2.1.132 | 140 | 79 | 56.4% | 10.5min | 0.6% | 1.8min | 0.1% | 8.7min | 0.5% | 7.3min | 54.4% |
| typescript-bun | sonnet46-200k-cli2.1.132 | 103 | 53 | 51.5% | 7.1min | 0.4% | 1.6min | 0.1% | 5.4min | 0.3% | 3.8min | 58.7% |
| typescript-bun | opus47-1m-xhigh-cli2.1.132 | 112 | 52 | 46.4% | 6.9min | 0.4% | 2.0min | 0.1% | 5.0min | 0.3% | 7.3min | 40.5% |
| typescript-bun | opus46-200k-cli2.1.132 | 103 | 44 | 42.7% | 5.9min | 0.3% | 2.7min | 0.2% | 3.2min | 0.2% | 3.6min | 47.0% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 0.3% | 5.2min | 0.3% | 0.7min | 0.0% | 1.7min | 29.1% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.1% | 1.5min | 0.1% | -0.2min | -0.0% | 0.5min | -57.5% |
| typescript-bun | opus47-1m-medium-cli2.1.132 | 92 | 36 | 39.1% | 4.8min | 0.3% | 3.1min | 0.2% | 1.7min | 0.1% | 5.7min | 23.2% |
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 0.4% | 0.2min | 0.0% | 7.4min | 0.4% | 3.5min | 67.9% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.1% | 0.2min | 0.0% | 1.4min | 0.1% | 3.0min | 32.2% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 0.0min | 91.1% |
| bash | opus46-200k-cli2.1.132 | 129 | 13 | 10.1% | 2.6min | 0.2% | 0.3min | 0.0% | 2.3min | 0.1% | 2.7min | 45.8% |
| powershell | opus46-200k-cli2.1.132 | 96 | 9 | 9.4% | 5.2min | 0.3% | 0.5min | 0.0% | 4.8min | 0.3% | 3.2min | 59.6% |
| bash | opus47-1m-high-cli2.1.132 | 116 | 7 | 6.0% | 1.4min | 0.1% | 0.2min | 0.0% | 1.2min | 0.1% | 10.9min | 9.5% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | 0.4min | 28.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.0% | 0.2min | 0.0% | 0.4min | 0.0% | 0.8min | 31.9% |
| bash | sonnet46-200k-cli2.1.132 | 106 | 4 | 3.8% | 0.8min | 0.0% | 0.2min | 0.0% | 0.6min | 0.0% | 9.5min | 6.4% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.1% | 0.8min | 0.0% | 1.5min | 0.1% | 6.0min | 20.1% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.1% | 0.7min | 0.0% | 1.1min | 0.1% | 3.2min | 25.3% |
| powershell-tool | opus46-200k-cli2.1.132 | 71 | 2 | 2.8% | 1.2min | 0.1% | 0.4min | 0.0% | 0.7min | 0.0% | 1.8min | 29.7% |
| bash | opus47-1m-medium-cli2.1.132 | 80 | 2 | 2.5% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 5.3min | 5.2% |
| bash | opus47-1m-xhigh-cli2.1.132 | 98 | 2 | 2.0% | 0.4min | 0.0% | 0.1min | 0.0% | 0.3min | 0.0% | 5.6min | 4.9% |
| default | opus47-1m-medium-cli2.1.132 | 77 | 1 | 1.3% | 0.1min | 0.0% | 0.1min | 0.0% | 0.0min | 0.0% | 6.9min | 0.4% |
| powershell | sonnet46-200k-cli2.1.132 | 79 | 1 | 1.3% | 0.6min | 0.0% | 0.4min | 0.0% | 0.2min | 0.0% | 2.5min | 7.2% |
| default | opus46-200k-cli2.1.132 | 91 | 1 | 1.1% | 0.1min | 0.0% | 0.3min | 0.0% | -0.1min | -0.0% | 1.2min | -11.3% |
| default | opus47-1m-high-cli2.1.132 | 101 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 8.7min | -2.3% |
| default | opus47-1m-xhigh-cli2.1.132 | 138 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.0% | -0.3min | -0.0% | 6.2min | -5.7% |
| default | sonnet46-200k-cli2.1.132 | 98 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 2.9min | -8.2% |
| powershell | opus47-1m-high-cli2.1.132 | 111 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.0% | -0.8min | -0.0% | 8.8min | -9.6% |
| powershell | opus47-1m-medium-cli2.1.132 | 107 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 10.0min | -6.6% |
| powershell | opus47-1m-xhigh-cli2.1.132 | 103 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 7.9min | -7.8% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.0% | -0.3min | -0.0% | 5.6min | -5.8% |
| powershell-tool | opus47-1m-high-cli2.1.132 | 133 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.0% | -0.8min | -0.0% | 9.2min | -10.1% |
| powershell-tool | opus47-1m-medium-cli2.1.132 | 97 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.0% | -0.6min | -0.0% | 5.6min | -12.7% |
| powershell-tool | opus47-1m-xhigh-cli2.1.132 | 87 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.0% | -0.5min | -0.0% | 5.8min | -10.3% |
| powershell-tool | sonnet46-200k-cli2.1.132 | 82 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.0% | -0.4min | -0.0% | 4.5min | -9.8% |

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.03 | 0.01% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 0.4% | $0.64 | 0.18% |
| repeated-test-reruns | bash | opus46-200k-cli2.1.132 | 1 | 2.0min | 0.1% | $0.16 | 0.04% |
| repeated-test-reruns | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 1.0min | 0.1% | $0.35 | 0.10% |
| repeated-test-reruns | bash | sonnet46-200k-cli2.1.132 | 3 | 3.0min | 0.2% | $0.40 | 0.11% |
| repeated-test-reruns | default | opus47-1m-high-cli2.1.132 | 1 | 0.7min | 0.0% | $0.19 | 0.05% |
| repeated-test-reruns | default | opus47-1m-medium-cli2.1.132 | 2 | 1.3min | 0.1% | $0.31 | 0.09% |
| repeated-test-reruns | default | opus47-1m-xhigh-cli2.1.132 | 1 | 1.3min | 0.1% | $0.38 | 0.10% |
| repeated-test-reruns | default | sonnet46-200k-cli2.1.132 | 1 | 0.7min | 0.0% | $0.11 | 0.03% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.1% | $0.17 | 0.05% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 0.3% | $0.33 | 0.09% |
| repeated-test-reruns | powershell | opus46-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.21 | 0.06% |
| repeated-test-reruns | powershell | opus47-1m-high-cli2.1.132 | 1 | 0.7min | 0.0% | $0.17 | 0.05% |
| repeated-test-reruns | powershell | opus47-1m-medium-cli2.1.132 | 2 | 1.7min | 0.1% | $0.40 | 0.11% |
| repeated-test-reruns | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 0.7min | 0.0% | $0.21 | 0.06% |
| repeated-test-reruns | powershell | sonnet46-200k-cli2.1.132 | 1 | 1.3min | 0.1% | $0.26 | 0.07% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.1% | $0.05 | 0.01% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.07 | 0.02% |
| repeated-test-reruns | powershell-tool | opus47-1m-high-cli2.1.132 | 2 | 1.7min | 0.1% | $0.52 | 0.14% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium-cli2.1.132 | 1 | 1.0min | 0.1% | $0.29 | 0.08% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 4 | 4.3min | 0.3% | $1.41 | 0.39% |
| repeated-test-reruns | powershell-tool | sonnet46-200k-cli2.1.132 | 3 | 2.7min | 0.2% | $0.36 | 0.10% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.05 | 0.01% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 0.5% | $0.88 | 0.24% |
| repeated-test-reruns | typescript-bun | opus46-200k-cli2.1.132 | 1 | 0.7min | 0.0% | $0.13 | 0.04% |
| repeated-test-reruns | typescript-bun | opus47-1m-high-cli2.1.132 | 3 | 4.0min | 0.2% | $1.22 | 0.33% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium-cli2.1.132 | 3 | 2.0min | 0.1% | $0.48 | 0.13% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 4 | 5.0min | 0.3% | $1.42 | 0.39% |
| repeated-test-reruns | typescript-bun | sonnet46-200k-cli2.1.132 | 4 | 3.3min | 0.2% | $0.61 | 0.17% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.1% | $0.15 | 0.04% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 0.5% | $0.85 | 0.23% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 7 | 8.8min | 0.5% | $1.84 | 0.50% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-high-cli2.1.132 | 7 | 15.8min | 0.9% | $4.92 | 1.35% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium-cli2.1.132 | 7 | 7.2min | 0.4% | $1.78 | 0.49% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 5 | 10.4min | 0.6% | $2.95 | 0.81% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46-200k-cli2.1.132 | 7 | 10.6min | 0.6% | $1.88 | 0.51% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.1% | $0.19 | 0.05% |
| fixture-rework | bash | opus46-200k-cli2.1.132 | 5 | 9.8min | 0.6% | $2.41 | 0.66% |
| fixture-rework | bash | opus47-1m-high-cli2.1.132 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| fixture-rework | bash | opus47-1m-medium-cli2.1.132 | 2 | 1.0min | 0.1% | $0.26 | 0.07% |
| fixture-rework | bash | opus47-1m-xhigh-cli2.1.132 | 3 | 2.2min | 0.1% | $0.72 | 0.20% |
| fixture-rework | bash | sonnet46-200k-cli2.1.132 | 3 | 4.5min | 0.3% | $0.67 | 0.18% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.0% | $0.03 | 0.01% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.1% | $0.17 | 0.05% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 2 | 1.8min | 0.1% | $0.38 | 0.10% |
| fixture-rework | default | opus47-1m-xhigh-cli2.1.132 | 2 | 1.5min | 0.1% | $0.47 | 0.13% |
| fixture-rework | default | sonnet46-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.17 | 0.05% |
| fixture-rework | powershell | opus46-200k-cli2.1.132 | 1 | 0.8min | 0.0% | $0.16 | 0.04% |
| fixture-rework | powershell | opus47-1m-high-cli2.1.132 | 2 | 1.0min | 0.1% | $0.28 | 0.08% |
| fixture-rework | powershell | opus47-1m-medium-cli2.1.132 | 1 | 1.2min | 0.1% | $0.37 | 0.10% |
| fixture-rework | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 0.8min | 0.0% | $0.23 | 0.06% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.0% | $0.06 | 0.02% |
| fixture-rework | powershell-tool | opus47-1m-high-cli2.1.132 | 1 | 3.2min | 0.2% | $1.18 | 0.32% |
| fixture-rework | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 3 | 2.0min | 0.1% | $0.65 | 0.18% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.1% | $0.17 | 0.05% |
| fixture-rework | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 4 | 2.0min | 0.1% | $0.58 | 0.16% |
| fixture-rework | typescript-bun | sonnet46-200k-cli2.1.132 | 1 | 0.5min | 0.0% | $0.11 | 0.03% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 0.2% | $0.20 | 0.05% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 0.3% | $0.53 | 0.15% |
| act-push-debug-loops | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| act-push-debug-loops | bash | sonnet46-200k-cli2.1.132 | 2 | 1.2min | 0.1% | $0.15 | 0.04% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.0% | $0.05 | 0.01% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.0% | $0.03 | 0.01% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 0.4% | $0.43 | 0.12% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 0.2% | $0.35 | 0.09% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 0.7% | $0.70 | 0.19% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.1% | $0.10 | 0.03% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 0.2% | $0.22 | 0.06% |
| actionlint-fix-cycles | bash | opus46-200k-cli2.1.132 | 1 | 1.7min | 0.1% | $0.42 | 0.11% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.1% | $0.22 | 0.06% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.05 | 0.01% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 0.2% | $0.19 | 0.05% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 0.2% | $0.20 | 0.05% |
| mid-run-module-restructure | powershell | opus47-1m-high-cli2.1.132 | 1 | 2.0min | 0.1% | $0.50 | 0.14% |
| mid-run-module-restructure | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 2.0min | 0.1% | $0.61 | 0.17% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 1 | 2.0min | 0.1% | $0.66 | 0.18% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.04 | 0.01% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 0.2% | $0.15 | 0.04% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.1% | $0.20 | 0.05% |
| docker-pwsh-install | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 1.5min | 0.1% | $0.42 | 0.12% |
| bats-setup-issues | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 1.0min | 0.1% | $0.26 | 0.07% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.0% | $0.03 | 0.01% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.0% | $0.03 | 0.01% |
| fixture-rework | typescript-bun | sonnet46-200k-cli2.1.132 | 1 | 0.5min | 0.0% | $0.11 | 0.03% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.0% | $0.05 | 0.01% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.04 | 0.01% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.03 | 0.01% |
| repeated-test-reruns | default | opus47-1m-high-cli2.1.132 | 1 | 0.7min | 0.0% | $0.19 | 0.05% |
| repeated-test-reruns | default | sonnet46-200k-cli2.1.132 | 1 | 0.7min | 0.0% | $0.11 | 0.03% |
| repeated-test-reruns | powershell | opus47-1m-high-cli2.1.132 | 1 | 0.7min | 0.0% | $0.17 | 0.05% |
| repeated-test-reruns | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 0.7min | 0.0% | $0.21 | 0.06% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.05 | 0.01% |
| repeated-test-reruns | typescript-bun | opus46-200k-cli2.1.132 | 1 | 0.7min | 0.0% | $0.13 | 0.04% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.05 | 0.01% |
| fixture-rework | bash | opus47-1m-high-cli2.1.132 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| fixture-rework | powershell | opus46-200k-cli2.1.132 | 1 | 0.8min | 0.0% | $0.16 | 0.04% |
| fixture-rework | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 0.8min | 0.0% | $0.23 | 0.06% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.0% | $0.06 | 0.02% |
| act-push-debug-loops | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| repeated-test-reruns | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 1.0min | 0.1% | $0.35 | 0.10% |
| repeated-test-reruns | powershell | opus46-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.21 | 0.06% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.1% | $0.05 | 0.01% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.07 | 0.02% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium-cli2.1.132 | 1 | 1.0min | 0.1% | $0.29 | 0.08% |
| fixture-rework | bash | opus47-1m-medium-cli2.1.132 | 2 | 1.0min | 0.1% | $0.26 | 0.07% |
| fixture-rework | default | sonnet46-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.17 | 0.05% |
| fixture-rework | powershell | opus47-1m-high-cli2.1.132 | 2 | 1.0min | 0.1% | $0.28 | 0.08% |
| bats-setup-issues | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 1.0min | 0.1% | $0.26 | 0.07% |
| act-push-debug-loops | bash | sonnet46-200k-cli2.1.132 | 2 | 1.2min | 0.1% | $0.15 | 0.04% |
| fixture-rework | powershell | opus47-1m-medium-cli2.1.132 | 1 | 1.2min | 0.1% | $0.37 | 0.10% |
| repeated-test-reruns | default | opus47-1m-medium-cli2.1.132 | 2 | 1.3min | 0.1% | $0.31 | 0.09% |
| repeated-test-reruns | default | opus47-1m-xhigh-cli2.1.132 | 1 | 1.3min | 0.1% | $0.38 | 0.10% |
| repeated-test-reruns | powershell | sonnet46-200k-cli2.1.132 | 1 | 1.3min | 0.1% | $0.26 | 0.07% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.1% | $0.10 | 0.03% |
| fixture-rework | default | opus47-1m-xhigh-cli2.1.132 | 2 | 1.5min | 0.1% | $0.47 | 0.13% |
| docker-pwsh-install | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 1.5min | 0.1% | $0.42 | 0.12% |
| repeated-test-reruns | powershell | opus47-1m-medium-cli2.1.132 | 2 | 1.7min | 0.1% | $0.40 | 0.11% |
| repeated-test-reruns | powershell-tool | opus47-1m-high-cli2.1.132 | 2 | 1.7min | 0.1% | $0.52 | 0.14% |
| actionlint-fix-cycles | bash | opus46-200k-cli2.1.132 | 1 | 1.7min | 0.1% | $0.42 | 0.11% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.1% | $0.17 | 0.05% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 2 | 1.8min | 0.1% | $0.38 | 0.10% |
| repeated-test-reruns | bash | opus46-200k-cli2.1.132 | 1 | 2.0min | 0.1% | $0.16 | 0.04% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium-cli2.1.132 | 3 | 2.0min | 0.1% | $0.48 | 0.13% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.1% | $0.15 | 0.04% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.1% | $0.19 | 0.05% |
| fixture-rework | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 3 | 2.0min | 0.1% | $0.65 | 0.18% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.1% | $0.17 | 0.05% |
| fixture-rework | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 4 | 2.0min | 0.1% | $0.58 | 0.16% |
| mid-run-module-restructure | powershell | opus47-1m-high-cli2.1.132 | 1 | 2.0min | 0.1% | $0.50 | 0.14% |
| mid-run-module-restructure | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 2.0min | 0.1% | $0.61 | 0.17% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 1 | 2.0min | 0.1% | $0.66 | 0.18% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.1% | $0.20 | 0.05% |
| fixture-rework | bash | opus47-1m-xhigh-cli2.1.132 | 3 | 2.2min | 0.1% | $0.72 | 0.20% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.1% | $0.17 | 0.05% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.1% | $0.22 | 0.06% |
| repeated-test-reruns | powershell-tool | sonnet46-200k-cli2.1.132 | 3 | 2.7min | 0.2% | $0.36 | 0.10% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 0.2% | $0.19 | 0.05% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 0.2% | $0.20 | 0.05% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 0.2% | $0.22 | 0.06% |
| repeated-test-reruns | bash | sonnet46-200k-cli2.1.132 | 3 | 3.0min | 0.2% | $0.40 | 0.11% |
| fixture-rework | powershell-tool | opus47-1m-high-cli2.1.132 | 1 | 3.2min | 0.2% | $1.18 | 0.32% |
| repeated-test-reruns | typescript-bun | sonnet46-200k-cli2.1.132 | 4 | 3.3min | 0.2% | $0.61 | 0.17% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 0.2% | $0.35 | 0.09% |
| repeated-test-reruns | typescript-bun | opus47-1m-high-cli2.1.132 | 3 | 4.0min | 0.2% | $1.22 | 0.33% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 0.2% | $0.15 | 0.04% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 0.2% | $0.20 | 0.05% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 4 | 4.3min | 0.3% | $1.41 | 0.39% |
| fixture-rework | bash | sonnet46-200k-cli2.1.132 | 3 | 4.5min | 0.3% | $0.67 | 0.18% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 4 | 5.0min | 0.3% | $1.42 | 0.39% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 0.3% | $0.53 | 0.15% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 0.3% | $0.33 | 0.09% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 0.4% | $0.43 | 0.12% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 0.4% | $0.64 | 0.18% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium-cli2.1.132 | 7 | 7.2min | 0.4% | $1.78 | 0.49% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 0.5% | $0.88 | 0.24% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 0.5% | $0.85 | 0.23% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 7 | 8.8min | 0.5% | $1.84 | 0.50% |
| fixture-rework | bash | opus46-200k-cli2.1.132 | 5 | 9.8min | 0.6% | $2.41 | 0.66% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 5 | 10.4min | 0.6% | $2.95 | 0.81% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46-200k-cli2.1.132 | 7 | 10.6min | 0.6% | $1.88 | 0.51% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 0.7% | $0.70 | 0.19% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-high-cli2.1.132 | 7 | 15.8min | 0.9% | $4.92 | 1.35% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.0% | $0.03 | 0.01% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.0% | $0.03 | 0.01% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.03 | 0.01% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.04 | 0.01% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.05 | 0.01% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.0% | $0.05 | 0.01% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.05 | 0.01% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.1% | $0.05 | 0.01% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.0% | $0.06 | 0.02% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.07 | 0.02% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.1% | $0.10 | 0.03% |
| fixture-rework | typescript-bun | sonnet46-200k-cli2.1.132 | 1 | 0.5min | 0.0% | $0.11 | 0.03% |
| repeated-test-reruns | default | sonnet46-200k-cli2.1.132 | 1 | 0.7min | 0.0% | $0.11 | 0.03% |
| repeated-test-reruns | typescript-bun | opus46-200k-cli2.1.132 | 1 | 0.7min | 0.0% | $0.13 | 0.04% |
| act-push-debug-loops | bash | sonnet46-200k-cli2.1.132 | 2 | 1.2min | 0.1% | $0.15 | 0.04% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.1% | $0.15 | 0.04% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 0.2% | $0.15 | 0.04% |
| fixture-rework | powershell | opus46-200k-cli2.1.132 | 1 | 0.8min | 0.0% | $0.16 | 0.04% |
| repeated-test-reruns | bash | opus46-200k-cli2.1.132 | 1 | 2.0min | 0.1% | $0.16 | 0.04% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.1% | $0.17 | 0.05% |
| repeated-test-reruns | powershell | opus47-1m-high-cli2.1.132 | 1 | 0.7min | 0.0% | $0.17 | 0.05% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.1% | $0.17 | 0.05% |
| fixture-rework | default | sonnet46-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.17 | 0.05% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.1% | $0.17 | 0.05% |
| repeated-test-reruns | default | opus47-1m-high-cli2.1.132 | 1 | 0.7min | 0.0% | $0.19 | 0.05% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 0.2% | $0.19 | 0.05% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.1% | $0.19 | 0.05% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 0.2% | $0.20 | 0.05% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 0.2% | $0.20 | 0.05% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.1% | $0.20 | 0.05% |
| repeated-test-reruns | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 0.7min | 0.0% | $0.21 | 0.06% |
| repeated-test-reruns | powershell | opus46-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.21 | 0.06% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 0.2% | $0.22 | 0.06% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.1% | $0.22 | 0.06% |
| fixture-rework | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 0.8min | 0.0% | $0.23 | 0.06% |
| act-push-debug-loops | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| fixture-rework | bash | opus47-1m-high-cli2.1.132 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| fixture-rework | bash | opus47-1m-medium-cli2.1.132 | 2 | 1.0min | 0.1% | $0.26 | 0.07% |
| bats-setup-issues | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 1.0min | 0.1% | $0.26 | 0.07% |
| repeated-test-reruns | powershell | sonnet46-200k-cli2.1.132 | 1 | 1.3min | 0.1% | $0.26 | 0.07% |
| fixture-rework | powershell | opus47-1m-high-cli2.1.132 | 2 | 1.0min | 0.1% | $0.28 | 0.08% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium-cli2.1.132 | 1 | 1.0min | 0.1% | $0.29 | 0.08% |
| repeated-test-reruns | default | opus47-1m-medium-cli2.1.132 | 2 | 1.3min | 0.1% | $0.31 | 0.09% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 0.3% | $0.33 | 0.09% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 0.2% | $0.35 | 0.09% |
| repeated-test-reruns | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 1.0min | 0.1% | $0.35 | 0.10% |
| repeated-test-reruns | powershell-tool | sonnet46-200k-cli2.1.132 | 3 | 2.7min | 0.2% | $0.36 | 0.10% |
| fixture-rework | powershell | opus47-1m-medium-cli2.1.132 | 1 | 1.2min | 0.1% | $0.37 | 0.10% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 2 | 1.8min | 0.1% | $0.38 | 0.10% |
| repeated-test-reruns | default | opus47-1m-xhigh-cli2.1.132 | 1 | 1.3min | 0.1% | $0.38 | 0.10% |
| repeated-test-reruns | powershell | opus47-1m-medium-cli2.1.132 | 2 | 1.7min | 0.1% | $0.40 | 0.11% |
| repeated-test-reruns | bash | sonnet46-200k-cli2.1.132 | 3 | 3.0min | 0.2% | $0.40 | 0.11% |
| actionlint-fix-cycles | bash | opus46-200k-cli2.1.132 | 1 | 1.7min | 0.1% | $0.42 | 0.11% |
| docker-pwsh-install | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 1.5min | 0.1% | $0.42 | 0.12% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 0.4% | $0.43 | 0.12% |
| fixture-rework | default | opus47-1m-xhigh-cli2.1.132 | 2 | 1.5min | 0.1% | $0.47 | 0.13% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium-cli2.1.132 | 3 | 2.0min | 0.1% | $0.48 | 0.13% |
| mid-run-module-restructure | powershell | opus47-1m-high-cli2.1.132 | 1 | 2.0min | 0.1% | $0.50 | 0.14% |
| repeated-test-reruns | powershell-tool | opus47-1m-high-cli2.1.132 | 2 | 1.7min | 0.1% | $0.52 | 0.14% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 0.3% | $0.53 | 0.15% |
| fixture-rework | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 4 | 2.0min | 0.1% | $0.58 | 0.16% |
| repeated-test-reruns | typescript-bun | sonnet46-200k-cli2.1.132 | 4 | 3.3min | 0.2% | $0.61 | 0.17% |
| mid-run-module-restructure | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 2.0min | 0.1% | $0.61 | 0.17% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 0.4% | $0.64 | 0.18% |
| fixture-rework | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 3 | 2.0min | 0.1% | $0.65 | 0.18% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 1 | 2.0min | 0.1% | $0.66 | 0.18% |
| fixture-rework | bash | sonnet46-200k-cli2.1.132 | 3 | 4.5min | 0.3% | $0.67 | 0.18% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 0.7% | $0.70 | 0.19% |
| fixture-rework | bash | opus47-1m-xhigh-cli2.1.132 | 3 | 2.2min | 0.1% | $0.72 | 0.20% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 0.5% | $0.85 | 0.23% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 0.5% | $0.88 | 0.24% |
| fixture-rework | powershell-tool | opus47-1m-high-cli2.1.132 | 1 | 3.2min | 0.2% | $1.18 | 0.32% |
| repeated-test-reruns | typescript-bun | opus47-1m-high-cli2.1.132 | 3 | 4.0min | 0.2% | $1.22 | 0.33% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 4 | 4.3min | 0.3% | $1.41 | 0.39% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 4 | 5.0min | 0.3% | $1.42 | 0.39% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium-cli2.1.132 | 7 | 7.2min | 0.4% | $1.78 | 0.49% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 7 | 8.8min | 0.5% | $1.84 | 0.50% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46-200k-cli2.1.132 | 7 | 10.6min | 0.6% | $1.88 | 0.51% |
| fixture-rework | bash | opus46-200k-cli2.1.132 | 5 | 9.8min | 0.6% | $2.41 | 0.66% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 5 | 10.4min | 0.6% | $2.95 | 0.81% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-high-cli2.1.132 | 7 | 15.8min | 0.9% | $4.92 | 1.35% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.03 | 0.01% |
| repeated-test-reruns | bash | opus46-200k-cli2.1.132 | 1 | 2.0min | 0.1% | $0.16 | 0.04% |
| repeated-test-reruns | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 1.0min | 0.1% | $0.35 | 0.10% |
| repeated-test-reruns | default | opus47-1m-high-cli2.1.132 | 1 | 0.7min | 0.0% | $0.19 | 0.05% |
| repeated-test-reruns | default | opus47-1m-xhigh-cli2.1.132 | 1 | 1.3min | 0.1% | $0.38 | 0.10% |
| repeated-test-reruns | default | sonnet46-200k-cli2.1.132 | 1 | 0.7min | 0.0% | $0.11 | 0.03% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.1% | $0.17 | 0.05% |
| repeated-test-reruns | powershell | opus46-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.21 | 0.06% |
| repeated-test-reruns | powershell | opus47-1m-high-cli2.1.132 | 1 | 0.7min | 0.0% | $0.17 | 0.05% |
| repeated-test-reruns | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 0.7min | 0.0% | $0.21 | 0.06% |
| repeated-test-reruns | powershell | sonnet46-200k-cli2.1.132 | 1 | 1.3min | 0.1% | $0.26 | 0.07% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.1% | $0.05 | 0.01% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.07 | 0.02% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium-cli2.1.132 | 1 | 1.0min | 0.1% | $0.29 | 0.08% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.05 | 0.01% |
| repeated-test-reruns | typescript-bun | opus46-200k-cli2.1.132 | 1 | 0.7min | 0.0% | $0.13 | 0.04% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.1% | $0.15 | 0.04% |
| fixture-rework | bash | opus47-1m-high-cli2.1.132 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.0% | $0.03 | 0.01% |
| fixture-rework | default | sonnet46-200k-cli2.1.132 | 1 | 1.0min | 0.1% | $0.17 | 0.05% |
| fixture-rework | powershell | opus46-200k-cli2.1.132 | 1 | 0.8min | 0.0% | $0.16 | 0.04% |
| fixture-rework | powershell | opus47-1m-medium-cli2.1.132 | 1 | 1.2min | 0.1% | $0.37 | 0.10% |
| fixture-rework | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 0.8min | 0.0% | $0.23 | 0.06% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.0% | $0.06 | 0.02% |
| fixture-rework | powershell-tool | opus47-1m-high-cli2.1.132 | 1 | 3.2min | 0.2% | $1.18 | 0.32% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.1% | $0.17 | 0.05% |
| fixture-rework | typescript-bun | sonnet46-200k-cli2.1.132 | 1 | 0.5min | 0.0% | $0.11 | 0.03% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 0.2% | $0.20 | 0.05% |
| act-push-debug-loops | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.0% | $0.05 | 0.01% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.0% | $0.03 | 0.01% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 0.4% | $0.43 | 0.12% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.1% | $0.10 | 0.03% |
| actionlint-fix-cycles | bash | opus46-200k-cli2.1.132 | 1 | 1.7min | 0.1% | $0.42 | 0.11% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.05 | 0.01% |
| mid-run-module-restructure | powershell | opus47-1m-high-cli2.1.132 | 1 | 2.0min | 0.1% | $0.50 | 0.14% |
| mid-run-module-restructure | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 2.0min | 0.1% | $0.61 | 0.17% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 1 | 2.0min | 0.1% | $0.66 | 0.18% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.0% | $0.04 | 0.01% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 0.2% | $0.15 | 0.04% |
| docker-pwsh-install | powershell | opus47-1m-xhigh-cli2.1.132 | 1 | 1.5min | 0.1% | $0.42 | 0.12% |
| bats-setup-issues | bash | opus47-1m-xhigh-cli2.1.132 | 1 | 1.0min | 0.1% | $0.26 | 0.07% |
| repeated-test-reruns | default | opus47-1m-medium-cli2.1.132 | 2 | 1.3min | 0.1% | $0.31 | 0.09% |
| repeated-test-reruns | powershell | opus47-1m-medium-cli2.1.132 | 2 | 1.7min | 0.1% | $0.40 | 0.11% |
| repeated-test-reruns | powershell-tool | opus47-1m-high-cli2.1.132 | 2 | 1.7min | 0.1% | $0.52 | 0.14% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.1% | $0.19 | 0.05% |
| fixture-rework | bash | opus47-1m-medium-cli2.1.132 | 2 | 1.0min | 0.1% | $0.26 | 0.07% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.1% | $0.17 | 0.05% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 2 | 1.8min | 0.1% | $0.38 | 0.10% |
| fixture-rework | default | opus47-1m-xhigh-cli2.1.132 | 2 | 1.5min | 0.1% | $0.47 | 0.13% |
| fixture-rework | powershell | opus47-1m-high-cli2.1.132 | 2 | 1.0min | 0.1% | $0.28 | 0.08% |
| act-push-debug-loops | bash | sonnet46-200k-cli2.1.132 | 2 | 1.2min | 0.1% | $0.15 | 0.04% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.1% | $0.22 | 0.06% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 0.2% | $0.20 | 0.05% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.1% | $0.20 | 0.05% |
| repeated-test-reruns | bash | sonnet46-200k-cli2.1.132 | 3 | 3.0min | 0.2% | $0.40 | 0.11% |
| repeated-test-reruns | powershell-tool | sonnet46-200k-cli2.1.132 | 3 | 2.7min | 0.2% | $0.36 | 0.10% |
| repeated-test-reruns | typescript-bun | opus47-1m-high-cli2.1.132 | 3 | 4.0min | 0.2% | $1.22 | 0.33% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium-cli2.1.132 | 3 | 2.0min | 0.1% | $0.48 | 0.13% |
| fixture-rework | bash | opus47-1m-xhigh-cli2.1.132 | 3 | 2.2min | 0.1% | $0.72 | 0.20% |
| fixture-rework | bash | sonnet46-200k-cli2.1.132 | 3 | 4.5min | 0.3% | $0.67 | 0.18% |
| fixture-rework | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 3 | 2.0min | 0.1% | $0.65 | 0.18% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 0.3% | $0.53 | 0.15% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 0.2% | $0.35 | 0.09% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 0.2% | $0.19 | 0.05% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 0.3% | $0.33 | 0.09% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh-cli2.1.132 | 4 | 4.3min | 0.3% | $1.41 | 0.39% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 4 | 5.0min | 0.3% | $1.42 | 0.39% |
| repeated-test-reruns | typescript-bun | sonnet46-200k-cli2.1.132 | 4 | 3.3min | 0.2% | $0.61 | 0.17% |
| fixture-rework | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 4 | 2.0min | 0.1% | $0.58 | 0.16% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 0.2% | $0.22 | 0.06% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 0.4% | $0.64 | 0.18% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh-cli2.1.132 | 5 | 10.4min | 0.6% | $2.95 | 0.81% |
| fixture-rework | bash | opus46-200k-cli2.1.132 | 5 | 9.8min | 0.6% | $2.41 | 0.66% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 0.7% | $0.70 | 0.19% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 0.5% | $0.88 | 0.24% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 0.5% | $0.85 | 0.23% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 7 | 8.8min | 0.5% | $1.84 | 0.50% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-high-cli2.1.132 | 7 | 15.8min | 0.9% | $4.92 | 1.35% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium-cli2.1.132 | 7 | 7.2min | 0.4% | $1.78 | 0.49% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46-200k-cli2.1.132 | 7 | 10.6min | 0.6% | $1.88 | 0.51% |

</details>

#### Trap Descriptions

- **act-permission-path-errors**: Files not found or permission denied inside the act Docker container.
- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **actionlint-fix-cycles**: Workflow YAML required 3+ actionlint runs and 2+ fixes to pass.
- **bats-setup-issues**: Agent struggled with bats-core test framework setup or load helpers.
- **docker-pwsh-install**: Multiple Docker test runs trying to figure out how to install PowerShell in act's container.
- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
- **mid-run-module-restructure**: Agent restructured from a flat .ps1 script to a .psm1 module mid-run.
- **pwsh-runtime-install-overhead**: Time spent installing PowerShell and Pester inside act containers. Both are pre-installed on real GitHub runners but must be downloaded (~56MB) and installed in each act job. Measured from act step durations.
- **repeated-test-reruns**: Same test command executed 4+ times without the underlying code changing.
- **ts-type-error-fix-cycles**: TypeScript type errors caught by `tsc --noEmit` hooks; each requires a fix cycle.

#### Column Definitions

- **Fell In**: Number of runs (within that language/model) where this trap was detected.
- **Time Lost**: Estimated wall-clock seconds wasted on the trap, based on the number of
  wasted commands multiplied by a per-command cost (15–25s for typical Bash, 45s for Docker runs, 50s for act push).
- **% of Time**: Time Lost as a percentage of total benchmark duration.
- **$ Lost**: Proportional cost impact, calculated as (Time Lost / Run Duration) × Run Cost for each affected run.
- **% of $**: $ Lost as a percentage of total benchmark cost.

### Traps by Language/Model/Effort

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 0.3% | $0.23 | 0.06% |
| bash | haiku45-200k-cli2.1.132 | 6 | 12 | 15.5min | 0.9% | $1.57 | 0.43% |
| bash | opus46-200k-cli2.1.132 | 7 | 7 | 13.4min | 0.8% | $2.98 | 0.82% |
| bash | opus47-1m-high-cli2.1.132 | 7 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| bash | opus47-1m-medium-cli2.1.132 | 7 | 2 | 1.0min | 0.1% | $0.26 | 0.07% |
| bash | opus47-1m-xhigh-cli2.1.132 | 5 | 6 | 5.1min | 0.3% | $1.57 | 0.43% |
| bash | sonnet46-200k-cli2.1.132 | 7 | 8 | 8.7min | 0.5% | $1.23 | 0.34% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.1% | $0.08 | 0.02% |
| default | haiku45-200k-cli2.1.132 | 5 | 5 | 4.4min | 0.3% | $0.42 | 0.11% |
| default | opus46-200k-cli2.1.132 | 7 | 2 | 1.8min | 0.1% | $0.38 | 0.10% |
| default | opus47-1m-high-cli2.1.132 | 7 | 1 | 0.7min | 0.0% | $0.19 | 0.05% |
| default | opus47-1m-medium-cli2.1.132 | 7 | 2 | 1.3min | 0.1% | $0.31 | 0.09% |
| default | opus47-1m-xhigh-cli2.1.132 | 6 | 3 | 2.8min | 0.2% | $0.85 | 0.23% |
| default | sonnet46-200k-cli2.1.132 | 7 | 2 | 1.7min | 0.1% | $0.28 | 0.08% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 0.5% | $0.64 | 0.18% |
| powershell | haiku45-200k-cli2.1.132 | 6 | 7 | 9.2min | 0.5% | $0.67 | 0.18% |
| powershell | opus46-200k-cli2.1.132 | 7 | 2 | 1.8min | 0.1% | $0.37 | 0.10% |
| powershell | opus47-1m-high-cli2.1.132 | 7 | 4 | 3.7min | 0.2% | $0.94 | 0.26% |
| powershell | opus47-1m-medium-cli2.1.132 | 7 | 3 | 2.9min | 0.2% | $0.77 | 0.21% |
| powershell | opus47-1m-xhigh-cli2.1.132 | 5 | 4 | 4.9min | 0.3% | $1.47 | 0.40% |
| powershell | sonnet46-200k-cli2.1.132 | 7 | 1 | 1.3min | 0.1% | $0.26 | 0.07% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.1% | $0.09 | 0.02% |
| powershell-tool | haiku45-200k-cli2.1.132 | 6 | 11 | 21.5min | 1.2% | $1.17 | 0.32% |
| powershell-tool | opus46-200k-cli2.1.132 | 7 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus47-1m-high-cli2.1.132 | 7 | 3 | 4.9min | 0.3% | $1.70 | 0.47% |
| powershell-tool | opus47-1m-medium-cli2.1.132 | 7 | 1 | 1.0min | 0.1% | $0.29 | 0.08% |
| powershell-tool | opus47-1m-xhigh-cli2.1.132 | 5 | 8 | 8.3min | 0.5% | $2.72 | 0.75% |
| powershell-tool | sonnet46-200k-cli2.1.132 | 7 | 3 | 2.7min | 0.2% | $0.36 | 0.10% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 0.2% | $0.30 | 0.08% |
| typescript-bun | haiku45-200k-cli2.1.132 | 6 | 19 | 24.8min | 1.4% | $2.31 | 0.63% |
| typescript-bun | opus46-200k-cli2.1.132 | 7 | 8 | 9.5min | 0.6% | $1.97 | 0.54% |
| typescript-bun | opus47-1m-high-cli2.1.132 | 7 | 10 | 19.8min | 1.2% | $6.14 | 1.68% |
| typescript-bun | opus47-1m-medium-cli2.1.132 | 7 | 10 | 9.2min | 0.5% | $2.26 | 0.62% |
| typescript-bun | opus47-1m-xhigh-cli2.1.132 | 5 | 13 | 17.4min | 1.0% | $4.95 | 1.36% |
| typescript-bun | sonnet46-200k-cli2.1.132 | 7 | 12 | 14.4min | 0.8% | $2.59 | 0.71% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| powershell-tool | opus46-200k-cli2.1.132 | 7 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus47-1m-high-cli2.1.132 | 7 | 1 | 0.7min | 0.0% | $0.19 | 0.05% |
| bash | opus47-1m-high-cli2.1.132 | 7 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| bash | opus47-1m-medium-cli2.1.132 | 7 | 2 | 1.0min | 0.1% | $0.26 | 0.07% |
| powershell-tool | opus47-1m-medium-cli2.1.132 | 7 | 1 | 1.0min | 0.1% | $0.29 | 0.08% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.1% | $0.08 | 0.02% |
| default | opus47-1m-medium-cli2.1.132 | 7 | 2 | 1.3min | 0.1% | $0.31 | 0.09% |
| powershell | sonnet46-200k-cli2.1.132 | 7 | 1 | 1.3min | 0.1% | $0.26 | 0.07% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.1% | $0.09 | 0.02% |
| default | sonnet46-200k-cli2.1.132 | 7 | 2 | 1.7min | 0.1% | $0.28 | 0.08% |
| default | opus46-200k-cli2.1.132 | 7 | 2 | 1.8min | 0.1% | $0.38 | 0.10% |
| powershell | opus46-200k-cli2.1.132 | 7 | 2 | 1.8min | 0.1% | $0.37 | 0.10% |
| powershell-tool | sonnet46-200k-cli2.1.132 | 7 | 3 | 2.7min | 0.2% | $0.36 | 0.10% |
| default | opus47-1m-xhigh-cli2.1.132 | 6 | 3 | 2.8min | 0.2% | $0.85 | 0.23% |
| powershell | opus47-1m-medium-cli2.1.132 | 7 | 3 | 2.9min | 0.2% | $0.77 | 0.21% |
| powershell | opus47-1m-high-cli2.1.132 | 7 | 4 | 3.7min | 0.2% | $0.94 | 0.26% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 0.2% | $0.30 | 0.08% |
| default | haiku45-200k-cli2.1.132 | 5 | 5 | 4.4min | 0.3% | $0.42 | 0.11% |
| powershell | opus47-1m-xhigh-cli2.1.132 | 5 | 4 | 4.9min | 0.3% | $1.47 | 0.40% |
| powershell-tool | opus47-1m-high-cli2.1.132 | 7 | 3 | 4.9min | 0.3% | $1.70 | 0.47% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 0.3% | $0.23 | 0.06% |
| bash | opus47-1m-xhigh-cli2.1.132 | 5 | 6 | 5.1min | 0.3% | $1.57 | 0.43% |
| powershell-tool | opus47-1m-xhigh-cli2.1.132 | 5 | 8 | 8.3min | 0.5% | $2.72 | 0.75% |
| bash | sonnet46-200k-cli2.1.132 | 7 | 8 | 8.7min | 0.5% | $1.23 | 0.34% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 0.5% | $0.64 | 0.18% |
| powershell | haiku45-200k-cli2.1.132 | 6 | 7 | 9.2min | 0.5% | $0.67 | 0.18% |
| typescript-bun | opus47-1m-medium-cli2.1.132 | 7 | 10 | 9.2min | 0.5% | $2.26 | 0.62% |
| typescript-bun | opus46-200k-cli2.1.132 | 7 | 8 | 9.5min | 0.6% | $1.97 | 0.54% |
| bash | opus46-200k-cli2.1.132 | 7 | 7 | 13.4min | 0.8% | $2.98 | 0.82% |
| typescript-bun | sonnet46-200k-cli2.1.132 | 7 | 12 | 14.4min | 0.8% | $2.59 | 0.71% |
| bash | haiku45-200k-cli2.1.132 | 6 | 12 | 15.5min | 0.9% | $1.57 | 0.43% |
| typescript-bun | opus47-1m-xhigh-cli2.1.132 | 5 | 13 | 17.4min | 1.0% | $4.95 | 1.36% |
| typescript-bun | opus47-1m-high-cli2.1.132 | 7 | 10 | 19.8min | 1.2% | $6.14 | 1.68% |
| powershell-tool | haiku45-200k-cli2.1.132 | 6 | 11 | 21.5min | 1.2% | $1.17 | 0.32% |
| typescript-bun | haiku45-200k-cli2.1.132 | 6 | 19 | 24.8min | 1.4% | $2.31 | 0.63% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| powershell-tool | opus46-200k-cli2.1.132 | 7 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.1% | $0.08 | 0.02% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.1% | $0.09 | 0.02% |
| default | opus47-1m-high-cli2.1.132 | 7 | 1 | 0.7min | 0.0% | $0.19 | 0.05% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 0.3% | $0.23 | 0.06% |
| bash | opus47-1m-high-cli2.1.132 | 7 | 1 | 0.8min | 0.0% | $0.24 | 0.07% |
| bash | opus47-1m-medium-cli2.1.132 | 7 | 2 | 1.0min | 0.1% | $0.26 | 0.07% |
| powershell | sonnet46-200k-cli2.1.132 | 7 | 1 | 1.3min | 0.1% | $0.26 | 0.07% |
| default | sonnet46-200k-cli2.1.132 | 7 | 2 | 1.7min | 0.1% | $0.28 | 0.08% |
| powershell-tool | opus47-1m-medium-cli2.1.132 | 7 | 1 | 1.0min | 0.1% | $0.29 | 0.08% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 0.2% | $0.30 | 0.08% |
| default | opus47-1m-medium-cli2.1.132 | 7 | 2 | 1.3min | 0.1% | $0.31 | 0.09% |
| powershell-tool | sonnet46-200k-cli2.1.132 | 7 | 3 | 2.7min | 0.2% | $0.36 | 0.10% |
| powershell | opus46-200k-cli2.1.132 | 7 | 2 | 1.8min | 0.1% | $0.37 | 0.10% |
| default | opus46-200k-cli2.1.132 | 7 | 2 | 1.8min | 0.1% | $0.38 | 0.10% |
| default | haiku45-200k-cli2.1.132 | 5 | 5 | 4.4min | 0.3% | $0.42 | 0.11% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 0.5% | $0.64 | 0.18% |
| powershell | haiku45-200k-cli2.1.132 | 6 | 7 | 9.2min | 0.5% | $0.67 | 0.18% |
| powershell | opus47-1m-medium-cli2.1.132 | 7 | 3 | 2.9min | 0.2% | $0.77 | 0.21% |
| default | opus47-1m-xhigh-cli2.1.132 | 6 | 3 | 2.8min | 0.2% | $0.85 | 0.23% |
| powershell | opus47-1m-high-cli2.1.132 | 7 | 4 | 3.7min | 0.2% | $0.94 | 0.26% |
| powershell-tool | haiku45-200k-cli2.1.132 | 6 | 11 | 21.5min | 1.2% | $1.17 | 0.32% |
| bash | sonnet46-200k-cli2.1.132 | 7 | 8 | 8.7min | 0.5% | $1.23 | 0.34% |
| powershell | opus47-1m-xhigh-cli2.1.132 | 5 | 4 | 4.9min | 0.3% | $1.47 | 0.40% |
| bash | haiku45-200k-cli2.1.132 | 6 | 12 | 15.5min | 0.9% | $1.57 | 0.43% |
| bash | opus47-1m-xhigh-cli2.1.132 | 5 | 6 | 5.1min | 0.3% | $1.57 | 0.43% |
| powershell-tool | opus47-1m-high-cli2.1.132 | 7 | 3 | 4.9min | 0.3% | $1.70 | 0.47% |
| typescript-bun | opus46-200k-cli2.1.132 | 7 | 8 | 9.5min | 0.6% | $1.97 | 0.54% |
| typescript-bun | opus47-1m-medium-cli2.1.132 | 7 | 10 | 9.2min | 0.5% | $2.26 | 0.62% |
| typescript-bun | haiku45-200k-cli2.1.132 | 6 | 19 | 24.8min | 1.4% | $2.31 | 0.63% |
| typescript-bun | sonnet46-200k-cli2.1.132 | 7 | 12 | 14.4min | 0.8% | $2.59 | 0.71% |
| powershell-tool | opus47-1m-xhigh-cli2.1.132 | 5 | 8 | 8.3min | 0.5% | $2.72 | 0.75% |
| bash | opus46-200k-cli2.1.132 | 7 | 7 | 13.4min | 0.8% | $2.98 | 0.82% |
| typescript-bun | opus47-1m-xhigh-cli2.1.132 | 5 | 13 | 17.4min | 1.0% | $4.95 | 1.36% |
| typescript-bun | opus47-1m-high-cli2.1.132 | 7 | 10 | 19.8min | 1.2% | $6.14 | 1.68% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 199 | $15.64 | 4.29% |
| Miss | 2 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| bash | opus46-200k | 23.0 | 42.9 | 1.9 | 0.71 |
| bash | opus47-1m-high | 27.3 | 41.9 | 1.5 | 1.14 |
| bash | opus47-1m-medium | 16.7 | 33.4 | 2.0 | 0.94 |
| bash | opus47-1m-xhigh | 20.4 | 51.8 | 2.5 | 0.84 |
| bash | sonnet46-200k | 23.0 | 42.0 | 1.8 | 0.76 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| default | opus46-200k | 10.3 | 27.7 | 2.7 | 1.88 |
| default | opus47-1m-high | 20.9 | 45.4 | 2.2 | 1.37 |
| default | opus47-1m-medium | 20.3 | 42.4 | 2.1 | 1.54 |
| default | opus47-1m-xhigh | 30.0 | 55.3 | 1.8 | 1.14 |
| default | sonnet46-200k | 36.1 | 51.6 | 1.4 | 2.11 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |
| powershell | opus46-200k | 36.3 | 54.6 | 1.5 | 1.34 |
| powershell | opus47-1m-high | 26.4 | 47.6 | 1.8 | 2.63 |
| powershell | opus47-1m-medium | 15.6 | 39.0 | 2.5 | 2.23 |
| powershell | opus47-1m-xhigh | 28.6 | 47.6 | 1.7 | 0.73 |
| powershell | sonnet46-200k | 43.3 | 59.7 | 1.4 | 2.44 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| powershell-tool | opus46-200k | 20.3 | 44.4 | 2.2 | 0.73 |
| powershell-tool | opus47-1m-high | 28.1 | 53.4 | 1.9 | 0.93 |
| powershell-tool | opus47-1m-medium | 17.6 | 34.9 | 2.0 | 2.01 |
| powershell-tool | opus47-1m-xhigh | 37.6 | 63.6 | 1.7 | 6.94 |
| powershell-tool | sonnet46-200k | 32.0 | 47.6 | 1.5 | 0.96 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| typescript-bun | opus46-200k | 22.7 | 55.1 | 2.4 | 0.92 |
| typescript-bun | opus47-1m-high | 27.6 | 62.0 | 2.2 | 1.73 |
| typescript-bun | opus47-1m-medium | 19.0 | 38.6 | 2.0 | 1.28 |
| typescript-bun | opus47-1m-xhigh | 21.2 | 47.4 | 2.2 | 1.36 |
| typescript-bun | sonnet46-200k | 38.7 | 65.0 | 1.7 | 1.63 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell | sonnet46-200k | 43.3 | 59.7 | 1.4 | 2.44 |
| typescript-bun | sonnet46-200k | 38.7 | 65.0 | 1.7 | 1.63 |
| powershell-tool | opus47-1m-xhigh | 37.6 | 63.6 | 1.7 | 6.94 |
| powershell | opus46-200k | 36.3 | 54.6 | 1.5 | 1.34 |
| default | sonnet46-200k | 36.1 | 51.6 | 1.4 | 2.11 |
| powershell-tool | sonnet46-200k | 32.0 | 47.6 | 1.5 | 0.96 |
| default | opus47-1m-xhigh | 30.0 | 55.3 | 1.8 | 1.14 |
| powershell | opus47-1m-xhigh | 28.6 | 47.6 | 1.7 | 0.73 |
| powershell-tool | opus47-1m-high | 28.1 | 53.4 | 1.9 | 0.93 |
| typescript-bun | opus47-1m-high | 27.6 | 62.0 | 2.2 | 1.73 |
| bash | opus47-1m-high | 27.3 | 41.9 | 1.5 | 1.14 |
| powershell | opus47-1m-high | 26.4 | 47.6 | 1.8 | 2.63 |
| bash | opus46-200k | 23.0 | 42.9 | 1.9 | 0.71 |
| bash | sonnet46-200k | 23.0 | 42.0 | 1.8 | 0.76 |
| typescript-bun | opus46-200k | 22.7 | 55.1 | 2.4 | 0.92 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| typescript-bun | opus47-1m-xhigh | 21.2 | 47.4 | 2.2 | 1.36 |
| default | opus47-1m-high | 20.9 | 45.4 | 2.2 | 1.37 |
| bash | opus47-1m-xhigh | 20.4 | 51.8 | 2.5 | 0.84 |
| default | opus47-1m-medium | 20.3 | 42.4 | 2.1 | 1.54 |
| powershell-tool | opus46-200k | 20.3 | 44.4 | 2.2 | 0.73 |
| typescript-bun | opus47-1m-medium | 19.0 | 38.6 | 2.0 | 1.28 |
| powershell-tool | opus47-1m-medium | 17.6 | 34.9 | 2.0 | 2.01 |
| bash | opus47-1m-medium | 16.7 | 33.4 | 2.0 | 0.94 |
| powershell | opus47-1m-medium | 15.6 | 39.0 | 2.5 | 2.23 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| default | opus46-200k | 10.3 | 27.7 | 2.7 | 1.88 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | sonnet46-200k | 38.7 | 65.0 | 1.7 | 1.63 |
| powershell-tool | opus47-1m-xhigh | 37.6 | 63.6 | 1.7 | 6.94 |
| typescript-bun | opus47-1m-high | 27.6 | 62.0 | 2.2 | 1.73 |
| powershell | sonnet46-200k | 43.3 | 59.7 | 1.4 | 2.44 |
| default | opus47-1m-xhigh | 30.0 | 55.3 | 1.8 | 1.14 |
| typescript-bun | opus46-200k | 22.7 | 55.1 | 2.4 | 0.92 |
| powershell | opus46-200k | 36.3 | 54.6 | 1.5 | 1.34 |
| powershell-tool | opus47-1m-high | 28.1 | 53.4 | 1.9 | 0.93 |
| bash | opus47-1m-xhigh | 20.4 | 51.8 | 2.5 | 0.84 |
| default | sonnet46-200k | 36.1 | 51.6 | 1.4 | 2.11 |
| powershell | opus47-1m-xhigh | 28.6 | 47.6 | 1.7 | 0.73 |
| powershell | opus47-1m-high | 26.4 | 47.6 | 1.8 | 2.63 |
| powershell-tool | sonnet46-200k | 32.0 | 47.6 | 1.5 | 0.96 |
| typescript-bun | opus47-1m-xhigh | 21.2 | 47.4 | 2.2 | 1.36 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| default | opus47-1m-high | 20.9 | 45.4 | 2.2 | 1.37 |
| powershell-tool | opus46-200k | 20.3 | 44.4 | 2.2 | 0.73 |
| bash | opus46-200k | 23.0 | 42.9 | 1.9 | 0.71 |
| default | opus47-1m-medium | 20.3 | 42.4 | 2.1 | 1.54 |
| bash | sonnet46-200k | 23.0 | 42.0 | 1.8 | 0.76 |
| bash | opus47-1m-high | 27.3 | 41.9 | 1.5 | 1.14 |
| powershell | opus47-1m-medium | 15.6 | 39.0 | 2.5 | 2.23 |
| typescript-bun | opus47-1m-medium | 19.0 | 38.6 | 2.0 | 1.28 |
| powershell-tool | opus47-1m-medium | 17.6 | 34.9 | 2.0 | 2.01 |
| bash | opus47-1m-medium | 16.7 | 33.4 | 2.0 | 0.94 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| default | opus46-200k | 10.3 | 27.7 | 2.7 | 1.88 |
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-tool | opus47-1m-xhigh | 37.6 | 63.6 | 1.7 | 6.94 |
| powershell | opus47-1m-high | 26.4 | 47.6 | 1.8 | 2.63 |
| powershell | sonnet46-200k | 43.3 | 59.7 | 1.4 | 2.44 |
| powershell | opus47-1m-medium | 15.6 | 39.0 | 2.5 | 2.23 |
| default | sonnet46-200k | 36.1 | 51.6 | 1.4 | 2.11 |
| powershell-tool | opus47-1m-medium | 17.6 | 34.9 | 2.0 | 2.01 |
| default | opus46-200k | 10.3 | 27.7 | 2.7 | 1.88 |
| typescript-bun | opus47-1m-high | 27.6 | 62.0 | 2.2 | 1.73 |
| typescript-bun | sonnet46-200k | 38.7 | 65.0 | 1.7 | 1.63 |
| default | opus47-1m-medium | 20.3 | 42.4 | 2.1 | 1.54 |
| default | opus47-1m-high | 20.9 | 45.4 | 2.2 | 1.37 |
| typescript-bun | opus47-1m-xhigh | 21.2 | 47.4 | 2.2 | 1.36 |
| powershell | opus46-200k | 36.3 | 54.6 | 1.5 | 1.34 |
| typescript-bun | opus47-1m-medium | 19.0 | 38.6 | 2.0 | 1.28 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| default | opus47-1m-xhigh | 30.0 | 55.3 | 1.8 | 1.14 |
| bash | opus47-1m-high | 27.3 | 41.9 | 1.5 | 1.14 |
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| powershell-tool | sonnet46-200k | 32.0 | 47.6 | 1.5 | 0.96 |
| bash | opus47-1m-medium | 16.7 | 33.4 | 2.0 | 0.94 |
| powershell-tool | opus47-1m-high | 28.1 | 53.4 | 1.9 | 0.93 |
| typescript-bun | opus46-200k | 22.7 | 55.1 | 2.4 | 0.92 |
| bash | opus47-1m-xhigh | 20.4 | 51.8 | 2.5 | 0.84 |
| bash | sonnet46-200k | 23.0 | 42.0 | 1.8 | 0.76 |
| powershell-tool | opus46-200k | 20.3 | 44.4 | 2.2 | 0.73 |
| powershell | opus47-1m-xhigh | 28.6 | 47.6 | 1.7 | 0.73 |
| bash | opus46-200k | 23.0 | 42.9 | 1.9 | 0.71 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Language | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | bash | haiku45-200k | 20 | 26 | 1.3 | 259 | 258 | 1.00 |
| Semantic Version Bumper | bash | opus46-200k | 16 | 36 | 2.2 | 155 | 365 | 0.42 |
| Semantic Version Bumper | bash | opus47-1m-high | 31 | 64 | 2.1 | 388 | 288 | 1.35 |
| Semantic Version Bumper | bash | opus47-1m-medium | 22 | 31 | 1.4 | 185 | 165 | 1.12 |
| Semantic Version Bumper | bash | sonnet46-200k | 24 | 18 | 0.8 | 156 | 189 | 0.83 |
| Semantic Version Bumper | default | haiku45-200k | 0 | 0 | 0.0 | 0 | 17 | 0.00 |
| Semantic Version Bumper | default | opus46-200k | 8 | 11 | 1.4 | 392 | 227 | 1.73 |
| Semantic Version Bumper | default | opus47-1m-high | 4 | 22 | 5.5 | 333 | 275 | 1.21 |
| Semantic Version Bumper | default | opus47-1m-medium | 24 | 51 | 2.1 | 360 | 204 | 1.76 |
| Semantic Version Bumper | default | sonnet46-200k | 51 | 53 | 1.0 | 498 | 230 | 2.17 |
| Semantic Version Bumper | powershell | haiku45-200k | 18 | 22 | 1.2 | 197 | 333 | 0.59 |
| Semantic Version Bumper | powershell | opus46-200k | 26 | 51 | 2.0 | 196 | 442 | 0.44 |
| Semantic Version Bumper | powershell | opus47-1m-high | 47 | 85 | 1.8 | 498 | 47 | 10.60 |
| Semantic Version Bumper | powershell | opus47-1m-medium | 16 | 29 | 1.8 | 175 | 156 | 1.12 |
| Semantic Version Bumper | powershell | sonnet46-200k | 33 | 40 | 1.2 | 251 | 194 | 1.29 |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 20 | 44 | 2.2 | 227 | 599 | 0.38 |
| Semantic Version Bumper | powershell-tool | opus46-200k | 24 | 34 | 1.4 | 197 | 345 | 0.57 |
| Semantic Version Bumper | powershell-tool | opus47-1m-high | 35 | 68 | 1.9 | 471 | 263 | 1.79 |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 18 | 26 | 1.4 | 84 | 139 | 0.60 |
| Semantic Version Bumper | powershell-tool | sonnet46-200k | 20 | 20 | 1.0 | 279 | 278 | 1.00 |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 38 | 76 | 2.0 | 503 | 585 | 0.86 |
| Semantic Version Bumper | typescript-bun | opus46-200k | 44 | 62 | 1.4 | 300 | 540 | 0.56 |
| Semantic Version Bumper | typescript-bun | opus47-1m-high | 46 | 87 | 1.9 | 713 | 391 | 1.82 |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 25 | 62 | 2.5 | 362 | 301 | 1.20 |
| Semantic Version Bumper | typescript-bun | sonnet46-200k | 51 | 93 | 1.8 | 567 | 205 | 2.77 |
| PR Label Assigner | bash | haiku45-200k | 15 | 13 | 0.9 | 145 | 163 | 0.89 |
| PR Label Assigner | bash | opus46-200k | 0 | 0 | 0.0 | 0 | 405 | 0.00 |
| PR Label Assigner | bash | opus47-1m-high | 14 | 28 | 2.0 | 104 | 274 | 0.38 |
| PR Label Assigner | bash | opus47-1m-medium | 21 | 43 | 2.0 | 237 | 132 | 1.80 |
| PR Label Assigner | bash | sonnet46-200k | 25 | 47 | 1.9 | 222 | 266 | 0.83 |
| PR Label Assigner | default | haiku45-200k | 14 | 19 | 1.4 | 302 | 121 | 2.50 |
| PR Label Assigner | default | opus46-200k | 0 | 16 | 0.0 | 252 | 120 | 2.10 |
| PR Label Assigner | default | opus47-1m-high | 16 | 24 | 1.5 | 199 | 406 | 0.49 |
| PR Label Assigner | default | opus47-1m-medium | 16 | 26 | 1.6 | 157 | 293 | 0.54 |
| PR Label Assigner | default | sonnet46-200k | 36 | 55 | 1.5 | 579 | 260 | 2.23 |
| PR Label Assigner | powershell | haiku45-200k | 13 | 22 | 1.7 | 253 | 317 | 0.80 |
| PR Label Assigner | powershell | opus46-200k | 30 | 42 | 1.4 | 263 | 217 | 1.21 |
| PR Label Assigner | powershell | opus47-1m-high | 27 | 39 | 1.4 | 286 | 487 | 0.59 |
| PR Label Assigner | powershell | opus47-1m-medium | 17 | 31 | 1.8 | 155 | 266 | 0.58 |
| PR Label Assigner | powershell | sonnet46-200k | 63 | 73 | 1.2 | 499 | 190 | 2.63 |
| PR Label Assigner | powershell-tool | haiku45-200k | 9 | 17 | 1.9 | 140 | 470 | 0.30 |
| PR Label Assigner | powershell-tool | opus46-200k | 20 | 36 | 1.8 | 157 | 127 | 1.24 |
| PR Label Assigner | powershell-tool | opus47-1m-high | 18 | 24 | 1.3 | 230 | 394 | 0.58 |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 25 | 44 | 1.8 | 211 | 139 | 1.52 |
| PR Label Assigner | powershell-tool | sonnet46-200k | 50 | 64 | 1.3 | 348 | 320 | 1.09 |
| PR Label Assigner | typescript-bun | haiku45-200k | 11 | 15 | 1.4 | 151 | 121 | 1.25 |
| PR Label Assigner | typescript-bun | opus46-200k | 8 | 30 | 3.8 | 189 | 121 | 1.56 |
| PR Label Assigner | typescript-bun | opus47-1m-high | 27 | 45 | 1.7 | 422 | 231 | 1.83 |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 16 | 24 | 1.5 | 198 | 135 | 1.47 |
| PR Label Assigner | typescript-bun | sonnet46-200k | 23 | 24 | 1.0 | 235 | 230 | 1.02 |
| Dependency License Checker | bash | haiku45-200k | 15 | 32 | 2.1 | 983 | 340 | 2.89 |
| Dependency License Checker | bash | opus46-200k | 21 | 52 | 2.5 | 168 | 456 | 0.37 |
| Dependency License Checker | bash | opus47-1m-high | 14 | 10 | 0.7 | 165 | 0 | 0.00 |
| Dependency License Checker | bash | opus47-1m-medium | 21 | 39 | 1.9 | 221 | 335 | 0.66 |
| Dependency License Checker | bash | sonnet46-200k | 18 | 55 | 3.1 | 269 | 211 | 1.27 |
| Dependency License Checker | default | haiku45-200k | 21 | 49 | 2.3 | 337 | 666 | 0.51 |
| Dependency License Checker | default | opus46-200k | 12 | 52 | 4.3 | 420 | 166 | 2.53 |
| Dependency License Checker | default | opus47-1m-high | 23 | 43 | 1.9 | 342 | 474 | 0.72 |
| Dependency License Checker | default | opus47-1m-medium | 26 | 62 | 2.4 | 531 | 261 | 2.03 |
| Dependency License Checker | default | sonnet46-200k | 36 | 57 | 1.6 | 386 | 492 | 0.78 |
| Dependency License Checker | powershell | haiku45-200k | 12 | 30 | 2.5 | 240 | 347 | 0.69 |
| Dependency License Checker | powershell | opus46-200k | 29 | 42 | 1.4 | 205 | 450 | 0.46 |
| Dependency License Checker | powershell | opus47-1m-high | 20 | 46 | 2.3 | 189 | 363 | 0.52 |
| Dependency License Checker | powershell | opus47-1m-medium | 10 | 32 | 3.2 | 184 | 285 | 0.65 |
| Dependency License Checker | powershell | sonnet46-200k | 32 | 49 | 1.5 | 284 | 370 | 0.77 |
| Dependency License Checker | powershell-tool | haiku45-200k | 10 | 31 | 3.1 | 187 | 414 | 0.45 |
| Dependency License Checker | powershell-tool | opus46-200k | 31 | 62 | 2.0 | 219 | 275 | 0.80 |
| Dependency License Checker | powershell-tool | opus47-1m-high | 40 | 65 | 1.6 | 419 | 283 | 1.48 |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 15 | 28 | 1.9 | 167 | 217 | 0.77 |
| Dependency License Checker | powershell-tool | sonnet46-200k | 33 | 43 | 1.3 | 232 | 287 | 0.81 |
| Dependency License Checker | typescript-bun | haiku45-200k | 14 | 33 | 2.4 | 227 | 346 | 0.66 |
| Dependency License Checker | typescript-bun | opus46-200k | 19 | 46 | 2.4 | 206 | 442 | 0.47 |
| Dependency License Checker | typescript-bun | opus47-1m-high | 26 | 42 | 1.6 | 547 | 271 | 2.02 |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 19 | 31 | 1.6 | 174 | 378 | 0.46 |
| Dependency License Checker | typescript-bun | sonnet46-200k | 29 | 68 | 2.3 | 362 | 186 | 1.95 |
| Test Results Aggregator | bash | haiku45-200k | 8 | 8 | 1.0 | 117 | 173 | 0.68 |
| Test Results Aggregator | bash | opus46-200k | 12 | 26 | 2.2 | 187 | 243 | 0.77 |
| Test Results Aggregator | bash | opus47-1m-high | 57 | 76 | 1.3 | 557 | 319 | 1.75 |
| Test Results Aggregator | bash | opus47-1m-medium | 7 | 30 | 4.3 | 115 | 149 | 0.77 |
| Test Results Aggregator | bash | sonnet46-200k | 16 | 17 | 1.1 | 149 | 317 | 0.47 |
| Test Results Aggregator | default | haiku45-200k | 5 | 26 | 5.2 | 176 | 257 | 0.68 |
| Test Results Aggregator | default | opus46-200k | 2 | 0 | 0.0 | 389 | 261 | 1.49 |
| Test Results Aggregator | default | opus47-1m-high | 29 | 62 | 2.1 | 628 | 339 | 1.85 |
| Test Results Aggregator | default | opus47-1m-medium | 13 | 27 | 2.1 | 191 | 397 | 0.48 |
| Test Results Aggregator | default | sonnet46-200k | 45 | 60 | 1.3 | 454 | 248 | 1.83 |
| Test Results Aggregator | powershell | haiku45-200k | 0 | 0 | 0.0 | 0 | 541 | 0.00 |
| Test Results Aggregator | powershell | opus46-200k | 59 | 63 | 1.1 | 358 | 412 | 0.87 |
| Test Results Aggregator | powershell | opus47-1m-high | 35 | 37 | 1.1 | 290 | 71 | 4.08 |
| Test Results Aggregator | powershell | opus47-1m-medium | 17 | 58 | 3.4 | 332 | 47 | 7.06 |
| Test Results Aggregator | powershell | sonnet46-200k | 47 | 53 | 1.1 | 311 | 209 | 1.49 |
| Test Results Aggregator | powershell-tool | haiku45-200k | 22 | 54 | 2.5 | 238 | 319 | 0.75 |
| Test Results Aggregator | powershell-tool | opus46-200k | 18 | 55 | 3.1 | 175 | 457 | 0.38 |
| Test Results Aggregator | powershell-tool | opus47-1m-high | 29 | 50 | 1.7 | 294 | 439 | 0.67 |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 24 | 73 | 3.0 | 391 | 39 | 10.03 |
| Test Results Aggregator | powershell-tool | sonnet46-200k | 43 | 67 | 1.6 | 353 | 285 | 1.24 |
| Test Results Aggregator | typescript-bun | haiku45-200k | 31 | 69 | 2.2 | 398 | 442 | 0.90 |
| Test Results Aggregator | typescript-bun | opus46-200k | 26 | 62 | 2.4 | 344 | 559 | 0.62 |
| Test Results Aggregator | typescript-bun | opus47-1m-high | 34 | 72 | 2.1 | 546 | 765 | 0.71 |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 26 | 49 | 1.9 | 403 | 317 | 1.27 |
| Test Results Aggregator | typescript-bun | sonnet46-200k | 61 | 87 | 1.4 | 625 | 453 | 1.38 |
| Environment Matrix Generator | bash | haiku45-200k | 14 | 3 | 0.2 | 212 | 130 | 1.63 |
| Environment Matrix Generator | bash | opus46-200k | 61 | 58 | 1.0 | 460 | 181 | 2.54 |
| Environment Matrix Generator | bash | opus47-1m-high | 22 | 36 | 1.6 | 271 | 315 | 0.86 |
| Environment Matrix Generator | bash | opus47-1m-medium | 15 | 25 | 1.7 | 118 | 181 | 0.65 |
| Environment Matrix Generator | bash | sonnet46-200k | 21 | 37 | 1.8 | 162 | 266 | 0.61 |
| Environment Matrix Generator | default | haiku45-200k | 19 | 41 | 2.2 | 522 | 184 | 2.84 |
| Environment Matrix Generator | default | opus46-200k | 4 | 29 | 7.2 | 301 | 349 | 0.86 |
| Environment Matrix Generator | default | opus47-1m-high | 25 | 53 | 2.1 | 526 | 194 | 2.71 |
| Environment Matrix Generator | default | opus47-1m-medium | 25 | 45 | 1.8 | 461 | 146 | 3.16 |
| Environment Matrix Generator | default | sonnet46-200k | 36 | 46 | 1.3 | 566 | 120 | 4.72 |
| Environment Matrix Generator | powershell | haiku45-200k | 8 | 15 | 1.9 | 146 | 179 | 0.82 |
| Environment Matrix Generator | powershell | opus46-200k | 66 | 69 | 1.0 | 452 | 115 | 3.93 |
| Environment Matrix Generator | powershell | opus47-1m-high | 16 | 25 | 1.6 | 218 | 260 | 0.84 |
| Environment Matrix Generator | powershell | opus47-1m-medium | 22 | 44 | 2.0 | 218 | 272 | 0.80 |
| Environment Matrix Generator | powershell | sonnet46-200k | 37 | 58 | 1.6 | 377 | 394 | 0.96 |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 12 | 25 | 2.1 | 193 | 137 | 1.41 |
| Environment Matrix Generator | powershell-tool | opus46-200k | 14 | 24 | 1.7 | 165 | 328 | 0.50 |
| Environment Matrix Generator | powershell-tool | opus47-1m-high | 30 | 53 | 1.8 | 320 | 549 | 0.58 |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 18 | 24 | 1.3 | 135 | 454 | 0.30 |
| Environment Matrix Generator | powershell-tool | sonnet46-200k | 31 | 42 | 1.4 | 322 | 389 | 0.83 |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 10 | 25 | 2.5 | 201 | 319 | 0.63 |
| Environment Matrix Generator | typescript-bun | opus46-200k | 14 | 40 | 2.9 | 266 | 176 | 1.51 |
| Environment Matrix Generator | typescript-bun | opus47-1m-high | 25 | 64 | 2.6 | 590 | 194 | 3.04 |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 17 | 32 | 1.9 | 324 | 162 | 2.00 |
| Environment Matrix Generator | typescript-bun | sonnet46-200k | 32 | 41 | 1.3 | 333 | 171 | 1.95 |
| Artifact Cleanup Script | bash | haiku45-200k | 12 | 28 | 2.3 | 166 | 369 | 0.45 |
| Artifact Cleanup Script | bash | opus46-200k | 23 | 86 | 3.7 | 216 | 546 | 0.40 |
| Artifact Cleanup Script | bash | opus47-1m-high | 27 | 76 | 2.8 | 275 | 363 | 0.76 |
| Artifact Cleanup Script | bash | opus47-1m-medium | 9 | 29 | 3.2 | 85 | 297 | 0.29 |
| Artifact Cleanup Script | bash | sonnet46-200k | 26 | 44 | 1.7 | 181 | 319 | 0.57 |
| Artifact Cleanup Script | default | haiku45-200k | 31 | 26 | 0.8 | 411 | 321 | 1.28 |
| Artifact Cleanup Script | default | opus46-200k | 2 | 0 | 0.0 | 420 | 335 | 1.25 |
| Artifact Cleanup Script | default | opus47-1m-high | 24 | 55 | 2.3 | 343 | 500 | 0.69 |
| Artifact Cleanup Script | default | opus47-1m-medium | 17 | 41 | 2.4 | 404 | 199 | 2.03 |
| Artifact Cleanup Script | default | sonnet46-200k | 13 | 44 | 3.4 | 359 | 283 | 1.27 |
| Artifact Cleanup Script | powershell | haiku45-200k | 11 | 24 | 2.2 | 185 | 279 | 0.66 |
| Artifact Cleanup Script | powershell | opus46-200k | 21 | 69 | 3.3 | 307 | 197 | 1.56 |
| Artifact Cleanup Script | powershell | opus47-1m-high | 11 | 38 | 3.5 | 210 | 557 | 0.38 |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 15 | 59 | 3.9 | 265 | 53 | 5.00 |
| Artifact Cleanup Script | powershell | sonnet46-200k | 49 | 68 | 1.4 | 473 | 246 | 1.92 |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 17 | 30 | 1.8 | 220 | 181 | 1.22 |
| Artifact Cleanup Script | powershell-tool | opus46-200k | 21 | 67 | 3.2 | 257 | 216 | 1.19 |
| Artifact Cleanup Script | powershell-tool | opus47-1m-high | 27 | 67 | 2.5 | 312 | 471 | 0.66 |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 14 | 28 | 2.0 | 169 | 374 | 0.45 |
| Artifact Cleanup Script | powershell-tool | sonnet46-200k | 13 | 33 | 2.5 | 194 | 258 | 0.75 |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 9 | 27 | 3.0 | 276 | 380 | 0.73 |
| Artifact Cleanup Script | typescript-bun | opus46-200k | 21 | 67 | 3.2 | 290 | 245 | 1.18 |
| Artifact Cleanup Script | typescript-bun | opus47-1m-high | 20 | 55 | 2.8 | 418 | 368 | 1.14 |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 14 | 37 | 2.6 | 269 | 213 | 1.26 |
| Artifact Cleanup Script | typescript-bun | sonnet46-200k | 23 | 55 | 2.4 | 259 | 452 | 0.57 |
| Secret Rotation Validator | bash | haiku45-200k | 15 | 32 | 2.1 | 134 | 453 | 0.30 |
| Secret Rotation Validator | bash | opus46-200k | 28 | 42 | 1.5 | 250 | 515 | 0.49 |
| Secret Rotation Validator | bash | opus47-1m-high | 26 | 3 | 0.1 | 140 | 49 | 2.86 |
| Secret Rotation Validator | bash | opus47-1m-medium | 22 | 37 | 1.7 | 266 | 207 | 1.29 |
| Secret Rotation Validator | bash | sonnet46-200k | 31 | 76 | 2.5 | 300 | 399 | 0.75 |
| Secret Rotation Validator | default | haiku45-200k | 13 | 38 | 2.9 | 270 | 505 | 0.53 |
| Secret Rotation Validator | default | opus46-200k | 44 | 86 | 2.0 | 816 | 255 | 3.20 |
| Secret Rotation Validator | default | opus47-1m-high | 25 | 59 | 2.4 | 577 | 304 | 1.90 |
| Secret Rotation Validator | default | opus47-1m-medium | 21 | 45 | 2.1 | 292 | 377 | 0.77 |
| Secret Rotation Validator | default | sonnet46-200k | 36 | 46 | 1.3 | 450 | 252 | 1.79 |
| Secret Rotation Validator | powershell | haiku45-200k | 0 | 0 | 0.0 | 0 | 590 | 0.00 |
| Secret Rotation Validator | powershell | opus46-200k | 23 | 46 | 2.0 | 215 | 231 | 0.93 |
| Secret Rotation Validator | powershell | opus47-1m-high | 29 | 63 | 2.2 | 327 | 235 | 1.39 |
| Secret Rotation Validator | powershell | opus47-1m-medium | 12 | 20 | 1.7 | 122 | 304 | 0.40 |
| Secret Rotation Validator | powershell | sonnet46-200k | 42 | 77 | 1.8 | 464 | 58 | 8.00 |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 0 | 0 | 0.0 | 0 | 375 | 0.00 |
| Secret Rotation Validator | powershell-tool | opus46-200k | 14 | 33 | 2.4 | 143 | 315 | 0.45 |
| Secret Rotation Validator | powershell-tool | opus47-1m-high | 18 | 47 | 2.6 | 229 | 302 | 0.76 |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 9 | 21 | 2.3 | 98 | 226 | 0.43 |
| Secret Rotation Validator | powershell-tool | sonnet46-200k | 34 | 64 | 1.9 | 321 | 311 | 1.03 |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 38 | 84 | 2.2 | 560 | 205 | 2.73 |
| Secret Rotation Validator | typescript-bun | opus46-200k | 27 | 79 | 2.9 | 305 | 583 | 0.52 |
| Secret Rotation Validator | typescript-bun | opus47-1m-high | 15 | 69 | 4.6 | 578 | 367 | 1.57 |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 16 | 35 | 2.2 | 347 | 261 | 1.33 |
| Secret Rotation Validator | typescript-bun | sonnet46-200k | 52 | 87 | 1.7 | 515 | 289 | 1.78 |
| Semantic Version Bumper | default | opus47-1m-xhigh | 40 | 70 | 1.8 | 514 | 288 | 1.78 |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 46 | 74 | 1.6 | 352 | 455 | 0.77 |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 38 | 65 | 1.7 | 440 | 319 | 1.38 |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 51 | 86 | 1.7 | 592 | 62 | 9.55 |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 33 | 70 | 2.1 | 523 | 284 | 1.84 |
| PR Label Assigner | default | opus47-1m-xhigh | 35 | 45 | 1.3 | 572 | 242 | 2.36 |
| PR Label Assigner | powershell | opus47-1m-xhigh | 0 | 0 | 0.0 | 0 | 634 | 0.00 |
| PR Label Assigner | bash | opus47-1m-xhigh | 10 | 21 | 2.1 | 210 | 156 | 1.35 |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 24 | 37 | 1.5 | 210 | 480 | 0.44 |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 18 | 33 | 1.8 | 466 | 272 | 1.71 |
| Dependency License Checker | default | opus47-1m-xhigh | 31 | 47 | 1.5 | 483 | 662 | 0.73 |
| Dependency License Checker | powershell | opus47-1m-xhigh | 44 | 66 | 1.5 | 336 | 372 | 0.90 |
| Dependency License Checker | bash | opus47-1m-xhigh | 13 | 32 | 2.5 | 158 | 232 | 0.68 |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 46 | 80 | 1.7 | 591 | 26 | 22.73 |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 21 | 35 | 1.7 | 556 | 353 | 1.58 |
| Test Results Aggregator | default | opus47-1m-xhigh | 24 | 64 | 2.7 | 391 | 669 | 0.58 |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 27 | 69 | 2.6 | 358 | 241 | 1.49 |
| Test Results Aggregator | bash | opus47-1m-xhigh | 28 | 106 | 3.8 | 306 | 400 | 0.77 |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 45 | 84 | 1.9 | 552 | 370 | 1.49 |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 26 | 68 | 2.6 | 597 | 480 | 1.24 |
| Environment Matrix Generator | default | opus47-1m-xhigh | 27 | 49 | 1.8 | 342 | 434 | 0.79 |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 26 | 29 | 1.1 | 228 | 453 | 0.50 |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 13 | 35 | 2.7 | 260 | 0 | 0.00 |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 22 | 31 | 1.4 | 258 | 524 | 0.49 |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 8 | 31 | 3.9 | 233 | 554 | 0.42 |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 23 | 57 | 2.5 | 357 | 579 | 0.62 |

</details>

## Per-Run Results

*Tests Quality = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Artifact Cleanup Script | bash | opus47-1m-high | 5.7min | 28 | 3 | $1.59 | — | bash | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 7.1min | 29 | 0 | $1.68 | — | bash | ok |
| Artifact Cleanup Script | bash | sonnet46-200k | 8.4min | 36 | 5 | $1.42 | — | bash | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Artifact Cleanup Script | default | opus47-1m-high | 8.1min | 40 | 0 | $2.68 | — | python | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 4.2min | 20 | 0 | $0.93 | — | python | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 11.7min | 60 | 1 | $3.89 | — | python | ok |
| Artifact Cleanup Script | default | sonnet46-200k | 11.5min | 39 | 3 | $1.55 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-high | 9.2min | 42 | 0 | $2.86 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.32 | — | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46-200k | 9.9min | 30 | 1 | $1.47 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus46-200k | 18.5min | 32 | 1 | $3.28 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-high | 12.0min | 60 | 2 | $3.90 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 6.0min | 26 | 0 | $1.65 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | sonnet46-200k | 7.0min | 26 | 1 | $1.08 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus46-200k | 5.0min | 35 | 2 | $1.19 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-high | 9.6min | 63 | 1 | $3.56 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 8.4min | 34 | 0 | $1.67 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46-200k | 8.3min | 38 | 2 | $1.40 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Dependency License Checker | bash | opus47-1m-high | 8.0min | 46 | 1 | $2.59 | — | bash | ok |
| Dependency License Checker | bash | opus47-1m-medium | 4.3min | 30 | 1 | $1.15 | — | bash | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 6.1min | 38 | 0 | $2.08 | — | bash | ok |
| Dependency License Checker | bash | sonnet46-200k | 11.9min | 53 | 7 | $1.90 | — | bash | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Dependency License Checker | default | opus47-1m-high | 7.3min | 38 | 0 | $2.05 | — | python | ok |
| Dependency License Checker | default | opus47-1m-medium | 7.7min | 35 | 0 | $1.76 | — | python | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 9.4min | 51 | 0 | $3.22 | — | python | ok |
| Dependency License Checker | default | sonnet46-200k | 9.0min | 41 | 4 | $1.53 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-high | 11.0min | 47 | 0 | $2.87 | — | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 5.5min | 19 | 0 | $1.09 | — | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 13.9min | 52 | 0 | $3.72 | — | powershell | ok |
| Dependency License Checker | powershell | sonnet46-200k | 7.2min | 29 | 3 | $1.13 | — | powershell | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-high | 7.3min | 28 | 0 | $1.62 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 5.5min | 30 | 1 | $1.47 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 12.7min | 46 | 0 | $3.88 | — | powershell | ok |
| Dependency License Checker | powershell-tool | sonnet46-200k | 5.0min | 27 | 0 | $0.68 | — | powershell | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-high | 8.3min | 49 | 0 | $2.01 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 4.1min | 24 | 0 | $0.99 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 16.4min | 75 | 0 | $4.47 | — | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet46-200k | 8.3min | 47 | 1 | $1.31 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-high | 20.6min | 57 | 0 | $3.39 | — | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.4min | 26 | 0 | $0.98 | — | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 10.7min | 43 | 2 | $3.05 | — | bash | ok |
| Environment Matrix Generator | bash | sonnet46-200k | 9.8min | 40 | 4 | $1.29 | — | bash | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Environment Matrix Generator | default | opus47-1m-high | 8.0min | 33 | 0 | $1.92 | — | python | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 31 | 0 | $1.33 | — | python | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 13.4min | 71 | 0 | $3.80 | — | python | ok |
| Environment Matrix Generator | default | sonnet46-200k | 6.8min | 46 | 4 | $1.28 | — | python | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-high | 10.5min | 33 | 0 | $2.66 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 8.0min | 40 | 1 | $2.14 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 9.2min | 35 | 1 | $2.57 | — | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46-200k | 15.1min | 53 | 7 | $2.98 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-high | 18.4min | 90 | 2 | $6.68 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 6.3min | 28 | 1 | $1.51 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 9.6min | 45 | 0 | $3.14 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | sonnet46-200k | 15.1min | 48 | 3 | $1.83 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-high | 8.1min | 48 | 0 | $2.51 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 4.3min | 35 | 1 | $1.21 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 39 | 1 | $2.84 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | sonnet46-200k | 10.2min | 49 | 3 | $1.46 | — | typescript | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |
| PR Label Assigner | bash | opus47-1m-high | 6.3min | 41 | 0 | $1.71 | — | bash | ok |
| PR Label Assigner | bash | opus47-1m-medium | 4.2min | 29 | 1 | $1.08 | — | bash | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 14.5min | 52 | 0 | $3.83 | — | bash | ok |
| PR Label Assigner | bash | sonnet46-200k | 13.4min | 47 | 5 | $2.21 | — | bash | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| PR Label Assigner | default | opus47-1m-high | 7.4min | 43 | 0 | $2.23 | — | python | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.0min | 19 | 0 | $0.85 | — | python | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 11.9min | 59 | 1 | $3.91 | — | python | ok |
| PR Label Assigner | default | sonnet46-200k | 11.4min | 45 | 4 | $1.66 | — | python | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-high | 15.3min | 51 | 1 | $3.83 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 8.7min | 57 | 2 | $2.56 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 11.3min | 56 | 2 | $3.56 | — | powershell | ok |
| PR Label Assigner | powershell | sonnet46-200k | 12.3min | 29 | 2 | $1.46 | — | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-high | 9.4min | 45 | 0 | $2.54 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 6.4min | 34 | 0 | $1.62 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 28.0min | 93 | 8 | $9.31 | — | powershell | timeout |
| PR Label Assigner | powershell-tool | sonnet46-200k | 11.8min | 38 | 3 | $1.76 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus47-1m-high | 6.2min | 36 | 1 | $1.85 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 4.0min | 26 | 0 | $1.02 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 12.1min | 64 | 0 | $3.19 | — | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet46-200k | 6.9min | 51 | 7 | $1.45 | — | typescript | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Secret Rotation Validator | bash | opus46-200k | 7.4min | 51 | 5 | $1.71 | — | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-high | 5.8min | 40 | 2 | $2.08 | — | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 4.8min | 24 | 0 | $1.17 | — | bash | ok |
| Secret Rotation Validator | bash | sonnet46-200k | 12.6min | 40 | 2 | $1.67 | — | bash | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| Secret Rotation Validator | default | opus46-200k | 8.3min | 34 | 5 | $2.04 | — | python | ok |
| Secret Rotation Validator | default | opus47-1m-high | 7.4min | 34 | 0 | $1.94 | — | python | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 4.0min | 26 | 1 | $1.26 | — | python | ok |
| Secret Rotation Validator | default | sonnet46-200k | 14.9min | 48 | 4 | $1.90 | — | python | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Secret Rotation Validator | powershell | opus46-200k | 7.2min | 51 | 0 | $1.78 | — | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-high | 7.6min | 40 | 0 | $2.32 | — | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 3.9min | 21 | 0 | $1.04 | — | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46-200k | 12.7min | 35 | 1 | $1.81 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus46-200k | 3.7min | 21 | 1 | $0.80 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-high | 10.5min | 36 | 0 | $2.51 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 3.9min | 23 | 0 | $1.06 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | sonnet46-200k | 10.3min | 33 | 3 | $1.28 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus46-200k | 8.9min | 24 | 1 | $1.51 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-high | 10.4min | 53 | 0 | $2.83 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 4.9min | 32 | 1 | $1.32 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet46-200k | 10.8min | 53 | 1 | $1.68 | — | typescript | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-high | 6.9min | 32 | 2 | $1.61 | — | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 3.8min | 26 | 1 | $1.06 | — | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 10.7min | 55 | 1 | $3.08 | — | bash | ok |
| Semantic Version Bumper | bash | sonnet46-200k | 5.7min | 30 | 1 | $0.88 | — | bash | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | default | opus47-1m-high | 7.2min | 29 | 0 | $2.10 | — | python | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.3min | 28 | 0 | $1.16 | — | python | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 7.6min | 37 | 0 | $2.10 | — | python | ok |
| Semantic Version Bumper | default | sonnet46-200k | 8.0min | 29 | 4 | $1.05 | — | python | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-high | 9.5min | 39 | 0 | $2.36 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.52 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 15.4min | 63 | 1 | $4.72 | — | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46-200k | 12.3min | 30 | 2 | $1.43 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-high | 7.8min | 40 | 0 | $2.59 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 3.6min | 21 | 0 | $0.82 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 9.3min | 46 | 0 | $2.72 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | sonnet46-200k | 12.7min | 42 | 0 | $1.92 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-high | 9.6min | 59 | 0 | $2.82 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.0min | 27 | 0 | $1.26 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 11.6min | 59 | 1 | $3.27 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet46-200k | 9.3min | 39 | 1 | $1.17 | — | typescript | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Test Results Aggregator | bash | opus47-1m-high | 20.0min | 74 | 3 | $4.92 | — | bash | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 3.6min | 25 | 1 | $1.01 | — | bash | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 9.6min | 60 | 4 | $3.39 | — | bash | ok |
| Test Results Aggregator | bash | sonnet46-200k | 17.4min | 52 | 4 | $1.97 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Test Results Aggregator | default | opus47-1m-high | 10.3min | 40 | 0 | $2.47 | — | python | ok |
| Test Results Aggregator | default | opus47-1m-medium | 3.8min | 21 | 0 | $1.00 | — | python | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 11.2min | 64 | 1 | $3.82 | — | python | ok |
| Test Results Aggregator | default | sonnet46-200k | 7.7min | 44 | 2 | $1.30 | — | python | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-high | 8.7min | 46 | 2 | $2.72 | — | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 11.2min | 40 | 0 | $2.26 | — | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 9.8min | 44 | 0 | $2.99 | — | powershell | ok |
| Test Results Aggregator | powershell | sonnet46-200k | 9.2min | 28 | 0 | $1.13 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-high | 17.3min | 79 | 1 | $5.01 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.3min | 44 | 0 | $2.68 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 12.4min | 57 | 0 | $3.99 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | sonnet46-200k | 12.8min | 39 | 0 | $1.70 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-high | 10.1min | 53 | 1 | $3.69 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 7.5min | 45 | 0 | $1.83 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 11.6min | 68 | 1 | $3.64 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet46-200k | 9.5min | 67 | 4 | $2.05 | — | typescript | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Dependency License Checker | powershell-tool | sonnet46-200k | 5.0min | 27 | 0 | $0.68 | — | powershell | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Secret Rotation Validator | powershell-tool | opus46-200k | 3.7min | 21 | 1 | $0.80 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 3.6min | 21 | 0 | $0.82 | — | powershell | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.0min | 19 | 0 | $0.85 | — | python | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Semantic Version Bumper | bash | sonnet46-200k | 5.7min | 30 | 1 | $0.88 | — | bash | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 4.2min | 20 | 0 | $0.93 | — | python | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.4min | 26 | 0 | $0.98 | — | bash | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 4.1min | 24 | 0 | $0.99 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| Test Results Aggregator | default | opus47-1m-medium | 3.8min | 21 | 0 | $1.00 | — | python | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 3.6min | 25 | 1 | $1.01 | — | bash | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 4.0min | 26 | 0 | $1.02 | — | typescript | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 3.9min | 21 | 0 | $1.04 | — | powershell | ok |
| Semantic Version Bumper | default | sonnet46-200k | 8.0min | 29 | 4 | $1.05 | — | python | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 3.9min | 23 | 0 | $1.06 | — | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 3.8min | 26 | 1 | $1.06 | — | bash | ok |
| Artifact Cleanup Script | powershell-tool | sonnet46-200k | 7.0min | 26 | 1 | $1.08 | — | powershell | ok |
| PR Label Assigner | bash | opus47-1m-medium | 4.2min | 29 | 1 | $1.08 | — | bash | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 5.5min | 19 | 0 | $1.09 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Dependency License Checker | powershell | sonnet46-200k | 7.2min | 29 | 3 | $1.13 | — | powershell | ok |
| Test Results Aggregator | powershell | sonnet46-200k | 9.2min | 28 | 0 | $1.13 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Dependency License Checker | bash | opus47-1m-medium | 4.3min | 30 | 1 | $1.15 | — | bash | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.3min | 28 | 0 | $1.16 | — | python | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | sonnet46-200k | 9.3min | 39 | 1 | $1.17 | — | typescript | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 4.8min | 24 | 0 | $1.17 | — | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus46-200k | 5.0min | 35 | 2 | $1.19 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 4.3min | 35 | 1 | $1.21 | — | typescript | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.0min | 27 | 0 | $1.26 | — | typescript | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 4.0min | 26 | 1 | $1.26 | — | python | ok |
| Environment Matrix Generator | default | sonnet46-200k | 6.8min | 46 | 4 | $1.28 | — | python | ok |
| Secret Rotation Validator | powershell-tool | sonnet46-200k | 10.3min | 33 | 3 | $1.28 | — | powershell | ok |
| Environment Matrix Generator | bash | sonnet46-200k | 9.8min | 40 | 4 | $1.29 | — | bash | ok |
| Test Results Aggregator | default | sonnet46-200k | 7.7min | 44 | 2 | $1.30 | — | python | ok |
| Dependency License Checker | typescript-bun | sonnet46-200k | 8.3min | 47 | 1 | $1.31 | — | typescript | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.32 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 4.9min | 32 | 1 | $1.32 | — | typescript | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 31 | 0 | $1.33 | — | python | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46-200k | 8.3min | 38 | 2 | $1.40 | — | typescript | ok |
| Artifact Cleanup Script | bash | sonnet46-200k | 8.4min | 36 | 5 | $1.42 | — | bash | ok |
| Semantic Version Bumper | powershell | sonnet46-200k | 12.3min | 30 | 2 | $1.43 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet46-200k | 6.9min | 51 | 7 | $1.45 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | sonnet46-200k | 10.2min | 49 | 3 | $1.46 | — | typescript | ok |
| PR Label Assigner | powershell | sonnet46-200k | 12.3min | 29 | 2 | $1.46 | — | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46-200k | 9.9min | 30 | 1 | $1.47 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 5.5min | 30 | 1 | $1.47 | — | powershell | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 6.3min | 28 | 1 | $1.51 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus46-200k | 8.9min | 24 | 1 | $1.51 | — | typescript | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.52 | — | powershell | ok |
| Dependency License Checker | default | sonnet46-200k | 9.0min | 41 | 4 | $1.53 | — | python | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Artifact Cleanup Script | default | sonnet46-200k | 11.5min | 39 | 3 | $1.55 | — | python | ok |
| Artifact Cleanup Script | bash | opus47-1m-high | 5.7min | 28 | 3 | $1.59 | — | bash | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Semantic Version Bumper | bash | opus47-1m-high | 6.9min | 32 | 2 | $1.61 | — | bash | ok |
| Dependency License Checker | powershell-tool | opus47-1m-high | 7.3min | 28 | 0 | $1.62 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 6.4min | 34 | 0 | $1.62 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 6.0min | 26 | 0 | $1.65 | — | powershell | ok |
| PR Label Assigner | default | sonnet46-200k | 11.4min | 45 | 4 | $1.66 | — | python | ok |
| Secret Rotation Validator | bash | sonnet46-200k | 12.6min | 40 | 2 | $1.67 | — | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 8.4min | 34 | 0 | $1.67 | — | typescript | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| Secret Rotation Validator | typescript-bun | sonnet46-200k | 10.8min | 53 | 1 | $1.68 | — | typescript | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 7.1min | 29 | 0 | $1.68 | — | bash | ok |
| Test Results Aggregator | powershell-tool | sonnet46-200k | 12.8min | 39 | 0 | $1.70 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| PR Label Assigner | bash | opus47-1m-high | 6.3min | 41 | 0 | $1.71 | — | bash | ok |
| Secret Rotation Validator | bash | opus46-200k | 7.4min | 51 | 5 | $1.71 | — | bash | ok |
| PR Label Assigner | powershell-tool | sonnet46-200k | 11.8min | 38 | 3 | $1.76 | — | powershell | ok |
| Dependency License Checker | default | opus47-1m-medium | 7.7min | 35 | 0 | $1.76 | — | python | ok |
| Secret Rotation Validator | powershell | opus46-200k | 7.2min | 51 | 0 | $1.78 | — | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46-200k | 12.7min | 35 | 1 | $1.81 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | sonnet46-200k | 15.1min | 48 | 3 | $1.83 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 7.5min | 45 | 0 | $1.83 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus47-1m-high | 6.2min | 36 | 1 | $1.85 | — | typescript | ok |
| Secret Rotation Validator | default | sonnet46-200k | 14.9min | 48 | 4 | $1.90 | — | python | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |
| Dependency License Checker | bash | sonnet46-200k | 11.9min | 53 | 7 | $1.90 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | sonnet46-200k | 12.7min | 42 | 0 | $1.92 | — | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-high | 8.0min | 33 | 0 | $1.92 | — | python | ok |
| Secret Rotation Validator | default | opus47-1m-high | 7.4min | 34 | 0 | $1.94 | — | python | ok |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| Test Results Aggregator | bash | sonnet46-200k | 17.4min | 52 | 4 | $1.97 | — | bash | ok |
| Dependency License Checker | typescript-bun | opus47-1m-high | 8.3min | 49 | 0 | $2.01 | — | typescript | ok |
| Secret Rotation Validator | default | opus46-200k | 8.3min | 34 | 5 | $2.04 | — | python | ok |
| Dependency License Checker | default | opus47-1m-high | 7.3min | 38 | 0 | $2.05 | — | python | ok |
| Test Results Aggregator | typescript-bun | sonnet46-200k | 9.5min | 67 | 4 | $2.05 | — | typescript | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 6.1min | 38 | 0 | $2.08 | — | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-high | 5.8min | 40 | 2 | $2.08 | — | bash | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 7.6min | 37 | 0 | $2.10 | — | python | ok |
| Semantic Version Bumper | default | opus47-1m-high | 7.2min | 29 | 0 | $2.10 | — | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 8.0min | 40 | 1 | $2.14 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| PR Label Assigner | bash | sonnet46-200k | 13.4min | 47 | 5 | $2.21 | — | bash | ok |
| PR Label Assigner | default | opus47-1m-high | 7.4min | 43 | 0 | $2.23 | — | python | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 11.2min | 40 | 0 | $2.26 | — | powershell | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-high | 7.6min | 40 | 0 | $2.32 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-high | 9.5min | 39 | 0 | $2.36 | — | powershell | ok |
| Test Results Aggregator | default | opus47-1m-high | 10.3min | 40 | 0 | $2.47 | — | python | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-high | 8.1min | 48 | 0 | $2.51 | — | typescript | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-high | 10.5min | 36 | 0 | $2.51 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-high | 9.4min | 45 | 0 | $2.54 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 8.7min | 57 | 2 | $2.56 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 9.2min | 35 | 1 | $2.57 | — | powershell | ok |
| Dependency License Checker | bash | opus47-1m-high | 8.0min | 46 | 1 | $2.59 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-high | 7.8min | 40 | 0 | $2.59 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-high | 10.5min | 33 | 0 | $2.66 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.3min | 44 | 0 | $2.68 | — | powershell | ok |
| Artifact Cleanup Script | default | opus47-1m-high | 8.1min | 40 | 0 | $2.68 | — | python | ok |
| Test Results Aggregator | powershell | opus47-1m-high | 8.7min | 46 | 2 | $2.72 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 9.3min | 46 | 0 | $2.72 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-high | 9.6min | 59 | 0 | $2.82 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-high | 10.4min | 53 | 0 | $2.83 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 39 | 1 | $2.84 | — | typescript | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-high | 9.2min | 42 | 0 | $2.86 | — | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-high | 11.0min | 47 | 0 | $2.87 | — | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46-200k | 15.1min | 53 | 7 | $2.98 | — | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 9.8min | 44 | 0 | $2.99 | — | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 10.7min | 43 | 2 | $3.05 | — | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 10.7min | 55 | 1 | $3.08 | — | bash | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 9.6min | 45 | 0 | $3.14 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 12.1min | 64 | 0 | $3.19 | — | typescript | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 9.4min | 51 | 0 | $3.22 | — | python | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 11.6min | 59 | 1 | $3.27 | — | typescript | ok |
| Artifact Cleanup Script | powershell-tool | opus46-200k | 18.5min | 32 | 1 | $3.28 | — | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-high | 20.6min | 57 | 0 | $3.39 | — | bash | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 9.6min | 60 | 4 | $3.39 | — | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-high | 9.6min | 63 | 1 | $3.56 | — | typescript | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 11.3min | 56 | 2 | $3.56 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 11.6min | 68 | 1 | $3.64 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-high | 10.1min | 53 | 1 | $3.69 | — | typescript | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 13.9min | 52 | 0 | $3.72 | — | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 13.4min | 71 | 0 | $3.80 | — | python | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 11.2min | 64 | 1 | $3.82 | — | python | ok |
| PR Label Assigner | powershell | opus47-1m-high | 15.3min | 51 | 1 | $3.83 | — | powershell | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 14.5min | 52 | 0 | $3.83 | — | bash | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 12.7min | 46 | 0 | $3.88 | — | powershell | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 11.7min | 60 | 1 | $3.89 | — | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-high | 12.0min | 60 | 2 | $3.90 | — | powershell | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 11.9min | 59 | 1 | $3.91 | — | python | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 12.4min | 57 | 0 | $3.99 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 16.4min | 75 | 0 | $4.47 | — | typescript | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 15.4min | 63 | 1 | $4.72 | — | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-high | 20.0min | 74 | 3 | $4.92 | — | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-high | 17.3min | 79 | 1 | $5.01 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-high | 18.4min | 90 | 2 | $6.68 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 28.0min | 93 | 8 | $9.31 | — | powershell | timeout |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | default | opus47-1m-medium | 3.0min | 19 | 0 | $0.85 | — | python | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.4min | 26 | 0 | $0.98 | — | bash | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 3.6min | 25 | 1 | $1.01 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 3.6min | 21 | 0 | $0.82 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus46-200k | 3.7min | 21 | 1 | $0.80 | — | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 3.8min | 26 | 1 | $1.06 | — | bash | ok |
| Test Results Aggregator | default | opus47-1m-medium | 3.8min | 21 | 0 | $1.00 | — | python | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 3.9min | 21 | 0 | $1.04 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 3.9min | 23 | 0 | $1.06 | — | powershell | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 4.0min | 26 | 1 | $1.26 | — | python | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 4.0min | 26 | 0 | $1.02 | — | typescript | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 4.1min | 24 | 0 | $0.99 | — | typescript | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 4.2min | 20 | 0 | $0.93 | — | python | ok |
| PR Label Assigner | bash | opus47-1m-medium | 4.2min | 29 | 1 | $1.08 | — | bash | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.3min | 28 | 0 | $1.16 | — | python | ok |
| Dependency License Checker | bash | opus47-1m-medium | 4.3min | 30 | 1 | $1.15 | — | bash | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 4.3min | 35 | 1 | $1.21 | — | typescript | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 4.8min | 24 | 0 | $1.17 | — | bash | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 4.9min | 32 | 1 | $1.32 | — | typescript | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Dependency License Checker | powershell-tool | sonnet46-200k | 5.0min | 27 | 0 | $0.68 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.0min | 27 | 0 | $1.26 | — | typescript | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Artifact Cleanup Script | typescript-bun | opus46-200k | 5.0min | 35 | 2 | $1.19 | — | typescript | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 31 | 0 | $1.33 | — | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 5.5min | 30 | 1 | $1.47 | — | powershell | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 5.5min | 19 | 0 | $1.09 | — | powershell | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | bash | sonnet46-200k | 5.7min | 30 | 1 | $0.88 | — | bash | ok |
| Artifact Cleanup Script | bash | opus47-1m-high | 5.7min | 28 | 3 | $1.59 | — | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-high | 5.8min | 40 | 2 | $2.08 | — | bash | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.52 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 6.0min | 26 | 0 | $1.65 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.32 | — | powershell | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 6.1min | 38 | 0 | $2.08 | — | bash | ok |
| PR Label Assigner | typescript-bun | opus47-1m-high | 6.2min | 36 | 1 | $1.85 | — | typescript | ok |
| PR Label Assigner | bash | opus47-1m-high | 6.3min | 41 | 0 | $1.71 | — | bash | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 6.3min | 28 | 1 | $1.51 | — | powershell | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 6.4min | 34 | 0 | $1.62 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |
| Environment Matrix Generator | default | sonnet46-200k | 6.8min | 46 | 4 | $1.28 | — | python | ok |
| Semantic Version Bumper | bash | opus47-1m-high | 6.9min | 32 | 2 | $1.61 | — | bash | ok |
| PR Label Assigner | typescript-bun | sonnet46-200k | 6.9min | 51 | 7 | $1.45 | — | typescript | ok |
| Artifact Cleanup Script | powershell-tool | sonnet46-200k | 7.0min | 26 | 1 | $1.08 | — | powershell | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 7.1min | 29 | 0 | $1.68 | — | bash | ok |
| Dependency License Checker | powershell | sonnet46-200k | 7.2min | 29 | 3 | $1.13 | — | powershell | ok |
| Semantic Version Bumper | default | opus47-1m-high | 7.2min | 29 | 0 | $2.10 | — | python | ok |
| Secret Rotation Validator | powershell | opus46-200k | 7.2min | 51 | 0 | $1.78 | — | powershell | ok |
| Dependency License Checker | default | opus47-1m-high | 7.3min | 38 | 0 | $2.05 | — | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m-high | 7.3min | 28 | 0 | $1.62 | — | powershell | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Secret Rotation Validator | default | opus47-1m-high | 7.4min | 34 | 0 | $1.94 | — | python | ok |
| Secret Rotation Validator | bash | opus46-200k | 7.4min | 51 | 5 | $1.71 | — | bash | ok |
| PR Label Assigner | default | opus47-1m-high | 7.4min | 43 | 0 | $2.23 | — | python | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 7.5min | 45 | 0 | $1.83 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-high | 7.6min | 40 | 0 | $2.32 | — | powershell | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 7.6min | 37 | 0 | $2.10 | — | python | ok |
| Test Results Aggregator | default | sonnet46-200k | 7.7min | 44 | 2 | $1.30 | — | python | ok |
| Dependency License Checker | default | opus47-1m-medium | 7.7min | 35 | 0 | $1.76 | — | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-high | 7.8min | 40 | 0 | $2.59 | — | powershell | ok |
| Semantic Version Bumper | default | sonnet46-200k | 8.0min | 29 | 4 | $1.05 | — | python | ok |
| Dependency License Checker | bash | opus47-1m-high | 8.0min | 46 | 1 | $2.59 | — | bash | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 8.0min | 40 | 1 | $2.14 | — | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-high | 8.0min | 33 | 0 | $1.92 | — | python | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-high | 8.1min | 48 | 0 | $2.51 | — | typescript | ok |
| Artifact Cleanup Script | default | opus47-1m-high | 8.1min | 40 | 0 | $2.68 | — | python | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46-200k | 8.3min | 38 | 2 | $1.40 | — | typescript | ok |
| Secret Rotation Validator | default | opus46-200k | 8.3min | 34 | 5 | $2.04 | — | python | ok |
| Dependency License Checker | typescript-bun | opus47-1m-high | 8.3min | 49 | 0 | $2.01 | — | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet46-200k | 8.3min | 47 | 1 | $1.31 | — | typescript | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Artifact Cleanup Script | bash | sonnet46-200k | 8.4min | 36 | 5 | $1.42 | — | bash | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 8.4min | 34 | 0 | $1.67 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 8.7min | 57 | 2 | $2.56 | — | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-high | 8.7min | 46 | 2 | $2.72 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus46-200k | 8.9min | 24 | 1 | $1.51 | — | typescript | ok |
| Dependency License Checker | default | sonnet46-200k | 9.0min | 41 | 4 | $1.53 | — | python | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| Artifact Cleanup Script | powershell | opus47-1m-high | 9.2min | 42 | 0 | $2.86 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 9.2min | 35 | 1 | $2.57 | — | powershell | ok |
| Test Results Aggregator | powershell | sonnet46-200k | 9.2min | 28 | 0 | $1.13 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet46-200k | 9.3min | 39 | 1 | $1.17 | — | typescript | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 9.3min | 46 | 0 | $2.72 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.3min | 44 | 0 | $2.68 | — | powershell | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 9.4min | 51 | 0 | $3.22 | — | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m-high | 9.4min | 45 | 0 | $2.54 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-high | 9.5min | 39 | 0 | $2.36 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | sonnet46-200k | 9.5min | 67 | 4 | $2.05 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-high | 9.6min | 59 | 0 | $2.82 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-high | 9.6min | 63 | 1 | $3.56 | — | typescript | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 9.6min | 45 | 0 | $3.14 | — | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 9.6min | 60 | 4 | $3.39 | — | bash | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 39 | 1 | $2.84 | — | typescript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Environment Matrix Generator | bash | sonnet46-200k | 9.8min | 40 | 4 | $1.29 | — | bash | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 9.8min | 44 | 0 | $2.99 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46-200k | 9.9min | 30 | 1 | $1.47 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-high | 10.1min | 53 | 1 | $3.69 | — | typescript | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | sonnet46-200k | 10.2min | 49 | 3 | $1.46 | — | typescript | ok |
| Test Results Aggregator | default | opus47-1m-high | 10.3min | 40 | 0 | $2.47 | — | python | ok |
| Secret Rotation Validator | powershell-tool | sonnet46-200k | 10.3min | 33 | 3 | $1.28 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-high | 10.4min | 53 | 0 | $2.83 | — | typescript | ok |
| Environment Matrix Generator | powershell | opus47-1m-high | 10.5min | 33 | 0 | $2.66 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-high | 10.5min | 36 | 0 | $2.51 | — | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 10.7min | 55 | 1 | $3.08 | — | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 10.7min | 43 | 2 | $3.05 | — | bash | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | sonnet46-200k | 10.8min | 53 | 1 | $1.68 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Dependency License Checker | powershell | opus47-1m-high | 11.0min | 47 | 0 | $2.87 | — | powershell | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 11.2min | 64 | 1 | $3.82 | — | python | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 11.2min | 40 | 0 | $2.26 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 11.3min | 56 | 2 | $3.56 | — | powershell | ok |
| PR Label Assigner | default | sonnet46-200k | 11.4min | 45 | 4 | $1.66 | — | python | ok |
| Artifact Cleanup Script | default | sonnet46-200k | 11.5min | 39 | 3 | $1.55 | — | python | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 11.6min | 68 | 1 | $3.64 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 11.6min | 59 | 1 | $3.27 | — | typescript | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 11.7min | 60 | 1 | $3.89 | — | python | ok |
| PR Label Assigner | powershell-tool | sonnet46-200k | 11.8min | 38 | 3 | $1.76 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Dependency License Checker | bash | sonnet46-200k | 11.9min | 53 | 7 | $1.90 | — | bash | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 11.9min | 59 | 1 | $3.91 | — | python | ok |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-high | 12.0min | 60 | 2 | $3.90 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 12.1min | 64 | 0 | $3.19 | — | typescript | ok |
| PR Label Assigner | powershell | sonnet46-200k | 12.3min | 29 | 2 | $1.46 | — | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46-200k | 12.3min | 30 | 2 | $1.43 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 12.4min | 57 | 0 | $3.99 | — | powershell | ok |
| Secret Rotation Validator | bash | sonnet46-200k | 12.6min | 40 | 2 | $1.67 | — | bash | ok |
| Secret Rotation Validator | powershell | sonnet46-200k | 12.7min | 35 | 1 | $1.81 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | sonnet46-200k | 12.7min | 42 | 0 | $1.92 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 12.7min | 46 | 0 | $3.88 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | sonnet46-200k | 12.8min | 39 | 0 | $1.70 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 13.4min | 71 | 0 | $3.80 | — | python | ok |
| PR Label Assigner | bash | sonnet46-200k | 13.4min | 47 | 5 | $2.21 | — | bash | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 13.9min | 52 | 0 | $3.72 | — | powershell | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 14.5min | 52 | 0 | $3.83 | — | bash | ok |
| Secret Rotation Validator | default | sonnet46-200k | 14.9min | 48 | 4 | $1.90 | — | python | ok |
| Environment Matrix Generator | powershell | sonnet46-200k | 15.1min | 53 | 7 | $2.98 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | sonnet46-200k | 15.1min | 48 | 3 | $1.83 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-high | 15.3min | 51 | 1 | $3.83 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 15.4min | 63 | 1 | $4.72 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 16.4min | 75 | 0 | $4.47 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-high | 17.3min | 79 | 1 | $5.01 | — | powershell | ok |
| Test Results Aggregator | bash | sonnet46-200k | 17.4min | 52 | 4 | $1.97 | — | bash | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-high | 18.4min | 90 | 2 | $6.68 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus46-200k | 18.5min | 32 | 1 | $3.28 | — | powershell | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Test Results Aggregator | bash | opus47-1m-high | 20.0min | 74 | 3 | $4.92 | — | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-high | 20.6min | 57 | 0 | $3.39 | — | bash | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 28.0min | 93 | 8 | $9.31 | — | powershell | timeout |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Semantic Version Bumper | default | opus47-1m-high | 7.2min | 29 | 0 | $2.10 | — | python | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.3min | 28 | 0 | $1.16 | — | python | ok |
| Semantic Version Bumper | powershell | opus47-1m-high | 9.5min | 39 | 0 | $2.36 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.52 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-high | 7.8min | 40 | 0 | $2.59 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 3.6min | 21 | 0 | $0.82 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | sonnet46-200k | 12.7min | 42 | 0 | $1.92 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-high | 9.6min | 59 | 0 | $2.82 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.0min | 27 | 0 | $1.26 | — | typescript | ok |
| PR Label Assigner | bash | opus47-1m-high | 6.3min | 41 | 0 | $1.71 | — | bash | ok |
| PR Label Assigner | default | opus47-1m-high | 7.4min | 43 | 0 | $2.23 | — | python | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.0min | 19 | 0 | $0.85 | — | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m-high | 9.4min | 45 | 0 | $2.54 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 6.4min | 34 | 0 | $1.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 4.0min | 26 | 0 | $1.02 | — | typescript | ok |
| Dependency License Checker | default | opus47-1m-high | 7.3min | 38 | 0 | $2.05 | — | python | ok |
| Dependency License Checker | default | opus47-1m-medium | 7.7min | 35 | 0 | $1.76 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-high | 11.0min | 47 | 0 | $2.87 | — | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 5.5min | 19 | 0 | $1.09 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-high | 7.3min | 28 | 0 | $1.62 | — | powershell | ok |
| Dependency License Checker | powershell-tool | sonnet46-200k | 5.0min | 27 | 0 | $0.68 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-high | 8.3min | 49 | 0 | $2.01 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 4.1min | 24 | 0 | $0.99 | — | typescript | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Test Results Aggregator | default | opus47-1m-high | 10.3min | 40 | 0 | $2.47 | — | python | ok |
| Test Results Aggregator | default | opus47-1m-medium | 3.8min | 21 | 0 | $1.00 | — | python | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 11.2min | 40 | 0 | $2.26 | — | powershell | ok |
| Test Results Aggregator | powershell | sonnet46-200k | 9.2min | 28 | 0 | $1.13 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.3min | 44 | 0 | $2.68 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | sonnet46-200k | 12.8min | 39 | 0 | $1.70 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 7.5min | 45 | 0 | $1.83 | — | typescript | ok |
| Environment Matrix Generator | bash | opus47-1m-high | 20.6min | 57 | 0 | $3.39 | — | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.4min | 26 | 0 | $0.98 | — | bash | ok |
| Environment Matrix Generator | default | opus47-1m-high | 8.0min | 33 | 0 | $1.92 | — | python | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 31 | 0 | $1.33 | — | python | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-high | 10.5min | 33 | 0 | $2.66 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-high | 8.1min | 48 | 0 | $2.51 | — | typescript | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 7.1min | 29 | 0 | $1.68 | — | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-high | 8.1min | 40 | 0 | $2.68 | — | python | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 4.2min | 20 | 0 | $0.93 | — | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m-high | 9.2min | 42 | 0 | $2.86 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.32 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 6.0min | 26 | 0 | $1.65 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 8.4min | 34 | 0 | $1.67 | — | typescript | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 4.8min | 24 | 0 | $1.17 | — | bash | ok |
| Secret Rotation Validator | default | opus47-1m-high | 7.4min | 34 | 0 | $1.94 | — | python | ok |
| Secret Rotation Validator | powershell | opus46-200k | 7.2min | 51 | 0 | $1.78 | — | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-high | 7.6min | 40 | 0 | $2.32 | — | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 3.9min | 21 | 0 | $1.04 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-high | 10.5min | 36 | 0 | $2.51 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 3.9min | 23 | 0 | $1.06 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-high | 10.4min | 53 | 0 | $2.83 | — | typescript | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 7.6min | 37 | 0 | $2.10 | — | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 9.3min | 46 | 0 | $2.72 | — | powershell | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 14.5min | 52 | 0 | $3.83 | — | bash | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 12.1min | 64 | 0 | $3.19 | — | typescript | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 9.4min | 51 | 0 | $3.22 | — | python | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 13.9min | 52 | 0 | $3.72 | — | powershell | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 6.1min | 38 | 0 | $2.08 | — | bash | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 12.7min | 46 | 0 | $3.88 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 16.4min | 75 | 0 | $4.47 | — | typescript | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 9.8min | 44 | 0 | $2.99 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 12.4min | 57 | 0 | $3.99 | — | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 13.4min | 71 | 0 | $3.80 | — | python | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 9.6min | 45 | 0 | $3.14 | — | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 3.8min | 26 | 1 | $1.06 | — | bash | ok |
| Semantic Version Bumper | bash | sonnet46-200k | 5.7min | 30 | 1 | $0.88 | — | bash | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet46-200k | 9.3min | 39 | 1 | $1.17 | — | typescript | ok |
| PR Label Assigner | bash | opus47-1m-medium | 4.2min | 29 | 1 | $1.08 | — | bash | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-high | 15.3min | 51 | 1 | $3.83 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-high | 6.2min | 36 | 1 | $1.85 | — | typescript | ok |
| Dependency License Checker | bash | opus47-1m-high | 8.0min | 46 | 1 | $2.59 | — | bash | ok |
| Dependency License Checker | bash | opus47-1m-medium | 4.3min | 30 | 1 | $1.15 | — | bash | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 5.5min | 30 | 1 | $1.47 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet46-200k | 8.3min | 47 | 1 | $1.31 | — | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 3.6min | 25 | 1 | $1.01 | — | bash | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-high | 17.3min | 79 | 1 | $5.01 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-high | 10.1min | 53 | 1 | $3.69 | — | typescript | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 8.0min | 40 | 1 | $2.14 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 6.3min | 28 | 1 | $1.51 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 4.3min | 35 | 1 | $1.21 | — | typescript | ok |
| Artifact Cleanup Script | powershell | sonnet46-200k | 9.9min | 30 | 1 | $1.47 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus46-200k | 18.5min | 32 | 1 | $3.28 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | sonnet46-200k | 7.0min | 26 | 1 | $1.08 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-high | 9.6min | 63 | 1 | $3.56 | — | typescript | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 4.0min | 26 | 1 | $1.26 | — | python | ok |
| Secret Rotation Validator | powershell | sonnet46-200k | 12.7min | 35 | 1 | $1.81 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus46-200k | 3.7min | 21 | 1 | $0.80 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus46-200k | 8.9min | 24 | 1 | $1.51 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 4.9min | 32 | 1 | $1.32 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet46-200k | 10.8min | 53 | 1 | $1.68 | — | typescript | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 15.4min | 63 | 1 | $4.72 | — | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 10.7min | 55 | 1 | $3.08 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 11.6min | 59 | 1 | $3.27 | — | typescript | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 11.9min | 59 | 1 | $3.91 | — | python | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 11.2min | 64 | 1 | $3.82 | — | python | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 11.6min | 68 | 1 | $3.64 | — | typescript | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 9.2min | 35 | 1 | $2.57 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 39 | 1 | $2.84 | — | typescript | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 11.7min | 60 | 1 | $3.89 | — | python | ok |
| Semantic Version Bumper | bash | opus47-1m-high | 6.9min | 32 | 2 | $1.61 | — | bash | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46-200k | 12.3min | 30 | 2 | $1.43 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 8.7min | 57 | 2 | $2.56 | — | powershell | ok |
| PR Label Assigner | powershell | sonnet46-200k | 12.3min | 29 | 2 | $1.46 | — | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Test Results Aggregator | default | sonnet46-200k | 7.7min | 44 | 2 | $1.30 | — | python | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-high | 8.7min | 46 | 2 | $2.72 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-high | 18.4min | 90 | 2 | $6.68 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-high | 12.0min | 60 | 2 | $3.90 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus46-200k | 5.0min | 35 | 2 | $1.19 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46-200k | 8.3min | 38 | 2 | $1.40 | — | typescript | ok |
| Secret Rotation Validator | bash | opus47-1m-high | 5.8min | 40 | 2 | $2.08 | — | bash | ok |
| Secret Rotation Validator | bash | sonnet46-200k | 12.6min | 40 | 2 | $1.67 | — | bash | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 11.3min | 56 | 2 | $3.56 | — | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 10.7min | 43 | 2 | $3.05 | — | bash | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| PR Label Assigner | powershell-tool | sonnet46-200k | 11.8min | 38 | 3 | $1.76 | — | powershell | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Dependency License Checker | powershell | sonnet46-200k | 7.2min | 29 | 3 | $1.13 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-high | 20.0min | 74 | 3 | $4.92 | — | bash | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | sonnet46-200k | 15.1min | 48 | 3 | $1.83 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | sonnet46-200k | 10.2min | 49 | 3 | $1.46 | — | typescript | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Artifact Cleanup Script | bash | opus47-1m-high | 5.7min | 28 | 3 | $1.59 | — | bash | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Artifact Cleanup Script | default | sonnet46-200k | 11.5min | 39 | 3 | $1.55 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | sonnet46-200k | 10.3min | 33 | 3 | $1.28 | — | powershell | ok |
| Semantic Version Bumper | default | sonnet46-200k | 8.0min | 29 | 4 | $1.05 | — | python | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| PR Label Assigner | default | sonnet46-200k | 11.4min | 45 | 4 | $1.66 | — | python | ok |
| Dependency License Checker | default | sonnet46-200k | 9.0min | 41 | 4 | $1.53 | — | python | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Test Results Aggregator | bash | sonnet46-200k | 17.4min | 52 | 4 | $1.97 | — | bash | ok |
| Test Results Aggregator | typescript-bun | sonnet46-200k | 9.5min | 67 | 4 | $2.05 | — | typescript | ok |
| Environment Matrix Generator | bash | sonnet46-200k | 9.8min | 40 | 4 | $1.29 | — | bash | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Environment Matrix Generator | default | sonnet46-200k | 6.8min | 46 | 4 | $1.28 | — | python | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Secret Rotation Validator | default | sonnet46-200k | 14.9min | 48 | 4 | $1.90 | — | python | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 9.6min | 60 | 4 | $3.39 | — | bash | ok |
| PR Label Assigner | bash | sonnet46-200k | 13.4min | 47 | 5 | $2.21 | — | bash | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| Artifact Cleanup Script | bash | sonnet46-200k | 8.4min | 36 | 5 | $1.42 | — | bash | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Secret Rotation Validator | bash | opus46-200k | 7.4min | 51 | 5 | $1.71 | — | bash | ok |
| Secret Rotation Validator | default | opus46-200k | 8.3min | 34 | 5 | $2.04 | — | python | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | typescript-bun | sonnet46-200k | 6.9min | 51 | 7 | $1.45 | — | typescript | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Dependency License Checker | bash | sonnet46-200k | 11.9min | 53 | 7 | $1.90 | — | bash | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Environment Matrix Generator | powershell | sonnet46-200k | 15.1min | 53 | 7 | $2.98 | — | powershell | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 28.0min | 93 | 8 | $9.31 | — | powershell | timeout |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | default | opus47-1m-medium | 3.0min | 19 | 0 | $0.85 | — | python | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 5.5min | 19 | 0 | $1.09 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 4.2min | 20 | 0 | $0.93 | — | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 3.6min | 21 | 0 | $0.82 | — | powershell | ok |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| Test Results Aggregator | default | opus47-1m-medium | 3.8min | 21 | 0 | $1.00 | — | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 3.9min | 21 | 0 | $1.04 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus46-200k | 3.7min | 21 | 1 | $0.80 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 3.9min | 23 | 0 | $1.06 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 4.1min | 24 | 0 | $0.99 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 4.8min | 24 | 0 | $1.17 | — | bash | ok |
| Secret Rotation Validator | typescript-bun | opus46-200k | 8.9min | 24 | 1 | $1.51 | — | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 3.6min | 25 | 1 | $1.01 | — | bash | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 3.8min | 26 | 1 | $1.06 | — | bash | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 4.0min | 26 | 0 | $1.02 | — | typescript | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.4min | 26 | 0 | $0.98 | — | bash | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 6.0min | 26 | 0 | $1.65 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | sonnet46-200k | 7.0min | 26 | 1 | $1.08 | — | powershell | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 4.0min | 26 | 1 | $1.26 | — | python | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.0min | 27 | 0 | $1.26 | — | typescript | ok |
| Dependency License Checker | powershell-tool | sonnet46-200k | 5.0min | 27 | 0 | $0.68 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.3min | 28 | 0 | $1.16 | — | python | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.52 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-high | 7.3min | 28 | 0 | $1.62 | — | powershell | ok |
| Test Results Aggregator | powershell | sonnet46-200k | 9.2min | 28 | 0 | $1.13 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 6.3min | 28 | 1 | $1.51 | — | powershell | ok |
| Artifact Cleanup Script | bash | opus47-1m-high | 5.7min | 28 | 3 | $1.59 | — | bash | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.32 | — | powershell | ok |
| Semantic Version Bumper | default | opus47-1m-high | 7.2min | 29 | 0 | $2.10 | — | python | ok |
| Semantic Version Bumper | default | sonnet46-200k | 8.0min | 29 | 4 | $1.05 | — | python | ok |
| PR Label Assigner | bash | opus47-1m-medium | 4.2min | 29 | 1 | $1.08 | — | bash | ok |
| PR Label Assigner | powershell | sonnet46-200k | 12.3min | 29 | 2 | $1.46 | — | powershell | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Dependency License Checker | powershell | sonnet46-200k | 7.2min | 29 | 3 | $1.13 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 7.1min | 29 | 0 | $1.68 | — | bash | ok |
| Semantic Version Bumper | bash | sonnet46-200k | 5.7min | 30 | 1 | $0.88 | — | bash | ok |
| Semantic Version Bumper | powershell | sonnet46-200k | 12.3min | 30 | 2 | $1.43 | — | powershell | ok |
| Dependency License Checker | bash | opus47-1m-medium | 4.3min | 30 | 1 | $1.15 | — | bash | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 5.5min | 30 | 1 | $1.47 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Artifact Cleanup Script | powershell | sonnet46-200k | 9.9min | 30 | 1 | $1.47 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 31 | 0 | $1.33 | — | python | ok |
| Semantic Version Bumper | bash | opus47-1m-high | 6.9min | 32 | 2 | $1.61 | — | bash | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | powershell-tool | opus46-200k | 18.5min | 32 | 1 | $3.28 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 4.9min | 32 | 1 | $1.32 | — | typescript | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-high | 8.0min | 33 | 0 | $1.92 | — | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-high | 10.5min | 33 | 0 | $2.66 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | sonnet46-200k | 10.3min | 33 | 3 | $1.28 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 6.4min | 34 | 0 | $1.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 8.4min | 34 | 0 | $1.67 | — | typescript | ok |
| Secret Rotation Validator | default | opus46-200k | 8.3min | 34 | 5 | $2.04 | — | python | ok |
| Secret Rotation Validator | default | opus47-1m-high | 7.4min | 34 | 0 | $1.94 | — | python | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| Dependency License Checker | default | opus47-1m-medium | 7.7min | 35 | 0 | $1.76 | — | python | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 4.3min | 35 | 1 | $1.21 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus46-200k | 5.0min | 35 | 2 | $1.19 | — | typescript | ok |
| Secret Rotation Validator | powershell | sonnet46-200k | 12.7min | 35 | 1 | $1.81 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 9.2min | 35 | 1 | $2.57 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-high | 6.2min | 36 | 1 | $1.85 | — | typescript | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Artifact Cleanup Script | bash | sonnet46-200k | 8.4min | 36 | 5 | $1.42 | — | bash | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-high | 10.5min | 36 | 0 | $2.51 | — | powershell | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 7.6min | 37 | 0 | $2.10 | — | python | ok |
| PR Label Assigner | powershell-tool | sonnet46-200k | 11.8min | 38 | 3 | $1.76 | — | powershell | ok |
| Dependency License Checker | default | opus47-1m-high | 7.3min | 38 | 0 | $2.05 | — | python | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46-200k | 8.3min | 38 | 2 | $1.40 | — | typescript | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 6.1min | 38 | 0 | $2.08 | — | bash | ok |
| Semantic Version Bumper | powershell | opus47-1m-high | 9.5min | 39 | 0 | $2.36 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet46-200k | 9.3min | 39 | 1 | $1.17 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | sonnet46-200k | 12.8min | 39 | 0 | $1.70 | — | powershell | ok |
| Artifact Cleanup Script | default | sonnet46-200k | 11.5min | 39 | 3 | $1.55 | — | python | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 39 | 1 | $2.84 | — | typescript | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-high | 7.8min | 40 | 0 | $2.59 | — | powershell | ok |
| Test Results Aggregator | default | opus47-1m-high | 10.3min | 40 | 0 | $2.47 | — | python | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 11.2min | 40 | 0 | $2.26 | — | powershell | ok |
| Environment Matrix Generator | bash | sonnet46-200k | 9.8min | 40 | 4 | $1.29 | — | bash | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 8.0min | 40 | 1 | $2.14 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-high | 8.1min | 40 | 0 | $2.68 | — | python | ok |
| Secret Rotation Validator | bash | opus47-1m-high | 5.8min | 40 | 2 | $2.08 | — | bash | ok |
| Secret Rotation Validator | bash | sonnet46-200k | 12.6min | 40 | 2 | $1.67 | — | bash | ok |
| Secret Rotation Validator | powershell | opus47-1m-high | 7.6min | 40 | 0 | $2.32 | — | powershell | ok |
| PR Label Assigner | bash | opus47-1m-high | 6.3min | 41 | 0 | $1.71 | — | bash | ok |
| Dependency License Checker | default | sonnet46-200k | 9.0min | 41 | 4 | $1.53 | — | python | ok |
| Semantic Version Bumper | powershell-tool | sonnet46-200k | 12.7min | 42 | 0 | $1.92 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-high | 9.2min | 42 | 0 | $2.86 | — | powershell | ok |
| PR Label Assigner | default | opus47-1m-high | 7.4min | 43 | 0 | $2.23 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 10.7min | 43 | 2 | $3.05 | — | bash | ok |
| Test Results Aggregator | default | sonnet46-200k | 7.7min | 44 | 2 | $1.30 | — | python | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.3min | 44 | 0 | $2.68 | — | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 9.8min | 44 | 0 | $2.99 | — | powershell | ok |
| PR Label Assigner | default | sonnet46-200k | 11.4min | 45 | 4 | $1.66 | — | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m-high | 9.4min | 45 | 0 | $2.54 | — | powershell | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 7.5min | 45 | 0 | $1.83 | — | typescript | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 9.6min | 45 | 0 | $3.14 | — | powershell | ok |
| Dependency License Checker | bash | opus47-1m-high | 8.0min | 46 | 1 | $2.59 | — | bash | ok |
| Test Results Aggregator | powershell | opus47-1m-high | 8.7min | 46 | 2 | $2.72 | — | powershell | ok |
| Environment Matrix Generator | default | sonnet46-200k | 6.8min | 46 | 4 | $1.28 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 9.3min | 46 | 0 | $2.72 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 12.7min | 46 | 0 | $3.88 | — | powershell | ok |
| PR Label Assigner | bash | sonnet46-200k | 13.4min | 47 | 5 | $2.21 | — | bash | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | powershell | opus47-1m-high | 11.0min | 47 | 0 | $2.87 | — | powershell | ok |
| Dependency License Checker | typescript-bun | sonnet46-200k | 8.3min | 47 | 1 | $1.31 | — | typescript | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Environment Matrix Generator | powershell-tool | sonnet46-200k | 15.1min | 48 | 3 | $1.83 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-high | 8.1min | 48 | 0 | $2.51 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Secret Rotation Validator | default | sonnet46-200k | 14.9min | 48 | 4 | $1.90 | — | python | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Dependency License Checker | typescript-bun | opus47-1m-high | 8.3min | 49 | 0 | $2.01 | — | typescript | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | sonnet46-200k | 10.2min | 49 | 3 | $1.46 | — | typescript | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| PR Label Assigner | powershell | opus47-1m-high | 15.3min | 51 | 1 | $3.83 | — | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet46-200k | 6.9min | 51 | 7 | $1.45 | — | typescript | ok |
| Secret Rotation Validator | bash | opus46-200k | 7.4min | 51 | 5 | $1.71 | — | bash | ok |
| Secret Rotation Validator | powershell | opus46-200k | 7.2min | 51 | 0 | $1.78 | — | powershell | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 9.4min | 51 | 0 | $3.22 | — | python | ok |
| Test Results Aggregator | bash | sonnet46-200k | 17.4min | 52 | 4 | $1.97 | — | bash | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 14.5min | 52 | 0 | $3.83 | — | bash | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 13.9min | 52 | 0 | $3.72 | — | powershell | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Dependency License Checker | bash | sonnet46-200k | 11.9min | 53 | 7 | $1.90 | — | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-high | 10.1min | 53 | 1 | $3.69 | — | typescript | ok |
| Environment Matrix Generator | powershell | sonnet46-200k | 15.1min | 53 | 7 | $2.98 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-high | 10.4min | 53 | 0 | $2.83 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet46-200k | 10.8min | 53 | 1 | $1.68 | — | typescript | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 10.7min | 55 | 1 | $3.08 | — | bash | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 11.3min | 56 | 2 | $3.56 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 8.7min | 57 | 2 | $2.56 | — | powershell | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-high | 20.6min | 57 | 0 | $3.39 | — | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 12.4min | 57 | 0 | $3.99 | — | powershell | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-high | 9.6min | 59 | 0 | $2.82 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 11.6min | 59 | 1 | $3.27 | — | typescript | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 11.9min | 59 | 1 | $3.91 | — | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-high | 12.0min | 60 | 2 | $3.90 | — | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 9.6min | 60 | 4 | $3.39 | — | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 11.7min | 60 | 1 | $3.89 | — | python | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-high | 9.6min | 63 | 1 | $3.56 | — | typescript | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 15.4min | 63 | 1 | $4.72 | — | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 12.1min | 64 | 0 | $3.19 | — | typescript | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 11.2min | 64 | 1 | $3.82 | — | python | ok |
| Test Results Aggregator | typescript-bun | sonnet46-200k | 9.5min | 67 | 4 | $2.05 | — | typescript | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 11.6min | 68 | 1 | $3.64 | — | typescript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 13.4min | 71 | 0 | $3.80 | — | python | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |
| Test Results Aggregator | bash | opus47-1m-high | 20.0min | 74 | 3 | $4.92 | — | bash | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 16.4min | 75 | 0 | $4.47 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-high | 17.3min | 79 | 1 | $5.01 | — | powershell | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-high | 18.4min | 90 | 2 | $6.68 | — | powershell | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 28.0min | 93 | 8 | $9.31 | — | powershell | timeout |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-high | 6.9min | 32 | 2 | $1.61 | — | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 3.8min | 26 | 1 | $1.06 | — | bash | ok |
| Semantic Version Bumper | bash | sonnet46-200k | 5.7min | 30 | 1 | $0.88 | — | bash | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | default | opus47-1m-high | 7.2min | 29 | 0 | $2.10 | — | python | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.3min | 28 | 0 | $1.16 | — | python | ok |
| Semantic Version Bumper | default | sonnet46-200k | 8.0min | 29 | 4 | $1.05 | — | python | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-high | 9.5min | 39 | 0 | $2.36 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.52 | — | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46-200k | 12.3min | 30 | 2 | $1.43 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-high | 7.8min | 40 | 0 | $2.59 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 3.6min | 21 | 0 | $0.82 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | sonnet46-200k | 12.7min | 42 | 0 | $1.92 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-high | 9.6min | 59 | 0 | $2.82 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.0min | 27 | 0 | $1.26 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet46-200k | 9.3min | 39 | 1 | $1.17 | — | typescript | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |
| PR Label Assigner | bash | opus47-1m-high | 6.3min | 41 | 0 | $1.71 | — | bash | ok |
| PR Label Assigner | bash | opus47-1m-medium | 4.2min | 29 | 1 | $1.08 | — | bash | ok |
| PR Label Assigner | bash | sonnet46-200k | 13.4min | 47 | 5 | $2.21 | — | bash | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| PR Label Assigner | default | opus47-1m-high | 7.4min | 43 | 0 | $2.23 | — | python | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.0min | 19 | 0 | $0.85 | — | python | ok |
| PR Label Assigner | default | sonnet46-200k | 11.4min | 45 | 4 | $1.66 | — | python | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-high | 15.3min | 51 | 1 | $3.83 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 8.7min | 57 | 2 | $2.56 | — | powershell | ok |
| PR Label Assigner | powershell | sonnet46-200k | 12.3min | 29 | 2 | $1.46 | — | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-high | 9.4min | 45 | 0 | $2.54 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 6.4min | 34 | 0 | $1.62 | — | powershell | ok |
| PR Label Assigner | powershell-tool | sonnet46-200k | 11.8min | 38 | 3 | $1.76 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus47-1m-high | 6.2min | 36 | 1 | $1.85 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 4.0min | 26 | 0 | $1.02 | — | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet46-200k | 6.9min | 51 | 7 | $1.45 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Dependency License Checker | bash | opus47-1m-high | 8.0min | 46 | 1 | $2.59 | — | bash | ok |
| Dependency License Checker | bash | opus47-1m-medium | 4.3min | 30 | 1 | $1.15 | — | bash | ok |
| Dependency License Checker | bash | sonnet46-200k | 11.9min | 53 | 7 | $1.90 | — | bash | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Dependency License Checker | default | opus47-1m-high | 7.3min | 38 | 0 | $2.05 | — | python | ok |
| Dependency License Checker | default | opus47-1m-medium | 7.7min | 35 | 0 | $1.76 | — | python | ok |
| Dependency License Checker | default | sonnet46-200k | 9.0min | 41 | 4 | $1.53 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-high | 11.0min | 47 | 0 | $2.87 | — | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 5.5min | 19 | 0 | $1.09 | — | powershell | ok |
| Dependency License Checker | powershell | sonnet46-200k | 7.2min | 29 | 3 | $1.13 | — | powershell | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-high | 7.3min | 28 | 0 | $1.62 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 5.5min | 30 | 1 | $1.47 | — | powershell | ok |
| Dependency License Checker | powershell-tool | sonnet46-200k | 5.0min | 27 | 0 | $0.68 | — | powershell | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-high | 8.3min | 49 | 0 | $2.01 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 4.1min | 24 | 0 | $0.99 | — | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet46-200k | 8.3min | 47 | 1 | $1.31 | — | typescript | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Test Results Aggregator | bash | opus47-1m-high | 20.0min | 74 | 3 | $4.92 | — | bash | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 3.6min | 25 | 1 | $1.01 | — | bash | ok |
| Test Results Aggregator | bash | sonnet46-200k | 17.4min | 52 | 4 | $1.97 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Test Results Aggregator | default | opus47-1m-high | 10.3min | 40 | 0 | $2.47 | — | python | ok |
| Test Results Aggregator | default | opus47-1m-medium | 3.8min | 21 | 0 | $1.00 | — | python | ok |
| Test Results Aggregator | default | sonnet46-200k | 7.7min | 44 | 2 | $1.30 | — | python | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-high | 8.7min | 46 | 2 | $2.72 | — | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 11.2min | 40 | 0 | $2.26 | — | powershell | ok |
| Test Results Aggregator | powershell | sonnet46-200k | 9.2min | 28 | 0 | $1.13 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-high | 17.3min | 79 | 1 | $5.01 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.3min | 44 | 0 | $2.68 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | sonnet46-200k | 12.8min | 39 | 0 | $1.70 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-high | 10.1min | 53 | 1 | $3.69 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 7.5min | 45 | 0 | $1.83 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet46-200k | 9.5min | 67 | 4 | $2.05 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-high | 20.6min | 57 | 0 | $3.39 | — | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.4min | 26 | 0 | $0.98 | — | bash | ok |
| Environment Matrix Generator | bash | sonnet46-200k | 9.8min | 40 | 4 | $1.29 | — | bash | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Environment Matrix Generator | default | opus47-1m-high | 8.0min | 33 | 0 | $1.92 | — | python | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 31 | 0 | $1.33 | — | python | ok |
| Environment Matrix Generator | default | sonnet46-200k | 6.8min | 46 | 4 | $1.28 | — | python | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-high | 10.5min | 33 | 0 | $2.66 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 8.0min | 40 | 1 | $2.14 | — | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46-200k | 15.1min | 53 | 7 | $2.98 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-high | 18.4min | 90 | 2 | $6.68 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 6.3min | 28 | 1 | $1.51 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | sonnet46-200k | 15.1min | 48 | 3 | $1.83 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-high | 8.1min | 48 | 0 | $2.51 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 4.3min | 35 | 1 | $1.21 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | sonnet46-200k | 10.2min | 49 | 3 | $1.46 | — | typescript | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Artifact Cleanup Script | bash | opus47-1m-high | 5.7min | 28 | 3 | $1.59 | — | bash | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 7.1min | 29 | 0 | $1.68 | — | bash | ok |
| Artifact Cleanup Script | bash | sonnet46-200k | 8.4min | 36 | 5 | $1.42 | — | bash | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Artifact Cleanup Script | default | opus47-1m-high | 8.1min | 40 | 0 | $2.68 | — | python | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 4.2min | 20 | 0 | $0.93 | — | python | ok |
| Artifact Cleanup Script | default | sonnet46-200k | 11.5min | 39 | 3 | $1.55 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-high | 9.2min | 42 | 0 | $2.86 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 6.0min | 28 | 0 | $1.32 | — | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46-200k | 9.9min | 30 | 1 | $1.47 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus46-200k | 18.5min | 32 | 1 | $3.28 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-high | 12.0min | 60 | 2 | $3.90 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 6.0min | 26 | 0 | $1.65 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | sonnet46-200k | 7.0min | 26 | 1 | $1.08 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus46-200k | 5.0min | 35 | 2 | $1.19 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-high | 9.6min | 63 | 1 | $3.56 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 8.4min | 34 | 0 | $1.67 | — | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46-200k | 8.3min | 38 | 2 | $1.40 | — | typescript | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Secret Rotation Validator | bash | opus46-200k | 7.4min | 51 | 5 | $1.71 | — | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-high | 5.8min | 40 | 2 | $2.08 | — | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 4.8min | 24 | 0 | $1.17 | — | bash | ok |
| Secret Rotation Validator | bash | sonnet46-200k | 12.6min | 40 | 2 | $1.67 | — | bash | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| Secret Rotation Validator | default | opus46-200k | 8.3min | 34 | 5 | $2.04 | — | python | ok |
| Secret Rotation Validator | default | opus47-1m-high | 7.4min | 34 | 0 | $1.94 | — | python | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 4.0min | 26 | 1 | $1.26 | — | python | ok |
| Secret Rotation Validator | default | sonnet46-200k | 14.9min | 48 | 4 | $1.90 | — | python | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Secret Rotation Validator | powershell | opus46-200k | 7.2min | 51 | 0 | $1.78 | — | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-high | 7.6min | 40 | 0 | $2.32 | — | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 3.9min | 21 | 0 | $1.04 | — | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46-200k | 12.7min | 35 | 1 | $1.81 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus46-200k | 3.7min | 21 | 1 | $0.80 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-high | 10.5min | 36 | 0 | $2.51 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 3.9min | 23 | 0 | $1.06 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | sonnet46-200k | 10.3min | 33 | 3 | $1.28 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus46-200k | 8.9min | 24 | 1 | $1.51 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-high | 10.4min | 53 | 0 | $2.83 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 4.9min | 32 | 1 | $1.32 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet46-200k | 10.8min | 53 | 1 | $1.68 | — | typescript | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 7.6min | 37 | 0 | $2.10 | — | python | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 15.4min | 63 | 1 | $4.72 | — | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 10.7min | 55 | 1 | $3.08 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 9.3min | 46 | 0 | $2.72 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 11.6min | 59 | 1 | $3.27 | — | typescript | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 11.9min | 59 | 1 | $3.91 | — | python | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 11.3min | 56 | 2 | $3.56 | — | powershell | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 14.5min | 52 | 0 | $3.83 | — | bash | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 28.0min | 93 | 8 | $9.31 | — | powershell | timeout |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 12.1min | 64 | 0 | $3.19 | — | typescript | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 9.4min | 51 | 0 | $3.22 | — | python | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 13.9min | 52 | 0 | $3.72 | — | powershell | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 6.1min | 38 | 0 | $2.08 | — | bash | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 12.7min | 46 | 0 | $3.88 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 16.4min | 75 | 0 | $4.47 | — | typescript | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 11.2min | 64 | 1 | $3.82 | — | python | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 9.8min | 44 | 0 | $2.99 | — | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 9.6min | 60 | 4 | $3.39 | — | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 12.4min | 57 | 0 | $3.99 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 11.6min | 68 | 1 | $3.64 | — | typescript | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 13.4min | 71 | 0 | $3.80 | — | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 9.2min | 35 | 1 | $2.57 | — | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 10.7min | 43 | 2 | $3.05 | — | bash | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 9.6min | 45 | 0 | $3.14 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 39 | 1 | $2.84 | — | typescript | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 11.7min | 60 | 1 | $3.89 | — | python | ok |

</details>

## Notes

### Tiers

- **Duration bands:** **A+** ≤1.09×, **A** ≤1.18×, **A-** ≤1.29×, **B+** ≤1.40×, **B** ≤1.53×, **B-** ≤1.66×, **C+** ≤1.81×, **C** ≤1.97×, **C-** ≤2.14×, **D+** ≤2.33×, **D** ≤2.54×, **D-** ≤2.76×, **F** >2.76×
- **Cost bands:** **A+** ≤1.20×, **A** ≤1.45×, **A-** ≤1.74×, **B+** ≤2.10×, **B** ≤2.53×, **B-** ≤3.04×, **C+** ≤3.66×, **C** ≤4.41×, **C-** ≤5.31×, **D+** ≤6.39×, **D** ≤7.69×, **D-** ≤9.25×, **F** >9.25×

*Tests/Workflow Craft bands are absolute Overall score bands:* **A+** ≥4.7, **A** ≥4.4, **A-** ≥4.1, **B+** ≥3.8, **B** ≥3.5, **B-** ≥3.2, **C+** ≥2.9, **C** ≥2.6, **C-** ≥2.3, **D+** ≥2.0, **D** ≥1.7, **D-** ≥1.4, **F** <1.4, `—` = no data.*

### CLI Version Legend

| Variant label | CLI version | Tasks | Languages |
|---------------|-------------|-------|-----------|
| haiku45-200k | 2.1.131 | 11-semantic-version-bumper, 12-pr-label-assigner | All |
| haiku45-200k | 2.1.132 | 12-pr-label-assigner, 13-dependency-license-checker, 15-test-results-aggregator, 16-environment-matrix-generator, 17-artifact-cleanup-script, 18-secret-rotation-validator | All |
| opus46-200k | 2.1.132 | All | All |
| opus47-1m-high | 2.1.132 | All | All |
| opus47-1m-medium | 2.1.132 | All | All |
| opus47-1m-xhigh | 2.1.132 | 11-semantic-version-bumper, 12-pr-label-assigner, 13-dependency-license-checker, 15-test-results-aggregator, 16-environment-matrix-generator, 17-artifact-cleanup-script | All |
| sonnet46-200k | 2.1.132 | All | All |

---
*Generated by generate_results.py — benchmark instructions v4*