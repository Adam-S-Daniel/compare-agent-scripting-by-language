# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-17 02:15:48 AM ET

**Status:** 6/35 runs completed, 29 remaining
**Total cost so far:** $17.03
**Total agent time so far:** 61.8 min

## Observations

- **Fastest (avg):** default/opus47-1m — 7.3min, then powershell/opus47-1m — 7.7min
- **Slowest (avg):** bash/opus47-1m — 17.2min, then typescript-bun/opus47-1m — 14.3min
- **Cheapest (avg):** powershell/opus47-1m — $2.27, then default/opus47-1m — $2.35
- **Most expensive (avg):** typescript-bun/opus47-1m — $4.21, then bash/opus47-1m — $2.95

- **Estimated time remaining:** 298.7min
- **Estimated total cost:** $99.37

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus47-1m | 1 | 17.2min | 17.2min | 2.0 | 48 | $2.95 | $2.95 |
| default | opus47-1m | 2 | 7.3min | 7.3min | 0.0 | 44 | $2.35 | $4.70 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |
| typescript-bun | opus47-1m | 1 | 14.3min | 5.7min | 1.0 | 80 | $4.21 | $4.21 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| default | opus47-1m | 2 | 7.3min | 7.3min | 0.0 | 44 | $2.35 | $4.70 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |
| bash | opus47-1m | 1 | 17.2min | 17.2min | 2.0 | 48 | $2.95 | $2.95 |
| typescript-bun | opus47-1m | 1 | 14.3min | 5.7min | 1.0 | 80 | $4.21 | $4.21 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 2 | 7.3min | 7.3min | 0.0 | 44 | $2.35 | $4.70 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |
| typescript-bun | opus47-1m | 1 | 14.3min | 5.7min | 1.0 | 80 | $4.21 | $4.21 |
| bash | opus47-1m | 1 | 17.2min | 17.2min | 2.0 | 48 | $2.95 | $2.95 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | opus47-1m | 1 | 14.3min | 5.7min | 1.0 | 80 | $4.21 | $4.21 |
| default | opus47-1m | 2 | 7.3min | 7.3min | 0.0 | 44 | $2.35 | $4.70 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| bash | opus47-1m | 1 | 17.2min | 17.2min | 2.0 | 48 | $2.95 | $2.95 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 2 | 7.3min | 7.3min | 0.0 | 44 | $2.35 | $4.70 |
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |
| typescript-bun | opus47-1m | 1 | 14.3min | 5.7min | 1.0 | 80 | $4.21 | $4.21 |
| bash | opus47-1m | 1 | 17.2min | 17.2min | 2.0 | 48 | $2.95 | $2.95 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus47-1m | 1 | 7.7min | 7.7min | 0.0 | 38 | $2.27 | $2.27 |
| default | opus47-1m | 2 | 7.3min | 7.3min | 0.0 | 44 | $2.35 | $4.70 |
| bash | opus47-1m | 1 | 17.2min | 17.2min | 2.0 | 48 | $2.95 | $2.95 |
| powershell-tool | opus47-1m | 1 | 8.0min | 7.3min | 0.0 | 49 | $2.90 | $2.90 |
| typescript-bun | opus47-1m | 1 | 14.3min | 5.7min | 1.0 | 80 | $4.21 | $4.21 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus47-1m | 17 | 2 | 11.8% | 0.4min | 0.6% | 0.0min | 0.0% | 0.4min | 0.6% | 6.8min | 5.8% |
| default | opus47-1m | 35 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.0% | -0.0min | -0.0% | 2.0min | -1.4% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.1min | -11.0% |
| powershell-tool | opus47-1m | 23 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.2min | -8.4% |
| typescript-bun | opus47-1m | 30 | 23 | 76.7% | 3.1min | 5.0% | 0.4min | 0.7% | 2.6min | 4.3% | 3.2min | 82.3% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 30 | 23 | 76.7% | 3.1min | 5.0% | 0.4min | 0.7% | 2.6min | 4.3% | 3.2min | 82.3% |
| bash | opus47-1m | 17 | 2 | 11.8% | 0.4min | 0.6% | 0.0min | 0.0% | 0.4min | 0.6% | 6.8min | 5.8% |
| default | opus47-1m | 35 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.0% | -0.0min | -0.0% | 2.0min | -1.4% |
| powershell-tool | opus47-1m | 23 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.2min | -8.4% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.1min | -11.0% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 30 | 23 | 76.7% | 3.1min | 5.0% | 0.4min | 0.7% | 2.6min | 4.3% | 3.2min | 82.3% |
| bash | opus47-1m | 17 | 2 | 11.8% | 0.4min | 0.6% | 0.0min | 0.0% | 0.4min | 0.6% | 6.8min | 5.8% |
| default | opus47-1m | 35 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.0% | -0.0min | -0.0% | 2.0min | -1.4% |
| powershell-tool | opus47-1m | 23 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.2min | -8.4% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.1min | -11.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 30 | 23 | 76.7% | 3.1min | 5.0% | 0.4min | 0.7% | 2.6min | 4.3% | 3.2min | 82.3% |
| bash | opus47-1m | 17 | 2 | 11.8% | 0.4min | 0.6% | 0.0min | 0.0% | 0.4min | 0.6% | 6.8min | 5.8% |
| default | opus47-1m | 35 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.0% | -0.0min | -0.0% | 2.0min | -1.4% |
| powershell | opus47-1m | 17 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.1min | -11.0% |
| powershell-tool | opus47-1m | 23 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.2min | -8.4% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 1.1% | $0.24 | 1.42% |
| repeated-test-reruns | typescript-bun | opus47-1m | 1 | 4.0min | 6.5% | $1.18 | 6.91% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 1 | 4.6min | 7.4% | $1.35 | 7.95% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 1.1% | $0.24 | 1.42% |
| repeated-test-reruns | typescript-bun | opus47-1m | 1 | 4.0min | 6.5% | $1.18 | 6.91% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 1 | 4.6min | 7.4% | $1.35 | 7.95% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 1.1% | $0.24 | 1.42% |
| repeated-test-reruns | typescript-bun | opus47-1m | 1 | 4.0min | 6.5% | $1.18 | 6.91% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 1 | 4.6min | 7.4% | $1.35 | 7.95% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 1.1% | $0.24 | 1.42% |
| repeated-test-reruns | typescript-bun | opus47-1m | 1 | 4.0min | 6.5% | $1.18 | 6.91% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 1 | 4.6min | 7.4% | $1.35 | 7.95% |

