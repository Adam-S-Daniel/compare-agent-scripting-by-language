# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 04:01:19 PM ET

**Status:** 3/64 runs completed, 61 remaining
**Total cost so far:** $4.02
**Total agent time so far:** 26.4 min

## Observations

- **Fastest (avg):** powershell/opus — 6.9min, then default/opus — 7.1min
- **Fastest net of traps:** powershell/opus — 6.9min, then default/opus — 7.1min
- **Slowest (avg):** bash/opus — 12.4min, then default/opus — 7.1min
- **Slowest net of traps:** bash/opus — 10.9min, then default/opus — 7.1min
- **Cheapest (avg):** powershell/opus — $1.04, then default/opus — $1.33
- **Cheapest net of traps:** powershell/opus — $1.04, then default/opus — $1.33
- **Most expensive (avg):** bash/opus — $1.65, then default/opus — $1.33
- **Most expensive net of traps:** bash/opus — $1.45, then default/opus — $1.33

- **Estimated time remaining:** 537.5min
- **Estimated total cost:** $85.72

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 17 | 1 | 5.9% | 0.2min | 0.8% | 0.7min | 2.8% | -0.5min | -2.0% | 3.9min | -13.6% |
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 1.5min | -5.7% |
| **Total** | | **31** | **1** | **3.2%** | **0.2min** | **0.8%** | **0.9min** | **3.3%** | **-0.7min** | **-2.5%** | **5.4min** | **-12.4%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 1.5min | -5.7% |
| bash | opus | 17 | 1 | 5.9% | 0.2min | 0.8% | 0.7min | 2.8% | -0.5min | -2.0% | 3.9min | -13.6% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 1.5min | -5.7% |
| bash | opus | 17 | 1 | 5.9% | 0.2min | 0.8% | 0.7min | 2.8% | -0.5min | -2.0% | 3.9min | -13.6% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 17 | 1 | 5.9% | 0.2min | 0.8% | 0.7min | 2.8% | -0.5min | -2.0% | 3.9min | -13.6% |
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 1.5min | -5.7% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 3.2% | $0.11 | 2.77% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 2.5% | $0.09 | 2.21% |
| **Total** | | | **1 runs** | **1.5min** | **5.7%** | **$0.20** | **4.98%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 2.5% | $0.09 | 2.21% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 3.2% | $0.11 | 2.77% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 2.5% | $0.09 | 2.21% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 3.2% | $0.11 | 2.77% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 3.2% | $0.11 | 2.77% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 2.5% | $0.09 | 2.21% |

</details>

#### Trap Descriptions

- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **actionlint-fix-cycles**: Workflow YAML required 3+ actionlint runs and 2+ fixes to pass.

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
| bash | opus | 1 | 1 | 100% | 2 | 1.5min | 5.7% | $0.20 | 4.98% |
| default | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| **Total** | | **3** | **1** | **33%** | **2** | **1.5min** | **5.7%** | **$0.20** | **4.98%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | opus | 1 | 1 | 100% | 2 | 1.5min | 5.7% | $0.20 | 4.98% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | opus | 1 | 1 | 100% | 2 | 1.5min | 5.7% | $0.20 | 4.98% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | opus | 1 | 1 | 100% | 2 | 1.5min | 5.7% | $0.20 | 4.98% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 3 | $0.59 | 14.68% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **3** | **$0.59** | **14.68%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*