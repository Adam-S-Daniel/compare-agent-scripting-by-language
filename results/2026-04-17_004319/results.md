# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-17 07:01:06 AM ET

**Status:** 29/35 runs completed, 6 remaining
**Total cost so far:** $89.94
**Total agent time so far:** 351.8 min

## Observations

- **Fastest (avg):** default/opus47-1m — 7.5min, then powershell-tool/opus47-1m — 10.7min
- **Slowest (avg):** bash/opus47-1m — 17.7min, then typescript-bun/opus47-1m — 13.4min
- **Cheapest (avg):** default/opus47-1m — $2.24, then bash/opus47-1m — $2.95
- **Most expensive (avg):** typescript-bun/opus47-1m — $3.96, then powershell-tool/opus47-1m — $3.26

- **Estimated time remaining:** 72.8min
- **Estimated total cost:** $108.55

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus47-1m | 6 | 17.7min | 17.4min | 1.7 | 52 | $2.95 | $17.71 |
| default | opus47-1m | 6 | 7.5min | 7.3min | 0.7 | 42 | $2.24 | $13.46 |
| powershell | opus47-1m | 6 | 11.5min | 10.5min | 0.2 | 50 | $3.23 | $19.41 |
| powershell-tool | opus47-1m | 6 | 10.7min | 9.8min | 0.3 | 48 | $3.26 | $19.55 |
| typescript-bun | opus47-1m | 5 | 13.4min | 9.4min | 0.4 | 73 | $3.96 | $19.81 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 6 | 7.5min | 7.3min | 0.7 | 42 | $2.24 | $13.46 |
| bash | opus47-1m | 6 | 17.7min | 17.4min | 1.7 | 52 | $2.95 | $17.71 |
| powershell | opus47-1m | 6 | 11.5min | 10.5min | 0.2 | 50 | $3.23 | $19.41 |
| powershell-tool | opus47-1m | 6 | 10.7min | 9.8min | 0.3 | 48 | $3.26 | $19.55 |
| typescript-bun | opus47-1m | 5 | 13.4min | 9.4min | 0.4 | 73 | $3.96 | $19.81 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 6 | 7.5min | 7.3min | 0.7 | 42 | $2.24 | $13.46 |
| powershell-tool | opus47-1m | 6 | 10.7min | 9.8min | 0.3 | 48 | $3.26 | $19.55 |
| powershell | opus47-1m | 6 | 11.5min | 10.5min | 0.2 | 50 | $3.23 | $19.41 |
| typescript-bun | opus47-1m | 5 | 13.4min | 9.4min | 0.4 | 73 | $3.96 | $19.81 |
| bash | opus47-1m | 6 | 17.7min | 17.4min | 1.7 | 52 | $2.95 | $17.71 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 6 | 7.5min | 7.3min | 0.7 | 42 | $2.24 | $13.46 |
| typescript-bun | opus47-1m | 5 | 13.4min | 9.4min | 0.4 | 73 | $3.96 | $19.81 |
| powershell-tool | opus47-1m | 6 | 10.7min | 9.8min | 0.3 | 48 | $3.26 | $19.55 |
| powershell | opus47-1m | 6 | 11.5min | 10.5min | 0.2 | 50 | $3.23 | $19.41 |
| bash | opus47-1m | 6 | 17.7min | 17.4min | 1.7 | 52 | $2.95 | $17.71 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus47-1m | 6 | 11.5min | 10.5min | 0.2 | 50 | $3.23 | $19.41 |
| powershell-tool | opus47-1m | 6 | 10.7min | 9.8min | 0.3 | 48 | $3.26 | $19.55 |
| typescript-bun | opus47-1m | 5 | 13.4min | 9.4min | 0.4 | 73 | $3.96 | $19.81 |
| default | opus47-1m | 6 | 7.5min | 7.3min | 0.7 | 42 | $2.24 | $13.46 |
| bash | opus47-1m | 6 | 17.7min | 17.4min | 1.7 | 52 | $2.95 | $17.71 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 6 | 7.5min | 7.3min | 0.7 | 42 | $2.24 | $13.46 |
| powershell-tool | opus47-1m | 6 | 10.7min | 9.8min | 0.3 | 48 | $3.26 | $19.55 |
| powershell | opus47-1m | 6 | 11.5min | 10.5min | 0.2 | 50 | $3.23 | $19.41 |
| bash | opus47-1m | 6 | 17.7min | 17.4min | 1.7 | 52 | $2.95 | $17.71 |
| typescript-bun | opus47-1m | 5 | 13.4min | 9.4min | 0.4 | 73 | $3.96 | $19.81 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus47-1m | 104 | 4 | 3.8% | 0.8min | 0.2% | 0.1min | 0.0% | 0.7min | 0.2% | 28.1min | 2.5% |
| default | opus47-1m | 90 | 3 | 3.3% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.1% | 6.5min | 3.6% |
| powershell | opus47-1m | 105 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.2% | -0.7min | -0.2% | 10.9min | -6.6% |
| powershell-tool | opus47-1m | 112 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.2% | -0.7min | -0.2% | 5.4min | -12.4% |
| typescript-bun | opus47-1m | 123 | 66 | 53.7% | 8.8min | 2.5% | 4.6min | 1.3% | 4.2min | 1.2% | 12.0min | 35.0% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 123 | 66 | 53.7% | 8.8min | 2.5% | 4.6min | 1.3% | 4.2min | 1.2% | 12.0min | 35.0% |
| bash | opus47-1m | 104 | 4 | 3.8% | 0.8min | 0.2% | 0.1min | 0.0% | 0.7min | 0.2% | 28.1min | 2.5% |
| default | opus47-1m | 90 | 3 | 3.3% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.1% | 6.5min | 3.6% |
| powershell-tool | opus47-1m | 112 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.2% | -0.7min | -0.2% | 5.4min | -12.4% |
| powershell | opus47-1m | 105 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.2% | -0.7min | -0.2% | 10.9min | -6.6% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 123 | 66 | 53.7% | 8.8min | 2.5% | 4.6min | 1.3% | 4.2min | 1.2% | 12.0min | 35.0% |
| default | opus47-1m | 90 | 3 | 3.3% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.1% | 6.5min | 3.6% |
| bash | opus47-1m | 104 | 4 | 3.8% | 0.8min | 0.2% | 0.1min | 0.0% | 0.7min | 0.2% | 28.1min | 2.5% |
| powershell | opus47-1m | 105 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.2% | -0.7min | -0.2% | 10.9min | -6.6% |
| powershell-tool | opus47-1m | 112 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.2% | -0.7min | -0.2% | 5.4min | -12.4% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 123 | 66 | 53.7% | 8.8min | 2.5% | 4.6min | 1.3% | 4.2min | 1.2% | 12.0min | 35.0% |
| bash | opus47-1m | 104 | 4 | 3.8% | 0.8min | 0.2% | 0.1min | 0.0% | 0.7min | 0.2% | 28.1min | 2.5% |
| default | opus47-1m | 90 | 3 | 3.3% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.1% | 6.5min | 3.6% |
| powershell | opus47-1m | 105 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.2% | -0.7min | -0.2% | 10.9min | -6.6% |
| powershell-tool | opus47-1m | 112 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.2% | -0.7min | -0.2% | 5.4min | -12.4% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.5% | $0.52 | 0.57% |
| repeated-test-reruns | default | opus47-1m | 1 | 0.7min | 0.2% | $0.18 | 0.20% |
| repeated-test-reruns | powershell | opus47-1m | 4 | 3.3min | 0.9% | $0.93 | 1.03% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.5% | $0.60 | 0.67% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 1.7% | $1.78 | 1.98% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 5 | 13.2min | 3.8% | $3.92 | 4.35% |
| fixture-rework | default | opus47-1m | 2 | 1.0min | 0.3% | $0.29 | 0.32% |
| fixture-rework | powershell | opus47-1m | 3 | 3.0min | 0.9% | $0.82 | 0.92% |
| fixture-rework | powershell-tool | opus47-1m | 2 | 1.8min | 0.5% | $0.60 | 0.67% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.4% | $0.38 | 0.42% |
| mid-run-module-restructure | powershell-tool | opus47-1m | 1 | 2.0min | 0.6% | $0.54 | 0.60% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus47-1m | 1 | 0.7min | 0.2% | $0.18 | 0.20% |
| fixture-rework | default | opus47-1m | 2 | 1.0min | 0.3% | $0.29 | 0.32% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.4% | $0.38 | 0.42% |
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.5% | $0.52 | 0.57% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.5% | $0.60 | 0.67% |
| fixture-rework | powershell-tool | opus47-1m | 2 | 1.8min | 0.5% | $0.60 | 0.67% |
| mid-run-module-restructure | powershell-tool | opus47-1m | 1 | 2.0min | 0.6% | $0.54 | 0.60% |
| fixture-rework | powershell | opus47-1m | 3 | 3.0min | 0.9% | $0.82 | 0.92% |
| repeated-test-reruns | powershell | opus47-1m | 4 | 3.3min | 0.9% | $0.93 | 1.03% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 1.7% | $1.78 | 1.98% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 5 | 13.2min | 3.8% | $3.92 | 4.35% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus47-1m | 1 | 0.7min | 0.2% | $0.18 | 0.20% |
| fixture-rework | default | opus47-1m | 2 | 1.0min | 0.3% | $0.29 | 0.32% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.4% | $0.38 | 0.42% |
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.5% | $0.52 | 0.57% |
| mid-run-module-restructure | powershell-tool | opus47-1m | 1 | 2.0min | 0.6% | $0.54 | 0.60% |
| fixture-rework | powershell-tool | opus47-1m | 2 | 1.8min | 0.5% | $0.60 | 0.67% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.5% | $0.60 | 0.67% |
| fixture-rework | powershell | opus47-1m | 3 | 3.0min | 0.9% | $0.82 | 0.92% |
| repeated-test-reruns | powershell | opus47-1m | 4 | 3.3min | 0.9% | $0.93 | 1.03% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 1.7% | $1.78 | 1.98% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 5 | 13.2min | 3.8% | $3.92 | 4.35% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | bash | opus47-1m | 1 | 1.7min | 0.5% | $0.52 | 0.57% |
| repeated-test-reruns | default | opus47-1m | 1 | 0.7min | 0.2% | $0.18 | 0.20% |
| mid-run-module-restructure | powershell-tool | opus47-1m | 1 | 2.0min | 0.6% | $0.54 | 0.60% |
| repeated-test-reruns | powershell-tool | opus47-1m | 2 | 1.7min | 0.5% | $0.60 | 0.67% |
| fixture-rework | default | opus47-1m | 2 | 1.0min | 0.3% | $0.29 | 0.32% |
| fixture-rework | powershell-tool | opus47-1m | 2 | 1.8min | 0.5% | $0.60 | 0.67% |
| fixture-rework | typescript-bun | opus47-1m | 2 | 1.2min | 0.4% | $0.38 | 0.42% |
| repeated-test-reruns | typescript-bun | opus47-1m | 3 | 6.0min | 1.7% | $1.78 | 1.98% |
| fixture-rework | powershell | opus47-1m | 3 | 3.0min | 0.9% | $0.82 | 0.92% |
| repeated-test-reruns | powershell | opus47-1m | 4 | 3.3min | 0.9% | $0.93 | 1.03% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 5 | 13.2min | 3.8% | $3.92 | 4.35% |

