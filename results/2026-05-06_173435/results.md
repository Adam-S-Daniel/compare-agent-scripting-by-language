# Benchmark Results: Language Comparison

**Last updated:** 2026-05-06 07:05:13 PM ET — 8/35 runs completed, 27 remaining; total cost $4.28; total agent time 86.9 min.

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

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (5.7min) | A+ ($0.38) | — | — |
| powershell-tool | haiku45-200k | D- (9.9min) | C+ ($0.53) | — | — |
| bash | haiku45-200k | D (9.2min) | C- ($0.57) | — | — |
| typescript-bun | haiku45-200k | C- (8.5min) | D ($0.63) | — | — |
| powershell | haiku45-200k | D- (9.8min) | D- ($0.70) | — | — |


<details>
<summary>Sorted by Duration tier (best-first), then avg of Cost/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (5.7min) | A+ ($0.38) | — | — |
| typescript-bun | haiku45-200k | C- (8.5min) | D ($0.63) | — | — |
| bash | haiku45-200k | D (9.2min) | C- ($0.57) | — | — |
| powershell-tool | haiku45-200k | D- (9.9min) | C+ ($0.53) | — | — |
| powershell | haiku45-200k | D- (9.8min) | D- ($0.70) | — | — |

</details>

<details>
<summary>Sorted by Cost tier (best-first), then avg of Duration/Tests/Workflow Craft tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (5.7min) | A+ ($0.38) | — | — |
| powershell-tool | haiku45-200k | D- (9.9min) | C+ ($0.53) | — | — |
| bash | haiku45-200k | D (9.2min) | C- ($0.57) | — | — |
| typescript-bun | haiku45-200k | C- (8.5min) | D ($0.63) | — | — |
| powershell | haiku45-200k | D- (9.8min) | D- ($0.70) | — | — |

</details>

<details>
<summary>Sorted by Tests Quality tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (5.7min) | A+ ($0.38) | — | — |
| powershell-tool | haiku45-200k | D- (9.9min) | C+ ($0.53) | — | — |
| bash | haiku45-200k | D (9.2min) | C- ($0.57) | — | — |
| typescript-bun | haiku45-200k | C- (8.5min) | D ($0.63) | — | — |
| powershell | haiku45-200k | D- (9.8min) | D- ($0.70) | — | — |

</details>

<details>
<summary>Sorted by Workflow Craft tier (best-first; no-data last), then avg of other tiers</summary>

| Language | Model | Duration | Cost | Tests Quality | Workflow Craft |
|----------|-------|----------|------|-----------|-------------|
| default | haiku45-200k | A+ (5.7min) | A+ ($0.38) | — | — |
| powershell-tool | haiku45-200k | D- (9.9min) | C+ ($0.53) | — | — |
| bash | haiku45-200k | D (9.2min) | C- ($0.57) | — | — |
| typescript-bun | haiku45-200k | C- (8.5min) | D ($0.63) | — | — |
| powershell | haiku45-200k | D- (9.8min) | D- ($0.70) | — | — |

</details>

