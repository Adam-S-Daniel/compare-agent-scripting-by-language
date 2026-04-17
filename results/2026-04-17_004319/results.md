# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-17 01:24:19 AM ET

**Status:** 2/35 runs completed, 33 remaining
**Total cost so far:** $4.72
**Total agent time so far:** 14.5 min

## Observations

- **Fastest (avg):** default/opus47-1m — 6.8min, then powershell/opus47-1m — 7.7min
- **Slowest (avg):** powershell/opus47-1m — 7.7min, then default/opus47-1m — 6.8min
- **Cheapest (avg):** powershell/opus47-1m — $2.27, then default/opus47-1m — $2.45
- **Most expensive (avg):** default/opus47-1m — $2.45, then powershell/opus47-1m — $2.27

- **Estimated time remaining:** 239.5min
- **Estimated total cost:** $82.56

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.8min | -1.8% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.8% | -0.1min | -0.8% | 1.1min | -11.0% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.8min | -1.8% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.8% | -0.1min | -0.8% | 1.1min | -11.0% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.8min | -1.8% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.8% | -0.1min | -0.8% | 1.1min | -11.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.8min | -1.8% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.8% | -0.1min | -0.8% | 1.1min | -11.0% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 2 | $0.19 | 3.96% |
| Miss | 0 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus47-1m | 30.0 | 70.0 | 2.3 | 1.80 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus47-1m | 30.0 | 70.0 | 2.3 | 1.80 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus47-1m | 30.0 | 70.0 | 2.3 | 1.80 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus47-1m | 30.0 | 70.0 | 2.3 | 1.80 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Mode | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | default | opus47-1m | 30 | 70 | 2.3 | 505 | 280 | 1.80 |
| Semantic Version Bumper | powershell | opus47-1m | 27 | 46 | 1.7 | 261 | 248 | 1.05 |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*