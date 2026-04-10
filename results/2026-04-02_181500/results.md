# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-10 04:30:36 AM ET

**Status:** 4/1 runs completed, 0 remaining
**Total cost so far:** $14.13
**Total agent time so far:** 42.2 min

## Observations

- **Fastest (avg):** powershell/opus — 4.4min, then default/opus — 5.3min
- **Slowest (avg):** csharp-script/opus — 24.6min, then powershell-strict/opus — 7.9min
- **Cheapest (avg):** powershell/opus — $1.17, then default/opus — $1.29
- **Most expensive (avg):** csharp-script/opus — $8.90, then powershell-strict/opus — $2.77

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| csharp-script | opus | 1 | 24.6min | -47.2min | 270.0 | 19 | $8.90 | $8.90 |
| default | opus | 1 | 5.3min | -20.7min | 69.0 | 75 | $1.29 | $1.29 |
| powershell | opus | 1 | 4.4min | -3.6min | 43.0 | 63 | $1.17 | $1.17 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 79.0 | 102 | $2.77 | $2.77 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus | 1 | 4.4min | -3.6min | 43.0 | 63 | $1.17 | $1.17 |
| default | opus | 1 | 5.3min | -20.7min | 69.0 | 75 | $1.29 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 79.0 | 102 | $2.77 | $2.77 |
| csharp-script | opus | 1 | 24.6min | -47.2min | 270.0 | 19 | $8.90 | $8.90 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus | 1 | 4.4min | -3.6min | 43.0 | 63 | $1.17 | $1.17 |
| default | opus | 1 | 5.3min | -20.7min | 69.0 | 75 | $1.29 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 79.0 | 102 | $2.77 | $2.77 |
| csharp-script | opus | 1 | 24.6min | -47.2min | 270.0 | 19 | $8.90 | $8.90 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| csharp-script | opus | 1 | 24.6min | -47.2min | 270.0 | 19 | $8.90 | $8.90 |
| default | opus | 1 | 5.3min | -20.7min | 69.0 | 75 | $1.29 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 79.0 | 102 | $2.77 | $2.77 |
| powershell | opus | 1 | 4.4min | -3.6min | 43.0 | 63 | $1.17 | $1.17 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus | 1 | 4.4min | -3.6min | 43.0 | 63 | $1.17 | $1.17 |
| default | opus | 1 | 5.3min | -20.7min | 69.0 | 75 | $1.29 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 79.0 | 102 | $2.77 | $2.77 |
| csharp-script | opus | 1 | 24.6min | -47.2min | 270.0 | 19 | $8.90 | $8.90 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| csharp-script | opus | 1 | 24.6min | -47.2min | 270.0 | 19 | $8.90 | $8.90 |
| powershell | opus | 1 | 4.4min | -3.6min | 43.0 | 63 | $1.17 | $1.17 |
| default | opus | 1 | 5.3min | -20.7min | 69.0 | 75 | $1.29 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 79.0 | 102 | $2.77 | $2.77 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| permission-denial-loops | csharp-script | opus | 1 | 41.3min | 98.0% | $14.97 | 105.93% |
| permission-denial-loops | default | opus | 1 | 11.3min | 26.9% | $2.78 | 19.64% |
| permission-denial-loops | powershell | opus | 1 | 6.3min | 15.0% | $1.67 | 11.83% |
| permission-denial-loops | powershell-strict | opus | 1 | 11.5min | 27.3% | $4.04 | 28.58% |
| dotnet-install-loop | csharp-script | opus | 1 | 30.4min | 72.1% | $11.01 | 77.91% |
| repeated-test-reruns | default | opus | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| repeated-test-reruns | powershell | opus | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| repeated-test-reruns | powershell-strict | opus | 3 | 6.0min | 14.2% | $2.11 | 14.91% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | opus | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| repeated-test-reruns | powershell-strict | opus | 3 | 6.0min | 14.2% | $2.11 | 14.91% |
| permission-denial-loops | powershell | opus | 1 | 6.3min | 15.0% | $1.67 | 11.83% |
| permission-denial-loops | default | opus | 1 | 11.3min | 26.9% | $2.78 | 19.64% |
| permission-denial-loops | powershell-strict | opus | 1 | 11.5min | 27.3% | $4.04 | 28.58% |
| repeated-test-reruns | default | opus | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| dotnet-install-loop | csharp-script | opus | 1 | 30.4min | 72.1% | $11.01 | 77.91% |
| permission-denial-loops | csharp-script | opus | 1 | 41.3min | 98.0% | $14.97 | 105.93% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | opus | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| permission-denial-loops | powershell | opus | 1 | 6.3min | 15.0% | $1.67 | 11.83% |
| repeated-test-reruns | powershell-strict | opus | 3 | 6.0min | 14.2% | $2.11 | 14.91% |
| permission-denial-loops | default | opus | 1 | 11.3min | 26.9% | $2.78 | 19.64% |
| repeated-test-reruns | default | opus | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| permission-denial-loops | powershell-strict | opus | 1 | 11.5min | 27.3% | $4.04 | 28.58% |
| dotnet-install-loop | csharp-script | opus | 1 | 30.4min | 72.1% | $11.01 | 77.91% |
| permission-denial-loops | csharp-script | opus | 1 | 41.3min | 98.0% | $14.97 | 105.93% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| permission-denial-loops | csharp-script | opus | 1 | 41.3min | 98.0% | $14.97 | 105.93% |
| permission-denial-loops | default | opus | 1 | 11.3min | 26.9% | $2.78 | 19.64% |
| permission-denial-loops | powershell | opus | 1 | 6.3min | 15.0% | $1.67 | 11.83% |
| permission-denial-loops | powershell-strict | opus | 1 | 11.5min | 27.3% | $4.04 | 28.58% |
| dotnet-install-loop | csharp-script | opus | 1 | 30.4min | 72.1% | $11.01 | 77.91% |
| repeated-test-reruns | powershell | opus | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| repeated-test-reruns | default | opus | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| repeated-test-reruns | powershell-strict | opus | 3 | 6.0min | 14.2% | $2.11 | 14.91% |

