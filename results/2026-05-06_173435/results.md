# Benchmark Results: Language Comparison

**Last updated:** 2026-05-06 09:01:31 PM ET — 27/35 runs completed, 8 remaining; total cost $13.40; total agent time 200.0 min.

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
| default | haiku45-200k | A+ (4.8min) | A+ ($0.37) | — | — |
| powershell | haiku45-200k* | B (6.0min) | B ($0.47) | — | — |
| typescript-bun | haiku45-200k | B- (6.1min) | B ($0.48) | — | — |
| powershell-tool | haiku45-200k | D- (8.3min) | B- ($0.50) | — | — |
| bash | haiku45-200k | D- (8.1min) | D- ($0.69) | — | — |


<details>
<summary>Sorted by Duration tier (best-first), then avg of Cost/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.37) | — | — |
| powershell | haiku45-200k* | B (6.0min) | B ($0.47) | — | — |
| typescript-bun | haiku45-200k | B- (6.1min) | B ($0.48) | — | — |
| powershell-tool | haiku45-200k | D- (8.3min) | B- ($0.50) | — | — |
| bash | haiku45-200k | D- (8.1min) | D- ($0.69) | — | — |

</details>

<details>
<summary>Sorted by Cost tier (best-first), then avg of Duration/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.37) | — | — |
| powershell | haiku45-200k* | B (6.0min) | B ($0.47) | — | — |
| typescript-bun | haiku45-200k | B- (6.1min) | B ($0.48) | — | — |
| powershell-tool | haiku45-200k | D- (8.3min) | B- ($0.50) | — | — |
| bash | haiku45-200k | D- (8.1min) | D- ($0.69) | — | — |

</details>

<details>
<summary>Sorted by Tests Quality tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.37) | — | — |
| powershell | haiku45-200k* | B (6.0min) | B ($0.47) | — | — |
| typescript-bun | haiku45-200k | B- (6.1min) | B ($0.48) | — | — |
| powershell-tool | haiku45-200k | D- (8.3min) | B- ($0.50) | — | — |
| bash | haiku45-200k | D- (8.1min) | D- ($0.69) | — | — |

</details>

<details>
<summary>Sorted by Workflow Craft tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (4.8min) | A+ ($0.37) | — | — |
| powershell | haiku45-200k* | B (6.0min) | B ($0.47) | — | — |
| typescript-bun | haiku45-200k | B- (6.1min) | B ($0.48) | — | — |
| powershell-tool | haiku45-200k | D- (8.3min) | B- ($0.50) | — | — |
| bash | haiku45-200k | D- (8.1min) | D- ($0.69) | — | — |

</details>

- **Estimated time remaining:** 59.3min
- **Estimated total cost:** $17.37

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
| default | haiku45-200k | 6 | 4.8min | 4.8min | 2.8 | 39 | $0.37 | $2.24 | — | — |
| powershell | haiku45-200k* | 5 | 6.0min | 6.0min | 2.0 | 48 | $0.47 | $2.35 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| typescript-bun | haiku45-200k | 5 | 6.1min | 6.1min | 3.4 | 49 | $0.48 | $2.38 | — | — |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 6 | 4.8min | 4.8min | 2.8 | 39 | $0.37 | $2.24 | — | — |
| powershell | haiku45-200k* | 5 | 6.0min | 6.0min | 2.0 | 48 | $0.47 | $2.35 | — | — |
| typescript-bun | haiku45-200k | 5 | 6.1min | 6.1min | 3.4 | 49 | $0.48 | $2.38 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 6 | 4.8min | 4.8min | 2.8 | 39 | $0.37 | $2.24 | — | — |
| powershell | haiku45-200k* | 5 | 6.0min | 6.0min | 2.0 | 48 | $0.47 | $2.35 | — | — |
| typescript-bun | haiku45-200k | 5 | 6.1min | 6.1min | 3.4 | 49 | $0.48 | $2.38 | — | — |
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 6 | 4.8min | 4.8min | 2.8 | 39 | $0.37 | $2.24 | — | — |
| powershell | haiku45-200k* | 5 | 6.0min | 6.0min | 2.0 | 48 | $0.47 | $2.35 | — | — |
| typescript-bun | haiku45-200k | 5 | 6.1min | 6.1min | 3.4 | 49 | $0.48 | $2.38 | — | — |
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| powershell | haiku45-200k* | 5 | 6.0min | 6.0min | 2.0 | 48 | $0.47 | $2.35 | — | — |
| default | haiku45-200k | 6 | 4.8min | 4.8min | 2.8 | 39 | $0.37 | $2.24 | — | — |
| typescript-bun | haiku45-200k | 5 | 6.1min | 6.1min | 3.4 | 49 | $0.48 | $2.38 | — | — |
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 6 | 4.8min | 4.8min | 2.8 | 39 | $0.37 | $2.24 | — | — |
| powershell | haiku45-200k* | 5 | 6.0min | 6.0min | 2.0 | 48 | $0.47 | $2.35 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| typescript-bun | haiku45-200k | 5 | 6.1min | 6.1min | 3.4 | 49 | $0.48 | $2.38 | — | — |
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |
| default | haiku45-200k | 6 | 4.8min | 4.8min | 2.8 | 39 | $0.37 | $2.24 | — | — |
| powershell | haiku45-200k* | 5 | 6.0min | 6.0min | 2.0 | 48 | $0.47 | $2.35 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| typescript-bun | haiku45-200k | 5 | 6.1min | 6.1min | 3.4 | 49 | $0.48 | $2.38 | — | — |

