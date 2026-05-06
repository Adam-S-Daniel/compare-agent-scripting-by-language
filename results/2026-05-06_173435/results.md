# Benchmark Results: Language Comparison

**Last updated:** 2026-05-06 07:59:22 PM ET — 18/35 runs completed, 17 remaining; total cost $9.00; total agent time 143.2 min.

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
| default | haiku45-200k | A+ (4.8min) | A+ ($0.36) | — | — |
| typescript-bun | haiku45-200k | B+ (5.7min) | B+ ($0.43) | — | — |
| powershell | haiku45-200k* | C- (7.1min) | C ($0.53) | — | — |
| powershell-tool | haiku45-200k | D- (7.9min) | C ($0.51) | — | — |
| bash | haiku45-200k | D- (8.2min) | D- ($0.66) | — | — |


<details>
<summary>Sorted by Duration tier (best-first), then avg of Cost/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.36) | — | — |
| typescript-bun | haiku45-200k | B+ (5.7min) | B+ ($0.43) | — | — |
| powershell | haiku45-200k* | C- (7.1min) | C ($0.53) | — | — |
| powershell-tool | haiku45-200k | D- (7.9min) | C ($0.51) | — | — |
| bash | haiku45-200k | D- (8.2min) | D- ($0.66) | — | — |

</details>

<details>
<summary>Sorted by Cost tier (best-first), then avg of Duration/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.36) | — | — |
| typescript-bun | haiku45-200k | B+ (5.7min) | B+ ($0.43) | — | — |
| powershell | haiku45-200k* | C- (7.1min) | C ($0.53) | — | — |
| powershell-tool | haiku45-200k | D- (7.9min) | C ($0.51) | — | — |
| bash | haiku45-200k | D- (8.2min) | D- ($0.66) | — | — |

</details>

<details>
<summary>Sorted by Tests Quality tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.36) | — | — |
| typescript-bun | haiku45-200k | B+ (5.7min) | B+ ($0.43) | — | — |
| powershell | haiku45-200k* | C- (7.1min) | C ($0.53) | — | — |
| powershell-tool | haiku45-200k | D- (7.9min) | C ($0.51) | — | — |
| bash | haiku45-200k | D- (8.2min) | D- ($0.66) | — | — |

</details>

<details>
<summary>Sorted by Workflow Craft tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.36) | — | — |
| typescript-bun | haiku45-200k | B+ (5.7min) | B+ ($0.43) | — | — |
| powershell | haiku45-200k* | C- (7.1min) | C ($0.53) | — | — |
| powershell-tool | haiku45-200k | D- (7.9min) | C ($0.51) | — | — |
| bash | haiku45-200k | D- (8.2min) | D- ($0.66) | — | — |

</details>

