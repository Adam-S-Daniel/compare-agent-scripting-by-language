# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-10 12:23:18 AM ET

**Status:** 2/2 runs completed, 0 remaining
**Total cost so far:** $2.28
**Total agent time so far:** 23.3 min

## Observations

- **Fastest (avg):** powershell/sonnet — 9.7min, then default/sonnet — 13.6min
- **Fastest net of traps:** powershell/sonnet — 8.6min, then default/sonnet — 12.6min
- **Slowest (avg):** default/sonnet — 13.6min, then powershell/sonnet — 9.7min
- **Slowest net of traps:** default/sonnet — 12.6min, then powershell/sonnet — 8.6min
- **Cheapest (avg):** powershell/sonnet — $0.96, then default/sonnet — $1.33
- **Cheapest net of traps:** powershell/sonnet — $0.85, then default/sonnet — $1.23
- **Most expensive (avg):** default/sonnet — $1.33, then powershell/sonnet — $0.96
- **Most expensive net of traps:** default/sonnet — $1.23, then powershell/sonnet — $0.85

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | sonnet | 1 | 13.6min | 12.6min | 1300 | 5.0 | 33 | $1.33 | $1.23 | $1.33 |
| powershell | sonnet | 1 | 9.7min | 8.6min | 1181 | 1.0 | 38 | $0.96 | $0.85 | $0.96 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | sonnet | 1 | 13.6min | 12.6min | 1300 | 5.0 | 33 | $1.33 | $1.23 | $1.33 |
| powershell | sonnet | 1 | 9.7min | 8.6min | 1181 | 1.0 | 38 | $0.96 | $0.85 | $0.96 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | sonnet | 1 | 13.6min | 12.6min | 1300 | 5.0 | 33 | $1.33 | $1.23 | $1.33 |
| powershell | sonnet | 1 | 9.7min | 8.6min | 1181 | 1.0 | 38 | $0.96 | $0.85 | $0.96 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | sonnet | 1 | 9.7min | 8.6min | 1181 | 1.0 | 38 | $0.96 | $0.85 | $0.96 |
| default | sonnet | 1 | 13.6min | 12.6min | 1300 | 5.0 | 33 | $1.33 | $1.23 | $1.33 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | sonnet | 1 | 9.7min | 8.6min | 1181 | 1.0 | 38 | $0.96 | $0.85 | $0.96 |
| default | sonnet | 1 | 13.6min | 12.6min | 1300 | 5.0 | 33 | $1.33 | $1.23 | $1.33 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | sonnet | 1 | 9.7min | 8.6min | 1181 | 1.0 | 38 | $0.96 | $0.85 | $0.96 |
| default | sonnet | 1 | 13.6min | 12.6min | 1300 | 5.0 | 33 | $1.33 | $1.23 | $1.33 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | sonnet | 1 | 13.6min | 12.6min | 1300 | 5.0 | 33 | $1.33 | $1.23 | $1.33 |
| powershell | sonnet | 1 | 9.7min | 8.6min | 1181 | 1.0 | 38 | $0.96 | $0.85 | $0.96 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | sonnet | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.0min | 0.0% |
| powershell | sonnet | 14 | 1 | 7.1% | 0.6min | 2.5% | 0.1min | 0.5% | 0.5min | 2.0% | 0.0min | 0.0% |
| **—** | **—** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | sonnet | 14 | 1 | 7.1% | 0.6min | 2.5% | 0.1min | 0.5% | 0.5min | 2.0% | 0.0min | 0.0% |
| default | sonnet | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | sonnet | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.0min | 0.0% |
| powershell | sonnet | 14 | 1 | 7.1% | 0.6min | 2.5% | 0.1min | 0.5% | 0.5min | 2.0% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | sonnet | 14 | 1 | 7.1% | 0.6min | 2.5% | 0.1min | 0.5% | 0.5min | 2.0% | 0.0min | 0.0% |
| default | sonnet | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.0min | 0.0% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| pwsh-runtime-install-overhead | powershell | sonnet | 1 | 1.1min | 4.6% | $0.11 | 4.66% |
| repeated-test-reruns | default | sonnet | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| **Total** | | | **2 runs** | **2.1min** | **8.9%** | **$0.20** | **8.92%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | sonnet | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| pwsh-runtime-install-overhead | powershell | sonnet | 1 | 1.1min | 4.6% | $0.11 | 4.66% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | sonnet | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| pwsh-runtime-install-overhead | powershell | sonnet | 1 | 1.1min | 4.6% | $0.11 | 4.66% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| pwsh-runtime-install-overhead | powershell | sonnet | 1 | 1.1min | 4.6% | $0.11 | 4.66% |
| repeated-test-reruns | default | sonnet | 1 | 1.0min | 4.3% | $0.10 | 4.26% |

