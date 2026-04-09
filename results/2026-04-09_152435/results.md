# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 05:22:39 PM ET

**Status:** 13/64 runs completed, 51 remaining
**Total cost so far:** $17.02
**Total agent time so far:** 112.7 min

## Observations

- **Fastest (avg):** default/opus — 7.4min, then typescript-bun/opus — 7.7min
- **Fastest net of traps:** typescript-bun/opus — 6.8min, then typescript-bun/sonnet — 7.3min
- **Slowest (avg):** powershell/sonnet — 11.4min, then powershell/opus — 9.2min
- **Slowest net of traps:** powershell/sonnet — 10.4min, then powershell/opus — 9.2min
- **Cheapest (avg):** powershell/sonnet — $0.92, then typescript-bun/sonnet — $0.97
- **Cheapest net of traps:** powershell/sonnet — $0.84, then typescript-bun/sonnet — $0.88
- **Most expensive (avg):** powershell/opus — $1.49, then default/opus — $1.45
- **Most expensive net of traps:** powershell/opus — $1.49, then default/opus — $1.45

- **Estimated time remaining:** 442.2min
- **Estimated total cost:** $83.79

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.2% | 0.9min | 0.8% | -0.7min | -0.6% | 4.3min | -15.4% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.5% | 0.6min | 0.6% | -0.0min | -0.0% | 0.3min | -13.9% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.1% | -0.2min | -0.1% | 0.2min | -70.2% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.2% | -0.1min | -0.1% | 0.6min | -14.6% |
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 1.0% | 0.4min | 0.3% | 0.8min | 0.7% | 2.5min | 31.8% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 4.7min | -5.8% |
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 1.1% | 3.1min | 2.7% | -1.9min | -1.6% | 2.5min | -73.9% |
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.5% | 1.4min | 1.3% | -0.9min | -0.8% | 0.0min | -4530.2% |
| **Total** | | **138** | **20** | **14.5%** | **3.8min** | **3.4%** | **7.0min** | **6.2%** | **-3.2min** | **-2.8%** | **15.2min** | **-20.9%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 1.0% | 0.4min | 0.3% | 0.8min | 0.7% | 2.5min | 31.8% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.5% | 0.6min | 0.6% | -0.0min | -0.0% | 0.3min | -13.9% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.2% | -0.1min | -0.1% | 0.6min | -14.6% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.1% | -0.2min | -0.1% | 0.2min | -70.2% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 4.7min | -5.8% |
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.2% | 0.9min | 0.8% | -0.7min | -0.6% | 4.3min | -15.4% |
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.5% | 1.4min | 1.3% | -0.9min | -0.8% | 0.0min | -4530.2% |
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 1.1% | 3.1min | 2.7% | -1.9min | -1.6% | 2.5min | -73.9% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 1.0% | 0.4min | 0.3% | 0.8min | 0.7% | 2.5min | 31.8% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 4.7min | -5.8% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.5% | 0.6min | 0.6% | -0.0min | -0.0% | 0.3min | -13.9% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.2% | -0.1min | -0.1% | 0.6min | -14.6% |
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.2% | 0.9min | 0.8% | -0.7min | -0.6% | 4.3min | -15.4% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.1% | -0.2min | -0.1% | 0.2min | -70.2% |
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 1.1% | 3.1min | 2.7% | -1.9min | -1.6% | 2.5min | -73.9% |
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.5% | 1.4min | 1.3% | -0.9min | -0.8% | 0.0min | -4530.2% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 1.1% | 3.1min | 2.7% | -1.9min | -1.6% | 2.5min | -73.9% |
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.5% | 1.4min | 1.3% | -0.9min | -0.8% | 0.0min | -4530.2% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.5% | 0.6min | 0.6% | -0.0min | -0.0% | 0.3min | -13.9% |
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 1.0% | 0.4min | 0.3% | 0.8min | 0.7% | 2.5min | 31.8% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.2% | -0.1min | -0.1% | 0.6min | -14.6% |
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.2% | 0.9min | 0.8% | -0.7min | -0.6% | 4.3min | -15.4% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.1% | -0.2min | -0.1% | 0.2min | -70.2% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.2% | -0.3min | -0.2% | 4.7min | -5.8% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.6% | $0.33 | 1.92% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 0.7% | $0.10 | 0.57% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.7% | $0.11 | 0.65% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.4% | $0.21 | 1.22% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.9% | $0.08 | 0.47% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.7% | $0.11 | 0.68% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.6% | $0.09 | 0.52% |
| **Total** | | | **7 runs** | **7.4min** | **6.6%** | **$1.03** | **6.03%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.6% | $0.09 | 0.52% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.7% | $0.11 | 0.68% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 0.7% | $0.10 | 0.57% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.7% | $0.11 | 0.65% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.9% | $0.08 | 0.47% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.4% | $0.21 | 1.22% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.6% | $0.33 | 1.92% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.9% | $0.08 | 0.47% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.6% | $0.09 | 0.52% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 0.7% | $0.10 | 0.57% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.7% | $0.11 | 0.65% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.7% | $0.11 | 0.68% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.4% | $0.21 | 1.22% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.6% | $0.33 | 1.92% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 0.7% | $0.10 | 0.57% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.7% | $0.11 | 0.65% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.4% | $0.21 | 1.22% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.9% | $0.08 | 0.47% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.7% | $0.11 | 0.68% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.6% | $0.09 | 0.52% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.6% | $0.33 | 1.92% |

</details>

#### Trap Descriptions

- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **actionlint-fix-cycles**: Workflow YAML required 3+ actionlint runs and 2+ fixes to pass.
- **bats-setup-issues**: Agent struggled with bats-core test framework setup or load helpers.
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
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.3% | $0.20 | 1.18% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.7% | $0.11 | 0.68% |
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.4% | $0.21 | 1.22% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 0.9% | $0.08 | 0.47% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.6% | $0.33 | 1.92% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.7% | $0.10 | 0.57% |
| **Total** | | **13** | **7** | **54%** | **8** | **7.4min** | **6.6%** | **$1.03** | **6.03%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.7% | $0.11 | 0.68% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.7% | $0.10 | 0.57% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 0.9% | $0.08 | 0.47% |
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.3% | $0.20 | 1.18% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.4% | $0.21 | 1.22% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.6% | $0.33 | 1.92% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 0.9% | $0.08 | 0.47% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.7% | $0.10 | 0.57% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.7% | $0.11 | 0.68% |
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.3% | $0.20 | 1.18% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.4% | $0.21 | 1.22% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.6% | $0.33 | 1.92% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.3% | $0.20 | 1.18% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.4% | $0.21 | 1.22% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.7% | $0.11 | 0.68% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 0.9% | $0.08 | 0.47% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.6% | $0.33 | 1.92% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.7% | $0.10 | 0.57% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 11 | $1.53 | 9.02% |
| Miss | 2 | $0.00 | 0.00% |
| **Total** | **13** | **$1.53** | **9.02%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*