</details>

#### Trap Descriptions

- **dotnet-install-loop**: Agent stuck in loop trying to install/verify .NET SDK, blocked by CLI sandbox.
- **permission-denial-loops**: CLI sandbox blocked commands and agent retried instead of adapting (v1 harness issue).
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
| csharp-script | opus | 1 | 2 | 71.7min | 170.1% | $25.98 | 183.83% |
| default | opus | 1 | 3 | 26.0min | 61.7% | $6.37 | 45.07% |
| powershell | opus | 1 | 2 | 8.0min | 19.0% | $2.11 | 14.95% |
| powershell-strict | opus | 1 | 4 | 17.5min | 41.5% | $6.15 | 43.50% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| powershell | opus | 1 | 2 | 8.0min | 19.0% | $2.11 | 14.95% |
| powershell-strict | opus | 1 | 4 | 17.5min | 41.5% | $6.15 | 43.50% |
| default | opus | 1 | 3 | 26.0min | 61.7% | $6.37 | 45.07% |
| csharp-script | opus | 1 | 2 | 71.7min | 170.1% | $25.98 | 183.83% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| powershell | opus | 1 | 2 | 8.0min | 19.0% | $2.11 | 14.95% |
| powershell-strict | opus | 1 | 4 | 17.5min | 41.5% | $6.15 | 43.50% |
| default | opus | 1 | 3 | 26.0min | 61.7% | $6.37 | 45.07% |
| csharp-script | opus | 1 | 2 | 71.7min | 170.1% | $25.98 | 183.83% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 2 | $0.46 | 3.22% |
| Partial | 1 | $0.19 | 1.38% |
| Miss | 1 | $0.00 | 0.00% |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 270 | $8.90 | csharp | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell | opus | 4.4min | 63 | 43 | $1.17 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 79 | $2.77 | powershell | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | powershell | opus | 4.4min | 63 | 43 | $1.17 | powershell | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 79 | $2.77 | powershell | ok |
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 270 | $8.90 | csharp | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | powershell | opus | 4.4min | 63 | 43 | $1.17 | powershell | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 79 | $2.77 | powershell | ok |
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 270 | $8.90 | csharp | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | powershell | opus | 4.4min | 63 | 43 | $1.17 | powershell | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 79 | $2.77 | powershell | ok |
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 270 | $8.90 | csharp | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 270 | $8.90 | csharp | ok |
| CSV Report Generator | powershell | opus | 4.4min | 63 | 43 | $1.17 | powershell | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 79 | $2.77 | powershell | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v1*