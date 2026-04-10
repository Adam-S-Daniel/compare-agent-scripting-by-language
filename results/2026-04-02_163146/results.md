# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-10 09:52:02 AM ET

**Status:** 144/144 runs completed, 0 remaining
**Total cost so far:** $436.67
**Total agent time so far:** 5098.1 min

## Observations

- **Fastest (avg):** default/sonnet — 16.7min, then powershell-strict/sonnet — 21.9min
- **Slowest (avg):** powershell-strict/opus — 52.8min, then csharp-script/opus — 40.2min
- **Cheapest (avg):** default/sonnet — $1.23, then powershell-strict/sonnet — $1.55
- **Most expensive (avg):** csharp-script/opus — $5.59, then powershell-strict/opus — $4.92

## Failed / Timed-Out Runs

| Task | Mode | Model | Duration | Reason | Lines | actionlint | act-result.txt |
|------|------|-------|----------|--------|-------|------------|----------------|
| CSV Report Generator | csharp-script | opus | 271.2min | exit_code=-1 | 165 | n/a | no |
| REST API Client | powershell | opus | 257.5min | exit_code=-1 | 629 | n/a | no |
| Config File Migrator | csharp-script | opus | 54.2min | exit_code=-1 | 1899 | n/a | no |
| Database Seed Script | csharp-script | sonnet | 28.1min | exit_code=-1 | 2013 | n/a | no |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | exit_code=-1 | 586 | n/a | no |

*5 run(s) excluded from averages below.*