</details>

#### Trap Descriptions

- **repeated-test-reruns**: Same test command executed 4+ times without the underlying code changing.
- **ts-type-error-fix-cycles**: TypeScript type errors caught by `tsc --noEmit` hooks; each requires a fix cycle.

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
| bash | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus47-1m | 2 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus47-1m | 1 | 1 | 0.7min | 1.1% | $0.24 | 1.42% |
| typescript-bun | opus47-1m | 1 | 2 | 8.6min | 13.9% | $2.53 | 14.86% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| bash | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus47-1m | 2 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus47-1m | 1 | 1 | 0.7min | 1.1% | $0.24 | 1.42% |
| typescript-bun | opus47-1m | 1 | 2 | 8.6min | 13.9% | $2.53 | 14.86% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| bash | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus47-1m | 2 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus47-1m | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus47-1m | 1 | 1 | 0.7min | 1.1% | $0.24 | 1.42% |
| typescript-bun | opus47-1m | 1 | 2 | 8.6min | 13.9% | $2.53 | 14.86% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 5 | $0.47 | 2.74% |
| Miss | 1 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | opus47-1m | 35.0 | 67.0 | 1.9 | 1.26 |
| default | opus47-1m | 28.5 | 56.5 | 2.0 | 1.86 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |
| powershell-tool | opus47-1m | 33.0 | 54.0 | 1.6 | 9.43 |
| typescript-bun | opus47-1m | 45.0 | 95.0 | 2.1 | 1.60 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m | 45.0 | 95.0 | 2.1 | 1.60 |
| bash | opus47-1m | 35.0 | 67.0 | 1.9 | 1.26 |
| powershell-tool | opus47-1m | 33.0 | 54.0 | 1.6 | 9.43 |
| default | opus47-1m | 28.5 | 56.5 | 2.0 | 1.86 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m | 45.0 | 95.0 | 2.1 | 1.60 |
| bash | opus47-1m | 35.0 | 67.0 | 1.9 | 1.26 |
| default | opus47-1m | 28.5 | 56.5 | 2.0 | 1.86 |
| powershell-tool | opus47-1m | 33.0 | 54.0 | 1.6 | 9.43 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-tool | opus47-1m | 33.0 | 54.0 | 1.6 | 9.43 |
| default | opus47-1m | 28.5 | 56.5 | 2.0 | 1.86 |
| typescript-bun | opus47-1m | 45.0 | 95.0 | 2.1 | 1.60 |
| bash | opus47-1m | 35.0 | 67.0 | 1.9 | 1.26 |
| powershell | opus47-1m | 27.0 | 46.0 | 1.7 | 1.05 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Mode | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | default | opus47-1m | 30 | 70 | 2.3 | 505 | 280 | 1.80 |
| Semantic Version Bumper | powershell | opus47-1m | 27 | 46 | 1.7 | 261 | 248 | 1.05 |
| Semantic Version Bumper | powershell-tool | opus47-1m | 33 | 54 | 1.6 | 396 | 42 | 9.43 |
| Semantic Version Bumper | bash | opus47-1m | 35 | 67 | 1.9 | 374 | 298 | 1.26 |
| Semantic Version Bumper | typescript-bun | opus47-1m | 45 | 95 | 2.1 | 805 | 504 | 1.60 |
| PR Label Assigner | default | opus47-1m | 27 | 43 | 1.6 | 431 | 224 | 1.92 |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*