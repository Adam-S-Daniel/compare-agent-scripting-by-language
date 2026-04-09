# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 05:50:28 PM ET

**Status:** 16/64 runs completed, 48 remaining
**Total cost so far:** $20.72
**Total agent time so far:** 142.8 min

## Observations

- **Fastest (avg):** default/opus — 7.4min, then typescript-bun/opus — 7.7min
- **Fastest net of traps:** typescript-bun/sonnet — 6.7min, then typescript-bun/opus — 6.8min
- **Slowest (avg):** bash/sonnet — 11.1min, then powershell/sonnet — 10.1min
- **Slowest net of traps:** bash/sonnet — 10.7min, then powershell/opus — 9.2min
- **Cheapest (avg):** typescript-bun/sonnet — $0.93, then powershell/sonnet — $1.01
- **Cheapest net of traps:** typescript-bun/sonnet — $0.77, then powershell/sonnet — $0.83
- **Most expensive (avg):** bash/sonnet — $1.55, then powershell/opus — $1.49
- **Most expensive net of traps:** bash/sonnet — $1.50, then powershell/opus — $1.49

- **Estimated time remaining:** 428.3min
- **Estimated total cost:** $82.89

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |

</details>

<details>
<summary>Sorted by avg cost net of traps (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | opus | 2 | 7.4min | 7.4min | 900 | 1.5 | 28 | $1.45 | $1.45 | $2.90 |
| powershell | opus | 2 | 9.2min | 9.2min | 728 | 1.0 | 31 | $1.49 | $1.49 | $2.97 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| bash | opus | 2 | 9.0min | 8.2min | 1098 | 1.5 | 46 | $1.41 | $1.31 | $2.81 |
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.1% | 0.5min | 0.4% | -0.3min | -0.2% | 4.3min | -7.5% |
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.7% | 0.6min | 0.4% | 0.4min | 0.3% | 1.5min | 25.8% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.1% | -0.2min | -0.1% | 0.2min | -70.2% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.2% | -0.1min | -0.1% | 0.6min | -14.6% |
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 0.8% | 0.3min | 0.2% | 0.8min | 0.6% | 2.5min | 32.4% |
| powershell | sonnet | 20 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.3% | -0.4min | -0.3% | 5.5min | -6.9% |
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 0.8% | 3.0min | 2.1% | -1.8min | -1.3% | 2.5min | -71.7% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.7% | 3.2min | 2.2% | -2.1min | -1.5% | 0.0min | -7355.4% |
| **Total** | | **165** | **26** | **15.8%** | **4.8min** | **3.3%** | **8.4min** | **5.9%** | **-3.6min** | **-2.5%** | **17.2min** | **-21.0%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 0.8% | 0.3min | 0.2% | 0.8min | 0.6% | 2.5min | 32.4% |
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.7% | 0.6min | 0.4% | 0.4min | 0.3% | 1.5min | 25.8% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.2% | -0.1min | -0.1% | 0.6min | -14.6% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.1% | -0.2min | -0.1% | 0.2min | -70.2% |
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.1% | 0.5min | 0.4% | -0.3min | -0.2% | 4.3min | -7.5% |
| powershell | sonnet | 20 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.3% | -0.4min | -0.3% | 5.5min | -6.9% |
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 0.8% | 3.0min | 2.1% | -1.8min | -1.3% | 2.5min | -71.7% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.7% | 3.2min | 2.2% | -2.1min | -1.5% | 0.0min | -7355.4% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 0.8% | 0.3min | 0.2% | 0.8min | 0.6% | 2.5min | 32.4% |
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.7% | 0.6min | 0.4% | 0.4min | 0.3% | 1.5min | 25.8% |
| powershell | sonnet | 20 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.3% | -0.4min | -0.3% | 5.5min | -6.9% |
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.1% | 0.5min | 0.4% | -0.3min | -0.2% | 4.3min | -7.5% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.2% | -0.1min | -0.1% | 0.6min | -14.6% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.1% | -0.2min | -0.1% | 0.2min | -70.2% |
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 0.8% | 3.0min | 2.1% | -1.8min | -1.3% | 2.5min | -71.7% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.7% | 3.2min | 2.2% | -2.1min | -1.5% | 0.0min | -7355.4% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 0.8% | 3.0min | 2.1% | -1.8min | -1.3% | 2.5min | -71.7% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.7% | 3.2min | 2.2% | -2.1min | -1.5% | 0.0min | -7355.4% |
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.7% | 0.6min | 0.4% | 0.4min | 0.3% | 1.5min | 25.8% |
| powershell | opus | 18 | 2 | 11.1% | 1.2min | 0.8% | 0.3min | 0.2% | 0.8min | 0.6% | 2.5min | 32.4% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.2% | -0.1min | -0.1% | 0.6min | -14.6% |
| bash | opus | 24 | 1 | 4.2% | 0.2min | 0.1% | 0.5min | 0.4% | -0.3min | -0.2% | 4.3min | -7.5% |
| default | opus | 15 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.1% | -0.2min | -0.1% | 0.2min | -70.2% |
| powershell | sonnet | 20 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.3% | -0.4min | -0.3% | 5.5min | -6.9% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.6% | $0.11 | 0.54% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.1% | $0.21 | 1.00% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.8% | $0.13 | 0.64% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.3% | $0.33 | 1.58% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 1.1% | $0.18 | 0.89% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.6% | $0.28 | 1.35% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.7% | $0.08 | 0.39% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.5% | $0.11 | 0.55% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.5% | $0.09 | 0.43% |
| **Total** | | | **9 runs** | **11.7min** | **8.2%** | **$1.53** | **7.36%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.5% | $0.09 | 0.43% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.5% | $0.11 | 0.55% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.6% | $0.11 | 0.54% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.7% | $0.08 | 0.39% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.8% | $0.13 | 0.64% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.1% | $0.21 | 1.00% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 1.1% | $0.18 | 0.89% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.3% | $0.33 | 1.58% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.6% | $0.28 | 1.35% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.7% | $0.08 | 0.39% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.5% | $0.09 | 0.43% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.6% | $0.11 | 0.54% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.5% | $0.11 | 0.55% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.8% | $0.13 | 0.64% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 1.1% | $0.18 | 0.89% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.1% | $0.21 | 1.00% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.6% | $0.28 | 1.35% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.3% | $0.33 | 1.58% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.6% | $0.11 | 0.54% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.1% | $0.21 | 1.00% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.8% | $0.13 | 0.64% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.6% | $0.28 | 1.35% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.7% | $0.08 | 0.39% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.5% | $0.11 | 0.55% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.5% | $0.09 | 0.43% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.3% | $0.33 | 1.58% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 1.1% | $0.18 | 0.89% |

</details>

#### Trap Descriptions

- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **actionlint-fix-cycles**: Workflow YAML required 3+ actionlint runs and 2+ fixes to pass.
- **bats-setup-issues**: Agent struggled with bats-core test framework setup or load helpers.
- **docker-pwsh-install**: Multiple Docker test runs trying to figure out how to install PowerShell in act's container.
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
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.1% | $0.20 | 0.97% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.5% | $0.11 | 0.55% |
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.1% | $0.21 | 1.00% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 2 | 2 | 100% | 2 | 3.2min | 2.3% | $0.36 | 1.74% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.3% | $0.33 | 1.58% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 2.0% | $0.32 | 1.52% |
| **Total** | | **16** | **9** | **56%** | **11** | **11.7min** | **8.2%** | **$1.53** | **7.36%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.5% | $0.11 | 0.55% |
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.1% | $0.20 | 0.97% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.1% | $0.21 | 1.00% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.3% | $0.33 | 1.58% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 2.0% | $0.32 | 1.52% |
| powershell | sonnet | 2 | 2 | 100% | 2 | 3.2min | 2.3% | $0.36 | 1.74% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.5% | $0.11 | 0.55% |
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.1% | $0.20 | 0.97% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.1% | $0.21 | 1.00% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 2.0% | $0.32 | 1.52% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.3% | $0.33 | 1.58% |
| powershell | sonnet | 2 | 2 | 100% | 2 | 3.2min | 2.3% | $0.36 | 1.74% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 2 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | opus | 2 | 1 | 50% | 2 | 1.5min | 1.1% | $0.20 | 0.97% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.5% | $0.11 | 0.55% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.1% | $0.21 | 1.00% |
| powershell | sonnet | 2 | 2 | 100% | 2 | 3.2min | 2.3% | $0.36 | 1.74% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.3% | $0.33 | 1.58% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 2.0% | $0.32 | 1.52% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 14 | $1.65 | 7.97% |
| Miss | 2 | $0.00 | 0.00% |
| **Total** | **16** | **$1.65** | **7.97%** |

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
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 799 | 1 | $1.09 | powershell | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 923 | 6 | $1.73 | bash | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1699 | 1 | $0.89 | typescript | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 923 | 6 | $1.73 | bash | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 799 | 1 | $1.09 | powershell | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1699 | 1 | $0.89 | typescript | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 923 | 6 | $1.73 | bash | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 799 | 1 | $1.09 | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1699 | 1 | $0.89 | typescript | ok |
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
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 799 | 1 | $1.09 | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1699 | 1 | $0.89 | typescript | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 923 | 6 | $1.73 | bash | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 799 | 1 | $1.09 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 923 | 6 | $1.73 | bash | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1699 | 1 | $0.89 | typescript | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 799 | 1 | $1.09 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 839 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 923 | 6 | $1.73 | bash | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1699 | 1 | $0.89 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*