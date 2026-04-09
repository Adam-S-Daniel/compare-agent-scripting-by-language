# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 10:36:03 AM ET

**Status:** 4/1 runs completed, 0 remaining
**Total cost so far:** $14.13
**Total agent time so far:** 2530s (42.2 min)

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | opus | 1 | 1474s | 653 | 270.0 | 19 | $8.90 | $8.90 |
| default | opus | 1 | 316s | 469 | 69.0 | 75 | $1.29 | $1.29 |
| powershell | opus | 1 | 266s | 95 | 43.0 | 63 | $1.17 | $1.17 |
| powershell-strict | opus | 1 | 474s | 641 | 79.0 | 102 | $2.77 | $2.77 |


<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | opus | 1 | 266s | 95 | 43.0 | 63 | $1.17 | $1.17 |
| default | opus | 1 | 316s | 469 | 69.0 | 75 | $1.29 | $1.29 |
| powershell-strict | opus | 1 | 474s | 641 | 79.0 | 102 | $2.77 | $2.77 |
| csharp-script | opus | 1 | 1474s | 653 | 270.0 | 19 | $8.90 | $8.90 |

</details>

<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | opus | 1 | 266s | 95 | 43.0 | 63 | $1.17 | $1.17 |
| default | opus | 1 | 316s | 469 | 69.0 | 75 | $1.29 | $1.29 |
| powershell-strict | opus | 1 | 474s | 641 | 79.0 | 102 | $2.77 | $2.77 |
| csharp-script | opus | 1 | 1474s | 653 | 270.0 | 19 | $8.90 | $8.90 |

</details>

<details>
<summary>Sorted by avg errors (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | opus | 1 | 1474s | 653 | 270.0 | 19 | $8.90 | $8.90 |
| powershell-strict | opus | 1 | 474s | 641 | 79.0 | 102 | $2.77 | $2.77 |
| default | opus | 1 | 316s | 469 | 69.0 | 75 | $1.29 | $1.29 |
| powershell | opus | 1 | 266s | 95 | 43.0 | 63 | $1.17 | $1.17 |

</details>

<details>
<summary>Sorted by total cost (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | opus | 1 | 1474s | 653 | 270.0 | 19 | $8.90 | $8.90 |
| powershell-strict | opus | 1 | 474s | 641 | 79.0 | 102 | $2.77 | $2.77 |
| default | opus | 1 | 316s | 469 | 69.0 | 75 | $1.29 | $1.29 |
| powershell | opus | 1 | 266s | 95 | 43.0 | 63 | $1.17 | $1.17 |

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
| Full hit (100%) | 2 | $0.46 | 3.22% |
| Partial | 1 | $0.19 | 1.38% |
| Miss | 1 | $0.00 | 0.00% |
| **Total** | **4** | **$0.65** | **4.60%** |

### Trap Analysis by Category

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 4 | 6 | -2 | 150% | 22.3min | 53.0% | $6.14 | 43.45% |
| act-permission-path-errors | 4 | 2 | 2 | 50% | 4.0min | 9.5% | $1.44 | 10.17% |
| **Total** | | **4 runs** | | **100%** | **26.3min** | **62.5%** | **$7.58** | **53.62%** |


<details>
<summary>Sorted by $ lost (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 4 | 6 | -2 | 150% | 22.3min | 53.0% | $6.14 | 43.45% |
| act-permission-path-errors | 4 | 2 | 2 | 50% | 4.0min | 9.5% | $1.44 | 10.17% |

</details>

<details>
<summary>Sorted by rate (highest first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 4 | 6 | -2 | 150% | 22.3min | 53.0% | $6.14 | 43.45% |
| act-permission-path-errors | 4 | 2 | 2 | 50% | 4.0min | 9.5% | $1.44 | 10.17% |

</details>

<details>
<summary>Sorted by runs affected (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 4 | 6 | -2 | 150% | 22.3min | 53.0% | $6.14 | 43.45% |
| act-permission-path-errors | 4 | 2 | 2 | 50% | 4.0min | 9.5% | $1.44 | 10.17% |

</details>

### Traps by Language/Model

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 1 | 1 | 100% | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| default | opus | 1 | 1 | 100% | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| powershell | opus | 1 | 1 | 100% | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 7.0min | 16.6% | $2.46 | 17.40% |
| **Total** | | **4** | **4** | **100%** | **8** | **26.3min** | **62.5%** | **$7.58** | **53.62%** |


<details>
<summary>Sorted by time lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 7.0min | 16.6% | $2.46 | 17.40% |
| csharp-script | opus | 1 | 1 | 100% | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| powershell | opus | 1 | 1 | 100% | 1 | 1.7min | 4.0% | $0.44 | 3.11% |

</details>

<details>
<summary>Sorted by $ lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 7.0min | 16.6% | $2.46 | 17.40% |
| csharp-script | opus | 1 | 1 | 100% | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| powershell | opus | 1 | 1 | 100% | 1 | 1.7min | 4.0% | $0.44 | 3.11% |

</details>

<details>
<summary>Sorted by trap rate (highest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 1 | 1 | 100% | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| default | opus | 1 | 1 | 100% | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| powershell | opus | 1 | 1 | 100% | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 7.0min | 16.6% | $2.46 | 17.40% |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| CSV Report Generator | csharp-script | opus | 1474s | 19 | 653 | 270 | $8.90 | csharp | ok |
| CSV Report Generator | default | opus | 316s | 75 | 469 | 69 | $1.29 | python | ok |
| CSV Report Generator | powershell | opus | 266s | 63 | 95 | 43 | $1.17 | powershell | ok |
| CSV Report Generator | powershell-strict | opus | 474s | 102 | 641 | 79 | $2.77 | powershell | ok |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Δ | Def Cost | Mode Cost | Cost Δ | Err Δ |
|------|-------|------|-------------|---------|----------|-------|----------|-----------|--------|-------|
| CSV Report Generator | opus | csharp-script | python | 316s | 1474s | +366% | $1.29 | $8.90 | +590% | +201 |
| CSV Report Generator | opus | powershell | python | 316s | 266s | -16% | $1.29 | $1.17 | -9% | -26 |
| CSV Report Generator | opus | powershell-strict | python | 316s | 474s | +50% | $1.29 | $2.77 | +115% | +10 |

## Observations

- **Fastest run:** CSV Report Generator / powershell / opus — 266s
- **Slowest run:** CSV Report Generator / csharp-script / opus — 1474s
- **Most errors:** CSV Report Generator / csharp-script / opus — 270 errors
- **Fewest errors:** CSV Report Generator / powershell / opus — 43 errors

- **Avg cost per run (opus):** $3.53


---
*Generated by runner.py, instructions version v3*