- **Estimated time remaining:** 293.3min
- **Estimated total cost:** $18.74

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
| bash | haiku45-200k | 2 | 9.2min | 9.2min | 4.5 | 62 | $0.57 | $1.15 | — | — |
| default | haiku45-200k | 2 | 5.7min | 5.1min | 1.5 | 40 | $0.38 | $0.76 | — | — |
| powershell | haiku45-200k | 1 | 9.8min | 0.7min | 3.0 | 71 | $0.70 | $0.70 | — | — |
| powershell-tool | haiku45-200k | 1 | 9.9min | 8.2min | 2.0 | 48 | $0.53 | $0.53 | — | — |
| typescript-bun | haiku45-200k | 1 | 8.5min | 4.4min | 4.0 | 55 | $0.63 | $0.63 | — | — |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 2 | 5.7min | 5.1min | 1.5 | 40 | $0.38 | $0.76 | — | — |
| powershell-tool | haiku45-200k | 1 | 9.9min | 8.2min | 2.0 | 48 | $0.53 | $0.53 | — | — |
| bash | haiku45-200k | 2 | 9.2min | 9.2min | 4.5 | 62 | $0.57 | $1.15 | — | — |
| typescript-bun | haiku45-200k | 1 | 8.5min | 4.4min | 4.0 | 55 | $0.63 | $0.63 | — | — |
| powershell | haiku45-200k | 1 | 9.8min | 0.7min | 3.0 | 71 | $0.70 | $0.70 | — | — |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 2 | 5.7min | 5.1min | 1.5 | 40 | $0.38 | $0.76 | — | — |
| typescript-bun | haiku45-200k | 1 | 8.5min | 4.4min | 4.0 | 55 | $0.63 | $0.63 | — | — |
| bash | haiku45-200k | 2 | 9.2min | 9.2min | 4.5 | 62 | $0.57 | $1.15 | — | — |
| powershell | haiku45-200k | 1 | 9.8min | 0.7min | 3.0 | 71 | $0.70 | $0.70 | — | — |
| powershell-tool | haiku45-200k | 1 | 9.9min | 8.2min | 2.0 | 48 | $0.53 | $0.53 | — | — |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| powershell | haiku45-200k | 1 | 9.8min | 0.7min | 3.0 | 71 | $0.70 | $0.70 | — | — |
| typescript-bun | haiku45-200k | 1 | 8.5min | 4.4min | 4.0 | 55 | $0.63 | $0.63 | — | — |
| default | haiku45-200k | 2 | 5.7min | 5.1min | 1.5 | 40 | $0.38 | $0.76 | — | — |
| powershell-tool | haiku45-200k | 1 | 9.9min | 8.2min | 2.0 | 48 | $0.53 | $0.53 | — | — |
| bash | haiku45-200k | 2 | 9.2min | 9.2min | 4.5 | 62 | $0.57 | $1.15 | — | — |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 2 | 5.7min | 5.1min | 1.5 | 40 | $0.38 | $0.76 | — | — |
| powershell-tool | haiku45-200k | 1 | 9.9min | 8.2min | 2.0 | 48 | $0.53 | $0.53 | — | — |
| powershell | haiku45-200k | 1 | 9.8min | 0.7min | 3.0 | 71 | $0.70 | $0.70 | — | — |
| typescript-bun | haiku45-200k | 1 | 8.5min | 4.4min | 4.0 | 55 | $0.63 | $0.63 | — | — |
| bash | haiku45-200k | 2 | 9.2min | 9.2min | 4.5 | 62 | $0.57 | $1.15 | — | — |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| default | haiku45-200k | 2 | 5.7min | 5.1min | 1.5 | 40 | $0.38 | $0.76 | — | — |
| powershell-tool | haiku45-200k | 1 | 9.9min | 8.2min | 2.0 | 48 | $0.53 | $0.53 | — | — |
| typescript-bun | haiku45-200k | 1 | 8.5min | 4.4min | 4.0 | 55 | $0.63 | $0.63 | — | — |
| bash | haiku45-200k | 2 | 9.2min | 9.2min | 4.5 | 62 | $0.57 | $1.15 | — | — |
| powershell | haiku45-200k | 1 | 9.8min | 0.7min | 3.0 | 71 | $0.70 | $0.70 | — | — |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 2 | 9.2min | 9.2min | 4.5 | 62 | $0.57 | $1.15 | — | — |
| default | haiku45-200k | 2 | 5.7min | 5.1min | 1.5 | 40 | $0.38 | $0.76 | — | — |
| powershell | haiku45-200k | 1 | 9.8min | 0.7min | 3.0 | 71 | $0.70 | $0.70 | — | — |
| powershell-tool | haiku45-200k | 1 | 9.9min | 8.2min | 2.0 | 48 | $0.53 | $0.53 | — | — |
| typescript-bun | haiku45-200k | 1 | 8.5min | 4.4min | 4.0 | 55 | $0.63 | $0.63 | — | — |

