# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 10:36:03 AM ET

**Status:** 111/144 runs completed, 0 remaining
**Total cost so far:** $76.34
**Total agent time so far:** 27550s (459.2 min)

## Failed / Timed-Out Runs

| Task | Mode | Model | Duration | Reason | Lines | actionlint | act-result.txt |
|------|------|-------|----------|--------|-------|------------|----------------|
| Database Seed Script | default | sonnet | 232s | exit_code=1 | 0 | n/a | no |
| Database Seed Script | powershell | sonnet | 226s | exit_code=1 | 0 | n/a | no |
| Database Seed Script | powershell-strict | sonnet | 214s | exit_code=1 | 0 | n/a | no |
| Error Retry Pipeline | default | sonnet | 222s | exit_code=1 | 0 | n/a | no |
| Error Retry Pipeline | powershell | sonnet | 230s | exit_code=1 | 0 | n/a | no |
| Error Retry Pipeline | powershell-strict | opus | 582s | exit_code=143 | 425 | n/a | no |
| Error Retry Pipeline | powershell-strict | sonnet | 230s | exit_code=1 | 0 | n/a | no |
| Multi-file Search and Replace | default | sonnet | 233s | exit_code=1 | 0 | n/a | no |
| Multi-file Search and Replace | powershell-strict | sonnet | 228s | exit_code=1 | 0 | n/a | no |
| Semantic Version Bumper | powershell-strict | sonnet | 317s | exit_code=1 | 353 | n/a | no |
| Dependency License Checker | default | sonnet | 239s | exit_code=1 | 0 | n/a | no |

*11 run(s) excluded from averages below.*

## Comparison by Language/Model
*(averages exclude failed/timed-out runs)*

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | opus | 2 | 106s | 804 | 0.0 | 10 | $0.42 | $0.84 |
| csharp-script | sonnet | 1 | 36s | 762 | 0.0 | 7 | $0.12 | $0.12 |
| default | opus | 18 | 209s | 1537 | 1.1 | 32 | $0.88 | $15.75 |
| default | sonnet | 14 | 166s | 1469 | 0.9 | 12 | $0.35 | $4.91 |
| powershell | opus | 18 | 258s | 74597 | 0.4 | 32 | $0.97 | $17.49 |
| powershell | sonnet | 16 | 215s | 543 | 0.0 | 11 | $0.39 | $6.32 |
| powershell-strict | opus | 17 | 296s | 608 | 0.8 | 37 | $1.20 | $20.45 |
| powershell-strict | sonnet | 14 | 367s | 673 | 0.1 | 17 | $0.74 | $10.31 |


<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | sonnet | 1 | 36s | 762 | 0.0 | 7 | $0.12 | $0.12 |
| csharp-script | opus | 2 | 106s | 804 | 0.0 | 10 | $0.42 | $0.84 |
| default | sonnet | 14 | 166s | 1469 | 0.9 | 12 | $0.35 | $4.91 |
| default | opus | 18 | 209s | 1537 | 1.1 | 32 | $0.88 | $15.75 |
| powershell | sonnet | 16 | 215s | 543 | 0.0 | 11 | $0.39 | $6.32 |
| powershell | opus | 18 | 258s | 74597 | 0.4 | 32 | $0.97 | $17.49 |
| powershell-strict | opus | 17 | 296s | 608 | 0.8 | 37 | $1.20 | $20.45 |
| powershell-strict | sonnet | 14 | 367s | 673 | 0.1 | 17 | $0.74 | $10.31 |

</details>

