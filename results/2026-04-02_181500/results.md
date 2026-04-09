# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 11:44:53 AM ET

**Status:** 4/1 runs completed, 0 remaining
**Total cost so far:** $14.13
**Total agent time so far:** 42.2 min

## Observations

- **Fastest (avg):** powershell/opus — 4.4min
- **Slowest (avg):** csharp-script/opus — 24.6min
- **Cheapest (avg):** powershell/opus — $1.17
- **Most expensive (avg):** csharp-script/opus — $8.90
- **Fastest single run:** CSV Report Generator / powershell / opus — 4.4min
- **Slowest single run:** CSV Report Generator / csharp-script / opus — 24.6min
- **Most errors:** CSV Report Generator / csharp-script / opus — 270 errors
- **Fewest errors:** CSV Report Generator / powershell / opus — 43 errors

- **Avg cost per run (opus):** $3.53

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | opus | 1 | 24.6min | 653 | 270.0 | 19 | $8.90 | $8.90 |
| default | opus | 1 | 5.3min | 469 | 69.0 | 75 | $1.29 | $1.29 |
| powershell | opus | 1 | 4.4min | 95 | 43.0 | 63 | $1.17 | $1.17 |
| powershell-strict | opus | 1 | 7.9min | 641 | 79.0 | 102 | $2.77 | $2.77 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | opus | 1 | 24.6min | 653 | 270.0 | 19 | $8.90 | $8.90 |
| powershell-strict | opus | 1 | 7.9min | 641 | 79.0 | 102 | $2.77 | $2.77 |
| default | opus | 1 | 5.3min | 469 | 69.0 | 75 | $1.29 | $1.29 |
| powershell | opus | 1 | 4.4min | 95 | 43.0 | 63 | $1.17 | $1.17 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | opus | 1 | 4.4min | 95 | 43.0 | 63 | $1.17 | $1.17 |
| default | opus | 1 | 5.3min | 469 | 69.0 | 75 | $1.29 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | 641 | 79.0 | 102 | $2.77 | $2.77 |
| csharp-script | opus | 1 | 24.6min | 653 | 270.0 | 19 | $8.90 | $8.90 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | opus | 1 | 4.4min | 95 | 43.0 | 63 | $1.17 | $1.17 |
| default | opus | 1 | 5.3min | 469 | 69.0 | 75 | $1.29 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | 641 | 79.0 | 102 | $2.77 | $2.77 |
| csharp-script | opus | 1 | 24.6min | 653 | 270.0 | 19 | $8.90 | $8.90 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| csharp-script | opus | 1 | 24.6min | 653 | 270.0 | 19 | $8.90 | $8.90 |
| powershell | opus | 1 | 4.4min | 95 | 43.0 | 63 | $1.17 | $1.17 |
| default | opus | 1 | 5.3min | 469 | 69.0 | 75 | $1.29 | $1.29 |
| powershell-strict | opus | 1 | 7.9min | 641 | 79.0 | 102 | $2.77 | $2.77 |

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
| repeated-test-reruns | default | opus | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| repeated-test-reruns | powershell | opus | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| repeated-test-reruns | powershell-strict | opus | 3 | 6.0min | 14.2% | $2.11 | 14.91% |
| act-permission-path-errors | csharp-script | opus | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| act-permission-path-errors | powershell-strict | opus | 1 | 1.0min | 2.4% | $0.35 | 2.49% |
| **Total** | | | **4 runs** | **26.3min** | **62.5%** | **$7.58** | **53.62%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-permission-path-errors | powershell-strict | opus | 1 | 1.0min | 2.4% | $0.35 | 2.49% |
| repeated-test-reruns | powershell | opus | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| act-permission-path-errors | csharp-script | opus | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| repeated-test-reruns | powershell-strict | opus | 3 | 6.0min | 14.2% | $2.11 | 14.91% |
| repeated-test-reruns | default | opus | 2 | 14.7min | 34.8% | $3.59 | 25.42% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-permission-path-errors | powershell-strict | opus | 1 | 1.0min | 2.4% | $0.35 | 2.49% |
| repeated-test-reruns | powershell | opus | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| act-permission-path-errors | csharp-script | opus | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| repeated-test-reruns | powershell-strict | opus | 3 | 6.0min | 14.2% | $2.11 | 14.91% |
| repeated-test-reruns | default | opus | 2 | 14.7min | 34.8% | $3.59 | 25.42% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | opus | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| act-permission-path-errors | csharp-script | opus | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| act-permission-path-errors | powershell-strict | opus | 1 | 1.0min | 2.4% | $0.35 | 2.49% |
| repeated-test-reruns | default | opus | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| repeated-test-reruns | powershell-strict | opus | 3 | 6.0min | 14.2% | $2.11 | 14.91% |

</details>

#### Trap Descriptions

- **act-permission-path-errors**: Files not found or permission denied inside the act Docker container.
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
| csharp-script | opus | 1 | 1 | 100% | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| default | opus | 1 | 1 | 100% | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| powershell | opus | 1 | 1 | 100% | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 7.0min | 16.6% | $2.46 | 17.40% |
| **Total** | | **4** | **4** | **100%** | **8** | **26.3min** | **62.5%** | **$7.58** | **53.62%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell | opus | 1 | 1 | 100% | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| csharp-script | opus | 1 | 1 | 100% | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 7.0min | 16.6% | $2.46 | 17.40% |
| default | opus | 1 | 1 | 100% | 2 | 14.7min | 34.8% | $3.59 | 25.42% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell | opus | 1 | 1 | 100% | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| csharp-script | opus | 1 | 1 | 100% | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 7.0min | 16.6% | $2.46 | 17.40% |
| default | opus | 1 | 1 | 100% | 2 | 14.7min | 34.8% | $3.59 | 25.42% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| csharp-script | opus | 1 | 1 | 100% | 1 | 3.0min | 7.1% | $1.09 | 7.69% |
| default | opus | 1 | 1 | 100% | 2 | 14.7min | 34.8% | $3.59 | 25.42% |
| powershell | opus | 1 | 1 | 100% | 1 | 1.7min | 4.0% | $0.44 | 3.11% |
| powershell-strict | opus | 1 | 1 | 100% | 4 | 7.0min | 16.6% | $2.46 | 17.40% |

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
*Generated by generate_results.py, instructions version v3*