## Comparison by Language/Model
*(averages exclude failed/timed-out runs)*

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| csharp-script | opus | 16 | 40.2min | 3.8min | 154.0 | 163 | $5.59 | $89.38 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 59.9 | 86 | $2.77 | $47.12 |
| default | opus | 18 | 30.8min | -18.0min | 149.4 | 148 | $3.99 | $71.84 |
| default | sonnet | 18 | 16.7min | 10.0min | 35.5 | 51 | $1.23 | $22.08 |
| powershell | opus | 17 | 30.1min | 0.9min | 101.4 | 112 | $3.65 | $61.98 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 46.9 | 63 | $1.63 | $29.38 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 134.1 | 145 | $4.92 | $88.48 |
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 32.5 | 48 | $1.55 | $26.42 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | sonnet | 18 | 16.7min | 10.0min | 35.5 | 51 | $1.23 | $22.08 |
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 32.5 | 48 | $1.55 | $26.42 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 46.9 | 63 | $1.63 | $29.38 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 59.9 | 86 | $2.77 | $47.12 |
| powershell | opus | 17 | 30.1min | 0.9min | 101.4 | 112 | $3.65 | $61.98 |
| default | opus | 18 | 30.8min | -18.0min | 149.4 | 148 | $3.99 | $71.84 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 134.1 | 145 | $4.92 | $88.48 |
| csharp-script | opus | 16 | 40.2min | 3.8min | 154.0 | 163 | $5.59 | $89.38 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | sonnet | 18 | 16.7min | 10.0min | 35.5 | 51 | $1.23 | $22.08 |
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 32.5 | 48 | $1.55 | $26.42 |
| powershell | opus | 17 | 30.1min | 0.9min | 101.4 | 112 | $3.65 | $61.98 |
| default | opus | 18 | 30.8min | -18.0min | 149.4 | 148 | $3.99 | $71.84 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 46.9 | 63 | $1.63 | $29.38 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 59.9 | 86 | $2.77 | $47.12 |
| csharp-script | opus | 16 | 40.2min | 3.8min | 154.0 | 163 | $5.59 | $89.38 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 134.1 | 145 | $4.92 | $88.48 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 18 | 30.8min | -18.0min | 149.4 | 148 | $3.99 | $71.84 |
| powershell | opus | 17 | 30.1min | 0.9min | 101.4 | 112 | $3.65 | $61.98 |
| csharp-script | opus | 16 | 40.2min | 3.8min | 154.0 | 163 | $5.59 | $89.38 |
| default | sonnet | 18 | 16.7min | 10.0min | 35.5 | 51 | $1.23 | $22.08 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 134.1 | 145 | $4.92 | $88.48 |
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 32.5 | 48 | $1.55 | $26.42 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 59.9 | 86 | $2.77 | $47.12 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 46.9 | 63 | $1.63 | $29.38 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 32.5 | 48 | $1.55 | $26.42 |
| default | sonnet | 18 | 16.7min | 10.0min | 35.5 | 51 | $1.23 | $22.08 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 46.9 | 63 | $1.63 | $29.38 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 59.9 | 86 | $2.77 | $47.12 |
| powershell | opus | 17 | 30.1min | 0.9min | 101.4 | 112 | $3.65 | $61.98 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 134.1 | 145 | $4.92 | $88.48 |
| default | opus | 18 | 30.8min | -18.0min | 149.4 | 148 | $3.99 | $71.84 |
| csharp-script | opus | 16 | 40.2min | 3.8min | 154.0 | 163 | $5.59 | $89.38 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 32.5 | 48 | $1.55 | $26.42 |
| default | sonnet | 18 | 16.7min | 10.0min | 35.5 | 51 | $1.23 | $22.08 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 46.9 | 63 | $1.63 | $29.38 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 59.9 | 86 | $2.77 | $47.12 |
| powershell | opus | 17 | 30.1min | 0.9min | 101.4 | 112 | $3.65 | $61.98 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 134.1 | 145 | $4.92 | $88.48 |
| default | opus | 18 | 30.8min | -18.0min | 149.4 | 148 | $3.99 | $71.84 |
| csharp-script | opus | 16 | 40.2min | 3.8min | 154.0 | 163 | $5.59 | $89.38 |

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
| permission-denial-loops | csharp-script | opus | 16 | 349.2min | 6.8% | $87.42 | 20.02% |
| permission-denial-loops | csharp-script | sonnet | 17 | 138.8min | 2.7% | $21.10 | 4.83% |
| permission-denial-loops | default | opus | 18 | 439.2min | 8.6% | $99.42 | 22.77% |
| permission-denial-loops | default | sonnet | 18 | 93.7min | 1.8% | $12.17 | 2.79% |
| permission-denial-loops | powershell | opus | 17 | 280.0min | 5.5% | $65.92 | 15.10% |
| permission-denial-loops | powershell | sonnet | 18 | 126.0min | 2.5% | $19.18 | 4.39% |
| permission-denial-loops | powershell-strict | opus | 18 | 391.5min | 7.7% | $101.79 | 23.31% |
| permission-denial-loops | powershell-strict | sonnet | 17 | 81.3min | 1.6% | $9.45 | 2.16% |
| repeated-test-reruns | csharp-script | opus | 24 | 55.7min | 1.1% | $16.57 | 3.79% |
| repeated-test-reruns | csharp-script | sonnet | 15 | 18.0min | 0.4% | $2.60 | 0.59% |
| repeated-test-reruns | default | opus | 50 | 439.7min | 8.6% | $107.75 | 24.68% |
| repeated-test-reruns | default | sonnet | 23 | 27.7min | 0.5% | $3.54 | 0.81% |
| repeated-test-reruns | powershell | opus | 48 | 215.3min | 4.2% | $50.76 | 11.62% |
| repeated-test-reruns | powershell | sonnet | 12 | 21.3min | 0.4% | $3.68 | 0.84% |
| repeated-test-reruns | powershell-strict | opus | 49 | 302.7min | 5.9% | $73.02 | 16.72% |
| repeated-test-reruns | powershell-strict | sonnet | 6 | 7.0min | 0.1% | $0.64 | 0.15% |
| dotnet-install-loop | csharp-script | opus | 16 | 178.6min | 3.5% | $40.93 | 9.37% |
| dotnet-install-loop | csharp-script | sonnet | 13 | 44.2min | 0.9% | $7.17 | 1.64% |
| pwsh-invoked-from-bash | powershell | sonnet | 1 | 7.7min | 0.2% | $1.46 | 0.33% |
| fixture-rework | default | opus | 1 | 0.5min | 0.0% | $0.03 | 0.01% |
| fixture-rework | default | sonnet | 1 | 0.8min | 0.0% | $0.15 | 0.03% |
| fixture-rework | powershell | sonnet | 1 | 0.5min | 0.0% | $0.08 | 0.02% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | opus | 1 | 0.5min | 0.0% | $0.03 | 0.01% |
| fixture-rework | powershell | sonnet | 1 | 0.5min | 0.0% | $0.08 | 0.02% |
| fixture-rework | default | sonnet | 1 | 0.8min | 0.0% | $0.15 | 0.03% |
| repeated-test-reruns | powershell-strict | sonnet | 6 | 7.0min | 0.1% | $0.64 | 0.15% |
| pwsh-invoked-from-bash | powershell | sonnet | 1 | 7.7min | 0.2% | $1.46 | 0.33% |
| repeated-test-reruns | csharp-script | sonnet | 15 | 18.0min | 0.4% | $2.60 | 0.59% |
| repeated-test-reruns | powershell | sonnet | 12 | 21.3min | 0.4% | $3.68 | 0.84% |
| repeated-test-reruns | default | sonnet | 23 | 27.7min | 0.5% | $3.54 | 0.81% |
| dotnet-install-loop | csharp-script | sonnet | 13 | 44.2min | 0.9% | $7.17 | 1.64% |
| repeated-test-reruns | csharp-script | opus | 24 | 55.7min | 1.1% | $16.57 | 3.79% |
| permission-denial-loops | powershell-strict | sonnet | 17 | 81.3min | 1.6% | $9.45 | 2.16% |
| permission-denial-loops | default | sonnet | 18 | 93.7min | 1.8% | $12.17 | 2.79% |
| permission-denial-loops | powershell | sonnet | 18 | 126.0min | 2.5% | $19.18 | 4.39% |
| permission-denial-loops | csharp-script | sonnet | 17 | 138.8min | 2.7% | $21.10 | 4.83% |
| dotnet-install-loop | csharp-script | opus | 16 | 178.6min | 3.5% | $40.93 | 9.37% |
| repeated-test-reruns | powershell | opus | 48 | 215.3min | 4.2% | $50.76 | 11.62% |
| permission-denial-loops | powershell | opus | 17 | 280.0min | 5.5% | $65.92 | 15.10% |
| repeated-test-reruns | powershell-strict | opus | 49 | 302.7min | 5.9% | $73.02 | 16.72% |
| permission-denial-loops | csharp-script | opus | 16 | 349.2min | 6.8% | $87.42 | 20.02% |
| permission-denial-loops | powershell-strict | opus | 18 | 391.5min | 7.7% | $101.79 | 23.31% |
| permission-denial-loops | default | opus | 18 | 439.2min | 8.6% | $99.42 | 22.77% |
| repeated-test-reruns | default | opus | 50 | 439.7min | 8.6% | $107.75 | 24.68% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | default | opus | 1 | 0.5min | 0.0% | $0.03 | 0.01% |
| fixture-rework | powershell | sonnet | 1 | 0.5min | 0.0% | $0.08 | 0.02% |
| fixture-rework | default | sonnet | 1 | 0.8min | 0.0% | $0.15 | 0.03% |
| repeated-test-reruns | powershell-strict | sonnet | 6 | 7.0min | 0.1% | $0.64 | 0.15% |
| pwsh-invoked-from-bash | powershell | sonnet | 1 | 7.7min | 0.2% | $1.46 | 0.33% |
| repeated-test-reruns | csharp-script | sonnet | 15 | 18.0min | 0.4% | $2.60 | 0.59% |
| repeated-test-reruns | default | sonnet | 23 | 27.7min | 0.5% | $3.54 | 0.81% |
| repeated-test-reruns | powershell | sonnet | 12 | 21.3min | 0.4% | $3.68 | 0.84% |
| dotnet-install-loop | csharp-script | sonnet | 13 | 44.2min | 0.9% | $7.17 | 1.64% |
| permission-denial-loops | powershell-strict | sonnet | 17 | 81.3min | 1.6% | $9.45 | 2.16% |
| permission-denial-loops | default | sonnet | 18 | 93.7min | 1.8% | $12.17 | 2.79% |
| repeated-test-reruns | csharp-script | opus | 24 | 55.7min | 1.1% | $16.57 | 3.79% |
| permission-denial-loops | powershell | sonnet | 18 | 126.0min | 2.5% | $19.18 | 4.39% |
| permission-denial-loops | csharp-script | sonnet | 17 | 138.8min | 2.7% | $21.10 | 4.83% |
| dotnet-install-loop | csharp-script | opus | 16 | 178.6min | 3.5% | $40.93 | 9.37% |
| repeated-test-reruns | powershell | opus | 48 | 215.3min | 4.2% | $50.76 | 11.62% |
| permission-denial-loops | powershell | opus | 17 | 280.0min | 5.5% | $65.92 | 15.10% |
| repeated-test-reruns | powershell-strict | opus | 49 | 302.7min | 5.9% | $73.02 | 16.72% |
| permission-denial-loops | csharp-script | opus | 16 | 349.2min | 6.8% | $87.42 | 20.02% |
| permission-denial-loops | default | opus | 18 | 439.2min | 8.6% | $99.42 | 22.77% |
| permission-denial-loops | powershell-strict | opus | 18 | 391.5min | 7.7% | $101.79 | 23.31% |
| repeated-test-reruns | default | opus | 50 | 439.7min | 8.6% | $107.75 | 24.68% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| pwsh-invoked-from-bash | powershell | sonnet | 1 | 7.7min | 0.2% | $1.46 | 0.33% |
| fixture-rework | default | opus | 1 | 0.5min | 0.0% | $0.03 | 0.01% |
| fixture-rework | default | sonnet | 1 | 0.8min | 0.0% | $0.15 | 0.03% |
| fixture-rework | powershell | sonnet | 1 | 0.5min | 0.0% | $0.08 | 0.02% |
| repeated-test-reruns | powershell-strict | sonnet | 6 | 7.0min | 0.1% | $0.64 | 0.15% |
| repeated-test-reruns | powershell | sonnet | 12 | 21.3min | 0.4% | $3.68 | 0.84% |
| dotnet-install-loop | csharp-script | sonnet | 13 | 44.2min | 0.9% | $7.17 | 1.64% |
| repeated-test-reruns | csharp-script | sonnet | 15 | 18.0min | 0.4% | $2.60 | 0.59% |
| permission-denial-loops | csharp-script | opus | 16 | 349.2min | 6.8% | $87.42 | 20.02% |
| dotnet-install-loop | csharp-script | opus | 16 | 178.6min | 3.5% | $40.93 | 9.37% |
| permission-denial-loops | csharp-script | sonnet | 17 | 138.8min | 2.7% | $21.10 | 4.83% |
| permission-denial-loops | powershell | opus | 17 | 280.0min | 5.5% | $65.92 | 15.10% |
| permission-denial-loops | powershell-strict | sonnet | 17 | 81.3min | 1.6% | $9.45 | 2.16% |
| permission-denial-loops | default | opus | 18 | 439.2min | 8.6% | $99.42 | 22.77% |
| permission-denial-loops | default | sonnet | 18 | 93.7min | 1.8% | $12.17 | 2.79% |
| permission-denial-loops | powershell | sonnet | 18 | 126.0min | 2.5% | $19.18 | 4.39% |
| permission-denial-loops | powershell-strict | opus | 18 | 391.5min | 7.7% | $101.79 | 23.31% |
| repeated-test-reruns | default | sonnet | 23 | 27.7min | 0.5% | $3.54 | 0.81% |
| repeated-test-reruns | csharp-script | opus | 24 | 55.7min | 1.1% | $16.57 | 3.79% |
| repeated-test-reruns | powershell | opus | 48 | 215.3min | 4.2% | $50.76 | 11.62% |
| repeated-test-reruns | powershell-strict | opus | 49 | 302.7min | 5.9% | $73.02 | 16.72% |
| repeated-test-reruns | default | opus | 50 | 439.7min | 8.6% | $107.75 | 24.68% |

</details>

#### Trap Descriptions

