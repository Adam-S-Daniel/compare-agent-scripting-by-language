# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-17 05:47:32 AM ET

**Status:** 21/35 runs completed, 14 remaining
**Total cost so far:** $67.69
**Total agent time so far:** 272.6 min

## Observations

- **Fastest (avg):** default/opus47-1m — 7.6min, then powershell-tool/opus47-1m — 10.5min
- **Slowest (avg):** bash/opus47-1m — 22.5min, then typescript-bun/opus47-1m — 14.3min
- **Cheapest (avg):** default/opus47-1m — $2.31, then powershell/opus47-1m — $3.07
- **Most expensive (avg):** typescript-bun/opus47-1m — $4.30, then bash/opus47-1m — $3.34

- **Estimated time remaining:** 181.7min
- **Estimated total cost:** $112.81

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus47-1m | 4 | 22.5min | 22.1min | 1.8 | 56 | $3.34 | $13.38 |
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| powershell | opus47-1m | 4 | 11.2min | 10.1min | 0.2 | 51 | $3.07 | $12.29 |
| powershell-tool | opus47-1m | 4 | 10.5min | 9.8min | 0.0 | 49 | $3.31 | $13.25 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| powershell | opus47-1m | 4 | 11.2min | 10.1min | 0.2 | 51 | $3.07 | $12.29 |
| powershell-tool | opus47-1m | 4 | 10.5min | 9.8min | 0.0 | 49 | $3.31 | $13.25 |
| bash | opus47-1m | 4 | 22.5min | 22.1min | 1.8 | 56 | $3.34 | $13.38 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| powershell-tool | opus47-1m | 4 | 10.5min | 9.8min | 0.0 | 49 | $3.31 | $13.25 |
| powershell | opus47-1m | 4 | 11.2min | 10.1min | 0.2 | 51 | $3.07 | $12.29 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |
| bash | opus47-1m | 4 | 22.5min | 22.1min | 1.8 | 56 | $3.34 | $13.38 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |
| powershell-tool | opus47-1m | 4 | 10.5min | 9.8min | 0.0 | 49 | $3.31 | $13.25 |
| powershell | opus47-1m | 4 | 11.2min | 10.1min | 0.2 | 51 | $3.07 | $12.29 |
| bash | opus47-1m | 4 | 22.5min | 22.1min | 1.8 | 56 | $3.34 | $13.38 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell-tool | opus47-1m | 4 | 10.5min | 9.8min | 0.0 | 49 | $3.31 | $13.25 |
| powershell | opus47-1m | 4 | 11.2min | 10.1min | 0.2 | 51 | $3.07 | $12.29 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| bash | opus47-1m | 4 | 22.5min | 22.1min | 1.8 | 56 | $3.34 | $13.38 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 5 | 7.6min | 7.5min | 0.6 | 43 | $2.31 | $11.56 |
| powershell-tool | opus47-1m | 4 | 10.5min | 9.8min | 0.0 | 49 | $3.31 | $13.25 |
| powershell | opus47-1m | 4 | 11.2min | 10.1min | 0.2 | 51 | $3.07 | $12.29 |
| bash | opus47-1m | 4 | 22.5min | 22.1min | 1.8 | 56 | $3.34 | $13.38 |
| typescript-bun | opus47-1m | 4 | 14.3min | 9.5min | 0.5 | 78 | $4.30 | $17.21 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus47-1m | 75 | 3 | 4.0% | 0.6min | 0.2% | 0.1min | 0.0% | 0.5min | 0.2% | 27.9min | 1.9% |
| default | opus47-1m | 76 | 2 | 2.6% | 0.3min | 0.1% | 0.1min | 0.0% | 0.1min | 0.1% | 5.5min | 2.5% |
| powershell | opus47-1m | 70 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.2% | -0.5min | -0.2% | 8.8min | -5.4% |
| powershell-tool | opus47-1m | 73 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.2% | -0.4min | -0.2% | 3.0min | -14.1% |
| typescript-bun | opus47-1m | 109 | 61 | 56.0% | 8.1min | 3.0% | 4.5min | 1.7% | 3.6min | 1.3% | 9.8min | 36.5% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 109 | 61 | 56.0% | 8.1min | 3.0% | 4.5min | 1.7% | 3.6min | 1.3% | 9.8min | 36.5% |
| bash | opus47-1m | 75 | 3 | 4.0% | 0.6min | 0.2% | 0.1min | 0.0% | 0.5min | 0.2% | 27.9min | 1.9% |
| default | opus47-1m | 76 | 2 | 2.6% | 0.3min | 0.1% | 0.1min | 0.0% | 0.1min | 0.1% | 5.5min | 2.5% |
| powershell-tool | opus47-1m | 73 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.2% | -0.4min | -0.2% | 3.0min | -14.1% |
| powershell | opus47-1m | 70 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.2% | -0.5min | -0.2% | 8.8min | -5.4% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 109 | 61 | 56.0% | 8.1min | 3.0% | 4.5min | 1.7% | 3.6min | 1.3% | 9.8min | 36.5% |
| default | opus47-1m | 76 | 2 | 2.6% | 0.3min | 0.1% | 0.1min | 0.0% | 0.1min | 0.1% | 5.5min | 2.5% |
| bash | opus47-1m | 75 | 3 | 4.0% | 0.6min | 0.2% | 0.1min | 0.0% | 0.5min | 0.2% | 27.9min | 1.9% |
| powershell | opus47-1m | 70 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.2% | -0.5min | -0.2% | 8.8min | -5.4% |
| powershell-tool | opus47-1m | 73 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.2% | -0.4min | -0.2% | 3.0min | -14.1% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 109 | 61 | 56.0% | 8.1min | 3.0% | 4.5min | 1.7% | 3.6min | 1.3% | 9.8min | 36.5% |
| bash | opus47-1m | 75 | 3 | 4.0% | 0.6min | 0.2% | 0.1min | 0.0% | 0.5min | 0.2% | 27.9min | 1.9% |
| default | opus47-1m | 76 | 2 | 2.6% | 0.3min | 0.1% | 0.1min | 0.0% | 0.1min | 0.1% | 5.5min | 2.5% |
| powershell | opus47-1m | 70 | 0 | 0.0% | 0.0min | 0.0% | 0.5min | 0.2% | -0.5min | -0.2% | 8.8min | -5.4% |
| powershell-tool | opus47-1m | 73 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.2% | -0.4min | -0.2% | 3.0min | -14.1% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 4 | 12.2min | 4.5% | $3.65 | 5.39% |
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.6% | $0.52 | 0.76% |
| repeated-test-reruns | powershell | opus47-1m | 2 | 2.0min | 0.7% | $0.54 | 0.79% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.6% | $0.60 | 0.89% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 2.2% | $1.78 | 2.63% |
| fixture-rework | default | opus47-1m | 1 | 0.5min | 0.2% | $0.15 | 0.23% |
| fixture-rework | powershell | opus47-1m | 2 | 2.2min | 0.8% | $0.60 | 0.89% |
| fixture-rework | powershell-tool | opus47-1m | 1 | 1.2min | 0.5% | $0.45 | 0.67% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.5% | $0.38 | 0.56% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | opus47-1m | 1 | 0.5min | 0.2% | $0.15 | 0.23% |
| fixture-rework | powershell-tool | opus47-1m | 1 | 1.2min | 0.5% | $0.45 | 0.67% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.5% | $0.38 | 0.56% |
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.6% | $0.52 | 0.76% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.6% | $0.60 | 0.89% |
| repeated-test-reruns | powershell | opus47-1m | 2 | 2.0min | 0.7% | $0.54 | 0.79% |
| fixture-rework | powershell | opus47-1m | 2 | 2.2min | 0.8% | $0.60 | 0.89% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 2.2% | $1.78 | 2.63% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 4 | 12.2min | 4.5% | $3.65 | 5.39% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | opus47-1m | 1 | 0.5min | 0.2% | $0.15 | 0.23% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.5% | $0.38 | 0.56% |
| fixture-rework | powershell-tool | opus47-1m | 1 | 1.2min | 0.5% | $0.45 | 0.67% |
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.6% | $0.52 | 0.76% |
| repeated-test-reruns | powershell | opus47-1m | 2 | 2.0min | 0.7% | $0.54 | 0.79% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.6% | $0.60 | 0.89% |
| fixture-rework | powershell | opus47-1m | 2 | 2.2min | 0.8% | $0.60 | 0.89% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 2.2% | $1.78 | 2.63% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 4 | 12.2min | 4.5% | $3.65 | 5.39% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.6% | $0.52 | 0.76% |
| fixture-rework | default | opus47-1m | 1 | 0.5min | 0.2% | $0.15 | 0.23% |
| fixture-rework | powershell-tool | opus47-1m | 1 | 1.2min | 0.5% | $0.45 | 0.67% |
| repeated-test-reruns | powershell | opus47-1m | 2 | 2.0min | 0.7% | $0.54 | 0.79% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.6% | $0.60 | 0.89% |
| fixture-rework | powershell | opus47-1m | 2 | 2.2min | 0.8% | $0.60 | 0.89% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.5% | $0.38 | 0.56% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 2.2% | $1.78 | 2.63% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 4 | 12.2min | 4.5% | $3.65 | 5.39% |

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
| bash | opus47-1m | 4 | 1 | 1.7min | 0.6% | $0.52 | 0.76% |
| default | opus47-1m | 5 | 1 | 0.5min | 0.2% | $0.15 | 0.23% |
| powershell | opus47-1m | 4 | 4 | 4.2min | 1.6% | $1.14 | 1.69% |
| powershell-tool | opus47-1m | 4 | 3 | 2.9min | 1.1% | $1.05 | 1.56% |
| typescript-bun | opus47-1m | 4 | 9 | 19.4min | 7.1% | $5.81 | 8.58% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m | 5 | 1 | 0.5min | 0.2% | $0.15 | 0.23% |
| bash | opus47-1m | 4 | 1 | 1.7min | 0.6% | $0.52 | 0.76% |
| powershell-tool | opus47-1m | 4 | 3 | 2.9min | 1.1% | $1.05 | 1.56% |
| powershell | opus47-1m | 4 | 4 | 4.2min | 1.6% | $1.14 | 1.69% |
| typescript-bun | opus47-1m | 4 | 9 | 19.4min | 7.1% | $5.81 | 8.58% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m | 5 | 1 | 0.5min | 0.2% | $0.15 | 0.23% |
| bash | opus47-1m | 4 | 1 | 1.7min | 0.6% | $0.52 | 0.76% |
| powershell-tool | opus47-1m | 4 | 3 | 2.9min | 1.1% | $1.05 | 1.56% |
| powershell | opus47-1m | 4 | 4 | 4.2min | 1.6% | $1.14 | 1.69% |
| typescript-bun | opus47-1m | 4 | 9 | 19.4min | 7.1% | $5.81 | 8.58% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 19 | $1.81 | 2.67% |
| Miss | 2 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | opus47-1m | 28.5 | 54.8 | 1.9 | 1.70 |
| default | opus47-1m | 26.8 | 50.8 | 1.9 | 1.45 |
| powershell | opus47-1m | 28.8 | 61.2 | 2.1 | 1.11 |
| powershell-tool | opus47-1m | 30.0 | 53.2 | 1.8 | 3.20 |
| typescript-bun | opus47-1m | 34.8 | 71.0 | 2.0 | 1.51 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m | 34.8 | 71.0 | 2.0 | 1.51 |
| powershell-tool | opus47-1m | 30.0 | 53.2 | 1.8 | 3.20 |
| powershell | opus47-1m | 28.8 | 61.2 | 2.1 | 1.11 |
| bash | opus47-1m | 28.5 | 54.8 | 1.9 | 1.70 |
| default | opus47-1m | 26.8 | 50.8 | 1.9 | 1.45 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m | 34.8 | 71.0 | 2.0 | 1.51 |
| powershell | opus47-1m | 28.8 | 61.2 | 2.1 | 1.11 |
| bash | opus47-1m | 28.5 | 54.8 | 1.9 | 1.70 |
| powershell-tool | opus47-1m | 30.0 | 53.2 | 1.8 | 3.20 |
| default | opus47-1m | 26.8 | 50.8 | 1.9 | 1.45 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-tool | opus47-1m | 30.0 | 53.2 | 1.8 | 3.20 |
| bash | opus47-1m | 28.5 | 54.8 | 1.9 | 1.70 |
| typescript-bun | opus47-1m | 34.8 | 71.0 | 2.0 | 1.51 |
| default | opus47-1m | 26.8 | 50.8 | 1.9 | 1.45 |
| powershell | opus47-1m | 28.8 | 61.2 | 2.1 | 1.11 |

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
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Dependency License Checker | typescript-bun | opus47-1m | 11.8min | 74 | 0 | $3.64 | typescript | ok |
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
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m | 11.8min | 74 | 0 | $3.64 | typescript | ok |
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
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| Test Results Aggregator | bash | opus47-1m | 16.5min | 79 | 1 | $5.09 | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m | 20.8min | 103 | 1 | $6.31 | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Dependency License Checker | bash | opus47-1m | 39.8min | 38 | 2 | $2.19 | bash | ok |
| Environment Matrix Generator | default | opus47-1m | 6.8min | 34 | 2 | $2.01 | python | ok |

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
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
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