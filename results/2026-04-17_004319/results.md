# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-17 04:08:23 AM ET

**Status:** 14/35 runs completed, 21 remaining
**Total cost so far:** $37.89
**Total agent time so far:** 175.0 min

## Observations

- **Fastest (avg):** default/opus47-1m — 7.4min, then powershell-tool/opus47-1m — 9.0min
- **Slowest (avg):** bash/opus47-1m — 24.6min, then typescript-bun/opus47-1m — 12.4min
- **Cheapest (avg):** default/opus47-1m — $2.25, then powershell-tool/opus47-1m — $2.59
- **Most expensive (avg):** typescript-bun/opus47-1m — $3.63, then bash/opus47-1m — $2.76

- **Estimated time remaining:** 262.5min
- **Estimated total cost:** $94.72

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus47-1m | 3 | 24.6min | 24.6min | 2.0 | 49 | $2.76 | $8.28 |
| default | opus47-1m | 3 | 7.4min | 7.4min | 0.0 | 43 | $2.25 | $6.74 |
| powershell | opus47-1m | 3 | 9.2min | 8.7min | 0.3 | 43 | $2.61 | $7.82 |
| powershell-tool | opus47-1m | 3 | 9.0min | 8.7min | 0.0 | 45 | $2.59 | $7.78 |
| typescript-bun | opus47-1m | 2 | 12.4min | 6.7min | 0.5 | 68 | $3.63 | $7.26 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 3 | 7.4min | 7.4min | 0.0 | 43 | $2.25 | $6.74 |
| powershell-tool | opus47-1m | 3 | 9.0min | 8.7min | 0.0 | 45 | $2.59 | $7.78 |
| powershell | opus47-1m | 3 | 9.2min | 8.7min | 0.3 | 43 | $2.61 | $7.82 |
| bash | opus47-1m | 3 | 24.6min | 24.6min | 2.0 | 49 | $2.76 | $8.28 |
| typescript-bun | opus47-1m | 2 | 12.4min | 6.7min | 0.5 | 68 | $3.63 | $7.26 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 3 | 7.4min | 7.4min | 0.0 | 43 | $2.25 | $6.74 |
| powershell-tool | opus47-1m | 3 | 9.0min | 8.7min | 0.0 | 45 | $2.59 | $7.78 |
| powershell | opus47-1m | 3 | 9.2min | 8.7min | 0.3 | 43 | $2.61 | $7.82 |
| typescript-bun | opus47-1m | 2 | 12.4min | 6.7min | 0.5 | 68 | $3.63 | $7.26 |
| bash | opus47-1m | 3 | 24.6min | 24.6min | 2.0 | 49 | $2.76 | $8.28 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | opus47-1m | 2 | 12.4min | 6.7min | 0.5 | 68 | $3.63 | $7.26 |
| default | opus47-1m | 3 | 7.4min | 7.4min | 0.0 | 43 | $2.25 | $6.74 |
| powershell | opus47-1m | 3 | 9.2min | 8.7min | 0.3 | 43 | $2.61 | $7.82 |
| powershell-tool | opus47-1m | 3 | 9.0min | 8.7min | 0.0 | 45 | $2.59 | $7.78 |
| bash | opus47-1m | 3 | 24.6min | 24.6min | 2.0 | 49 | $2.76 | $8.28 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 3 | 7.4min | 7.4min | 0.0 | 43 | $2.25 | $6.74 |
| powershell-tool | opus47-1m | 3 | 9.0min | 8.7min | 0.0 | 45 | $2.59 | $7.78 |
| powershell | opus47-1m | 3 | 9.2min | 8.7min | 0.3 | 43 | $2.61 | $7.82 |
| typescript-bun | opus47-1m | 2 | 12.4min | 6.7min | 0.5 | 68 | $3.63 | $7.26 |
| bash | opus47-1m | 3 | 24.6min | 24.6min | 2.0 | 49 | $2.76 | $8.28 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m | 3 | 7.4min | 7.4min | 0.0 | 43 | $2.25 | $6.74 |
| powershell | opus47-1m | 3 | 9.2min | 8.7min | 0.3 | 43 | $2.61 | $7.82 |
| powershell-tool | opus47-1m | 3 | 9.0min | 8.7min | 0.0 | 45 | $2.59 | $7.78 |
| bash | opus47-1m | 3 | 24.6min | 24.6min | 2.0 | 49 | $2.76 | $8.28 |
| typescript-bun | opus47-1m | 2 | 12.4min | 6.7min | 0.5 | 68 | $3.63 | $7.26 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus47-1m | 47 | 3 | 6.4% | 0.6min | 0.3% | 0.0min | 0.0% | 0.6min | 0.3% | 25.1min | 2.2% |
| default | opus47-1m | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.1% | -0.1min | -0.1% | 3.1min | -3.5% |
| powershell | opus47-1m | 50 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 4.0min | -7.1% |
| powershell-tool | opus47-1m | 51 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 2.0min | -13.8% |
| typescript-bun | opus47-1m | 48 | 32 | 66.7% | 4.3min | 2.4% | 1.4min | 0.8% | 2.9min | 1.7% | 4.4min | 66.4% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 48 | 32 | 66.7% | 4.3min | 2.4% | 1.4min | 0.8% | 2.9min | 1.7% | 4.4min | 66.4% |
| bash | opus47-1m | 47 | 3 | 6.4% | 0.6min | 0.3% | 0.0min | 0.0% | 0.6min | 0.3% | 25.1min | 2.2% |
| default | opus47-1m | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.1% | -0.1min | -0.1% | 3.1min | -3.5% |
| powershell-tool | opus47-1m | 51 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 2.0min | -13.8% |
| powershell | opus47-1m | 50 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 4.0min | -7.1% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 48 | 32 | 66.7% | 4.3min | 2.4% | 1.4min | 0.8% | 2.9min | 1.7% | 4.4min | 66.4% |
| bash | opus47-1m | 47 | 3 | 6.4% | 0.6min | 0.3% | 0.0min | 0.0% | 0.6min | 0.3% | 25.1min | 2.2% |
| default | opus47-1m | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.1% | -0.1min | -0.1% | 3.1min | -3.5% |
| powershell | opus47-1m | 50 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 4.0min | -7.1% |
| powershell-tool | opus47-1m | 51 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 2.0min | -13.8% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m | 48 | 32 | 66.7% | 4.3min | 2.4% | 1.4min | 0.8% | 2.9min | 1.7% | 4.4min | 66.4% |
| bash | opus47-1m | 47 | 3 | 6.4% | 0.6min | 0.3% | 0.0min | 0.0% | 0.6min | 0.3% | 25.1min | 2.2% |
| default | opus47-1m | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.1% | -0.1min | -0.1% | 3.1min | -3.5% |
| powershell | opus47-1m | 50 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 4.0min | -7.1% |
| powershell-tool | opus47-1m | 51 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 2.0min | -13.8% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 2 | 6.4min | 3.7% | $1.88 | 4.96% |
| repeated-test-reruns | powershell | opus47-1m | 1 | 0.7min | 0.4% | $0.19 | 0.51% |
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 0.4% | $0.24 | 0.64% |
| repeated-test-reruns | typescript-bun | opus47-1m | 2 | 5.0min | 2.9% | $1.47 | 3.88% |
| fixture-rework | powershell | opus47-1m | 1 | 0.8min | 0.4% | $0.22 | 0.57% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | opus47-1m | 1 | 0.7min | 0.4% | $0.19 | 0.51% |
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 0.4% | $0.24 | 0.64% |
| fixture-rework | powershell | opus47-1m | 1 | 0.8min | 0.4% | $0.22 | 0.57% |
| repeated-test-reruns | typescript-bun | opus47-1m | 2 | 5.0min | 2.9% | $1.47 | 3.88% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 2 | 6.4min | 3.7% | $1.88 | 4.96% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | opus47-1m | 1 | 0.7min | 0.4% | $0.19 | 0.51% |
| fixture-rework | powershell | opus47-1m | 1 | 0.8min | 0.4% | $0.22 | 0.57% |
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 0.4% | $0.24 | 0.64% |
| repeated-test-reruns | typescript-bun | opus47-1m | 2 | 5.0min | 2.9% | $1.47 | 3.88% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 2 | 6.4min | 3.7% | $1.88 | 4.96% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | opus47-1m | 1 | 0.7min | 0.4% | $0.19 | 0.51% |
| repeated-test-reruns | powershell-tool | opus47-1m | 1 | 0.7min | 0.4% | $0.24 | 0.64% |
| fixture-rework | powershell | opus47-1m | 1 | 0.8min | 0.4% | $0.22 | 0.57% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m | 2 | 6.4min | 3.7% | $1.88 | 4.96% |
| repeated-test-reruns | typescript-bun | opus47-1m | 2 | 5.0min | 2.9% | $1.47 | 3.88% |

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
| bash | opus47-1m | 3 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus47-1m | 3 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus47-1m | 3 | 2 | 1.4min | 0.8% | $0.41 | 1.08% |
| powershell-tool | opus47-1m | 3 | 1 | 0.7min | 0.4% | $0.24 | 0.64% |
| typescript-bun | opus47-1m | 2 | 4 | 11.4min | 6.5% | $3.35 | 8.85% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| bash | opus47-1m | 3 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus47-1m | 3 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus47-1m | 3 | 1 | 0.7min | 0.4% | $0.24 | 0.64% |
| powershell | opus47-1m | 3 | 2 | 1.4min | 0.8% | $0.41 | 1.08% |
| typescript-bun | opus47-1m | 2 | 4 | 11.4min | 6.5% | $3.35 | 8.85% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| bash | opus47-1m | 3 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus47-1m | 3 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell-tool | opus47-1m | 3 | 1 | 0.7min | 0.4% | $0.24 | 0.64% |
| powershell | opus47-1m | 3 | 2 | 1.4min | 0.8% | $0.41 | 1.08% |
| typescript-bun | opus47-1m | 2 | 4 | 11.4min | 6.5% | $3.35 | 8.85% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 13 | $1.24 | 3.29% |
| Miss | 1 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | opus47-1m | 25.7 | 41.3 | 1.6 | 1.00 |
| default | opus47-1m | 27.0 | 49.7 | 1.8 | 1.40 |
| powershell | opus47-1m | 29.3 | 57.3 | 2.0 | 1.18 |
| powershell-tool | opus47-1m | 27.7 | 49.3 | 1.8 | 3.85 |
| typescript-bun | opus47-1m | 38.5 | 73.0 | 1.9 | 1.98 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m | 38.5 | 73.0 | 1.9 | 1.98 |
| powershell | opus47-1m | 29.3 | 57.3 | 2.0 | 1.18 |
| powershell-tool | opus47-1m | 27.7 | 49.3 | 1.8 | 3.85 |
| default | opus47-1m | 27.0 | 49.7 | 1.8 | 1.40 |
| bash | opus47-1m | 25.7 | 41.3 | 1.6 | 1.00 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m | 38.5 | 73.0 | 1.9 | 1.98 |
| powershell | opus47-1m | 29.3 | 57.3 | 2.0 | 1.18 |
| default | opus47-1m | 27.0 | 49.7 | 1.8 | 1.40 |
| powershell-tool | opus47-1m | 27.7 | 49.3 | 1.8 | 3.85 |
| bash | opus47-1m | 25.7 | 41.3 | 1.6 | 1.00 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-tool | opus47-1m | 27.7 | 49.3 | 1.8 | 3.85 |
| typescript-bun | opus47-1m | 38.5 | 73.0 | 1.9 | 1.98 |
| default | opus47-1m | 27.0 | 49.7 | 1.8 | 1.40 |
| powershell | opus47-1m | 29.3 | 57.3 | 2.0 | 1.18 |
| bash | opus47-1m | 25.7 | 41.3 | 1.6 | 1.00 |

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


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| PR Label Assigner | powershell-tool | opus47-1m | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| Dependency License Checker | default | opus47-1m | 7.5min | 40 | 0 | $2.04 | python | ok |
| Dependency License Checker | bash | opus47-1m | 39.8min | 38 | 2 | $2.19 | bash | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m | 6.8min | 45 | 0 | $2.45 | python | ok |
| Dependency License Checker | default | opus47-1m | 7.5min | 40 | 0 | $2.04 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| PR Label Assigner | default | opus47-1m | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| PR Label Assigner | powershell | opus47-1m | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Dependency License Checker | powershell-tool | opus47-1m | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
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
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Dependency License Checker | powershell | opus47-1m | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m | 17.2min | 48 | 2 | $2.95 | bash | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Dependency License Checker | bash | opus47-1m | 39.8min | 38 | 2 | $2.19 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
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
| PR Label Assigner | typescript-bun | opus47-1m | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| PR Label Assigner | bash | opus47-1m | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m | 14.3min | 80 | 1 | $4.21 | typescript | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*