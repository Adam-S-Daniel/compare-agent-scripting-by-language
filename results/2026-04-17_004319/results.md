# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-17 06:13:48 AM ET

**Status:** 24/35 runs completed, 11 remaining
**Total cost so far:** $77.19
**Total agent time so far:** 304.5 min

## Observations

- **Fastest (avg):** default/opus47-1m — 7.6min, then powershell-tool/opus47-1m — 10.5min
- **Slowest (avg):** bash/opus47-1m — 19.7min, then typescript-bun/opus47-1m — 14.3min
- **Cheapest (avg):** default/opus47-1m — $2.31, then bash/opus47-1m — $3.17
- **Most expensive (avg):** typescript-bun/opus47-1m — $4.30, then powershell-tool/opus47-1m — $3.27

- **Estimated time remaining:** 139.5min
- **Estimated total cost:** $112.57

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus47-1m | 5 | 19.7min | 19.3min | 1.8 | 55 | $3.17 | $15.87 |
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| powershell | opus47-1m | 5 | 11.7min | 10.5min | 0.2 | 51 | $3.24 | $16.22 |
| powershell-tool | opus47-1m | 5 | 10.5min | 9.8min | 0.2 | 48 | $3.27 | $16.33 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| bash | opus47-1m | 5 | 19.7min | 19.3min | 1.8 | 55 | $3.17 | $15.87 |
| powershell | opus47-1m | 5 | 11.7min | 10.5min | 0.2 | 51 | $3.24 | $16.22 |
| powershell-tool | opus47-1m | 5 | 10.5min | 9.8min | 0.2 | 48 | $3.27 | $16.33 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| powershell-tool | opus47-1m | 5 | 10.5min | 9.8min | 0.2 | 48 | $3.27 | $16.33 |
| powershell | opus47-1m | 5 | 11.7min | 10.5min | 0.2 | 51 | $3.24 | $16.22 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |
| bash | opus47-1m | 5 | 19.7min | 19.3min | 1.8 | 55 | $3.17 | $15.87 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |
| powershell-tool | opus47-1m | 5 | 10.5min | 9.8min | 0.2 | 48 | $3.27 | $16.33 |
| powershell | opus47-1m | 5 | 11.7min | 10.5min | 0.2 | 51 | $3.24 | $16.22 |
| bash | opus47-1m | 5 | 19.7min | 19.3min | 1.8 | 55 | $3.17 | $15.87 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus47-1m | 5 | 11.7min | 10.5min | 0.2 | 51 | $3.24 | $16.22 |
| powershell-tool | opus47-1m | 5 | 10.5min | 9.8min | 0.2 | 48 | $3.27 | $16.33 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| bash | opus47-1m | 5 | 19.7min | 19.3min | 1.8 | 55 | $3.17 | $15.87 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| powershell-tool | opus47-1m | 5 | 10.5min | 9.8min | 0.2 | 48 | $3.27 | $16.33 |
| powershell | opus47-1m | 5 | 11.7min | 10.5min | 0.2 | 51 | $3.24 | $16.22 |
| bash | opus47-1m | 5 | 19.7min | 19.3min | 1.8 | 55 | $3.17 | $15.87 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus47-1m | 94 | 4 | 4.3% | 0.8min | 0.3% | 0.1min | 0.0% | 0.7min | 0.2% | 28.0min | 2.6% |
| default | opus47-1m | 76 | 2 | 2.6% | 0.3min | 0.1% | 0.1min | 0.0% | 0.1min | 0.0% | 5.5min | 2.5% |
| powershell | opus47-1m | 88 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 9.4min | -6.2% |
| powershell-tool | opus47-1m | 91 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 4.0min | -13.9% |
| typescript-bun | opus47-1m | 109 | 61 | 56.0% | 8.1min | 2.7% | 4.5min | 1.5% | 3.6min | 1.2% | 9.8min | 36.5% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 109 | 61 | 56.0% | 8.1min | 2.7% | 4.5min | 1.5% | 3.6min | 1.2% | 9.8min | 36.5% |
| bash | opus47-1m | 94 | 4 | 4.3% | 0.8min | 0.3% | 0.1min | 0.0% | 0.7min | 0.2% | 28.0min | 2.6% |
| default | opus47-1m | 76 | 2 | 2.6% | 0.3min | 0.1% | 0.1min | 0.0% | 0.1min | 0.0% | 5.5min | 2.5% |
| powershell-tool | opus47-1m | 91 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 4.0min | -13.9% |
| powershell | opus47-1m | 88 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 9.4min | -6.2% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 109 | 61 | 56.0% | 8.1min | 2.7% | 4.5min | 1.5% | 3.6min | 1.2% | 9.8min | 36.5% |
| bash | opus47-1m | 94 | 4 | 4.3% | 0.8min | 0.3% | 0.1min | 0.0% | 0.7min | 0.2% | 28.0min | 2.6% |
| default | opus47-1m | 76 | 2 | 2.6% | 0.3min | 0.1% | 0.1min | 0.0% | 0.1min | 0.0% | 5.5min | 2.5% |
| powershell | opus47-1m | 88 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 9.4min | -6.2% |
| powershell-tool | opus47-1m | 91 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 4.0min | -13.9% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 109 | 61 | 56.0% | 8.1min | 2.7% | 4.5min | 1.5% | 3.6min | 1.2% | 9.8min | 36.5% |
| bash | opus47-1m | 94 | 4 | 4.3% | 0.8min | 0.3% | 0.1min | 0.0% | 0.7min | 0.2% | 28.0min | 2.6% |
| default | opus47-1m | 76 | 2 | 2.6% | 0.3min | 0.1% | 0.1min | 0.0% | 0.1min | 0.0% | 5.5min | 2.5% |
| powershell | opus47-1m | 88 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 9.4min | -6.2% |
| powershell-tool | opus47-1m | 91 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 4.0min | -13.9% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 4 | 12.2min | 4.0% | $3.65 | 4.73% |
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.5% | $0.52 | 0.67% |
| repeated-test-reruns | powershell | opus47-1m | 3 | 2.7min | 0.9% | $0.73 | 0.95% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.5% | $0.60 | 0.78% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 2.0% | $1.78 | 2.30% |
| fixture-rework | default | opus47-1m | 1 | 0.5min | 0.2% | $0.15 | 0.20% |
| fixture-rework | powershell | opus47-1m | 3 | 3.0min | 1.0% | $0.82 | 1.07% |
| fixture-rework | powershell-tool | opus47-1m | 2 | 1.8min | 0.6% | $0.60 | 0.78% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.4% | $0.38 | 0.49% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | opus47-1m | 1 | 0.5min | 0.2% | $0.15 | 0.20% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.4% | $0.38 | 0.49% |
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.5% | $0.52 | 0.67% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.5% | $0.60 | 0.78% |
| fixture-rework | powershell-tool | opus47-1m | 2 | 1.8min | 0.6% | $0.60 | 0.78% |
| repeated-test-reruns | powershell | opus47-1m | 3 | 2.7min | 0.9% | $0.73 | 0.95% |
| fixture-rework | powershell | opus47-1m | 3 | 3.0min | 1.0% | $0.82 | 1.07% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 2.0% | $1.78 | 2.30% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 4 | 12.2min | 4.0% | $3.65 | 4.73% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | opus47-1m | 1 | 0.5min | 0.2% | $0.15 | 0.20% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.4% | $0.38 | 0.49% |
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.5% | $0.52 | 0.67% |
| fixture-rework | powershell-tool | opus47-1m | 2 | 1.8min | 0.6% | $0.60 | 0.78% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.5% | $0.60 | 0.78% |
| repeated-test-reruns | powershell | opus47-1m | 3 | 2.7min | 0.9% | $0.73 | 0.95% |
| fixture-rework | powershell | opus47-1m | 3 | 3.0min | 1.0% | $0.82 | 1.07% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 2.0% | $1.78 | 2.30% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 4 | 12.2min | 4.0% | $3.65 | 4.73% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.5% | $0.52 | 0.67% |
| fixture-rework | default | opus47-1m | 1 | 0.5min | 0.2% | $0.15 | 0.20% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.5% | $0.60 | 0.78% |
| fixture-rework | powershell-tool | opus47-1m | 2 | 1.8min | 0.6% | $0.60 | 0.78% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.4% | $0.38 | 0.49% |
| repeated-test-reruns | powershell | opus47-1m | 3 | 2.7min | 0.9% | $0.73 | 0.95% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 2.0% | $1.78 | 2.30% |
| fixture-rework | powershell | opus47-1m | 3 | 3.0min | 1.0% | $0.82 | 1.07% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 4 | 12.2min | 4.0% | $3.65 | 4.73% |