</details>

<details>
<summary>Sorted by deliverable-quality score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 5 | 8.1min | 8.1min | 4.4 | 68 | $0.69 | $3.43 | — | — |
| default | haiku45-200k | 6 | 4.8min | 4.8min | 2.8 | 39 | $0.37 | $2.24 | — | — |
| powershell | haiku45-200k* | 5 | 6.0min | 6.0min | 2.0 | 48 | $0.47 | $2.35 | — | — |
| powershell-tool | haiku45-200k | 5 | 8.3min | 8.3min | 1.6 | 49 | $0.50 | $2.49 | — | — |
| typescript-bun | haiku45-200k | 5 | 6.1min | 6.1min | 3.4 | 49 | $0.48 | $2.38 | — | — |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

*`% of Test Time Saved` = `net / (net + test_time) × 100` — the share of total (would-have-been + actually-spent) test time that hooks eliminated. Bounded in (-∞, 100%) without an artificial cap; near 100% means hooks substituted for almost all of the hypothetical test work.*

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| bash | haiku45-200k-cli2.1.132 | 82 | 15 | 18.3% | 3.0min | 1.5% | 0.1min | 0.1% | 2.9min | 1.4% | 0.7min | 81.2% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.2% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| default | haiku45-200k-cli2.1.132 | 58 | 10 | 17.2% | 1.3min | 0.7% | 0.2min | 0.1% | 1.2min | 0.6% | 2.3min | 33.7% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.3% | 0.2min | 0.1% | 0.4min | 0.2% | 0.8min | 31.9% |
| powershell | haiku45-200k-cli2.1.132 | 82 | 4 | 4.9% | 2.3min | 1.2% | 0.7min | 0.4% | 1.6min | 0.8% | 5.3min | 23.4% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |
| powershell-tool | haiku45-200k-cli2.1.132 | 71 | 1 | 1.4% | 0.6min | 0.3% | 0.5min | 0.3% | 0.1min | 0.0% | 3.0min | 2.7% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.7% | 1.5min | 0.8% | -0.2min | -0.1% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 70 | 25 | 35.7% | 3.3min | 1.7% | 4.2min | 2.1% | -0.9min | -0.5% | 1.7min | -116.7% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.132 | 82 | 15 | 18.3% | 3.0min | 1.5% | 0.1min | 0.1% | 2.9min | 1.4% | 0.7min | 81.2% |
| powershell | haiku45-200k-cli2.1.132 | 82 | 4 | 4.9% | 2.3min | 1.2% | 0.7min | 0.4% | 1.6min | 0.8% | 5.3min | 23.4% |
| default | haiku45-200k-cli2.1.132 | 58 | 10 | 17.2% | 1.3min | 0.7% | 0.2min | 0.1% | 1.2min | 0.6% | 2.3min | 33.7% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.3% | 0.2min | 0.1% | 0.4min | 0.2% | 0.8min | 31.9% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.2% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| powershell-tool | haiku45-200k-cli2.1.132 | 71 | 1 | 1.4% | 0.6min | 0.3% | 0.5min | 0.3% | 0.1min | 0.0% | 3.0min | 2.7% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.7% | 1.5min | 0.8% | -0.2min | -0.1% | 0.5min | -57.5% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |
| typescript-bun | haiku45-200k-cli2.1.132 | 70 | 25 | 35.7% | 3.3min | 1.7% | 4.2min | 2.1% | -0.9min | -0.5% | 1.7min | -116.7% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.2% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.132 | 82 | 15 | 18.3% | 3.0min | 1.5% | 0.1min | 0.1% | 2.9min | 1.4% | 0.7min | 81.2% |
| default | haiku45-200k-cli2.1.132 | 58 | 10 | 17.2% | 1.3min | 0.7% | 0.2min | 0.1% | 1.2min | 0.6% | 2.3min | 33.7% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.3% | 0.2min | 0.1% | 0.4min | 0.2% | 0.8min | 31.9% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| powershell | haiku45-200k-cli2.1.132 | 82 | 4 | 4.9% | 2.3min | 1.2% | 0.7min | 0.4% | 1.6min | 0.8% | 5.3min | 23.4% |
| powershell-tool | haiku45-200k-cli2.1.132 | 71 | 1 | 1.4% | 0.6min | 0.3% | 0.5min | 0.3% | 0.1min | 0.0% | 3.0min | 2.7% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.7% | 1.5min | 0.8% | -0.2min | -0.1% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 70 | 25 | 35.7% | 3.3min | 1.7% | 4.2min | 2.1% | -0.9min | -0.5% | 1.7min | -116.7% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 0.7% | 1.5min | 0.8% | -0.2min | -0.1% | 0.5min | -57.5% |
| typescript-bun | haiku45-200k-cli2.1.132 | 70 | 25 | 35.7% | 3.3min | 1.7% | 4.2min | 2.1% | -0.9min | -0.5% | 1.7min | -116.7% |
| bash | haiku45-200k-cli2.1.132 | 82 | 15 | 18.3% | 3.0min | 1.5% | 0.1min | 0.1% | 2.9min | 1.4% | 0.7min | 81.2% |
| default | haiku45-200k-cli2.1.132 | 58 | 10 | 17.2% | 1.3min | 0.7% | 0.2min | 0.1% | 1.2min | 0.6% | 2.3min | 33.7% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.2% | 0.1min | 0.0% | 0.3min | 0.2% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.1% | 0.0min | 0.0% | 0.2min | 0.1% | 0.4min | 28.2% |
| powershell | haiku45-200k-cli2.1.132 | 82 | 4 | 4.9% | 2.3min | 1.2% | 0.7min | 0.4% | 1.6min | 0.8% | 5.3min | 23.4% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.3% | 0.2min | 0.1% | 0.4min | 0.2% | 0.8min | 31.9% |
| powershell-tool | haiku45-200k-cli2.1.132 | 71 | 1 | 1.4% | 0.6min | 0.3% | 0.5min | 0.3% | 0.1min | 0.0% | 3.0min | 2.7% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 5.6min | -5.8% |

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 2.1% | $0.20 | 1.46% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 2.6% | $0.53 | 3.95% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.3% | $0.05 | 0.36% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.2% | $0.03 | 0.22% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 3.0% | $0.43 | 3.21% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.1% | $0.16 | 1.22% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 11.4min | 5.7% | $0.56 | 4.17% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.7% | $0.10 | 0.76% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 3 | 2.3min | 1.2% | $0.18 | 1.32% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.03 | 0.23% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 3 | 3.7min | 1.8% | $0.36 | 2.72% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.2% | $0.17 | 1.24% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 2.7% | $0.33 | 2.43% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.5% | $0.05 | 0.40% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.5% | $0.07 | 0.56% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.05 | 0.37% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 3.7min | 1.8% | $0.30 | 2.21% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.2% | $0.22 | 1.62% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.05 | 0.35% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 2 | 1.7min | 0.8% | $0.09 | 0.65% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 1.3% | $0.20 | 1.49% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.0% | $0.15 | 1.11% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 5.0min | 2.5% | $0.40 | 3.01% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.6% | $0.12 | 0.92% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.2% | $0.03 | 0.23% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.9% | $0.17 | 1.29% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.4% | $0.06 | 0.43% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 1.0% | $0.17 | 1.26% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.04 | 0.27% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 2.1% | $0.15 | 1.14% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 1.0% | $0.20 | 1.49% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.2% | $0.03 | 0.22% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.2% | $0.03 | 0.23% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.3% | $0.05 | 0.36% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.04 | 0.27% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.03 | 0.23% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.05 | 0.37% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.05 | 0.35% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.4% | $0.06 | 0.43% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.5% | $0.05 | 0.40% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.5% | $0.07 | 0.56% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.6% | $0.12 | 0.92% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.7% | $0.10 | 0.76% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 2 | 1.7min | 0.8% | $0.09 | 0.65% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.9% | $0.17 | 1.29% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.0% | $0.15 | 1.11% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 1.0% | $0.17 | 1.26% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 1.0% | $0.20 | 1.49% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.1% | $0.16 | 1.22% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.2% | $0.17 | 1.24% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.2% | $0.22 | 1.62% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 3 | 2.3min | 1.2% | $0.18 | 1.32% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 1.3% | $0.20 | 1.49% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 3 | 3.7min | 1.8% | $0.36 | 2.72% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 3.7min | 1.8% | $0.30 | 2.21% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 2.1% | $0.15 | 1.14% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 2.1% | $0.20 | 1.46% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 5.0min | 2.5% | $0.40 | 3.01% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 2.6% | $0.53 | 3.95% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 2.7% | $0.33 | 2.43% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 3.0% | $0.43 | 3.21% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 11.4min | 5.7% | $0.56 | 4.17% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.2% | $0.03 | 0.22% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.2% | $0.03 | 0.23% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.03 | 0.23% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.04 | 0.27% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.05 | 0.35% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.3% | $0.05 | 0.36% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.05 | 0.37% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.5% | $0.05 | 0.40% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.4% | $0.06 | 0.43% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.5% | $0.07 | 0.56% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 2 | 1.7min | 0.8% | $0.09 | 0.65% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.7% | $0.10 | 0.76% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.6% | $0.12 | 0.92% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.0% | $0.15 | 1.11% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 2.1% | $0.15 | 1.14% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.1% | $0.16 | 1.22% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.2% | $0.17 | 1.24% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 1.0% | $0.17 | 1.26% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.9% | $0.17 | 1.29% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 3 | 2.3min | 1.2% | $0.18 | 1.32% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 2.1% | $0.20 | 1.46% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 1.3% | $0.20 | 1.49% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 1.0% | $0.20 | 1.49% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.2% | $0.22 | 1.62% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 3.7min | 1.8% | $0.30 | 2.21% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 2.7% | $0.33 | 2.43% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 3 | 3.7min | 1.8% | $0.36 | 2.72% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 5.0min | 2.5% | $0.40 | 3.01% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 3.0% | $0.43 | 3.21% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 2.6% | $0.53 | 3.95% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 11.4min | 5.7% | $0.56 | 4.17% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 2.1% | $0.20 | 1.46% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.3% | $0.05 | 0.36% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.132 | 1 | 0.3min | 0.2% | $0.03 | 0.22% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 3.0% | $0.43 | 3.21% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 0.7% | $0.10 | 0.76% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.03 | 0.23% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 1.2% | $0.17 | 1.24% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 0.5% | $0.05 | 0.40% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 1.0min | 0.5% | $0.07 | 0.56% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.05 | 0.37% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.05 | 0.35% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 1.0% | $0.15 | 1.11% |
| fixture-rework | bash | haiku45-200k-cli2.1.132 | 1 | 1.2min | 0.6% | $0.12 | 0.92% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.2% | $0.03 | 0.23% |
| fixture-rework | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 0.8min | 0.4% | $0.06 | 0.43% |
| fixture-rework | typescript-bun | haiku45-200k-cli2.1.132 | 1 | 2.0min | 1.0% | $0.17 | 1.26% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.3% | $0.04 | 0.27% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.132 | 1 | 4.2min | 2.1% | $0.15 | 1.14% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.132 | 2 | 2.1min | 1.1% | $0.16 | 1.22% |
| actionlint-fix-cycles | default | haiku45-200k-cli2.1.132 | 2 | 2.3min | 1.2% | $0.22 | 1.62% |
| actionlint-fix-cycles | powershell-tool | haiku45-200k-cli2.1.132 | 2 | 1.7min | 0.8% | $0.09 | 0.65% |
| actionlint-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 2 | 2.7min | 1.3% | $0.20 | 1.49% |
| fixture-rework | default | haiku45-200k-cli2.1.132 | 2 | 1.8min | 0.9% | $0.17 | 1.29% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 2 | 2.0min | 1.0% | $0.20 | 1.49% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 3 | 5.1min | 2.6% | $0.53 | 3.95% |
| act-push-debug-loops | powershell-tool | haiku45-200k-cli2.1.132 | 3 | 11.4min | 5.7% | $0.56 | 4.17% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.132 | 3 | 2.3min | 1.2% | $0.18 | 1.32% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 3 | 3.7min | 1.8% | $0.36 | 2.72% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 4 | 5.3min | 2.7% | $0.33 | 2.43% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 3.7min | 1.8% | $0.30 | 2.21% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.132 | 4 | 5.0min | 2.5% | $0.40 | 3.01% |

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
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 2.5% | $0.23 | 1.68% |
| bash | haiku45-200k-cli2.1.132 | 4 | 9 | 12.1min | 6.0% | $1.22 | 9.08% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.5% | $0.08 | 0.59% |
| default | haiku45-200k-cli2.1.132 | 4 | 5 | 4.4min | 2.2% | $0.42 | 3.13% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 4.5% | $0.64 | 4.81% |
| powershell | haiku45-200k-cli2.1.132 | 5 | 6 | 7.5min | 3.7% | $0.49 | 3.65% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.8% | $0.09 | 0.67% |
| powershell-tool | haiku45-200k-cli2.1.132 | 4 | 8 | 19.0min | 9.5% | $0.93 | 6.95% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 2.0% | $0.30 | 2.24% |
| typescript-bun | haiku45-200k-cli2.1.132 | 4 | 14 | 15.7min | 7.8% | $1.25 | 9.29% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.5% | $0.08 | 0.59% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.8% | $0.09 | 0.67% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 2.0% | $0.30 | 2.24% |
| default | haiku45-200k-cli2.1.132 | 4 | 5 | 4.4min | 2.2% | $0.42 | 3.13% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 2.5% | $0.23 | 1.68% |
| powershell | haiku45-200k-cli2.1.132 | 5 | 6 | 7.5min | 3.7% | $0.49 | 3.65% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 4.5% | $0.64 | 4.81% |
| bash | haiku45-200k-cli2.1.132 | 4 | 9 | 12.1min | 6.0% | $1.22 | 9.08% |
| typescript-bun | haiku45-200k-cli2.1.132 | 4 | 14 | 15.7min | 7.8% | $1.25 | 9.29% |
| powershell-tool | haiku45-200k-cli2.1.132 | 4 | 8 | 19.0min | 9.5% | $0.93 | 6.95% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 0.5% | $0.08 | 0.59% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 0.8% | $0.09 | 0.67% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 2.5% | $0.23 | 1.68% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 2.0% | $0.30 | 2.24% |
| default | haiku45-200k-cli2.1.132 | 4 | 5 | 4.4min | 2.2% | $0.42 | 3.13% |
| powershell | haiku45-200k-cli2.1.132 | 5 | 6 | 7.5min | 3.7% | $0.49 | 3.65% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 4.5% | $0.64 | 4.81% |
| powershell-tool | haiku45-200k-cli2.1.132 | 4 | 8 | 19.0min | 9.5% | $0.93 | 6.95% |
| bash | haiku45-200k-cli2.1.132 | 4 | 9 | 12.1min | 6.0% | $1.22 | 9.08% |
| typescript-bun | haiku45-200k-cli2.1.132 | 4 | 14 | 15.7min | 7.8% | $1.25 | 9.29% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 25 | $0.71 | 5.28% |
| Miss | 2 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45-200k | 14.4 | 16.4 | 1.1 | 1.42 |
| default | haiku45-200k | 15.0 | 26.8 | 1.8 | 1.30 |
| powershell | haiku45-200k | 10.3 | 18.8 | 1.8 | 0.59 |
| powershell-tool | haiku45-200k | 14.6 | 34.2 | 2.3 | 0.66 |
| typescript-bun | haiku45-200k | 20.8 | 43.6 | 2.1 | 0.86 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | haiku45-200k | 20.8 | 43.6 | 2.1 | 0.86 |
| default | haiku45-200k | 15.0 | 26.8 | 1.8 | 1.30 |
| powershell-tool | haiku45-200k | 14.6 | 34.2 | 2.3 | 0.66 |
| bash | haiku45-200k | 14.4 | 16.4 | 1.1 | 1.42 |
| powershell | haiku45-200k | 10.3 | 18.8 | 1.8 | 0.59 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | haiku45-200k | 20.8 | 43.6 | 2.1 | 0.86 |
| powershell-tool | haiku45-200k | 14.6 | 34.2 | 2.3 | 0.66 |
| default | haiku45-200k | 15.0 | 26.8 | 1.8 | 1.30 |
| powershell | haiku45-200k | 10.3 | 18.8 | 1.8 | 0.59 |
| bash | haiku45-200k | 14.4 | 16.4 | 1.1 | 1.42 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45-200k | 14.4 | 16.4 | 1.1 | 1.42 |
| default | haiku45-200k | 15.0 | 26.8 | 1.8 | 1.30 |
| typescript-bun | haiku45-200k | 20.8 | 43.6 | 2.1 | 0.86 |
| powershell-tool | haiku45-200k | 14.6 | 34.2 | 2.3 | 0.66 |
| powershell | haiku45-200k | 10.3 | 18.8 | 1.8 | 0.59 |

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
| Environment Matrix Generator | typescript-bun | haiku45-200k | 10 | 25 | 2.5 | 201 | 319 | 0.63 |
| Artifact Cleanup Script | default | haiku45-200k | 31 | 26 | 0.8 | 411 | 321 | 1.28 |
| Artifact Cleanup Script | powershell | haiku45-200k | 11 | 24 | 2.2 | 185 | 279 | 0.66 |

