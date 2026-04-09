# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 10:36:00 AM ET

**Status:** 144/144 runs completed, 0 remaining
**Total cost so far:** $436.67
**Total agent time so far:** 305888s (5098.1 min)

## Failed / Timed-Out Runs

| Task | Mode | Model | Duration | Reason | Lines | actionlint | act-result.txt |
|------|------|-------|----------|--------|-------|------------|----------------|
| CSV Report Generator | csharp-script | opus | 16271s | exit_code=-1 | 165 | n/a | no |
| REST API Client | powershell | opus | 15450s | exit_code=-1 | 629 | n/a | no |
| Config File Migrator | csharp-script | opus | 3254s | exit_code=-1 | 1899 | n/a | no |
| Database Seed Script | csharp-script | sonnet | 1687s | exit_code=-1 | 2013 | n/a | no |
| Environment Matrix Generator | powershell-strict | sonnet | 1800s | exit_code=-1 | 586 | n/a | no |

*5 run(s) excluded from averages below.*

## Comparison by Language/Model
*(averages exclude failed/timed-out runs)*

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | opus | 16 | 2414s | 10069 | 154.0 | 163 | $5.59 | $89.38 |
| csharp-script | sonnet | 17 | 1987s | 1154 | 59.9 | 86 | $2.77 | $47.12 |
| default | opus | 18 | 1851s | 745 | 149.4 | 148 | $3.99 | $71.84 |
| default | sonnet | 18 | 1004s | 728 | 35.5 | 51 | $1.23 | $22.08 |
| powershell | opus | 17 | 1803s | 764 | 101.4 | 112 | $3.65 | $61.98 |
| powershell | sonnet | 18 | 1867s | 634 | 46.9 | 63 | $1.63 | $29.38 |
| powershell-strict | opus | 18 | 3170s | 883 | 134.1 | 145 | $4.92 | $88.48 |
| powershell-strict | sonnet | 17 | 1311s | 783 | 32.5 | 48 | $1.55 | $26.42 |


<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | sonnet | 18 | 1004s | 728 | 35.5 | 51 | $1.23 | $22.08 |
| powershell-strict | sonnet | 17 | 1311s | 783 | 32.5 | 48 | $1.55 | $26.42 |
| powershell | opus | 17 | 1803s | 764 | 101.4 | 112 | $3.65 | $61.98 |
| default | opus | 18 | 1851s | 745 | 149.4 | 148 | $3.99 | $71.84 |
| powershell | sonnet | 18 | 1867s | 634 | 46.9 | 63 | $1.63 | $29.38 |
| csharp-script | sonnet | 17 | 1987s | 1154 | 59.9 | 86 | $2.77 | $47.12 |
| csharp-script | opus | 16 | 2414s | 10069 | 154.0 | 163 | $5.59 | $89.38 |
| powershell-strict | opus | 18 | 3170s | 883 | 134.1 | 145 | $4.92 | $88.48 |

</details>

<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | sonnet | 18 | 1004s | 728 | 35.5 | 51 | $1.23 | $22.08 |
| powershell-strict | sonnet | 17 | 1311s | 783 | 32.5 | 48 | $1.55 | $26.42 |
| powershell | sonnet | 18 | 1867s | 634 | 46.9 | 63 | $1.63 | $29.38 |
| csharp-script | sonnet | 17 | 1987s | 1154 | 59.9 | 86 | $2.77 | $47.12 |
| powershell | opus | 17 | 1803s | 764 | 101.4 | 112 | $3.65 | $61.98 |
| default | opus | 18 | 1851s | 745 | 149.4 | 148 | $3.99 | $71.84 |
| powershell-strict | opus | 18 | 3170s | 883 | 134.1 | 145 | $4.92 | $88.48 |
| csharp-script | opus | 16 | 2414s | 10069 | 154.0 | 163 | $5.59 | $89.38 |

</details>

