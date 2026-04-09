# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 02:23:32 PM ET

**Status:** 3/3 runs completed, 0 remaining
**Total cost so far:** $2.91
**Total agent time so far:** 14.6 min

## Observations

- **Fastest (avg):** bash/opus — 2.4min, then default/opus — 4.9min
- **Slowest (avg):** powershell/opus — 7.3min, then default/opus — 4.9min
- **Cheapest (avg):** bash/opus — $0.51, then default/opus — $0.92
- **Most expensive (avg):** powershell/opus — $1.48, then default/opus — $0.92
- **Fastest net of traps:** bash/opus — 2.4min, then powershell/opus — 3.6min
- **Slowest net of traps:** default/opus — 3.9min, then powershell/opus — 3.6min
- **Cheapest net of traps:** bash/opus — $0.51, then default/opus — $0.74
- **Most expensive net of traps:** powershell/opus — $0.74, then default/opus — $0.74

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 2.4min | 2.4min | 420 | 1.0 | 22 | $0.51 | $0.51 | $0.51 |
| default | opus | 1 | 4.9min | 3.9min | 692 | 1.0 | 39 | $0.92 | $0.74 | $0.92 |
| powershell | opus | 1 | 7.3min | 3.6min | 692 | 0.0 | 54 | $1.48 | $0.74 | $1.48 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 7.3min | 3.6min | 692 | 0.0 | 54 | $1.48 | $0.74 | $1.48 |
| default | opus | 1 | 4.9min | 3.9min | 692 | 1.0 | 39 | $0.92 | $0.74 | $0.92 |
| bash | opus | 1 | 2.4min | 2.4min | 420 | 1.0 | 22 | $0.51 | $0.51 | $0.51 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 7.3min | 3.6min | 692 | 0.0 | 54 | $1.48 | $0.74 | $1.48 |
| default | opus | 1 | 4.9min | 3.9min | 692 | 1.0 | 39 | $0.92 | $0.74 | $0.92 |
| bash | opus | 1 | 2.4min | 2.4min | 420 | 1.0 | 22 | $0.51 | $0.51 | $0.51 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 2.4min | 2.4min | 420 | 1.0 | 22 | $0.51 | $0.51 | $0.51 |
| powershell | opus | 1 | 7.3min | 3.6min | 692 | 0.0 | 54 | $1.48 | $0.74 | $1.48 |
| default | opus | 1 | 4.9min | 3.9min | 692 | 1.0 | 39 | $0.92 | $0.74 | $0.92 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 7.3min | 3.6min | 692 | 0.0 | 54 | $1.48 | $0.74 | $1.48 |
| bash | opus | 1 | 2.4min | 2.4min | 420 | 1.0 | 22 | $0.51 | $0.51 | $0.51 |
| default | opus | 1 | 4.9min | 3.9min | 692 | 1.0 | 39 | $0.92 | $0.74 | $0.92 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 2.4min | 2.4min | 420 | 1.0 | 22 | $0.51 | $0.51 | $0.51 |
| default | opus | 1 | 4.9min | 3.9min | 692 | 1.0 | 39 | $0.92 | $0.74 | $0.92 |
| powershell | opus | 1 | 7.3min | 3.6min | 692 | 0.0 | 54 | $1.48 | $0.74 | $1.48 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 2.4min | 2.4min | 420 | 1.0 | 22 | $0.51 | $0.51 | $0.51 |
| default | opus | 1 | 4.9min | 3.9min | 692 | 1.0 | 39 | $0.92 | $0.74 | $0.92 |
| powershell | opus | 1 | 7.3min | 3.6min | 692 | 0.0 | 54 | $1.48 | $0.74 | $1.48 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 11 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 0.0min | 0.0% |
| default | opus | 15 | 3 | 20.0% | 0.4min | 2.7% | 0.1min | 0.9% | 0.3min | 1.9% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 1.3% | -0.2min | -1.3% | 0.0min | 0.0% |
| **—** | **—** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 15 | 3 | 20.0% | 0.4min | 2.7% | 0.1min | 0.9% | 0.3min | 1.9% | 0.0min | 0.0% |
| bash | opus | 11 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 1.3% | -0.2min | -1.3% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 11 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 0.0min | 0.0% |
| default | opus | 15 | 3 | 20.0% | 0.4min | 2.7% | 0.1min | 0.9% | 0.3min | 1.9% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 1.3% | -0.2min | -1.3% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 15 | 3 | 20.0% | 0.4min | 2.7% | 0.1min | 0.9% | 0.3min | 1.9% | 0.0min | 0.0% |
| bash | opus | 11 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 1.3% | -0.2min | -1.3% | 0.0min | 0.0% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| repeated-test-reruns | powershell | opus | 1 | 3.7min | 25.0% | $0.74 | 25.55% |
| **Total** | | | **2 runs** | **4.7min** | **31.9%** | **$0.93** | **31.97%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| repeated-test-reruns | powershell | opus | 1 | 3.7min | 25.0% | $0.74 | 25.55% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| repeated-test-reruns | powershell | opus | 1 | 3.7min | 25.0% | $0.74 | 25.55% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| repeated-test-reruns | powershell | opus | 1 | 3.7min | 25.0% | $0.74 | 25.55% |