</details>

## Per-Run Results

*Tests Quality = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
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
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
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
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Environment Matrix Generator | default | haiku45-200k | 5.0min | 48 | 4 | $0.44 | — | python | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
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
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
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
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
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
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Dependency License Checker | default | haiku45-200k | 4.8min | 34 | 2 | $0.32 | — | python | ok |
| Environment Matrix Generator | powershell-tool | haiku45-200k | 10.1min | 36 | 1 | $0.36 | — | powershell | ok |
| Dependency License Checker | typescript-bun | haiku45-200k | 4.5min | 37 | 4 | $0.32 | — | typescript | ok |
| Test Results Aggregator | default | haiku45-200k | 3.2min | 37 | 5 | $0.35 | — | python | ok |
| Dependency License Checker | powershell-tool | haiku45-200k | 5.2min | 38 | 1 | $0.39 | — | powershell | ok |
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Dependency License Checker | powershell | haiku45-200k | 5.0min | 43 | 0 | $0.42 | — | powershell | ok |
| Test Results Aggregator | bash | haiku45-200k | 3.4min | 45 | 0 | $0.34 | — | bash | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |
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
| Environment Matrix Generator | typescript-bun | haiku45-200k | 5.2min | 40 | 0 | $0.40 | — | typescript | ok |
| Artifact Cleanup Script | default | haiku45-200k | 4.4min | 32 | 3 | $0.37 | — | python | ok |
| Artifact Cleanup Script | powershell | haiku45-200k | 5.5min | 46 | 3 | $0.46 | — | powershell | ok |

