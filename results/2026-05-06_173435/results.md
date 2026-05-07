# Benchmark Results: Language Comparison

**Last updated:** 2026-05-06 08:43:24 PM ET — 24/35 runs completed, 11 remaining; total cost $12.17; total agent time 185.0 min.

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
| default | haiku45-200k | A+ (4.9min) | A+ ($0.37) | — | — |
| powershell | haiku45-200k* | B- (6.1min) | B ($0.47) | — | — |
| typescript-bun | haiku45-200k | B- (6.3min) | B- ($0.50) | — | — |
| powershell-tool | haiku45-200k | D- (8.3min) | B- ($0.50) | — | — |
| bash | haiku45-200k | D- (8.1min) | D- ($0.69) | — | — |


<details>
<summary>Sorted by Duration tier (best-first), then avg of Cost/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.9min) | A+ ($0.37) | — | — |
| powershell | haiku45-200k* | B- (6.1min) | B ($0.47) | — | — |
| typescript-bun | haiku45-200k | B- (6.3min) | B- ($0.50) | — | — |
| powershell-tool | haiku45-200k | D- (8.3min) | B- ($0.50) | — | — |
| bash | haiku45-200k | D- (8.1min) | D- ($0.69) | — | — |

</details>

<details>
<summary>Sorted by Cost tier (best-first), then avg of Duration/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.9min) | A+ ($0.37) | — | — |
| powershell | haiku45-200k* | B- (6.1min) | B ($0.47) | — | — |
| typescript-bun | haiku45-200k | B- (6.3min) | B- ($0.50) | — | — |
| powershell-tool | haiku45-200k | D- (8.3min) | B- ($0.50) | — | — |
| bash | haiku45-200k | D- (8.1min) | D- ($0.69) | — | — |

</details>

<details>
<summary>Sorted by Tests Quality tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.9min) | A+ ($0.37) | — | — |
| powershell | haiku45-200k* | B- (6.1min) | B ($0.47) | — | — |
| typescript-bun | haiku45-200k | B- (6.3min) | B- ($0.50) | — | — |
| powershell-tool | haiku45-200k | D- (8.3min) | B- ($0.50) | — | — |
| bash | haiku45-200k | D- (8.1min) | D- ($0.69) | — | — |

</details>

<details>
<summary>Sorted by Workflow Craft tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.9min) | A+ ($0.37) | — | — |
| powershell | haiku45-200k* | B- (6.1min) | B ($0.47) | — | — |
| typescript-bun | haiku45-200k | B- (6.3min) | B- ($0.50) | — | — |
| powershell-tool | haiku45-200k | D- (8.3min) | B- ($0.50) | — | — |
| bash | haiku45-200k | D- (8.1min) | D- ($0.69) | — | — |

</details>

- **Estimated time remaining:** 84.8min
- **Estimated total cost:** $17.75

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
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |
| default | haiku45-200k | 5 | 4.9min | 4.9min | 2.8 | 40 | $0.37 | $1.87 | — | — |
| powershell | haiku45-200k* | 4 | 6.1min | 6.1min | 1.8 | 49 | $0.47 | $1.89 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| typescript-bun | haiku45-200k | 4 | 6.3min | 6.3min | 4.2 | 52 | $0.50 | $1.98 | — | — |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 5 | 4.9min | 4.9min | 2.8 | 40 | $0.37 | $1.87 | — | — |
| powershell | haiku45-200k* | 4 | 6.1min | 6.1min | 1.8 | 49 | $0.47 | $1.89 | — | — |
| typescript-bun | haiku45-200k | 4 | 6.3min | 6.3min | 4.2 | 52 | $0.50 | $1.98 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 5 | 4.9min | 4.9min | 2.8 | 40 | $0.37 | $1.87 | — | — |
| powershell | haiku45-200k* | 4 | 6.1min | 6.1min | 1.8 | 49 | $0.47 | $1.89 | — | — |
| typescript-bun | haiku45-200k | 4 | 6.3min | 6.3min | 4.2 | 52 | $0.50 | $1.98 | — | — |
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 5 | 4.9min | 4.9min | 2.8 | 40 | $0.37 | $1.87 | — | — |
| powershell | haiku45-200k* | 4 | 6.1min | 6.1min | 1.8 | 49 | $0.47 | $1.89 | — | — |
| typescript-bun | haiku45-200k | 4 | 6.3min | 6.3min | 4.2 | 52 | $0.50 | $1.98 | — | — |
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| powershell | haiku45-200k* | 4 | 6.1min | 6.1min | 1.8 | 49 | $0.47 | $1.89 | — | — |
| default | haiku45-200k | 5 | 4.9min | 4.9min | 2.8 | 40 | $0.37 | $1.87 | — | — |
| typescript-bun | haiku45-200k | 4 | 6.3min | 6.3min | 4.2 | 52 | $0.50 | $1.98 | — | — |
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 5 | 4.9min | 4.9min | 2.8 | 40 | $0.37 | $1.87 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| powershell | haiku45-200k* | 4 | 6.1min | 6.1min | 1.8 | 49 | $0.47 | $1.89 | — | — |
| typescript-bun | haiku45-200k | 4 | 6.3min | 6.3min | 4.2 | 52 | $0.50 | $1.98 | — | — |
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |
| default | haiku45-200k | 5 | 4.9min | 4.9min | 2.8 | 40 | $0.37 | $1.87 | — | — |
| powershell | haiku45-200k* | 4 | 6.1min | 6.1min | 1.8 | 49 | $0.47 | $1.89 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| typescript-bun | haiku45-200k | 4 | 6.3min | 6.3min | 4.2 | 52 | $0.50 | $1.98 | — | — |