</details>

#### Trap Descriptions

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
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| powershell | opus | 1 | 1 | 100% | 1 | 3.7min | 25.0% | $0.74 | 25.55% |
| **Total** | | **3** | **2** | **67%** | **2** | **4.7min** | **31.9%** | **$0.93** | **31.97%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| powershell | opus | 1 | 1 | 100% | 1 | 3.7min | 25.0% | $0.74 | 25.55% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| powershell | opus | 1 | 1 | 100% | 1 | 3.7min | 25.0% | $0.74 | 25.55% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| powershell | opus | 1 | 1 | 100% | 1 | 3.7min | 25.0% | $0.74 | 25.55% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 3 | $0.59 | 20.30% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **3** | **$0.59** | **20.30%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 2.4min | 22 | 420 | 1 | $0.51 | bash | ok |
| Semantic Version Bumper | default | opus | 4.9min | 39 | 692 | 1 | $0.92 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 7.3min | 54 | 692 | 0 | $1.48 | powershell | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 7.3min | 54 | 692 | 0 | $1.48 | powershell | ok |
| Semantic Version Bumper | default | opus | 4.9min | 39 | 692 | 1 | $0.92 | typescript | ok |
| Semantic Version Bumper | bash | opus | 2.4min | 22 | 420 | 1 | $0.51 | bash | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 7.3min | 54 | 692 | 0 | $1.48 | powershell | ok |
| Semantic Version Bumper | default | opus | 4.9min | 39 | 692 | 1 | $0.92 | typescript | ok |
| Semantic Version Bumper | bash | opus | 2.4min | 22 | 420 | 1 | $0.51 | bash | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 7.3min | 54 | 692 | 0 | $1.48 | powershell | ok |
| Semantic Version Bumper | bash | opus | 2.4min | 22 | 420 | 1 | $0.51 | bash | ok |
| Semantic Version Bumper | default | opus | 4.9min | 39 | 692 | 1 | $0.92 | typescript | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 2.4min | 22 | 420 | 1 | $0.51 | bash | ok |
| Semantic Version Bumper | default | opus | 4.9min | 39 | 692 | 1 | $0.92 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 7.3min | 54 | 692 | 0 | $1.48 | powershell | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 2.4min | 22 | 420 | 1 | $0.51 | bash | ok |
| Semantic Version Bumper | default | opus | 4.9min | 39 | 692 | 1 | $0.92 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 7.3min | 54 | 692 | 0 | $1.48 | powershell | ok |

</details>

---
*Generated by generate_results.py, instructions version v3*