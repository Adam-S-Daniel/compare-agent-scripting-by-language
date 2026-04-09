# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 02:44:47 PM ET

**Status:** 4/1 runs completed, 0 remaining
**Total cost so far:** $14.13
**Total agent time so far:** 42.2 min

## Observations

- **Fastest (avg):** powershell/opus — 4.4min, then default/opus — 5.3min
- **Fastest net of traps:** csharp-script/opus — -47.2min, then default/opus — -20.7min
- **Slowest (avg):** csharp-script/opus — 24.6min, then powershell-strict/opus — 7.9min
- **Slowest net of traps:** powershell/opus — -3.6min, then powershell-strict/opus — -9.6min
- **Cheapest (avg):** powershell/opus — $1.17, then default/opus — $1.29
- **Cheapest net of traps:** csharp-script/opus — $-17.08, then default/opus — $-5.08
- **Most expensive (avg):** csharp-script/opus — $8.90, then powershell-strict/opus — $2.77
- **Most expensive net of traps:** powershell/opus — $-0.94, then powershell-strict/opus — $-3.38

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| csharp-script | opus | 1 | 24.6min | -47.2min | 653 | 270.0 | 19 | $8.90 | $-17.08 | $8.90 |
| default | opus | 1 | 5.3min | -20.7min | 469 | 69.0 | 75 | $1.29 | $-5.08 | $1.29 |
| powershell | opus | 1 | 4.4min | -3.6min | 95 | 43.0 | 63 | $1.17 | $-0.94 | $1.17 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 641 | 79.0 | 102 | $2.77 | $-3.38 | $2.77 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| csharp-script | opus | 1 | 24.6min | -47.2min | 653 | 270.0 | 19 | $8.90 | $-17.08 | $8.90 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 641 | 79.0 | 102 | $2.77 | $-3.38 | $2.77 |
| default | opus | 1 | 5.3min | -20.7min | 469 | 69.0 | 75 | $1.29 | $-5.08 | $1.29 |
| powershell | opus | 1 | 4.4min | -3.6min | 95 | 43.0 | 63 | $1.17 | $-0.94 | $1.17 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 4.4min | -3.6min | 95 | 43.0 | 63 | $1.17 | $-0.94 | $1.17 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 641 | 79.0 | 102 | $2.77 | $-3.38 | $2.77 |
| default | opus | 1 | 5.3min | -20.7min | 469 | 69.0 | 75 | $1.29 | $-5.08 | $1.29 |
| csharp-script | opus | 1 | 24.6min | -47.2min | 653 | 270.0 | 19 | $8.90 | $-17.08 | $8.90 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| csharp-script | opus | 1 | 24.6min | -47.2min | 653 | 270.0 | 19 | $8.90 | $-17.08 | $8.90 |
| default | opus | 1 | 5.3min | -20.7min | 469 | 69.0 | 75 | $1.29 | $-5.08 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 641 | 79.0 | 102 | $2.77 | $-3.38 | $2.77 |
| powershell | opus | 1 | 4.4min | -3.6min | 95 | 43.0 | 63 | $1.17 | $-0.94 | $1.17 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 4.4min | -3.6min | 95 | 43.0 | 63 | $1.17 | $-0.94 | $1.17 |
| default | opus | 1 | 5.3min | -20.7min | 469 | 69.0 | 75 | $1.29 | $-5.08 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 641 | 79.0 | 102 | $2.77 | $-3.38 | $2.77 |
| csharp-script | opus | 1 | 24.6min | -47.2min | 653 | 270.0 | 19 | $8.90 | $-17.08 | $8.90 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 4.4min | -3.6min | 95 | 43.0 | 63 | $1.17 | $-0.94 | $1.17 |
| default | opus | 1 | 5.3min | -20.7min | 469 | 69.0 | 75 | $1.29 | $-5.08 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 641 | 79.0 | 102 | $2.77 | $-3.38 | $2.77 |
| csharp-script | opus | 1 | 24.6min | -47.2min | 653 | 270.0 | 19 | $8.90 | $-17.08 | $8.90 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| csharp-script | opus | 1 | 24.6min | -47.2min | 653 | 270.0 | 19 | $8.90 | $-17.08 | $8.90 |
| powershell | opus | 1 | 4.4min | -3.6min | 95 | 43.0 | 63 | $1.17 | $-0.94 | $1.17 |
| default | opus | 1 | 5.3min | -20.7min | 469 | 69.0 | 75 | $1.29 | $-5.08 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | -9.6min | 641 | 79.0 | 102 | $2.77 | $-3.38 | $2.77 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|

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
| **Total** | | | **4 runs** | **123.2min** | **292.3%** | **$40.62** | **287.34%** |


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

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 1 | 1 | 100% | 2 | 71.7min | 170.1% | $25.98 | 183.83% |
| default | opus | 1 | 1 | 100% | 3 | 26.0min | 61.7% | $6.37 | 45.07% |
| powershell | opus | 1 | 1 | 100% | 2 | 8.0min | 19.0% | $2.11 | 14.95% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 17.5min | 41.5% | $6.15 | 43.50% |
| **Total** | | **4** | **4** | **100%** | **11** | **123.2min** | **292.3%** | **$40.62** | **287.34%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell | opus | 1 | 1 | 100% | 2 | 8.0min | 19.0% | $2.11 | 14.95% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 17.5min | 41.5% | $6.15 | 43.50% |
| default | opus | 1 | 1 | 100% | 3 | 26.0min | 61.7% | $6.37 | 45.07% |
| csharp-script | opus | 1 | 1 | 100% | 2 | 71.7min | 170.1% | $25.98 | 183.83% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell | opus | 1 | 1 | 100% | 2 | 8.0min | 19.0% | $2.11 | 14.95% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 17.5min | 41.5% | $6.15 | 43.50% |
| default | opus | 1 | 1 | 100% | 3 | 26.0min | 61.7% | $6.37 | 45.07% |
| csharp-script | opus | 1 | 1 | 100% | 2 | 71.7min | 170.1% | $25.98 | 183.83% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 1 | 1 | 100% | 2 | 71.7min | 170.1% | $25.98 | 183.83% |
| default | opus | 1 | 1 | 100% | 3 | 26.0min | 61.7% | $6.37 | 45.07% |
| powershell | opus | 1 | 1 | 100% | 2 | 8.0min | 19.0% | $2.11 | 14.95% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 17.5min | 41.5% | $6.15 | 43.50% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 2 | $0.46 | 3.22% |
| Partial | 1 | $0.19 | 1.38% |
| Miss | 1 | $0.00 | 0.00% |
| **Total** | **4** | **$0.65** | **4.60%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 653 | 270 | $8.90 | csharp | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 469 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell | opus | 4.4min | 63 | 95 | 43 | $1.17 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 641 | 79 | $2.77 | powershell | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 653 | 270 | $8.90 | csharp | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 641 | 79 | $2.77 | powershell | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 469 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell | opus | 4.4min | 63 | 95 | 43 | $1.17 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 653 | 270 | $8.90 | csharp | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 641 | 79 | $2.77 | powershell | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 469 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell | opus | 4.4min | 63 | 95 | 43 | $1.17 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | powershell | opus | 4.4min | 63 | 95 | 43 | $1.17 | powershell | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 469 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 641 | 79 | $2.77 | powershell | ok |
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 653 | 270 | $8.90 | csharp | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | powershell | opus | 4.4min | 63 | 95 | 43 | $1.17 | powershell | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 469 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 641 | 79 | $2.77 | powershell | ok |
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 653 | 270 | $8.90 | csharp | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 24.6min | 19 | 653 | 270 | $8.90 | csharp | ok |
| CSV Report Generator | powershell | opus | 4.4min | 63 | 95 | 43 | $1.17 | powershell | ok |
| CSV Report Generator | default | opus | 5.3min | 75 | 469 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell-strict | opus | 7.9min | 102 | 641 | 79 | $2.77 | powershell | ok |

</details>

---
*Generated by generate_results.py, instructions version v4*