- **Estimated time remaining:** 135.3min
- **Estimated total cost:** $17.50

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
| bash | haiku45-200k | 4 | 8.2min | 8.2min | 3.5 | 65 | $0.66 | $2.65 | — | — |
| default | haiku45-200k | 4 | 4.8min | 4.8min | 2.5 | 38 | $0.36 | $1.43 | — | — |
| powershell | haiku45-200k* | 3 | 7.1min | 7.1min | 1.3 | 54 | $0.53 | $1.59 | — | — |
| powershell-tool | haiku45-200k | 3 | 7.9min | 7.9min | 1.7 | 50 | $0.51 | $1.54 | — | — |
| typescript-bun | haiku45-200k | 3 | 5.7min | 5.7min | 3.3 | 46 | $0.43 | $1.28 | — | — |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 4 | 4.8min | 4.8min | 2.5 | 38 | $0.36 | $1.43 | — | — |
| typescript-bun | haiku45-200k | 3 | 5.7min | 5.7min | 3.3 | 46 | $0.43 | $1.28 | — | — |
| powershell-tool | haiku45-200k | 3 | 7.9min | 7.9min | 1.7 | 50 | $0.51 | $1.54 | — | — |
| powershell | haiku45-200k* | 3 | 7.1min | 7.1min | 1.3 | 54 | $0.53 | $1.59 | — | — |
| bash | haiku45-200k | 4 | 8.2min | 8.2min | 3.5 | 65 | $0.66 | $2.65 | — | — |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 4 | 4.8min | 4.8min | 2.5 | 38 | $0.36 | $1.43 | — | — |
| typescript-bun | haiku45-200k | 3 | 5.7min | 5.7min | 3.3 | 46 | $0.43 | $1.28 | — | — |
| powershell | haiku45-200k* | 3 | 7.1min | 7.1min | 1.3 | 54 | $0.53 | $1.59 | — | — |
| powershell-tool | haiku45-200k | 3 | 7.9min | 7.9min | 1.7 | 50 | $0.51 | $1.54 | — | — |
| bash | haiku45-200k | 4 | 8.2min | 8.2min | 3.5 | 65 | $0.66 | $2.65 | — | — |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 4 | 4.8min | 4.8min | 2.5 | 38 | $0.36 | $1.43 | — | — |
| typescript-bun | haiku45-200k | 3 | 5.7min | 5.7min | 3.3 | 46 | $0.43 | $1.28 | — | — |
| powershell | haiku45-200k* | 3 | 7.1min | 7.1min | 1.3 | 54 | $0.53 | $1.59 | — | — |
| powershell-tool | haiku45-200k | 3 | 7.9min | 7.9min | 1.7 | 50 | $0.51 | $1.54 | — | — |
| bash | haiku45-200k | 4 | 8.2min | 8.2min | 3.5 | 65 | $0.66 | $2.65 | — | — |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| powershell | haiku45-200k* | 3 | 7.1min | 7.1min | 1.3 | 54 | $0.53 | $1.59 | — | — |
| powershell-tool | haiku45-200k | 3 | 7.9min | 7.9min | 1.7 | 50 | $0.51 | $1.54 | — | — |
| default | haiku45-200k | 4 | 4.8min | 4.8min | 2.5 | 38 | $0.36 | $1.43 | — | — |
| typescript-bun | haiku45-200k | 3 | 5.7min | 5.7min | 3.3 | 46 | $0.43 | $1.28 | — | — |
| bash | haiku45-200k | 4 | 8.2min | 8.2min | 3.5 | 65 | $0.66 | $2.65 | — | — |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 4 | 4.8min | 4.8min | 2.5 | 38 | $0.36 | $1.43 | — | — |
| typescript-bun | haiku45-200k | 3 | 5.7min | 5.7min | 3.3 | 46 | $0.43 | $1.28 | — | — |
| powershell-tool | haiku45-200k | 3 | 7.9min | 7.9min | 1.7 | 50 | $0.51 | $1.54 | — | — |
| powershell | haiku45-200k* | 3 | 7.1min | 7.1min | 1.3 | 54 | $0.53 | $1.59 | — | — |
| bash | haiku45-200k | 4 | 8.2min | 8.2min | 3.5 | 65 | $0.66 | $2.65 | — | — |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 4 | 8.2min | 8.2min | 3.5 | 65 | $0.66 | $2.65 | — | — |
| default | haiku45-200k | 4 | 4.8min | 4.8min | 2.5 | 38 | $0.36 | $1.43 | — | — |
| powershell | haiku45-200k* | 3 | 7.1min | 7.1min | 1.3 | 54 | $0.53 | $1.59 | — | — |
| powershell-tool | haiku45-200k | 3 | 7.9min | 7.9min | 1.7 | 50 | $0.51 | $1.54 | — | — |
| typescript-bun | haiku45-200k | 3 | 5.7min | 5.7min | 3.3 | 46 | $0.43 | $1.28 | — | — |

</details>

<details>
<summary>Sorted by deliverable-quality score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 4 | 8.2min | 8.2min | 3.5 | 65 | $0.66 | $2.65 | — | — |
| default | haiku45-200k | 4 | 4.8min | 4.8min | 2.5 | 38 | $0.36 | $1.43 | — | — |
| powershell | haiku45-200k* | 3 | 7.1min | 7.1min | 1.3 | 54 | $0.53 | $1.59 | — | — |
| powershell-tool | haiku45-200k | 3 | 7.9min | 7.9min | 1.7 | 50 | $0.51 | $1.54 | — | — |
| typescript-bun | haiku45-200k | 3 | 5.7min | 5.7min | 3.3 | 46 | $0.43 | $1.28 | — | — |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