</details>

#### Trap Descriptions

- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
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
| bash | opus47-1m | 5 | 1 | 1.7min | 0.5% | $0.52 | 0.67% |
| default | opus47-1m | 5 | 1 | 0.5min | 0.2% | $0.15 | 0.20% |
| powershell | opus47-1m | 5 | 6 | 5.7min | 1.9% | $1.56 | 2.02% |
| powershell-tool | opus47-1m | 5 | 4 | 3.4min | 1.1% | $1.20 | 1.56% |
| typescript-bun | opus47-1m | 4 | 9 | 19.4min | 6.4% | $5.81 | 7.53% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m | 5 | 1 | 0.5min | 0.2% | $0.15 | 0.20% |
| bash | opus47-1m | 5 | 1 | 1.7min | 0.5% | $0.52 | 0.67% |
| powershell-tool | opus47-1m | 5 | 4 | 3.4min | 1.1% | $1.20 | 1.56% |
| powershell | opus47-1m | 5 | 6 | 5.7min | 1.9% | $1.56 | 2.02% |
| typescript-bun | opus47-1m | 4 | 9 | 19.4min | 6.4% | $5.81 | 7.53% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m | 5 | 1 | 0.5min | 0.2% | $0.15 | 0.20% |
| bash | opus47-1m | 5 | 1 | 1.7min | 0.5% | $0.52 | 0.67% |
| powershell-tool | opus47-1m | 5 | 4 | 3.4min | 1.1% | $1.20 | 1.56% |
| powershell | opus47-1m | 5 | 6 | 5.7min | 1.9% | $1.56 | 2.02% |
| typescript-bun | opus47-1m | 4 | 9 | 19.4min | 6.4% | $5.81 | 7.53% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 21 | $1.99 | 2.58% |
| Miss | 3 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | opus47-1m | 28.2 | 49.8 | 1.8 | 1.48 |
| default | opus47-1m | 26.8 | 50.8 | 1.9 | 1.45 |
| powershell | opus47-1m | 30.8 | 59.8 | 1.9 | 1.05 |
| powershell-tool | opus47-1m | 32.4 | 54.4 | 1.7 | 2.70 |
| typescript-bun | opus47-1m | 34.8 | 71.0 | 2.0 | 1.51 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m | 34.8 | 71.0 | 2.0 | 1.51 |
| powershell-tool | opus47-1m | 32.4 | 54.4 | 1.7 | 2.70 |
| powershell | opus47-1m | 30.8 | 59.8 | 1.9 | 1.05 |
| bash | opus47-1m | 28.2 | 49.8 | 1.8 | 1.48 |
| default | opus47-1m | 26.8 | 50.8 | 1.9 | 1.45 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m | 34.8 | 71.0 | 2.0 | 1.51 |
| powershell | opus47-1m | 30.8 | 59.8 | 1.9 | 1.05 |
| powershell-tool | opus47-1m | 32.4 | 54.4 | 1.7 | 2.70 |
| default | opus47-1m | 26.8 | 50.8 | 1.9 | 1.45 |
| bash | opus47-1m | 28.2 | 49.8 | 1.8 | 1.48 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-tool | opus47-1m | 32.4 | 54.4 | 1.7 | 2.70 |
| typescript-bun | opus47-1m | 34.8 | 71.0 | 2.0 | 1.51 |
| bash | opus47-1m | 28.2 | 49.8 | 1.8 | 1.48 |
| default | opus47-1m | 26.8 | 50.8 | 1.9 | 1.45 |
| powershell | opus47-1m | 30.8 | 59.8 | 1.9 | 1.05 |

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
| PR Label Assigner | powershell | opus47-1m | 39 | 47 | 1.2 | 319 | 386 | 0.83 |
| PR Label Assigner | powershell-tool | opus47-1m | 31 | 62 | 2.0 | 324 | 202 | 1.60 |
| PR Label Assigner | bash | opus47-1m | 28 | 43 | 1.5 | 303 | 360 | 0.84 |
| PR Label Assigner | typescript-bun | opus47-1m | 32 | 51 | 1.6 | 620 | 263 | 2.36 |
| Dependency License Checker | default | opus47-1m | 24 | 36 | 1.5 | 284 | 578 | 0.49 |
| Dependency License Checker | powershell | opus47-1m | 22 | 79 | 3.6 | 456 | 277 | 1.65 |
| Dependency License Checker | powershell-tool | opus47-1m | 19 | 32 | 1.7 | 223 | 440 | 0.51 |
| Dependency License Checker | bash | opus47-1m | 14 | 14 | 1.0 | 152 | 171 | 0.89 |
| Dependency License Checker | typescript-bun | opus47-1m | 29 | 50 | 1.7 | 402 | 559 | 0.72 |
| Test Results Aggregator | default | opus47-1m | 30 | 70 | 2.3 | 543 | 334 | 1.63 |
| Test Results Aggregator | powershell | opus47-1m | 27 | 73 | 2.7 | 343 | 372 | 0.92 |
| Test Results Aggregator | powershell-tool | opus47-1m | 37 | 65 | 1.8 | 337 | 265 | 1.27 |
| Test Results Aggregator | bash | opus47-1m | 37 | 95 | 2.6 | 385 | 101 | 3.81 |
| Test Results Aggregator | typescript-bun | opus47-1m | 33 | 88 | 2.7 | 658 | 481 | 1.37 |
| Environment Matrix Generator | default | opus47-1m | 23 | 35 | 1.5 | 283 | 202 | 1.40 |
| Environment Matrix Generator | powershell | opus47-1m | 39 | 54 | 1.4 | 334 | 411 | 0.81 |
| Environment Matrix Generator | powershell-tool | opus47-1m | 42 | 59 | 1.4 | 294 | 437 | 0.67 |
| Environment Matrix Generator | bash | opus47-1m | 27 | 30 | 1.1 | 186 | 304 | 0.61 |

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
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Dependency License Checker | default | opus47-1m | 7.5min | 40 | 0 | $2.04 | python | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Dependency License Checker | bash | opus47-1m | 39.8min | 38 | 2 | $2.19 | bash | ok |
| Dependency License Checker | typescript-bun | opus47-1m | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| Test Results Aggregator | powershell | opus47-1m | 17.3min | 74 | 0 | $4.47 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m | 15.2min | 63 | 0 | $5.47 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m | 16.5min | 79 | 1 | $5.09 | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m | 20.8min | 103 | 1 | $6.31 | typescript | ok |
| Environment Matrix Generator | default | opus47-1m | 6.8min | 34 | 2 | $2.01 | python | ok |
| Environment Matrix Generator | powershell | opus47-1m | 13.5min | 54 | 0 | $3.93 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m | 8.3min | 51 | 2 | $2.49 | bash | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Environment Matrix Generator | default | opus47-1m | 6.8min | 34 | 2 | $2.01 | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| Dependency License Checker | default | opus47-1m | 7.5min | 40 | 0 | $2.04 | python | ok |
| Dependency License Checker | bash | opus47-1m | 39.8min | 38 | 2 | $2.19 | bash | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Environment Matrix Generator | bash | opus47-1m | 8.3min | 51 | 2 | $2.49 | bash | ok |
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Dependency License Checker | typescript-bun | opus47-1m | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Environment Matrix Generator | powershell | opus47-1m | 13.5min | 54 | 0 | $3.93 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Test Results Aggregator | powershell | opus47-1m | 17.3min | 74 | 0 | $4.47 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m | 16.5min | 79 | 1 | $5.09 | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m | 15.2min | 63 | 0 | $5.47 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m | 20.8min | 103 | 1 | $6.31 | typescript | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Environment Matrix Generator | default | opus47-1m | 6.8min | 34 | 2 | $2.01 | python | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Dependency License Checker | default | opus47-1m | 7.5min | 40 | 0 | $2.04 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m | 8.3min | 51 | 2 | $2.49 | bash | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Environment Matrix Generator | powershell | opus47-1m | 13.5min | 54 | 0 | $3.93 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Test Results Aggregator | powershell-tool | opus47-1m | 15.2min | 63 | 0 | $5.47 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m | 16.5min | 79 | 1 | $5.09 | bash | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Test Results Aggregator | powershell | opus47-1m | 17.3min | 74 | 0 | $4.47 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m | 20.8min | 103 | 1 | $6.31 | typescript | ok |
| Dependency License Checker | bash | opus47-1m | 39.8min | 38 | 2 | $2.19 | bash | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Dependency License Checker | default | opus47-1m | 7.5min | 40 | 0 | $2.04 | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Test Results Aggregator | powershell | opus47-1m | 17.3min | 74 | 0 | $4.47 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m | 15.2min | 63 | 0 | $5.47 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m | 13.5min | 54 | 0 | $3.93 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| Test Results Aggregator | bash | opus47-1m | 16.5min | 79 | 1 | $5.09 | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m | 20.8min | 103 | 1 | $6.31 | typescript | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Dependency License Checker | bash | opus47-1m | 39.8min | 38 | 2 | $2.19 | bash | ok |
| Environment Matrix Generator | default | opus47-1m | 6.8min | 34 | 2 | $2.01 | python | ok |
| Environment Matrix Generator | bash | opus47-1m | 8.3min | 51 | 2 | $2.49 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Environment Matrix Generator | default | opus47-1m | 6.8min | 34 | 2 | $2.01 | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Dependency License Checker | bash | opus47-1m | 39.8min | 38 | 2 | $2.19 | bash | ok |
| Dependency License Checker | default | opus47-1m | 7.5min | 40 | 0 | $2.04 | python | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m | 8.3min | 51 | 2 | $2.49 | bash | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| Environment Matrix Generator | powershell | opus47-1m | 13.5min | 54 | 0 | $3.93 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m | 15.2min | 63 | 0 | $5.47 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Test Results Aggregator | powershell | opus47-1m | 17.3min | 74 | 0 | $4.47 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m | 16.5min | 79 | 1 | $5.09 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m | 20.8min | 103 | 1 | $6.31 | typescript | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*