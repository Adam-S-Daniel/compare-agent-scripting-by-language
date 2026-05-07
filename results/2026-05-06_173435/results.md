# Benchmark Results: Language Comparison

**Last updated:** 2026-05-07 01:21:43 AM ET — 63/70 runs completed, 7 remaining; total cost $59.16; total agent time 449.0 min.

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
| powershell | haiku45-200k* | B- (6.4min) | A- ($0.54) | — | — |
| powershell-tool | haiku45-200k | C (7.2min) | A ($0.48) | — | — |
| bash | haiku45-200k | C- (7.6min) | B ($0.70) | — | — |
| default | opus46-200k | B (6.1min) | D+ ($1.26) | — | — |
| typescript-bun | opus46-200k | B (5.9min) | D+ ($1.28) | — | — |
| powershell-tool | opus46-200k | C+ (6.9min) | D+ ($1.37) | — | — |
| bash | opus46-200k | D (8.5min) | D- ($1.62) | — | — |
| powershell | opus46-200k | D- (9.1min) | D- ($1.79) | — | — |


<details>
<summary>Sorted by Duration tier (best-first), then avg of Cost/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | A- (5.5min) | A ($0.48) | — | — |
| default | opus46-200k | B (6.1min) | D+ ($1.26) | — | — |
| typescript-bun | opus46-200k | B (5.9min) | D+ ($1.28) | — | — |
| powershell | haiku45-200k* | B- (6.4min) | A- ($0.54) | — | — |
| powershell-tool | opus46-200k | C+ (6.9min) | D+ ($1.37) | — | — |
| powershell-tool | haiku45-200k | C (7.2min) | A ($0.48) | — | — |
| bash | haiku45-200k | C- (7.6min) | B ($0.70) | — | — |
| bash | opus46-200k | D (8.5min) | D- ($1.62) | — | — |
| powershell | opus46-200k | D- (9.1min) | D- ($1.79) | — | — |

</details>

<details>
<summary>Sorted by Cost tier (best-first), then avg of Duration/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | A- (5.5min) | A ($0.48) | — | — |
| powershell-tool | haiku45-200k | C (7.2min) | A ($0.48) | — | — |
| powershell | haiku45-200k* | B- (6.4min) | A- ($0.54) | — | — |
| bash | haiku45-200k | C- (7.6min) | B ($0.70) | — | — |
| default | opus46-200k | B (6.1min) | D+ ($1.26) | — | — |
| typescript-bun | opus46-200k | B (5.9min) | D+ ($1.28) | — | — |
| powershell-tool | opus46-200k | C+ (6.9min) | D+ ($1.37) | — | — |
| bash | opus46-200k | D (8.5min) | D- ($1.62) | — | — |
| powershell | opus46-200k | D- (9.1min) | D- ($1.79) | — | — |

</details>

<details>
<summary>Sorted by Tests Quality tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | A- (5.5min) | A ($0.48) | — | — |
| powershell | haiku45-200k* | B- (6.4min) | A- ($0.54) | — | — |
| powershell-tool | haiku45-200k | C (7.2min) | A ($0.48) | — | — |
| bash | haiku45-200k | C- (7.6min) | B ($0.70) | — | — |
| default | opus46-200k | B (6.1min) | D+ ($1.26) | — | — |
| typescript-bun | opus46-200k | B (5.9min) | D+ ($1.28) | — | — |
| powershell-tool | opus46-200k | C+ (6.9min) | D+ ($1.37) | — | — |
| bash | opus46-200k | D (8.5min) | D- ($1.62) | — | — |
| powershell | opus46-200k | D- (9.1min) | D- ($1.79) | — | — |

</details>

<details>
<summary>Sorted by Workflow Craft tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | A- (5.5min) | A ($0.48) | — | — |
| powershell | haiku45-200k* | B- (6.4min) | A- ($0.54) | — | — |
| powershell-tool | haiku45-200k | C (7.2min) | A ($0.48) | — | — |
| bash | haiku45-200k | C- (7.6min) | B ($0.70) | — | — |
| default | opus46-200k | B (6.1min) | D+ ($1.26) | — | — |
| typescript-bun | opus46-200k | B (5.9min) | D+ ($1.28) | — | — |
| powershell-tool | opus46-200k | C+ (6.9min) | D+ ($1.37) | — | — |
| bash | opus46-200k | D (8.5min) | D- ($1.62) | — | — |
| powershell | opus46-200k | D- (9.1min) | D- ($1.79) | — | — |

</details>

- **Estimated time remaining:** 299.4min
- **Estimated total cost:** $65.73

## Failed / Timed-Out Runs

| Task | Language | Model | Duration | Reason | Lines | actionlint | act-result.txt |
|------|------|-------|----------|--------|-------|------------|----------------|
| PR Label Assigner | powershell | haiku45-200k | 29.1min | timeout | 1141 | pass | yes |

*1 run(s) excluded from averages below.*

