# Benchmark Results: Language Comparison

**Last updated:** 2026-05-06 10:17:36 PM ET — 41/70 runs completed, 29 remaining; total cost $25.10; total agent time 274.9 min.

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
| default | haiku45-200k | A (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | B (5.5min) | A ($0.48) | — | — |
| typescript-bun | opus46-200k | A+ (4.5min) | C- ($1.00) | — | — |
| powershell | haiku45-200k* | C- (6.4min) | A- ($0.54) | — | — |
| powershell-tool | haiku45-200k | D (7.2min) | A ($0.48) | — | — |
| default | opus46-200k | B+ (5.2min) | D+ ($1.13) | — | — |
| powershell-tool | opus46-200k | B+ (5.1min) | D ($1.22) | — | — |
| powershell | opus46-200k | C+ (6.0min) | D+ ($1.12) | — | — |
| bash | haiku45-200k | D- (7.6min) | B- ($0.70) | — | — |
| bash | opus46-200k | C+ (5.9min) | D- ($1.52) | — | — |


<details>
<summary>Sorted by Duration tier (best-first), then avg of Cost/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| typescript-bun | opus46-200k | A+ (4.5min) | C- ($1.00) | — | — |
| default | haiku45-200k | A (4.8min) | A+ ($0.38) | — | — |
| default | opus46-200k | B+ (5.2min) | D+ ($1.13) | — | — |
| powershell-tool | opus46-200k | B+ (5.1min) | D ($1.22) | — | — |
| typescript-bun | haiku45-200k | B (5.5min) | A ($0.48) | — | — |
| powershell | opus46-200k | C+ (6.0min) | D+ ($1.12) | — | — |
| bash | opus46-200k | C+ (5.9min) | D- ($1.52) | — | — |
| powershell | haiku45-200k* | C- (6.4min) | A- ($0.54) | — | — |
| powershell-tool | haiku45-200k | D (7.2min) | A ($0.48) | — | — |
| bash | haiku45-200k | D- (7.6min) | B- ($0.70) | — | — |

</details>

<details>
<summary>Sorted by Cost tier (best-first), then avg of Duration/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | B (5.5min) | A ($0.48) | — | — |
| powershell-tool | haiku45-200k | D (7.2min) | A ($0.48) | — | — |
| powershell | haiku45-200k* | C- (6.4min) | A- ($0.54) | — | — |
| bash | haiku45-200k | D- (7.6min) | B- ($0.70) | — | — |
| typescript-bun | opus46-200k | A+ (4.5min) | C- ($1.00) | — | — |
| default | opus46-200k | B+ (5.2min) | D+ ($1.13) | — | — |
| powershell | opus46-200k | C+ (6.0min) | D+ ($1.12) | — | — |
| powershell-tool | opus46-200k | B+ (5.1min) | D ($1.22) | — | — |
| bash | opus46-200k | C+ (5.9min) | D- ($1.52) | — | — |

</details>

<details>
<summary>Sorted by Tests Quality tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | B (5.5min) | A ($0.48) | — | — |
| typescript-bun | opus46-200k | A+ (4.5min) | C- ($1.00) | — | — |
| powershell | haiku45-200k* | C- (6.4min) | A- ($0.54) | — | — |
| powershell-tool | haiku45-200k | D (7.2min) | A ($0.48) | — | — |
| default | opus46-200k | B+ (5.2min) | D+ ($1.13) | — | — |
| powershell-tool | opus46-200k | B+ (5.1min) | D ($1.22) | — | — |
| powershell | opus46-200k | C+ (6.0min) | D+ ($1.12) | — | — |
| bash | haiku45-200k | D- (7.6min) | B- ($0.70) | — | — |
| bash | opus46-200k | C+ (5.9min) | D- ($1.52) | — | — |

</details>

<details>
<summary>Sorted by Workflow Craft tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A (4.8min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | B (5.5min) | A ($0.48) | — | — |
| typescript-bun | opus46-200k | A+ (4.5min) | C- ($1.00) | — | — |
| powershell | haiku45-200k* | C- (6.4min) | A- ($0.54) | — | — |
| powershell-tool | haiku45-200k | D (7.2min) | A ($0.48) | — | — |
| default | opus46-200k | B+ (5.2min) | D+ ($1.13) | — | — |
| powershell-tool | opus46-200k | B+ (5.1min) | D ($1.22) | — | — |
| powershell | opus46-200k | C+ (6.0min) | D+ ($1.12) | — | — |
| bash | haiku45-200k | D- (7.6min) | B- ($0.70) | — | — |
| bash | opus46-200k | C+ (5.9min) | D- ($1.52) | — | — |

</details>

- **Estimated time remaining:** 429.2min
- **Estimated total cost:** $42.85

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
| bash | opus46-200k | 1 | 5.9min | 5.9min | 3.0 | 53 | $1.52 | $1.52 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | opus46-200k | 2 | 5.2min | 4.6min | 2.0 | 36 | $1.13 | $2.27 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus46-200k | 1 | 6.0min | 6.0min | 2.0 | 28 | $1.12 | $1.12 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | opus46-200k | 1 | 5.1min | 5.1min | 1.0 | 33 | $1.22 | $1.22 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus46-200k | 1 | 4.5min | 3.3min | 1.0 | 31 | $1.00 | $1.00 | — | — |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| typescript-bun | opus46-200k | 1 | 4.5min | 3.3min | 1.0 | 31 | $1.00 | $1.00 | — | — |
| powershell | opus46-200k | 1 | 6.0min | 6.0min | 2.0 | 28 | $1.12 | $1.12 | — | — |
| default | opus46-200k | 2 | 5.2min | 4.6min | 2.0 | 36 | $1.13 | $2.27 | — | — |
| powershell-tool | opus46-200k | 1 | 5.1min | 5.1min | 1.0 | 33 | $1.22 | $1.22 | — | — |
| bash | opus46-200k | 1 | 5.9min | 5.9min | 3.0 | 53 | $1.52 | $1.52 | — | — |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| typescript-bun | opus46-200k | 1 | 4.5min | 3.3min | 1.0 | 31 | $1.00 | $1.00 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| powershell-tool | opus46-200k | 1 | 5.1min | 5.1min | 1.0 | 33 | $1.22 | $1.22 | — | — |
| default | opus46-200k | 2 | 5.2min | 4.6min | 2.0 | 36 | $1.13 | $2.27 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| bash | opus46-200k | 1 | 5.9min | 5.9min | 3.0 | 53 | $1.52 | $1.52 | — | — |
| powershell | opus46-200k | 1 | 6.0min | 6.0min | 2.0 | 28 | $1.12 | $1.12 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| typescript-bun | opus46-200k | 1 | 4.5min | 3.3min | 1.0 | 31 | $1.00 | $1.00 | — | — |
| default | opus46-200k | 2 | 5.2min | 4.6min | 2.0 | 36 | $1.13 | $2.27 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| powershell-tool | opus46-200k | 1 | 5.1min | 5.1min | 1.0 | 33 | $1.22 | $1.22 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| bash | opus46-200k | 1 | 5.9min | 5.9min | 3.0 | 53 | $1.52 | $1.52 | — | — |
| powershell | opus46-200k | 1 | 6.0min | 6.0min | 2.0 | 28 | $1.12 | $1.12 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| powershell-tool | opus46-200k | 1 | 5.1min | 5.1min | 1.0 | 33 | $1.22 | $1.22 | — | — |
| typescript-bun | opus46-200k | 1 | 4.5min | 3.3min | 1.0 | 31 | $1.00 | $1.00 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| default | opus46-200k | 2 | 5.2min | 4.6min | 2.0 | 36 | $1.13 | $2.27 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus46-200k | 1 | 6.0min | 6.0min | 2.0 | 28 | $1.12 | $1.12 | — | — |
| bash | opus46-200k | 1 | 5.9min | 5.9min | 3.0 | 53 | $1.52 | $1.52 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| powershell | opus46-200k | 1 | 6.0min | 6.0min | 2.0 | 28 | $1.12 | $1.12 | — | — |
| typescript-bun | opus46-200k | 1 | 4.5min | 3.3min | 1.0 | 31 | $1.00 | $1.00 | — | — |
| powershell-tool | opus46-200k | 1 | 5.1min | 5.1min | 1.0 | 33 | $1.22 | $1.22 | — | — |
| default | opus46-200k | 2 | 5.2min | 4.6min | 2.0 | 36 | $1.13 | $2.27 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| bash | opus46-200k | 1 | 5.9min | 5.9min | 3.0 | 53 | $1.52 | $1.52 | — | — |
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 1 | 5.9min | 5.9min | 3.0 | 53 | $1.52 | $1.52 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | opus46-200k | 2 | 5.2min | 4.6min | 2.0 | 36 | $1.13 | $2.27 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus46-200k | 1 | 6.0min | 6.0min | 2.0 | 28 | $1.12 | $1.12 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | opus46-200k | 1 | 5.1min | 5.1min | 1.0 | 33 | $1.22 | $1.22 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus46-200k | 1 | 4.5min | 3.3min | 1.0 | 31 | $1.00 | $1.00 | — | — |

</details>

<details>
<summary>Sorted by deliverable-quality score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 7 | 7.6min | 7.6min | 4.9 | 70 | $0.70 | $4.87 | — | — |
| bash | opus46-200k | 1 | 5.9min | 5.9min | 3.0 | 53 | $1.52 | $1.52 | — | — |
| default | haiku45-200k | 7 | 4.8min | 4.8min | 3.6 | 40 | $0.38 | $2.68 | — | — |
| default | opus46-200k | 2 | 5.2min | 4.6min | 2.0 | 36 | $1.13 | $2.27 | — | — |
| powershell | haiku45-200k* | 6 | 6.4min | 6.4min | 2.0 | 52 | $0.54 | $3.23 | — | — |
| powershell | opus46-200k | 1 | 6.0min | 6.0min | 2.0 | 28 | $1.12 | $1.12 | — | — |
| powershell-tool | haiku45-200k | 7 | 7.2min | 7.2min | 1.4 | 46 | $0.48 | $3.34 | — | — |
| powershell-tool | opus46-200k | 1 | 5.1min | 5.1min | 1.0 | 33 | $1.22 | $1.22 | — | — |
| typescript-bun | haiku45-200k | 7 | 5.5min | 5.5min | 4.0 | 50 | $0.48 | $3.34 | — | — |
| typescript-bun | opus46-200k | 1 | 4.5min | 3.3min | 1.0 | 31 | $1.00 | $1.00 | — | — |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

*`% of Test Time Saved` = `net / (net + test_time) × 100` — the share of total (would-have-been + actually-spent) test time that hooks eliminated. Bounded in (-∞, 100%) without an artificial cap; near 100% means hooks substituted for almost all of the hypothetical test work.*

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 2.8% | 0.2min | 0.1% | 7.4min | 2.7% | 3.5min | 67.9% |
| bash | opus46-200k-cli2.1.132 | 19 | 2 | 10.5% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.2min | 61.4% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.0min | 91.1% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.6% | 0.2min | 0.1% | 1.4min | 0.5% | 3.0min | 32.2% |
| default | opus46-200k-cli2.1.132 | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 0.4min | -21.9% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.2% | 0.2min | 0.1% | 0.4min | 0.1% | 0.8min | 31.9% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.8% | 0.8min | 0.3% | 1.5min | 0.6% | 6.0min | 20.1% |
| powershell | opus46-200k-cli2.1.132 | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 1.0min | -8.7% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.1% | -0.3min | -0.1% | 5.6min | -5.8% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.6% | 0.7min | 0.2% | 1.1min | 0.4% | 3.2min | 25.3% |
| powershell-tool | opus46-200k-cli2.1.132 | 12 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 0.2min | -66.3% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.5% | 1.5min | 0.6% | -0.2min | -0.1% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 2.1% | 5.2min | 1.9% | 0.7min | 0.3% | 1.7min | 29.1% |
| typescript-bun | opus46-200k-cli2.1.132 | 14 | 6 | 42.9% | 0.8min | 0.3% | 0.1min | 0.0% | 0.7min | 0.3% | 0.5min | 58.6% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 2.8% | 0.2min | 0.1% | 7.4min | 2.7% | 3.5min | 67.9% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.8% | 0.8min | 0.3% | 1.5min | 0.6% | 6.0min | 20.1% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.6% | 0.2min | 0.1% | 1.4min | 0.5% | 3.0min | 32.2% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.6% | 0.7min | 0.2% | 1.1min | 0.4% | 3.2min | 25.3% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 2.1% | 5.2min | 1.9% | 0.7min | 0.3% | 1.7min | 29.1% |
| typescript-bun | opus46-200k-cli2.1.132 | 14 | 6 | 42.9% | 0.8min | 0.3% | 0.1min | 0.0% | 0.7min | 0.3% | 0.5min | 58.6% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.2% | 0.2min | 0.1% | 0.4min | 0.1% | 0.8min | 31.9% |
| bash | opus46-200k-cli2.1.132 | 19 | 2 | 10.5% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.2min | 61.4% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| powershell-tool | opus46-200k-cli2.1.132 | 12 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 0.2min | -66.3% |
| powershell | opus46-200k-cli2.1.132 | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 1.0min | -8.7% |
| default | opus46-200k-cli2.1.132 | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 0.4min | -21.9% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.5% | 1.5min | 0.6% | -0.2min | -0.1% | 0.5min | -57.5% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.1% | -0.3min | -0.1% | 5.6min | -5.8% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 2.8% | 0.2min | 0.1% | 7.4min | 2.7% | 3.5min | 67.9% |
| bash | opus46-200k-cli2.1.132 | 19 | 2 | 10.5% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.2min | 61.4% |
| typescript-bun | opus46-200k-cli2.1.132 | 14 | 6 | 42.9% | 0.8min | 0.3% | 0.1min | 0.0% | 0.7min | 0.3% | 0.5min | 58.6% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.6% | 0.2min | 0.1% | 1.4min | 0.5% | 3.0min | 32.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.2% | 0.2min | 0.1% | 0.4min | 0.1% | 0.8min | 31.9% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 2.1% | 5.2min | 1.9% | 0.7min | 0.3% | 1.7min | 29.1% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.6% | 0.7min | 0.2% | 1.1min | 0.4% | 3.2min | 25.3% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.8% | 0.8min | 0.3% | 1.5min | 0.6% | 6.0min | 20.1% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.1% | -0.3min | -0.1% | 5.6min | -5.8% |
| powershell | opus46-200k-cli2.1.132 | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 1.0min | -8.7% |
| default | opus46-200k-cli2.1.132 | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 0.4min | -21.9% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.5% | 1.5min | 0.6% | -0.2min | -0.1% | 0.5min | -57.5% |
| powershell-tool | opus46-200k-cli2.1.132 | 12 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 0.2min | -66.3% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus46-200k-cli2.1.132 | 14 | 6 | 42.9% | 0.8min | 0.3% | 0.1min | 0.0% | 0.7min | 0.3% | 0.5min | 58.6% |
| typescript-bun | haiku45-200k-cli2.1.132 | 108 | 44 | 40.7% | 5.9min | 2.1% | 5.2min | 1.9% | 0.7min | 0.3% | 1.7min | 29.1% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.5% | 1.5min | 0.6% | -0.2min | -0.1% | 0.5min | -57.5% |
| bash | haiku45-200k-cli2.1.132 | 124 | 38 | 30.6% | 7.6min | 2.8% | 0.2min | 0.1% | 7.4min | 2.7% | 3.5min | 67.9% |
| default | haiku45-200k-cli2.1.132 | 74 | 12 | 16.2% | 1.6min | 0.6% | 0.2min | 0.1% | 1.4min | 0.5% | 3.0min | 32.2% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.0min | 91.1% |
| bash | opus46-200k-cli2.1.132 | 19 | 2 | 10.5% | 0.4min | 0.1% | 0.1min | 0.0% | 0.3min | 0.1% | 0.2min | 61.4% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.2% | 0.2min | 0.1% | 0.4min | 0.1% | 0.8min | 31.9% |
| powershell | haiku45-200k-cli2.1.132 | 109 | 4 | 3.7% | 2.3min | 0.8% | 0.8min | 0.3% | 1.5min | 0.6% | 6.0min | 20.1% |
| powershell-tool | haiku45-200k-cli2.1.132 | 102 | 3 | 2.9% | 1.8min | 0.6% | 0.7min | 0.2% | 1.1min | 0.4% | 3.2min | 25.3% |
| default | opus46-200k-cli2.1.132 | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 0.4min | -21.9% |
| powershell | opus46-200k-cli2.1.132 | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 1.0min | -8.7% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.1% | -0.3min | -0.1% | 5.6min | -5.8% |
| powershell-tool | opus46-200k-cli2.1.132 | 12 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.0% | -0.1min | -0.0% | 0.2min | -66.3% |

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 1.5% | $0.20 | 0.78% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 1.9% | $0.53 | 2.11% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.2% | $0.05 | 0.19% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.1% | $0.03 | 0.12% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 2.2% | $0.43 | 1.72% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 1.4% | $0.35 | 1.37% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 4.7% | $0.70 | 2.78% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.5% | $0.10 | 0.41% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 1.0% | $0.22 | 0.86% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.03 | 0.12% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 2.3% | $0.64 | 2.57% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.8% | $0.17 | 0.66% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 1.9% | $0.33 | 1.30% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.4% | $0.05 | 0.22% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.4% | $0.07 | 0.30% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.05 | 0.20% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 3.2% | $0.88 | 3.50% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.7% | $0.15 | 0.59% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 3.2% | $0.85 | 3.37% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 1 | 1.2min | 0.4% | $0.27 | 1.06% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.8% | $0.22 | 0.87% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.05 | 0.19% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 1.0% | $0.19 | 0.76% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 1.0% | $0.20 | 0.79% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.7% | $0.19 | 0.77% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.2% | $0.03 | 0.12% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.6% | $0.17 | 0.69% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 1 | 1.2min | 0.5% | $0.28 | 1.12% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.3% | $0.06 | 0.23% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.7% | $0.17 | 0.67% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.04 | 0.14% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 1.5% | $0.15 | 0.61% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.7% | $0.20 | 0.80% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.1% | $0.03 | 0.12% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.2% | $0.03 | 0.12% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.2% | $0.05 | 0.19% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.04 | 0.14% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.03 | 0.12% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.05 | 0.20% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.05 | 0.19% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.3% | $0.06 | 0.23% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.4% | $0.05 | 0.22% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.4% | $0.07 | 0.30% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 1 | 1.2min | 0.4% | $0.27 | 1.06% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 1 | 1.2min | 0.5% | $0.28 | 1.12% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.5% | $0.10 | 0.41% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.6% | $0.17 | 0.69% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.7% | $0.15 | 0.59% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.7% | $0.19 | 0.77% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.7% | $0.17 | 0.67% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.7% | $0.20 | 0.80% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.8% | $0.17 | 0.66% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.8% | $0.22 | 0.87% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 1.0% | $0.19 | 0.76% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 1.0% | $0.20 | 0.79% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 1.0% | $0.22 | 0.86% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 1.4% | $0.35 | 1.37% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 1.5% | $0.15 | 0.61% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 1.5% | $0.20 | 0.78% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 1.9% | $0.53 | 2.11% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 1.9% | $0.33 | 1.30% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 2.2% | $0.43 | 1.72% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 2.3% | $0.64 | 2.57% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 3.2% | $0.88 | 3.50% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 3.2% | $0.85 | 3.37% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 4.7% | $0.70 | 2.78% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.1% | $0.03 | 0.12% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.2% | $0.03 | 0.12% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.03 | 0.12% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.04 | 0.14% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.05 | 0.19% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.2% | $0.05 | 0.19% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.05 | 0.20% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.4% | $0.05 | 0.22% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.3% | $0.06 | 0.23% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.4% | $0.07 | 0.30% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.5% | $0.10 | 0.41% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.7% | $0.15 | 0.59% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 1.5% | $0.15 | 0.61% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.8% | $0.17 | 0.66% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.7% | $0.17 | 0.67% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.6% | $0.17 | 0.69% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 1.0% | $0.19 | 0.76% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.7% | $0.19 | 0.77% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 1.5% | $0.20 | 0.78% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 1.0% | $0.20 | 0.79% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.7% | $0.20 | 0.80% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 1.0% | $0.22 | 0.86% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.8% | $0.22 | 0.87% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 1 | 1.2min | 0.4% | $0.27 | 1.06% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 1 | 1.2min | 0.5% | $0.28 | 1.12% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 1.9% | $0.33 | 1.30% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 1.4% | $0.35 | 1.37% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 2.2% | $0.43 | 1.72% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 1.9% | $0.53 | 2.11% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 2.3% | $0.64 | 2.57% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 4.7% | $0.70 | 2.78% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 3.2% | $0.85 | 3.37% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 3.2% | $0.88 | 3.50% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 1.5% | $0.20 | 0.78% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.2% | $0.05 | 0.19% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.1% | $0.03 | 0.12% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 2.2% | $0.43 | 1.72% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.5% | $0.10 | 0.41% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.03 | 0.12% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 0.8% | $0.17 | 0.66% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.4% | $0.05 | 0.22% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.4% | $0.07 | 0.30% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.05 | 0.20% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 0.7% | $0.15 | 0.59% |
| ts-type-error-fix-cycles | typescript-bun | opus46-200k-cli2.1.132 | 1 | 1.2min | 0.4% | $0.27 | 1.06% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.05 | 0.19% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.2% | $0.03 | 0.12% |
| fixture-rework | default | opus46-200k-cli2.1.132 | 1 | 1.2min | 0.5% | $0.28 | 1.12% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.3% | $0.06 | 0.23% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 0.7% | $0.17 | 0.67% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.2% | $0.04 | 0.14% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 1.5% | $0.15 | 0.61% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 0.8% | $0.22 | 0.87% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 1.0% | $0.20 | 0.79% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.7% | $0.19 | 0.77% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.6% | $0.17 | 0.69% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 0.7% | $0.20 | 0.80% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 1.9% | $0.53 | 2.11% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 3 | 3.9min | 1.4% | $0.35 | 1.37% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 2.7min | 1.0% | $0.19 | 0.76% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 2.7min | 1.0% | $0.22 | 0.86% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 1.9% | $0.33 | 1.30% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 5 | 12.8min | 4.7% | $0.70 | 2.78% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 5 | 6.3min | 2.3% | $0.64 | 2.57% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.7min | 3.2% | $0.88 | 3.50% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 6 | 8.8min | 3.2% | $0.85 | 3.37% |

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
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 1.8% | $0.23 | 0.90% |
| bash | haiku45-200k-cli2.1.132 | 6 | 12 | 15.5min | 5.6% | $1.57 | 6.24% |
| bash | opus46-200k-cli2.1.132 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.4% | $0.08 | 0.31% |
| default | haiku45-200k-cli2.1.132 | 5 | 5 | 4.4min | 1.6% | $0.42 | 1.67% |
| default | opus46-200k-cli2.1.132 | 2 | 1 | 1.2min | 0.5% | $0.28 | 1.12% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 3.3% | $0.64 | 2.57% |
| powershell | haiku45-200k-cli2.1.132 | 6 | 7 | 9.2min | 3.3% | $0.67 | 2.67% |
| powershell | opus46-200k-cli2.1.132 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.6% | $0.09 | 0.36% |
| powershell-tool | haiku45-200k-cli2.1.132 | 6 | 11 | 21.5min | 7.8% | $1.17 | 4.68% |
| powershell-tool | opus46-200k-cli2.1.132 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 1.5% | $0.30 | 1.20% |
| typescript-bun | haiku45-200k-cli2.1.132 | 6 | 19 | 24.8min | 9.0% | $2.31 | 9.21% |
| typescript-bun | opus46-200k-cli2.1.132 | 1 | 1 | 1.2min | 0.4% | $0.27 | 1.06% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| bash | opus46-200k-cli2.1.132 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus46-200k-cli2.1.132 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus46-200k-cli2.1.132 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.4% | $0.08 | 0.31% |
| typescript-bun | opus46-200k-cli2.1.132 | 1 | 1 | 1.2min | 0.4% | $0.27 | 1.06% |
| default | opus46-200k-cli2.1.132 | 2 | 1 | 1.2min | 0.5% | $0.28 | 1.12% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.6% | $0.09 | 0.36% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 1.5% | $0.30 | 1.20% |
| default | haiku45-200k-cli2.1.132 | 5 | 5 | 4.4min | 1.6% | $0.42 | 1.67% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 1.8% | $0.23 | 0.90% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 3.3% | $0.64 | 2.57% |
| powershell | haiku45-200k-cli2.1.132 | 6 | 7 | 9.2min | 3.3% | $0.67 | 2.67% |
| bash | haiku45-200k-cli2.1.132 | 6 | 12 | 15.5min | 5.6% | $1.57 | 6.24% |
| powershell-tool | haiku45-200k-cli2.1.132 | 6 | 11 | 21.5min | 7.8% | $1.17 | 4.68% |
| typescript-bun | haiku45-200k-cli2.1.132 | 6 | 19 | 24.8min | 9.0% | $2.31 | 9.21% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| bash | opus46-200k-cli2.1.132 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus46-200k-cli2.1.132 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus46-200k-cli2.1.132 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.4% | $0.08 | 0.31% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.6% | $0.09 | 0.36% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 1.8% | $0.23 | 0.90% |
| typescript-bun | opus46-200k-cli2.1.132 | 1 | 1 | 1.2min | 0.4% | $0.27 | 1.06% |
| default | opus46-200k-cli2.1.132 | 2 | 1 | 1.2min | 0.5% | $0.28 | 1.12% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 1.5% | $0.30 | 1.20% |
| default | haiku45-200k-cli2.1.132 | 5 | 5 | 4.4min | 1.6% | $0.42 | 1.67% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 3.3% | $0.64 | 2.57% |
| powershell | haiku45-200k-cli2.1.132 | 6 | 7 | 9.2min | 3.3% | $0.67 | 2.67% |
| powershell-tool | haiku45-200k-cli2.1.132 | 6 | 11 | 21.5min | 7.8% | $1.17 | 4.68% |
| bash | haiku45-200k-cli2.1.132 | 6 | 12 | 15.5min | 5.6% | $1.57 | 6.24% |
| typescript-bun | haiku45-200k-cli2.1.132 | 6 | 19 | 24.8min | 9.0% | $2.31 | 9.21% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 39 | $1.41 | 5.60% |
| Miss | 2 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| bash | opus46-200k | 16.0 | 36.0 | 2.2 | 0.42 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| default | opus46-200k | 4.0 | 13.5 | 3.4 | 1.92 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |
| powershell | opus46-200k | 26.0 | 51.0 | 2.0 | 0.44 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| powershell-tool | opus46-200k | 24.0 | 34.0 | 1.4 | 0.57 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| typescript-bun | opus46-200k | 44.0 | 62.0 | 1.4 | 0.56 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus46-200k | 44.0 | 62.0 | 1.4 | 0.56 |
| powershell | opus46-200k | 26.0 | 51.0 | 2.0 | 0.44 |
| powershell-tool | opus46-200k | 24.0 | 34.0 | 1.4 | 0.57 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| bash | opus46-200k | 16.0 | 36.0 | 2.2 | 0.42 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |
| default | opus46-200k | 4.0 | 13.5 | 3.4 | 1.92 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus46-200k | 44.0 | 62.0 | 1.4 | 0.56 |
| powershell | opus46-200k | 26.0 | 51.0 | 2.0 | 0.44 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| bash | opus46-200k | 16.0 | 36.0 | 2.2 | 0.42 |
| powershell-tool | opus46-200k | 24.0 | 34.0 | 1.4 | 0.57 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |
| default | opus46-200k | 4.0 | 13.5 | 3.4 | 1.92 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus46-200k | 4.0 | 13.5 | 3.4 | 1.92 |
| default | haiku45-200k | 14.7 | 28.4 | 1.9 | 1.19 |
| bash | haiku45-200k | 14.1 | 20.3 | 1.4 | 1.12 |
| typescript-bun | haiku45-200k | 21.6 | 47.0 | 2.2 | 1.11 |
| powershell-tool | haiku45-200k | 12.9 | 28.7 | 2.2 | 0.64 |
| powershell-tool | opus46-200k | 24.0 | 34.0 | 1.4 | 0.57 |
| typescript-bun | opus46-200k | 44.0 | 62.0 | 1.4 | 0.56 |
| powershell | haiku45-200k | 8.9 | 16.1 | 1.8 | 0.51 |
| powershell | opus46-200k | 26.0 | 51.0 | 2.0 | 0.44 |
| bash | opus46-200k | 16.0 | 36.0 | 2.2 | 0.42 |

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

</details>

## Per-Run Results

*Tests Quality = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
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
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |


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
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |

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
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
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
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Artifact Cleanup Script | bash | haiku45-200k | 7.6min | 88 | 7 | $0.93 | — | bash | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Semantic Version Bumper | powershell | opus46-200k | 6.0min | 28 | 2 | $1.12 | — | powershell | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Semantic Version Bumper | typescript-bun | opus46-200k | 4.5min | 31 | 1 | $1.00 | — | typescript | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Semantic Version Bumper | powershell-tool | opus46-200k | 5.1min | 33 | 1 | $1.22 | — | powershell | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Secret Rotation Validator | powershell-tool | haiku45-200k | 4.3min | 34 | 1 | $0.38 | — | powershell | ok |
| PR Label Assigner | default | opus46-200k | 4.8min | 35 | 3 | $1.02 | — | python | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Semantic Version Bumper | default | opus46-200k | 5.5min | 37 | 1 | $1.25 | — | python | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Artifact Cleanup Script | powershell-tool | haiku45-200k | 4.5min | 43 | 1 | $0.47 | — | powershell | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
| Secret Rotation Validator | default | haiku45-200k | 4.6min | 46 | 8 | $0.44 | — | python | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Artifact Cleanup Script | typescript-bun | haiku45-200k | 4.3min | 48 | 4 | $0.47 | — | typescript | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | bash | opus46-200k | 5.9min | 53 | 3 | $1.52 | — | bash | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Secret Rotation Validator | typescript-bun | haiku45-200k | 3.9min | 55 | 7 | $0.49 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Secret Rotation Validator | bash | haiku45-200k | 5.4min | 58 | 5 | $0.51 | — | bash | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Secret Rotation Validator | powershell | haiku45-200k | 8.4min | 72 | 2 | $0.88 | — | powershell | ok |
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

</details>

## Notes

### Tiers

- **Duration bands:** **A+** ≤1.05×, **A** ≤1.09×, **A-** ≤1.14×, **B+** ≤1.19×, **B** ≤1.25×, **B-** ≤1.30×, **C+** ≤1.36×, **C** ≤1.42×, **C-** ≤1.49×, **D+** ≤1.55×, **D** ≤1.62×, **D-** ≤1.70×, **F** >1.70×
- **Cost bands:** **A+** ≤1.12×, **A** ≤1.26×, **A-** ≤1.41×, **B+** ≤1.58×, **B** ≤1.78×, **B-** ≤1.99×, **C+** ≤2.24×, **C** ≤2.51×, **C-** ≤2.81×, **D+** ≤3.16×, **D** ≤3.54×, **D-** ≤3.97×, **F** >3.97×

*Tests/Workflow Craft bands are absolute Overall score bands:* **A+** ≥4.7, **A** ≥4.4, **A-** ≥4.1, **B+** ≥3.8, **B** ≥3.5, **B-** ≥3.2, **C+** ≥2.9, **C** ≥2.6, **C-** ≥2.3, **D+** ≥2.0, **D** ≥1.7, **D-** ≥1.4, **F** <1.4, `—` = no data.*

### CLI Version Legend

| Variant label | CLI version | Tasks | Languages |
|---------------|-------------|-------|-----------|
| haiku45-200k | 2.1.131 | 11-semantic-version-bumper, 12-pr-label-assigner | All |
| haiku45-200k | 2.1.132 | 12-pr-label-assigner, 13-dependency-license-checker, 15-test-results-aggregator, 16-environment-matrix-generator, 17-artifact-cleanup-script, 18-secret-rotation-validator | All |
| opus46-200k | 2.1.132 | 11-semantic-version-bumper, 12-pr-label-assigner | All |

---
*Generated by generate_results.py — benchmark instructions v4*