</details>

<details>
<summary>Sorted by deliverable-quality score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |
| default | haiku45-200k | 5 | 4.9min | 4.9min | 2.8 | 40 | $0.37 | $1.87 | — | — |
| powershell | haiku45-200k* | 4 | 6.1min | 6.1min | 1.8 | 49 | $0.47 | $1.89 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| typescript-bun | haiku45-200k | 4 | 6.3min | 6.3min | 4.2 | 52 | $0.50 | $1.98 | — | — |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

*`% of Test Time Saved` = `net / (net + test_time) × 100` — the share of total (would-have-been + actually-spent) test time that hooks eliminated. Bounded in (-∞, 100%) without an artificial cap; near 100% means hooks substituted for almost all of the hypothetical test work.*

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| bash | haiku45-200k-cli2.1.132 | 82 | 15 | 18.3% | 3.0min | 1.6% | 0.1min | 0.1% | 2.9min | 1.5% | 0.7min | 81.2% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.2% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| default | haiku45-200k-cli2.1.132 | 43 | 4 | 9.3% | 0.5min | 0.3% | 0.1min | 0.1% | 0.4min | 0.2% | 2.3min | 15.3% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.3% | 0.2min | 0.1% | 0.4min | 0.2% | 0.8min | 31.9% |
| powershell | haiku45-200k-cli2.1.132 | 64 | 4 | 6.2% | 2.3min | 1.3% | 0.6min | 0.3% | 1.7min | 0.9% | 3.5min | 33.0% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |
| powershell-tool | haiku45-200k-cli2.1.132 | 71 | 1 | 1.4% | 0.6min | 0.3% | 0.5min | 0.3% | 0.1min | 0.0% | 3.0min | 2.7% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.7% | 1.5min | 0.8% | -0.2min | -0.1% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 59 | 19 | 32.2% | 2.5min | 1.4% | 4.1min | 2.2% | -1.6min | -0.8% | 0.3min | 121.3% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.132 | 82 | 15 | 18.3% | 3.0min | 1.6% | 0.1min | 0.1% | 2.9min | 1.5% | 0.7min | 81.2% |
| powershell | haiku45-200k-cli2.1.132 | 64 | 4 | 6.2% | 2.3min | 1.3% | 0.6min | 0.3% | 1.7min | 0.9% | 3.5min | 33.0% |
| default | haiku45-200k-cli2.1.132 | 43 | 4 | 9.3% | 0.5min | 0.3% | 0.1min | 0.1% | 0.4min | 0.2% | 2.3min | 15.3% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.3% | 0.2min | 0.1% | 0.4min | 0.2% | 0.8min | 31.9% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.2% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| powershell-tool | haiku45-200k-cli2.1.132 | 71 | 1 | 1.4% | 0.6min | 0.3% | 0.5min | 0.3% | 0.1min | 0.0% | 3.0min | 2.7% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.7% | 1.5min | 0.8% | -0.2min | -0.1% | 0.5min | -57.5% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |
| typescript-bun | haiku45-200k-cli2.1.132 | 59 | 19 | 32.2% | 2.5min | 1.4% | 4.1min | 2.2% | -1.6min | -0.8% | 0.3min | 121.3% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | haiku45-200k-cli2.1.132 | 59 | 19 | 32.2% | 2.5min | 1.4% | 4.1min | 2.2% | -1.6min | -0.8% | 0.3min | 121.3% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.2% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.132 | 82 | 15 | 18.3% | 3.0min | 1.6% | 0.1min | 0.1% | 2.9min | 1.5% | 0.7min | 81.2% |
| powershell | haiku45-200k-cli2.1.132 | 64 | 4 | 6.2% | 2.3min | 1.3% | 0.6min | 0.3% | 1.7min | 0.9% | 3.5min | 33.0% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.3% | 0.2min | 0.1% | 0.4min | 0.2% | 0.8min | 31.9% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| default | haiku45-200k-cli2.1.132 | 43 | 4 | 9.3% | 0.5min | 0.3% | 0.1min | 0.1% | 0.4min | 0.2% | 2.3min | 15.3% |
| powershell-tool | haiku45-200k-cli2.1.132 | 71 | 1 | 1.4% | 0.6min | 0.3% | 0.5min | 0.3% | 0.1min | 0.0% | 3.0min | 2.7% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.7% | 1.5min | 0.8% | -0.2min | -0.1% | 0.5min | -57.5% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.7% | 1.5min | 0.8% | -0.2min | -0.1% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 59 | 19 | 32.2% | 2.5min | 1.4% | 4.1min | 2.2% | -1.6min | -0.8% | 0.3min | 121.3% |
| bash | haiku45-200k-cli2.1.132 | 82 | 15 | 18.3% | 3.0min | 1.6% | 0.1min | 0.1% | 2.9min | 1.5% | 0.7min | 81.2% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.2% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| default | haiku45-200k-cli2.1.132 | 43 | 4 | 9.3% | 0.5min | 0.3% | 0.1min | 0.1% | 0.4min | 0.2% | 2.3min | 15.3% |
| powershell | haiku45-200k-cli2.1.132 | 64 | 4 | 6.2% | 2.3min | 1.3% | 0.6min | 0.3% | 1.7min | 0.9% | 3.5min | 33.0% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.3% | 0.2min | 0.1% | 0.4min | 0.2% | 0.8min | 31.9% |
| powershell-tool | haiku45-200k-cli2.1.132 | 71 | 1 | 1.4% | 0.6min | 0.3% | 0.5min | 0.3% | 0.1min | 0.0% | 3.0min | 2.7% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 2.3% | $0.20 | 1.60% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 2.8% | $0.53 | 4.35% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.3% | $0.05 | 0.40% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 3.3% | $0.43 | 3.54% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.1% | $0.16 | 1.34% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 11.4min | 6.1% | $0.56 | 4.59% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.7% | $0.10 | 0.84% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 1.5min | 0.8% | $0.11 | 0.92% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.03 | 0.25% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 3 | 3.7min | 2.0% | $0.36 | 3.00% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.3% | $0.17 | 1.36% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 3 | 4.3min | 2.3% | $0.24 | 1.99% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.5% | $0.05 | 0.44% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.5% | $0.07 | 0.62% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.05 | 0.41% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 3.7min | 2.0% | $0.30 | 2.44% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.7% | $0.12 | 1.01% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.3% | $0.03 | 0.25% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.9% | $0.17 | 1.42% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.4% | $0.06 | 0.47% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 1.1% | $0.17 | 1.39% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.3% | $0.22 | 1.78% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.05 | 0.39% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 2 | 1.7min | 0.9% | $0.09 | 0.72% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 1.3min | 0.7% | $0.10 | 0.78% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.1% | $0.15 | 1.23% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 3 | 3.8min | 2.1% | $0.31 | 2.55% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.04 | 0.29% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 2.3% | $0.15 | 1.26% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 1.1% | $0.20 | 1.64% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.3% | $0.03 | 0.25% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.3% | $0.05 | 0.40% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.04 | 0.29% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.03 | 0.25% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.05 | 0.41% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.05 | 0.39% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.4% | $0.06 | 0.47% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.5% | $0.05 | 0.44% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.5% | $0.07 | 0.62% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.7% | $0.12 | 1.01% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 1.3min | 0.7% | $0.10 | 0.78% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.7% | $0.10 | 0.84% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 1.5min | 0.8% | $0.11 | 0.92% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 2 | 1.7min | 0.9% | $0.09 | 0.72% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.9% | $0.17 | 1.42% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 1.1% | $0.17 | 1.39% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.1% | $0.15 | 1.23% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 1.1% | $0.20 | 1.64% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.1% | $0.16 | 1.34% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.3% | $0.17 | 1.36% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.3% | $0.22 | 1.78% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 3 | 3.7min | 2.0% | $0.36 | 3.00% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 3.7min | 2.0% | $0.30 | 2.44% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 3 | 3.8min | 2.1% | $0.31 | 2.55% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 2.3% | $0.15 | 1.26% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 2.3% | $0.20 | 1.60% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 3 | 4.3min | 2.3% | $0.24 | 1.99% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 2.8% | $0.53 | 4.35% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 3.3% | $0.43 | 3.54% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 11.4min | 6.1% | $0.56 | 4.59% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.3% | $0.03 | 0.25% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.03 | 0.25% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.04 | 0.29% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.05 | 0.39% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.3% | $0.05 | 0.40% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.05 | 0.41% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.5% | $0.05 | 0.44% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.4% | $0.06 | 0.47% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.5% | $0.07 | 0.62% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 2 | 1.7min | 0.9% | $0.09 | 0.72% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 1.3min | 0.7% | $0.10 | 0.78% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.7% | $0.10 | 0.84% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 1.5min | 0.8% | $0.11 | 0.92% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.7% | $0.12 | 1.01% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.1% | $0.15 | 1.23% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 2.3% | $0.15 | 1.26% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.1% | $0.16 | 1.34% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.3% | $0.17 | 1.36% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 1.1% | $0.17 | 1.39% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.9% | $0.17 | 1.42% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 2.3% | $0.20 | 1.60% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 1.1% | $0.20 | 1.64% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.3% | $0.22 | 1.78% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 3 | 4.3min | 2.3% | $0.24 | 1.99% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 3.7min | 2.0% | $0.30 | 2.44% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 3 | 3.8min | 2.1% | $0.31 | 2.55% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 3 | 3.7min | 2.0% | $0.36 | 3.00% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 3.3% | $0.43 | 3.54% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 2.8% | $0.53 | 4.35% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 11.4min | 6.1% | $0.56 | 4.59% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 2.3% | $0.20 | 1.60% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.3% | $0.05 | 0.40% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 3.3% | $0.43 | 3.54% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.7% | $0.10 | 0.84% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.03 | 0.25% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.3% | $0.17 | 1.36% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.5% | $0.05 | 0.44% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.5% | $0.07 | 0.62% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.05 | 0.41% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.7% | $0.12 | 1.01% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.3% | $0.03 | 0.25% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.4% | $0.06 | 0.47% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 1.1% | $0.17 | 1.39% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.05 | 0.39% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 1.3min | 0.7% | $0.10 | 0.78% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.1% | $0.15 | 1.23% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.4% | $0.04 | 0.29% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 2.3% | $0.15 | 1.26% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.1% | $0.16 | 1.34% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 1.5min | 0.8% | $0.11 | 0.92% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.9% | $0.17 | 1.42% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.3% | $0.22 | 1.78% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 2 | 1.7min | 0.9% | $0.09 | 0.72% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 1.1% | $0.20 | 1.64% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 2.8% | $0.53 | 4.35% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 11.4min | 6.1% | $0.56 | 4.59% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 3 | 3.7min | 2.0% | $0.36 | 3.00% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 3 | 4.3min | 2.3% | $0.24 | 1.99% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 3 | 3.8min | 2.1% | $0.31 | 2.55% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 3.7min | 2.0% | $0.30 | 2.44% |

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
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 2.7% | $0.23 | 1.86% |
| bash | haiku45-200k-cli2.1.132 | 4 | 9 | 12.1min | 6.5% | $1.22 | 10.00% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.6% | $0.08 | 0.65% |
| default | haiku45-200k-cli2.1.132 | 3 | 4 | 4.1min | 2.2% | $0.39 | 3.20% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 4.9% | $0.64 | 5.29% |
| powershell | haiku45-200k-cli2.1.132 | 4 | 5 | 6.5min | 3.5% | $0.41 | 3.33% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.9% | $0.09 | 0.74% |
| powershell-tool | haiku45-200k-cli2.1.132 | 4 | 8 | 19.0min | 10.3% | $0.93 | 7.65% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 2.2% | $0.30 | 2.47% |
| typescript-bun | haiku45-200k-cli2.1.132 | 3 | 11 | 12.3min | 6.7% | $0.98 | 8.08% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.6% | $0.08 | 0.65% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.9% | $0.09 | 0.74% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 2.2% | $0.30 | 2.47% |
| default | haiku45-200k-cli2.1.132 | 3 | 4 | 4.1min | 2.2% | $0.39 | 3.20% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 2.7% | $0.23 | 1.86% |
| powershell | haiku45-200k-cli2.1.132 | 4 | 5 | 6.5min | 3.5% | $0.41 | 3.33% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 4.9% | $0.64 | 5.29% |
| bash | haiku45-200k-cli2.1.132 | 4 | 9 | 12.1min | 6.5% | $1.22 | 10.00% |
| typescript-bun | haiku45-200k-cli2.1.132 | 3 | 11 | 12.3min | 6.7% | $0.98 | 8.08% |
| powershell-tool | haiku45-200k-cli2.1.132 | 4 | 8 | 19.0min | 10.3% | $0.93 | 7.65% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.6% | $0.08 | 0.65% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.9% | $0.09 | 0.74% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 2.7% | $0.23 | 1.86% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 2.2% | $0.30 | 2.47% |
| default | haiku45-200k-cli2.1.132 | 3 | 4 | 4.1min | 2.2% | $0.39 | 3.20% |
| powershell | haiku45-200k-cli2.1.132 | 4 | 5 | 6.5min | 3.5% | $0.41 | 3.33% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 4.9% | $0.64 | 5.29% |
| powershell-tool | haiku45-200k-cli2.1.132 | 4 | 8 | 19.0min | 10.3% | $0.93 | 7.65% |
| typescript-bun | haiku45-200k-cli2.1.132 | 3 | 11 | 12.3min | 6.7% | $0.98 | 8.08% |
| bash | haiku45-200k-cli2.1.132 | 4 | 9 | 12.1min | 6.5% | $1.22 | 10.00% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 22 | $0.62 | 5.12% |
| Miss | 2 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45-200k | 14.4 | 16.4 | 1.1 | 1.42 |
| default | haiku45-200k | 11.8 | 27.0 | 2.3 | 1.31 |
| powershell | haiku45-200k | 10.2 | 17.8 | 1.7 | 0.58 |
| powershell-tool | haiku45-200k | 14.6 | 34.2 | 2.3 | 0.66 |
| typescript-bun | haiku45-200k | 23.5 | 48.2 | 2.1 | 0.92 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | haiku45-200k | 23.5 | 48.2 | 2.1 | 0.92 |
| powershell-tool | haiku45-200k | 14.6 | 34.2 | 2.3 | 0.66 |
| bash | haiku45-200k | 14.4 | 16.4 | 1.1 | 1.42 |
| default | haiku45-200k | 11.8 | 27.0 | 2.3 | 1.31 |
| powershell | haiku45-200k | 10.2 | 17.8 | 1.7 | 0.58 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | haiku45-200k | 23.5 | 48.2 | 2.1 | 0.92 |
| powershell-tool | haiku45-200k | 14.6 | 34.2 | 2.3 | 0.66 |
| default | haiku45-200k | 11.8 | 27.0 | 2.3 | 1.31 |
| powershell | haiku45-200k | 10.2 | 17.8 | 1.7 | 0.58 |
| bash | haiku45-200k | 14.4 | 16.4 | 1.1 | 1.42 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45-200k | 14.4 | 16.4 | 1.1 | 1.42 |
| default | haiku45-200k | 11.8 | 27.0 | 2.3 | 1.31 |
| typescript-bun | haiku45-200k | 23.5 | 48.2 | 2.1 | 0.92 |
| powershell-tool | haiku45-200k | 14.6 | 34.2 | 2.3 | 0.66 |
| powershell | haiku45-200k | 10.2 | 17.8 | 1.7 | 0.58 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Language | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | default | haiku45-200k | 0 | 0 | 0.0 | 0 | 17 | 0.00 |
| Semantic Version Bumper | powershell | haiku45-200k | 18 | 22 | 1.2 | 197 | 333 | 0.59 |
| Semantic Version Bumper | bash | haiku45-200k | 20 | 26 | 1.3 | 259 | 258 | 1.00 |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 20 | 44 | 2.2 | 227 | 599 | 0.38 |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 38 | 76 | 2.0 | 503 | 585 | 0.86 |
| PR Label Assigner | default | haiku45-200k | 14 | 19 | 1.4 | 302 | 121 | 2.50 |
| PR Label Assigner | powershell | haiku45-200k | 13 | 22 | 1.7 | 253 | 317 | 0.80 |
| PR Label Assigner | bash | haiku45-200k | 15 | 13 | 0.9 | 145 | 163 | 0.89 |
| PR Label Assigner | powershell-tool | haiku45-200k | 9 | 17 | 1.9 | 140 | 470 | 0.30 |
| PR Label Assigner | typescript-bun | haiku45-200k | 11 | 15 | 1.4 | 151 | 121 | 1.25 |
| Dependency License Checker | default | haiku45-200k | 21 | 49 | 2.3 | 337 | 666 | 0.51 |
| Dependency License Checker | powershell | haiku45-200k | 12 | 30 | 2.5 | 240 | 347 | 0.69 |
| Dependency License Checker | bash | haiku45-200k | 15 | 32 | 2.1 | 983 | 340 | 2.89 |
| Dependency License Checker | powershell-tool | haiku45-200k | 10 | 31 | 3.1 | 187 | 414 | 0.45 |
| Dependency License Checker | typescript-bun | haiku45-200k | 14 | 33 | 2.4 | 227 | 346 | 0.66 |
| Test Results Aggregator | default | haiku45-200k | 5 | 26 | 5.2 | 176 | 257 | 0.68 |
| Test Results Aggregator | powershell | haiku45-200k | 0 | 0 | 0.0 | 0 | 541 | 0.00 |
| Test Results Aggregator | bash | haiku45-200k | 8 | 8 | 1.0 | 117 | 173 | 0.68 |
| Test Results Aggregator | powershell-tool | haiku45-200k | 22 | 54 | 2.5 | 238 | 319 | 0.75 |
| Test Results Aggregator | typescript-bun | haiku45-200k | 31 | 69 | 2.2 | 398 | 442 | 0.90 |
| Environment Matrix Generator | default | haiku45-200k | 19 | 41 | 2.2 | 522 | 184 | 2.84 |
| Environment Matrix Generator | powershell | haiku45-200k | 8 | 15 | 1.9 | 146 | 179 | 0.82 |
| Environment Matrix Generator | bash | haiku45-200k | 14 | 3 | 0.2 | 212 | 130 | 1.63 |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 12 | 25 | 2.1 | 193 | 137 | 1.41 |

