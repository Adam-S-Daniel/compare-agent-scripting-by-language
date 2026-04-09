# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 11:44:54 AM ET

**Status:** 4/4 runs completed, 0 remaining
**Total cost so far:** $6.95
**Total agent time so far:** 31.7 min

## Observations

- **Fastest (avg):** typescript-bun/opus — 5.4min
- **Slowest (avg):** powershell/opus — 12.5min
- **Cheapest (avg):** typescript-bun/opus — $0.93
- **Most expensive (avg):** powershell/opus — $2.40
- **Fastest single run:** Semantic Version Bumper / typescript-bun / opus — 5.4min
- **Slowest single run:** Semantic Version Bumper / powershell / opus — 12.5min
- **Most errors:** Semantic Version Bumper / bash / opus — 2 errors
- **Fewest errors:** Semantic Version Bumper / powershell / opus — 0 errors

- **Avg cost per run (opus):** $1.74

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | opus | 1 | 5.5min | 1016 | 2.0 | 45 | $1.22 | $1.22 |
| default | opus | 1 | 8.3min | 896 | 1.0 | 77 | $2.39 | $2.39 |
| powershell | opus | 1 | 12.5min | 1033 | 0.0 | 71 | $2.40 | $2.40 |
| typescript-bun | opus | 1 | 5.4min | 1029 | 2.0 | 33 | $0.93 | $0.93 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | opus | 1 | 12.5min | 1033 | 0.0 | 71 | $2.40 | $2.40 |
| default | opus | 1 | 8.3min | 896 | 1.0 | 77 | $2.39 | $2.39 |
| bash | opus | 1 | 5.5min | 1016 | 2.0 | 45 | $1.22 | $1.22 |
| typescript-bun | opus | 1 | 5.4min | 1029 | 2.0 | 33 | $0.93 | $0.93 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | opus | 1 | 12.5min | 1033 | 0.0 | 71 | $2.40 | $2.40 |
| default | opus | 1 | 8.3min | 896 | 1.0 | 77 | $2.39 | $2.39 |
| bash | opus | 1 | 5.5min | 1016 | 2.0 | 45 | $1.22 | $1.22 |
| typescript-bun | opus | 1 | 5.4min | 1029 | 2.0 | 33 | $0.93 | $0.93 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | opus | 1 | 8.3min | 896 | 1.0 | 77 | $2.39 | $2.39 |
| bash | opus | 1 | 5.5min | 1016 | 2.0 | 45 | $1.22 | $1.22 |
| typescript-bun | opus | 1 | 5.4min | 1029 | 2.0 | 33 | $0.93 | $0.93 |
| powershell | opus | 1 | 12.5min | 1033 | 0.0 | 71 | $2.40 | $2.40 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| typescript-bun | opus | 1 | 5.4min | 1029 | 2.0 | 33 | $0.93 | $0.93 |
| bash | opus | 1 | 5.5min | 1016 | 2.0 | 45 | $1.22 | $1.22 |
| powershell | opus | 1 | 12.5min | 1033 | 0.0 | 71 | $2.40 | $2.40 |
| default | opus | 1 | 8.3min | 896 | 1.0 | 77 | $2.39 | $2.39 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| default | opus | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.7% | -0.2min | -0.7% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.6% | -0.2min | -0.6% | 0.0min | 0.0% |
| typescript-bun | opus | 12 | 6 | 50.0% | 0.8min | 2.5% | 0.1min | 0.3% | 0.7min | 2.2% | 0.0min | 0.0% |
| **—** | **—** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 12 | 6 | 50.0% | 0.8min | 2.5% | 0.1min | 0.3% | 0.7min | 2.2% | 0.0min | 0.0% |
| bash | opus | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.6% | -0.2min | -0.6% | 0.0min | 0.0% |
| default | opus | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.7% | -0.2min | -0.7% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| default | opus | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.7% | -0.2min | -0.7% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.6% | -0.2min | -0.6% | 0.0min | 0.0% |
| typescript-bun | opus | 12 | 6 | 50.0% | 0.8min | 2.5% | 0.1min | 0.3% | 0.7min | 2.2% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 12 | 6 | 50.0% | 0.8min | 2.5% | 0.1min | 0.3% | 0.7min | 2.2% | 0.0min | 0.0% |
| bash | opus | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| default | opus | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.7% | -0.2min | -0.7% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.6% | -0.2min | -0.6% | 0.0min | 0.0% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 2.3min | 7.4% | $0.68 | 9.72% |
| repeated-test-reruns | powershell | opus | 1 | 2.7min | 8.4% | $0.51 | 7.38% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| act-push-debug-loops | powershell | opus | 1 | 0.8min | 2.6% | $0.16 | 2.31% |
| **Total** | | | **3 runs** | **7.0min** | **22.2%** | **$1.55** | **22.38%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | powershell | opus | 1 | 0.8min | 2.6% | $0.16 | 2.31% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| repeated-test-reruns | default | opus | 1 | 2.3min | 7.4% | $0.68 | 9.72% |
| repeated-test-reruns | powershell | opus | 1 | 2.7min | 8.4% | $0.51 | 7.38% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | powershell | opus | 1 | 0.8min | 2.6% | $0.16 | 2.31% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| repeated-test-reruns | powershell | opus | 1 | 2.7min | 8.4% | $0.51 | 7.38% |
| repeated-test-reruns | default | opus | 1 | 2.3min | 7.4% | $0.68 | 9.72% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 2.3min | 7.4% | $0.68 | 9.72% |
| repeated-test-reruns | powershell | opus | 1 | 2.7min | 8.4% | $0.51 | 7.38% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| act-push-debug-loops | powershell | opus | 1 | 0.8min | 2.6% | $0.16 | 2.31% |