- **dotnet-install-loop**: Agent stuck in loop trying to install/verify .NET SDK, blocked by CLI sandbox.
- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
- **permission-denial-loops**: CLI sandbox blocked commands and agent retried instead of adapting (v1 harness issue).
- **pwsh-invoked-from-bash**: Agent used `pwsh -Command`/`-File` from bash `run:` steps instead of `shell: pwsh`, causing cross-shell debugging (parse errors, quoting issues, scope problems, late pwsh discovery in act).
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
| csharp-script | opus | 18 | 56 | 583.4min | 11.4% | $144.91 | 33.19% |
| csharp-script | sonnet | 18 | 45 | 201.0min | 3.9% | $30.87 | 7.07% |
| default | opus | 18 | 69 | 879.3min | 17.2% | $207.20 | 47.45% |
| default | sonnet | 18 | 42 | 122.1min | 2.4% | $15.86 | 3.63% |
| powershell | opus | 18 | 65 | 495.3min | 9.7% | $116.68 | 26.72% |
| powershell | sonnet | 18 | 32 | 155.5min | 3.1% | $24.40 | 5.59% |
| powershell-strict | opus | 18 | 67 | 694.2min | 13.6% | $174.81 | 40.03% |
| powershell-strict | sonnet | 18 | 23 | 88.3min | 1.7% | $10.09 | 2.31% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| powershell-strict | sonnet | 18 | 23 | 88.3min | 1.7% | $10.09 | 2.31% |
| default | sonnet | 18 | 42 | 122.1min | 2.4% | $15.86 | 3.63% |
| powershell | sonnet | 18 | 32 | 155.5min | 3.1% | $24.40 | 5.59% |
| csharp-script | sonnet | 18 | 45 | 201.0min | 3.9% | $30.87 | 7.07% |
| powershell | opus | 18 | 65 | 495.3min | 9.7% | $116.68 | 26.72% |
| csharp-script | opus | 18 | 56 | 583.4min | 11.4% | $144.91 | 33.19% |
| powershell-strict | opus | 18 | 67 | 694.2min | 13.6% | $174.81 | 40.03% |
| default | opus | 18 | 69 | 879.3min | 17.2% | $207.20 | 47.45% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| powershell-strict | sonnet | 18 | 23 | 88.3min | 1.7% | $10.09 | 2.31% |
| default | sonnet | 18 | 42 | 122.1min | 2.4% | $15.86 | 3.63% |
| powershell | sonnet | 18 | 32 | 155.5min | 3.1% | $24.40 | 5.59% |
| csharp-script | sonnet | 18 | 45 | 201.0min | 3.9% | $30.87 | 7.07% |
| powershell | opus | 18 | 65 | 495.3min | 9.7% | $116.68 | 26.72% |
| csharp-script | opus | 18 | 56 | 583.4min | 11.4% | $144.91 | 33.19% |
| powershell-strict | opus | 18 | 67 | 694.2min | 13.6% | $174.81 | 40.03% |
| default | opus | 18 | 69 | 879.3min | 17.2% | $207.20 | 47.45% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 125 | $11.01 | 2.52% |
| Miss | 14 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| csharp-script | opus | 0.0 | 0.0 | 0.0 | 0.00 |
| csharp-script | sonnet | 0.0 | 0.0 | 0.0 | 0.32 |
| default | opus | 32.6 | 54.9 | 1.7 | 1.27 |
| default | sonnet | 31.7 | 55.8 | 1.8 | 1.30 |
| powershell | opus | 39.1 | 66.8 | 1.7 | 38.36 |
| powershell | sonnet | 25.7 | 45.3 | 1.8 | 2.47 |
| powershell-strict | opus | 37.5 | 71.0 | 1.9 | 76.19 |
| powershell-strict | sonnet | 27.0 | 48.9 | 1.8 | 13.65 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell | opus | 39.1 | 66.8 | 1.7 | 38.36 |
| powershell-strict | opus | 37.5 | 71.0 | 1.9 | 76.19 |
| default | opus | 32.6 | 54.9 | 1.7 | 1.27 |
| default | sonnet | 31.7 | 55.8 | 1.8 | 1.30 |
| powershell-strict | sonnet | 27.0 | 48.9 | 1.8 | 13.65 |
| powershell | sonnet | 25.7 | 45.3 | 1.8 | 2.47 |
| csharp-script | opus | 0.0 | 0.0 | 0.0 | 0.00 |
| csharp-script | sonnet | 0.0 | 0.0 | 0.0 | 0.32 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-strict | opus | 37.5 | 71.0 | 1.9 | 76.19 |
| powershell | opus | 39.1 | 66.8 | 1.7 | 38.36 |
| default | sonnet | 31.7 | 55.8 | 1.8 | 1.30 |
| default | opus | 32.6 | 54.9 | 1.7 | 1.27 |
| powershell-strict | sonnet | 27.0 | 48.9 | 1.8 | 13.65 |
| powershell | sonnet | 25.7 | 45.3 | 1.8 | 2.47 |
| csharp-script | opus | 0.0 | 0.0 | 0.0 | 0.00 |
| csharp-script | sonnet | 0.0 | 0.0 | 0.0 | 0.32 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-strict | opus | 37.5 | 71.0 | 1.9 | 76.19 |
| powershell | opus | 39.1 | 66.8 | 1.7 | 38.36 |
| powershell-strict | sonnet | 27.0 | 48.9 | 1.8 | 13.65 |
| powershell | sonnet | 25.7 | 45.3 | 1.8 | 2.47 |
| default | sonnet | 31.7 | 55.8 | 1.8 | 1.30 |
| default | opus | 32.6 | 54.9 | 1.7 | 1.27 |
| csharp-script | sonnet | 0.0 | 0.0 | 0.0 | 0.32 |
| csharp-script | opus | 0.0 | 0.0 | 0.0 | 0.00 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Mode | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| CSV Report Generator | csharp-script | opus | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| CSV Report Generator | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| CSV Report Generator | default | opus | 29 | 40 | 1.4 | 203 | 154 | 1.32 |
| CSV Report Generator | default | sonnet | 18 | 34 | 1.9 | 279 | 207 | 1.35 |
| CSV Report Generator | powershell | opus | 36 | 47 | 1.3 | 289 | 177 | 1.63 |
| CSV Report Generator | powershell | sonnet | 17 | 27 | 1.6 | 180 | 215 | 0.84 |
| CSV Report Generator | powershell-strict | opus | 25 | 50 | 2.0 | 270 | 38 | 7.11 |
| CSV Report Generator | powershell-strict | sonnet | 24 | 39 | 1.6 | 226 | 66 | 3.42 |
| Log File Analyzer | csharp-script | opus | 0 | 0 | 0.0 | 0 | 30 | 0.00 |
| Log File Analyzer | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 64 | 0.00 |
| Log File Analyzer | default | opus | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Log File Analyzer | default | sonnet | 64 | 122 | 1.9 | 778 | 372 | 2.09 |
| Log File Analyzer | powershell | opus | 33 | 55 | 1.7 | 294 | 291 | 1.01 |
| Log File Analyzer | powershell | sonnet | 34 | 57 | 1.7 | 365 | 373 | 0.98 |
| Log File Analyzer | powershell-strict | opus | 28 | 73 | 2.6 | 344 | 54 | 6.37 |
| Log File Analyzer | powershell-strict | sonnet | 44 | 66 | 1.5 | 357 | 52 | 6.87 |
| Directory Tree Sync | csharp-script | opus | 0 | 0 | 0.0 | 0 | 24 | 0.00 |
| Directory Tree Sync | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 24 | 0.00 |
| Directory Tree Sync | default | opus | 28 | 52 | 1.9 | 414 | 245 | 1.69 |
| Directory Tree Sync | default | sonnet | 34 | 51 | 1.5 | 427 | 252 | 1.69 |
| Directory Tree Sync | powershell | opus | 26 | 51 | 2.0 | 481 | 275 | 1.75 |
| Directory Tree Sync | powershell | sonnet | 26 | 45 | 1.7 | 371 | 277 | 1.34 |
| Directory Tree Sync | powershell-strict | opus | 29 | 97 | 3.3 | 522 | 4 | 130.50 |
| Directory Tree Sync | powershell-strict | sonnet | 28 | 47 | 1.7 | 457 | 329 | 1.39 |
| REST API Client | csharp-script | opus | 0 | 0 | 0.0 | 0 | 40 | 0.00 |
| REST API Client | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| REST API Client | default | opus | 25 | 51 | 2.0 | 366 | 210 | 1.74 |
| REST API Client | default | sonnet | 26 | 40 | 1.5 | 418 | 276 | 1.51 |
| REST API Client | powershell | opus | 21 | 23 | 1.1 | 373 | 3 | 124.33 |
| REST API Client | powershell | sonnet | 26 | 28 | 1.1 | 373 | 322 | 1.16 |
| REST API Client | powershell-strict | opus | 40 | 50 | 1.2 | 638 | 53 | 12.04 |
| REST API Client | powershell-strict | sonnet | 21 | 47 | 2.2 | 381 | 24 | 15.88 |
| Process Monitor | csharp-script | opus | 0 | 0 | 0.0 | 0 | 23 | 0.00 |
| Process Monitor | csharp-script | sonnet | 0 | 0 | 0.0 | 86 | 0 | 0.00 |
| Process Monitor | default | opus | 31 | 43 | 1.4 | 320 | 260 | 1.23 |
| Process Monitor | default | sonnet | 23 | 51 | 2.2 | 285 | 263 | 1.08 |
| Process Monitor | powershell | opus | 37 | 66 | 1.8 | 379 | 1 | 379.00 |
| Process Monitor | powershell | sonnet | 17 | 44 | 2.6 | 214 | 239 | 0.90 |
| Process Monitor | powershell-strict | opus | 40 | 75 | 1.9 | 417 | 0 | 0.00 |
| Process Monitor | powershell-strict | sonnet | 28 | 50 | 1.8 | 310 | 33 | 9.39 |
| Config File Migrator | csharp-script | opus | 0 | 0 | 0.0 | 0 | 58 | 0.00 |
| Config File Migrator | csharp-script | sonnet | 0 | 0 | 0.0 | 81 | 0 | 0.00 |
| Config File Migrator | default | opus | 43 | 90 | 2.1 | 510 | 435 | 1.17 |
| Config File Migrator | default | sonnet | 42 | 68 | 1.6 | 487 | 383 | 1.27 |
| Config File Migrator | powershell | opus | 67 | 102 | 1.5 | 647 | 329 | 1.97 |
| Config File Migrator | powershell | sonnet | 33 | 72 | 2.2 | 548 | 470 | 1.17 |
| Config File Migrator | powershell-strict | opus | 78 | 133 | 1.7 | 624 | 3 | 208.00 |
| Config File Migrator | powershell-strict | sonnet | 28 | 51 | 1.8 | 326 | 25 | 13.04 |
| Batch File Renamer | csharp-script | opus | 0 | 0 | 0.0 | 0 | 42 | 0.00 |
| Batch File Renamer | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Batch File Renamer | default | opus | 31 | 45 | 1.5 | 369 | 344 | 1.07 |
| Batch File Renamer | default | sonnet | 22 | 44 | 2.0 | 328 | 221 | 1.48 |
| Batch File Renamer | powershell | opus | 34 | 94 | 2.8 | 571 | 329 | 1.74 |
| Batch File Renamer | powershell | sonnet | 18 | 34 | 1.9 | 243 | 208 | 1.17 |
| Batch File Renamer | powershell-strict | opus | 23 | 50 | 2.2 | 375 | 0 | 0.00 |
| Batch File Renamer | powershell-strict | sonnet | 18 | 50 | 2.8 | 323 | 17 | 19.00 |
| Database Seed Script | csharp-script | opus | 0 | 0 | 0.0 | 0 | 19 | 0.00 |
| Database Seed Script | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 60 | 0.00 |
| Database Seed Script | default | opus | 50 | 75 | 1.5 | 477 | 366 | 1.30 |
| Database Seed Script | default | sonnet | 30 | 51 | 1.7 | 341 | 388 | 0.88 |
| Database Seed Script | powershell | opus | 70 | 120 | 1.7 | 544 | 569 | 0.96 |
| Database Seed Script | powershell | sonnet | 27 | 65 | 2.4 | 315 | 493 | 0.64 |
| Database Seed Script | powershell-strict | opus | 47 | 95 | 2.0 | 449 | 30 | 14.97 |
| Database Seed Script | powershell-strict | sonnet | 46 | 80 | 1.7 | 454 | 137 | 3.31 |
| Error Retry Pipeline | csharp-script | opus | 0 | 0 | 0.0 | 0 | 111 | 0.00 |
| Error Retry Pipeline | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Error Retry Pipeline | default | opus | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Error Retry Pipeline | default | sonnet | 23 | 45 | 2.0 | 305 | 328 | 0.93 |
| Error Retry Pipeline | powershell | opus | 25 | 89 | 3.6 | 420 | 245 | 1.71 |
| Error Retry Pipeline | powershell | sonnet | 21 | 42 | 2.0 | 232 | 9 | 25.78 |
| Error Retry Pipeline | powershell-strict | opus | 35 | 93 | 2.7 | 546 | 2 | 273.00 |
| Error Retry Pipeline | powershell-strict | sonnet | 17 | 45 | 2.6 | 208 | 0 | 0.00 |
| Multi-file Search and Replace | csharp-script | opus | 0 | 0 | 0.0 | 0 | 39 | 0.00 |
| Multi-file Search and Replace | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 34 | 0.00 |
| Multi-file Search and Replace | default | opus | 38 | 65 | 1.7 | 429 | 227 | 1.89 |
| Multi-file Search and Replace | default | sonnet | 39 | 75 | 1.9 | 411 | 375 | 1.10 |
| Multi-file Search and Replace | powershell | opus | 38 | 56 | 1.5 | 381 | 6 | 63.50 |
| Multi-file Search and Replace | powershell | sonnet | 19 | 29 | 1.5 | 261 | 198 | 1.32 |
| Multi-file Search and Replace | powershell-strict | opus | 14 | 38 | 2.7 | 251 | 242 | 1.04 |
| Multi-file Search and Replace | powershell-strict | sonnet | 36 | 70 | 1.9 | 565 | 355 | 1.59 |
| Semantic Version Bumper | csharp-script | opus | 0 | 0 | 0.0 | 0 | 18 | 0.00 |
| Semantic Version Bumper | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Semantic Version Bumper | default | opus | 53 | 72 | 1.4 | 429 | 395 | 1.09 |
| Semantic Version Bumper | default | sonnet | 35 | 35 | 1.0 | 267 | 354 | 0.75 |
| Semantic Version Bumper | powershell | opus | 54 | 69 | 1.3 | 431 | 0 | 0.00 |
| Semantic Version Bumper | powershell | sonnet | 33 | 46 | 1.4 | 329 | 263 | 1.25 |
| Semantic Version Bumper | powershell-strict | opus | 34 | 62 | 1.8 | 393 | 5 | 78.60 |
| Semantic Version Bumper | powershell-strict | sonnet | 42 | 57 | 1.4 | 389 | 349 | 1.11 |
| PR Label Assigner | csharp-script | opus | 0 | 0 | 0.0 | 0 | 32 | 0.00 |
| PR Label Assigner | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 35 | 0.00 |
| PR Label Assigner | default | opus | 28 | 39 | 1.4 | 306 | 211 | 1.45 |
| PR Label Assigner | default | sonnet | 22 | 28 | 1.3 | 337 | 193 | 1.75 |
| PR Label Assigner | powershell | opus | 31 | 56 | 1.8 | 342 | 263 | 1.30 |
| PR Label Assigner | powershell | sonnet | 39 | 61 | 1.6 | 286 | 168 | 1.70 |
| PR Label Assigner | powershell-strict | opus | 35 | 59 | 1.7 | 395 | 275 | 1.44 |
| PR Label Assigner | powershell-strict | sonnet | 28 | 42 | 1.5 | 239 | 141 | 1.70 |
| Dependency License Checker | csharp-script | opus | 0 | 0 | 0.0 | 0 | 23 | 0.00 |
| Dependency License Checker | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 92 | 0.00 |
| Dependency License Checker | default | opus | 37 | 71 | 1.9 | 531 | 358 | 1.48 |
| Dependency License Checker | default | sonnet | 31 | 55 | 1.8 | 384 | 291 | 1.32 |
| Dependency License Checker | powershell | opus | 36 | 62 | 1.7 | 482 | 361 | 1.34 |
| Dependency License Checker | powershell | sonnet | 22 | 43 | 2.0 | 258 | 270 | 0.96 |
| Dependency License Checker | powershell-strict | opus | 37 | 71 | 1.9 | 497 | 6 | 82.83 |
| Dependency License Checker | powershell-strict | sonnet | 0 | 0 | 0.0 | 16 | 0 | 0.00 |
| Docker Image Tag Generator | csharp-script | opus | 0 | 0 | 0.0 | 0 | 6 | 0.00 |
| Docker Image Tag Generator | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 42 | 0.00 |
| Docker Image Tag Generator | default | opus | 33 | 39 | 1.2 | 259 | 141 | 1.84 |
| Docker Image Tag Generator | default | sonnet | 17 | 20 | 1.2 | 142 | 155 | 0.92 |
| Docker Image Tag Generator | powershell | opus | 39 | 50 | 1.3 | 270 | 151 | 1.79 |
| Docker Image Tag Generator | powershell | sonnet | 20 | 23 | 1.1 | 155 | 129 | 1.20 |
| Docker Image Tag Generator | powershell-strict | opus | 26 | 36 | 1.4 | 305 | 173 | 1.76 |
| Docker Image Tag Generator | powershell-strict | sonnet | 23 | 28 | 1.2 | 357 | 71 | 5.03 |
| Test Results Aggregator | csharp-script | opus | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Test Results Aggregator | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Test Results Aggregator | default | opus | 41 | 62 | 1.5 | 375 | 351 | 1.07 |
| Test Results Aggregator | default | sonnet | 52 | 120 | 2.3 | 710 | 471 | 1.51 |
| Test Results Aggregator | powershell | opus | 48 | 68 | 1.4 | 414 | 4 | 103.50 |
| Test Results Aggregator | powershell | sonnet | 40 | 68 | 1.7 | 372 | 406 | 0.92 |
| Test Results Aggregator | powershell-strict | opus | 56 | 70 | 1.2 | 454 | 5 | 90.80 |
| Test Results Aggregator | powershell-strict | sonnet | 14 | 45 | 3.2 | 247 | 3 | 82.33 |
| Environment Matrix Generator | csharp-script | opus | 0 | 0 | 0.0 | 0 | 23 | 0.00 |
| Environment Matrix Generator | csharp-script | sonnet | 0 | 0 | 0.0 | 30 | 0 | 0.00 |
| Environment Matrix Generator | default | opus | 30 | 56 | 1.9 | 427 | 270 | 1.58 |
| Environment Matrix Generator | default | sonnet | 46 | 66 | 1.4 | 576 | 349 | 1.65 |
| Environment Matrix Generator | powershell | opus | 44 | 74 | 1.7 | 672 | 259 | 2.59 |
| Environment Matrix Generator | powershell | sonnet | 19 | 36 | 1.9 | 294 | 222 | 1.32 |
| Environment Matrix Generator | powershell-strict | opus | 27 | 47 | 1.7 | 493 | 372 | 1.33 |
| Environment Matrix Generator | powershell-strict | sonnet | 24 | 36 | 1.5 | 323 | 17 | 19.00 |
| Artifact Cleanup Script | csharp-script | opus | 0 | 0 | 0.0 | 0 | 3 | 0.00 |
| Artifact Cleanup Script | csharp-script | sonnet | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Artifact Cleanup Script | default | opus | 32 | 71 | 2.2 | 430 | 396 | 1.09 |
| Artifact Cleanup Script | default | sonnet | 21 | 50 | 2.4 | 306 | 248 | 1.23 |
| Artifact Cleanup Script | powershell | opus | 34 | 81 | 2.4 | 440 | 344 | 1.28 |
| Artifact Cleanup Script | powershell | sonnet | 25 | 43 | 1.7 | 318 | 409 | 0.78 |
| Artifact Cleanup Script | powershell-strict | opus | 34 | 73 | 2.1 | 653 | 3 | 217.67 |
| Artifact Cleanup Script | powershell-strict | sonnet | 35 | 74 | 2.1 | 524 | 9 | 58.22 |
| Secret Rotation Validator | csharp-script | opus | 0 | 0 | 0.0 | 0 | 8 | 0.00 |
| Secret Rotation Validator | csharp-script | sonnet | 0 | 0 | 0.0 | 34 | 6 | 5.67 |
| Secret Rotation Validator | default | opus | 58 | 118 | 2.0 | 766 | 418 | 1.83 |
| Secret Rotation Validator | default | sonnet | 26 | 50 | 1.9 | 282 | 304 | 0.93 |
| Secret Rotation Validator | powershell | opus | 30 | 40 | 1.3 | 328 | 328 | 1.00 |
| Secret Rotation Validator | powershell | sonnet | 27 | 53 | 2.0 | 435 | 408 | 1.07 |
| Secret Rotation Validator | powershell-strict | opus | 67 | 106 | 1.6 | 732 | 3 | 244.00 |
| Secret Rotation Validator | powershell-strict | sonnet | 30 | 53 | 1.8 | 441 | 101 | 4.37 |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 0 | $0.00 | csharp | failed |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 26 | $1.13 | csharp | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 225 | $4.92 | python | ok |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 25 | $0.65 | python | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 89 | $3.05 | powershell | ok |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 27 | $0.97 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 176 | $5.79 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 41 | $1.75 | powershell | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 193 | $8.66 | csharp | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 73 | $4.11 | csharp | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 205 | $5.43 | javascript | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 48 | $1.84 | python | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 105 | $3.88 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 51 | $1.78 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 134 | $5.44 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 22 | $1.37 | powershell | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 205 | $7.54 | csharp | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 49 | $2.42 | csharp | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 107 | $3.24 | python | ok |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 9 | $0.42 | python | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 91 | $2.97 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 41 | $1.54 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 140 | $4.71 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 19 | $0.57 | powershell | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 177 | $7.32 | csharp | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 63 | $3.91 | csharp | ok |
| REST API Client | default | opus | 157.1min | 113 | 118 | $3.08 | python | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 33 | $1.49 | python | ok |
| REST API Client | powershell | opus | 257.5min | 0 | 0 | $0.00 | powershell | failed |
| REST API Client | powershell | sonnet | 13.9min | 56 | 35 | $1.93 | powershell | ok |
| REST API Client | powershell-strict | opus | 378.5min | 101 | 87 | $4.06 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 27 | $1.82 | powershell | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 188 | $6.00 | csharp | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 33 | $1.89 | csharp | ok |
| Process Monitor | default | opus | 9.8min | 115 | 109 | $2.34 | python | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 61 | $1.60 | python | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 78 | $3.28 | powershell | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 33 | $1.11 | powershell | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 114 | $4.00 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 39 | $2.11 | powershell | ok |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 0 | $0.00 | csharp | failed |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 58 | $5.32 | csharp | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 150 | $5.11 | python | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 65 | $2.44 | python | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 90 | $3.65 | powershell | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 60 | $2.57 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 130 | $5.77 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 40 | $1.84 | powershell | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 134 | $3.34 | csharp | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 121 | $3.76 | csharp | ok |
| Batch File Renamer | default | opus | 33.9min | 106 | 109 | $2.76 | python | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 44 | $1.27 | python | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 117 | $3.32 | powershell | ok |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 37 | $2.07 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 148 | $5.60 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 30 | $1.38 | powershell | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 103 | $3.49 | csharp | ok |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 0 | $0.00 | csharp | failed |
| Database Seed Script | default | opus | 13.1min | 146 | 141 | $3.83 | python | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 28 | $0.98 | python | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 140 | $5.61 | powershell | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 36 | $1.67 | powershell | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 160 | $6.54 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 17 | $1.65 | powershell | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 194 | $6.97 | csharp | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 42 | $1.49 | csharp | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 140 | $3.93 |  | ok |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 42 | $1.50 | python | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 90 | $3.26 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 22 | $1.05 | powershell | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 103 | $3.17 | powershell | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 17 | $0.92 | powershell | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 130 | $4.56 | csharp | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 66 | $2.39 | csharp | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 171 | $4.45 | python | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 21 | $0.71 | python | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 124 | $4.56 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 49 | $1.17 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 130 | $3.52 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 62 | $2.41 | powershell | ok |
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 96 | $1.39 | bash | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 42 | $2.67 | csharp | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 115 | $3.34 | python | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 58 | $2.16 | python | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 100 | $3.84 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 96 | $2.60 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 210 | $7.96 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 59 | $2.08 | powershell | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 203 | $7.33 | csharp | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 95 | $4.26 | csharp | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 142 | $3.77 | python | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 23 | $0.92 | python | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 75 | $2.48 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 33 | $1.26 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 130 | $3.72 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 16 | $1.02 | powershell | ok |
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 197 | $8.83 | csharp | ok |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 67 | $3.08 | csharp | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 220 | $6.00 | python | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 39 | $1.18 | python | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 99 | $4.17 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 18 | $0.59 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 60 | $2.75 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 57 | $2.20 | powershell | ok |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 139 | $4.60 | csharp | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 88 | $2.28 | csharp | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 162 | $3.82 | python | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 17 | $0.50 | python | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 101 | $3.05 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 143 | $3.46 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 127 | $3.40 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 38 | $1.34 | powershell | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 93 | $3.40 | csharp | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 29 | $2.32 | csharp | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 203 | $4.97 | python | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 59 | $2.01 | python | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 70 | $3.10 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 40 | $1.57 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 148 | $6.18 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 27 | $1.33 | powershell | ok |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 142 | $6.47 | csharp | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 59 | $2.26 | csharp | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 172 | $3.93 | python | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 33 | $1.32 | python | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 117 | $4.93 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 33 | $0.89 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 126 | $4.48 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 0 | $0.00 | powershell | failed |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 121 | $4.17 | csharp | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 22 | $1.16 | csharp | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 113 | $3.49 | python | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 15 | $0.49 | python | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 90 | $2.83 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 37 | $1.63 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 132 | $5.03 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 35 | $1.83 | powershell | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 149 | $5.30 | csharp | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 85 | $2.67 | csharp | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 88 | $3.43 | python | ok |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 19 | $0.58 | python | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 148 | $4.01 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 53 | $1.52 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 159 | $6.38 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 6 | $0.80 | powershell | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 0 | $0.00 | csharp | failed |
| REST API Client | powershell | opus | 257.5min | 0 | 0 | $0.00 | powershell | failed |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 0 | $0.00 | csharp | failed |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 0 | $0.00 | csharp | failed |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 0 | $0.00 | powershell | failed |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 9 | $0.42 | python | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 15 | $0.49 | python | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 17 | $0.50 | python | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 19 | $0.57 | powershell | ok |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 19 | $0.58 | python | ok |
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 18 | $0.59 | powershell | ok |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 25 | $0.65 | python | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 21 | $0.71 | python | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 6 | $0.80 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 33 | $0.89 | powershell | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 17 | $0.92 | powershell | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 23 | $0.92 | python | ok |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 27 | $0.97 | powershell | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 28 | $0.98 | python | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 16 | $1.02 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 22 | $1.05 | powershell | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 33 | $1.11 | powershell | ok |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 26 | $1.13 | csharp | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 22 | $1.16 | csharp | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 49 | $1.17 | powershell | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 39 | $1.18 | python | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 33 | $1.26 | powershell | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 44 | $1.27 | python | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 33 | $1.32 | python | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 27 | $1.33 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 38 | $1.34 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 22 | $1.37 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 30 | $1.38 | powershell | ok |
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 96 | $1.39 | bash | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 33 | $1.49 | python | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 42 | $1.49 | csharp | ok |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 42 | $1.50 | python | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 53 | $1.52 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 41 | $1.54 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 40 | $1.57 | powershell | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 61 | $1.60 | python | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 37 | $1.63 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 17 | $1.65 | powershell | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 36 | $1.67 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 41 | $1.75 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 51 | $1.78 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 27 | $1.82 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 35 | $1.83 | powershell | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 48 | $1.84 | python | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 40 | $1.84 | powershell | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 33 | $1.89 | csharp | ok |
| REST API Client | powershell | sonnet | 13.9min | 56 | 35 | $1.93 | powershell | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 59 | $2.01 | python | ok |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 37 | $2.07 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 59 | $2.08 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 39 | $2.11 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 58 | $2.16 | python | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 57 | $2.20 | powershell | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 59 | $2.26 | csharp | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 88 | $2.28 | csharp | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 29 | $2.32 | csharp | ok |
| Process Monitor | default | opus | 9.8min | 115 | 109 | $2.34 | python | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 66 | $2.39 | csharp | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 62 | $2.41 | powershell | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 49 | $2.42 | csharp | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 65 | $2.44 | python | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 75 | $2.48 | powershell | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 60 | $2.57 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 96 | $2.60 | powershell | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 42 | $2.67 | csharp | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 85 | $2.67 | csharp | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 60 | $2.75 | powershell | ok |
| Batch File Renamer | default | opus | 33.9min | 106 | 109 | $2.76 | python | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 90 | $2.83 | powershell | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 91 | $2.97 | powershell | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 101 | $3.05 | powershell | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 89 | $3.05 | powershell | ok |
| REST API Client | default | opus | 157.1min | 113 | 118 | $3.08 | python | ok |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 67 | $3.08 | csharp | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 70 | $3.10 | powershell | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 103 | $3.17 | powershell | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 107 | $3.24 | python | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 90 | $3.26 | powershell | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 78 | $3.28 | powershell | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 117 | $3.32 | powershell | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 115 | $3.34 | python | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 134 | $3.34 | csharp | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 127 | $3.40 | powershell | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 93 | $3.40 | csharp | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 88 | $3.43 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 143 | $3.46 | powershell | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 113 | $3.49 | python | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 103 | $3.49 | csharp | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 130 | $3.52 | powershell | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 90 | $3.65 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 130 | $3.72 | powershell | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 121 | $3.76 | csharp | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 142 | $3.77 | python | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 162 | $3.82 | python | ok |
| Database Seed Script | default | opus | 13.1min | 146 | 141 | $3.83 | python | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 100 | $3.84 | powershell | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 105 | $3.88 | powershell | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 63 | $3.91 | csharp | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 140 | $3.93 |  | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 172 | $3.93 | python | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 114 | $4.00 | powershell | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 148 | $4.01 | powershell | ok |
| REST API Client | powershell-strict | opus | 378.5min | 101 | 87 | $4.06 | powershell | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 73 | $4.11 | csharp | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 99 | $4.17 | powershell | ok |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 121 | $4.17 | csharp | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 95 | $4.26 | csharp | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 171 | $4.45 | python | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 126 | $4.48 | powershell | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 124 | $4.56 | powershell | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 130 | $4.56 | csharp | ok |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 139 | $4.60 | csharp | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 140 | $4.71 | powershell | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 225 | $4.92 | python | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 117 | $4.93 | powershell | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 203 | $4.97 | python | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 132 | $5.03 | powershell | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 150 | $5.11 | python | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 149 | $5.30 | csharp | ok |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 58 | $5.32 | csharp | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 205 | $5.43 | javascript | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 134 | $5.44 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 148 | $5.60 | powershell | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 140 | $5.61 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 130 | $5.77 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 176 | $5.79 | powershell | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 220 | $6.00 | python | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 188 | $6.00 | csharp | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 148 | $6.18 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 159 | $6.38 | powershell | ok |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 142 | $6.47 | csharp | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 160 | $6.54 | powershell | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 194 | $6.97 | csharp | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 177 | $7.32 | csharp | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 203 | $7.33 | csharp | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 205 | $7.54 | csharp | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 210 | $7.96 | powershell | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 193 | $8.66 | csharp | ok |
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 197 | $8.83 | csharp | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 18 | $0.59 | powershell | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 15 | $0.49 | python | ok |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 19 | $0.58 | python | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 17 | $0.50 | python | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 21 | $0.71 | python | ok |
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 96 | $1.39 | bash | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 33 | $1.11 | powershell | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 23 | $0.92 | python | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 33 | $0.89 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 6 | $0.80 | powershell | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 17 | $0.92 | powershell | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 39 | $1.18 | python | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 33 | $1.26 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 22 | $1.05 | powershell | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 33 | $1.32 | python | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 53 | $1.52 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 38 | $1.34 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 49 | $1.17 | powershell | ok |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 42 | $1.50 | python | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 16 | $1.02 | powershell | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 22 | $1.16 | csharp | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 40 | $1.57 | powershell | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 61 | $1.60 | python | ok |
| Process Monitor | default | opus | 9.8min | 115 | 109 | $2.34 | python | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 75 | $2.48 | powershell | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 42 | $1.49 | csharp | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 70 | $3.10 | powershell | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 59 | $2.01 | python | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 48 | $1.84 | python | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 51 | $1.78 | powershell | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 33 | $1.49 | python | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 130 | $3.72 | powershell | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 103 | $3.17 | powershell | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 103 | $3.49 | csharp | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 89 | $3.05 | powershell | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 90 | $2.83 | powershell | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 93 | $3.40 | csharp | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 115 | $3.34 | python | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 36 | $1.67 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 130 | $3.52 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 127 | $3.40 | powershell | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 88 | $3.43 | python | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 101 | $3.05 | powershell | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 90 | $3.65 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 30 | $1.38 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 59 | $2.08 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 17 | $1.65 | powershell | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 59 | $2.26 | csharp | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 58 | $2.16 | python | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 113 | $3.49 | python | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 29 | $2.32 | csharp | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 37 | $1.63 | powershell | ok |
| Database Seed Script | default | opus | 13.1min | 146 | 141 | $3.83 | python | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 33 | $1.89 | csharp | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 88 | $2.28 | csharp | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 100 | $3.84 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 35 | $1.83 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 27 | $1.82 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 143 | $3.46 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 96 | $2.60 | powershell | ok |
| REST API Client | powershell | sonnet | 13.9min | 56 | 35 | $1.93 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 39 | $2.11 | powershell | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 85 | $2.67 | csharp | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 140 | $5.61 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 27 | $1.33 | powershell | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 78 | $3.28 | powershell | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 66 | $2.39 | csharp | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 60 | $2.75 | powershell | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 90 | $3.26 | powershell | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 99 | $4.17 | powershell | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 117 | $4.93 | powershell | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 114 | $4.00 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 62 | $2.41 | powershell | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 162 | $3.82 | python | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 148 | $4.01 | powershell | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 172 | $3.93 | python | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 57 | $2.20 | powershell | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 171 | $4.45 | python | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 142 | $3.77 | python | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 176 | $5.79 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 130 | $5.77 | powershell | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 28 | $0.98 | python | ok |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 139 | $4.60 | csharp | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 132 | $5.03 | powershell | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 150 | $5.11 | python | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 126 | $4.48 | powershell | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 203 | $4.97 | python | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 42 | $2.67 | csharp | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 140 | $3.93 |  | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 124 | $4.56 | powershell | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 220 | $6.00 | python | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 149 | $5.30 | csharp | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 130 | $4.56 | csharp | ok |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 121 | $4.17 | csharp | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 210 | $7.96 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 148 | $6.18 | powershell | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 121 | $3.76 | csharp | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 160 | $6.54 | powershell | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 95 | $4.26 | csharp | ok |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 142 | $6.47 | csharp | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 203 | $7.33 | csharp | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 188 | $6.00 | csharp | ok |
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 197 | $8.83 | csharp | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 177 | $7.32 | csharp | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 63 | $3.91 | csharp | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 159 | $6.38 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 19 | $0.57 | powershell | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 225 | $4.92 | python | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 22 | $1.37 | powershell | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 73 | $4.11 | csharp | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 194 | $6.97 | csharp | ok |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 9 | $0.42 | python | ok |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 67 | $3.08 | csharp | ok |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 0 | $0.00 | csharp | failed |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 0 | $0.00 | powershell | failed |
| Batch File Renamer | default | opus | 33.9min | 106 | 109 | $2.76 | python | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 134 | $3.34 | csharp | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 107 | $3.24 | python | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 40 | $1.84 | powershell | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 44 | $1.27 | python | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 60 | $2.57 | powershell | ok |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 25 | $0.65 | python | ok |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 0 | $0.00 | csharp | failed |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 27 | $0.97 | powershell | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 65 | $2.44 | python | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 117 | $3.32 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 41 | $1.54 | powershell | ok |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 58 | $5.32 | csharp | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 148 | $5.60 | powershell | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 205 | $5.43 | javascript | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 91 | $2.97 | powershell | ok |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 26 | $1.13 | csharp | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 41 | $1.75 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 134 | $5.44 | powershell | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 49 | $2.42 | csharp | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 105 | $3.88 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 140 | $4.71 | powershell | ok |
| REST API Client | default | opus | 157.1min | 113 | 118 | $3.08 | python | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 193 | $8.66 | csharp | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 205 | $7.54 | csharp | ok |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 37 | $2.07 | powershell | ok |
| REST API Client | powershell | opus | 257.5min | 0 | 0 | $0.00 | powershell | failed |
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 0 | $0.00 | csharp | failed |
| REST API Client | powershell-strict | opus | 378.5min | 101 | 87 | $4.06 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 0 | $0.00 | csharp | failed |
| REST API Client | powershell | opus | 257.5min | 0 | 0 | $0.00 | powershell | failed |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 0 | $0.00 | csharp | failed |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 0 | $0.00 | csharp | failed |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 0 | $0.00 | powershell | failed |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 6 | $0.80 | powershell | ok |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 9 | $0.42 | python | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 15 | $0.49 | python | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 16 | $1.02 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 17 | $1.65 | powershell | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 17 | $0.92 | powershell | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 17 | $0.50 | python | ok |
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 18 | $0.59 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 19 | $0.57 | powershell | ok |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 19 | $0.58 | python | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 21 | $0.71 | python | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 22 | $1.37 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 22 | $1.05 | powershell | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 22 | $1.16 | csharp | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 23 | $0.92 | python | ok |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 25 | $0.65 | python | ok |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 26 | $1.13 | csharp | ok |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 27 | $0.97 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 27 | $1.82 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 27 | $1.33 | powershell | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 28 | $0.98 | python | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 29 | $2.32 | csharp | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 30 | $1.38 | powershell | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 33 | $1.49 | python | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 33 | $1.89 | csharp | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 33 | $1.11 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 33 | $1.26 | powershell | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 33 | $1.32 | python | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 33 | $0.89 | powershell | ok |
| REST API Client | powershell | sonnet | 13.9min | 56 | 35 | $1.93 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 35 | $1.83 | powershell | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 36 | $1.67 | powershell | ok |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 37 | $2.07 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 37 | $1.63 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 38 | $1.34 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 39 | $2.11 | powershell | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 39 | $1.18 | python | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 40 | $1.84 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 40 | $1.57 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 41 | $1.75 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 41 | $1.54 | powershell | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 42 | $1.49 | csharp | ok |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 42 | $1.50 | python | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 42 | $2.67 | csharp | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 44 | $1.27 | python | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 48 | $1.84 | python | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 49 | $2.42 | csharp | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 49 | $1.17 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 51 | $1.78 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 53 | $1.52 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 57 | $2.20 | powershell | ok |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 58 | $5.32 | csharp | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 58 | $2.16 | python | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 59 | $2.08 | powershell | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 59 | $2.01 | python | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 59 | $2.26 | csharp | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 60 | $2.57 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 60 | $2.75 | powershell | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 61 | $1.60 | python | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 62 | $2.41 | powershell | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 63 | $3.91 | csharp | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 65 | $2.44 | python | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 66 | $2.39 | csharp | ok |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 67 | $3.08 | csharp | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 70 | $3.10 | powershell | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 73 | $4.11 | csharp | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 75 | $2.48 | powershell | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 78 | $3.28 | powershell | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 85 | $2.67 | csharp | ok |
| REST API Client | powershell-strict | opus | 378.5min | 101 | 87 | $4.06 | powershell | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 88 | $2.28 | csharp | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 88 | $3.43 | python | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 89 | $3.05 | powershell | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 90 | $3.65 | powershell | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 90 | $3.26 | powershell | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 90 | $2.83 | powershell | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 91 | $2.97 | powershell | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 93 | $3.40 | csharp | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 95 | $4.26 | csharp | ok |
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 96 | $1.39 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 96 | $2.60 | powershell | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 99 | $4.17 | powershell | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 100 | $3.84 | powershell | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 101 | $3.05 | powershell | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 103 | $3.49 | csharp | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 103 | $3.17 | powershell | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 105 | $3.88 | powershell | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 107 | $3.24 | python | ok |
| Process Monitor | default | opus | 9.8min | 115 | 109 | $2.34 | python | ok |
| Batch File Renamer | default | opus | 33.9min | 106 | 109 | $2.76 | python | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 113 | $3.49 | python | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 114 | $4.00 | powershell | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 115 | $3.34 | python | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 117 | $3.32 | powershell | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 117 | $4.93 | powershell | ok |
| REST API Client | default | opus | 157.1min | 113 | 118 | $3.08 | python | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 121 | $3.76 | csharp | ok |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 121 | $4.17 | csharp | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 124 | $4.56 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 126 | $4.48 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 127 | $3.40 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 130 | $5.77 | powershell | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 130 | $4.56 | csharp | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 130 | $3.52 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 130 | $3.72 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 132 | $5.03 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 134 | $5.44 | powershell | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 134 | $3.34 | csharp | ok |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 139 | $4.60 | csharp | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 140 | $4.71 | powershell | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 140 | $5.61 | powershell | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 140 | $3.93 |  | ok |
| Database Seed Script | default | opus | 13.1min | 146 | 141 | $3.83 | python | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 142 | $3.77 | python | ok |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 142 | $6.47 | csharp | ok |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 143 | $3.46 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 148 | $5.60 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 148 | $6.18 | powershell | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 148 | $4.01 | powershell | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 149 | $5.30 | csharp | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 150 | $5.11 | python | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 159 | $6.38 | powershell | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 160 | $6.54 | powershell | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 162 | $3.82 | python | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 171 | $4.45 | python | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 172 | $3.93 | python | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 176 | $5.79 | powershell | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 177 | $7.32 | csharp | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 188 | $6.00 | csharp | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 193 | $8.66 | csharp | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 194 | $6.97 | csharp | ok |
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 197 | $8.83 | csharp | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 203 | $7.33 | csharp | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 203 | $4.97 | python | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 205 | $5.43 | javascript | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 205 | $7.54 | csharp | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 210 | $7.96 | powershell | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 220 | $6.00 | python | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 225 | $4.92 | python | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 0 | $0.00 | csharp | failed |
| REST API Client | powershell | opus | 257.5min | 0 | 0 | $0.00 | powershell | failed |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 0 | $0.00 | csharp | failed |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 0 | $0.00 | csharp | failed |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 0 | $0.00 | powershell | failed |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 6 | $0.80 | powershell | ok |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 9 | $0.42 | python | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 17 | $0.50 | python | ok |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 19 | $0.58 | python | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 21 | $0.71 | python | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 23 | $0.92 | python | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 15 | $0.49 | python | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 16 | $1.02 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 33 | $0.89 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 19 | $0.57 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 18 | $0.59 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 17 | $1.65 | powershell | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 17 | $0.92 | powershell | ok |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 25 | $0.65 | python | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 27 | $1.33 | powershell | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 22 | $1.16 | csharp | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 37 | $1.63 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 27 | $1.82 | powershell | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 28 | $0.98 | python | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 22 | $1.05 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 33 | $1.26 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 39 | $2.11 | powershell | ok |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 26 | $1.13 | csharp | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 30 | $1.38 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 49 | $1.17 | powershell | ok |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 27 | $0.97 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 22 | $1.37 | powershell | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 39 | $1.18 | python | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 33 | $1.32 | python | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 35 | $1.83 | powershell | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 33 | $1.11 | powershell | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 33 | $1.49 | python | ok |
| REST API Client | powershell | sonnet | 13.9min | 56 | 35 | $1.93 | powershell | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 44 | $1.27 | python | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 38 | $1.34 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 41 | $1.54 | powershell | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 121 | $3.76 | csharp | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 36 | $1.67 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 59 | $2.08 | powershell | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 33 | $1.89 | csharp | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 53 | $1.52 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 51 | $1.78 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 40 | $1.57 | powershell | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 42 | $2.67 | csharp | ok |
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 96 | $1.39 | bash | ok |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 37 | $2.07 | powershell | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 29 | $2.32 | csharp | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 40 | $1.84 | powershell | ok |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 42 | $1.50 | python | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 62 | $2.41 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 57 | $2.20 | powershell | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 42 | $1.49 | csharp | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 48 | $1.84 | python | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 41 | $1.75 | powershell | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 63 | $3.91 | csharp | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 85 | $2.67 | csharp | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 61 | $1.60 | python | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 59 | $2.01 | python | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 90 | $3.26 | powershell | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 60 | $2.57 | powershell | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 49 | $2.42 | csharp | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 59 | $2.26 | csharp | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 60 | $2.75 | powershell | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 70 | $3.10 | powershell | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 90 | $2.83 | powershell | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 91 | $2.97 | powershell | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 75 | $2.48 | powershell | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 66 | $2.39 | csharp | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 78 | $3.28 | powershell | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 89 | $3.05 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 58 | $2.16 | python | ok |
| REST API Client | powershell-strict | opus | 378.5min | 101 | 87 | $4.06 | powershell | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 65 | $2.44 | python | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 88 | $2.28 | csharp | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 117 | $3.32 | powershell | ok |
| Batch File Renamer | default | opus | 33.9min | 106 | 109 | $2.76 | python | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 134 | $3.34 | csharp | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 88 | $3.43 | python | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 101 | $3.05 | powershell | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 113 | $3.49 | python | ok |
| REST API Client | default | opus | 157.1min | 113 | 118 | $3.08 | python | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 103 | $3.17 | powershell | ok |
| Process Monitor | default | opus | 9.8min | 115 | 109 | $2.34 | python | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 90 | $3.65 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 96 | $2.60 | powershell | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 99 | $4.17 | powershell | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 172 | $3.93 | python | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 100 | $3.84 | powershell | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 93 | $3.40 | csharp | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 107 | $3.24 | python | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 103 | $3.49 | csharp | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 105 | $3.88 | powershell | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 114 | $4.00 | powershell | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 124 | $4.56 | powershell | ok |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 67 | $3.08 | csharp | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 130 | $3.52 | powershell | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 115 | $3.34 | python | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 127 | $3.40 | powershell | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 73 | $4.11 | csharp | ok |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 121 | $4.17 | csharp | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 130 | $4.56 | csharp | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 132 | $5.03 | powershell | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 148 | $4.01 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 126 | $4.48 | powershell | ok |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 58 | $5.32 | csharp | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 140 | $4.71 | powershell | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 142 | $3.77 | python | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 130 | $3.72 | powershell | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 95 | $4.26 | csharp | ok |
| Database Seed Script | default | opus | 13.1min | 146 | 141 | $3.83 | python | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 117 | $4.93 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 130 | $5.77 | powershell | ok |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 139 | $4.60 | csharp | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 134 | $5.44 | powershell | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 140 | $3.93 |  | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 162 | $3.82 | python | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 160 | $6.54 | powershell | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 149 | $5.30 | csharp | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 148 | $5.60 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 148 | $6.18 | powershell | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 150 | $5.11 | python | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 140 | $5.61 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 176 | $5.79 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 143 | $3.46 | powershell | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 203 | $4.97 | python | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 194 | $6.97 | csharp | ok |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 142 | $6.47 | csharp | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 159 | $6.38 | powershell | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 171 | $4.45 | python | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 188 | $6.00 | csharp | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 205 | $5.43 | javascript | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 177 | $7.32 | csharp | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 203 | $7.33 | csharp | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 220 | $6.00 | python | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 193 | $8.66 | csharp | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 225 | $4.92 | python | ok |
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 197 | $8.83 | csharp | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 210 | $7.96 | powershell | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 205 | $7.54 | csharp | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v1*