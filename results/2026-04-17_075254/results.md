# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-17 08:11:47 AM ET

**Status:** 3/35 runs completed, 32 remaining
**Total cost so far:** $3.87
**Total agent time so far:** 17.9 min

## Observations

- **Fastest (avg):** default/opus47-1m — 4.6min, then powershell/opus47-1m — 5.0min
- **Slowest (avg):** powershell-tool/opus47-1m — 8.4min, then powershell/opus47-1m — 5.0min
- **Cheapest (avg):** default/opus47-1m — $0.88, then powershell/opus47-1m — $1.25
- **Most expensive (avg):** powershell-tool/opus47-1m — $1.73, then powershell/opus47-1m — $1.25

- **Estimated time remaining:** 191.5min
- **Estimated total cost:** $45.09

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 4.6min | 4.6min | 0.0 | 24 | $0.88 | $0.88 |
| powershell | opus47-1m | 1 | 5.0min | 5.0min | 0.0 | 29 | $1.25 | $1.25 |
| powershell-tool | opus47-1m | 1 | 8.4min | 8.4min | 1.0 | 33 | $1.73 | $1.73 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 4.6min | 4.6min | 0.0 | 24 | $0.88 | $0.88 |
| powershell | opus47-1m | 1 | 5.0min | 5.0min | 0.0 | 29 | $1.25 | $1.25 |
| powershell-tool | opus47-1m | 1 | 8.4min | 8.4min | 1.0 | 33 | $1.73 | $1.73 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 4.6min | 4.6min | 0.0 | 24 | $0.88 | $0.88 |
| powershell | opus47-1m | 1 | 5.0min | 5.0min | 0.0 | 29 | $1.25 | $1.25 |
| powershell-tool | opus47-1m | 1 | 8.4min | 8.4min | 1.0 | 33 | $1.73 | $1.73 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 4.6min | 4.6min | 0.0 | 24 | $0.88 | $0.88 |
| powershell | opus47-1m | 1 | 5.0min | 5.0min | 0.0 | 29 | $1.25 | $1.25 |
| powershell-tool | opus47-1m | 1 | 8.4min | 8.4min | 1.0 | 33 | $1.73 | $1.73 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 4.6min | 4.6min | 0.0 | 24 | $0.88 | $0.88 |
| powershell | opus47-1m | 1 | 5.0min | 5.0min | 0.0 | 29 | $1.25 | $1.25 |
| powershell-tool | opus47-1m | 1 | 8.4min | 8.4min | 1.0 | 33 | $1.73 | $1.73 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 4.6min | 4.6min | 0.0 | 24 | $0.88 | $0.88 |
| powershell | opus47-1m | 1 | 5.0min | 5.0min | 0.0 | 29 | $1.25 | $1.25 |
| powershell-tool | opus47-1m | 1 | 8.4min | 8.4min | 1.0 | 33 | $1.73 | $1.73 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | opus47-1m | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.8% | -0.2min | -0.8% | 1.5min | -9.8% |
| powershell | opus47-1m | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.2min | -56.3% |
| powershell-tool | opus47-1m | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 3.0min | -2.1% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell-tool | opus47-1m | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 3.0min | -2.1% |
| powershell | opus47-1m | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.2min | -56.3% |
| default | opus47-1m | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.8% | -0.2min | -0.8% | 1.5min | -9.8% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell-tool | opus47-1m | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 3.0min | -2.1% |
| default | opus47-1m | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.8% | -0.2min | -0.8% | 1.5min | -9.8% |
| powershell | opus47-1m | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.2min | -56.3% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | opus47-1m | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.8% | -0.2min | -0.8% | 1.5min | -9.8% |
| powershell | opus47-1m | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.2min | -56.3% |
| powershell-tool | opus47-1m | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 3.0min | -2.1% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 1 | $0.09 | 2.42% |
| Miss | 2 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus47-1m | 25.0 | 42.0 | 1.7 | 1.61 |
| powershell | opus47-1m | 30.0 | 47.0 | 1.6 | 1.79 |
| powershell-tool | opus47-1m | 22.0 | 33.0 | 1.5 | 0.98 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell | opus47-1m | 30.0 | 47.0 | 1.6 | 1.79 |
| default | opus47-1m | 25.0 | 42.0 | 1.7 | 1.61 |
| powershell-tool | opus47-1m | 22.0 | 33.0 | 1.5 | 0.98 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell | opus47-1m | 30.0 | 47.0 | 1.6 | 1.79 |
| default | opus47-1m | 25.0 | 42.0 | 1.7 | 1.61 |
| powershell-tool | opus47-1m | 22.0 | 33.0 | 1.5 | 0.98 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell | opus47-1m | 30.0 | 47.0 | 1.6 | 1.79 |
| default | opus47-1m | 25.0 | 42.0 | 1.7 | 1.61 |
| powershell-tool | opus47-1m | 22.0 | 33.0 | 1.5 | 0.98 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Mode | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | default | opus47-1m | 25 | 42 | 1.7 | 333 | 207 | 1.61 |
| Semantic Version Bumper | powershell | opus47-1m | 30 | 47 | 1.6 | 174 | 97 | 1.79 |
| Semantic Version Bumper | powershell-tool | opus47-1m | 22 | 33 | 1.5 | 163 | 167 | 0.98 |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 4.6min | 24 | 0 | $0.88 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 5.0min | 29 | 0 | $1.25 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.4min | 33 | 1 | $1.73 | powershell | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 4.6min | 24 | 0 | $0.88 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 5.0min | 29 | 0 | $1.25 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.4min | 33 | 1 | $1.73 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 4.6min | 24 | 0 | $0.88 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 5.0min | 29 | 0 | $1.25 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.4min | 33 | 1 | $1.73 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 4.6min | 24 | 0 | $0.88 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 5.0min | 29 | 0 | $1.25 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.4min | 33 | 1 | $1.73 | powershell | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 4.6min | 24 | 0 | $0.88 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 5.0min | 29 | 0 | $1.25 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.4min | 33 | 1 | $1.73 | powershell | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*