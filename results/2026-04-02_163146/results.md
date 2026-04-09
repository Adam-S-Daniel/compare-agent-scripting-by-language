# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 02:52:48 PM ET

**Status:** 144/144 runs completed, 0 remaining
**Total cost so far:** $436.67
**Total agent time so far:** 5098.1 min

## Observations

- **Fastest (avg):** default/sonnet — 16.7min, then powershell-strict/sonnet — 21.9min
- **Fastest net of traps:** default/opus — -18.0min, then powershell/opus — 0.9min
- **Slowest (avg):** powershell-strict/opus — 52.8min, then csharp-script/opus — 40.2min
- **Slowest net of traps:** powershell/sonnet — 22.5min, then csharp-script/sonnet — 21.3min
- **Cheapest (avg):** default/sonnet — $1.23, then powershell-strict/sonnet — $1.55
- **Cheapest net of traps:** default/opus — $-7.52, then powershell-strict/opus — $-4.80
- **Most expensive (avg):** csharp-script/opus — $5.59, then powershell-strict/opus — $4.92
- **Most expensive net of traps:** powershell-strict/sonnet — $0.96, then csharp-script/sonnet — $0.96

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

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| csharp-script | opus | 16 | 40.2min | 3.8min | 10069 | 154.0 | 163 | $5.59 | $-3.47 | $89.38 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 1154 | 59.9 | 86 | $2.77 | $0.96 | $47.12 |
| default | opus | 18 | 30.8min | -18.0min | 745 | 149.4 | 148 | $3.99 | $-7.52 | $71.84 |
| default | sonnet | 18 | 16.7min | 10.0min | 728 | 35.5 | 51 | $1.23 | $0.35 | $22.08 |
| powershell | opus | 17 | 30.1min | 0.9min | 764 | 101.4 | 112 | $3.65 | $-3.22 | $61.98 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 634 | 46.9 | 63 | $1.63 | $0.28 | $29.38 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 883 | 134.1 | 145 | $4.92 | $-4.80 | $88.48 |
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 783 | 32.5 | 48 | $1.55 | $0.96 | $26.42 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| csharp-script | opus | 16 | 40.2min | 3.8min | 10069 | 154.0 | 163 | $5.59 | $-3.47 | $89.38 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 883 | 134.1 | 145 | $4.92 | $-4.80 | $88.48 |
| default | opus | 18 | 30.8min | -18.0min | 745 | 149.4 | 148 | $3.99 | $-7.52 | $71.84 |
| powershell | opus | 17 | 30.1min | 0.9min | 764 | 101.4 | 112 | $3.65 | $-3.22 | $61.98 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 1154 | 59.9 | 86 | $2.77 | $0.96 | $47.12 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 634 | 46.9 | 63 | $1.63 | $0.28 | $29.38 |
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 783 | 32.5 | 48 | $1.55 | $0.96 | $26.42 |
| default | sonnet | 18 | 16.7min | 10.0min | 728 | 35.5 | 51 | $1.23 | $0.35 | $22.08 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 783 | 32.5 | 48 | $1.55 | $0.96 | $26.42 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 1154 | 59.9 | 86 | $2.77 | $0.96 | $47.12 |
| default | sonnet | 18 | 16.7min | 10.0min | 728 | 35.5 | 51 | $1.23 | $0.35 | $22.08 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 634 | 46.9 | 63 | $1.63 | $0.28 | $29.38 |
| powershell | opus | 17 | 30.1min | 0.9min | 764 | 101.4 | 112 | $3.65 | $-3.22 | $61.98 |
| csharp-script | opus | 16 | 40.2min | 3.8min | 10069 | 154.0 | 163 | $5.59 | $-3.47 | $89.38 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 883 | 134.1 | 145 | $4.92 | $-4.80 | $88.48 |
| default | opus | 18 | 30.8min | -18.0min | 745 | 149.4 | 148 | $3.99 | $-7.52 | $71.84 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | opus | 18 | 30.8min | -18.0min | 745 | 149.4 | 148 | $3.99 | $-7.52 | $71.84 |
| powershell | opus | 17 | 30.1min | 0.9min | 764 | 101.4 | 112 | $3.65 | $-3.22 | $61.98 |
| csharp-script | opus | 16 | 40.2min | 3.8min | 10069 | 154.0 | 163 | $5.59 | $-3.47 | $89.38 |
| default | sonnet | 18 | 16.7min | 10.0min | 728 | 35.5 | 51 | $1.23 | $0.35 | $22.08 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 883 | 134.1 | 145 | $4.92 | $-4.80 | $88.48 |
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 783 | 32.5 | 48 | $1.55 | $0.96 | $26.42 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 1154 | 59.9 | 86 | $2.77 | $0.96 | $47.12 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 634 | 46.9 | 63 | $1.63 | $0.28 | $29.38 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 783 | 32.5 | 48 | $1.55 | $0.96 | $26.42 |
| default | sonnet | 18 | 16.7min | 10.0min | 728 | 35.5 | 51 | $1.23 | $0.35 | $22.08 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 634 | 46.9 | 63 | $1.63 | $0.28 | $29.38 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 1154 | 59.9 | 86 | $2.77 | $0.96 | $47.12 |
| powershell | opus | 17 | 30.1min | 0.9min | 764 | 101.4 | 112 | $3.65 | $-3.22 | $61.98 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 883 | 134.1 | 145 | $4.92 | $-4.80 | $88.48 |
| default | opus | 18 | 30.8min | -18.0min | 745 | 149.4 | 148 | $3.99 | $-7.52 | $71.84 |
| csharp-script | opus | 16 | 40.2min | 3.8min | 10069 | 154.0 | 163 | $5.59 | $-3.47 | $89.38 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | sonnet | 18 | 31.1min | 22.5min | 634 | 46.9 | 63 | $1.63 | $0.28 | $29.38 |
| default | sonnet | 18 | 16.7min | 10.0min | 728 | 35.5 | 51 | $1.23 | $0.35 | $22.08 |
| default | opus | 18 | 30.8min | -18.0min | 745 | 149.4 | 148 | $3.99 | $-7.52 | $71.84 |
| powershell | opus | 17 | 30.1min | 0.9min | 764 | 101.4 | 112 | $3.65 | $-3.22 | $61.98 |
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 783 | 32.5 | 48 | $1.55 | $0.96 | $26.42 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 883 | 134.1 | 145 | $4.92 | $-4.80 | $88.48 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 1154 | 59.9 | 86 | $2.77 | $0.96 | $47.12 |
| csharp-script | opus | 16 | 40.2min | 3.8min | 10069 | 154.0 | 163 | $5.59 | $-3.47 | $89.38 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell-strict | sonnet | 17 | 21.9min | 16.7min | 783 | 32.5 | 48 | $1.55 | $0.96 | $26.42 |
| default | sonnet | 18 | 16.7min | 10.0min | 728 | 35.5 | 51 | $1.23 | $0.35 | $22.08 |
| powershell | sonnet | 18 | 31.1min | 22.5min | 634 | 46.9 | 63 | $1.63 | $0.28 | $29.38 |
| csharp-script | sonnet | 17 | 33.1min | 21.3min | 1154 | 59.9 | 86 | $2.77 | $0.96 | $47.12 |
| powershell | opus | 17 | 30.1min | 0.9min | 764 | 101.4 | 112 | $3.65 | $-3.22 | $61.98 |
| powershell-strict | opus | 18 | 52.8min | 14.3min | 883 | 134.1 | 145 | $4.92 | $-4.80 | $88.48 |
| default | opus | 18 | 30.8min | -18.0min | 745 | 149.4 | 148 | $3.99 | $-7.52 | $71.84 |
| csharp-script | opus | 16 | 40.2min | 3.8min | 10069 | 154.0 | 163 | $5.59 | $-3.47 | $89.38 |

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
| **Total** | | | **139 runs** | **3219.2min** | **63.1%** | **$724.82** | **165.99%** |


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

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 18 | 16 | 89% | 56 | 583.4min | 11.4% | $144.91 | 33.19% |
| csharp-script | sonnet | 18 | 17 | 94% | 45 | 201.0min | 3.9% | $30.87 | 7.07% |
| default | opus | 18 | 18 | 100% | 69 | 879.3min | 17.2% | $207.20 | 47.45% |
| default | sonnet | 18 | 18 | 100% | 42 | 122.1min | 2.4% | $15.86 | 3.63% |
| powershell | opus | 18 | 17 | 94% | 65 | 495.3min | 9.7% | $116.68 | 26.72% |
| powershell | sonnet | 18 | 18 | 100% | 32 | 155.5min | 3.1% | $24.40 | 5.59% |
| powershell-strict | opus | 18 | 18 | 100% | 67 | 694.2min | 13.6% | $174.81 | 40.03% |
| powershell-strict | sonnet | 18 | 17 | 94% | 23 | 88.3min | 1.7% | $10.09 | 2.31% |
| **Total** | | **144** | **139** | **97%** | **399** | **3219.2min** | **63.1%** | **$724.82** | **165.99%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell-strict | sonnet | 18 | 17 | 94% | 23 | 88.3min | 1.7% | $10.09 | 2.31% |
| default | sonnet | 18 | 18 | 100% | 42 | 122.1min | 2.4% | $15.86 | 3.63% |
| powershell | sonnet | 18 | 18 | 100% | 32 | 155.5min | 3.1% | $24.40 | 5.59% |
| csharp-script | sonnet | 18 | 17 | 94% | 45 | 201.0min | 3.9% | $30.87 | 7.07% |
| powershell | opus | 18 | 17 | 94% | 65 | 495.3min | 9.7% | $116.68 | 26.72% |
| csharp-script | opus | 18 | 16 | 89% | 56 | 583.4min | 11.4% | $144.91 | 33.19% |
| powershell-strict | opus | 18 | 18 | 100% | 67 | 694.2min | 13.6% | $174.81 | 40.03% |
| default | opus | 18 | 18 | 100% | 69 | 879.3min | 17.2% | $207.20 | 47.45% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell-strict | sonnet | 18 | 17 | 94% | 23 | 88.3min | 1.7% | $10.09 | 2.31% |
| default | sonnet | 18 | 18 | 100% | 42 | 122.1min | 2.4% | $15.86 | 3.63% |
| powershell | sonnet | 18 | 18 | 100% | 32 | 155.5min | 3.1% | $24.40 | 5.59% |
| csharp-script | sonnet | 18 | 17 | 94% | 45 | 201.0min | 3.9% | $30.87 | 7.07% |
| powershell | opus | 18 | 17 | 94% | 65 | 495.3min | 9.7% | $116.68 | 26.72% |
| csharp-script | opus | 18 | 16 | 89% | 56 | 583.4min | 11.4% | $144.91 | 33.19% |
| powershell-strict | opus | 18 | 18 | 100% | 67 | 694.2min | 13.6% | $174.81 | 40.03% |
| default | opus | 18 | 18 | 100% | 69 | 879.3min | 17.2% | $207.20 | 47.45% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 18 | 16 | 89% | 56 | 583.4min | 11.4% | $144.91 | 33.19% |
| csharp-script | sonnet | 18 | 17 | 94% | 45 | 201.0min | 3.9% | $30.87 | 7.07% |
| powershell | opus | 18 | 17 | 94% | 65 | 495.3min | 9.7% | $116.68 | 26.72% |
| powershell-strict | sonnet | 18 | 17 | 94% | 23 | 88.3min | 1.7% | $10.09 | 2.31% |
| default | opus | 18 | 18 | 100% | 69 | 879.3min | 17.2% | $207.20 | 47.45% |
| default | sonnet | 18 | 18 | 100% | 42 | 122.1min | 2.4% | $15.86 | 3.63% |
| powershell | sonnet | 18 | 18 | 100% | 32 | 155.5min | 3.1% | $24.40 | 5.59% |
| powershell-strict | opus | 18 | 18 | 100% | 67 | 694.2min | 13.6% | $174.81 | 40.03% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 125 | $11.01 | 2.52% |
| Miss | 14 | $0.00 | 0.00% |
| **Total** | **139** | **$11.01** | **2.52%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 165 | 0 | $0.00 | csharp | failed |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 669 | 26 | $1.13 | csharp | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 371 | 225 | $4.92 | python | ok |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 511 | 25 | $0.65 | python | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 479 | 89 | $3.05 | powershell | ok |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 439 | 27 | $0.97 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 604 | 176 | $5.79 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 604 | 41 | $1.75 | powershell | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 1302 | 193 | $8.66 | csharp | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 1446 | 73 | $4.11 | csharp | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 843 | 205 | $5.43 | javascript | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 1204 | 48 | $1.84 | python | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 612 | 105 | $3.88 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 784 | 51 | $1.78 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 795 | 134 | $5.44 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 863 | 22 | $1.37 | powershell | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 851 | 205 | $7.54 | csharp | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 1468 | 49 | $2.42 | csharp | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 659 | 107 | $3.24 | python | ok |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 679 | 9 | $0.42 | python | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 759 | 91 | $2.97 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 648 | 41 | $1.54 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 810 | 140 | $4.71 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 786 | 19 | $0.57 | powershell | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 1615 | 177 | $7.32 | csharp | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 1133 | 63 | $3.91 | csharp | ok |
| REST API Client | default | opus | 157.1min | 113 | 579 | 118 | $3.08 | python | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 707 | 33 | $1.49 | python | ok |
| REST API Client | powershell | opus | 257.5min | 0 | 629 | 0 | $0.00 | powershell | failed |
| REST API Client | powershell | sonnet | 13.9min | 56 | 699 | 35 | $1.93 | powershell | ok |
| REST API Client | powershell-strict | opus | 378.5min | 101 | 1073 | 87 | $4.06 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 678 | 27 | $1.82 | powershell | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 832 | 188 | $6.00 | csharp | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 971 | 33 | $1.89 | csharp | ok |
| Process Monitor | default | opus | 9.8min | 115 | 580 | 109 | $2.34 | python | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 578 | 61 | $1.60 | python | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 598 | 78 | $3.28 | powershell | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 476 | 33 | $1.11 | powershell | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 720 | 114 | $4.00 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 721 | 39 | $2.11 | powershell | ok |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 1899 | 0 | $0.00 | csharp | failed |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 1947 | 58 | $5.32 | csharp | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 1053 | 150 | $5.11 | python | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 992 | 65 | $2.44 | python | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 1063 | 90 | $3.65 | powershell | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 1018 | 60 | $2.57 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 1244 | 130 | $5.77 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 779 | 40 | $1.84 | powershell | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 1009 | 134 | $3.34 | csharp | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 1088 | 121 | $3.76 | csharp | ok |
| Batch File Renamer | default | opus | 33.9min | 106 | 716 | 109 | $2.76 | python | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 555 | 44 | $1.27 | python | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 900 | 117 | $3.32 | powershell | ok |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 481 | 37 | $2.07 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 647 | 148 | $5.60 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 626 | 30 | $1.38 | powershell | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 1340 | 103 | $3.49 | csharp | ok |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 2013 | 0 | $0.00 | csharp | failed |
| Database Seed Script | default | opus | 13.1min | 146 | 843 | 141 | $3.83 | python | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 742 | 28 | $0.98 | python | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 1115 | 140 | $5.61 | powershell | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 813 | 36 | $1.67 | powershell | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 1500 | 160 | $6.54 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 1178 | 17 | $1.65 | powershell | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 1067 | 194 | $6.97 | csharp | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 797 | 42 | $1.49 | csharp | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 870 | 140 | $3.93 |  | ok |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 636 | 42 | $1.50 | python | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 665 | 90 | $3.26 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 628 | 22 | $1.05 | powershell | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 941 | 103 | $3.17 | powershell | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 479 | 17 | $0.92 | powershell | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 1281 | 130 | $4.56 | csharp | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 892 | 66 | $2.39 | csharp | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 656 | 171 | $4.45 | python | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 786 | 21 | $0.71 | python | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 726 | 124 | $4.56 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 471 | 49 | $1.17 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 496 | 130 | $3.52 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 957 | 62 | $2.41 | powershell | ok |
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 18 | 96 | $1.39 | bash | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 1625 | 42 | $2.67 | csharp | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 829 | 115 | $3.34 | python | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 714 | 58 | $2.16 | python | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 879 | 100 | $3.84 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 624 | 96 | $2.60 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 866 | 210 | $7.96 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 773 | 59 | $2.08 | powershell | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 1107 | 203 | $7.33 | csharp | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 957 | 95 | $4.26 | csharp | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 517 | 142 | $3.77 | python | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 530 | 23 | $0.92 | python | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 605 | 75 | $2.48 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 454 | 33 | $1.26 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 670 | 130 | $3.72 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 542 | 16 | $1.02 | powershell | ok |
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 1316 | 197 | $8.83 | csharp | ok |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 1413 | 67 | $3.08 | csharp | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 889 | 220 | $6.00 | python | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 729 | 39 | $1.18 | python | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 847 | 99 | $4.17 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 555 | 18 | $0.59 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 933 | 60 | $2.75 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 1016 | 57 | $2.20 | powershell | ok |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 143163 | 139 | $4.60 | csharp | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 760 | 88 | $2.28 | csharp | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 400 | 162 | $3.82 | python | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 297 | 17 | $0.50 | python | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 421 | 101 | $3.05 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 292 | 143 | $3.46 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 481 | 127 | $3.40 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 643 | 38 | $1.34 | powershell | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 1834 | 93 | $3.40 | csharp | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 1464 | 29 | $2.32 | csharp | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 818 | 203 | $4.97 | python | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 1375 | 59 | $2.01 | python | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 904 | 70 | $3.10 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 907 | 40 | $1.57 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 990 | 148 | $6.18 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 794 | 27 | $1.33 | powershell | ok |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 1945 | 142 | $6.47 | csharp | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 1126 | 59 | $2.26 | csharp | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 713 | 172 | $3.93 | python | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 925 | 33 | $1.32 | python | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 931 | 117 | $4.93 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 516 | 33 | $0.89 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 868 | 126 | $4.48 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 586 | 0 | $0.00 | powershell | failed |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 1012 | 121 | $4.17 | csharp | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 829 | 22 | $1.16 | csharp | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 829 | 113 | $3.49 | python | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 554 | 15 | $0.49 | python | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 784 | 90 | $2.83 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 731 | 37 | $1.63 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 1058 | 132 | $5.03 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 965 | 35 | $1.83 | powershell | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 1412 | 149 | $5.30 | csharp | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 1036 | 85 | $2.67 | csharp | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 1237 | 88 | $3.43 | python | ok |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 586 | 19 | $0.58 | python | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 696 | 148 | $4.01 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 884 | 53 | $1.52 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 1192 | 159 | $6.38 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 914 | 6 | $0.80 | powershell | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 1316 | 197 | $8.83 | csharp | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 1302 | 193 | $8.66 | csharp | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 866 | 210 | $7.96 | powershell | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 851 | 205 | $7.54 | csharp | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 1107 | 203 | $7.33 | csharp | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 1615 | 177 | $7.32 | csharp | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 1067 | 194 | $6.97 | csharp | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 1500 | 160 | $6.54 | powershell | ok |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 1945 | 142 | $6.47 | csharp | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 1192 | 159 | $6.38 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 990 | 148 | $6.18 | powershell | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 832 | 188 | $6.00 | csharp | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 889 | 220 | $6.00 | python | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 604 | 176 | $5.79 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 1244 | 130 | $5.77 | powershell | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 1115 | 140 | $5.61 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 647 | 148 | $5.60 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 795 | 134 | $5.44 | powershell | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 843 | 205 | $5.43 | javascript | ok |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 1947 | 58 | $5.32 | csharp | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 1412 | 149 | $5.30 | csharp | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 1053 | 150 | $5.11 | python | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 1058 | 132 | $5.03 | powershell | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 818 | 203 | $4.97 | python | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 931 | 117 | $4.93 | powershell | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 371 | 225 | $4.92 | python | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 810 | 140 | $4.71 | powershell | ok |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 143163 | 139 | $4.60 | csharp | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 1281 | 130 | $4.56 | csharp | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 726 | 124 | $4.56 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 868 | 126 | $4.48 | powershell | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 656 | 171 | $4.45 | python | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 957 | 95 | $4.26 | csharp | ok |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 1012 | 121 | $4.17 | csharp | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 847 | 99 | $4.17 | powershell | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 1446 | 73 | $4.11 | csharp | ok |
| REST API Client | powershell-strict | opus | 378.5min | 101 | 1073 | 87 | $4.06 | powershell | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 696 | 148 | $4.01 | powershell | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 720 | 114 | $4.00 | powershell | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 713 | 172 | $3.93 | python | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 870 | 140 | $3.93 |  | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 1133 | 63 | $3.91 | csharp | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 612 | 105 | $3.88 | powershell | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 879 | 100 | $3.84 | powershell | ok |
| Database Seed Script | default | opus | 13.1min | 146 | 843 | 141 | $3.83 | python | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 400 | 162 | $3.82 | python | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 517 | 142 | $3.77 | python | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 1088 | 121 | $3.76 | csharp | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 670 | 130 | $3.72 | powershell | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 1063 | 90 | $3.65 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 496 | 130 | $3.52 | powershell | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 1340 | 103 | $3.49 | csharp | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 829 | 113 | $3.49 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 292 | 143 | $3.46 | powershell | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 1237 | 88 | $3.43 | python | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 1834 | 93 | $3.40 | csharp | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 481 | 127 | $3.40 | powershell | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 1009 | 134 | $3.34 | csharp | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 829 | 115 | $3.34 | python | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 900 | 117 | $3.32 | powershell | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 598 | 78 | $3.28 | powershell | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 665 | 90 | $3.26 | powershell | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 659 | 107 | $3.24 | python | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 941 | 103 | $3.17 | powershell | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 904 | 70 | $3.10 | powershell | ok |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 1413 | 67 | $3.08 | csharp | ok |
| REST API Client | default | opus | 157.1min | 113 | 579 | 118 | $3.08 | python | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 479 | 89 | $3.05 | powershell | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 421 | 101 | $3.05 | powershell | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 759 | 91 | $2.97 | powershell | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 784 | 90 | $2.83 | powershell | ok |
| Batch File Renamer | default | opus | 33.9min | 106 | 716 | 109 | $2.76 | python | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 933 | 60 | $2.75 | powershell | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 1036 | 85 | $2.67 | csharp | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 1625 | 42 | $2.67 | csharp | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 624 | 96 | $2.60 | powershell | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 1018 | 60 | $2.57 | powershell | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 605 | 75 | $2.48 | powershell | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 992 | 65 | $2.44 | python | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 1468 | 49 | $2.42 | csharp | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 957 | 62 | $2.41 | powershell | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 892 | 66 | $2.39 | csharp | ok |
| Process Monitor | default | opus | 9.8min | 115 | 580 | 109 | $2.34 | python | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 1464 | 29 | $2.32 | csharp | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 760 | 88 | $2.28 | csharp | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 1126 | 59 | $2.26 | csharp | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 1016 | 57 | $2.20 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 714 | 58 | $2.16 | python | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 721 | 39 | $2.11 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 773 | 59 | $2.08 | powershell | ok |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 481 | 37 | $2.07 | powershell | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 1375 | 59 | $2.01 | python | ok |
| REST API Client | powershell | sonnet | 13.9min | 56 | 699 | 35 | $1.93 | powershell | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 971 | 33 | $1.89 | csharp | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 779 | 40 | $1.84 | powershell | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 1204 | 48 | $1.84 | python | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 965 | 35 | $1.83 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 678 | 27 | $1.82 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 784 | 51 | $1.78 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 604 | 41 | $1.75 | powershell | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 813 | 36 | $1.67 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 1178 | 17 | $1.65 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 731 | 37 | $1.63 | powershell | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 578 | 61 | $1.60 | python | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 907 | 40 | $1.57 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 648 | 41 | $1.54 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 884 | 53 | $1.52 | powershell | ok |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 636 | 42 | $1.50 | python | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 797 | 42 | $1.49 | csharp | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 707 | 33 | $1.49 | python | ok |
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 18 | 96 | $1.39 | bash | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 626 | 30 | $1.38 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 863 | 22 | $1.37 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 643 | 38 | $1.34 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 794 | 27 | $1.33 | powershell | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 925 | 33 | $1.32 | python | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 555 | 44 | $1.27 | python | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 454 | 33 | $1.26 | powershell | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 729 | 39 | $1.18 | python | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 471 | 49 | $1.17 | powershell | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 829 | 22 | $1.16 | csharp | ok |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 669 | 26 | $1.13 | csharp | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 476 | 33 | $1.11 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 628 | 22 | $1.05 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 542 | 16 | $1.02 | powershell | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 742 | 28 | $0.98 | python | ok |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 439 | 27 | $0.97 | powershell | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 530 | 23 | $0.92 | python | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 479 | 17 | $0.92 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 516 | 33 | $0.89 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 914 | 6 | $0.80 | powershell | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 786 | 21 | $0.71 | python | ok |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 511 | 25 | $0.65 | python | ok |
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 555 | 18 | $0.59 | powershell | ok |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 586 | 19 | $0.58 | python | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 786 | 19 | $0.57 | powershell | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 297 | 17 | $0.50 | python | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 554 | 15 | $0.49 | python | ok |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 679 | 9 | $0.42 | python | ok |
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 165 | 0 | $0.00 | csharp | failed |
| REST API Client | powershell | opus | 257.5min | 0 | 629 | 0 | $0.00 | powershell | failed |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 1899 | 0 | $0.00 | csharp | failed |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 2013 | 0 | $0.00 | csharp | failed |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 586 | 0 | $0.00 | powershell | failed |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| REST API Client | powershell-strict | opus | 378.5min | 101 | 1073 | 87 | $4.06 | powershell | ok |
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 165 | 0 | $0.00 | csharp | failed |
| REST API Client | powershell | opus | 257.5min | 0 | 629 | 0 | $0.00 | powershell | failed |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 481 | 37 | $2.07 | powershell | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 851 | 205 | $7.54 | csharp | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 1302 | 193 | $8.66 | csharp | ok |
| REST API Client | default | opus | 157.1min | 113 | 579 | 118 | $3.08 | python | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 810 | 140 | $4.71 | powershell | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 612 | 105 | $3.88 | powershell | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 1468 | 49 | $2.42 | csharp | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 795 | 134 | $5.44 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 604 | 41 | $1.75 | powershell | ok |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 669 | 26 | $1.13 | csharp | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 759 | 91 | $2.97 | powershell | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 843 | 205 | $5.43 | javascript | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 647 | 148 | $5.60 | powershell | ok |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 1947 | 58 | $5.32 | csharp | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 648 | 41 | $1.54 | powershell | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 900 | 117 | $3.32 | powershell | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 992 | 65 | $2.44 | python | ok |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 439 | 27 | $0.97 | powershell | ok |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 1899 | 0 | $0.00 | csharp | failed |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 511 | 25 | $0.65 | python | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 1018 | 60 | $2.57 | powershell | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 555 | 44 | $1.27 | python | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 779 | 40 | $1.84 | powershell | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 659 | 107 | $3.24 | python | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 1009 | 134 | $3.34 | csharp | ok |
| Batch File Renamer | default | opus | 33.9min | 106 | 716 | 109 | $2.76 | python | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 586 | 0 | $0.00 | powershell | failed |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 2013 | 0 | $0.00 | csharp | failed |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 1413 | 67 | $3.08 | csharp | ok |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 679 | 9 | $0.42 | python | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 1067 | 194 | $6.97 | csharp | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 1446 | 73 | $4.11 | csharp | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 863 | 22 | $1.37 | powershell | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 371 | 225 | $4.92 | python | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 786 | 19 | $0.57 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 1192 | 159 | $6.38 | powershell | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 1133 | 63 | $3.91 | csharp | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 1615 | 177 | $7.32 | csharp | ok |
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 1316 | 197 | $8.83 | csharp | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 832 | 188 | $6.00 | csharp | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 1107 | 203 | $7.33 | csharp | ok |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 1945 | 142 | $6.47 | csharp | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 957 | 95 | $4.26 | csharp | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 1500 | 160 | $6.54 | powershell | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 1088 | 121 | $3.76 | csharp | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 990 | 148 | $6.18 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 866 | 210 | $7.96 | powershell | ok |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 1012 | 121 | $4.17 | csharp | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 1281 | 130 | $4.56 | csharp | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 1412 | 149 | $5.30 | csharp | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 889 | 220 | $6.00 | python | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 726 | 124 | $4.56 | powershell | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 870 | 140 | $3.93 |  | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 1625 | 42 | $2.67 | csharp | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 818 | 203 | $4.97 | python | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 868 | 126 | $4.48 | powershell | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 1053 | 150 | $5.11 | python | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 1058 | 132 | $5.03 | powershell | ok |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 143163 | 139 | $4.60 | csharp | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 742 | 28 | $0.98 | python | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 1244 | 130 | $5.77 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 604 | 176 | $5.79 | powershell | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 517 | 142 | $3.77 | python | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 656 | 171 | $4.45 | python | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 1016 | 57 | $2.20 | powershell | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 713 | 172 | $3.93 | python | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 696 | 148 | $4.01 | powershell | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 400 | 162 | $3.82 | python | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 957 | 62 | $2.41 | powershell | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 720 | 114 | $4.00 | powershell | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 931 | 117 | $4.93 | powershell | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 847 | 99 | $4.17 | powershell | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 665 | 90 | $3.26 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 933 | 60 | $2.75 | powershell | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 892 | 66 | $2.39 | csharp | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 598 | 78 | $3.28 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 794 | 27 | $1.33 | powershell | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 1115 | 140 | $5.61 | powershell | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 1036 | 85 | $2.67 | csharp | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 721 | 39 | $2.11 | powershell | ok |
| REST API Client | powershell | sonnet | 13.9min | 56 | 699 | 35 | $1.93 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 624 | 96 | $2.60 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 292 | 143 | $3.46 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 678 | 27 | $1.82 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 965 | 35 | $1.83 | powershell | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 879 | 100 | $3.84 | powershell | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 760 | 88 | $2.28 | csharp | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 971 | 33 | $1.89 | csharp | ok |
| Database Seed Script | default | opus | 13.1min | 146 | 843 | 141 | $3.83 | python | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 731 | 37 | $1.63 | powershell | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 1464 | 29 | $2.32 | csharp | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 829 | 113 | $3.49 | python | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 714 | 58 | $2.16 | python | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 1126 | 59 | $2.26 | csharp | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 1178 | 17 | $1.65 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 773 | 59 | $2.08 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 626 | 30 | $1.38 | powershell | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 1063 | 90 | $3.65 | powershell | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 421 | 101 | $3.05 | powershell | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 1237 | 88 | $3.43 | python | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 481 | 127 | $3.40 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 496 | 130 | $3.52 | powershell | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 813 | 36 | $1.67 | powershell | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 829 | 115 | $3.34 | python | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 1834 | 93 | $3.40 | csharp | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 784 | 90 | $2.83 | powershell | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 479 | 89 | $3.05 | powershell | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 1340 | 103 | $3.49 | csharp | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 941 | 103 | $3.17 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 670 | 130 | $3.72 | powershell | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 707 | 33 | $1.49 | python | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 784 | 51 | $1.78 | powershell | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 1204 | 48 | $1.84 | python | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 1375 | 59 | $2.01 | python | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 904 | 70 | $3.10 | powershell | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 797 | 42 | $1.49 | csharp | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 605 | 75 | $2.48 | powershell | ok |
| Process Monitor | default | opus | 9.8min | 115 | 580 | 109 | $2.34 | python | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 578 | 61 | $1.60 | python | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 907 | 40 | $1.57 | powershell | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 829 | 22 | $1.16 | csharp | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 542 | 16 | $1.02 | powershell | ok |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 636 | 42 | $1.50 | python | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 471 | 49 | $1.17 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 643 | 38 | $1.34 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 884 | 53 | $1.52 | powershell | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 925 | 33 | $1.32 | python | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 628 | 22 | $1.05 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 454 | 33 | $1.26 | powershell | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 729 | 39 | $1.18 | python | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 479 | 17 | $0.92 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 914 | 6 | $0.80 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 516 | 33 | $0.89 | powershell | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 530 | 23 | $0.92 | python | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 476 | 33 | $1.11 | powershell | ok |
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 18 | 96 | $1.39 | bash | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 786 | 21 | $0.71 | python | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 297 | 17 | $0.50 | python | ok |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 586 | 19 | $0.58 | python | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 554 | 15 | $0.49 | python | ok |
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 555 | 18 | $0.59 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 165 | 0 | $0.00 | csharp | failed |
| REST API Client | powershell | opus | 257.5min | 0 | 629 | 0 | $0.00 | powershell | failed |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 1899 | 0 | $0.00 | csharp | failed |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 2013 | 0 | $0.00 | csharp | failed |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 586 | 0 | $0.00 | powershell | failed |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 914 | 6 | $0.80 | powershell | ok |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 679 | 9 | $0.42 | python | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 554 | 15 | $0.49 | python | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 542 | 16 | $1.02 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 1178 | 17 | $1.65 | powershell | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 479 | 17 | $0.92 | powershell | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 297 | 17 | $0.50 | python | ok |
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 555 | 18 | $0.59 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 786 | 19 | $0.57 | powershell | ok |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 586 | 19 | $0.58 | python | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 786 | 21 | $0.71 | python | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 863 | 22 | $1.37 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 628 | 22 | $1.05 | powershell | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 829 | 22 | $1.16 | csharp | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 530 | 23 | $0.92 | python | ok |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 511 | 25 | $0.65 | python | ok |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 669 | 26 | $1.13 | csharp | ok |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 439 | 27 | $0.97 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 678 | 27 | $1.82 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 794 | 27 | $1.33 | powershell | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 742 | 28 | $0.98 | python | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 1464 | 29 | $2.32 | csharp | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 626 | 30 | $1.38 | powershell | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 707 | 33 | $1.49 | python | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 971 | 33 | $1.89 | csharp | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 476 | 33 | $1.11 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 454 | 33 | $1.26 | powershell | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 925 | 33 | $1.32 | python | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 516 | 33 | $0.89 | powershell | ok |
| REST API Client | powershell | sonnet | 13.9min | 56 | 699 | 35 | $1.93 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 965 | 35 | $1.83 | powershell | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 813 | 36 | $1.67 | powershell | ok |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 481 | 37 | $2.07 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 731 | 37 | $1.63 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 643 | 38 | $1.34 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 721 | 39 | $2.11 | powershell | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 729 | 39 | $1.18 | python | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 779 | 40 | $1.84 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 907 | 40 | $1.57 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 604 | 41 | $1.75 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 648 | 41 | $1.54 | powershell | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 797 | 42 | $1.49 | csharp | ok |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 636 | 42 | $1.50 | python | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 1625 | 42 | $2.67 | csharp | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 555 | 44 | $1.27 | python | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 1204 | 48 | $1.84 | python | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 1468 | 49 | $2.42 | csharp | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 471 | 49 | $1.17 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 784 | 51 | $1.78 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 884 | 53 | $1.52 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 1016 | 57 | $2.20 | powershell | ok |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 1947 | 58 | $5.32 | csharp | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 714 | 58 | $2.16 | python | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 773 | 59 | $2.08 | powershell | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 1375 | 59 | $2.01 | python | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 1126 | 59 | $2.26 | csharp | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 1018 | 60 | $2.57 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 933 | 60 | $2.75 | powershell | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 578 | 61 | $1.60 | python | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 957 | 62 | $2.41 | powershell | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 1133 | 63 | $3.91 | csharp | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 992 | 65 | $2.44 | python | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 892 | 66 | $2.39 | csharp | ok |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 1413 | 67 | $3.08 | csharp | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 904 | 70 | $3.10 | powershell | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 1446 | 73 | $4.11 | csharp | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 605 | 75 | $2.48 | powershell | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 598 | 78 | $3.28 | powershell | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 1036 | 85 | $2.67 | csharp | ok |
| REST API Client | powershell-strict | opus | 378.5min | 101 | 1073 | 87 | $4.06 | powershell | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 760 | 88 | $2.28 | csharp | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 1237 | 88 | $3.43 | python | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 479 | 89 | $3.05 | powershell | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 1063 | 90 | $3.65 | powershell | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 665 | 90 | $3.26 | powershell | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 784 | 90 | $2.83 | powershell | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 759 | 91 | $2.97 | powershell | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 1834 | 93 | $3.40 | csharp | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 957 | 95 | $4.26 | csharp | ok |
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 18 | 96 | $1.39 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 624 | 96 | $2.60 | powershell | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 847 | 99 | $4.17 | powershell | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 879 | 100 | $3.84 | powershell | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 421 | 101 | $3.05 | powershell | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 1340 | 103 | $3.49 | csharp | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 941 | 103 | $3.17 | powershell | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 612 | 105 | $3.88 | powershell | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 659 | 107 | $3.24 | python | ok |
| Process Monitor | default | opus | 9.8min | 115 | 580 | 109 | $2.34 | python | ok |
| Batch File Renamer | default | opus | 33.9min | 106 | 716 | 109 | $2.76 | python | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 829 | 113 | $3.49 | python | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 720 | 114 | $4.00 | powershell | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 829 | 115 | $3.34 | python | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 900 | 117 | $3.32 | powershell | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 931 | 117 | $4.93 | powershell | ok |
| REST API Client | default | opus | 157.1min | 113 | 579 | 118 | $3.08 | python | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 1088 | 121 | $3.76 | csharp | ok |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 1012 | 121 | $4.17 | csharp | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 726 | 124 | $4.56 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 868 | 126 | $4.48 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 481 | 127 | $3.40 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 1244 | 130 | $5.77 | powershell | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 1281 | 130 | $4.56 | csharp | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 496 | 130 | $3.52 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 670 | 130 | $3.72 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 1058 | 132 | $5.03 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 795 | 134 | $5.44 | powershell | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 1009 | 134 | $3.34 | csharp | ok |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 143163 | 139 | $4.60 | csharp | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 810 | 140 | $4.71 | powershell | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 1115 | 140 | $5.61 | powershell | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 870 | 140 | $3.93 |  | ok |
| Database Seed Script | default | opus | 13.1min | 146 | 843 | 141 | $3.83 | python | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 517 | 142 | $3.77 | python | ok |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 1945 | 142 | $6.47 | csharp | ok |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 292 | 143 | $3.46 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 647 | 148 | $5.60 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 990 | 148 | $6.18 | powershell | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 696 | 148 | $4.01 | powershell | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 1412 | 149 | $5.30 | csharp | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 1053 | 150 | $5.11 | python | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 1192 | 159 | $6.38 | powershell | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 1500 | 160 | $6.54 | powershell | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 400 | 162 | $3.82 | python | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 656 | 171 | $4.45 | python | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 713 | 172 | $3.93 | python | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 604 | 176 | $5.79 | powershell | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 1615 | 177 | $7.32 | csharp | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 832 | 188 | $6.00 | csharp | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 1302 | 193 | $8.66 | csharp | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 1067 | 194 | $6.97 | csharp | ok |
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 1316 | 197 | $8.83 | csharp | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 1107 | 203 | $7.33 | csharp | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 818 | 203 | $4.97 | python | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 843 | 205 | $5.43 | javascript | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 851 | 205 | $7.54 | csharp | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 866 | 210 | $7.96 | powershell | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 889 | 220 | $6.00 | python | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 371 | 225 | $4.92 | python | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 18 | 96 | $1.39 | bash | ok |
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 165 | 0 | $0.00 | csharp | failed |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 292 | 143 | $3.46 | powershell | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 297 | 17 | $0.50 | python | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 371 | 225 | $4.92 | python | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 400 | 162 | $3.82 | python | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 421 | 101 | $3.05 | powershell | ok |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 439 | 27 | $0.97 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 454 | 33 | $1.26 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 471 | 49 | $1.17 | powershell | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 476 | 33 | $1.11 | powershell | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 479 | 89 | $3.05 | powershell | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 479 | 17 | $0.92 | powershell | ok |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 481 | 37 | $2.07 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 481 | 127 | $3.40 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 496 | 130 | $3.52 | powershell | ok |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 511 | 25 | $0.65 | python | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 516 | 33 | $0.89 | powershell | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 517 | 142 | $3.77 | python | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 530 | 23 | $0.92 | python | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 542 | 16 | $1.02 | powershell | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 554 | 15 | $0.49 | python | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 555 | 44 | $1.27 | python | ok |
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 555 | 18 | $0.59 | powershell | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 578 | 61 | $1.60 | python | ok |
| REST API Client | default | opus | 157.1min | 113 | 579 | 118 | $3.08 | python | ok |
| Process Monitor | default | opus | 9.8min | 115 | 580 | 109 | $2.34 | python | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 586 | 0 | $0.00 | powershell | failed |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 586 | 19 | $0.58 | python | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 598 | 78 | $3.28 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 604 | 176 | $5.79 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 604 | 41 | $1.75 | powershell | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 605 | 75 | $2.48 | powershell | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 612 | 105 | $3.88 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 624 | 96 | $2.60 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 626 | 30 | $1.38 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 628 | 22 | $1.05 | powershell | ok |
| REST API Client | powershell | opus | 257.5min | 0 | 629 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 636 | 42 | $1.50 | python | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 643 | 38 | $1.34 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 647 | 148 | $5.60 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 648 | 41 | $1.54 | powershell | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 656 | 171 | $4.45 | python | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 659 | 107 | $3.24 | python | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 665 | 90 | $3.26 | powershell | ok |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 669 | 26 | $1.13 | csharp | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 670 | 130 | $3.72 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 678 | 27 | $1.82 | powershell | ok |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 679 | 9 | $0.42 | python | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 696 | 148 | $4.01 | powershell | ok |
| REST API Client | powershell | sonnet | 13.9min | 56 | 699 | 35 | $1.93 | powershell | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 707 | 33 | $1.49 | python | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 713 | 172 | $3.93 | python | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 714 | 58 | $2.16 | python | ok |
| Batch File Renamer | default | opus | 33.9min | 106 | 716 | 109 | $2.76 | python | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 720 | 114 | $4.00 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 721 | 39 | $2.11 | powershell | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 726 | 124 | $4.56 | powershell | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 729 | 39 | $1.18 | python | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 731 | 37 | $1.63 | powershell | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 742 | 28 | $0.98 | python | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 759 | 91 | $2.97 | powershell | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 760 | 88 | $2.28 | csharp | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 773 | 59 | $2.08 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 779 | 40 | $1.84 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 784 | 51 | $1.78 | powershell | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 784 | 90 | $2.83 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 786 | 19 | $0.57 | powershell | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 786 | 21 | $0.71 | python | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 794 | 27 | $1.33 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 795 | 134 | $5.44 | powershell | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 797 | 42 | $1.49 | csharp | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 810 | 140 | $4.71 | powershell | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 813 | 36 | $1.67 | powershell | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 818 | 203 | $4.97 | python | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 829 | 115 | $3.34 | python | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 829 | 22 | $1.16 | csharp | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 829 | 113 | $3.49 | python | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 832 | 188 | $6.00 | csharp | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 843 | 205 | $5.43 | javascript | ok |
| Database Seed Script | default | opus | 13.1min | 146 | 843 | 141 | $3.83 | python | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 847 | 99 | $4.17 | powershell | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 851 | 205 | $7.54 | csharp | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 863 | 22 | $1.37 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 866 | 210 | $7.96 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 868 | 126 | $4.48 | powershell | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 870 | 140 | $3.93 |  | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 879 | 100 | $3.84 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 884 | 53 | $1.52 | powershell | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 889 | 220 | $6.00 | python | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 892 | 66 | $2.39 | csharp | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 900 | 117 | $3.32 | powershell | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 904 | 70 | $3.10 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 907 | 40 | $1.57 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 914 | 6 | $0.80 | powershell | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 925 | 33 | $1.32 | python | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 931 | 117 | $4.93 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 933 | 60 | $2.75 | powershell | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 941 | 103 | $3.17 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 957 | 62 | $2.41 | powershell | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 957 | 95 | $4.26 | csharp | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 965 | 35 | $1.83 | powershell | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 971 | 33 | $1.89 | csharp | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 990 | 148 | $6.18 | powershell | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 992 | 65 | $2.44 | python | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 1009 | 134 | $3.34 | csharp | ok |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 1012 | 121 | $4.17 | csharp | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 1016 | 57 | $2.20 | powershell | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 1018 | 60 | $2.57 | powershell | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 1036 | 85 | $2.67 | csharp | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 1053 | 150 | $5.11 | python | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 1058 | 132 | $5.03 | powershell | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 1063 | 90 | $3.65 | powershell | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 1067 | 194 | $6.97 | csharp | ok |
| REST API Client | powershell-strict | opus | 378.5min | 101 | 1073 | 87 | $4.06 | powershell | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 1088 | 121 | $3.76 | csharp | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 1107 | 203 | $7.33 | csharp | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 1115 | 140 | $5.61 | powershell | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 1126 | 59 | $2.26 | csharp | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 1133 | 63 | $3.91 | csharp | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 1178 | 17 | $1.65 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 1192 | 159 | $6.38 | powershell | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 1204 | 48 | $1.84 | python | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 1237 | 88 | $3.43 | python | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 1244 | 130 | $5.77 | powershell | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 1281 | 130 | $4.56 | csharp | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 1302 | 193 | $8.66 | csharp | ok |
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 1316 | 197 | $8.83 | csharp | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 1340 | 103 | $3.49 | csharp | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 1375 | 59 | $2.01 | python | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 1412 | 149 | $5.30 | csharp | ok |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 1413 | 67 | $3.08 | csharp | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 1446 | 73 | $4.11 | csharp | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 1464 | 29 | $2.32 | csharp | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 1468 | 49 | $2.42 | csharp | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 1500 | 160 | $6.54 | powershell | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 1615 | 177 | $7.32 | csharp | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 1625 | 42 | $2.67 | csharp | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 1834 | 93 | $3.40 | csharp | ok |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 1899 | 0 | $0.00 | csharp | failed |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 1945 | 142 | $6.47 | csharp | ok |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 1947 | 58 | $5.32 | csharp | ok |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 2013 | 0 | $0.00 | csharp | failed |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 143163 | 139 | $4.60 | csharp | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 271.2min | 0 | 165 | 0 | $0.00 | csharp | failed |
| REST API Client | powershell | opus | 257.5min | 0 | 629 | 0 | $0.00 | powershell | failed |
| Config File Migrator | csharp-script | opus | 54.2min | 0 | 1899 | 0 | $0.00 | csharp | failed |
| Database Seed Script | csharp-script | sonnet | 28.1min | 0 | 2013 | 0 | $0.00 | csharp | failed |
| Environment Matrix Generator | powershell-strict | sonnet | 30.0min | 0 | 586 | 0 | $0.00 | powershell | failed |
| Secret Rotation Validator | powershell-strict | sonnet | 7.0min | 13 | 914 | 6 | $0.80 | powershell | ok |
| Directory Tree Sync | default | sonnet | 26.1min | 17 | 679 | 9 | $0.42 | python | ok |
| Docker Image Tag Generator | default | sonnet | 3.8min | 20 | 297 | 17 | $0.50 | python | ok |
| Secret Rotation Validator | default | sonnet | 3.7min | 23 | 586 | 19 | $0.58 | python | ok |
| Multi-file Search and Replace | default | sonnet | 4.5min | 25 | 786 | 21 | $0.71 | python | ok |
| PR Label Assigner | default | sonnet | 6.7min | 26 | 530 | 23 | $0.92 | python | ok |
| Artifact Cleanup Script | default | sonnet | 3.2min | 26 | 554 | 15 | $0.49 | python | ok |
| PR Label Assigner | powershell-strict | sonnet | 8.9min | 28 | 542 | 16 | $1.02 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 6.7min | 30 | 516 | 33 | $0.89 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 23.7min | 31 | 786 | 19 | $0.57 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 3.0min | 33 | 555 | 18 | $0.59 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 12.7min | 35 | 1178 | 17 | $1.65 | powershell | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 7.1min | 35 | 479 | 17 | $0.92 | powershell | ok |
| CSV Report Generator | default | sonnet | 53.2min | 37 | 511 | 25 | $0.65 | python | ok |
| Test Results Aggregator | powershell-strict | sonnet | 14.6min | 37 | 794 | 27 | $1.33 | powershell | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 9.1min | 39 | 829 | 22 | $1.16 | csharp | ok |
| Artifact Cleanup Script | powershell | sonnet | 13.0min | 40 | 731 | 37 | $1.63 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 13.4min | 41 | 678 | 27 | $1.82 | powershell | ok |
| Database Seed Script | default | sonnet | 16.3min | 42 | 742 | 28 | $0.98 | python | ok |
| Error Retry Pipeline | powershell | sonnet | 8.2min | 42 | 628 | 22 | $1.05 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 7.8min | 44 | 454 | 33 | $1.26 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 14.1min | 46 | 721 | 39 | $2.11 | powershell | ok |
| CSV Report Generator | csharp-script | sonnet | 112.8min | 48 | 669 | 26 | $1.13 | csharp | ok |
| Batch File Renamer | powershell-strict | sonnet | 12.6min | 48 | 626 | 30 | $1.38 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 8.8min | 49 | 471 | 49 | $1.17 | powershell | ok |
| CSV Report Generator | powershell | sonnet | 56.1min | 52 | 439 | 27 | $0.97 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 25.2min | 52 | 863 | 22 | $1.37 | powershell | ok |
| Dependency License Checker | default | sonnet | 7.3min | 52 | 729 | 39 | $1.18 | python | ok |
| Environment Matrix Generator | default | sonnet | 8.2min | 52 | 925 | 33 | $1.32 | python | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 13.3min | 52 | 965 | 35 | $1.83 | powershell | ok |
| Process Monitor | powershell | sonnet | 6.6min | 53 | 476 | 33 | $1.11 | powershell | ok |
| REST API Client | default | sonnet | 10.8min | 54 | 707 | 33 | $1.49 | python | ok |
| REST API Client | powershell | sonnet | 13.9min | 56 | 699 | 35 | $1.93 | powershell | ok |
| Batch File Renamer | default | sonnet | 46.7min | 58 | 555 | 44 | $1.27 | python | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 8.7min | 59 | 643 | 38 | $1.34 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 69.6min | 60 | 648 | 41 | $1.54 | powershell | ok |
| Batch File Renamer | csharp-script | sonnet | 19.3min | 60 | 1088 | 121 | $3.76 | csharp | ok |
| Database Seed Script | powershell | sonnet | 12.1min | 60 | 813 | 36 | $1.67 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 12.7min | 60 | 773 | 59 | $2.08 | powershell | ok |
| Process Monitor | csharp-script | sonnet | 13.2min | 61 | 971 | 33 | $1.89 | csharp | ok |
| Secret Rotation Validator | powershell | sonnet | 8.3min | 61 | 884 | 53 | $1.52 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 10.6min | 62 | 784 | 51 | $1.78 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 9.6min | 63 | 907 | 40 | $1.57 | powershell | ok |
| Semantic Version Bumper | csharp-script | sonnet | 17.0min | 64 | 1625 | 42 | $2.67 | csharp | ok |
| Semantic Version Bumper | csharp-script | opus | 6.2min | 65 | 18 | 96 | $1.39 | bash | ok |
| Batch File Renamer | powershell | sonnet | 246.7min | 67 | 481 | 37 | $2.07 | powershell | ok |
| Test Results Aggregator | csharp-script | sonnet | 13.0min | 67 | 1464 | 29 | $2.32 | csharp | ok |
| Config File Migrator | powershell-strict | sonnet | 44.9min | 69 | 779 | 40 | $1.84 | powershell | ok |
| Error Retry Pipeline | default | sonnet | 8.8min | 69 | 636 | 42 | $1.50 | python | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 15.3min | 69 | 957 | 62 | $2.41 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 15.7min | 70 | 1016 | 57 | $2.20 | powershell | ok |
| Error Retry Pipeline | csharp-script | sonnet | 10.1min | 71 | 797 | 42 | $1.49 | csharp | ok |
| Log File Analyzer | default | sonnet | 10.6min | 72 | 1204 | 48 | $1.84 | python | ok |
| CSV Report Generator | powershell-strict | sonnet | 121.6min | 74 | 604 | 41 | $1.75 | powershell | ok |
| REST API Client | csharp-script | sonnet | 23.2min | 74 | 1133 | 63 | $3.91 | csharp | ok |
| Secret Rotation Validator | csharp-script | sonnet | 14.2min | 74 | 1036 | 85 | $2.67 | csharp | ok |
| Process Monitor | default | sonnet | 9.8min | 76 | 578 | 61 | $1.60 | python | ok |
| Test Results Aggregator | default | sonnet | 10.2min | 76 | 1375 | 59 | $2.01 | python | ok |
| Error Retry Pipeline | powershell | opus | 14.6min | 80 | 665 | 90 | $3.26 | powershell | ok |
| Config File Migrator | powershell | sonnet | 52.0min | 81 | 1018 | 60 | $2.57 | powershell | ok |
| Directory Tree Sync | csharp-script | sonnet | 143.8min | 83 | 1468 | 49 | $2.42 | csharp | ok |
| Environment Matrix Generator | csharp-script | sonnet | 12.9min | 85 | 1126 | 59 | $2.26 | csharp | ok |
| Dependency License Checker | powershell-strict | opus | 14.6min | 87 | 933 | 60 | $2.75 | powershell | ok |
| Test Results Aggregator | powershell | opus | 10.2min | 89 | 904 | 70 | $3.10 | powershell | ok |
| Artifact Cleanup Script | powershell | opus | 11.6min | 91 | 784 | 90 | $2.83 | powershell | ok |
| Directory Tree Sync | powershell | opus | 112.3min | 93 | 759 | 91 | $2.97 | powershell | ok |
| PR Label Assigner | powershell | opus | 10.0min | 93 | 605 | 75 | $2.48 | powershell | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 14.6min | 94 | 892 | 66 | $2.39 | csharp | ok |
| Process Monitor | powershell | opus | 14.6min | 96 | 598 | 78 | $3.28 | powershell | ok |
| CSV Report Generator | powershell | opus | 11.4min | 97 | 479 | 89 | $3.05 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 12.9min | 98 | 714 | 58 | $2.16 | python | ok |
| REST API Client | powershell-strict | opus | 378.5min | 101 | 1073 | 87 | $4.06 | powershell | ok |
| Config File Migrator | default | sonnet | 58.5min | 102 | 992 | 65 | $2.44 | python | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 13.3min | 103 | 760 | 88 | $2.28 | csharp | ok |
| Batch File Renamer | powershell | opus | 67.4min | 104 | 900 | 117 | $3.32 | powershell | ok |
| Batch File Renamer | default | opus | 33.9min | 106 | 716 | 109 | $2.76 | python | ok |
| Batch File Renamer | csharp-script | opus | 40.4min | 108 | 1009 | 134 | $3.34 | csharp | ok |
| Secret Rotation Validator | default | opus | 12.2min | 108 | 1237 | 88 | $3.43 | python | ok |
| Docker Image Tag Generator | powershell | opus | 12.4min | 109 | 421 | 101 | $3.05 | powershell | ok |
| Artifact Cleanup Script | default | opus | 12.9min | 110 | 829 | 113 | $3.49 | python | ok |
| REST API Client | default | opus | 157.1min | 113 | 579 | 118 | $3.08 | python | ok |
| Error Retry Pipeline | powershell-strict | opus | 11.1min | 114 | 941 | 103 | $3.17 | powershell | ok |
| Process Monitor | default | opus | 9.8min | 115 | 580 | 109 | $2.34 | python | ok |
| Config File Migrator | powershell | opus | 12.6min | 115 | 1063 | 90 | $3.65 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 13.7min | 116 | 624 | 96 | $2.60 | powershell | ok |
| Dependency License Checker | powershell | opus | 14.9min | 118 | 847 | 99 | $4.17 | powershell | ok |
| Environment Matrix Generator | default | opus | 15.5min | 119 | 713 | 172 | $3.93 | python | ok |
| Semantic Version Bumper | powershell | opus | 13.3min | 120 | 879 | 100 | $3.84 | powershell | ok |
| Test Results Aggregator | csharp-script | opus | 11.7min | 120 | 1834 | 93 | $3.40 | csharp | ok |
| Directory Tree Sync | default | opus | 44.4min | 122 | 659 | 107 | $3.24 | python | ok |
| Database Seed Script | csharp-script | opus | 11.4min | 122 | 1340 | 103 | $3.49 | csharp | ok |
| Log File Analyzer | powershell | opus | 143.9min | 123 | 612 | 105 | $3.88 | powershell | ok |
| Process Monitor | powershell-strict | opus | 15.3min | 126 | 720 | 114 | $4.00 | powershell | ok |
| Multi-file Search and Replace | powershell | opus | 17.1min | 126 | 726 | 124 | $4.56 | powershell | ok |
| Dependency License Checker | csharp-script | sonnet | 26.6min | 126 | 1413 | 67 | $3.08 | csharp | ok |
| Multi-file Search and Replace | powershell-strict | opus | 12.2min | 129 | 496 | 130 | $3.52 | powershell | ok |
| Semantic Version Bumper | default | opus | 12.0min | 129 | 829 | 115 | $3.34 | python | ok |
| Docker Image Tag Generator | powershell-strict | opus | 12.2min | 130 | 481 | 127 | $3.40 | powershell | ok |
| Log File Analyzer | csharp-script | sonnet | 25.4min | 131 | 1446 | 73 | $4.11 | csharp | ok |
| Artifact Cleanup Script | csharp-script | opus | 17.9min | 131 | 1012 | 121 | $4.17 | csharp | ok |
| Multi-file Search and Replace | csharp-script | opus | 17.3min | 134 | 1281 | 130 | $4.56 | csharp | ok |
| Artifact Cleanup Script | powershell-strict | opus | 16.7min | 135 | 1058 | 132 | $5.03 | powershell | ok |
| Secret Rotation Validator | powershell | opus | 15.4min | 136 | 696 | 148 | $4.01 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 16.8min | 137 | 868 | 126 | $4.48 | powershell | ok |
| Config File Migrator | csharp-script | sonnet | 73.6min | 138 | 1947 | 58 | $5.32 | csharp | ok |
| Directory Tree Sync | powershell-strict | opus | 144.7min | 140 | 810 | 140 | $4.71 | powershell | ok |
| PR Label Assigner | default | opus | 16.1min | 140 | 517 | 142 | $3.77 | python | ok |
| PR Label Assigner | powershell-strict | opus | 11.1min | 141 | 670 | 130 | $3.72 | powershell | ok |
| PR Label Assigner | csharp-script | sonnet | 21.0min | 143 | 957 | 95 | $4.26 | csharp | ok |
| Database Seed Script | default | opus | 13.1min | 146 | 843 | 141 | $3.83 | python | ok |
| Environment Matrix Generator | powershell | opus | 14.9min | 148 | 931 | 117 | $4.93 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 16.2min | 154 | 1244 | 130 | $5.77 | powershell | ok |
| Docker Image Tag Generator | csharp-script | opus | 16.6min | 154 | 143163 | 139 | $4.60 | csharp | ok |
| Log File Analyzer | powershell-strict | opus | 128.9min | 155 | 795 | 134 | $5.44 | powershell | ok |
| Error Retry Pipeline | default | opus | 17.1min | 156 | 870 | 140 | $3.93 |  | ok |
| Docker Image Tag Generator | default | opus | 15.3min | 156 | 400 | 162 | $3.82 | python | ok |
| Database Seed Script | powershell-strict | opus | 19.8min | 162 | 1500 | 160 | $6.54 | powershell | ok |
| Secret Rotation Validator | csharp-script | opus | 17.2min | 162 | 1412 | 149 | $5.30 | csharp | ok |
| Batch File Renamer | powershell-strict | opus | 76.3min | 163 | 647 | 148 | $5.60 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 18.6min | 164 | 990 | 148 | $6.18 | powershell | ok |
| Config File Migrator | default | opus | 16.7min | 165 | 1053 | 150 | $5.11 | python | ok |
| Database Seed Script | powershell | opus | 14.4min | 167 | 1115 | 140 | $5.61 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 16.2min | 168 | 604 | 176 | $5.79 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 13.5min | 169 | 292 | 143 | $3.46 | powershell | ok |
| Test Results Aggregator | default | opus | 16.9min | 172 | 818 | 203 | $4.97 | python | ok |
| Error Retry Pipeline | csharp-script | opus | 26.0min | 173 | 1067 | 194 | $6.97 | csharp | ok |
| Environment Matrix Generator | csharp-script | opus | 21.0min | 175 | 1945 | 142 | $6.47 | csharp | ok |
| Secret Rotation Validator | powershell-strict | opus | 23.4min | 175 | 1192 | 159 | $6.38 | powershell | ok |
| Multi-file Search and Replace | default | opus | 15.9min | 181 | 656 | 171 | $4.45 | python | ok |
| Process Monitor | csharp-script | opus | 21.7min | 182 | 832 | 188 | $6.00 | csharp | ok |
| Log File Analyzer | default | opus | 105.3min | 195 | 843 | 205 | $5.43 | javascript | ok |
| REST API Client | csharp-script | opus | 22.6min | 195 | 1615 | 177 | $7.32 | csharp | ok |
| PR Label Assigner | csharp-script | opus | 21.5min | 215 | 1107 | 203 | $7.33 | csharp | ok |
| Dependency License Checker | default | opus | 17.2min | 217 | 889 | 220 | $6.00 | python | ok |
| Log File Analyzer | csharp-script | opus | 168.4min | 221 | 1302 | 193 | $8.66 | csharp | ok |
| CSV Report Generator | default | opus | 23.8min | 222 | 371 | 225 | $4.92 | python | ok |
| Dependency License Checker | csharp-script | opus | 21.8min | 223 | 1316 | 197 | $8.83 | csharp | ok |
| Semantic Version Bumper | powershell-strict | opus | 18.5min | 225 | 866 | 210 | $7.96 | powershell | ok |
| Directory Tree Sync | csharp-script | opus | 202.0min | 229 | 851 | 205 | $7.54 | csharp | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v1*