</details>

<details>
<summary>Sorted by deliverable-quality score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg Tests Quality | Avg Workflow Craft |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|-----------------|
| bash | haiku45-200k | 2 | 9.2min | 9.2min | 4.5 | 62 | $0.57 | $1.15 | — | — |
| default | haiku45-200k | 2 | 5.7min | 5.1min | 1.5 | 40 | $0.38 | $0.76 | — | — |
| powershell | haiku45-200k | 1 | 9.8min | 0.7min | 3.0 | 71 | $0.70 | $0.70 | — | — |
| powershell-tool | haiku45-200k | 1 | 9.9min | 8.2min | 2.0 | 48 | $0.53 | $0.53 | — | — |
| typescript-bun | haiku45-200k | 1 | 8.5min | 4.4min | 4.0 | 55 | $0.63 | $0.63 | — | — |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

*`% of Test Time Saved` = `net / (net + test_time) × 100` — the share of total (would-have-been + actually-spent) test time that hooks eliminated. Bounded in (-∞, 100%) without an artificial cap; near 100% means hooks substituted for almost all of the hypothetical test work.*

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.2% | 0.0min | 0.0% | 0.2min | 0.2% | 0.4min | 28.2% |
| bash | haiku45-200k-cli2.1.132 | 18 | 4 | 22.2% | 0.8min | 0.9% | 0.0min | 0.0% | 0.8min | 0.9% | 0.2min | 83.5% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.5% | 0.1min | 0.1% | 0.3min | 0.4% | 0.0min | 91.1% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.7% | 0.2min | 0.3% | 0.4min | 0.4% | 0.8min | 31.9% |
| powershell | haiku45-200k-cli2.1.132 | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.0min | -16.4% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.4% | -0.3min | -0.4% | 5.6min | -5.8% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 1.5% | 1.5min | 1.7% | -0.2min | -0.2% | 0.5min | -57.5% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45-200k-cli2.1.132 | 18 | 4 | 22.2% | 0.8min | 0.9% | 0.0min | 0.0% | 0.8min | 0.9% | 0.2min | 83.5% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.7% | 0.2min | 0.3% | 0.4min | 0.4% | 0.8min | 31.9% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.5% | 0.1min | 0.1% | 0.3min | 0.4% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.2% | 0.0min | 0.0% | 0.2min | 0.2% | 0.4min | 28.2% |
| powershell | haiku45-200k-cli2.1.132 | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.0min | -16.4% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 1.5% | 1.5min | 1.7% | -0.2min | -0.2% | 0.5min | -57.5% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.4% | -0.3min | -0.4% | 5.6min | -5.8% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.5% | 0.1min | 0.1% | 0.3min | 0.4% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.132 | 18 | 4 | 22.2% | 0.8min | 0.9% | 0.0min | 0.0% | 0.8min | 0.9% | 0.2min | 83.5% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.7% | 0.2min | 0.3% | 0.4min | 0.4% | 0.8min | 31.9% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.2% | 0.0min | 0.0% | 0.2min | 0.2% | 0.4min | 28.2% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.4% | -0.3min | -0.4% | 5.6min | -5.8% |
| powershell | haiku45-200k-cli2.1.132 | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.0min | -16.4% |
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 1.5% | 1.5min | 1.7% | -0.2min | -0.2% | 0.5min | -57.5% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | haiku45-200k-cli2.1.131 | 25 | 10 | 40.0% | 1.3min | 1.5% | 1.5min | 1.7% | -0.2min | -0.2% | 0.5min | -57.5% |
| bash | haiku45-200k-cli2.1.132 | 18 | 4 | 22.2% | 0.8min | 0.9% | 0.0min | 0.0% | 0.8min | 0.9% | 0.2min | 83.5% |
| default | haiku45-200k-cli2.1.131 | 27 | 3 | 11.1% | 0.4min | 0.5% | 0.1min | 0.1% | 0.3min | 0.4% | 0.0min | 91.1% |
| bash | haiku45-200k-cli2.1.131 | 20 | 1 | 5.0% | 0.2min | 0.2% | 0.0min | 0.0% | 0.2min | 0.2% | 0.4min | 28.2% |
| powershell | haiku45-200k-cli2.1.131 | 23 | 1 | 4.3% | 0.6min | 0.7% | 0.2min | 0.3% | 0.4min | 0.4% | 0.8min | 31.9% |
| powershell | haiku45-200k-cli2.1.132 | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.0min | -16.4% |
| powershell-tool | haiku45-200k-cli2.1.131 | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.4% | -0.3min | -0.4% | 5.6min | -5.8% |

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 4.9% | $0.20 | 4.56% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 1 | 0.6min | 0.7% | $0.06 | 1.32% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.7% | $0.05 | 1.13% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 7.0% | $0.43 | 10.06% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 1.6% | $0.10 | 2.38% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.03 | 0.71% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 1 | 1.0min | 1.2% | $0.09 | 2.15% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 2.7% | $0.17 | 3.88% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 1 | 1.7min | 1.9% | $0.03 | 0.68% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 1.2% | $0.05 | 1.26% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.05 | 1.16% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 2.3% | $0.15 | 3.49% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.05 | 1.11% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.04 | 0.83% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.6% | $0.03 | 0.71% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 1 | 0.5min | 0.6% | $0.05 | 1.08% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.6% | $0.03 | 0.71% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 1 | 0.5min | 0.6% | $0.05 | 1.08% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.7% | $0.05 | 1.13% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 1 | 0.6min | 0.7% | $0.06 | 1.32% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.04 | 0.83% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.03 | 0.71% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.05 | 1.16% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.05 | 1.11% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 1 | 1.0min | 1.2% | $0.09 | 2.15% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 1.2% | $0.05 | 1.26% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 1.6% | $0.10 | 2.38% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 1 | 1.7min | 1.9% | $0.03 | 0.68% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 2.3% | $0.15 | 3.49% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 2.7% | $0.17 | 3.88% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 4.9% | $0.20 | 4.56% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 7.0% | $0.43 | 10.06% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 1 | 1.7min | 1.9% | $0.03 | 0.68% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.6% | $0.03 | 0.71% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.03 | 0.71% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.04 | 0.83% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 1 | 0.5min | 0.6% | $0.05 | 1.08% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.05 | 1.11% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.7% | $0.05 | 1.13% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.05 | 1.16% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 1.2% | $0.05 | 1.26% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 1 | 0.6min | 0.7% | $0.06 | 1.32% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 1 | 1.0min | 1.2% | $0.09 | 2.15% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 1.6% | $0.10 | 2.38% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 2.3% | $0.15 | 3.49% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 2.7% | $0.17 | 3.88% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 4.9% | $0.20 | 4.56% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 7.0% | $0.43 | 10.06% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | haiku45-200k-cli2.1.131 | 1 | 4.3min | 4.9% | $0.20 | 4.56% |
| act-push-debug-loops | bash | haiku45-200k-cli2.1.132 | 1 | 0.6min | 0.7% | $0.06 | 1.32% |
| act-push-debug-loops | default | haiku45-200k-cli2.1.131 | 1 | 0.6min | 0.7% | $0.05 | 1.13% |
| act-push-debug-loops | powershell | haiku45-200k-cli2.1.131 | 1 | 6.1min | 7.0% | $0.43 | 10.06% |
| act-push-debug-loops | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 1.4min | 1.6% | $0.10 | 2.38% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.03 | 0.71% |
| repeated-test-reruns | bash | haiku45-200k-cli2.1.132 | 1 | 1.0min | 1.2% | $0.09 | 2.15% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.131 | 1 | 2.3min | 2.7% | $0.17 | 3.88% |
| repeated-test-reruns | powershell | haiku45-200k-cli2.1.132 | 1 | 1.7min | 1.9% | $0.03 | 0.68% |
| repeated-test-reruns | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 1.0min | 1.2% | $0.05 | 1.26% |
| repeated-test-reruns | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.05 | 1.16% |
| ts-type-error-fix-cycles | typescript-bun | haiku45-200k-cli2.1.131 | 1 | 2.0min | 2.3% | $0.15 | 3.49% |
| actionlint-fix-cycles | powershell | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.05 | 1.11% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45-200k-cli2.1.131 | 1 | 0.7min | 0.8% | $0.04 | 0.83% |
| fixture-rework | default | haiku45-200k-cli2.1.131 | 1 | 0.5min | 0.6% | $0.03 | 0.71% |
| act-permission-path-errors | bash | haiku45-200k-cli2.1.132 | 1 | 0.5min | 0.6% | $0.05 | 1.08% |

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
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 5.7% | $0.23 | 5.27% |
| bash | haiku45-200k-cli2.1.132 | 1 | 3 | 2.1min | 2.4% | $0.19 | 4.55% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 1.3% | $0.08 | 1.84% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 10.4% | $0.64 | 15.04% |
| powershell | haiku45-200k-cli2.1.132 | 1 | 1 | 1.7min | 1.9% | $0.03 | 0.68% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 1.9% | $0.09 | 2.09% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 4.6% | $0.30 | 7.02% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 1.3% | $0.08 | 1.84% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 1.9% | $0.09 | 2.09% |
| powershell | haiku45-200k-cli2.1.132 | 1 | 1 | 1.7min | 1.9% | $0.03 | 0.68% |
| bash | haiku45-200k-cli2.1.132 | 1 | 3 | 2.1min | 2.4% | $0.19 | 4.55% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 4.6% | $0.30 | 7.02% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 5.7% | $0.23 | 5.27% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 10.4% | $0.64 | 15.04% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| powershell | haiku45-200k-cli2.1.132 | 1 | 1 | 1.7min | 1.9% | $0.03 | 0.68% |
| default | haiku45-200k-cli2.1.131 | 2 | 2 | 1.1min | 1.3% | $0.08 | 1.84% |
| powershell-tool | haiku45-200k-cli2.1.131 | 1 | 2 | 1.7min | 1.9% | $0.09 | 2.09% |
| bash | haiku45-200k-cli2.1.132 | 1 | 3 | 2.1min | 2.4% | $0.19 | 4.55% |
| bash | haiku45-200k-cli2.1.131 | 1 | 2 | 4.9min | 5.7% | $0.23 | 5.27% |
| typescript-bun | haiku45-200k-cli2.1.131 | 1 | 3 | 4.0min | 4.6% | $0.30 | 7.02% |
| powershell | haiku45-200k-cli2.1.131 | 1 | 3 | 9.1min | 10.4% | $0.64 | 15.04% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 7 | $0.20 | 4.57% |
| Miss | 1 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45-200k | 17.5 | 19.5 | 1.1 | 0.95 |
| default | haiku45-200k | 7.0 | 9.5 | 1.4 | 1.25 |
| powershell | haiku45-200k | 15.5 | 22.0 | 1.4 | 0.70 |
| powershell-tool | haiku45-200k | 20.0 | 44.0 | 2.2 | 0.38 |
| typescript-bun | haiku45-200k | 38.0 | 76.0 | 2.0 | 0.86 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | haiku45-200k | 38.0 | 76.0 | 2.0 | 0.86 |
| powershell-tool | haiku45-200k | 20.0 | 44.0 | 2.2 | 0.38 |
| bash | haiku45-200k | 17.5 | 19.5 | 1.1 | 0.95 |
| powershell | haiku45-200k | 15.5 | 22.0 | 1.4 | 0.70 |
| default | haiku45-200k | 7.0 | 9.5 | 1.4 | 1.25 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | haiku45-200k | 38.0 | 76.0 | 2.0 | 0.86 |
| powershell-tool | haiku45-200k | 20.0 | 44.0 | 2.2 | 0.38 |
| powershell | haiku45-200k | 15.5 | 22.0 | 1.4 | 0.70 |
| bash | haiku45-200k | 17.5 | 19.5 | 1.1 | 0.95 |
| default | haiku45-200k | 7.0 | 9.5 | 1.4 | 1.25 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | haiku45-200k | 7.0 | 9.5 | 1.4 | 1.25 |
| bash | haiku45-200k | 17.5 | 19.5 | 1.1 | 0.95 |
| typescript-bun | haiku45-200k | 38.0 | 76.0 | 2.0 | 0.86 |
| powershell | haiku45-200k | 15.5 | 22.0 | 1.4 | 0.70 |
| powershell-tool | haiku45-200k | 20.0 | 44.0 | 2.2 | 0.38 |

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