<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | sonnet | 1 | 36s | 762 | 0.0 | 7 | $0.12 | $0.12 |
| default | sonnet | 14 | 166s | 1469 | 0.9 | 12 | $0.35 | $4.91 |
| powershell | sonnet | 16 | 215s | 543 | 0.0 | 11 | $0.39 | $6.32 |
| csharp-script | opus | 2 | 106s | 804 | 0.0 | 10 | $0.42 | $0.84 |
| powershell-strict | sonnet | 14 | 367s | 673 | 0.1 | 17 | $0.74 | $10.31 |
| default | opus | 18 | 209s | 1537 | 1.1 | 32 | $0.88 | $15.75 |
| powershell | opus | 18 | 258s | 74597 | 0.4 | 32 | $0.97 | $17.49 |
| powershell-strict | opus | 17 | 296s | 608 | 0.8 | 37 | $1.20 | $20.45 |

</details>

<details>
<summary>Sorted by avg errors (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | opus | 18 | 209s | 1537 | 1.1 | 32 | $0.88 | $15.75 |
| default | sonnet | 14 | 166s | 1469 | 0.9 | 12 | $0.35 | $4.91 |
| powershell-strict | opus | 17 | 296s | 608 | 0.8 | 37 | $1.20 | $20.45 |
| powershell | opus | 18 | 258s | 74597 | 0.4 | 32 | $0.97 | $17.49 |
| powershell-strict | sonnet | 14 | 367s | 673 | 0.1 | 17 | $0.74 | $10.31 |
| csharp-script | opus | 2 | 106s | 804 | 0.0 | 10 | $0.42 | $0.84 |
| csharp-script | sonnet | 1 | 36s | 762 | 0.0 | 7 | $0.12 | $0.12 |
| powershell | sonnet | 16 | 215s | 543 | 0.0 | 11 | $0.39 | $6.32 |

</details>

<details>
<summary>Sorted by total cost (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell-strict | opus | 17 | 296s | 608 | 0.8 | 37 | $1.20 | $20.45 |
| powershell | opus | 18 | 258s | 74597 | 0.4 | 32 | $0.97 | $17.49 |
| default | opus | 18 | 209s | 1537 | 1.1 | 32 | $0.88 | $15.75 |
| powershell-strict | sonnet | 14 | 367s | 673 | 0.1 | 17 | $0.74 | $10.31 |
| powershell | sonnet | 16 | 215s | 543 | 0.0 | 11 | $0.39 | $6.32 |
| default | sonnet | 14 | 166s | 1469 | 0.9 | 12 | $0.35 | $4.91 |
| csharp-script | opus | 2 | 106s | 804 | 0.0 | 10 | $0.42 | $0.84 |
| csharp-script | sonnet | 1 | 36s | 762 | 0.0 | 7 | $0.12 | $0.12 |

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
| Partial | 102 | $12.80 | 16.77% |
| Miss | 9 | $0.00 | 0.00% |
| **Total** | **111** | **$12.80** | **16.77%** |

### Trap Analysis by Category

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 111 | 55 | 56 | 50% | 125.7min | 27.4% | $29.92 | 39.19% |
| act-permission-path-errors | 111 | 1 | 110 | 1% | 0.8min | 0.2% | $0.27 | 0.35% |
| fixture-rework | 111 | 1 | 110 | 1% | 0.5min | 0.1% | $0.12 | 0.15% |
| **Total** | | **56 runs** | | **50%** | **126.9min** | **27.6%** | **$30.30** | **39.69%** |


<details>
<summary>Sorted by $ lost (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 111 | 55 | 56 | 50% | 125.7min | 27.4% | $29.92 | 39.19% |
| act-permission-path-errors | 111 | 1 | 110 | 1% | 0.8min | 0.2% | $0.27 | 0.35% |
| fixture-rework | 111 | 1 | 110 | 1% | 0.5min | 0.1% | $0.12 | 0.15% |

</details>

<details>
<summary>Sorted by rate (highest first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 111 | 55 | 56 | 50% | 125.7min | 27.4% | $29.92 | 39.19% |
| act-permission-path-errors | 111 | 1 | 110 | 1% | 0.8min | 0.2% | $0.27 | 0.35% |
| fixture-rework | 111 | 1 | 110 | 1% | 0.5min | 0.1% | $0.12 | 0.15% |

</details>

<details>
<summary>Sorted by runs affected (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 111 | 55 | 56 | 50% | 125.7min | 27.4% | $29.92 | 39.19% |
| act-permission-path-errors | 111 | 1 | 110 | 1% | 0.8min | 0.2% | $0.27 | 0.35% |
| fixture-rework | 111 | 1 | 110 | 1% | 0.5min | 0.1% | $0.12 | 0.15% |

</details>

### Traps by Language/Model

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 2 | 1 | 50% | 1 | 0.8min | 0.2% | $0.27 | 0.35% |
| csharp-script | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 18 | 13 | 72% | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| default | sonnet | 18 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 18 | 17 | 94% | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| powershell | sonnet | 18 | 2 | 11% | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| powershell-strict | opus | 18 | 17 | 94% | 18 | 49.2min | 10.7% | $12.30 | 16.12% |
| powershell-strict | sonnet | 18 | 6 | 33% | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| **Total** | | **111** | **56** | **50%** | **57** | **126.9min** | **27.6%** | **$30.30** | **39.69%** |


<details>
<summary>Sorted by time lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell-strict | opus | 18 | 17 | 94% | 18 | 49.2min | 10.7% | $12.30 | 16.12% |
| powershell | opus | 18 | 17 | 94% | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| default | opus | 18 | 13 | 72% | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| powershell-strict | sonnet | 18 | 6 | 33% | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| powershell | sonnet | 18 | 2 | 11% | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| csharp-script | opus | 2 | 1 | 50% | 1 | 0.8min | 0.2% | $0.27 | 0.35% |
| csharp-script | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 18 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

<details>
<summary>Sorted by $ lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell-strict | opus | 18 | 17 | 94% | 18 | 49.2min | 10.7% | $12.30 | 16.12% |
| powershell | opus | 18 | 17 | 94% | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| default | opus | 18 | 13 | 72% | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| powershell-strict | sonnet | 18 | 6 | 33% | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| csharp-script | opus | 2 | 1 | 50% | 1 | 0.8min | 0.2% | $0.27 | 0.35% |
| powershell | sonnet | 18 | 2 | 11% | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| csharp-script | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 18 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

<details>
<summary>Sorted by trap rate (highest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell | opus | 18 | 17 | 94% | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| powershell-strict | opus | 18 | 17 | 94% | 18 | 49.2min | 10.7% | $12.30 | 16.12% |
| default | opus | 18 | 13 | 72% | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| csharp-script | opus | 2 | 1 | 50% | 1 | 0.8min | 0.2% | $0.27 | 0.35% |
| powershell-strict | sonnet | 18 | 6 | 33% | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| powershell | sonnet | 18 | 2 | 11% | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| csharp-script | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 18 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 169s | 12 | 732 | 0 | $0.58 | csharp | ok |
| CSV Report Generator | csharp-script | sonnet | 36s | 7 | 762 | 0 | $0.12 | csharp | ok |
| CSV Report Generator | default | opus | 102s | 12 | 960 | 0 | $0.38 | python | ok |
| CSV Report Generator | default | sonnet | 376s | 1 | 1760 | 3 | $0.71 | python | ok |
| CSV Report Generator | powershell | opus | 255s | 37 | 330 | 0 | $1.05 | powershell | ok |
| CSV Report Generator | powershell | sonnet | 124s | 9 | 464 | 0 | $0.31 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 256s | 40 | 486 | 1 | $1.04 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet | 392s | 29 | 535 | 0 | $0.97 | powershell | ok |
| Log File Analyzer | csharp-script | opus | 43s | 9 | 877 | 0 | $0.25 | csharp | ok |
| Log File Analyzer | default | opus | 249s | 43 | 1464 | 0 | $1.18 | python | ok |
| Log File Analyzer | default | sonnet | 176s | 19 | 2268 | 0 | $0.48 | python | ok |
| Log File Analyzer | powershell | opus | 273s | 41 | 558 | 0 | $1.14 | powershell | ok |
| Log File Analyzer | powershell | sonnet | 232s | 10 | 681 | 0 | $0.44 | powershell | ok |
| Log File Analyzer | powershell-strict | opus | 267s | 31 | 552 | 1 | $0.95 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet | 228s | 14 | 802 | 1 | $0.50 | powershell | ok |
| Directory Tree Sync | default | opus | 227s | 43 | 1877 | 0 | $1.18 | python | ok |
| Directory Tree Sync | default | sonnet | 234s | 11 | 1723 | 1 | $0.45 | python | ok |
| Directory Tree Sync | powershell | opus | 318s | 42 | 542 | 0 | $1.13 | powershell | ok |
| Directory Tree Sync | powershell | sonnet | 179s | 11 | 757 | 0 | $0.37 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus | 323s | 34 | 628 | 0 | $1.21 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet | 259s | 13 | 621 | 0 | $0.49 | powershell | ok |
| REST API Client | default | opus | 315s | 45 | 1399 | 0 | $1.21 | python | ok |
| REST API Client | default | sonnet | 109s | 9 | 1065 | 1 | $0.23 | python | ok |
| REST API Client | powershell | opus | 430s | 51 | 537 | 1 | $1.82 | powershell | ok |
| REST API Client | powershell | sonnet | 758s | 13 | 427 | 0 | $0.96 | powershell | ok |
| REST API Client | powershell-strict | opus | 308s | 19 | 673 | 0 | $0.94 | powershell | ok |
| REST API Client | powershell-strict | sonnet | 552s | 14 | 686 | 0 | $0.99 | powershell | ok |
| Process Monitor | default | opus | 201s | 40 | 1305 | 1 | $1.00 | python | ok |
| Process Monitor | default | sonnet | 120s | 12 | 865 | 0 | $0.25 | python | ok |
| Process Monitor | powershell | opus | 323s | 39 | 392 | 0 | $1.21 | powershell | ok |
| Process Monitor | powershell | sonnet | 227s | 13 | 389 | 0 | $0.40 | powershell | ok |
| Process Monitor | powershell-strict | opus | 339s | 53 | 411 | 0 | $1.61 | powershell | ok |
| Process Monitor | powershell-strict | sonnet | 274s | 19 | 461 | 0 | $0.54 | powershell | ok |
| Config File Migrator | default | opus | 166s | 14 | 2361 | 1 | $0.59 | python | ok |
| Config File Migrator | default | sonnet | 203s | 18 | 1806 | 1 | $0.47 | python | ok |
| Config File Migrator | powershell | opus | 225s | 20 | 666 | 0 | $0.69 | powershell | ok |
| Config File Migrator | powershell | sonnet | 204s | 15 | 894 | 0 | $0.38 | powershell | ok |
| Config File Migrator | powershell-strict | opus | 162s | 12 | 754 | 0 | $0.49 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet | 831s | 21 | 1161 | 0 | $1.60 | powershell | ok |
| Batch File Renamer | default | opus | 169s | 30 | 1069 | 2 | $0.81 | python | ok |
| Batch File Renamer | default | sonnet | 136s | 8 | 1462 | 0 | $0.22 | python | ok |
| Batch File Renamer | powershell | opus | 179s | 21 | 351 | 0 | $0.59 | powershell | ok |
| Batch File Renamer | powershell | sonnet | 84s | 6 | 351 | 0 | $0.16 | powershell | ok |
| Batch File Renamer | powershell-strict | opus | 269s | 35 | 470 | 0 | $1.05 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet | 220s | 16 | 536 | 1 | $0.50 | powershell | ok |
| Database Seed Script | default | opus | 257s | 36 | 2359 | 1 | $1.04 | python | ok |
| Database Seed Script | default | sonnet | 232s | 1 | 0 | 0 | $0.00 |  | failed |
| Database Seed Script | powershell | opus | 349s | 42 | 1334560 | 4 | $1.32 | powershell | ok |
| Database Seed Script | powershell | sonnet | 226s | 1 | 0 | 0 | $0.00 | powershell | failed |
| Database Seed Script | powershell-strict | opus | 520s | 56 | 956 | 2 | $2.03 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet | 214s | 1 | 0 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | default | opus | 141s | 24 | 1364 | 0 | $0.54 | python | ok |
| Error Retry Pipeline | default | sonnet | 222s | 1 | 0 | 0 | $0.00 |  | failed |
| Error Retry Pipeline | powershell | opus | 229s | 34 | 368 | 0 | $0.93 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet | 230s | 1 | 0 | 0 | $0.00 | powershell | failed |
| Error Retry Pipeline | powershell-strict | opus | 582s | 0 | 425 | 1 | $0.00 | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet | 230s | 1 | 0 | 0 | $0.00 | powershell | failed |
| Multi-file Search and Replace | default | opus | 187s | 25 | 1388 | 3 | $0.70 | python | ok |
| Multi-file Search and Replace | default | sonnet | 233s | 1 | 0 | 0 | $0.00 |  | failed |
| Multi-file Search and Replace | powershell | opus | 217s | 21 | 449 | 0 | $0.65 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet | 84s | 10 | 339 | 0 | $0.19 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus | 246s | 34 | 499 | 0 | $1.09 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | sonnet | 228s | 1 | 0 | 0 | $0.00 | powershell | failed |
| Semantic Version Bumper | default | opus | 289s | 47 | 1747 | 5 | $1.23 | python | ok |
| Semantic Version Bumper | default | sonnet | 149s | 11 | 1356 | 0 | $0.25 | python | ok |
| Semantic Version Bumper | powershell | opus | 213s | 27 | 462 | 0 | $0.77 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 160s | 16 | 647 | 0 | $0.33 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus | 347s | 52 | 620 | 0 | $1.57 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet | 317s | 5 | 353 | 0 | $0.15 | powershell | failed |
| PR Label Assigner | default | opus | 115s | 11 | 991 | 1 | $0.38 | python | ok |
| PR Label Assigner | default | sonnet | 106s | 8 | 1189 | 0 | $0.21 | python | ok |
| PR Label Assigner | powershell | opus | 187s | 23 | 358 | 0 | $0.61 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 220s | 10 | 515 | 0 | $0.38 | powershell | ok |
| PR Label Assigner | powershell-strict | opus | 241s | 37 | 396 | 0 | $1.03 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet | 196s | 12 | 526 | 0 | $0.35 | powershell | ok |
| Dependency License Checker | default | opus | 339s | 64 | 1836 | 4 | $1.73 | python | ok |
| Dependency License Checker | default | sonnet | 239s | 1 | 0 | 0 | $0.00 |  | failed |
| Dependency License Checker | powershell | opus | 346s | 45 | 547 | 1 | $1.37 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 154s | 11 | 660 | 0 | $0.36 | powershell | ok |
| Dependency License Checker | powershell-strict | opus | 326s | 52 | 717 | 4 | $1.59 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet | 569s | 18 | 655 | 0 | $0.97 | powershell | ok |
| Docker Image Tag Generator | default | opus | 161s | 30 | 969 | 0 | $0.67 | python | ok |
| Docker Image Tag Generator | default | sonnet | 108s | 10 | 685 | 1 | $0.23 | python | ok |
| Docker Image Tag Generator | powershell | opus | 208s | 32 | 222 | 0 | $0.84 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 177s | 9 | 253 | 0 | $0.31 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus | 299s | 44 | 349 | 0 | $1.28 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet | 152s | 13 | 371 | 0 | $0.33 | powershell | ok |
| Test Results Aggregator | default | opus | 140s | 15 | 2245 | 1 | $0.51 | python | ok |
| Test Results Aggregator | default | sonnet | 240s | 20 | 2252 | 1 | $0.49 | python | ok |
| Test Results Aggregator | powershell | opus | 256s | 33 | 789 | 0 | $0.95 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 298s | 15 | 654 | 0 | $0.55 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus | 237s | 24 | 791 | 0 | $0.95 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet | 690s | 20 | 1119 | 0 | $1.42 | powershell | ok |
| Environment Matrix Generator | default | opus | 281s | 38 | 1757 | 1 | $1.11 | python | ok |
| Environment Matrix Generator | default | sonnet | 121s | 9 | 1543 | 0 | $0.26 | python | ok |
| Environment Matrix Generator | powershell | opus | 141s | 18 | 454 | 0 | $0.54 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 169s | 13 | 476 | 0 | $0.36 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus | 251s | 31 | 658 | 2 | $0.96 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet | 325s | 16 | 748 | 0 | $0.62 | powershell | ok |
| Artifact Cleanup Script | default | opus | 262s | 34 | 1472 | 0 | $0.98 | python | ok |
| Artifact Cleanup Script | default | sonnet | 157s | 17 | 1378 | 4 | $0.44 | python | ok |
| Artifact Cleanup Script | powershell | opus | 295s | 30 | 637 | 0 | $1.16 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 156s | 9 | 457 | 0 | $0.35 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus | 332s | 37 | 721 | 1 | $1.37 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet | 217s | 15 | 647 | 0 | $0.49 | powershell | ok |
| Secret Rotation Validator | default | opus | 158s | 17 | 1100 | 0 | $0.51 | python | ok |
| Secret Rotation Validator | default | sonnet | 92s | 11 | 1220 | 0 | $0.22 | python | ok |
| Secret Rotation Validator | powershell | opus | 197s | 23 | 518 | 1 | $0.72 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 212s | 11 | 718 | 0 | $0.48 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus | 318s | 39 | 662 | 2 | $1.27 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet | 238s | 20 | 553 | 0 | $0.53 | powershell | ok |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Δ | Def Cost | Mode Cost | Cost Δ | Err Δ |
|------|-------|------|-------------|---------|----------|-------|----------|-----------|--------|-------|
| CSV Report Generator | opus | csharp-script | python | 102s | 169s | +66% | $0.38 | $0.58 | +55% | +0 |
| CSV Report Generator | opus | powershell | python | 102s | 255s | +151% | $0.38 | $1.05 | +178% | +0 |
| CSV Report Generator | opus | powershell-strict | python | 102s | 256s | +151% | $0.38 | $1.04 | +178% | +1 |
| CSV Report Generator | sonnet | csharp-script | python | 376s | 36s | -90% | $0.71 | $0.12 | -83% | -3 |
| CSV Report Generator | sonnet | powershell | python | 376s | 124s | -67% | $0.71 | $0.31 | -57% | -3 |
| CSV Report Generator | sonnet | powershell-strict | python | 376s | 392s | +4% | $0.71 | $0.97 | +37% | -3 |
| Log File Analyzer | opus | csharp-script | python | 249s | 43s | -83% | $1.18 | $0.25 | -79% | +0 |
| Log File Analyzer | opus | powershell | python | 249s | 273s | +10% | $1.18 | $1.14 | -4% | +0 |
| Log File Analyzer | opus | powershell-strict | python | 249s | 267s | +7% | $1.18 | $0.95 | -20% | +1 |
| Log File Analyzer | sonnet | powershell | python | 176s | 232s | +32% | $0.48 | $0.44 | -9% | +0 |
| Log File Analyzer | sonnet | powershell-strict | python | 176s | 228s | +30% | $0.48 | $0.50 | +5% | +1 |
| Directory Tree Sync | opus | powershell | python | 227s | 318s | +40% | $1.18 | $1.13 | -5% | +0 |
| Directory Tree Sync | opus | powershell-strict | python | 227s | 323s | +42% | $1.18 | $1.21 | +3% | +0 |
| Directory Tree Sync | sonnet | powershell | python | 234s | 179s | -23% | $0.45 | $0.37 | -18% | -1 |
| Directory Tree Sync | sonnet | powershell-strict | python | 234s | 259s | +11% | $0.45 | $0.49 | +9% | -1 |
| REST API Client | opus | powershell | python | 315s | 430s | +37% | $1.21 | $1.82 | +50% | +1 |
| REST API Client | opus | powershell-strict | python | 315s | 308s | -2% | $1.21 | $0.94 | -23% | +0 |
| REST API Client | sonnet | powershell | python | 109s | 758s | +594% | $0.23 | $0.96 | +316% | -1 |
| REST API Client | sonnet | powershell-strict | python | 109s | 552s | +405% | $0.23 | $0.99 | +331% | -1 |
| Process Monitor | opus | powershell | python | 201s | 323s | +61% | $1.00 | $1.21 | +21% | -1 |
| Process Monitor | opus | powershell-strict | python | 201s | 339s | +69% | $1.00 | $1.61 | +61% | -1 |
| Process Monitor | sonnet | powershell | python | 120s | 227s | +89% | $0.25 | $0.40 | +63% | +0 |
| Process Monitor | sonnet | powershell-strict | python | 120s | 274s | +128% | $0.25 | $0.54 | +118% | +0 |
| Config File Migrator | opus | powershell | python | 166s | 225s | +35% | $0.59 | $0.69 | +16% | -1 |
| Config File Migrator | opus | powershell-strict | python | 166s | 162s | -3% | $0.59 | $0.49 | -18% | -1 |
| Config File Migrator | sonnet | powershell | python | 203s | 204s | +0% | $0.47 | $0.38 | -20% | -1 |
| Config File Migrator | sonnet | powershell-strict | python | 203s | 831s | +309% | $0.47 | $1.60 | +241% | -1 |
| Batch File Renamer | opus | powershell | python | 169s | 179s | +6% | $0.81 | $0.59 | -27% | -2 |
| Batch File Renamer | opus | powershell-strict | python | 169s | 269s | +60% | $0.81 | $1.05 | +30% | -2 |
| Batch File Renamer | sonnet | powershell | python | 136s | 84s | -38% | $0.22 | $0.16 | -29% | +0 |
| Batch File Renamer | sonnet | powershell-strict | python | 136s | 220s | +62% | $0.22 | $0.50 | +126% | +1 |
| Database Seed Script | opus | powershell | python | 257s | 349s | +36% | $1.04 | $1.32 | +27% | +3 |
| Database Seed Script | opus | powershell-strict | python | 257s | 520s | +102% | $1.04 | $2.03 | +96% | +1 |
| Error Retry Pipeline | opus | powershell | python | 141s | 229s | +63% | $0.54 | $0.93 | +73% | +0 |
| Multi-file Search and Rep | opus | powershell | python | 187s | 217s | +16% | $0.70 | $0.65 | -6% | -3 |
| Multi-file Search and Rep | opus | powershell-strict | python | 187s | 246s | +32% | $0.70 | $1.09 | +56% | -3 |
| Semantic Version Bumper | opus | powershell | python | 289s | 213s | -26% | $1.23 | $0.77 | -38% | -5 |
| Semantic Version Bumper | opus | powershell-strict | python | 289s | 347s | +20% | $1.23 | $1.57 | +28% | -5 |
| Semantic Version Bumper | sonnet | powershell | python | 149s | 160s | +8% | $0.25 | $0.33 | +33% | +0 |
| PR Label Assigner | opus | powershell | python | 115s | 187s | +63% | $0.38 | $0.61 | +63% | -1 |
| PR Label Assigner | opus | powershell-strict | python | 115s | 241s | +110% | $0.38 | $1.03 | +175% | -1 |
| PR Label Assigner | sonnet | powershell | python | 106s | 220s | +108% | $0.21 | $0.38 | +79% | +0 |
| PR Label Assigner | sonnet | powershell-strict | python | 106s | 196s | +86% | $0.21 | $0.35 | +66% | +0 |
| Dependency License Checke | opus | powershell | python | 339s | 346s | +2% | $1.73 | $1.37 | -21% | -3 |
| Dependency License Checke | opus | powershell-strict | python | 339s | 326s | -4% | $1.73 | $1.59 | -8% | +0 |
| Docker Image Tag Generato | opus | powershell | python | 161s | 208s | +29% | $0.67 | $0.84 | +26% | +0 |
| Docker Image Tag Generato | opus | powershell-strict | python | 161s | 299s | +85% | $0.67 | $1.28 | +92% | +0 |
| Docker Image Tag Generato | sonnet | powershell | python | 108s | 177s | +64% | $0.23 | $0.31 | +33% | -1 |
| Docker Image Tag Generato | sonnet | powershell-strict | python | 108s | 152s | +42% | $0.23 | $0.33 | +41% | -1 |
| Test Results Aggregator | opus | powershell | python | 140s | 256s | +83% | $0.51 | $0.95 | +85% | -1 |
| Test Results Aggregator | opus | powershell-strict | python | 140s | 237s | +70% | $0.51 | $0.95 | +85% | -1 |
| Test Results Aggregator | sonnet | powershell | python | 240s | 298s | +24% | $0.49 | $0.55 | +12% | -1 |
| Test Results Aggregator | sonnet | powershell-strict | python | 240s | 690s | +187% | $0.49 | $1.42 | +188% | -1 |
| Environment Matrix Genera | opus | powershell | python | 281s | 141s | -50% | $1.11 | $0.54 | -52% | -1 |
| Environment Matrix Genera | opus | powershell-strict | python | 281s | 251s | -11% | $1.11 | $0.96 | -14% | +1 |
| Environment Matrix Genera | sonnet | powershell | python | 121s | 169s | +40% | $0.26 | $0.36 | +35% | +0 |
| Environment Matrix Genera | sonnet | powershell-strict | python | 121s | 325s | +169% | $0.26 | $0.62 | +135% | +0 |
| Artifact Cleanup Script | opus | powershell | python | 262s | 295s | +13% | $0.98 | $1.16 | +19% | +0 |
| Artifact Cleanup Script | opus | powershell-strict | python | 262s | 332s | +27% | $0.98 | $1.37 | +39% | +1 |
| Artifact Cleanup Script | sonnet | powershell | python | 157s | 156s | -1% | $0.44 | $0.35 | -20% | -4 |
| Artifact Cleanup Script | sonnet | powershell-strict | python | 157s | 217s | +39% | $0.44 | $0.49 | +12% | -4 |
| Secret Rotation Validator | opus | powershell | python | 158s | 197s | +24% | $0.51 | $0.72 | +40% | +1 |
| Secret Rotation Validator | opus | powershell-strict | python | 158s | 318s | +101% | $0.51 | $1.27 | +147% | +2 |
| Secret Rotation Validator | sonnet | powershell | python | 92s | 212s | +131% | $0.22 | $0.48 | +117% | +0 |
| Secret Rotation Validator | sonnet | powershell-strict | python | 92s | 238s | +160% | $0.22 | $0.53 | +138% | +0 |

## Observations

- **Fastest run:** CSV Report Generator / csharp-script / sonnet — 36s
- **Slowest run:** Config File Migrator / powershell-strict / sonnet — 831s
- **Most errors:** Semantic Version Bumper / default / opus — 5 errors
- **Fewest errors:** CSV Report Generator / csharp-script / opus — 0 errors

- **Avg cost per run (opus):** $0.99
- **Avg cost per run (sonnet):** $0.48

- **Estimated time remaining:** 0.0 hours (based on avg 248s per run)
- **Estimated total cost:** $99.03

---
*Generated by runner.py, instructions version v3*