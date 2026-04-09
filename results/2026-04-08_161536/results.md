# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 02:52:54 PM ET

**Status:** 7/7 runs completed, 0 remaining
**Total cost so far:** $6.59
**Total agent time so far:** 43.4 min

## Observations

- **Fastest (avg):** bash/sonnet — 2.7min, then default/sonnet — 2.9min
- **Fastest net of traps:** bash/sonnet — 2.7min, then default/sonnet — 2.9min
- **Slowest (avg):** default/opus — 14.3min, then typescript-bun/opus — 9.0min
- **Slowest net of traps:** default/opus — 12.6min, then typescript-bun/opus — 4.9min
- **Cheapest (avg):** bash/sonnet — $0.40, then default/sonnet — $0.45
- **Cheapest net of traps:** bash/sonnet — $0.40, then default/sonnet — $0.45
- **Most expensive (avg):** typescript-bun/opus — $1.84, then powershell/opus — $1.51
- **Most expensive net of traps:** typescript-bun/opus — $1.00, then default/opus — $0.99

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 3.4min | 3.4min | 691 | 2.0 | 27 | $0.76 | $0.76 | $0.76 |
| bash | sonnet | 1 | 2.7min | 2.7min | 586 | 3.0 | 24 | $0.40 | $0.40 | $0.40 |
| default | opus | 1 | 14.3min | 12.6min | 649 | 2.0 | 39 | $1.12 | $0.99 | $1.12 |
| default | sonnet | 1 | 2.9min | 2.9min | 693 | 1.0 | 19 | $0.45 | $0.45 | $0.45 |
| powershell | opus | 1 | 7.9min | 4.2min | 656 | 2.0 | 50 | $1.51 | $0.81 | $1.51 |
| powershell | sonnet | 1 | 3.2min | 3.2min | 593 | 0.0 | 22 | $0.50 | $0.50 | $0.50 |
| typescript-bun | opus | 1 | 9.0min | 4.9min | 1205 | 8.0 | 65 | $1.84 | $1.00 | $1.84 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| typescript-bun | opus | 1 | 9.0min | 4.9min | 1205 | 8.0 | 65 | $1.84 | $1.00 | $1.84 |
| powershell | opus | 1 | 7.9min | 4.2min | 656 | 2.0 | 50 | $1.51 | $0.81 | $1.51 |
| default | opus | 1 | 14.3min | 12.6min | 649 | 2.0 | 39 | $1.12 | $0.99 | $1.12 |
| bash | opus | 1 | 3.4min | 3.4min | 691 | 2.0 | 27 | $0.76 | $0.76 | $0.76 |
| powershell | sonnet | 1 | 3.2min | 3.2min | 593 | 0.0 | 22 | $0.50 | $0.50 | $0.50 |
| default | sonnet | 1 | 2.9min | 2.9min | 693 | 1.0 | 19 | $0.45 | $0.45 | $0.45 |
| bash | sonnet | 1 | 2.7min | 2.7min | 586 | 3.0 | 24 | $0.40 | $0.40 | $0.40 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| typescript-bun | opus | 1 | 9.0min | 4.9min | 1205 | 8.0 | 65 | $1.84 | $1.00 | $1.84 |
| default | opus | 1 | 14.3min | 12.6min | 649 | 2.0 | 39 | $1.12 | $0.99 | $1.12 |
| powershell | opus | 1 | 7.9min | 4.2min | 656 | 2.0 | 50 | $1.51 | $0.81 | $1.51 |
| bash | opus | 1 | 3.4min | 3.4min | 691 | 2.0 | 27 | $0.76 | $0.76 | $0.76 |
| powershell | sonnet | 1 | 3.2min | 3.2min | 593 | 0.0 | 22 | $0.50 | $0.50 | $0.50 |
| default | sonnet | 1 | 2.9min | 2.9min | 693 | 1.0 | 19 | $0.45 | $0.45 | $0.45 |
| bash | sonnet | 1 | 2.7min | 2.7min | 586 | 3.0 | 24 | $0.40 | $0.40 | $0.40 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | sonnet | 1 | 2.7min | 2.7min | 586 | 3.0 | 24 | $0.40 | $0.40 | $0.40 |
| default | sonnet | 1 | 2.9min | 2.9min | 693 | 1.0 | 19 | $0.45 | $0.45 | $0.45 |
| powershell | sonnet | 1 | 3.2min | 3.2min | 593 | 0.0 | 22 | $0.50 | $0.50 | $0.50 |
| bash | opus | 1 | 3.4min | 3.4min | 691 | 2.0 | 27 | $0.76 | $0.76 | $0.76 |
| powershell | opus | 1 | 7.9min | 4.2min | 656 | 2.0 | 50 | $1.51 | $0.81 | $1.51 |
| typescript-bun | opus | 1 | 9.0min | 4.9min | 1205 | 8.0 | 65 | $1.84 | $1.00 | $1.84 |
| default | opus | 1 | 14.3min | 12.6min | 649 | 2.0 | 39 | $1.12 | $0.99 | $1.12 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | sonnet | 1 | 3.2min | 3.2min | 593 | 0.0 | 22 | $0.50 | $0.50 | $0.50 |
| default | sonnet | 1 | 2.9min | 2.9min | 693 | 1.0 | 19 | $0.45 | $0.45 | $0.45 |
| bash | opus | 1 | 3.4min | 3.4min | 691 | 2.0 | 27 | $0.76 | $0.76 | $0.76 |
| default | opus | 1 | 14.3min | 12.6min | 649 | 2.0 | 39 | $1.12 | $0.99 | $1.12 |
| powershell | opus | 1 | 7.9min | 4.2min | 656 | 2.0 | 50 | $1.51 | $0.81 | $1.51 |
| bash | sonnet | 1 | 2.7min | 2.7min | 586 | 3.0 | 24 | $0.40 | $0.40 | $0.40 |
| typescript-bun | opus | 1 | 9.0min | 4.9min | 1205 | 8.0 | 65 | $1.84 | $1.00 | $1.84 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | sonnet | 1 | 2.7min | 2.7min | 586 | 3.0 | 24 | $0.40 | $0.40 | $0.40 |
| powershell | sonnet | 1 | 3.2min | 3.2min | 593 | 0.0 | 22 | $0.50 | $0.50 | $0.50 |
| default | opus | 1 | 14.3min | 12.6min | 649 | 2.0 | 39 | $1.12 | $0.99 | $1.12 |
| powershell | opus | 1 | 7.9min | 4.2min | 656 | 2.0 | 50 | $1.51 | $0.81 | $1.51 |
| bash | opus | 1 | 3.4min | 3.4min | 691 | 2.0 | 27 | $0.76 | $0.76 | $0.76 |
| default | sonnet | 1 | 2.9min | 2.9min | 693 | 1.0 | 19 | $0.45 | $0.45 | $0.45 |
| typescript-bun | opus | 1 | 9.0min | 4.9min | 1205 | 8.0 | 65 | $1.84 | $1.00 | $1.84 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | sonnet | 1 | 2.9min | 2.9min | 693 | 1.0 | 19 | $0.45 | $0.45 | $0.45 |
| powershell | sonnet | 1 | 3.2min | 3.2min | 593 | 0.0 | 22 | $0.50 | $0.50 | $0.50 |
| bash | sonnet | 1 | 2.7min | 2.7min | 586 | 3.0 | 24 | $0.40 | $0.40 | $0.40 |
| bash | opus | 1 | 3.4min | 3.4min | 691 | 2.0 | 27 | $0.76 | $0.76 | $0.76 |
| default | opus | 1 | 14.3min | 12.6min | 649 | 2.0 | 39 | $1.12 | $0.99 | $1.12 |
| powershell | opus | 1 | 7.9min | 4.2min | 656 | 2.0 | 50 | $1.51 | $0.81 | $1.51 |
| typescript-bun | opus | 1 | 9.0min | 4.9min | 1205 | 8.0 | 65 | $1.84 | $1.00 | $1.84 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 8 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| bash | sonnet | 11 | 2 | 18.2% | 0.4min | 0.9% | 0.1min | 0.2% | 0.3min | 0.7% | 0.0min | 0.0% |
| default | opus | 15 | 2 | 13.3% | 0.3min | 0.6% | 0.1min | 0.3% | 0.1min | 0.3% | 0.0min | 0.0% |
| default | sonnet | 4 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.0min | 0.0% |
| powershell | opus | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 0.0min | 0.0% |
| powershell | sonnet | 9 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| typescript-bun | opus | 23 | 9 | 39.1% | 1.2min | 2.8% | 0.2min | 0.4% | 1.0min | 2.3% | 0.0min | 0.0% |
| **—** | **—** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 23 | 9 | 39.1% | 1.2min | 2.8% | 0.2min | 0.4% | 1.0min | 2.3% | 0.0min | 0.0% |
| bash | sonnet | 11 | 2 | 18.2% | 0.4min | 0.9% | 0.1min | 0.2% | 0.3min | 0.7% | 0.0min | 0.0% |
| default | opus | 15 | 2 | 13.3% | 0.3min | 0.6% | 0.1min | 0.3% | 0.1min | 0.3% | 0.0min | 0.0% |
| default | sonnet | 4 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.0min | 0.0% |
| bash | opus | 8 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| powershell | sonnet | 9 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| powershell | opus | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 8 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| bash | sonnet | 11 | 2 | 18.2% | 0.4min | 0.9% | 0.1min | 0.2% | 0.3min | 0.7% | 0.0min | 0.0% |
| default | opus | 15 | 2 | 13.3% | 0.3min | 0.6% | 0.1min | 0.3% | 0.1min | 0.3% | 0.0min | 0.0% |
| default | sonnet | 4 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.0min | 0.0% |
| powershell | opus | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 0.0min | 0.0% |
| powershell | sonnet | 9 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| typescript-bun | opus | 23 | 9 | 39.1% | 1.2min | 2.8% | 0.2min | 0.4% | 1.0min | 2.3% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 23 | 9 | 39.1% | 1.2min | 2.8% | 0.2min | 0.4% | 1.0min | 2.3% | 0.0min | 0.0% |
| bash | sonnet | 11 | 2 | 18.2% | 0.4min | 0.9% | 0.1min | 0.2% | 0.3min | 0.7% | 0.0min | 0.0% |
| default | opus | 15 | 2 | 13.3% | 0.3min | 0.6% | 0.1min | 0.3% | 0.1min | 0.3% | 0.0min | 0.0% |
| bash | opus | 8 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| default | sonnet | 4 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.0min | 0.0% |
| powershell | opus | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 0.0min | 0.0% |
| powershell | sonnet | 9 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| repeated-test-reruns | powershell | opus | 1 | 2.0min | 4.6% | $0.38 | 5.83% |
| repeated-test-reruns | typescript-bun | opus | 2 | 2.3min | 5.4% | $0.47 | 7.21% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 1.8min | 4.1% | $0.37 | 5.56% |
| act-push-debug-loops | powershell | opus | 1 | 1.7min | 3.8% | $0.32 | 4.86% |
| **Total** | | | **3 runs** | **9.5min** | **21.8%** | **$1.68** | **25.45%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| act-push-debug-loops | powershell | opus | 1 | 1.7min | 3.8% | $0.32 | 4.86% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 1.8min | 4.1% | $0.37 | 5.56% |
| repeated-test-reruns | powershell | opus | 1 | 2.0min | 4.6% | $0.38 | 5.83% |
| repeated-test-reruns | typescript-bun | opus | 2 | 2.3min | 5.4% | $0.47 | 7.21% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| act-push-debug-loops | powershell | opus | 1 | 1.7min | 3.8% | $0.32 | 4.86% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 1.8min | 4.1% | $0.37 | 5.56% |
| repeated-test-reruns | powershell | opus | 1 | 2.0min | 4.6% | $0.38 | 5.83% |
| repeated-test-reruns | typescript-bun | opus | 2 | 2.3min | 5.4% | $0.47 | 7.21% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| repeated-test-reruns | powershell | opus | 1 | 2.0min | 4.6% | $0.38 | 5.83% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 1.8min | 4.1% | $0.37 | 5.56% |
| act-push-debug-loops | powershell | opus | 1 | 1.7min | 3.8% | $0.32 | 4.86% |
| repeated-test-reruns | typescript-bun | opus | 2 | 2.3min | 5.4% | $0.47 | 7.21% |

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
| bash | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| default | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.7min | 8.4% | $0.70 | 10.69% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| typescript-bun | opus | 1 | 1 | 100% | 3 | 4.1min | 9.5% | $0.84 | 12.77% |
| **Total** | | **7** | **3** | **43%** | **6** | **9.5min** | **21.8%** | **$1.68** | **25.45%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.7min | 8.4% | $0.70 | 10.69% |
| typescript-bun | opus | 1 | 1 | 100% | 3 | 4.1min | 9.5% | $0.84 | 12.77% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.7min | 8.4% | $0.70 | 10.69% |
| typescript-bun | opus | 1 | 1 | 100% | 3 | 4.1min | 9.5% | $0.84 | 12.77% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.7min | 8.4% | $0.70 | 10.69% |
| typescript-bun | opus | 1 | 1 | 100% | 3 | 4.1min | 9.5% | $0.84 | 12.77% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 7 | $0.90 | 13.71% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **7** | **$0.90** | **13.71%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 3.4min | 27 | 691 | 2 | $0.76 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 2.7min | 24 | 586 | 3 | $0.40 | bash | ok |
| Semantic Version Bumper | default | opus | 14.3min | 39 | 649 | 2 | $1.12 | python | ok |
| Semantic Version Bumper | default | sonnet | 2.9min | 19 | 693 | 1 | $0.45 | python | ok |
| Semantic Version Bumper | powershell | opus | 7.9min | 50 | 656 | 2 | $1.51 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 3.2min | 22 | 593 | 0 | $0.50 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 9.0min | 65 | 1205 | 8 | $1.84 | typescript | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | typescript-bun | opus | 9.0min | 65 | 1205 | 8 | $1.84 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 7.9min | 50 | 656 | 2 | $1.51 | powershell | ok |
| Semantic Version Bumper | default | opus | 14.3min | 39 | 649 | 2 | $1.12 | python | ok |
| Semantic Version Bumper | bash | opus | 3.4min | 27 | 691 | 2 | $0.76 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 3.2min | 22 | 593 | 0 | $0.50 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 2.9min | 19 | 693 | 1 | $0.45 | python | ok |
| Semantic Version Bumper | bash | sonnet | 2.7min | 24 | 586 | 3 | $0.40 | bash | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 14.3min | 39 | 649 | 2 | $1.12 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 9.0min | 65 | 1205 | 8 | $1.84 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 7.9min | 50 | 656 | 2 | $1.51 | powershell | ok |
| Semantic Version Bumper | bash | opus | 3.4min | 27 | 691 | 2 | $0.76 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 3.2min | 22 | 593 | 0 | $0.50 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 2.9min | 19 | 693 | 1 | $0.45 | python | ok |
| Semantic Version Bumper | bash | sonnet | 2.7min | 24 | 586 | 3 | $0.40 | bash | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | sonnet | 3.2min | 22 | 593 | 0 | $0.50 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 2.9min | 19 | 693 | 1 | $0.45 | python | ok |
| Semantic Version Bumper | bash | opus | 3.4min | 27 | 691 | 2 | $0.76 | bash | ok |
| Semantic Version Bumper | default | opus | 14.3min | 39 | 649 | 2 | $1.12 | python | ok |
| Semantic Version Bumper | powershell | opus | 7.9min | 50 | 656 | 2 | $1.51 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 2.7min | 24 | 586 | 3 | $0.40 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus | 9.0min | 65 | 1205 | 8 | $1.84 | typescript | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | sonnet | 2.7min | 24 | 586 | 3 | $0.40 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 3.2min | 22 | 593 | 0 | $0.50 | powershell | ok |
| Semantic Version Bumper | default | opus | 14.3min | 39 | 649 | 2 | $1.12 | python | ok |
| Semantic Version Bumper | powershell | opus | 7.9min | 50 | 656 | 2 | $1.51 | powershell | ok |
| Semantic Version Bumper | bash | opus | 3.4min | 27 | 691 | 2 | $0.76 | bash | ok |
| Semantic Version Bumper | default | sonnet | 2.9min | 19 | 693 | 1 | $0.45 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 9.0min | 65 | 1205 | 8 | $1.84 | typescript | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | sonnet | 2.9min | 19 | 693 | 1 | $0.45 | python | ok |
| Semantic Version Bumper | powershell | sonnet | 3.2min | 22 | 593 | 0 | $0.50 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 2.7min | 24 | 586 | 3 | $0.40 | bash | ok |
| Semantic Version Bumper | bash | opus | 3.4min | 27 | 691 | 2 | $0.76 | bash | ok |
| Semantic Version Bumper | default | opus | 14.3min | 39 | 649 | 2 | $1.12 | python | ok |
| Semantic Version Bumper | powershell | opus | 7.9min | 50 | 656 | 2 | $1.51 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 9.0min | 65 | 1205 | 8 | $1.84 | typescript | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v3*