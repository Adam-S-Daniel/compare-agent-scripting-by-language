# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-17 01:31:39 AM ET

**Status:** 3/35 runs completed, 32 remaining
**Total cost so far:** $7.62
**Total agent time so far:** 22.5 min

## Observations

- **Fastest (avg):** default/opus47-1m — 6.8min, then powershell/opus47-1m — 7.7min
- **Slowest (avg):** powershell-tool/opus47-1m — 8.0min, then powershell/opus47-1m — 7.7min
- **Cheapest (avg):** powershell/opus47-1m — $2.27, then default/opus47-1m — $2.45
- **Most expensive (avg):** powershell-tool/opus47-1m — $2.90, then default/opus47-1m — $2.45

- **Estimated time remaining:** 240.3min
- **Estimated total cost:** $88.93

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| default | opus47-1m | 1 | 6.8min | 6.8min | 0.0 | 45 | $2.45 | $2.45 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.8min | -1.8% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 1.1min | -11.0% |
| powershell-tool | opus47-1m | 23 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 1.2min | -8.4% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.8min | -1.8% |
| powershell-tool | opus47-1m | 23 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 1.2min | -8.4% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 1.1min | -11.0% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.8min | -1.8% |
| powershell-tool | opus47-1m | 23 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 1.2min | -8.4% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 1.1min | -11.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| default | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.8min | -1.8% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 1.1min | -11.0% |
| powershell-tool | opus47-1m | 23 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 1.2min | -8.4% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 3.0% | $0.24 | 3.17% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 3.0% | $0.24 | 3.17% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 3.0% | $0.24 | 3.17% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 3.0% | $0.24 | 3.17% |

</details>

#### Trap Descriptions

- **repeated-test-reruns**: Same test command executed 4+ times without the underlying code changing.

#### Column Definitions

- **Fell In**: Number of runs (within that mode/model) where this trap was detected.
- **Time Lost**: Estimated wall-clock seconds wasted on the trap, based on the number of
  wasted commands multiplied by a per-command cost (15–25s for typical Bash, 45s for Docker runs, 50s for act push).
- **% of Time**: Time Lost as a percentage of total benchmark duration.
- **$ Lost**: Proportional cost impact, calculated as (Time Lost / Run Duration) × Run Cost for each affected run.
- **% of $**: $ Lost as a percentage of total benchmark cost.

### Traps by Language/Model

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus47-1m | 1 | 1 | 0.7min | 3.0% | $0.24 | 3.17% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus47-1m | 1 | 1 | 0.7min | 3.0% | $0.24 | 3.17% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus47-1m | 1 | 1 | 0.7min | 3.0% | $0.24 | 3.17% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 2 | $0.19 | 2.45% |
| Miss | 1 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus47-1m | 30.0 | 70.0 | 2.3 | 1.80 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |
| powershell-tool | opus47-1m | 33.0 | 54.0 | 1.6 | 9.43 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-tool | opus47-1m | 33.0 | 54.0 | 1.6 | 9.43 |
| default | opus47-1m | 30.0 | 70.0 | 2.3 | 1.80 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus47-1m | 30.0 | 70.0 | 2.3 | 1.80 |
| powershell-tool | opus47-1m | 33.0 | 54.0 | 1.6 | 9.43 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-tool | opus47-1m | 33.0 | 54.0 | 1.6 | 9.43 |
| default | opus47-1m | 30.0 | 70.0 | 2.3 | 1.80 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Mode | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | default | opus47-1m | 30 | 70 | 2.3 | 505 | 280 | 1.80 |
| Semantic Version Bumper | powershell | opus47-1m | 27 | 46 | 1.7 | 261 | 248 | 1.05 |
| Semantic Version Bumper | powershell-tool | opus47-1m | 33 | 54 | 1.6 | 396 | 42 | 9.43 |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*