<details>
<summary>Sorted by avg errors (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | opus | 16 | 2414s | 10069 | 154.0 | 163 | $5.59 | $89.38 |
| default | opus | 18 | 1851s | 745 | 149.4 | 148 | $3.99 | $71.84 |
| powershell-strict | opus | 18 | 3170s | 883 | 134.1 | 145 | $4.92 | $88.48 |
| powershell | opus | 17 | 1803s | 764 | 101.4 | 112 | $3.65 | $61.98 |
| csharp-script | sonnet | 17 | 1987s | 1154 | 59.9 | 86 | $2.77 | $47.12 |
| powershell | sonnet | 18 | 1867s | 634 | 46.9 | 63 | $1.63 | $29.38 |
| default | sonnet | 18 | 1004s | 728 | 35.5 | 51 | $1.23 | $22.08 |
| powershell-strict | sonnet | 17 | 1311s | 783 | 32.5 | 48 | $1.55 | $26.42 |

</details>

<details>
<summary>Sorted by total cost (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | opus | 16 | 2414s | 10069 | 154.0 | 163 | $5.59 | $89.38 |
| powershell-strict | opus | 18 | 3170s | 883 | 134.1 | 145 | $4.92 | $88.48 |
| default | opus | 18 | 1851s | 745 | 149.4 | 148 | $3.99 | $71.84 |
| powershell | opus | 17 | 1803s | 764 | 101.4 | 112 | $3.65 | $61.98 |
| csharp-script | sonnet | 17 | 1987s | 1154 | 59.9 | 86 | $2.77 | $47.12 |
| powershell | sonnet | 18 | 1867s | 634 | 46.9 | 63 | $1.63 | $29.38 |
| powershell-strict | sonnet | 17 | 1311s | 783 | 32.5 | 48 | $1.55 | $26.42 |
| default | sonnet | 18 | 1004s | 728 | 35.5 | 51 | $1.23 | $22.08 |

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
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|

</details>

<details>
<summary>Sorted by overhead (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|

</details>

<details>
<summary>Sorted by test run time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 125 | $11.01 | 2.52% |
| Miss | 14 | $0.00 | 0.00% |
| **Total** | **139** | **$11.01** | **2.52%** |

### Trap Analysis by Category

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 144 | 164 | -20 | 114% | 876.0min | 17.2% | $205.34 | 47.02% |
| act-permission-path-errors | 144 | 55 | 89 | 38% | 95.5min | 1.9% | $19.09 | 4.37% |
| fixture-rework | 144 | 5 | 139 | 3% | 31.0min | 0.6% | $7.97 | 1.83% |
| **Total** | | **100 runs** | | **69%** | **1002.5min** | **19.7%** | **$232.40** | **53.22%** |


<details>
<summary>Sorted by $ lost (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 144 | 164 | -20 | 114% | 876.0min | 17.2% | $205.34 | 47.02% |
| act-permission-path-errors | 144 | 55 | 89 | 38% | 95.5min | 1.9% | $19.09 | 4.37% |
| fixture-rework | 144 | 5 | 139 | 3% | 31.0min | 0.6% | $7.97 | 1.83% |

</details>

<details>
<summary>Sorted by rate (highest first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 144 | 164 | -20 | 114% | 876.0min | 17.2% | $205.34 | 47.02% |
| act-permission-path-errors | 144 | 55 | 89 | 38% | 95.5min | 1.9% | $19.09 | 4.37% |
| fixture-rework | 144 | 5 | 139 | 3% | 31.0min | 0.6% | $7.97 | 1.83% |

</details>

<details>
<summary>Sorted by runs affected (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 144 | 164 | -20 | 114% | 876.0min | 17.2% | $205.34 | 47.02% |
| act-permission-path-errors | 144 | 55 | 89 | 38% | 95.5min | 1.9% | $19.09 | 4.37% |
| fixture-rework | 144 | 5 | 139 | 3% | 31.0min | 0.6% | $7.97 | 1.83% |

</details>

### Traps by Language/Model

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 18 | 15 | 83% | 15 | 45.0min | 0.9% | $8.99 | 2.06% |
| csharp-script | sonnet | 18 | 3 | 17% | 3 | 3.0min | 0.1% | $0.51 | 0.12% |
| default | opus | 18 | 17 | 94% | 41 | 349.8min | 6.9% | $85.59 | 19.60% |
| default | sonnet | 18 | 11 | 61% | 20 | 26.6min | 0.5% | $3.52 | 0.81% |
| powershell | opus | 18 | 17 | 94% | 55 | 222.6min | 4.4% | $52.40 | 12.00% |
| powershell | sonnet | 18 | 13 | 72% | 22 | 31.1min | 0.6% | $5.24 | 1.20% |
| powershell-strict | opus | 18 | 17 | 94% | 58 | 314.4min | 6.2% | $75.22 | 17.23% |
| powershell-strict | sonnet | 18 | 7 | 39% | 10 | 10.0min | 0.2% | $0.92 | 0.21% |
| **Total** | | **144** | **100** | **69%** | **224** | **1002.5min** | **19.7%** | **$232.40** | **53.22%** |


<details>
<summary>Sorted by time lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 18 | 17 | 94% | 41 | 349.8min | 6.9% | $85.59 | 19.60% |
| powershell-strict | opus | 18 | 17 | 94% | 58 | 314.4min | 6.2% | $75.22 | 17.23% |
| powershell | opus | 18 | 17 | 94% | 55 | 222.6min | 4.4% | $52.40 | 12.00% |
| csharp-script | opus | 18 | 15 | 83% | 15 | 45.0min | 0.9% | $8.99 | 2.06% |
| powershell | sonnet | 18 | 13 | 72% | 22 | 31.1min | 0.6% | $5.24 | 1.20% |
| default | sonnet | 18 | 11 | 61% | 20 | 26.6min | 0.5% | $3.52 | 0.81% |
| powershell-strict | sonnet | 18 | 7 | 39% | 10 | 10.0min | 0.2% | $0.92 | 0.21% |
| csharp-script | sonnet | 18 | 3 | 17% | 3 | 3.0min | 0.1% | $0.51 | 0.12% |

</details>

<details>
<summary>Sorted by $ lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 18 | 17 | 94% | 41 | 349.8min | 6.9% | $85.59 | 19.60% |
| powershell-strict | opus | 18 | 17 | 94% | 58 | 314.4min | 6.2% | $75.22 | 17.23% |
| powershell | opus | 18 | 17 | 94% | 55 | 222.6min | 4.4% | $52.40 | 12.00% |
| csharp-script | opus | 18 | 15 | 83% | 15 | 45.0min | 0.9% | $8.99 | 2.06% |
| powershell | sonnet | 18 | 13 | 72% | 22 | 31.1min | 0.6% | $5.24 | 1.20% |
| default | sonnet | 18 | 11 | 61% | 20 | 26.6min | 0.5% | $3.52 | 0.81% |
| powershell-strict | sonnet | 18 | 7 | 39% | 10 | 10.0min | 0.2% | $0.92 | 0.21% |
| csharp-script | sonnet | 18 | 3 | 17% | 3 | 3.0min | 0.1% | $0.51 | 0.12% |

</details>

<details>
<summary>Sorted by trap rate (highest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 18 | 17 | 94% | 41 | 349.8min | 6.9% | $85.59 | 19.60% |
| powershell | opus | 18 | 17 | 94% | 55 | 222.6min | 4.4% | $52.40 | 12.00% |
| powershell-strict | opus | 18 | 17 | 94% | 58 | 314.4min | 6.2% | $75.22 | 17.23% |
| csharp-script | opus | 18 | 15 | 83% | 15 | 45.0min | 0.9% | $8.99 | 2.06% |
| powershell | sonnet | 18 | 13 | 72% | 22 | 31.1min | 0.6% | $5.24 | 1.20% |
| default | sonnet | 18 | 11 | 61% | 20 | 26.6min | 0.5% | $3.52 | 0.81% |
| powershell-strict | sonnet | 18 | 7 | 39% | 10 | 10.0min | 0.2% | $0.92 | 0.21% |
| csharp-script | sonnet | 18 | 3 | 17% | 3 | 3.0min | 0.1% | $0.51 | 0.12% |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 16271s | 0 | 165 | 0 | $0.00 | csharp | failed |
| CSV Report Generator | csharp-script | sonnet | 6765s | 48 | 669 | 26 | $1.13 | csharp | ok |
| CSV Report Generator | default | opus | 1430s | 222 | 371 | 225 | $4.92 | python | ok |
| CSV Report Generator | default | sonnet | 3190s | 37 | 511 | 25 | $0.65 | python | ok |
| CSV Report Generator | powershell | opus | 686s | 97 | 479 | 89 | $3.05 | powershell | ok |
| CSV Report Generator | powershell | sonnet | 3368s | 52 | 439 | 27 | $0.97 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 971s | 168 | 604 | 176 | $5.79 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 7297s | 74 | 604 | 41 | $1.75 | powershell | ok |
| Log File Analyzer | csharp-script | opus | 10102s | 221 | 1302 | 193 | $8.66 | csharp | ok |
| Log File Analyzer | csharp-script | sonnet | 1525s | 131 | 1446 | 73 | $4.11 | csharp | ok |
| Log File Analyzer | default | opus | 6317s | 195 | 843 | 205 | $5.43 | javascript | ok |
| Log File Analyzer | default | sonnet | 634s | 72 | 1204 | 48 | $1.84 | python | ok |
| Log File Analyzer | powershell | opus | 8633s | 123 | 612 | 105 | $3.88 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 634s | 62 | 784 | 51 | $1.78 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 7731s | 155 | 795 | 134 | $5.44 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 1513s | 52 | 863 | 22 | $1.37 | powershell | ok |
| Directory Tree Sync | csharp-script | opus | 12122s | 229 | 851 | 205 | $7.54 | csharp | ok |
| Directory Tree Sync | csharp-script | sonnet | 8628s | 83 | 1468 | 49 | $2.42 | csharp | ok |
| Directory Tree Sync | default | opus | 2661s | 122 | 659 | 107 | $3.24 | python | ok |
| Directory Tree Sync | default | sonnet | 1566s | 17 | 679 | 9 | $0.42 | python | ok |
| Directory Tree Sync | powershell | opus | 6736s | 93 | 759 | 91 | $2.97 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 4174s | 60 | 648 | 41 | $1.54 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus | 8683s | 140 | 810 | 140 | $4.71 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 1423s | 31 | 786 | 19 | $0.57 | powershell | ok |
| REST API Client | csharp-script | opus | 1358s | 195 | 1615 | 177 | $7.32 | csharp | ok |
| REST API Client | csharp-script | sonnet | 1394s | 74 | 1133 | 63 | $3.91 | csharp | ok |
| REST API Client | default | opus | 9428s | 113 | 579 | 118 | $3.08 | python | ok |
| REST API Client | default | sonnet | 648s | 54 | 707 | 33 | $1.49 | python | ok |
| REST API Client | powershell | opus | 15450s | 0 | 629 | 0 | $0.00 | powershell | failed |
| REST API Client | powershell | sonnet | 832s | 56 | 699 | 35 | $1.93 | powershell | ok |
| REST API Client | powershell-strict | opus | 22713s | 101 | 1073 | 87 | $4.06 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 805s | 41 | 678 | 27 | $1.82 | powershell | ok |
| Process Monitor | csharp-script | opus | 1299s | 182 | 832 | 188 | $6.00 | csharp | ok |
| Process Monitor | csharp-script | sonnet | 791s | 61 | 971 | 33 | $1.89 | csharp | ok |
| Process Monitor | default | opus | 591s | 115 | 580 | 109 | $2.34 | python | ok |
| Process Monitor | default | sonnet | 589s | 76 | 578 | 61 | $1.60 | python | ok |
| Process Monitor | powershell | opus | 875s | 96 | 598 | 78 | $3.28 | powershell | ok |
| Process Monitor | powershell | sonnet | 397s | 53 | 476 | 33 | $1.11 | powershell | ok |
| Process Monitor | powershell-strict | opus | 918s | 126 | 720 | 114 | $4.00 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 846s | 46 | 721 | 39 | $2.11 | powershell | ok |
| Config File Migrator | csharp-script | opus | 3254s | 0 | 1899 | 0 | $0.00 | csharp | failed |
| Config File Migrator | csharp-script | sonnet | 4419s | 138 | 1947 | 58 | $5.32 | csharp | ok |
| Config File Migrator | default | opus | 1004s | 165 | 1053 | 150 | $5.11 | python | ok |
| Config File Migrator | default | sonnet | 3510s | 102 | 992 | 65 | $2.44 | python | ok |
| Config File Migrator | powershell | opus | 753s | 115 | 1063 | 90 | $3.65 | powershell | ok |
| Config File Migrator | powershell | sonnet | 3123s | 81 | 1018 | 60 | $2.57 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 972s | 154 | 1244 | 130 | $5.77 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet | 2694s | 69 | 779 | 40 | $1.84 | powershell | ok |
| Batch File Renamer | csharp-script | opus | 2425s | 108 | 1009 | 134 | $3.34 | csharp | ok |
| Batch File Renamer | csharp-script | sonnet | 1156s | 60 | 1088 | 121 | $3.76 | csharp | ok |
| Batch File Renamer | default | opus | 2033s | 106 | 716 | 109 | $2.76 | python | ok |
| Batch File Renamer | default | sonnet | 2802s | 58 | 555 | 44 | $1.27 | python | ok |
| Batch File Renamer | powershell | opus | 4044s | 104 | 900 | 117 | $3.32 | powershell | ok |
| Batch File Renamer | powershell | sonnet | 14801s | 67 | 481 | 37 | $2.07 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 4577s | 163 | 647 | 148 | $5.60 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 754s | 48 | 626 | 30 | $1.38 | powershell | ok |
| Database Seed Script | csharp-script | opus | 684s | 122 | 1340 | 103 | $3.49 | csharp | ok |
| Database Seed Script | csharp-script | sonnet | 1687s | 0 | 2013 | 0 | $0.00 | csharp | failed |
| Database Seed Script | default | opus | 788s | 146 | 843 | 141 | $3.83 | python | ok |
| Database Seed Script | default | sonnet | 978s | 42 | 742 | 28 | $0.98 | python | ok |
| Database Seed Script | powershell | opus | 863s | 167 | 1115 | 140 | $5.61 | powershell | ok |
| Database Seed Script | powershell | sonnet | 724s | 60 | 813 | 36 | $1.67 | powershell | ok |
| Database Seed Script | powershell-strict | opus | 1188s | 162 | 1500 | 160 | $6.54 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 763s | 35 | 1178 | 17 | $1.65 | powershell | ok |
| Error Retry Pipeline | csharp-script | opus | 1562s | 173 | 1067 | 194 | $6.97 | csharp | ok |
| Error Retry Pipeline | csharp-script | sonnet | 607s | 71 | 797 | 42 | $1.49 | csharp | ok |
| Error Retry Pipeline | default | opus | 1024s | 156 | 870 | 140 | $3.93 |  | ok |
| Error Retry Pipeline | default | sonnet | 530s | 69 | 636 | 42 | $1.50 | python | ok |
| Error Retry Pipeline | powershell | opus | 877s | 80 | 665 | 90 | $3.26 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 492s | 42 | 628 | 22 | $1.05 | powershell | ok |
| Error Retry Pipeline | powershell-strict | opus | 668s | 114 | 941 | 103 | $3.17 | powershell | ok |
| Error Retry Pipeline | powershell-strict | sonnet | 427s | 35 | 479 | 17 | $0.92 | powershell | ok |
| Multi-file Search and Replace | csharp-script | opus | 1040s | 134 | 1281 | 130 | $4.56 | csharp | ok |
| Multi-file Search and Replace | csharp-script | sonnet | 875s | 94 | 892 | 66 | $2.39 | csharp | ok |
| Multi-file Search and Replace | default | opus | 953s | 181 | 656 | 171 | $4.45 | python | ok |
| Multi-file Search and Replace | default | sonnet | 270s | 25 | 786 | 21 | $0.71 | python | ok |
| Multi-file Search and Replace | powershell | opus | 1026s | 126 | 726 | 124 | $4.56 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 527s | 49 | 471 | 49 | $1.17 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 730s | 129 | 496 | 130 | $3.52 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 919s | 69 | 957 | 62 | $2.41 | powershell | ok |
| Semantic Version Bumper | csharp-script | opus | 369s | 65 | 18 | 96 | $1.39 | bash | ok |
| Semantic Version Bumper | csharp-script | sonnet | 1022s | 64 | 1625 | 42 | $2.67 | csharp | ok |
| Semantic Version Bumper | default | opus | 719s | 129 | 829 | 115 | $3.34 | python | ok |
| Semantic Version Bumper | default | sonnet | 775s | 98 | 714 | 58 | $2.16 | python | ok |
| Semantic Version Bumper | powershell | opus | 798s | 120 | 879 | 100 | $3.84 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 820s | 116 | 624 | 96 | $2.60 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 1111s | 225 | 866 | 210 | $7.96 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 760s | 60 | 773 | 59 | $2.08 | powershell | ok |
| PR Label Assigner | csharp-script | opus | 1290s | 215 | 1107 | 203 | $7.33 | csharp | ok |
| PR Label Assigner | csharp-script | sonnet | 1259s | 143 | 957 | 95 | $4.26 | csharp | ok |
| PR Label Assigner | default | opus | 965s | 140 | 517 | 142 | $3.77 | python | ok |
| PR Label Assigner | default | sonnet | 401s | 26 | 530 | 23 | $0.92 | python | ok |
| PR Label Assigner | powershell | opus | 598s | 93 | 605 | 75 | $2.48 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 467s | 44 | 454 | 33 | $1.26 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 667s | 141 | 670 | 130 | $3.72 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet | 531s | 28 | 542 | 16 | $1.02 | powershell | ok |
| Dependency License Checker | csharp-script | opus | 1311s | 223 | 1316 | 197 | $8.83 | csharp | ok |
| Dependency License Checker | csharp-script | sonnet | 1596s | 126 | 1413 | 67 | $3.08 | csharp | ok |
| Dependency License Checker | default | opus | 1032s | 217 | 889 | 220 | $6.00 | python | ok |
| Dependency License Checker | default | sonnet | 435s | 52 | 729 | 39 | $1.18 | python | ok |
| Dependency License Checker | powershell | opus | 896s | 118 | 847 | 99 | $4.17 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 181s | 33 | 555 | 18 | $0.59 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 876s | 87 | 933 | 60 | $2.75 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 943s | 70 | 1016 | 57 | $2.20 | powershell | ok |
| Docker Image Tag Generator | csharp-script | opus | 994s | 154 | 143163 | 139 | $4.60 | csharp | ok |
| Docker Image Tag Generator | csharp-script | sonnet | 797s | 103 | 760 | 88 | $2.28 | csharp | ok |
| Docker Image Tag Generator | default | opus | 920s | 156 | 400 | 162 | $3.82 | python | ok |
| Docker Image Tag Generator | default | sonnet | 229s | 20 | 297 | 17 | $0.50 | python | ok |
| Docker Image Tag Generator | powershell | opus | 745s | 109 | 421 | 101 | $3.05 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 808s | 169 | 292 | 143 | $3.46 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 731s | 130 | 481 | 127 | $3.40 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 522s | 59 | 643 | 38 | $1.34 | powershell | ok |
| Test Results Aggregator | csharp-script | opus | 704s | 120 | 1834 | 93 | $3.40 | csharp | ok |
| Test Results Aggregator | csharp-script | sonnet | 780s | 67 | 1464 | 29 | $2.32 | csharp | ok |
| Test Results Aggregator | default | opus | 1014s | 172 | 818 | 203 | $4.97 | python | ok |
| Test Results Aggregator | default | sonnet | 612s | 76 | 1375 | 59 | $2.01 | python | ok |
| Test Results Aggregator | powershell | opus | 610s | 89 | 904 | 70 | $3.10 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 575s | 63 | 907 | 40 | $1.57 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 1113s | 164 | 990 | 148 | $6.18 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 874s | 37 | 794 | 27 | $1.33 | powershell | ok |
| Environment Matrix Generator | csharp-script | opus | 1260s | 175 | 1945 | 142 | $6.47 | csharp | ok |
| Environment Matrix Generator | csharp-script | sonnet | 773s | 85 | 1126 | 59 | $2.26 | csharp | ok |
| Environment Matrix Generator | default | opus | 929s | 119 | 713 | 172 | $3.93 | python | ok |
| Environment Matrix Generator | default | sonnet | 492s | 52 | 925 | 33 | $1.32 | python | ok |
| Environment Matrix Generator | powershell | opus | 897s | 148 | 931 | 117 | $4.93 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 402s | 30 | 516 | 33 | $0.89 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 1007s | 137 | 868 | 126 | $4.48 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 1800s | 0 | 586 | 0 | $0.00 | powershell | failed |
| Artifact Cleanup Script | csharp-script | opus | 1074s | 131 | 1012 | 121 | $4.17 | csharp | ok |
| Artifact Cleanup Script | csharp-script | sonnet | 548s | 39 | 829 | 22 | $1.16 | csharp | ok |
| Artifact Cleanup Script | default | opus | 775s | 110 | 829 | 113 | $3.49 | python | ok |
| Artifact Cleanup Script | default | sonnet | 194s | 26 | 554 | 15 | $0.49 | python | ok |
| Artifact Cleanup Script | powershell | opus | 698s | 91 | 784 | 90 | $2.83 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 782s | 40 | 731 | 37 | $1.63 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus | 1000s | 135 | 1058 | 132 | $5.03 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 801s | 52 | 965 | 35 | $1.83 | powershell | ok |
| Secret Rotation Validator | csharp-script | opus | 1034s | 162 | 1412 | 149 | $5.30 | csharp | ok |
| Secret Rotation Validator | csharp-script | sonnet | 851s | 74 | 1036 | 85 | $2.67 | csharp | ok |
| Secret Rotation Validator | default | opus | 734s | 108 | 1237 | 88 | $3.43 | python | ok |
| Secret Rotation Validator | default | sonnet | 224s | 23 | 586 | 19 | $0.58 | python | ok |
| Secret Rotation Validator | powershell | opus | 926s | 136 | 696 | 148 | $4.01 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 498s | 61 | 884 | 53 | $1.52 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus | 1402s | 175 | 1192 | 159 | $6.38 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 423s | 13 | 914 | 6 | $0.80 | powershell | ok |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Δ | Def Cost | Mode Cost | Cost Δ | Err Δ |
|------|-------|------|-------------|---------|----------|-------|----------|-----------|--------|-------|
| CSV Report Generator | opus | powershell | python | 1430s | 686s | -52% | $4.92 | $3.05 | -38% | -136 |
| CSV Report Generator | opus | powershell-strict | python | 1430s | 971s | -32% | $4.92 | $5.79 | +18% | -49 |
| CSV Report Generator | sonnet | csharp-script | python | 3190s | 6765s | +112% | $0.65 | $1.13 | +73% | +1 |
| CSV Report Generator | sonnet | powershell | python | 3190s | 3368s | +6% | $0.65 | $0.97 | +49% | +2 |
| CSV Report Generator | sonnet | powershell-strict | python | 3190s | 7297s | +129% | $0.65 | $1.75 | +168% | +16 |
| Log File Analyzer | opus | csharp-script | javascript | 6317s | 10102s | +60% | $5.43 | $8.66 | +59% | -12 |
| Log File Analyzer | opus | powershell | javascript | 6317s | 8633s | +37% | $5.43 | $3.88 | -29% | -100 |
| Log File Analyzer | opus | powershell-strict | javascript | 6317s | 7731s | +22% | $5.43 | $5.44 | +0% | -71 |
| Log File Analyzer | sonnet | csharp-script | python | 634s | 1525s | +140% | $1.84 | $4.11 | +124% | +25 |
| Log File Analyzer | sonnet | powershell | python | 634s | 634s | +0% | $1.84 | $1.78 | -3% | +3 |
| Log File Analyzer | sonnet | powershell-strict | python | 634s | 1513s | +138% | $1.84 | $1.37 | -25% | -26 |
| Directory Tree Sync | opus | csharp-script | python | 2661s | 12122s | +355% | $3.24 | $7.54 | +133% | +98 |
| Directory Tree Sync | opus | powershell | python | 2661s | 6736s | +153% | $3.24 | $2.97 | -8% | -16 |
| Directory Tree Sync | opus | powershell-strict | python | 2661s | 8683s | +226% | $3.24 | $4.71 | +45% | +33 |
| Directory Tree Sync | sonnet | csharp-script | python | 1566s | 8628s | +451% | $0.42 | $2.42 | +479% | +40 |
| Directory Tree Sync | sonnet | powershell | python | 1566s | 4174s | +167% | $0.42 | $1.54 | +268% | +32 |
| Directory Tree Sync | sonnet | powershell-strict | python | 1566s | 1423s | -9% | $0.42 | $0.57 | +36% | +10 |
| REST API Client | opus | csharp-script | python | 9428s | 1358s | -86% | $3.08 | $7.32 | +138% | +59 |
| REST API Client | opus | powershell-strict | python | 9428s | 22713s | +141% | $3.08 | $4.06 | +32% | -31 |
| REST API Client | sonnet | csharp-script | python | 648s | 1394s | +115% | $1.49 | $3.91 | +162% | +30 |
| REST API Client | sonnet | powershell | python | 648s | 832s | +28% | $1.49 | $1.93 | +30% | +2 |
| REST API Client | sonnet | powershell-strict | python | 648s | 805s | +24% | $1.49 | $1.82 | +22% | -6 |
| Process Monitor | opus | csharp-script | python | 591s | 1299s | +120% | $2.34 | $6.00 | +157% | +79 |
| Process Monitor | opus | powershell | python | 591s | 875s | +48% | $2.34 | $3.28 | +40% | -31 |
| Process Monitor | opus | powershell-strict | python | 591s | 918s | +55% | $2.34 | $4.00 | +71% | +5 |
| Process Monitor | sonnet | csharp-script | python | 589s | 791s | +34% | $1.60 | $1.89 | +18% | -28 |
| Process Monitor | sonnet | powershell | python | 589s | 397s | -33% | $1.60 | $1.11 | -31% | -28 |
| Process Monitor | sonnet | powershell-strict | python | 589s | 846s | +44% | $1.60 | $2.11 | +32% | -22 |
| Config File Migrator | opus | powershell | python | 1004s | 753s | -25% | $5.11 | $3.65 | -29% | -60 |
| Config File Migrator | opus | powershell-strict | python | 1004s | 972s | -3% | $5.11 | $5.77 | +13% | -20 |
| Config File Migrator | sonnet | csharp-script | python | 3510s | 4419s | +26% | $2.44 | $5.32 | +118% | -7 |
| Config File Migrator | sonnet | powershell | python | 3510s | 3123s | -11% | $2.44 | $2.57 | +5% | -5 |
| Config File Migrator | sonnet | powershell-strict | python | 3510s | 2694s | -23% | $2.44 | $1.84 | -25% | -25 |
| Batch File Renamer | opus | csharp-script | python | 2033s | 2425s | +19% | $2.76 | $3.34 | +21% | +25 |
| Batch File Renamer | opus | powershell | python | 2033s | 4044s | +99% | $2.76 | $3.32 | +20% | +8 |
| Batch File Renamer | opus | powershell-strict | python | 2033s | 4577s | +125% | $2.76 | $5.60 | +103% | +39 |
| Batch File Renamer | sonnet | csharp-script | python | 2802s | 1156s | -59% | $1.27 | $3.76 | +195% | +77 |
| Batch File Renamer | sonnet | powershell | python | 2802s | 14801s | +428% | $1.27 | $2.07 | +63% | -7 |
| Batch File Renamer | sonnet | powershell-strict | python | 2802s | 754s | -73% | $1.27 | $1.38 | +9% | -14 |
| Database Seed Script | opus | csharp-script | python | 788s | 684s | -13% | $3.83 | $3.49 | -9% | -38 |
| Database Seed Script | opus | powershell | python | 788s | 863s | +10% | $3.83 | $5.61 | +47% | -1 |
| Database Seed Script | opus | powershell-strict | python | 788s | 1188s | +51% | $3.83 | $6.54 | +71% | +19 |
| Database Seed Script | sonnet | powershell | python | 978s | 724s | -26% | $0.98 | $1.67 | +70% | +8 |
| Database Seed Script | sonnet | powershell-strict | python | 978s | 763s | -22% | $0.98 | $1.65 | +69% | -11 |
| Error Retry Pipeline | opus | csharp-script |  | 1024s | 1562s | +52% | $3.93 | $6.97 | +78% | +54 |
| Error Retry Pipeline | opus | powershell |  | 1024s | 877s | -14% | $3.93 | $3.26 | -17% | -50 |
| Error Retry Pipeline | opus | powershell-strict |  | 1024s | 668s | -35% | $3.93 | $3.17 | -19% | -37 |
| Error Retry Pipeline | sonnet | csharp-script | python | 530s | 607s | +15% | $1.50 | $1.49 | -1% | +0 |
| Error Retry Pipeline | sonnet | powershell | python | 530s | 492s | -7% | $1.50 | $1.05 | -30% | -20 |
| Error Retry Pipeline | sonnet | powershell-strict | python | 530s | 427s | -20% | $1.50 | $0.92 | -39% | -25 |
| Multi-file Search and Rep | opus | csharp-script | python | 953s | 1040s | +9% | $4.45 | $4.56 | +2% | -41 |
| Multi-file Search and Rep | opus | powershell | python | 953s | 1026s | +8% | $4.45 | $4.56 | +2% | -47 |
| Multi-file Search and Rep | opus | powershell-strict | python | 953s | 730s | -23% | $4.45 | $3.52 | -21% | -41 |
| Multi-file Search and Rep | sonnet | csharp-script | python | 270s | 875s | +224% | $0.71 | $2.39 | +236% | +45 |
| Multi-file Search and Rep | sonnet | powershell | python | 270s | 527s | +95% | $0.71 | $1.17 | +65% | +28 |
| Multi-file Search and Rep | sonnet | powershell-strict | python | 270s | 919s | +240% | $0.71 | $2.41 | +239% | +41 |
| Semantic Version Bumper | opus | csharp-script | python | 719s | 369s | -49% | $3.34 | $1.39 | -58% | -19 |
| Semantic Version Bumper | opus | powershell | python | 719s | 798s | +11% | $3.34 | $3.84 | +15% | -15 |
| Semantic Version Bumper | opus | powershell-strict | python | 719s | 1111s | +54% | $3.34 | $7.96 | +139% | +95 |
| Semantic Version Bumper | sonnet | csharp-script | python | 775s | 1022s | +32% | $2.16 | $2.67 | +23% | -16 |
| Semantic Version Bumper | sonnet | powershell | python | 775s | 820s | +6% | $2.16 | $2.60 | +20% | +38 |
| Semantic Version Bumper | sonnet | powershell-strict | python | 775s | 760s | -2% | $2.16 | $2.08 | -4% | +1 |
| PR Label Assigner | opus | csharp-script | python | 965s | 1290s | +34% | $3.77 | $7.33 | +95% | +61 |
| PR Label Assigner | opus | powershell | python | 965s | 598s | -38% | $3.77 | $2.48 | -34% | -67 |
| PR Label Assigner | opus | powershell-strict | python | 965s | 667s | -31% | $3.77 | $3.72 | -1% | -12 |
| PR Label Assigner | sonnet | csharp-script | python | 401s | 1259s | +214% | $0.92 | $4.26 | +361% | +72 |
| PR Label Assigner | sonnet | powershell | python | 401s | 467s | +16% | $0.92 | $1.26 | +36% | +10 |
| PR Label Assigner | sonnet | powershell-strict | python | 401s | 531s | +32% | $0.92 | $1.02 | +10% | -7 |
| Dependency License Checke | opus | csharp-script | python | 1032s | 1311s | +27% | $6.00 | $8.83 | +47% | -23 |
| Dependency License Checke | opus | powershell | python | 1032s | 896s | -13% | $6.00 | $4.17 | -31% | -121 |
| Dependency License Checke | opus | powershell-strict | python | 1032s | 876s | -15% | $6.00 | $2.75 | -54% | -160 |
| Dependency License Checke | sonnet | csharp-script | python | 435s | 1596s | +267% | $1.18 | $3.08 | +160% | +28 |
| Dependency License Checke | sonnet | powershell | python | 435s | 181s | -58% | $1.18 | $0.59 | -51% | -21 |
| Dependency License Checke | sonnet | powershell-strict | python | 435s | 943s | +117% | $1.18 | $2.20 | +86% | +18 |
| Docker Image Tag Generato | opus | csharp-script | python | 920s | 994s | +8% | $3.82 | $4.60 | +20% | -23 |
| Docker Image Tag Generato | opus | powershell | python | 920s | 745s | -19% | $3.82 | $3.05 | -20% | -61 |
| Docker Image Tag Generato | opus | powershell-strict | python | 920s | 731s | -21% | $3.82 | $3.40 | -11% | -35 |
| Docker Image Tag Generato | sonnet | csharp-script | python | 229s | 797s | +248% | $0.50 | $2.28 | +354% | +71 |
| Docker Image Tag Generato | sonnet | powershell | python | 229s | 808s | +252% | $0.50 | $3.46 | +589% | +126 |
| Docker Image Tag Generato | sonnet | powershell-strict | python | 229s | 522s | +128% | $0.50 | $1.34 | +166% | +21 |
| Test Results Aggregator | opus | csharp-script | python | 1014s | 704s | -31% | $4.97 | $3.40 | -32% | -110 |
| Test Results Aggregator | opus | powershell | python | 1014s | 610s | -40% | $4.97 | $3.10 | -38% | -133 |
| Test Results Aggregator | opus | powershell-strict | python | 1014s | 1113s | +10% | $4.97 | $6.18 | +24% | -55 |
| Test Results Aggregator | sonnet | csharp-script | python | 612s | 780s | +27% | $2.01 | $2.32 | +16% | -30 |
| Test Results Aggregator | sonnet | powershell | python | 612s | 575s | -6% | $2.01 | $1.57 | -22% | -19 |
| Test Results Aggregator | sonnet | powershell-strict | python | 612s | 874s | +43% | $2.01 | $1.33 | -34% | -32 |
| Environment Matrix Genera | opus | csharp-script | python | 929s | 1260s | +36% | $3.93 | $6.47 | +65% | -30 |
| Environment Matrix Genera | opus | powershell | python | 929s | 897s | -4% | $3.93 | $4.93 | +26% | -55 |
| Environment Matrix Genera | opus | powershell-strict | python | 929s | 1007s | +8% | $3.93 | $4.48 | +14% | -46 |
| Environment Matrix Genera | sonnet | csharp-script | python | 492s | 773s | +57% | $1.32 | $2.26 | +71% | +26 |
| Environment Matrix Genera | sonnet | powershell | python | 492s | 402s | -18% | $1.32 | $0.89 | -33% | +0 |
| Artifact Cleanup Script | opus | csharp-script | python | 775s | 1074s | +39% | $3.49 | $4.17 | +20% | +8 |
| Artifact Cleanup Script | opus | powershell | python | 775s | 698s | -10% | $3.49 | $2.83 | -19% | -23 |
| Artifact Cleanup Script | opus | powershell-strict | python | 775s | 1000s | +29% | $3.49 | $5.03 | +44% | +19 |
| Artifact Cleanup Script | sonnet | csharp-script | python | 194s | 548s | +182% | $0.49 | $1.16 | +139% | +7 |
| Artifact Cleanup Script | sonnet | powershell | python | 194s | 782s | +302% | $0.49 | $1.63 | +235% | +22 |
| Artifact Cleanup Script | sonnet | powershell-strict | python | 194s | 801s | +312% | $0.49 | $1.83 | +276% | +20 |
| Secret Rotation Validator | opus | csharp-script | python | 734s | 1034s | +41% | $3.43 | $5.30 | +54% | +61 |
| Secret Rotation Validator | opus | powershell | python | 734s | 926s | +26% | $3.43 | $4.01 | +17% | +60 |
| Secret Rotation Validator | opus | powershell-strict | python | 734s | 1402s | +91% | $3.43 | $6.38 | +86% | +71 |
| Secret Rotation Validator | sonnet | csharp-script | python | 224s | 851s | +281% | $0.58 | $2.67 | +358% | +66 |
| Secret Rotation Validator | sonnet | powershell | python | 224s | 498s | +123% | $0.58 | $1.52 | +160% | +34 |
| Secret Rotation Validator | sonnet | powershell-strict | python | 224s | 423s | +89% | $0.58 | $0.80 | +38% | -13 |

## Observations

- **Fastest run:** Dependency License Checker / powershell / sonnet — 181s
- **Slowest run:** REST API Client / powershell-strict / opus — 22713s
- **Most errors:** CSV Report Generator / default / opus — 225 errors
- **Fewest errors:** Secret Rotation Validator / powershell-strict / sonnet — 6 errors

- **Avg cost per run (opus):** $4.52
- **Avg cost per run (sonnet):** $1.79


---
*Generated by runner.py, instructions version v3*