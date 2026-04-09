# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 05:05:46 PM ET

**Status:** 11/64 runs completed, 53 remaining
**Total cost so far:** $14.48
**Total agent time so far:** 97.3 min

## Observations

- **Fastest (avg):** default/sonnet — 7.3min, then default/opus — 7.4min
- **Fastest net of traps:** default/sonnet — 5.8min, then typescript-bun/sonnet — 7.3min
- **Slowest (avg):** powershell/sonnet — 11.4min, then typescript-bun/opus — 10.3min
- **Slowest net of traps:** powershell/sonnet — 10.4min, then typescript-bun/opus — 9.7min
- **Cheapest (avg):** powershell/sonnet — $0.92, then typescript-bun/sonnet — $0.97
- **Cheapest net of traps:** default/sonnet — $0.78, then powershell/sonnet — $0.84
- **Most expensive (avg):** typescript-bun/opus — $1.54, then powershell/opus — $1.49
- **Most expensive net of traps:** powershell/opus — $1.49, then typescript-bun/opus — $1.45

- **Estimated time remaining:** 468.6min
- **Estimated total cost:** $84.27

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
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
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.2% | 0.9min | 0.9% | -0.7min | -0.7% | 4.3min | -15.4% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.6% | 0.6min | 0.7% | -0.0min | -0.0% | 0.3min | -13.9% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.2% | -0.2min | -0.2% | 0.2min | -70.2% |
| default | sonnet | 6 | 1 | 16.7% | 0.1min | 0.1% | 0.1min | 0.1% | 0.1min | 0.1% | 0.2min | 35.9% |
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 1.2% | 0.4min | 0.4% | 0.8min | 0.8% | 2.5min | 31.8% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.3% | -0.3min | -0.3% | 4.7min | -5.8% |
| typescript-bun | opus | 11 | 3 | 27.3% | 0.4min | 0.4% | 2.4min | 2.4% | -2.0min | -2.0% | 1.7min | -115.8% |
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.5% | 1.9min | 2.0% | -1.4min | -1.4% | 0.0min | -6942.8% |
| **Total** | | **115** | **14** | **12.2%** | **3.0min** | **3.1%** | **6.7min** | **6.8%** | **-3.6min** | **-3.7%** | **14.0min** | **-25.8%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 1.2% | 0.4min | 0.4% | 0.8min | 0.8% | 2.5min | 31.8% |
| default | sonnet | 6 | 1 | 16.7% | 0.1min | 0.1% | 0.1min | 0.1% | 0.1min | 0.1% | 0.2min | 35.9% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.6% | 0.6min | 0.7% | -0.0min | -0.0% | 0.3min | -13.9% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.2% | -0.2min | -0.2% | 0.2min | -70.2% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.3% | -0.3min | -0.3% | 4.7min | -5.8% |
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.2% | 0.9min | 0.9% | -0.7min | -0.7% | 4.3min | -15.4% |
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.5% | 1.9min | 2.0% | -1.4min | -1.4% | 0.0min | -6942.8% |
| typescript-bun | opus | 11 | 3 | 27.3% | 0.4min | 0.4% | 2.4min | 2.4% | -2.0min | -2.0% | 1.7min | -115.8% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | sonnet | 6 | 1 | 16.7% | 0.1min | 0.1% | 0.1min | 0.1% | 0.1min | 0.1% | 0.2min | 35.9% |
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 1.2% | 0.4min | 0.4% | 0.8min | 0.8% | 2.5min | 31.8% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.3% | -0.3min | -0.3% | 4.7min | -5.8% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.6% | 0.6min | 0.7% | -0.0min | -0.0% | 0.3min | -13.9% |
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.2% | 0.9min | 0.9% | -0.7min | -0.7% | 4.3min | -15.4% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.2% | -0.2min | -0.2% | 0.2min | -70.2% |
| typescript-bun | opus | 11 | 3 | 27.3% | 0.4min | 0.4% | 2.4min | 2.4% | -2.0min | -2.0% | 1.7min | -115.8% |
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.5% | 1.9min | 2.0% | -1.4min | -1.4% | 0.0min | -6942.8% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.5% | 1.9min | 2.0% | -1.4min | -1.4% | 0.0min | -6942.8% |
| typescript-bun | opus | 11 | 3 | 27.3% | 0.4min | 0.4% | 2.4min | 2.4% | -2.0min | -2.0% | 1.7min | -115.8% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.6% | 0.6min | 0.7% | -0.0min | -0.0% | 0.3min | -13.9% |
| default | sonnet | 6 | 1 | 16.7% | 0.1min | 0.1% | 0.1min | 0.1% | 0.1min | 0.1% | 0.2min | 35.9% |
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 1.2% | 0.4min | 0.4% | 0.8min | 0.8% | 2.5min | 31.8% |
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.2% | 0.9min | 0.9% | -0.7min | -0.7% | 4.3min | -15.4% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.2% | -0.2min | -0.2% | 0.2min | -70.2% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.3% | -0.3min | -0.3% | 4.7min | -5.8% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.9% | $0.11 | 0.77% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.6% | $0.21 | 1.43% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 0.6min | 0.6% | $0.09 | 0.62% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 0.8% | $0.10 | 0.67% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 1.0% | $0.08 | 0.56% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.8% | $0.11 | 0.79% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.7% | $0.09 | 0.61% |
| **Total** | | | **6 runs** | **6.2min** | **6.4%** | **$0.79** | **5.45%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 0.6min | 0.6% | $0.09 | 0.62% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.7% | $0.09 | 0.61% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.8% | $0.11 | 0.79% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 0.8% | $0.10 | 0.67% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.9% | $0.11 | 0.77% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 1.0% | $0.08 | 0.56% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.6% | $0.21 | 1.43% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 1.0% | $0.08 | 0.56% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.7% | $0.09 | 0.61% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 0.6min | 0.6% | $0.09 | 0.62% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 0.8% | $0.10 | 0.67% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.9% | $0.11 | 0.77% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.8% | $0.11 | 0.79% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.6% | $0.21 | 1.43% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.9% | $0.11 | 0.77% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.6% | $0.21 | 1.43% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 0.6min | 0.6% | $0.09 | 0.62% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 0.8% | $0.10 | 0.67% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 1.0% | $0.08 | 0.56% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.8% | $0.11 | 0.79% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.7% | $0.09 | 0.61% |

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
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.5% | $0.20 | 1.38% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.8% | $0.11 | 0.79% |
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 1 | 1 | 100% | 1 | 1.5min | 1.6% | $0.21 | 1.43% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 1.0% | $0.08 | 0.56% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 0.6min | 0.6% | $0.09 | 0.62% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.8% | $0.10 | 0.67% |
| **Total** | | **11** | **6** | **55%** | **7** | **6.2min** | **6.4%** | **$0.79** | **5.45%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 0.6min | 0.6% | $0.09 | 0.62% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.8% | $0.11 | 0.79% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.8% | $0.10 | 0.67% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 1.0% | $0.08 | 0.56% |
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.5% | $0.20 | 1.38% |
| default | sonnet | 1 | 1 | 100% | 1 | 1.5min | 1.6% | $0.21 | 1.43% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 1.0% | $0.08 | 0.56% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 0.6min | 0.6% | $0.09 | 0.62% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.8% | $0.10 | 0.67% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.8% | $0.11 | 0.79% |
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.5% | $0.20 | 1.38% |
| default | sonnet | 1 | 1 | 100% | 1 | 1.5min | 1.6% | $0.21 | 1.43% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.5% | $0.20 | 1.38% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.8% | $0.11 | 0.79% |
| default | sonnet | 1 | 1 | 100% | 1 | 1.5min | 1.6% | $0.21 | 1.43% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 1.0% | $0.08 | 0.56% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 0.6min | 0.6% | $0.09 | 0.62% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 0.8% | $0.10 | 0.67% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 9 | $1.30 | 8.97% |
| Miss | 2 | $0.00 | 0.00% |
| **Total** | **11** | **$1.30** | **8.97%** |

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


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
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
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |

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
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
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
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*