*`% of Test Time Saved` = `net / (net + test_time) × 100` — the share of total (would-have-been + actually-spent) test time that hooks eliminated. Bounded in (-∞, 100%) without an artificial cap; near 100% means hooks substituted for almost all of the hypothetical test work.*

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| bash | haiku45-200k-cli2.1.132 | 61 | 10 | 16.4% | 2.0min | 1.4% | 0.1min | 0.1% | 1.9min | 1.3% | 0.4min | 81.5% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.3% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| default | haiku45-200k-cli2.1.132 | 26 | 2 | 7.7% | 0.3min | 0.2% | 0.1min | 0.0% | 0.2min | 0.1% | 1.7min | 10.6% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.4% | 0.2min | 0.2% | 0.4min | 0.3% | 0.8min | 31.9% |
| powershell | haiku45-200k-cli2.1.132 | 55 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.4% | -0.5min | -0.4% | 3.2min | -19.4% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |
| powershell-tool | haiku45-200k-cli2.1.132 | 37 | 1 | 2.7% | 0.6min | 0.4% | 0.3min | 0.2% | 0.3min | 0.2% | 2.6min | 10.1% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.9% | 1.5min | 1.1% | -0.2min | -0.1% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 33 | 12 | 36.4% | 1.6min | 1.1% | 1.9min | 1.3% | -0.3min | -0.2% | 0.1min | 131.4% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.132 | 61 | 10 | 16.4% | 2.0min | 1.4% | 0.1min | 0.1% | 1.9min | 1.3% | 0.4min | 81.5% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.4% | 0.2min | 0.2% | 0.4min | 0.3% | 0.8min | 31.9% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.3% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| powershell-tool | haiku45-200k-cli2.1.132 | 37 | 1 | 2.7% | 0.6min | 0.4% | 0.3min | 0.2% | 0.3min | 0.2% | 2.6min | 10.1% |
| default | haiku45-200k-cli2.1.132 | 26 | 2 | 7.7% | 0.3min | 0.2% | 0.1min | 0.0% | 0.2min | 0.1% | 1.7min | 10.6% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.9% | 1.5min | 1.1% | -0.2min | -0.1% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 33 | 12 | 36.4% | 1.6min | 1.1% | 1.9min | 1.3% | -0.3min | -0.2% | 0.1min | 131.4% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |
| powershell | haiku45-200k-cli2.1.132 | 55 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.4% | -0.5min | -0.4% | 3.2min | -19.4% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | haiku45-200k-cli2.1.132 | 33 | 12 | 36.4% | 1.6min | 1.1% | 1.9min | 1.3% | -0.3min | -0.2% | 0.1min | 131.4% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.3% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.132 | 61 | 10 | 16.4% | 2.0min | 1.4% | 0.1min | 0.1% | 1.9min | 1.3% | 0.4min | 81.5% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.4% | 0.2min | 0.2% | 0.4min | 0.3% | 0.8min | 31.9% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| default | haiku45-200k-cli2.1.132 | 26 | 2 | 7.7% | 0.3min | 0.2% | 0.1min | 0.0% | 0.2min | 0.1% | 1.7min | 10.6% |
| powershell-tool | haiku45-200k-cli2.1.132 | 37 | 1 | 2.7% | 0.6min | 0.4% | 0.3min | 0.2% | 0.3min | 0.2% | 2.6min | 10.1% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |
| powershell | haiku45-200k-cli2.1.132 | 55 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.4% | -0.5min | -0.4% | 3.2min | -19.4% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.9% | 1.5min | 1.1% | -0.2min | -0.1% | 0.5min | -57.5% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.9% | 1.5min | 1.1% | -0.2min | -0.1% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 33 | 12 | 36.4% | 1.6min | 1.1% | 1.9min | 1.3% | -0.3min | -0.2% | 0.1min | 131.4% |
| bash | haiku45-200k-cli2.1.132 | 61 | 10 | 16.4% | 2.0min | 1.4% | 0.1min | 0.1% | 1.9min | 1.3% | 0.4min | 81.5% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.3% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| default | haiku45-200k-cli2.1.132 | 26 | 2 | 7.7% | 0.3min | 0.2% | 0.1min | 0.0% | 0.2min | 0.1% | 1.7min | 10.6% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.4% | 0.2min | 0.2% | 0.4min | 0.3% | 0.8min | 31.9% |
| powershell-tool | haiku45-200k-cli2.1.132 | 37 | 1 | 2.7% | 0.6min | 0.4% | 0.3min | 0.2% | 0.3min | 0.2% | 2.6min | 10.1% |
| powershell | haiku45-200k-cli2.1.132 | 55 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.4% | -0.5min | -0.4% | 3.2min | -19.4% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 3.0% | $0.20 | 2.17% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.6% | $0.24 | 2.63% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.4% | $0.05 | 0.54% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 4.2% | $0.43 | 4.78% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.5% | $0.16 | 1.81% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.9% | $0.09 | 1.04% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 1.0% | $0.10 | 1.13% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 1.5min | 1.1% | $0.11 | 1.24% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.03 | 0.34% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.09 | 1.02% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.6% | $0.17 | 1.84% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 3 | 4.3min | 3.0% | $0.24 | 2.69% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.7% | $0.05 | 0.60% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.07 | 0.83% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.05 | 0.55% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.6% | $0.18 | 2.04% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.4% | $0.15 | 1.66% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.4min | 1.7% | $0.19 | 2.13% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.9% | $0.12 | 1.36% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.3% | $0.03 | 0.34% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.11 | 1.18% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 1 | 0.7min | 0.5% | $0.07 | 0.79% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.05 | 0.53% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 1.3min | 0.9% | $0.10 | 1.06% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.04 | 0.40% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 1 | 0.5min | 0.3% | $0.05 | 0.51% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.3% | $0.03 | 0.34% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 1 | 0.5min | 0.3% | $0.05 | 0.51% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.4% | $0.05 | 0.54% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.04 | 0.40% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.03 | 0.34% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.05 | 0.55% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 1 | 0.7min | 0.5% | $0.07 | 0.79% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.05 | 0.53% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.09 | 1.02% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.7% | $0.05 | 0.60% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.07 | 0.83% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.11 | 1.18% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.9% | $0.09 | 1.04% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.9% | $0.12 | 1.36% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 1.3min | 0.9% | $0.10 | 1.06% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 1.0% | $0.10 | 1.13% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 1.5min | 1.1% | $0.11 | 1.24% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.4% | $0.15 | 1.66% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.5% | $0.16 | 1.81% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.6% | $0.24 | 2.63% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.6% | $0.17 | 1.84% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.6% | $0.18 | 2.04% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.4min | 1.7% | $0.19 | 2.13% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 3.0% | $0.20 | 2.17% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 3 | 4.3min | 3.0% | $0.24 | 2.69% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 4.2% | $0.43 | 4.78% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.3% | $0.03 | 0.34% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.03 | 0.34% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.04 | 0.40% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 1 | 0.5min | 0.3% | $0.05 | 0.51% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.05 | 0.53% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.4% | $0.05 | 0.54% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.05 | 0.55% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.7% | $0.05 | 0.60% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 1 | 0.7min | 0.5% | $0.07 | 0.79% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.07 | 0.83% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.09 | 1.02% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.9% | $0.09 | 1.04% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 1.3min | 0.9% | $0.10 | 1.06% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 1.0% | $0.10 | 1.13% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.11 | 1.18% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 1.5min | 1.1% | $0.11 | 1.24% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.9% | $0.12 | 1.36% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.4% | $0.15 | 1.66% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.5% | $0.16 | 1.81% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.6% | $0.17 | 1.84% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.6% | $0.18 | 2.04% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.4min | 1.7% | $0.19 | 2.13% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 3.0% | $0.20 | 2.17% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.6% | $0.24 | 2.63% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 3 | 4.3min | 3.0% | $0.24 | 2.69% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 4.2% | $0.43 | 4.78% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 3.0% | $0.20 | 2.17% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.4% | $0.05 | 0.54% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 4.2% | $0.43 | 4.78% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.9% | $0.09 | 1.04% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 1.0% | $0.10 | 1.13% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.03 | 0.34% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.09 | 1.02% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.6% | $0.17 | 1.84% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.7% | $0.05 | 0.60% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.07 | 0.83% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.05 | 0.55% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.4% | $0.15 | 1.66% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.9% | $0.12 | 1.36% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.3% | $0.03 | 0.34% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.7% | $0.11 | 1.18% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 1 | 0.7min | 0.5% | $0.07 | 0.79% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.05 | 0.53% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 1.3min | 0.9% | $0.10 | 1.06% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.5% | $0.04 | 0.40% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 1 | 0.5min | 0.3% | $0.05 | 0.51% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.6% | $0.24 | 2.63% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.5% | $0.16 | 1.81% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 1.5min | 1.1% | $0.11 | 1.24% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.6% | $0.18 | 2.04% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.4min | 1.7% | $0.19 | 2.13% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 3 | 4.3min | 3.0% | $0.24 | 2.69% |

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
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 3.4% | $0.23 | 2.51% |
| bash | haiku45-200k-cli2.1.132 | 3 | 5 | 5.0min | 3.5% | $0.50 | 5.53% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.8% | $0.08 | 0.87% |
| default | haiku45-200k-cli2.1.132 | 2 | 2 | 1.7min | 1.2% | $0.18 | 1.97% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 6.3% | $0.64 | 7.16% |
| powershell | haiku45-200k-cli2.1.132 | 3 | 5 | 6.5min | 4.5% | $0.41 | 4.50% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 1.2% | $0.09 | 1.00% |
| powershell-tool | haiku45-200k-cli2.1.132 | 2 | 2 | 2.2min | 1.6% | $0.17 | 1.87% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 2.8% | $0.30 | 3.34% |
| typescript-bun | haiku45-200k-cli2.1.132 | 2 | 7 | 7.6min | 5.3% | $0.58 | 6.48% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.8% | $0.08 | 0.87% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 1.2% | $0.09 | 1.00% |
| default | haiku45-200k-cli2.1.132 | 2 | 2 | 1.7min | 1.2% | $0.18 | 1.97% |
| powershell-tool | haiku45-200k-cli2.1.132 | 2 | 2 | 2.2min | 1.6% | $0.17 | 1.87% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 2.8% | $0.30 | 3.34% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 3.4% | $0.23 | 2.51% |
| bash | haiku45-200k-cli2.1.132 | 3 | 5 | 5.0min | 3.5% | $0.50 | 5.53% |
| powershell | haiku45-200k-cli2.1.132 | 3 | 5 | 6.5min | 4.5% | $0.41 | 4.50% |
| typescript-bun | haiku45-200k-cli2.1.132 | 2 | 7 | 7.6min | 5.3% | $0.58 | 6.48% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 6.3% | $0.64 | 7.16% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.8% | $0.08 | 0.87% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 1.2% | $0.09 | 1.00% |
| powershell-tool | haiku45-200k-cli2.1.132 | 2 | 2 | 2.2min | 1.6% | $0.17 | 1.87% |
| default | haiku45-200k-cli2.1.132 | 2 | 2 | 1.7min | 1.2% | $0.18 | 1.97% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 3.4% | $0.23 | 2.51% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 2.8% | $0.30 | 3.34% |
| powershell | haiku45-200k-cli2.1.132 | 3 | 5 | 6.5min | 4.5% | $0.41 | 4.50% |
| bash | haiku45-200k-cli2.1.132 | 3 | 5 | 5.0min | 3.5% | $0.50 | 5.53% |
| typescript-bun | haiku45-200k-cli2.1.132 | 2 | 7 | 7.6min | 5.3% | $0.58 | 6.48% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 6.3% | $0.64 | 7.16% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 16 | $0.45 | 5.01% |
| Miss | 2 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45-200k | 14.5 | 19.8 | 1.4 | 1.36 |
| default | haiku45-200k | 10.0 | 23.5 | 2.4 | 0.92 |
| powershell | haiku45-200k | 10.8 | 18.5 | 1.7 | 0.52 |
| powershell-tool | haiku45-200k | 13.0 | 30.7 | 2.4 | 0.38 |
| typescript-bun | haiku45-200k | 21.0 | 41.3 | 2.0 | 0.92 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | haiku45-200k | 21.0 | 41.3 | 2.0 | 0.92 |
| bash | haiku45-200k | 14.5 | 19.8 | 1.4 | 1.36 |
| powershell-tool | haiku45-200k | 13.0 | 30.7 | 2.4 | 0.38 |
| powershell | haiku45-200k | 10.8 | 18.5 | 1.7 | 0.52 |
| default | haiku45-200k | 10.0 | 23.5 | 2.4 | 0.92 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | haiku45-200k | 21.0 | 41.3 | 2.0 | 0.92 |
| powershell-tool | haiku45-200k | 13.0 | 30.7 | 2.4 | 0.38 |
| default | haiku45-200k | 10.0 | 23.5 | 2.4 | 0.92 |
| bash | haiku45-200k | 14.5 | 19.8 | 1.4 | 1.36 |
| powershell | haiku45-200k | 10.8 | 18.5 | 1.7 | 0.52 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45-200k | 14.5 | 19.8 | 1.4 | 1.36 |
| typescript-bun | haiku45-200k | 21.0 | 41.3 | 2.0 | 0.92 |
| default | haiku45-200k | 10.0 | 23.5 | 2.4 | 0.92 |
| powershell | haiku45-200k | 10.8 | 18.5 | 1.7 | 0.52 |
| powershell-tool | haiku45-200k | 13.0 | 30.7 | 2.4 | 0.38 |

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


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
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
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Dependency License Checker | bash | haiku45-200k | 10.8min | 93 | 5 | $1.17 | — | bash | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| PR Label Assigner | typescript-bun | haiku45-200k | 4.0min | 47 | 2 | $0.33 | — | typescript | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Test Results Aggregator | powershell | haiku45-200k | 6.6min | 49 | 1 | $0.47 | — | powershell | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| PR Label Assigner | powershell-tool | haiku45-200k | 8.7min | 64 | 2 | $0.62 | — | powershell | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
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