</details>

#### Trap Descriptions

- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
- **mid-run-module-restructure**: Agent restructured from a flat .ps1 script to a .psm1 module mid-run.
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
| bash | opus47-1m | 6 | 1 | 1.7min | 0.5% | $0.52 | 0.57% |
| default | opus47-1m | 6 | 3 | 1.7min | 0.5% | $0.47 | 0.52% |
| powershell | opus47-1m | 6 | 7 | 6.3min | 1.8% | $1.75 | 1.95% |
| powershell-tool | opus47-1m | 6 | 5 | 5.4min | 1.5% | $1.74 | 1.93% |
| typescript-bun | opus47-1m | 5 | 10 | 20.4min | 5.8% | $6.08 | 6.75% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| bash | opus47-1m | 6 | 1 | 1.7min | 0.5% | $0.52 | 0.57% |
| default | opus47-1m | 6 | 3 | 1.7min | 0.5% | $0.47 | 0.52% |
| powershell-tool | opus47-1m | 6 | 5 | 5.4min | 1.5% | $1.74 | 1.93% |
| powershell | opus47-1m | 6 | 7 | 6.3min | 1.8% | $1.75 | 1.95% |
| typescript-bun | opus47-1m | 5 | 10 | 20.4min | 5.8% | $6.08 | 6.75% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m | 6 | 3 | 1.7min | 0.5% | $0.47 | 0.52% |
| bash | opus47-1m | 6 | 1 | 1.7min | 0.5% | $0.52 | 0.57% |
| powershell-tool | opus47-1m | 6 | 5 | 5.4min | 1.5% | $1.74 | 1.93% |
| powershell | opus47-1m | 6 | 7 | 6.3min | 1.8% | $1.75 | 1.95% |
| typescript-bun | opus47-1m | 5 | 10 | 20.4min | 5.8% | $6.08 | 6.75% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 26 | $2.47 | 2.75% |
| Miss | 3 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | opus47-1m | 26.0 | 52.0 | 2.0 | 1.31 |
| default | opus47-1m | 25.3 | 48.8 | 1.9 | 1.48 |
| powershell | opus47-1m | 28.8 | 57.2 | 2.0 | 0.99 |
| powershell-tool | opus47-1m | 29.8 | 51.2 | 1.7 | 2.34 |
| typescript-bun | opus47-1m | 34.0 | 68.6 | 2.0 | 1.62 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m | 34.0 | 68.6 | 2.0 | 1.62 |
| powershell-tool | opus47-1m | 29.8 | 51.2 | 1.7 | 2.34 |
| powershell | opus47-1m | 28.8 | 57.2 | 2.0 | 0.99 |
| bash | opus47-1m | 26.0 | 52.0 | 2.0 | 1.31 |
| default | opus47-1m | 25.3 | 48.8 | 1.9 | 1.48 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m | 34.0 | 68.6 | 2.0 | 1.62 |
| powershell | opus47-1m | 28.8 | 57.2 | 2.0 | 0.99 |
| bash | opus47-1m | 26.0 | 52.0 | 2.0 | 1.31 |
| powershell-tool | opus47-1m | 29.8 | 51.2 | 1.7 | 2.34 |
| default | opus47-1m | 25.3 | 48.8 | 1.9 | 1.48 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-tool | opus47-1m | 29.8 | 51.2 | 1.7 | 2.34 |
| typescript-bun | opus47-1m | 34.0 | 68.6 | 2.0 | 1.62 |
| default | opus47-1m | 25.3 | 48.8 | 1.9 | 1.48 |
| bash | opus47-1m | 26.0 | 52.0 | 2.0 | 1.31 |
| powershell | opus47-1m | 28.8 | 57.2 | 2.0 | 0.99 |

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
| Environment Matrix Generator | typescript-bun | opus47-1m | 31 | 59 | 1.9 | 622 | 305 | 2.04 |
| Artifact Cleanup Script | default | opus47-1m | 18 | 39 | 2.2 | 525 | 321 | 1.64 |
| Artifact Cleanup Script | powershell | opus47-1m | 19 | 44 | 2.3 | 267 | 374 | 0.71 |
| Artifact Cleanup Script | powershell-tool | opus47-1m | 17 | 35 | 2.1 | 205 | 373 | 0.55 |
| Artifact Cleanup Script | bash | opus47-1m | 15 | 63 | 4.2 | 183 | 398 | 0.46 |

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
| Environment Matrix Generator | typescript-bun | opus47-1m | 9.8min | 52 | 0 | $2.60 | typescript | ok |
| Artifact Cleanup Script | default | opus47-1m | 7.1min | 35 | 1 | $1.91 | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m | 10.9min | 43 | 0 | $3.19 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m | 12.0min | 51 | 1 | $3.21 | powershell | ok |
| Artifact Cleanup Script | bash | opus47-1m | 7.6min | 34 | 1 | $1.84 | bash | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Artifact Cleanup Script | bash | opus47-1m | 7.6min | 34 | 1 | $1.84 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m | 7.1min | 35 | 1 | $1.91 | python | ok |
| Environment Matrix Generator | default | opus47-1m | 6.8min | 34 | 2 | $2.01 | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| Dependency License Checker | default | opus47-1m | 7.5min | 40 | 0 | $2.04 | python | ok |
| Dependency License Checker | bash | opus47-1m | 39.8min | 38 | 2 | $2.19 | bash | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Environment Matrix Generator | bash | opus47-1m | 8.3min | 51 | 2 | $2.49 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m | 9.8min | 52 | 0 | $2.60 | typescript | ok |
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Artifact Cleanup Script | powershell | opus47-1m | 10.9min | 43 | 0 | $3.19 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m | 12.0min | 51 | 1 | $3.21 | powershell | ok |
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
| Artifact Cleanup Script | default | opus47-1m | 7.1min | 35 | 1 | $1.91 | python | ok |
| Dependency License Checker | default | opus47-1m | 7.5min | 40 | 0 | $2.04 | python | ok |
| Artifact Cleanup Script | bash | opus47-1m | 7.6min | 34 | 1 | $1.84 | bash | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m | 8.3min | 51 | 2 | $2.49 | bash | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m | 9.8min | 52 | 0 | $2.60 | typescript | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Artifact Cleanup Script | powershell | opus47-1m | 10.9min | 43 | 0 | $3.19 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m | 12.0min | 51 | 1 | $3.21 | powershell | ok |
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
| Environment Matrix Generator | typescript-bun | opus47-1m | 9.8min | 52 | 0 | $2.60 | typescript | ok |
| Artifact Cleanup Script | powershell | opus47-1m | 10.9min | 43 | 0 | $3.19 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Test Results Aggregator | default | opus47-1m | 9.2min | 54 | 1 | $2.81 | python | ok |
| Test Results Aggregator | bash | opus47-1m | 16.5min | 79 | 1 | $5.09 | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m | 20.8min | 103 | 1 | $6.31 | typescript | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Artifact Cleanup Script | default | opus47-1m | 7.1min | 35 | 1 | $1.91 | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m | 12.0min | 51 | 1 | $3.21 | powershell | ok |
| Artifact Cleanup Script | bash | opus47-1m | 7.6min | 34 | 1 | $1.84 | bash | ok |
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
| Artifact Cleanup Script | bash | opus47-1m | 7.6min | 34 | 1 | $1.84 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m | 7.1min | 35 | 1 | $1.91 | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Dependency License Checker | bash | opus47-1m | 39.8min | 38 | 2 | $2.19 | bash | ok |
| Dependency License Checker | default | opus47-1m | 7.5min | 40 | 0 | $2.04 | python | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m | 10.9min | 43 | 0 | $3.19 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m | 8.3min | 51 | 2 | $2.49 | bash | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m | 12.0min | 51 | 1 | $3.21 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m | 9.8min | 52 | 0 | $2.60 | typescript | ok |
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