</details>

## Per-Run Results

*Tests Quality = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | Tests Quality | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | default | haiku45-200k | 3.8min | 31 | 2 | $0.31 | — | python | ok |
| Semantic Version Bumper | powershell-tool | haiku45-200k | 9.9min | 48 | 2 | $0.53 | — | powershell | ok |
| PR Label Assigner | powershell | haiku45-200k | 29.1min | 49 | 1 | $0.51 | — | powershell | timeout |
| Semantic Version Bumper | default | haiku45-200k | 7.5min | 50 | 1 | $0.45 | — | javascript | ok |
| Semantic Version Bumper | bash | haiku45-200k | 11.9min | 55 | 3 | $0.54 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45-200k | 8.5min | 55 | 4 | $0.63 | — | typescript | ok |
| PR Label Assigner | bash | haiku45-200k | 6.5min | 68 | 6 | $0.60 | — | bash | ok |
| Semantic Version Bumper | powershell | haiku45-200k | 9.8min | 71 | 3 | $0.70 | — | powershell | ok |

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

</details>

## Notes

### Tiers

- **Duration bands:** **A+** ≤1.05×, **A** ≤1.10×, **A-** ≤1.15×, **B+** ≤1.20×, **B** ≤1.26×, **B-** ≤1.32×, **C+** ≤1.38×, **C** ≤1.45×, **C-** ≤1.52×, **D+** ≤1.59×, **D** ≤1.67×, **D-** ≤1.75×, **F** >1.75×
- **Cost bands:** **A+** ≤1.05×, **A** ≤1.11×, **A-** ≤1.16×, **B+** ≤1.22×, **B** ≤1.28×, **B-** ≤1.35×, **C+** ≤1.42×, **C** ≤1.49×, **C-** ≤1.57×, **D+** ≤1.65×, **D** ≤1.73×, **D-** ≤1.82×, **F** >1.82×

*Tests/Workflow Craft bands are absolute Overall score bands:* **A+** ≥4.7, **A** ≥4.4, **A-** ≥4.1, **B+** ≥3.8, **B** ≥3.5, **B-** ≥3.2, **C+** ≥2.9, **C** ≥2.6, **C-** ≥2.3, **D+** ≥2.0, **D** ≥1.7, **D-** ≥1.4, **F** <1.4, `—` = no data.*

### CLI Version Legend

| Variant label | CLI version | Tasks | Languages |
|---------------|-------------|-------|-----------|
| haiku45-200k | 2.1.131 | All | All |
| haiku45-200k | 2.1.132 | 12-pr-label-assigner | bash |

---
*Generated by generate_results.py — benchmark instructions v4*