</details>

#### Trap Descriptions

- **pwsh-runtime-install-overhead**: Time spent installing PowerShell and Pester inside act containers. Both are pre-installed on real GitHub runners but must be downloaded (~56MB) and installed in each act job. Measured from act step durations.
- **repeated-test-reruns**: Same test command executed 4+ times without the underlying code changing.

#### Column Definitions

- **Fell In**: Number of runs (within that mode/model) where this trap was detected.
- **Time Lost**: Estimated wall-clock seconds wasted on the trap, based on the number of
  wasted commands multiplied by a per-command cost (15–25s for typical Bash, 45s for Docker runs, 50s for act push).
- **% of Time**: Time Lost as a percentage of total benchmark duration.
- **$ Lost**: Proportional cost impact, calculated as (Time Lost / Run Duration) × Run Cost for each affected run.
- **% of $**: $ Lost as a percentage of total benchmark cost.

### Traps by Language/Model

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | sonnet | 1 | 1 | 100% | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.1min | 4.6% | $0.11 | 4.66% |
| **Total** | | **2** | **2** | **100%** | **2** | **2.1min** | **8.9%** | **$0.20** | **8.92%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | sonnet | 1 | 1 | 100% | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.1min | 4.6% | $0.11 | 4.66% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | sonnet | 1 | 1 | 100% | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.1min | 4.6% | $0.11 | 4.66% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | sonnet | 1 | 1 | 100% | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.1min | 4.6% | $0.11 | 4.66% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 2 | $0.08 | 3.41% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **2** | **$0.08** | **3.41%** |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | sonnet | 94.0 | 47.0 | 0.5 | 0.59 |
| powershell | sonnet | 27.0 | 35.0 | 1.3 | 0.49 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | sonnet | 94.0 | 47.0 | 0.5 | 0.59 |
| powershell | sonnet | 27.0 | 35.0 | 1.3 | 0.49 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | sonnet | 94.0 | 47.0 | 0.5 | 0.59 |
| powershell | sonnet | 27.0 | 35.0 | 1.3 | 0.49 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | sonnet | 94.0 | 47.0 | 0.5 | 0.59 |
| powershell | sonnet | 27.0 | 35.0 | 1.3 | 0.49 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Mode | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | default | sonnet | 94 | 47 | 0.5 | 325 | 548 | 0.59 |
| Semantic Version Bumper | powershell | sonnet | 27 | 35 | 1.3 | 241 | 495 | 0.49 |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | sonnet | 13.6min | 33 | 1300 | 5 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | sonnet | 9.7min | 38 | 1181 | 1 | $0.96 | powershell | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | sonnet | 13.6min | 33 | 1300 | 5 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | sonnet | 9.7min | 38 | 1181 | 1 | $0.96 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | sonnet | 13.6min | 33 | 1300 | 5 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | sonnet | 9.7min | 38 | 1181 | 1 | $0.96 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | sonnet | 9.7min | 38 | 1181 | 1 | $0.96 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 13.6min | 33 | 1300 | 5 | $1.33 | python | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | sonnet | 9.7min | 38 | 1181 | 1 | $0.96 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 13.6min | 33 | 1300 | 5 | $1.33 | python | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | sonnet | 13.6min | 33 | 1300 | 5 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | sonnet | 9.7min | 38 | 1181 | 1 | $0.96 | powershell | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v3*