## Comparison by Language/Model/Effort
*(averages exclude failed/timed-out runs)*
*See [Notes](#notes) for scoring rubric and CLI version legend.*

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 6 | 8.5min | 6.4min | 5.5 | 53 | $1.62 | $9.70 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | opus46-200k | 6 | 6.1min | 5.8min | 2.5 | 34 | $1.26 | $7.55 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus46-200k | 6 | 9.1min | 8.8min | 1.2 | 30 | $1.79 | $10.72 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | opus46-200k | 5 | 6.9min | 6.9min | 1.4 | 28 | $1.37 | $6.83 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus46-200k | 5 | 5.9min | 4.5min | 2.0 | 37 | $1.28 | $6.39 | — | — |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| default | opus46-200k | 6 | 6.1min | 5.8min | 2.5 | 34 | $1.26 | $7.55 | — | — |
| typescript-bun | opus46-200k | 5 | 5.9min | 4.5min | 2.0 | 37 | $1.28 | $6.39 | — | — |
| powershell-tool | opus46-200k | 5 | 6.9min | 6.9min | 1.4 | 28 | $1.37 | $6.83 | — | — |
| bash | opus46-200k | 6 | 8.5min | 6.4min | 5.5 | 53 | $1.62 | $9.70 | — | — |
| powershell | opus46-200k | 6 | 9.1min | 8.8min | 1.2 | 30 | $1.79 | $10.72 | — | — |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus46-200k | 5 | 5.9min | 4.5min | 2.0 | 37 | $1.28 | $6.39 | — | — |
| default | opus46-200k | 6 | 6.1min | 5.8min | 2.5 | 34 | $1.26 | $7.55 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell-tool | opus46-200k | 5 | 6.9min | 6.9min | 1.4 | 28 | $1.37 | $6.83 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 6 | 8.5min | 6.4min | 5.5 | 53 | $1.62 | $9.70 | — | — |
| powershell | opus46-200k | 6 | 9.1min | 8.8min | 1.2 | 30 | $1.79 | $10.72 | — | — |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| typescript-bun | opus46-200k | 5 | 5.9min | 4.5min | 2.0 | 37 | $1.28 | $6.39 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| default | opus46-200k | 6 | 6.1min | 5.8min | 2.5 | 34 | $1.26 | $7.55 | — | — |
| bash | opus46-200k | 6 | 8.5min | 6.4min | 5.5 | 53 | $1.62 | $9.70 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell-tool | opus46-200k | 5 | 6.9min | 6.9min | 1.4 | 28 | $1.37 | $6.83 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| powershell | opus46-200k | 6 | 9.1min | 8.8min | 1.2 | 30 | $1.79 | $10.72 | — | — |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| powershell | opus46-200k | 6 | 9.1min | 8.8min | 1.2 | 30 | $1.79 | $10.72 | — | — |
| powershell-tool | opus46-200k | 5 | 6.9min | 6.9min | 1.4 | 28 | $1.37 | $6.83 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| typescript-bun | opus46-200k | 5 | 5.9min | 4.5min | 2.0 | 37 | $1.28 | $6.39 | — | — |
| default | opus46-200k | 6 | 6.1min | 5.8min | 2.5 | 34 | $1.26 | $7.55 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 6 | 8.5min | 6.4min | 5.5 | 53 | $1.62 | $9.70 | — | — |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| powershell-tool | opus46-200k | 5 | 6.9min | 6.9min | 1.4 | 28 | $1.37 | $6.83 | — | — |
| powershell | opus46-200k | 6 | 9.1min | 8.8min | 1.2 | 30 | $1.79 | $10.72 | — | — |
| default | opus46-200k | 6 | 6.1min | 5.8min | 2.5 | 34 | $1.26 | $7.55 | — | — |
| typescript-bun | opus46-200k | 5 | 5.9min | 4.5min | 2.0 | 37 | $1.28 | $6.39 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| bash | opus46-200k | 6 | 8.5min | 6.4min | 5.5 | 53 | $1.62 | $9.70 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 6 | 8.5min | 6.4min | 5.5 | 53 | $1.62 | $9.70 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | opus46-200k | 6 | 6.1min | 5.8min | 2.5 | 34 | $1.26 | $7.55 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus46-200k | 6 | 9.1min | 8.8min | 1.2 | 30 | $1.79 | $10.72 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | opus46-200k | 5 | 6.9min | 6.9min | 1.4 | 28 | $1.37 | $6.83 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus46-200k | 5 | 5.9min | 4.5min | 2.0 | 37 | $1.28 | $6.39 | — | — |

</details>

<details>
<summary>Sorted by deliverable-quality score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 6 | 8.5min | 6.4min | 5.5 | 53 | $1.62 | $9.70 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | opus46-200k | 6 | 6.1min | 5.8min | 2.5 | 34 | $1.26 | $7.55 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus46-200k | 6 | 9.1min | 8.8min | 1.2 | 30 | $1.79 | $10.72 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | opus46-200k | 5 | 6.9min | 6.9min | 1.4 | 28 | $1.37 | $6.83 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus46-200k | 5 | 5.9min | 4.5min | 2.0 | 37 | $1.28 | $6.39 | — | — |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

*`% of Test Time Saved` = `net / (net + test_time) × 100` — the share of total (would-have-been + actually-spent) test time that hooks eliminated. Bounded in (-∞, 100%) without an artificial cap; near 100% means hooks substituted for almost all of the hypothetical test work.*

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | 0.4min | 28.2% |
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 1.7% | 0.2min | 0.0% | 7.4min | 1.6% | 3.5min | 67.9% |
| bash | opus46-200k-cli2.1.132 | 114 | 11 | 9.6% | 2.2min | 0.5% | 0.3min | 0.1% | 1.9min | 0.4% | 2.2min | 46.6% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.0min | 91.1% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.4% | 0.2min | 0.0% | 1.4min | 0.3% | 3.0min | 32.2% |
| default | opus46-200k-cli2.1.132 | 77 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.1% | -0.1min | -0.0% | 1.0min | -11.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 0.8min | 31.9% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.5% | 0.8min | 0.2% | 1.5min | 0.3% | 6.0min | 20.1% |
| powershell | opus46-200k-cli2.1.132 | 72 | 4 | 5.6% | 2.3min | 0.5% | 0.4min | 0.1% | 2.0min | 0.4% | 2.7min | 41.6% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.1% | -0.3min | -0.1% | 5.6min | -5.8% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.4% | 0.7min | 0.1% | 1.1min | 0.2% | 3.2min | 25.3% |
| powershell-tool | opus46-200k-cli2.1.132 | 53 | 2 | 3.8% | 1.2min | 0.3% | 0.3min | 0.1% | 0.8min | 0.2% | 1.4min | 38.3% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.3% | 1.5min | 0.3% | -0.2min | -0.0% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 1.3% | 5.2min | 1.1% | 0.7min | 0.2% | 1.7min | 29.1% |
| typescript-bun | opus46-200k-cli2.1.132 | 76 | 32 | 42.1% | 4.3min | 1.0% | 2.3min | 0.5% | 2.0min | 0.4% | 3.0min | 39.9% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 1.7% | 0.2min | 0.0% | 7.4min | 1.6% | 3.5min | 67.9% |
| typescript-bun | opus46-200k-cli2.1.132 | 76 | 32 | 42.1% | 4.3min | 1.0% | 2.3min | 0.5% | 2.0min | 0.4% | 3.0min | 39.9% |
| powershell | opus46-200k-cli2.1.132 | 72 | 4 | 5.6% | 2.3min | 0.5% | 0.4min | 0.1% | 2.0min | 0.4% | 2.7min | 41.6% |
| bash | opus46-200k-cli2.1.132 | 114 | 11 | 9.6% | 2.2min | 0.5% | 0.3min | 0.1% | 1.9min | 0.4% | 2.2min | 46.6% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.5% | 0.8min | 0.2% | 1.5min | 0.3% | 6.0min | 20.1% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.4% | 0.2min | 0.0% | 1.4min | 0.3% | 3.0min | 32.2% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.4% | 0.7min | 0.1% | 1.1min | 0.2% | 3.2min | 25.3% |
| powershell-tool | opus46-200k-cli2.1.132 | 53 | 2 | 3.8% | 1.2min | 0.3% | 0.3min | 0.1% | 0.8min | 0.2% | 1.4min | 38.3% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 1.3% | 5.2min | 1.1% | 0.7min | 0.2% | 1.7min | 29.1% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 0.8min | 31.9% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | 0.4min | 28.2% |
| default | opus46-200k-cli2.1.132 | 77 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.1% | -0.1min | -0.0% | 1.0min | -11.2% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.3% | 1.5min | 0.3% | -0.2min | -0.0% | 0.5min | -57.5% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.1% | -0.3min | -0.1% | 5.6min | -5.8% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 1.7% | 0.2min | 0.0% | 7.4min | 1.6% | 3.5min | 67.9% |
| bash | opus46-200k-cli2.1.132 | 114 | 11 | 9.6% | 2.2min | 0.5% | 0.3min | 0.1% | 1.9min | 0.4% | 2.2min | 46.6% |
| powershell | opus46-200k-cli2.1.132 | 72 | 4 | 5.6% | 2.3min | 0.5% | 0.4min | 0.1% | 2.0min | 0.4% | 2.7min | 41.6% |
| typescript-bun | opus46-200k-cli2.1.132 | 76 | 32 | 42.1% | 4.3min | 1.0% | 2.3min | 0.5% | 2.0min | 0.4% | 3.0min | 39.9% |
| powershell-tool | opus46-200k-cli2.1.132 | 53 | 2 | 3.8% | 1.2min | 0.3% | 0.3min | 0.1% | 0.8min | 0.2% | 1.4min | 38.3% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.4% | 0.2min | 0.0% | 1.4min | 0.3% | 3.0min | 32.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 0.8min | 31.9% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 1.3% | 5.2min | 1.1% | 0.7min | 0.2% | 1.7min | 29.1% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | 0.4min | 28.2% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.4% | 0.7min | 0.1% | 1.1min | 0.2% | 3.2min | 25.3% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.5% | 0.8min | 0.2% | 1.5min | 0.3% | 6.0min | 20.1% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.1% | -0.3min | -0.1% | 5.6min | -5.8% |
| default | opus46-200k-cli2.1.132 | 77 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.1% | -0.1min | -0.0% | 1.0min | -11.2% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.3% | 1.5min | 0.3% | -0.2min | -0.0% | 0.5min | -57.5% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus46-200k-cli2.1.132 | 76 | 32 | 42.1% | 4.3min | 1.0% | 2.3min | 0.5% | 2.0min | 0.4% | 3.0min | 39.9% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 1.3% | 5.2min | 1.1% | 0.7min | 0.2% | 1.7min | 29.1% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.3% | 1.5min | 0.3% | -0.2min | -0.0% | 0.5min | -57.5% |
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 1.7% | 0.2min | 0.0% | 7.4min | 1.6% | 3.5min | 67.9% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.4% | 0.2min | 0.0% | 1.4min | 0.3% | 3.0min | 32.2% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.0min | 91.1% |
| bash | opus46-200k-cli2.1.132 | 114 | 11 | 9.6% | 2.2min | 0.5% | 0.3min | 0.1% | 1.9min | 0.4% | 2.2min | 46.6% |
| powershell | opus46-200k-cli2.1.132 | 72 | 4 | 5.6% | 2.3min | 0.5% | 0.4min | 0.1% | 2.0min | 0.4% | 2.7min | 41.6% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | 0.4min | 28.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 0.8min | 31.9% |
| powershell-tool | opus46-200k-cli2.1.132 | 53 | 2 | 3.8% | 1.2min | 0.3% | 0.3min | 0.1% | 0.8min | 0.2% | 1.4min | 38.3% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.5% | 0.8min | 0.2% | 1.5min | 0.3% | 6.0min | 20.1% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.4% | 0.7min | 0.1% | 1.1min | 0.2% | 3.2min | 25.3% |
| default | opus46-200k-cli2.1.132 | 77 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.1% | -0.1min | -0.0% | 1.0min | -11.2% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.1% | -0.3min | -0.1% | 5.6min | -5.8% |

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 0.9% | $0.20 | 0.33% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 1.1% | $0.53 | 0.90% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.1% | $0.05 | 0.08% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.1% | $0.03 | 0.05% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 1.3% | $0.43 | 0.73% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 0.9% | $0.35 | 0.58% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 2.9% | $0.70 | 1.18% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.3% | $0.10 | 0.17% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 0.6% | $0.22 | 0.36% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.03 | 0.05% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 1.4% | $0.64 | 1.09% |
| repeated-test-reruns | bash | opus46-200k-cli2.1.132 | 1 | 2.0min | 0.4% | $0.16 | 0.27% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.5% | $0.17 | 0.28% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 1.2% | $0.33 | 0.55% |
| repeated-test-reruns | powershell | opus46-200k-cli2.1.132 | 1 | 1.0min | 0.2% | $0.21 | 0.36% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.2% | $0.05 | 0.09% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.2% | $0.07 | 0.13% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.05 | 0.08% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 1.9% | $0.88 | 1.49% |
| repeated-test-reruns | typescript-bun | opus46-200k-cli2.1.132 | 1 | 0.7min | 0.1% | $0.13 | 0.22% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.4% | $0.19 | 0.33% |
| fixture-rework | bash | opus46-200k-cli2.1.132 | 4 | 9.0min | 2.0% | $2.23 | 3.77% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.1% | $0.03 | 0.05% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.4% | $0.17 | 0.29% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 2 | 1.8min | 0.4% | $0.38 | 0.64% |
| fixture-rework | powershell | opus46-200k-cli2.1.132 | 1 | 0.8min | 0.2% | $0.16 | 0.27% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.2% | $0.06 | 0.10% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.4% | $0.17 | 0.29% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.4% | $0.15 | 0.25% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 2.0% | $0.85 | 1.43% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 5 | 6.4min | 1.4% | $1.35 | 2.29% |
| actionlint-fix-cycles | bash | opus46-200k-cli2.1.132 | 1 | 1.7min | 0.4% | $0.42 | 0.70% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.5% | $0.22 | 0.37% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.05 | 0.08% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 0.6% | $0.19 | 0.32% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 0.6% | $0.20 | 0.34% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.04 | 0.06% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 0.9% | $0.15 | 0.26% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.4% | $0.20 | 0.34% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.1% | $0.03 | 0.05% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.1% | $0.03 | 0.05% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.1% | $0.05 | 0.08% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.04 | 0.06% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.03 | 0.05% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.05 | 0.08% |
| repeated-test-reruns | typescript-bun | opus46-200k-cli2.1.132 | 1 | 0.7min | 0.1% | $0.13 | 0.22% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.05 | 0.08% |
| fixture-rework | powershell | opus46-200k-cli2.1.132 | 1 | 0.8min | 0.2% | $0.16 | 0.27% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.2% | $0.06 | 0.10% |
| repeated-test-reruns | powershell | opus46-200k-cli2.1.132 | 1 | 1.0min | 0.2% | $0.21 | 0.36% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.2% | $0.05 | 0.09% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.2% | $0.07 | 0.13% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.3% | $0.10 | 0.17% |
| actionlint-fix-cycles | bash | opus46-200k-cli2.1.132 | 1 | 1.7min | 0.4% | $0.42 | 0.70% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.4% | $0.17 | 0.29% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 2 | 1.8min | 0.4% | $0.38 | 0.64% |
| repeated-test-reruns | bash | opus46-200k-cli2.1.132 | 1 | 2.0min | 0.4% | $0.16 | 0.27% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.4% | $0.19 | 0.33% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.4% | $0.17 | 0.29% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.4% | $0.15 | 0.25% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.4% | $0.20 | 0.34% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.5% | $0.17 | 0.28% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.5% | $0.22 | 0.37% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 0.6% | $0.19 | 0.32% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 0.6% | $0.20 | 0.34% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 0.6% | $0.22 | 0.36% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 0.9% | $0.35 | 0.58% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 0.9% | $0.15 | 0.26% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 0.9% | $0.20 | 0.33% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 1.1% | $0.53 | 0.90% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 1.2% | $0.33 | 0.55% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 1.3% | $0.43 | 0.73% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 1.4% | $0.64 | 1.09% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 5 | 6.4min | 1.4% | $1.35 | 2.29% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 1.9% | $0.88 | 1.49% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 2.0% | $0.85 | 1.43% |
| fixture-rework | bash | opus46-200k-cli2.1.132 | 4 | 9.0min | 2.0% | $2.23 | 3.77% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 2.9% | $0.70 | 1.18% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.1% | $0.03 | 0.05% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.1% | $0.03 | 0.05% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.03 | 0.05% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.04 | 0.06% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.05 | 0.08% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.1% | $0.05 | 0.08% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.05 | 0.08% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.2% | $0.05 | 0.09% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.2% | $0.06 | 0.10% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.2% | $0.07 | 0.13% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.3% | $0.10 | 0.17% |
| repeated-test-reruns | typescript-bun | opus46-200k-cli2.1.132 | 1 | 0.7min | 0.1% | $0.13 | 0.22% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.4% | $0.15 | 0.25% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 0.9% | $0.15 | 0.26% |
| fixture-rework | powershell | opus46-200k-cli2.1.132 | 1 | 0.8min | 0.2% | $0.16 | 0.27% |
| repeated-test-reruns | bash | opus46-200k-cli2.1.132 | 1 | 2.0min | 0.4% | $0.16 | 0.27% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.5% | $0.17 | 0.28% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.4% | $0.17 | 0.29% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.4% | $0.17 | 0.29% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 0.6% | $0.19 | 0.32% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.4% | $0.19 | 0.33% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 0.9% | $0.20 | 0.33% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 0.6% | $0.20 | 0.34% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.4% | $0.20 | 0.34% |
| repeated-test-reruns | powershell | opus46-200k-cli2.1.132 | 1 | 1.0min | 0.2% | $0.21 | 0.36% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 0.6% | $0.22 | 0.36% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.5% | $0.22 | 0.37% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 1.2% | $0.33 | 0.55% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 0.9% | $0.35 | 0.58% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 2 | 1.8min | 0.4% | $0.38 | 0.64% |
| actionlint-fix-cycles | bash | opus46-200k-cli2.1.132 | 1 | 1.7min | 0.4% | $0.42 | 0.70% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 1.3% | $0.43 | 0.73% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 1.1% | $0.53 | 0.90% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 1.4% | $0.64 | 1.09% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 2.9% | $0.70 | 1.18% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 2.0% | $0.85 | 1.43% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 1.9% | $0.88 | 1.49% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 5 | 6.4min | 1.4% | $1.35 | 2.29% |
| fixture-rework | bash | opus46-200k-cli2.1.132 | 4 | 9.0min | 2.0% | $2.23 | 3.77% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 0.9% | $0.20 | 0.33% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.1% | $0.05 | 0.08% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.1% | $0.03 | 0.05% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 1.3% | $0.43 | 0.73% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.3% | $0.10 | 0.17% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.03 | 0.05% |
| repeated-test-reruns | bash | opus46-200k-cli2.1.132 | 1 | 2.0min | 0.4% | $0.16 | 0.27% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.5% | $0.17 | 0.28% |
| repeated-test-reruns | powershell | opus46-200k-cli2.1.132 | 1 | 1.0min | 0.2% | $0.21 | 0.36% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.2% | $0.05 | 0.09% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.2% | $0.07 | 0.13% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.05 | 0.08% |
| repeated-test-reruns | typescript-bun | opus46-200k-cli2.1.132 | 1 | 0.7min | 0.1% | $0.13 | 0.22% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.1% | $0.03 | 0.05% |
| fixture-rework | powershell | opus46-200k-cli2.1.132 | 1 | 0.8min | 0.2% | $0.16 | 0.27% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.2% | $0.06 | 0.10% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.4% | $0.17 | 0.29% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.4% | $0.15 | 0.25% |
| actionlint-fix-cycles | bash | opus46-200k-cli2.1.132 | 1 | 1.7min | 0.4% | $0.42 | 0.70% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.05 | 0.08% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.1% | $0.04 | 0.06% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 0.9% | $0.15 | 0.26% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.4% | $0.19 | 0.33% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.4% | $0.17 | 0.29% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 2 | 1.8min | 0.4% | $0.38 | 0.64% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.5% | $0.22 | 0.37% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 0.6% | $0.20 | 0.34% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.4% | $0.20 | 0.34% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 1.1% | $0.53 | 0.90% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 0.9% | $0.35 | 0.58% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 0.6% | $0.19 | 0.32% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 0.6% | $0.22 | 0.36% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 1.2% | $0.33 | 0.55% |
| fixture-rework | bash | opus46-200k-cli2.1.132 | 4 | 9.0min | 2.0% | $2.23 | 3.77% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 2.9% | $0.70 | 1.18% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 1.4% | $0.64 | 1.09% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 5 | 6.4min | 1.4% | $1.35 | 2.29% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 1.9% | $0.88 | 1.49% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 2.0% | $0.85 | 1.43% |

</details>

#### Trap Descriptions

- **act-permission-path-errors**: Files not found or permission denied inside the act Docker container.
- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **actionlint-fix-cycles**: Workflow YAML required 3+ actionlint runs and 2+ fixes to pass.
- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
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
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 1.1% | $0.23 | 0.38% |
| bash | haiku45-200k-cli2.1.132 | 6 | 12 | 15.5min | 3.4% | $1.57 | 2.65% |
| bash | opus46-200k-cli2.1.132 | 6 | 6 | 12.7min | 2.8% | $2.81 | 4.75% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.2% | $0.08 | 0.13% |
| default | haiku45-200k-cli2.1.132 | 5 | 5 | 4.4min | 1.0% | $0.42 | 0.71% |
| default | opus46-200k-cli2.1.132 | 6 | 2 | 1.8min | 0.4% | $0.38 | 0.64% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 2.0% | $0.64 | 1.09% |
| powershell | haiku45-200k-cli2.1.132 | 6 | 7 | 9.2min | 2.0% | $0.67 | 1.13% |
| powershell | opus46-200k-cli2.1.132 | 6 | 2 | 1.8min | 0.4% | $0.37 | 0.62% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.4% | $0.09 | 0.15% |
| powershell-tool | haiku45-200k-cli2.1.132 | 6 | 11 | 21.5min | 4.8% | $1.17 | 1.98% |
| powershell-tool | opus46-200k-cli2.1.132 | 5 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 0.9% | $0.30 | 0.51% |
| typescript-bun | haiku45-200k-cli2.1.132 | 6 | 19 | 24.8min | 5.5% | $2.31 | 3.91% |
| typescript-bun | opus46-200k-cli2.1.132 | 5 | 6 | 7.1min | 1.6% | $1.48 | 2.50% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| powershell-tool | opus46-200k-cli2.1.132 | 5 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.2% | $0.08 | 0.13% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.4% | $0.09 | 0.15% |
| default | opus46-200k-cli2.1.132 | 6 | 2 | 1.8min | 0.4% | $0.38 | 0.64% |
| powershell | opus46-200k-cli2.1.132 | 6 | 2 | 1.8min | 0.4% | $0.37 | 0.62% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 0.9% | $0.30 | 0.51% |
| default | haiku45-200k-cli2.1.132 | 5 | 5 | 4.4min | 1.0% | $0.42 | 0.71% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 1.1% | $0.23 | 0.38% |
| typescript-bun | opus46-200k-cli2.1.132 | 5 | 6 | 7.1min | 1.6% | $1.48 | 2.50% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 2.0% | $0.64 | 1.09% |
| powershell | haiku45-200k-cli2.1.132 | 6 | 7 | 9.2min | 2.0% | $0.67 | 1.13% |
| bash | opus46-200k-cli2.1.132 | 6 | 6 | 12.7min | 2.8% | $2.81 | 4.75% |
| bash | haiku45-200k-cli2.1.132 | 6 | 12 | 15.5min | 3.4% | $1.57 | 2.65% |
| powershell-tool | haiku45-200k-cli2.1.132 | 6 | 11 | 21.5min | 4.8% | $1.17 | 1.98% |
| typescript-bun | haiku45-200k-cli2.1.132 | 6 | 19 | 24.8min | 5.5% | $2.31 | 3.91% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| powershell-tool | opus46-200k-cli2.1.132 | 5 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.2% | $0.08 | 0.13% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.4% | $0.09 | 0.15% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 1.1% | $0.23 | 0.38% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 0.9% | $0.30 | 0.51% |
| powershell | opus46-200k-cli2.1.132 | 6 | 2 | 1.8min | 0.4% | $0.37 | 0.62% |
| default | opus46-200k-cli2.1.132 | 6 | 2 | 1.8min | 0.4% | $0.38 | 0.64% |
| default | haiku45-200k-cli2.1.132 | 5 | 5 | 4.4min | 1.0% | $0.42 | 0.71% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 2.0% | $0.64 | 1.09% |
| powershell | haiku45-200k-cli2.1.132 | 6 | 7 | 9.2min | 2.0% | $0.67 | 1.13% |
| powershell-tool | haiku45-200k-cli2.1.132 | 6 | 11 | 21.5min | 4.8% | $1.17 | 1.98% |
| typescript-bun | opus46-200k-cli2.1.132 | 5 | 6 | 7.1min | 1.6% | $1.48 | 2.50% |
| bash | haiku45-200k-cli2.1.132 | 6 | 12 | 15.5min | 3.4% | $1.57 | 2.65% |
| typescript-bun | haiku45-200k-cli2.1.132 | 6 | 19 | 24.8min | 5.5% | $2.31 | 3.91% |
| bash | opus46-200k-cli2.1.132 | 6 | 6 | 12.7min | 2.8% | $2.81 | 4.75% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 61 | $3.13 | 5.29% |
| Miss | 2 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| bash | opus46-200k | 22.2 | 43.0 | 1.9 | 0.75 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| default | opus46-200k | 4.7 | 18.0 | 3.9 | 1.66 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |
| powershell | opus46-200k | 38.5 | 56.0 | 1.5 | 1.41 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| powershell-tool | opus46-200k | 21.4 | 42.2 | 2.0 | 0.70 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| typescript-bun | opus46-200k | 22.2 | 48.0 | 2.2 | 0.94 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell | opus46-200k | 38.5 | 56.0 | 1.5 | 1.41 |
| typescript-bun | opus46-200k | 22.2 | 48.0 | 2.2 | 0.94 |
| bash | opus46-200k | 22.2 | 43.0 | 1.9 | 0.75 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| powershell-tool | opus46-200k | 21.4 | 42.2 | 2.0 | 0.70 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |
| default | opus46-200k | 4.7 | 18.0 | 3.9 | 1.66 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell | opus46-200k | 38.5 | 56.0 | 1.5 | 1.41 |
| typescript-bun | opus46-200k | 22.2 | 48.0 | 2.2 | 0.94 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| bash | opus46-200k | 22.2 | 43.0 | 1.9 | 0.75 |
| powershell-tool | opus46-200k | 21.4 | 42.2 | 2.0 | 0.70 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| default | opus46-200k | 4.7 | 18.0 | 3.9 | 1.66 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus46-200k | 4.7 | 18.0 | 3.9 | 1.66 |
| powershell | opus46-200k | 38.5 | 56.0 | 1.5 | 1.41 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| typescript-bun | opus46-200k | 22.2 | 48.0 | 2.2 | 0.94 |
| bash | opus46-200k | 22.2 | 43.0 | 1.9 | 0.75 |
| powershell-tool | opus46-200k | 21.4 | 42.2 | 2.0 | 0.70 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Language | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | bash | haiku45-200k | 20 | 26 | 1.3 | 259 | 258 | 1.00 |
| Semantic Version Bumper | default | haiku45-200k | 0 | 0 | 0.0 | 0 | 17 | 0.00 |
| Semantic Version Bumper | powershell | haiku45-200k | 18 | 22 | 1.2 | 197 | 333 | 0.59 |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 20 | 44 | 2.2 | 227 | 599 | 0.38 |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 38 | 76 | 2.0 | 503 | 585 | 0.86 |
| PR Label Assigner | bash | haiku45-200k | 15 | 13 | 0.9 | 145 | 163 | 0.89 |
| PR Label Assigner | default | haiku45-200k | 14 | 19 | 1.4 | 302 | 121 | 2.50 |
| PR Label Assigner | powershell | haiku45-200k | 13 | 22 | 1.7 | 253 | 317 | 0.80 |
| PR Label Assigner | powershell-tool | haiku45-200k | 9 | 17 | 1.9 | 140 | 470 | 0.30 |
| PR Label Assigner | typescript-bun | haiku45-200k | 11 | 15 | 1.4 | 151 | 121 | 1.25 |
| Dependency License Checker | bash | haiku45-200k | 15 | 32 | 2.1 | 983 | 340 | 2.89 |
| Dependency License Checker | default | haiku45-200k | 21 | 49 | 2.3 | 337 | 666 | 0.51 |
| Dependency License Checker | powershell | haiku45-200k | 12 | 30 | 2.5 | 240 | 347 | 0.69 |
| Dependency License Checker | powershell-tool | haiku45-200k | 10 | 31 | 3.1 | 187 | 414 | 0.45 |
| Dependency License Checker | typescript-bun | haiku45-200k | 14 | 33 | 2.4 | 227 | 346 | 0.66 |
| Test Results Aggregator | bash | haiku45-200k | 8 | 8 | 1.0 | 117 | 173 | 0.68 |
| Test Results Aggregator | default | haiku45-200k | 5 | 26 | 5.2 | 176 | 257 | 0.68 |
| Test Results Aggregator | powershell | haiku45-200k | 0 | 0 | 0.0 | 0 | 541 | 0.00 |
| Test Results Aggregator | powershell-tool | haiku45-200k | 22 | 54 | 2.5 | 238 | 319 | 0.75 |
| Test Results Aggregator | typescript-bun | haiku45-200k | 31 | 69 | 2.2 | 398 | 442 | 0.90 |
| Environment Matrix Generator | bash | haiku45-200k | 14 | 3 | 0.2 | 212 | 130 | 1.63 |
| Environment Matrix Generator | default | haiku45-200k | 19 | 41 | 2.2 | 522 | 184 | 2.84 |
| Environment Matrix Generator | powershell | haiku45-200k | 8 | 15 | 1.9 | 146 | 179 | 0.82 |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 12 | 25 | 2.1 | 193 | 137 | 1.41 |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 10 | 25 | 2.5 | 201 | 319 | 0.63 |
| Artifact Cleanup Script | bash | haiku45-200k | 12 | 28 | 2.3 | 166 | 369 | 0.45 |
| Artifact Cleanup Script | default | haiku45-200k | 31 | 26 | 0.8 | 411 | 321 | 1.28 |
| Artifact Cleanup Script | powershell | haiku45-200k | 11 | 24 | 2.2 | 185 | 279 | 0.66 |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 17 | 30 | 1.8 | 220 | 181 | 1.22 |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 9 | 27 | 3.0 | 276 | 380 | 0.73 |
| Secret Rotation Validator | bash | haiku45-200k | 15 | 32 | 2.1 | 134 | 453 | 0.30 |
| Secret Rotation Validator | default | haiku45-200k | 13 | 38 | 2.9 | 270 | 505 | 0.53 |
| Secret Rotation Validator | powershell | haiku45-200k | 0 | 0 | 0.0 | 0 | 590 | 0.00 |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 0 | 0 | 0.0 | 0 | 375 | 0.00 |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 38 | 84 | 2.2 | 560 | 205 | 2.73 |
| Semantic Version Bumper | default | opus46-200k | 8 | 11 | 1.4 | 392 | 227 | 1.73 |
| Semantic Version Bumper | powershell | opus46-200k | 26 | 51 | 2.0 | 196 | 442 | 0.44 |
| Semantic Version Bumper | bash | opus46-200k | 16 | 36 | 2.2 | 155 | 365 | 0.42 |
| Semantic Version Bumper | powershell-tool | opus46-200k | 24 | 34 | 1.4 | 197 | 345 | 0.57 |
| Semantic Version Bumper | typescript-bun | opus46-200k | 44 | 62 | 1.4 | 300 | 540 | 0.56 |
| PR Label Assigner | default | opus46-200k | 0 | 16 | 0.0 | 252 | 120 | 2.10 |
| PR Label Assigner | powershell | opus46-200k | 30 | 42 | 1.4 | 263 | 217 | 1.21 |
| PR Label Assigner | bash | opus46-200k | 0 | 0 | 0.0 | 0 | 405 | 0.00 |
| PR Label Assigner | powershell-tool | opus46-200k | 20 | 36 | 1.8 | 157 | 127 | 1.24 |
| PR Label Assigner | typescript-bun | opus46-200k | 8 | 30 | 3.8 | 189 | 121 | 1.56 |
| Dependency License Checker | default | opus46-200k | 12 | 52 | 4.3 | 420 | 166 | 2.53 |
| Dependency License Checker | powershell | opus46-200k | 29 | 42 | 1.4 | 205 | 450 | 0.46 |
| Dependency License Checker | bash | opus46-200k | 21 | 52 | 2.5 | 168 | 456 | 0.37 |
| Dependency License Checker | powershell-tool | opus46-200k | 31 | 62 | 2.0 | 219 | 275 | 0.80 |
| Dependency License Checker | typescript-bun | opus46-200k | 19 | 46 | 2.4 | 206 | 442 | 0.47 |
| Test Results Aggregator | default | opus46-200k | 2 | 0 | 0.0 | 389 | 261 | 1.49 |
| Test Results Aggregator | powershell | opus46-200k | 59 | 63 | 1.1 | 358 | 412 | 0.87 |
| Test Results Aggregator | bash | opus46-200k | 12 | 26 | 2.2 | 187 | 243 | 0.77 |
| Test Results Aggregator | powershell-tool | opus46-200k | 18 | 55 | 3.1 | 175 | 457 | 0.38 |
| Test Results Aggregator | typescript-bun | opus46-200k | 26 | 62 | 2.4 | 344 | 559 | 0.62 |
| Environment Matrix Generator | default | opus46-200k | 4 | 29 | 7.2 | 301 | 349 | 0.86 |
| Environment Matrix Generator | powershell | opus46-200k | 66 | 69 | 1.0 | 452 | 115 | 3.93 |
| Environment Matrix Generator | bash | opus46-200k | 61 | 58 | 1.0 | 460 | 181 | 2.54 |
| Environment Matrix Generator | powershell-tool | opus46-200k | 14 | 24 | 1.7 | 165 | 328 | 0.50 |
| Environment Matrix Generator | typescript-bun | opus46-200k | 14 | 40 | 2.9 | 266 | 176 | 1.51 |
| Artifact Cleanup Script | default | opus46-200k | 2 | 0 | 0.0 | 420 | 335 | 1.25 |
| Artifact Cleanup Script | powershell | opus46-200k | 21 | 69 | 3.3 | 307 | 197 | 1.56 |
| Artifact Cleanup Script | bash | opus46-200k | 23 | 86 | 3.7 | 216 | 546 | 0.40 |

</details>

## Per-Run Results

*Tests Quality = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |


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
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| PR Label Assigner | powershell | opus46-200k | 12.0min | 21 | 1 | $1.96 | — | powershell | ok |
| PR Label Assigner | bash | opus46-200k | 6.7min | 73 | 10 | $1.90 | — | bash | ok |
| PR Label Assigner | powershell-tool | opus46-200k | 10.7min | 20 | 1 | $1.70 | — | powershell | ok |
| PR Label Assigner | typescript-bun | opus46-200k | 5.5min | 34 | 0 | $0.98 | — | typescript | ok |
| Dependency License Checker | default | opus46-200k | 4.2min | 29 | 3 | $0.91 | — | python | ok |
| Dependency License Checker | powershell | opus46-200k | 6.4min | 38 | 0 | $1.35 | — | powershell | ok |
| Dependency License Checker | bash | opus46-200k | 6.4min | 57 | 7 | $1.59 | — | bash | ok |
| Dependency License Checker | powershell-tool | opus46-200k | 6.1min | 38 | 3 | $1.45 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus46-200k | 4.7min | 30 | 1 | $1.09 | — | typescript | ok |
| Test Results Aggregator | default | opus46-200k | 6.1min | 36 | 3 | $1.36 | — | python | ok |
| Test Results Aggregator | powershell | opus46-200k | 11.9min | 26 | 2 | $2.31 | — | powershell | ok |
| Test Results Aggregator | bash | opus46-200k | 19.3min | 47 | 7 | $1.54 | — | bash | ok |
| Test Results Aggregator | powershell-tool | opus46-200k | 8.5min | 24 | 1 | $1.59 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | opus46-200k | 9.0min | 62 | 5 | $2.16 | — | typescript | ok |
| Environment Matrix Generator | default | opus46-200k | 7.3min | 30 | 2 | $1.40 | — | python | ok |
| Environment Matrix Generator | powershell | opus46-200k | 13.1min | 40 | 0 | $2.85 | — | powershell | ok |
| Environment Matrix Generator | bash | opus46-200k | 7.5min | 50 | 3 | $1.67 | — | bash | ok |
| Environment Matrix Generator | powershell-tool | opus46-200k | 3.9min | 25 | 1 | $0.87 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus46-200k | 6.0min | 29 | 3 | $1.16 | — | typescript | ok |
| Artifact Cleanup Script | default | opus46-200k | 8.3min | 34 | 3 | $1.61 | — | python | ok |
| Artifact Cleanup Script | powershell | opus46-200k | 5.2min | 27 | 2 | $1.14 | — | powershell | ok |
| Artifact Cleanup Script | bash | opus46-200k | 5.2min | 40 | 3 | $1.48 | — | bash | ok |

</details>

## Notes

### Tiers

- **Duration bands:** **A+** ≤1.06×, **A** ≤1.11×, **A-** ≤1.18×, **B+** ≤1.24×, **B** ≤1.31×, **B-** ≤1.38×, **C+** ≤1.46×, **C** ≤1.54×, **C-** ≤1.63×, **D+** ≤1.72×, **D** ≤1.81×, **D-** ≤1.91×, **F** >1.91×
- **Cost bands:** **A+** ≤1.14×, **A** ≤1.29×, **A-** ≤1.47×, **B+** ≤1.67×, **B** ≤1.90×, **B-** ≤2.16×, **C+** ≤2.45×, **C** ≤2.79×, **C-** ≤3.17×, **D+** ≤3.61×, **D** ≤4.10×, **D-** ≤4.66×, **F** >4.66×

*Tests/Workflow Craft bands are absolute Overall score bands:* **A+** ≥4.7, **A** ≥4.4, **A-** ≥4.1, **B+** ≥3.8, **B** ≥3.5, **B-** ≥3.2, **C+** ≥2.9, **C** ≥2.6, **C-** ≥2.3, **D+** ≥2.0, **D** ≥1.7, **D-** ≥1.4, **F** <1.4, `—` = no data.*

### CLI Version Legend

| Variant label | CLI version | Tasks | Languages |
|---------------|-------------|-------|-----------|
| haiku45-200k | 2.1.131 | 11-semantic-version-bumper, 12-pr-label-assigner | All |
| haiku45-200k | 2.1.132 | 12-pr-label-assigner, 13-dependency-license-checker, 15-test-results-aggregator, 16-environment-matrix-generator, 17-artifact-cleanup-script, 18-secret-rotation-validator | All |
| opus46-200k | 2.1.132 | 11-semantic-version-bumper, 12-pr-label-assigner, 13-dependency-license-checker, 15-test-results-aggregator, 16-environment-matrix-generator, 17-artifact-cleanup-script | All |

---
*Generated by generate_results.py — benchmark instructions v4*