</details>

## Notes

### Tiers

- **Duration bands:** **A+** ≤1.04×, **A** ≤1.09×, **A-** ≤1.14×, **B+** ≤1.19×, **B** ≤1.24×, **B-** ≤1.30×, **C+** ≤1.36×, **C** ≤1.42×, **C-** ≤1.48×, **D+** ≤1.55×, **D** ≤1.62×, **D-** ≤1.69×, **F** >1.69×
- **Cost bands:** **A+** ≤1.05×, **A** ≤1.11×, **A-** ≤1.17×, **B+** ≤1.23×, **B** ≤1.29×, **B-** ≤1.36×, **C+** ≤1.44×, **C** ≤1.51×, **C-** ≤1.59×, **D+** ≤1.68×, **D** ≤1.77×, **D-** ≤1.86×, **F** >1.86×

*Tests/Workflow Craft bands are absolute Overall score bands:* **A+** ≥4.7, **A** ≥4.4, **A-** ≥4.1, **B+** ≥3.8, **B** ≥3.5, **B-** ≥3.2, **C+** ≥2.9, **C** ≥2.6, **C-** ≥2.3, **D+** ≥2.0, **D** ≥1.7, **D-** ≥1.4, **F** <1.4, `—` = no data.*

### CLI Version Legend

| Variant label | CLI version | Tasks | Languages |
|---------------|-------------|-------|-----------|
| haiku45-200k | 2.1.131 | 11-semantic-version-bumper, 12-pr-label-assigner | All |
| haiku45-200k | 2.1.132 | 12-pr-label-assigner, 13-dependency-license-checker, 15-test-results-aggregator | All |

---
*Generated by generate_results.py — benchmark instructions v4*