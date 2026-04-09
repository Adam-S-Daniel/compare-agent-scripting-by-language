# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 12:23:16 PM ET

**Status:** 1/1 runs completed, 0 remaining
**Total cost so far:** $1.16
**Total agent time so far:** 5.3 min

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | opus | 1 | 5.3min | 504 | 1.0 | 42 | $1.16 | $1.16 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | opus | 1 | 5.3min | 504 | 1.0 | 42 | $1.16 | $1.16 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | opus | 1 | 5.3min | 504 | 1.0 | 42 | $1.16 | $1.16 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | opus | 1 | 5.3min | 504 | 1.0 | 42 | $1.16 | $1.16 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | opus | 1 | 5.3min | 504 | 1.0 | 42 | $1.16 | $1.16 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 3.5% | -0.2min | -3.5% | 0.0min | 0.0% |
| **—** | **—** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 3.5% | -0.2min | -3.5% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 3.5% | -0.2min | -3.5% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 3.5% | -0.2min | -3.5% | 0.0min | 0.0% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 2.3min | 44.1% | $0.51 | 44.09% |
| **Total** | | | **1 runs** | **2.3min** | **44.1%** | **$0.51** | **44.09%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 2.3min | 44.1% | $0.51 | 44.09% |

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
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 44.1% | $0.51 | 44.09% |
| **Total** | | **1** | **1** | **100%** | **1** | **2.3min** | **44.1%** | **$0.51** | **44.09%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 1 | $0.20 | 16.94% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **1** | **$0.20** | **16.94%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 5.3min | 42 | 504 | 1 | $1.16 | python | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 5.3min | 42 | 504 | 1 | $1.16 | python | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 5.3min | 42 | 504 | 1 | $1.16 | python | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 5.3min | 42 | 504 | 1 | $1.16 | python | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 5.3min | 42 | 504 | 1 | $1.16 | python | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 5.3min | 42 | 504 | 1 | $1.16 | python | ok |

</details>

---
*Generated by generate_results.py, instructions version v3*