</details>

## Notes

### Tiers

- **Duration bands:** **A+** ≤1.05×, **A** ≤1.10×, **A-** ≤1.15×, **B+** ≤1.20×, **B** ≤1.26×, **B-** ≤1.32×, **C+** ≤1.38×, **C** ≤1.44×, **C-** ≤1.51×, **D+** ≤1.58×, **D** ≤1.66×, **D-** ≤1.73×, **F** >1.73×
- **Cost bands:** **A+** ≤1.05×, **A** ≤1.11×, **A-** ≤1.16×, **B+** ≤1.22×, **B** ≤1.29×, **B-** ≤1.36×, **C+** ≤1.43×, **C** ≤1.50×, **C-** ≤1.58×, **D+** ≤1.66×, **D** ≤1.75×, **D-** ≤1.84×, **F** >1.84×

*Tests/Workflow Craft bands are absolute Overall score bands:* **A+** ≥4.7, **A** ≥4.4, **A-** ≥4.1, **B+** ≥3.8, **B** ≥3.5, **B-** ≥3.2, **C+** ≥2.9, **C** ≥2.6, **C-** ≥2.3, **D+** ≥2.0, **D** ≥1.7, **D-** ≥1.4, **F** <1.4, `—` = no data.*

### CLI Version Legend

| Variant label | CLI version | Tasks | Languages |
|---------------|-------------|-------|-----------|
| haiku45-200k | 2.1.131 | 11-semantic-version-bumper, 12-pr-label-assigner | All |
| haiku45-200k | 2.1.132 | 12-pr-label-assigner, 13-dependency-license-checker, 15-test-results-aggregator, 16-environment-matrix-generator, 17-artifact-cleanup-script | All |

---
*Generated by generate_results.py — benchmark instructions v4*