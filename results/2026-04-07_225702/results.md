# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-10 04:30:36 AM ET

**Status:** 111/144 runs completed, 0 remaining
**Total cost so far:** $76.34
**Total agent time so far:** 459.2 min

## Observations

- **Fastest (avg):** csharp-script/sonnet — 0.6min, then csharp-script/opus — 1.8min
- **Slowest (avg):** powershell-strict/sonnet — 6.1min, then powershell-strict/opus — 4.9min
- **Cheapest (avg):** csharp-script/sonnet — $0.12, then default/sonnet — $0.35
- **Most expensive (avg):** powershell-strict/opus — $1.20, then powershell/opus — $0.97

- **Estimated time remaining:** 0.0min
- **Estimated total cost:** $99.03

## Failed / Timed-Out Runs

| Task | Mode | Model | Duration | Reason | Lines | actionlint | act-result.txt |
|------|------|-------|----------|--------|-------|------------|----------------|
| Database Seed Script | default | sonnet | 3.9min | exit_code=1 | 0 | n/a | no |
| Database Seed Script | powershell | sonnet | 3.8min | exit_code=1 | 0 | n/a | no |
| Database Seed Script | powershell-strict | sonnet | 3.6min | exit_code=1 | 0 | n/a | no |
| Error Retry Pipeline | default | sonnet | 3.7min | exit_code=1 | 0 | n/a | no |
| Error Retry Pipeline | powershell | sonnet | 3.8min | exit_code=1 | 0 | n/a | no |
| Error Retry Pipeline | powershell-strict | opus | 9.7min | exit_code=143 | 425 | n/a | no |
| Error Retry Pipeline | powershell-strict | sonnet | 3.8min | exit_code=1 | 0 | n/a | no |
| Multi-file Search and Replace | default | sonnet | 3.9min | exit_code=1 | 0 | n/a | no |
| Multi-file Search and Replace | powershell-strict | sonnet | 3.8min | exit_code=1 | 0 | n/a | no |
| Semantic Version Bumper | powershell-strict | sonnet | 5.3min | exit_code=1 | 353 | n/a | no |
| Dependency License Checker | default | sonnet | 4.0min | exit_code=1 | 0 | n/a | no |

*11 run(s) excluded from averages below.*

## Comparison by Language/Model
*(averages exclude failed/timed-out runs)*

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| csharp-script | opus | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 |
| csharp-script | sonnet | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 |
| default | opus | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 |
| default | sonnet | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 |
| powershell | opus | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 |
| powershell | sonnet | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 |
| powershell-strict | opus | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 |
| powershell-strict | sonnet | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| csharp-script | sonnet | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 |
| default | sonnet | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 |
| powershell | sonnet | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 |
| csharp-script | opus | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 |
| powershell-strict | sonnet | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 |
| default | opus | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 |
| powershell | opus | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 |
| powershell-strict | opus | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| csharp-script | sonnet | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 |
| csharp-script | opus | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 |
| default | sonnet | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 |
| default | opus | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 |
| powershell | sonnet | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 |
| powershell | opus | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 |
| powershell-strict | opus | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 |
| powershell-strict | sonnet | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| csharp-script | sonnet | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 |
| csharp-script | opus | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 |
| powershell | opus | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 |
| default | opus | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 |
| powershell-strict | opus | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 |
| default | sonnet | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 |
| powershell | sonnet | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 |
| powershell-strict | sonnet | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| csharp-script | opus | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 |
| csharp-script | sonnet | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 |
| powershell | sonnet | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 |
| powershell-strict | sonnet | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 |
| powershell | opus | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 |
| powershell-strict | opus | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 |
| default | sonnet | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 |
| default | opus | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| csharp-script | sonnet | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 |
| csharp-script | opus | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 |
| powershell | sonnet | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 |
| default | sonnet | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 |
| powershell-strict | sonnet | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 |
| default | opus | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 |
| powershell | opus | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 |
| powershell-strict | opus | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 |

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
| repeated-test-reruns | default | opus | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| repeated-test-reruns | powershell | opus | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| repeated-test-reruns | powershell | sonnet | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| repeated-test-reruns | powershell-strict | opus | 17 | 48.7min | 10.6% | $12.19 | 15.97% |
| repeated-test-reruns | powershell-strict | sonnet | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| fixture-rework | powershell-strict | opus | 1 | 0.5min | 0.1% | $0.12 | 0.15% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | powershell-strict | opus | 1 | 0.5min | 0.1% | $0.12 | 0.15% |
| repeated-test-reruns | powershell | sonnet | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| repeated-test-reruns | powershell-strict | sonnet | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| repeated-test-reruns | default | opus | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| repeated-test-reruns | powershell | opus | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| repeated-test-reruns | powershell-strict | opus | 17 | 48.7min | 10.6% | $12.19 | 15.97% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | powershell-strict | opus | 1 | 0.5min | 0.1% | $0.12 | 0.15% |
| repeated-test-reruns | powershell | sonnet | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| repeated-test-reruns | powershell-strict | sonnet | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| repeated-test-reruns | default | opus | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| repeated-test-reruns | powershell | opus | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| repeated-test-reruns | powershell-strict | opus | 17 | 48.7min | 10.6% | $12.19 | 15.97% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | powershell-strict | opus | 1 | 0.5min | 0.1% | $0.12 | 0.15% |
| repeated-test-reruns | powershell | sonnet | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| repeated-test-reruns | powershell-strict | sonnet | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| repeated-test-reruns | default | opus | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| repeated-test-reruns | powershell | opus | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| repeated-test-reruns | powershell-strict | opus | 17 | 48.7min | 10.6% | $12.19 | 15.97% |

</details>

#### Trap Descriptions

- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
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
| csharp-script | opus | 2 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| csharp-script | sonnet | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 18 | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| default | sonnet | 18 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 18 | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| powershell | sonnet | 18 | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| powershell-strict | opus | 18 | 18 | 49.2min | 10.7% | $12.30 | 16.12% |
| powershell-strict | sonnet | 18 | 6 | 5.7min | 1.2% | $0.76 | 1.00% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 2 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| csharp-script | sonnet | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 18 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 18 | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| powershell-strict | sonnet | 18 | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| default | opus | 18 | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| powershell | opus | 18 | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| powershell-strict | opus | 18 | 18 | 49.2min | 10.7% | $12.30 | 16.12% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 2 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| csharp-script | sonnet | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 18 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 18 | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| powershell-strict | sonnet | 18 | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| default | opus | 18 | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| powershell | opus | 18 | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| powershell-strict | opus | 18 | 18 | 49.2min | 10.7% | $12.30 | 16.12% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 102 | $12.80 | 16.77% |
| Miss | 9 | $0.00 | 0.00% |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 2.8min | 12 | 0 | $0.58 | csharp | ok |
| CSV Report Generator | csharp-script | sonnet | 0.6min | 7 | 0 | $0.12 | csharp | ok |
| CSV Report Generator | default | opus | 1.7min | 12 | 0 | $0.38 | python | ok |
| CSV Report Generator | default | sonnet | 6.3min | 1 | 3 | $0.71 | python | ok |
| CSV Report Generator | powershell | opus | 4.3min | 37 | 0 | $1.05 | powershell | ok |
| CSV Report Generator | powershell | sonnet | 2.1min | 9 | 0 | $0.31 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 4.3min | 40 | 1 | $1.04 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 6.5min | 29 | 0 | $0.97 | powershell | ok |
| Log File Analyzer | csharp-script | opus | 0.7min | 9 | 0 | $0.25 | csharp | ok |
| Log File Analyzer | default | opus | 4.2min | 43 | 0 | $1.18 | python | ok |
| Log File Analyzer | default | sonnet | 2.9min | 19 | 0 | $0.48 | python | ok |
| Log File Analyzer | powershell | opus | 4.6min | 41 | 0 | $1.14 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 3.9min | 10 | 0 | $0.44 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 4.5min | 31 | 1 | $0.95 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 3.8min | 14 | 1 | $0.50 | powershell | ok |
| Directory Tree Sync | default | opus | 3.8min | 43 | 0 | $1.18 | python | ok |
| Directory Tree Sync | default | sonnet | 3.9min | 11 | 1 | $0.45 | python | ok |
| Directory Tree Sync | powershell | opus | 5.3min | 42 | 0 | $1.13 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 3.0min | 11 | 0 | $0.37 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus | 5.4min | 34 | 0 | $1.21 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 4.3min | 13 | 0 | $0.49 | powershell | ok |
| REST API Client | default | opus | 5.2min | 45 | 0 | $1.21 | python | ok |
| REST API Client | default | sonnet | 1.8min | 9 | 1 | $0.23 | python | ok |
| REST API Client | powershell | opus | 7.2min | 51 | 1 | $1.82 | powershell | ok |
| REST API Client | powershell | sonnet | 12.6min | 13 | 0 | $0.96 | powershell | ok |
| REST API Client | powershell-strict | opus | 5.1min | 19 | 0 | $0.94 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 9.2min | 14 | 0 | $0.99 | powershell | ok |
| Process Monitor | default | opus | 3.3min | 40 | 1 | $1.00 | python | ok |
| Process Monitor | default | sonnet | 2.0min | 12 | 0 | $0.25 | python | ok |
| Process Monitor | powershell | opus | 5.4min | 39 | 0 | $1.21 | powershell | ok |
| Process Monitor | powershell | sonnet | 3.8min | 13 | 0 | $0.40 | powershell | ok |
| Process Monitor | powershell-strict | opus | 5.6min | 53 | 0 | $1.61 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 4.6min | 19 | 0 | $0.54 | powershell | ok |
| Config File Migrator | default | opus | 2.8min | 14 | 1 | $0.59 | python | ok |
| Config File Migrator | default | sonnet | 3.4min | 18 | 1 | $0.47 | python | ok |
| Config File Migrator | powershell | opus | 3.7min | 20 | 0 | $0.69 | powershell | ok |
| Config File Migrator | powershell | sonnet | 3.4min | 15 | 0 | $0.38 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 2.7min | 12 | 0 | $0.49 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet | 13.9min | 21 | 0 | $1.60 | powershell | ok |
| Batch File Renamer | default | opus | 2.8min | 30 | 2 | $0.81 | python | ok |
| Batch File Renamer | default | sonnet | 2.3min | 8 | 0 | $0.22 | python | ok |
| Batch File Renamer | powershell | opus | 3.0min | 21 | 0 | $0.59 | powershell | ok |
| Batch File Renamer | powershell | sonnet | 1.4min | 6 | 0 | $0.16 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 4.5min | 35 | 0 | $1.05 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 3.7min | 16 | 1 | $0.50 | powershell | ok |
| Database Seed Script | default | opus | 4.3min | 36 | 1 | $1.04 | python | ok |
| Database Seed Script | default | sonnet | 3.9min | 1 | 0 | $0.00 |  | failed |
| Database Seed Script | powershell | opus | 5.8min | 42 | 4 | $1.32 | powershell | ok |
| Database Seed Script | powershell | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Database Seed Script | powershell-strict | opus | 8.7min | 56 | 2 | $2.03 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 3.6min | 1 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | default | opus | 2.3min | 24 | 0 | $0.54 | python | ok |
| Error Retry Pipeline | default | sonnet | 3.7min | 1 | 0 | $0.00 |  | failed |
| Error Retry Pipeline | powershell | opus | 3.8min | 34 | 0 | $0.93 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | powershell-strict | opus | 9.7min | 0 | 1 | $0.00 | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Multi-file Search and Replace | default | opus | 3.1min | 25 | 3 | $0.70 | python | ok |
| Multi-file Search and Replace | default | sonnet | 3.9min | 1 | 0 | $0.00 |  | failed |
| Multi-file Search and Replace | powershell | opus | 3.6min | 21 | 0 | $0.65 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 1.4min | 10 | 0 | $0.19 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 4.1min | 34 | 0 | $1.09 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Semantic Version Bumper | default | opus | 4.8min | 47 | 5 | $1.23 | python | ok |
| Semantic Version Bumper | default | sonnet | 2.5min | 11 | 0 | $0.25 | python | ok |
| Semantic Version Bumper | powershell | opus | 3.6min | 27 | 0 | $0.77 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 2.7min | 16 | 0 | $0.33 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 5.8min | 52 | 0 | $1.57 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 5.3min | 5 | 0 | $0.15 | powershell | failed |
| PR Label Assigner | default | opus | 1.9min | 11 | 1 | $0.38 | python | ok |
| PR Label Assigner | default | sonnet | 1.8min | 8 | 0 | $0.21 | python | ok |
| PR Label Assigner | powershell | opus | 3.1min | 23 | 0 | $0.61 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 3.7min | 10 | 0 | $0.38 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 4.0min | 37 | 0 | $1.03 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet | 3.3min | 12 | 0 | $0.35 | powershell | ok |
| Dependency License Checker | default | opus | 5.6min | 64 | 4 | $1.73 | python | ok |
| Dependency License Checker | default | sonnet | 4.0min | 1 | 0 | $0.00 |  | failed |
| Dependency License Checker | powershell | opus | 5.8min | 45 | 1 | $1.37 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 2.6min | 11 | 0 | $0.36 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 5.4min | 52 | 4 | $1.59 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 9.5min | 18 | 0 | $0.97 | powershell | ok |
| Docker Image Tag Generator | default | opus | 2.7min | 30 | 0 | $0.67 | python | ok |
| Docker Image Tag Generator | default | sonnet | 1.8min | 10 | 1 | $0.23 | python | ok |
| Docker Image Tag Generator | powershell | opus | 3.5min | 32 | 0 | $0.84 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 2.9min | 9 | 0 | $0.31 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 5.0min | 44 | 0 | $1.28 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 2.5min | 13 | 0 | $0.33 | powershell | ok |
| Test Results Aggregator | default | opus | 2.3min | 15 | 1 | $0.51 | python | ok |
| Test Results Aggregator | default | sonnet | 4.0min | 20 | 1 | $0.49 | python | ok |
| Test Results Aggregator | powershell | opus | 4.3min | 33 | 0 | $0.95 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 5.0min | 15 | 0 | $0.55 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 4.0min | 24 | 0 | $0.95 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 11.5min | 20 | 0 | $1.42 | powershell | ok |
| Environment Matrix Generator | default | opus | 4.7min | 38 | 1 | $1.11 | python | ok |
| Environment Matrix Generator | default | sonnet | 2.0min | 9 | 0 | $0.26 | python | ok |
| Environment Matrix Generator | powershell | opus | 2.3min | 18 | 0 | $0.54 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 2.8min | 13 | 0 | $0.36 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 4.2min | 31 | 2 | $0.96 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 5.4min | 16 | 0 | $0.62 | powershell | ok |
| Artifact Cleanup Script | default | opus | 4.4min | 34 | 0 | $0.98 | python | ok |
| Artifact Cleanup Script | default | sonnet | 2.6min | 17 | 4 | $0.44 | python | ok |
| Artifact Cleanup Script | powershell | opus | 4.9min | 30 | 0 | $1.16 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 2.6min | 9 | 0 | $0.35 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus | 5.5min | 37 | 1 | $1.37 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 3.6min | 15 | 0 | $0.49 | powershell | ok |
| Secret Rotation Validator | default | opus | 2.6min | 17 | 0 | $0.51 | python | ok |
| Secret Rotation Validator | default | sonnet | 1.5min | 11 | 0 | $0.22 | python | ok |
| Secret Rotation Validator | powershell | opus | 3.3min | 23 | 1 | $0.72 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 3.5min | 11 | 0 | $0.48 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus | 5.3min | 39 | 2 | $1.27 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 4.0min | 20 | 0 | $0.53 | powershell | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Database Seed Script | default | sonnet | 3.9min | 1 | 0 | $0.00 |  | failed |
| Database Seed Script | powershell | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Database Seed Script | powershell-strict | sonnet | 3.6min | 1 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | default | sonnet | 3.7min | 1 | 0 | $0.00 |  | failed |
| Error Retry Pipeline | powershell | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | powershell-strict | opus | 9.7min | 0 | 1 | $0.00 | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Multi-file Search and Replace | default | sonnet | 3.9min | 1 | 0 | $0.00 |  | failed |
| Multi-file Search and Replace | powershell-strict | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Dependency License Checker | default | sonnet | 4.0min | 1 | 0 | $0.00 |  | failed |
| CSV Report Generator | csharp-script | sonnet | 0.6min | 7 | 0 | $0.12 | csharp | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 5.3min | 5 | 0 | $0.15 | powershell | failed |
| Batch File Renamer | powershell | sonnet | 1.4min | 6 | 0 | $0.16 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 1.4min | 10 | 0 | $0.19 | powershell | ok |
| PR Label Assigner | default | sonnet | 1.8min | 8 | 0 | $0.21 | python | ok |
| Secret Rotation Validator | default | sonnet | 1.5min | 11 | 0 | $0.22 | python | ok |
| Batch File Renamer | default | sonnet | 2.3min | 8 | 0 | $0.22 | python | ok |
| REST API Client | default | sonnet | 1.8min | 9 | 1 | $0.23 | python | ok |
| Docker Image Tag Generator | default | sonnet | 1.8min | 10 | 1 | $0.23 | python | ok |
| Semantic Version Bumper | default | sonnet | 2.5min | 11 | 0 | $0.25 | python | ok |
| Process Monitor | default | sonnet | 2.0min | 12 | 0 | $0.25 | python | ok |
| Log File Analyzer | csharp-script | opus | 0.7min | 9 | 0 | $0.25 | csharp | ok |
| Environment Matrix Generator | default | sonnet | 2.0min | 9 | 0 | $0.26 | python | ok |
| CSV Report Generator | powershell | sonnet | 2.1min | 9 | 0 | $0.31 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 2.9min | 9 | 0 | $0.31 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 2.7min | 16 | 0 | $0.33 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 2.5min | 13 | 0 | $0.33 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 2.6min | 9 | 0 | $0.35 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet | 3.3min | 12 | 0 | $0.35 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 2.8min | 13 | 0 | $0.36 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 2.6min | 11 | 0 | $0.36 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 3.0min | 11 | 0 | $0.37 | powershell | ok |
| PR Label Assigner | default | opus | 1.9min | 11 | 1 | $0.38 | python | ok |
| CSV Report Generator | default | opus | 1.7min | 12 | 0 | $0.38 | python | ok |
| Config File Migrator | powershell | sonnet | 3.4min | 15 | 0 | $0.38 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 3.7min | 10 | 0 | $0.38 | powershell | ok |
| Process Monitor | powershell | sonnet | 3.8min | 13 | 0 | $0.40 | powershell | ok |
| Artifact Cleanup Script | default | sonnet | 2.6min | 17 | 4 | $0.44 | python | ok |
| Log File Analyzer | powershell | sonnet | 3.9min | 10 | 0 | $0.44 | powershell | ok |
| Directory Tree Sync | default | sonnet | 3.9min | 11 | 1 | $0.45 | python | ok |
| Config File Migrator | default | sonnet | 3.4min | 18 | 1 | $0.47 | python | ok |
| Secret Rotation Validator | powershell | sonnet | 3.5min | 11 | 0 | $0.48 | powershell | ok |
| Log File Analyzer | default | sonnet | 2.9min | 19 | 0 | $0.48 | python | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 3.6min | 15 | 0 | $0.49 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 2.7min | 12 | 0 | $0.49 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 4.3min | 13 | 0 | $0.49 | powershell | ok |
| Test Results Aggregator | default | sonnet | 4.0min | 20 | 1 | $0.49 | python | ok |
| Batch File Renamer | powershell-strict | sonnet | 3.7min | 16 | 1 | $0.50 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 3.8min | 14 | 1 | $0.50 | powershell | ok |
| Test Results Aggregator | default | opus | 2.3min | 15 | 1 | $0.51 | python | ok |
| Secret Rotation Validator | default | opus | 2.6min | 17 | 0 | $0.51 | python | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 4.0min | 20 | 0 | $0.53 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 4.6min | 19 | 0 | $0.54 | powershell | ok |
| Environment Matrix Generator | powershell | opus | 2.3min | 18 | 0 | $0.54 | powershell | ok |
| Error Retry Pipeline | default | opus | 2.3min | 24 | 0 | $0.54 | python | ok |
| Test Results Aggregator | powershell | sonnet | 5.0min | 15 | 0 | $0.55 | powershell | ok |
| CSV Report Generator | csharp-script | opus | 2.8min | 12 | 0 | $0.58 | csharp | ok |
| Config File Migrator | default | opus | 2.8min | 14 | 1 | $0.59 | python | ok |
| Batch File Renamer | powershell | opus | 3.0min | 21 | 0 | $0.59 | powershell | ok |
| PR Label Assigner | powershell | opus | 3.1min | 23 | 0 | $0.61 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 5.4min | 16 | 0 | $0.62 | powershell | ok |
| Multi-file Search and Replace | powershell | opus | 3.6min | 21 | 0 | $0.65 | powershell | ok |
| Docker Image Tag Generator | default | opus | 2.7min | 30 | 0 | $0.67 | python | ok |
| Config File Migrator | powershell | opus | 3.7min | 20 | 0 | $0.69 | powershell | ok |
| Multi-file Search and Replace | default | opus | 3.1min | 25 | 3 | $0.70 | python | ok |
| CSV Report Generator | default | sonnet | 6.3min | 1 | 3 | $0.71 | python | ok |
| Secret Rotation Validator | powershell | opus | 3.3min | 23 | 1 | $0.72 | powershell | ok |
| Semantic Version Bumper | powershell | opus | 3.6min | 27 | 0 | $0.77 | powershell | ok |
| Batch File Renamer | default | opus | 2.8min | 30 | 2 | $0.81 | python | ok |
| Docker Image Tag Generator | powershell | opus | 3.5min | 32 | 0 | $0.84 | powershell | ok |
| Error Retry Pipeline | powershell | opus | 3.8min | 34 | 0 | $0.93 | powershell | ok |
| REST API Client | powershell-strict | opus | 5.1min | 19 | 0 | $0.94 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 4.5min | 31 | 1 | $0.95 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 4.0min | 24 | 0 | $0.95 | powershell | ok |
| Test Results Aggregator | powershell | opus | 4.3min | 33 | 0 | $0.95 | powershell | ok |
| REST API Client | powershell | sonnet | 12.6min | 13 | 0 | $0.96 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 4.2min | 31 | 2 | $0.96 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 9.5min | 18 | 0 | $0.97 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 6.5min | 29 | 0 | $0.97 | powershell | ok |
| Artifact Cleanup Script | default | opus | 4.4min | 34 | 0 | $0.98 | python | ok |
| REST API Client | powershell-strict | sonnet | 9.2min | 14 | 0 | $0.99 | powershell | ok |
| Process Monitor | default | opus | 3.3min | 40 | 1 | $1.00 | python | ok |
| PR Label Assigner | powershell-strict | opus | 4.0min | 37 | 0 | $1.03 | powershell | ok |
| Database Seed Script | default | opus | 4.3min | 36 | 1 | $1.04 | python | ok |
| CSV Report Generator | powershell-strict | opus | 4.3min | 40 | 1 | $1.04 | powershell | ok |
| CSV Report Generator | powershell | opus | 4.3min | 37 | 0 | $1.05 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 4.5min | 35 | 0 | $1.05 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 4.1min | 34 | 0 | $1.09 | powershell | ok |
| Environment Matrix Generator | default | opus | 4.7min | 38 | 1 | $1.11 | python | ok |
| Directory Tree Sync | powershell | opus | 5.3min | 42 | 0 | $1.13 | powershell | ok |
| Log File Analyzer | powershell | opus | 4.6min | 41 | 0 | $1.14 | powershell | ok |
| Artifact Cleanup Script | powershell | opus | 4.9min | 30 | 0 | $1.16 | powershell | ok |
| Directory Tree Sync | default | opus | 3.8min | 43 | 0 | $1.18 | python | ok |
| Log File Analyzer | default | opus | 4.2min | 43 | 0 | $1.18 | python | ok |
| Process Monitor | powershell | opus | 5.4min | 39 | 0 | $1.21 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus | 5.4min | 34 | 0 | $1.21 | powershell | ok |
| REST API Client | default | opus | 5.2min | 45 | 0 | $1.21 | python | ok |
| Semantic Version Bumper | default | opus | 4.8min | 47 | 5 | $1.23 | python | ok |
| Secret Rotation Validator | powershell-strict | opus | 5.3min | 39 | 2 | $1.27 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 5.0min | 44 | 0 | $1.28 | powershell | ok |
| Database Seed Script | powershell | opus | 5.8min | 42 | 4 | $1.32 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus | 5.5min | 37 | 1 | $1.37 | powershell | ok |
| Dependency License Checker | powershell | opus | 5.8min | 45 | 1 | $1.37 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 11.5min | 20 | 0 | $1.42 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 5.8min | 52 | 0 | $1.57 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 5.4min | 52 | 4 | $1.59 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet | 13.9min | 21 | 0 | $1.60 | powershell | ok |
| Process Monitor | powershell-strict | opus | 5.6min | 53 | 0 | $1.61 | powershell | ok |
| Dependency License Checker | default | opus | 5.6min | 64 | 4 | $1.73 | python | ok |
| REST API Client | powershell | opus | 7.2min | 51 | 1 | $1.82 | powershell | ok |
| Database Seed Script | powershell-strict | opus | 8.7min | 56 | 2 | $2.03 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | sonnet | 0.6min | 7 | 0 | $0.12 | csharp | ok |
| Log File Analyzer | csharp-script | opus | 0.7min | 9 | 0 | $0.25 | csharp | ok |
| Batch File Renamer | powershell | sonnet | 1.4min | 6 | 0 | $0.16 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 1.4min | 10 | 0 | $0.19 | powershell | ok |
| Secret Rotation Validator | default | sonnet | 1.5min | 11 | 0 | $0.22 | python | ok |
| CSV Report Generator | default | opus | 1.7min | 12 | 0 | $0.38 | python | ok |
| PR Label Assigner | default | sonnet | 1.8min | 8 | 0 | $0.21 | python | ok |
| Docker Image Tag Generator | default | sonnet | 1.8min | 10 | 1 | $0.23 | python | ok |
| REST API Client | default | sonnet | 1.8min | 9 | 1 | $0.23 | python | ok |
| PR Label Assigner | default | opus | 1.9min | 11 | 1 | $0.38 | python | ok |
| Process Monitor | default | sonnet | 2.0min | 12 | 0 | $0.25 | python | ok |
| Environment Matrix Generator | default | sonnet | 2.0min | 9 | 0 | $0.26 | python | ok |
| CSV Report Generator | powershell | sonnet | 2.1min | 9 | 0 | $0.31 | powershell | ok |
| Batch File Renamer | default | sonnet | 2.3min | 8 | 0 | $0.22 | python | ok |
| Test Results Aggregator | default | opus | 2.3min | 15 | 1 | $0.51 | python | ok |
| Error Retry Pipeline | default | opus | 2.3min | 24 | 0 | $0.54 | python | ok |
| Environment Matrix Generator | powershell | opus | 2.3min | 18 | 0 | $0.54 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 2.5min | 11 | 0 | $0.25 | python | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 2.5min | 13 | 0 | $0.33 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 2.6min | 11 | 0 | $0.36 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 2.6min | 9 | 0 | $0.35 | powershell | ok |
| Artifact Cleanup Script | default | sonnet | 2.6min | 17 | 4 | $0.44 | python | ok |
| Secret Rotation Validator | default | opus | 2.6min | 17 | 0 | $0.51 | python | ok |
| Semantic Version Bumper | powershell | sonnet | 2.7min | 16 | 0 | $0.33 | powershell | ok |
| Docker Image Tag Generator | default | opus | 2.7min | 30 | 0 | $0.67 | python | ok |
| Config File Migrator | powershell-strict | opus | 2.7min | 12 | 0 | $0.49 | powershell | ok |
| Config File Migrator | default | opus | 2.8min | 14 | 1 | $0.59 | python | ok |
| Batch File Renamer | default | opus | 2.8min | 30 | 2 | $0.81 | python | ok |
| Environment Matrix Generator | powershell | sonnet | 2.8min | 13 | 0 | $0.36 | powershell | ok |
| CSV Report Generator | csharp-script | opus | 2.8min | 12 | 0 | $0.58 | csharp | ok |
| Log File Analyzer | default | sonnet | 2.9min | 19 | 0 | $0.48 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 2.9min | 9 | 0 | $0.31 | powershell | ok |
| Batch File Renamer | powershell | opus | 3.0min | 21 | 0 | $0.59 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 3.0min | 11 | 0 | $0.37 | powershell | ok |
| PR Label Assigner | powershell | opus | 3.1min | 23 | 0 | $0.61 | powershell | ok |
| Multi-file Search and Replace | default | opus | 3.1min | 25 | 3 | $0.70 | python | ok |
| PR Label Assigner | powershell-strict | sonnet | 3.3min | 12 | 0 | $0.35 | powershell | ok |
| Secret Rotation Validator | powershell | opus | 3.3min | 23 | 1 | $0.72 | powershell | ok |
| Process Monitor | default | opus | 3.3min | 40 | 1 | $1.00 | python | ok |
| Config File Migrator | default | sonnet | 3.4min | 18 | 1 | $0.47 | python | ok |
| Config File Migrator | powershell | sonnet | 3.4min | 15 | 0 | $0.38 | powershell | ok |
| Docker Image Tag Generator | powershell | opus | 3.5min | 32 | 0 | $0.84 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 3.5min | 11 | 0 | $0.48 | powershell | ok |
| Semantic Version Bumper | powershell | opus | 3.6min | 27 | 0 | $0.77 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 3.6min | 1 | 0 | $0.00 | powershell | failed |
| Artifact Cleanup Script | powershell-strict | sonnet | 3.6min | 15 | 0 | $0.49 | powershell | ok |
| Multi-file Search and Replace | powershell | opus | 3.6min | 21 | 0 | $0.65 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 3.7min | 10 | 0 | $0.38 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 3.7min | 16 | 1 | $0.50 | powershell | ok |
| Error Retry Pipeline | default | sonnet | 3.7min | 1 | 0 | $0.00 |  | failed |
| Config File Migrator | powershell | opus | 3.7min | 20 | 0 | $0.69 | powershell | ok |
| Database Seed Script | powershell | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Process Monitor | powershell | sonnet | 3.8min | 13 | 0 | $0.40 | powershell | ok |
| Directory Tree Sync | default | opus | 3.8min | 43 | 0 | $1.18 | python | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Log File Analyzer | powershell-strict | sonnet | 3.8min | 14 | 1 | $0.50 | powershell | ok |
| Error Retry Pipeline | powershell | opus | 3.8min | 34 | 0 | $0.93 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Database Seed Script | default | sonnet | 3.9min | 1 | 0 | $0.00 |  | failed |
| Log File Analyzer | powershell | sonnet | 3.9min | 10 | 0 | $0.44 | powershell | ok |
| Multi-file Search and Replace | default | sonnet | 3.9min | 1 | 0 | $0.00 |  | failed |
| Directory Tree Sync | default | sonnet | 3.9min | 11 | 1 | $0.45 | python | ok |
| Test Results Aggregator | powershell-strict | opus | 4.0min | 24 | 0 | $0.95 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 4.0min | 20 | 0 | $0.53 | powershell | ok |
| Dependency License Checker | default | sonnet | 4.0min | 1 | 0 | $0.00 |  | failed |
| Test Results Aggregator | default | sonnet | 4.0min | 20 | 1 | $0.49 | python | ok |
| PR Label Assigner | powershell-strict | opus | 4.0min | 37 | 0 | $1.03 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 4.1min | 34 | 0 | $1.09 | powershell | ok |
| Log File Analyzer | default | opus | 4.2min | 43 | 0 | $1.18 | python | ok |
| Environment Matrix Generator | powershell-strict | opus | 4.2min | 31 | 2 | $0.96 | powershell | ok |
| CSV Report Generator | powershell | opus | 4.3min | 37 | 0 | $1.05 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 4.3min | 40 | 1 | $1.04 | powershell | ok |
| Test Results Aggregator | powershell | opus | 4.3min | 33 | 0 | $0.95 | powershell | ok |
| Database Seed Script | default | opus | 4.3min | 36 | 1 | $1.04 | python | ok |
| Directory Tree Sync | powershell-strict | sonnet | 4.3min | 13 | 0 | $0.49 | powershell | ok |
| Artifact Cleanup Script | default | opus | 4.4min | 34 | 0 | $0.98 | python | ok |
| Log File Analyzer | powershell-strict | opus | 4.5min | 31 | 1 | $0.95 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 4.5min | 35 | 0 | $1.05 | powershell | ok |
| Log File Analyzer | powershell | opus | 4.6min | 41 | 0 | $1.14 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 4.6min | 19 | 0 | $0.54 | powershell | ok |
| Environment Matrix Generator | default | opus | 4.7min | 38 | 1 | $1.11 | python | ok |
| Semantic Version Bumper | default | opus | 4.8min | 47 | 5 | $1.23 | python | ok |
| Artifact Cleanup Script | powershell | opus | 4.9min | 30 | 0 | $1.16 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 5.0min | 15 | 0 | $0.55 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 5.0min | 44 | 0 | $1.28 | powershell | ok |
| REST API Client | powershell-strict | opus | 5.1min | 19 | 0 | $0.94 | powershell | ok |
| REST API Client | default | opus | 5.2min | 45 | 0 | $1.21 | python | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 5.3min | 5 | 0 | $0.15 | powershell | failed |
| Secret Rotation Validator | powershell-strict | opus | 5.3min | 39 | 2 | $1.27 | powershell | ok |
| Directory Tree Sync | powershell | opus | 5.3min | 42 | 0 | $1.13 | powershell | ok |
| Process Monitor | powershell | opus | 5.4min | 39 | 0 | $1.21 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus | 5.4min | 34 | 0 | $1.21 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 5.4min | 16 | 0 | $0.62 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 5.4min | 52 | 4 | $1.59 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus | 5.5min | 37 | 1 | $1.37 | powershell | ok |
| Dependency License Checker | default | opus | 5.6min | 64 | 4 | $1.73 | python | ok |
| Process Monitor | powershell-strict | opus | 5.6min | 53 | 0 | $1.61 | powershell | ok |
| Dependency License Checker | powershell | opus | 5.8min | 45 | 1 | $1.37 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 5.8min | 52 | 0 | $1.57 | powershell | ok |
| Database Seed Script | powershell | opus | 5.8min | 42 | 4 | $1.32 | powershell | ok |
| CSV Report Generator | default | sonnet | 6.3min | 1 | 3 | $0.71 | python | ok |
| CSV Report Generator | powershell-strict | sonnet | 6.5min | 29 | 0 | $0.97 | powershell | ok |
| REST API Client | powershell | opus | 7.2min | 51 | 1 | $1.82 | powershell | ok |
| Database Seed Script | powershell-strict | opus | 8.7min | 56 | 2 | $2.03 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 9.2min | 14 | 0 | $0.99 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 9.5min | 18 | 0 | $0.97 | powershell | ok |
| Error Retry Pipeline | powershell-strict | opus | 9.7min | 0 | 1 | $0.00 | powershell | failed |
| Test Results Aggregator | powershell-strict | sonnet | 11.5min | 20 | 0 | $1.42 | powershell | ok |
| REST API Client | powershell | sonnet | 12.6min | 13 | 0 | $0.96 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet | 13.9min | 21 | 0 | $1.60 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 2.8min | 12 | 0 | $0.58 | csharp | ok |
| CSV Report Generator | csharp-script | sonnet | 0.6min | 7 | 0 | $0.12 | csharp | ok |
| CSV Report Generator | default | opus | 1.7min | 12 | 0 | $0.38 | python | ok |
| CSV Report Generator | powershell | opus | 4.3min | 37 | 0 | $1.05 | powershell | ok |
| CSV Report Generator | powershell | sonnet | 2.1min | 9 | 0 | $0.31 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 6.5min | 29 | 0 | $0.97 | powershell | ok |
| Log File Analyzer | csharp-script | opus | 0.7min | 9 | 0 | $0.25 | csharp | ok |
| Log File Analyzer | default | opus | 4.2min | 43 | 0 | $1.18 | python | ok |
| Log File Analyzer | default | sonnet | 2.9min | 19 | 0 | $0.48 | python | ok |
| Log File Analyzer | powershell | opus | 4.6min | 41 | 0 | $1.14 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 3.9min | 10 | 0 | $0.44 | powershell | ok |
| Directory Tree Sync | default | opus | 3.8min | 43 | 0 | $1.18 | python | ok |
| Directory Tree Sync | powershell | opus | 5.3min | 42 | 0 | $1.13 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 3.0min | 11 | 0 | $0.37 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus | 5.4min | 34 | 0 | $1.21 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 4.3min | 13 | 0 | $0.49 | powershell | ok |
| REST API Client | default | opus | 5.2min | 45 | 0 | $1.21 | python | ok |
| REST API Client | powershell | sonnet | 12.6min | 13 | 0 | $0.96 | powershell | ok |
| REST API Client | powershell-strict | opus | 5.1min | 19 | 0 | $0.94 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 9.2min | 14 | 0 | $0.99 | powershell | ok |
| Process Monitor | default | sonnet | 2.0min | 12 | 0 | $0.25 | python | ok |
| Process Monitor | powershell | opus | 5.4min | 39 | 0 | $1.21 | powershell | ok |
| Process Monitor | powershell | sonnet | 3.8min | 13 | 0 | $0.40 | powershell | ok |
| Process Monitor | powershell-strict | opus | 5.6min | 53 | 0 | $1.61 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 4.6min | 19 | 0 | $0.54 | powershell | ok |
| Config File Migrator | powershell | opus | 3.7min | 20 | 0 | $0.69 | powershell | ok |
| Config File Migrator | powershell | sonnet | 3.4min | 15 | 0 | $0.38 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 2.7min | 12 | 0 | $0.49 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet | 13.9min | 21 | 0 | $1.60 | powershell | ok |
| Batch File Renamer | default | sonnet | 2.3min | 8 | 0 | $0.22 | python | ok |
| Batch File Renamer | powershell | opus | 3.0min | 21 | 0 | $0.59 | powershell | ok |
| Batch File Renamer | powershell | sonnet | 1.4min | 6 | 0 | $0.16 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 4.5min | 35 | 0 | $1.05 | powershell | ok |
| Database Seed Script | default | sonnet | 3.9min | 1 | 0 | $0.00 |  | failed |
| Database Seed Script | powershell | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Database Seed Script | powershell-strict | sonnet | 3.6min | 1 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | default | opus | 2.3min | 24 | 0 | $0.54 | python | ok |
| Error Retry Pipeline | default | sonnet | 3.7min | 1 | 0 | $0.00 |  | failed |
| Error Retry Pipeline | powershell | opus | 3.8min | 34 | 0 | $0.93 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Multi-file Search and Replace | default | sonnet | 3.9min | 1 | 0 | $0.00 |  | failed |
| Multi-file Search and Replace | powershell | opus | 3.6min | 21 | 0 | $0.65 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 1.4min | 10 | 0 | $0.19 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 4.1min | 34 | 0 | $1.09 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Semantic Version Bumper | default | sonnet | 2.5min | 11 | 0 | $0.25 | python | ok |
| Semantic Version Bumper | powershell | opus | 3.6min | 27 | 0 | $0.77 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 2.7min | 16 | 0 | $0.33 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 5.8min | 52 | 0 | $1.57 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 5.3min | 5 | 0 | $0.15 | powershell | failed |
| PR Label Assigner | default | sonnet | 1.8min | 8 | 0 | $0.21 | python | ok |
| PR Label Assigner | powershell | opus | 3.1min | 23 | 0 | $0.61 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 3.7min | 10 | 0 | $0.38 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 4.0min | 37 | 0 | $1.03 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet | 3.3min | 12 | 0 | $0.35 | powershell | ok |
| Dependency License Checker | default | sonnet | 4.0min | 1 | 0 | $0.00 |  | failed |
| Dependency License Checker | powershell | sonnet | 2.6min | 11 | 0 | $0.36 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 9.5min | 18 | 0 | $0.97 | powershell | ok |
| Docker Image Tag Generator | default | opus | 2.7min | 30 | 0 | $0.67 | python | ok |
| Docker Image Tag Generator | powershell | opus | 3.5min | 32 | 0 | $0.84 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 2.9min | 9 | 0 | $0.31 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 5.0min | 44 | 0 | $1.28 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 2.5min | 13 | 0 | $0.33 | powershell | ok |
| Test Results Aggregator | powershell | opus | 4.3min | 33 | 0 | $0.95 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 5.0min | 15 | 0 | $0.55 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 4.0min | 24 | 0 | $0.95 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 11.5min | 20 | 0 | $1.42 | powershell | ok |
| Environment Matrix Generator | default | sonnet | 2.0min | 9 | 0 | $0.26 | python | ok |
| Environment Matrix Generator | powershell | opus | 2.3min | 18 | 0 | $0.54 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 2.8min | 13 | 0 | $0.36 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 5.4min | 16 | 0 | $0.62 | powershell | ok |
| Artifact Cleanup Script | default | opus | 4.4min | 34 | 0 | $0.98 | python | ok |
| Artifact Cleanup Script | powershell | opus | 4.9min | 30 | 0 | $1.16 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 2.6min | 9 | 0 | $0.35 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 3.6min | 15 | 0 | $0.49 | powershell | ok |
| Secret Rotation Validator | default | opus | 2.6min | 17 | 0 | $0.51 | python | ok |
| Secret Rotation Validator | default | sonnet | 1.5min | 11 | 0 | $0.22 | python | ok |
| Secret Rotation Validator | powershell | sonnet | 3.5min | 11 | 0 | $0.48 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 4.0min | 20 | 0 | $0.53 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 4.3min | 40 | 1 | $1.04 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 4.5min | 31 | 1 | $0.95 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 3.8min | 14 | 1 | $0.50 | powershell | ok |
| Directory Tree Sync | default | sonnet | 3.9min | 11 | 1 | $0.45 | python | ok |
| REST API Client | default | sonnet | 1.8min | 9 | 1 | $0.23 | python | ok |
| REST API Client | powershell | opus | 7.2min | 51 | 1 | $1.82 | powershell | ok |
| Process Monitor | default | opus | 3.3min | 40 | 1 | $1.00 | python | ok |
| Config File Migrator | default | opus | 2.8min | 14 | 1 | $0.59 | python | ok |
| Config File Migrator | default | sonnet | 3.4min | 18 | 1 | $0.47 | python | ok |
| Batch File Renamer | powershell-strict | sonnet | 3.7min | 16 | 1 | $0.50 | powershell | ok |
| Database Seed Script | default | opus | 4.3min | 36 | 1 | $1.04 | python | ok |
| Error Retry Pipeline | powershell-strict | opus | 9.7min | 0 | 1 | $0.00 | powershell | failed |
| PR Label Assigner | default | opus | 1.9min | 11 | 1 | $0.38 | python | ok |
| Dependency License Checker | powershell | opus | 5.8min | 45 | 1 | $1.37 | powershell | ok |
| Docker Image Tag Generator | default | sonnet | 1.8min | 10 | 1 | $0.23 | python | ok |
| Test Results Aggregator | default | opus | 2.3min | 15 | 1 | $0.51 | python | ok |
| Test Results Aggregator | default | sonnet | 4.0min | 20 | 1 | $0.49 | python | ok |
| Environment Matrix Generator | default | opus | 4.7min | 38 | 1 | $1.11 | python | ok |
| Artifact Cleanup Script | powershell-strict | opus | 5.5min | 37 | 1 | $1.37 | powershell | ok |
| Secret Rotation Validator | powershell | opus | 3.3min | 23 | 1 | $0.72 | powershell | ok |
| Batch File Renamer | default | opus | 2.8min | 30 | 2 | $0.81 | python | ok |
| Database Seed Script | powershell-strict | opus | 8.7min | 56 | 2 | $2.03 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 4.2min | 31 | 2 | $0.96 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus | 5.3min | 39 | 2 | $1.27 | powershell | ok |
| CSV Report Generator | default | sonnet | 6.3min | 1 | 3 | $0.71 | python | ok |
| Multi-file Search and Replace | default | opus | 3.1min | 25 | 3 | $0.70 | python | ok |
| Database Seed Script | powershell | opus | 5.8min | 42 | 4 | $1.32 | powershell | ok |
| Dependency License Checker | default | opus | 5.6min | 64 | 4 | $1.73 | python | ok |
| Dependency License Checker | powershell-strict | opus | 5.4min | 52 | 4 | $1.59 | powershell | ok |
| Artifact Cleanup Script | default | sonnet | 2.6min | 17 | 4 | $0.44 | python | ok |
| Semantic Version Bumper | default | opus | 4.8min | 47 | 5 | $1.23 | python | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Error Retry Pipeline | powershell-strict | opus | 9.7min | 0 | 1 | $0.00 | powershell | failed |
| CSV Report Generator | default | sonnet | 6.3min | 1 | 3 | $0.71 | python | ok |
| Database Seed Script | default | sonnet | 3.9min | 1 | 0 | $0.00 |  | failed |
| Database Seed Script | powershell | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Database Seed Script | powershell-strict | sonnet | 3.6min | 1 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | default | sonnet | 3.7min | 1 | 0 | $0.00 |  | failed |
| Error Retry Pipeline | powershell | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Multi-file Search and Replace | default | sonnet | 3.9min | 1 | 0 | $0.00 |  | failed |
| Multi-file Search and Replace | powershell-strict | sonnet | 3.8min | 1 | 0 | $0.00 | powershell | failed |
| Dependency License Checker | default | sonnet | 4.0min | 1 | 0 | $0.00 |  | failed |
| Semantic Version Bumper | powershell-strict | sonnet | 5.3min | 5 | 0 | $0.15 | powershell | failed |
| Batch File Renamer | powershell | sonnet | 1.4min | 6 | 0 | $0.16 | powershell | ok |
| CSV Report Generator | csharp-script | sonnet | 0.6min | 7 | 0 | $0.12 | csharp | ok |
| Batch File Renamer | default | sonnet | 2.3min | 8 | 0 | $0.22 | python | ok |
| PR Label Assigner | default | sonnet | 1.8min | 8 | 0 | $0.21 | python | ok |
| CSV Report Generator | powershell | sonnet | 2.1min | 9 | 0 | $0.31 | powershell | ok |
| Log File Analyzer | csharp-script | opus | 0.7min | 9 | 0 | $0.25 | csharp | ok |
| REST API Client | default | sonnet | 1.8min | 9 | 1 | $0.23 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 2.9min | 9 | 0 | $0.31 | powershell | ok |
| Environment Matrix Generator | default | sonnet | 2.0min | 9 | 0 | $0.26 | python | ok |
| Artifact Cleanup Script | powershell | sonnet | 2.6min | 9 | 0 | $0.35 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 3.9min | 10 | 0 | $0.44 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 1.4min | 10 | 0 | $0.19 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 3.7min | 10 | 0 | $0.38 | powershell | ok |
| Docker Image Tag Generator | default | sonnet | 1.8min | 10 | 1 | $0.23 | python | ok |
| Directory Tree Sync | default | sonnet | 3.9min | 11 | 1 | $0.45 | python | ok |
| Directory Tree Sync | powershell | sonnet | 3.0min | 11 | 0 | $0.37 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 2.5min | 11 | 0 | $0.25 | python | ok |
| PR Label Assigner | default | opus | 1.9min | 11 | 1 | $0.38 | python | ok |
| Dependency License Checker | powershell | sonnet | 2.6min | 11 | 0 | $0.36 | powershell | ok |
| Secret Rotation Validator | default | sonnet | 1.5min | 11 | 0 | $0.22 | python | ok |
| Secret Rotation Validator | powershell | sonnet | 3.5min | 11 | 0 | $0.48 | powershell | ok |
| CSV Report Generator | csharp-script | opus | 2.8min | 12 | 0 | $0.58 | csharp | ok |
| CSV Report Generator | default | opus | 1.7min | 12 | 0 | $0.38 | python | ok |
| Process Monitor | default | sonnet | 2.0min | 12 | 0 | $0.25 | python | ok |
| Config File Migrator | powershell-strict | opus | 2.7min | 12 | 0 | $0.49 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet | 3.3min | 12 | 0 | $0.35 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 4.3min | 13 | 0 | $0.49 | powershell | ok |
| REST API Client | powershell | sonnet | 12.6min | 13 | 0 | $0.96 | powershell | ok |
| Process Monitor | powershell | sonnet | 3.8min | 13 | 0 | $0.40 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 2.5min | 13 | 0 | $0.33 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 2.8min | 13 | 0 | $0.36 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 3.8min | 14 | 1 | $0.50 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 9.2min | 14 | 0 | $0.99 | powershell | ok |
| Config File Migrator | default | opus | 2.8min | 14 | 1 | $0.59 | python | ok |
| Config File Migrator | powershell | sonnet | 3.4min | 15 | 0 | $0.38 | powershell | ok |
| Test Results Aggregator | default | opus | 2.3min | 15 | 1 | $0.51 | python | ok |
| Test Results Aggregator | powershell | sonnet | 5.0min | 15 | 0 | $0.55 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 3.6min | 15 | 0 | $0.49 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 3.7min | 16 | 1 | $0.50 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 2.7min | 16 | 0 | $0.33 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 5.4min | 16 | 0 | $0.62 | powershell | ok |
| Artifact Cleanup Script | default | sonnet | 2.6min | 17 | 4 | $0.44 | python | ok |
| Secret Rotation Validator | default | opus | 2.6min | 17 | 0 | $0.51 | python | ok |
| Config File Migrator | default | sonnet | 3.4min | 18 | 1 | $0.47 | python | ok |
| Dependency License Checker | powershell-strict | sonnet | 9.5min | 18 | 0 | $0.97 | powershell | ok |
| Environment Matrix Generator | powershell | opus | 2.3min | 18 | 0 | $0.54 | powershell | ok |
| Log File Analyzer | default | sonnet | 2.9min | 19 | 0 | $0.48 | python | ok |
| REST API Client | powershell-strict | opus | 5.1min | 19 | 0 | $0.94 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 4.6min | 19 | 0 | $0.54 | powershell | ok |
| Config File Migrator | powershell | opus | 3.7min | 20 | 0 | $0.69 | powershell | ok |
| Test Results Aggregator | default | sonnet | 4.0min | 20 | 1 | $0.49 | python | ok |
| Test Results Aggregator | powershell-strict | sonnet | 11.5min | 20 | 0 | $1.42 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 4.0min | 20 | 0 | $0.53 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet | 13.9min | 21 | 0 | $1.60 | powershell | ok |
| Batch File Renamer | powershell | opus | 3.0min | 21 | 0 | $0.59 | powershell | ok |
| Multi-file Search and Replace | powershell | opus | 3.6min | 21 | 0 | $0.65 | powershell | ok |
| PR Label Assigner | powershell | opus | 3.1min | 23 | 0 | $0.61 | powershell | ok |
| Secret Rotation Validator | powershell | opus | 3.3min | 23 | 1 | $0.72 | powershell | ok |
| Error Retry Pipeline | default | opus | 2.3min | 24 | 0 | $0.54 | python | ok |
| Test Results Aggregator | powershell-strict | opus | 4.0min | 24 | 0 | $0.95 | powershell | ok |
| Multi-file Search and Replace | default | opus | 3.1min | 25 | 3 | $0.70 | python | ok |
| Semantic Version Bumper | powershell | opus | 3.6min | 27 | 0 | $0.77 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 6.5min | 29 | 0 | $0.97 | powershell | ok |
| Batch File Renamer | default | opus | 2.8min | 30 | 2 | $0.81 | python | ok |
| Docker Image Tag Generator | default | opus | 2.7min | 30 | 0 | $0.67 | python | ok |
| Artifact Cleanup Script | powershell | opus | 4.9min | 30 | 0 | $1.16 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 4.5min | 31 | 1 | $0.95 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 4.2min | 31 | 2 | $0.96 | powershell | ok |
| Docker Image Tag Generator | powershell | opus | 3.5min | 32 | 0 | $0.84 | powershell | ok |
| Test Results Aggregator | powershell | opus | 4.3min | 33 | 0 | $0.95 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus | 5.4min | 34 | 0 | $1.21 | powershell | ok |
| Error Retry Pipeline | powershell | opus | 3.8min | 34 | 0 | $0.93 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 4.1min | 34 | 0 | $1.09 | powershell | ok |
| Artifact Cleanup Script | default | opus | 4.4min | 34 | 0 | $0.98 | python | ok |
| Batch File Renamer | powershell-strict | opus | 4.5min | 35 | 0 | $1.05 | powershell | ok |
| Database Seed Script | default | opus | 4.3min | 36 | 1 | $1.04 | python | ok |
| CSV Report Generator | powershell | opus | 4.3min | 37 | 0 | $1.05 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 4.0min | 37 | 0 | $1.03 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus | 5.5min | 37 | 1 | $1.37 | powershell | ok |
| Environment Matrix Generator | default | opus | 4.7min | 38 | 1 | $1.11 | python | ok |
| Process Monitor | powershell | opus | 5.4min | 39 | 0 | $1.21 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus | 5.3min | 39 | 2 | $1.27 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 4.3min | 40 | 1 | $1.04 | powershell | ok |
| Process Monitor | default | opus | 3.3min | 40 | 1 | $1.00 | python | ok |
| Log File Analyzer | powershell | opus | 4.6min | 41 | 0 | $1.14 | powershell | ok |
| Directory Tree Sync | powershell | opus | 5.3min | 42 | 0 | $1.13 | powershell | ok |
| Database Seed Script | powershell | opus | 5.8min | 42 | 4 | $1.32 | powershell | ok |
| Log File Analyzer | default | opus | 4.2min | 43 | 0 | $1.18 | python | ok |
| Directory Tree Sync | default | opus | 3.8min | 43 | 0 | $1.18 | python | ok |
| Docker Image Tag Generator | powershell-strict | opus | 5.0min | 44 | 0 | $1.28 | powershell | ok |
| REST API Client | default | opus | 5.2min | 45 | 0 | $1.21 | python | ok |
| Dependency License Checker | powershell | opus | 5.8min | 45 | 1 | $1.37 | powershell | ok |
| Semantic Version Bumper | default | opus | 4.8min | 47 | 5 | $1.23 | python | ok |
| REST API Client | powershell | opus | 7.2min | 51 | 1 | $1.82 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 5.8min | 52 | 0 | $1.57 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 5.4min | 52 | 4 | $1.59 | powershell | ok |
| Process Monitor | powershell-strict | opus | 5.6min | 53 | 0 | $1.61 | powershell | ok |
| Database Seed Script | powershell-strict | opus | 8.7min | 56 | 2 | $2.03 | powershell | ok |
| Dependency License Checker | default | opus | 5.6min | 64 | 4 | $1.73 | python | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v2*