</details>

#### Trap Descriptions

- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **repeated-test-reruns**: Same test command executed 4+ times without the underlying code changing.
- **ts-type-error-fix-cycles**: TypeScript type errors caught by `tsc --noEmit` hooks; each requires a fix cycle.

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
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 7.4% | $0.68 | 9.72% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.5min | 11.0% | $0.67 | 9.69% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| **Total** | | **4** | **3** | **75%** | **4** | **7.0min** | **22.2%** | **$1.55** | **22.38%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 7.4% | $0.68 | 9.72% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.5min | 11.0% | $0.67 | 9.69% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.5min | 11.0% | $0.67 | 9.69% |
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 7.4% | $0.68 | 9.72% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 7.4% | $0.68 | 9.72% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.5min | 11.0% | $0.67 | 9.69% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 1.2min | 3.8% | $0.21 | 2.97% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 4 | $0.79 | 11.33% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **4** | **$0.79** | **11.33%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 5.5min | 45 | 1016 | 2 | $1.22 | bash | ok |
| Semantic Version Bumper | default | opus | 8.3min | 77 | 896 | 1 | $2.39 | python | ok |
| Semantic Version Bumper | powershell | opus | 12.5min | 71 | 1033 | 0 | $2.40 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 5.4min | 33 | 1029 | 2 | $0.93 | typescript | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 12.5min | 71 | 1033 | 0 | $2.40 | powershell | ok |
| Semantic Version Bumper | default | opus | 8.3min | 77 | 896 | 1 | $2.39 | python | ok |
| Semantic Version Bumper | bash | opus | 5.5min | 45 | 1016 | 2 | $1.22 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus | 5.4min | 33 | 1029 | 2 | $0.93 | typescript | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 12.5min | 71 | 1033 | 0 | $2.40 | powershell | ok |
| Semantic Version Bumper | default | opus | 8.3min | 77 | 896 | 1 | $2.39 | python | ok |
| Semantic Version Bumper | bash | opus | 5.5min | 45 | 1016 | 2 | $1.22 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus | 5.4min | 33 | 1029 | 2 | $0.93 | typescript | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 12.5min | 71 | 1033 | 0 | $2.40 | powershell | ok |
| Semantic Version Bumper | default | opus | 8.3min | 77 | 896 | 1 | $2.39 | python | ok |
| Semantic Version Bumper | bash | opus | 5.5min | 45 | 1016 | 2 | $1.22 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus | 5.4min | 33 | 1029 | 2 | $0.93 | typescript | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 8.3min | 77 | 896 | 1 | $2.39 | python | ok |
| Semantic Version Bumper | bash | opus | 5.5min | 45 | 1016 | 2 | $1.22 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus | 5.4min | 33 | 1029 | 2 | $0.93 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 12.5min | 71 | 1033 | 0 | $2.40 | powershell | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | typescript-bun | opus | 5.4min | 33 | 1029 | 2 | $0.93 | typescript | ok |
| Semantic Version Bumper | bash | opus | 5.5min | 45 | 1016 | 2 | $1.22 | bash | ok |
| Semantic Version Bumper | powershell | opus | 12.5min | 71 | 1033 | 0 | $2.40 | powershell | ok |
| Semantic Version Bumper | default | opus | 8.3min | 77 | 896 | 1 | $2.39 | python | ok |

</details>

---
*Generated by generate_results.py, instructions version v3*