</details>

## Per-Run Results

*Tests Quality = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
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
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
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
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
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
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Test Results Aggregator | powershell-tool | haiku45-200k | 7.6min | 57 | 2 | $0.58 | — | powershell | ok |
| Test Results Aggregator | typescript-bun | haiku45-200k | 8.2min | 68 | 7 | $0.70 | — | typescript | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Environment Matrix Generator | powershell | haiku45-200k | 3.2min | 32 | 3 | $0.31 | — | powershell | ok |
| Environment Matrix Generator | bash | haiku45-200k | 7.6min | 80 | 8 | $0.78 | — | bash | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |

</details>

## Notes

### Tiers

- **Duration bands:** **A+** ≤1.05×, **A** ≤1.09×, **A-** ≤1.14×, **B+** ≤1.19×, **B** ≤1.25×, **B-** ≤1.31×, **C+** ≤1.36×, **C** ≤1.43×, **C-** ≤1.49×, **D+** ≤1.56×, **D** ≤1.63×, **D-** ≤1.70×, **F** >1.70×
- **Cost bands:** **A+** ≤1.05×, **A** ≤1.11×, **A-** ≤1.16×, **B+** ≤1.22×, **B** ≤1.29×, **B-** ≤1.36×, **C+** ≤1.43×, **C** ≤1.50×, **C-** ≤1.58×, **D+** ≤1.66×, **D** ≤1.75×, **D-** ≤1.84×, **F** >1.84×

*Tests/Workflow Craft bands are absolute Overall score bands:* **A+** ≥4.7, **A** ≥4.4, **A-** ≥4.1, **B+** ≥3.8, **B** ≥3.5, **B-** ≥3.2, **C+** ≥2.9, **C** ≥2.6, **C-** ≥2.3, **D+** ≥2.0, **D** ≥1.7, **D-** ≥1.4, **F** <1.4, `—` = no data.*

### CLI Version Legend

| Variant label | CLI version | Tasks | Languages |
|---------------|-------------|-------|-----------|
| haiku45-200k | 2.1.131 | 11-semantic-version-bumper, 12-pr-label-assigner | All |
| haiku45-200k | 2.1.132 | 12-pr-label-assigner, 13-dependency-license-checker, 15-test-results-aggregator, 16-environment-matrix-generator | All |

---
*Generated by generate_results.py — benchmark instructions v4*