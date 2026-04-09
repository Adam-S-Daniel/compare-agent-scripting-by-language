# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 04:43:49 PM ET

**Status:** 8/64 runs completed, 56 remaining
**Total cost so far:** $9.82
**Total agent time so far:** 72.6 min

## Observations

- **Fastest (avg):** powershell/opus — 6.9min, then default/opus — 7.1min
- **Fastest net of traps:** default/sonnet — 5.8min, then powershell/opus — 6.9min
- **Slowest (avg):** bash/opus — 12.4min, then powershell/sonnet — 11.4min
- **Slowest net of traps:** bash/opus — 10.9min, then powershell/sonnet — 10.4min
- **Cheapest (avg):** powershell/sonnet — $0.92, then typescript-bun/sonnet — $0.97
- **Cheapest net of traps:** default/sonnet — $0.78, then powershell/sonnet — $0.84
- **Most expensive (avg):** bash/opus — $1.65, then typescript-bun/opus — $1.54
- **Most expensive net of traps:** bash/opus — $1.45, then typescript-bun/opus — $1.45

- **Estimated time remaining:** 508.0min
- **Estimated total cost:** $78.56

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 1 | 6.9min | 6.9min | 618 | 0.0 | 27 | $1.04 | $1.04 | $1.04 |
| default | opus | 1 | 7.1min | 7.1min | 878 | 1.0 | 28 | $1.33 | $1.33 | $1.33 |
| typescript-bun | sonnet | 1 | 8.1min | 7.3min | 1034 | 1.0 | 30 | $0.97 | $0.88 | $0.97 |
| typescript-bun | opus | 1 | 10.3min | 9.7min | 1071 | 1.0 | 32 | $1.54 | $1.45 | $1.54 |
| powershell | sonnet | 1 | 11.4min | 10.4min | 1255 | 3.0 | 43 | $0.92 | $0.84 | $0.92 |
| default | sonnet | 1 | 7.3min | 5.8min | 1311 | 1.0 | 46 | $0.99 | $0.78 | $0.99 |
| bash | opus | 1 | 12.4min | 10.9min | 1710 | 1.0 | 50 | $1.65 | $1.45 | $1.65 |
| bash | sonnet | 1 | 9.0min | 8.3min | 889 | 6.0 | 57 | $1.38 | $1.27 | $1.38 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 17 | 1 | 5.9% | 0.2min | 0.3% | 0.7min | 1.0% | -0.5min | -0.7% | 3.9min | -13.6% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.8% | 0.8min | 1.1% | -0.2min | -0.2% | 0.3min | -55.1% |
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.1% | -0.1min | -0.1% | 0.0min | 0.0% |
| default | sonnet | 6 | 1 | 16.7% | 0.1min | 0.2% | 0.1min | 0.1% | 0.1min | 0.1% | 0.2min | 29.5% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.5min | -9.7% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.4% | -0.3min | -0.4% | 4.7min | -6.2% |
| typescript-bun | opus | 11 | 3 | 27.3% | 0.4min | 0.6% | 2.4min | 3.3% | -2.0min | -2.7% | 1.7min | -115.8% |
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.7% | 1.9min | 2.7% | -1.4min | -1.9% | 0.0min | -6942.8% |
| **Total** | | **89** | **12** | **13.5%** | **1.9min** | **2.6%** | **6.4min** | **8.8%** | **-4.5min** | **-6.3%** | **12.4min** | **-36.7%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | sonnet | 6 | 1 | 16.7% | 0.1min | 0.2% | 0.1min | 0.1% | 0.1min | 0.1% | 0.2min | 29.5% |
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.1% | -0.1min | -0.1% | 0.0min | 0.0% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.5min | -9.7% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.8% | 0.8min | 1.1% | -0.2min | -0.2% | 0.3min | -55.1% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.4% | -0.3min | -0.4% | 4.7min | -6.2% |
| bash | opus | 17 | 1 | 5.9% | 0.2min | 0.3% | 0.7min | 1.0% | -0.5min | -0.7% | 3.9min | -13.6% |
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.7% | 1.9min | 2.7% | -1.4min | -1.9% | 0.0min | -6942.8% |
| typescript-bun | opus | 11 | 3 | 27.3% | 0.4min | 0.6% | 2.4min | 3.3% | -2.0min | -2.7% | 1.7min | -115.8% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | sonnet | 6 | 1 | 16.7% | 0.1min | 0.2% | 0.1min | 0.1% | 0.1min | 0.1% | 0.2min | 29.5% |
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.1% | -0.1min | -0.1% | 0.0min | 0.0% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.4% | -0.3min | -0.4% | 4.7min | -6.2% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.5min | -9.7% |
| bash | opus | 17 | 1 | 5.9% | 0.2min | 0.3% | 0.7min | 1.0% | -0.5min | -0.7% | 3.9min | -13.6% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.8% | 0.8min | 1.1% | -0.2min | -0.2% | 0.3min | -55.1% |
| typescript-bun | opus | 11 | 3 | 27.3% | 0.4min | 0.6% | 2.4min | 3.3% | -2.0min | -2.7% | 1.7min | -115.8% |
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.7% | 1.9min | 2.7% | -1.4min | -1.9% | 0.0min | -6942.8% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | sonnet | 9 | 4 | 44.4% | 0.5min | 0.7% | 1.9min | 2.7% | -1.4min | -1.9% | 0.0min | -6942.8% |
| typescript-bun | opus | 11 | 3 | 27.3% | 0.4min | 0.6% | 2.4min | 3.3% | -2.0min | -2.7% | 1.7min | -115.8% |
| bash | sonnet | 18 | 3 | 16.7% | 0.6min | 0.8% | 0.8min | 1.1% | -0.2min | -0.2% | 0.3min | -55.1% |
| default | sonnet | 6 | 1 | 16.7% | 0.1min | 0.2% | 0.1min | 0.1% | 0.1min | 0.1% | 0.2min | 29.5% |
| bash | opus | 17 | 1 | 5.9% | 0.2min | 0.3% | 0.7min | 1.0% | -0.5min | -0.7% | 3.9min | -13.6% |
| default | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.1% | -0.1min | -0.1% | 0.0min | 0.0% |
| powershell | opus | 7 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 1.5min | -9.7% |
| powershell | sonnet | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.3min | 0.4% | -0.3min | -0.4% | 4.7min | -6.2% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 1.1% | $0.11 | 1.13% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 2.1% | $0.21 | 2.11% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 0.6min | 0.8% | $0.09 | 0.91% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 1.1% | $0.10 | 0.98% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 1.4% | $0.08 | 0.82% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 1.0% | $0.11 | 1.17% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.9% | $0.09 | 0.91% |
| **Total** | | | **6 runs** | **6.2min** | **8.5%** | **$0.79** | **8.04%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 0.6min | 0.8% | $0.09 | 0.91% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.9% | $0.09 | 0.91% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 1.0% | $0.11 | 1.17% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 1.1% | $0.10 | 0.98% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 1.1% | $0.11 | 1.13% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 1.4% | $0.08 | 0.82% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 2.1% | $0.21 | 2.11% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 1.4% | $0.08 | 0.82% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.9% | $0.09 | 0.91% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 0.6min | 0.8% | $0.09 | 0.91% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 1.1% | $0.10 | 0.98% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 1.1% | $0.11 | 1.13% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 1.0% | $0.11 | 1.17% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 2.1% | $0.21 | 2.11% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 1.1% | $0.11 | 1.13% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 2.1% | $0.21 | 2.11% |
| ts-type-error-fix-cycles | typescript-bun | opus | 1 | 0.6min | 0.8% | $0.09 | 0.91% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 1 | 0.8min | 1.1% | $0.10 | 0.98% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 1.4% | $0.08 | 0.82% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 1.0% | $0.11 | 1.17% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.9% | $0.09 | 0.91% |

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
| bash | opus | 1 | 1 | 100% | 2 | 1.5min | 2.1% | $0.20 | 2.04% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 1.0% | $0.11 | 1.17% |
| default | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 1 | 1 | 100% | 1 | 1.5min | 2.1% | $0.21 | 2.11% |
| powershell | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 1.4% | $0.08 | 0.82% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 0.6min | 0.8% | $0.09 | 0.91% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 1.1% | $0.10 | 0.98% |
| **Total** | | **8** | **6** | **75%** | **7** | **6.2min** | **8.5%** | **$0.79** | **8.04%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 0.6min | 0.8% | $0.09 | 0.91% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 1.0% | $0.11 | 1.17% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 1.1% | $0.10 | 0.98% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 1.4% | $0.08 | 0.82% |
| bash | opus | 1 | 1 | 100% | 2 | 1.5min | 2.1% | $0.20 | 2.04% |
| default | sonnet | 1 | 1 | 100% | 1 | 1.5min | 2.1% | $0.21 | 2.11% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 1.4% | $0.08 | 0.82% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 0.6min | 0.8% | $0.09 | 0.91% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 1.1% | $0.10 | 0.98% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 1.0% | $0.11 | 1.17% |
| bash | opus | 1 | 1 | 100% | 2 | 1.5min | 2.1% | $0.20 | 2.04% |
| default | sonnet | 1 | 1 | 100% | 1 | 1.5min | 2.1% | $0.21 | 2.11% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | opus | 1 | 1 | 100% | 2 | 1.5min | 2.1% | $0.20 | 2.04% |
| bash | sonnet | 1 | 1 | 100% | 1 | 0.8min | 1.0% | $0.11 | 1.17% |
| default | sonnet | 1 | 1 | 100% | 1 | 1.5min | 2.1% | $0.21 | 2.11% |
| powershell | sonnet | 1 | 1 | 100% | 1 | 1.0min | 1.4% | $0.08 | 0.82% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 0.6min | 0.8% | $0.09 | 0.91% |
| typescript-bun | sonnet | 1 | 1 | 100% | 1 | 0.8min | 1.1% | $0.10 | 0.98% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 6 | $0.71 | 7.20% |
| Miss | 2 | $0.00 | 0.00% |
| **Total** | **8** | **$0.71** | **7.20%** |

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


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
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
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
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
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
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
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*