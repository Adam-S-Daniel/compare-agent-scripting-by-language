# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 03:43:53 PM ET

**Status:** 2/64 runs completed, 62 remaining
**Total cost so far:** $2.36
**Total agent time so far:** 14.0 min

## Observations

- **Fastest (avg):** powershell/opus — 6.9min, then default/opus — 7.1min
- **Slowest (avg):** default/opus — 7.1min, then powershell/opus — 6.9min
- **Cheapest (avg):** powershell/opus — $1.04, then default/opus — $1.33
- **Most expensive (avg):** default/opus — $1.33, then powershell/opus — $1.04

- **Estimated time remaining:** 435.2min
- **Estimated total cost:** $75.66

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 1.5min | -5.7% |
| **Total** | | **14** | **0** | **0.0%** | **0.0min** | **0.0%** | **0.1min** | **1.0%** | **-0.1min** | **-1.0%** | **1.5min** | **-9.2%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 1.5min | -5.7% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 1.5min | -5.7% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 1.5min | -5.7% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 2 | $0.39 | 16.63% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **2** | **$0.39** | **16.63%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*