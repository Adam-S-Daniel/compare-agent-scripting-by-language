# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 06:09:17 PM ET

**Status:** 19/64 runs completed, 45 remaining
**Total cost so far:** $24.70
**Total agent time so far:** 161.6 min

## Observations

- **Fastest (avg):** default/opus — 6.9min, then typescript-bun/opus — 7.7min
- **Fastest net of traps:** typescript-bun/sonnet — 6.7min, then typescript-bun/opus — 6.8min
- **Slowest (avg):** bash/sonnet — 11.1min, then powershell/sonnet — 10.1min
- **Slowest net of traps:** bash/sonnet — 10.7min, then powershell/sonnet — 8.5min
- **Cheapest (avg):** typescript-bun/sonnet — $0.93, then powershell/sonnet — $1.01
- **Cheapest net of traps:** typescript-bun/sonnet — $0.77, then powershell/sonnet — $0.83
- **Most expensive (avg):** bash/sonnet — $1.55, then bash/opus — $1.44
- **Most expensive net of traps:** bash/sonnet — $1.50, then powershell/opus — $1.40

- **Estimated time remaining:** 382.8min
- **Estimated total cost:** $83.20

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | opus | 3 | 8.3min | 7.5min | 1012 | 2.0 | 49 | $1.44 | $1.30 | $4.31 |
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |
| default | opus | 3 | 6.9min | 6.9min | 952 | 1.0 | 32 | $1.38 | $1.38 | $4.14 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| powershell | opus | 3 | 8.1min | 8.1min | 852 | 1.7 | 33 | $1.40 | $1.40 | $4.21 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |
| bash | opus | 3 | 8.3min | 7.5min | 1012 | 2.0 | 49 | $1.44 | $1.30 | $4.31 |
| powershell | opus | 3 | 8.1min | 8.1min | 852 | 1.7 | 33 | $1.40 | $1.40 | $4.21 |
| default | opus | 3 | 6.9min | 6.9min | 952 | 1.0 | 32 | $1.38 | $1.38 | $4.14 |
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
| powershell | opus | 3 | 8.1min | 8.1min | 852 | 1.7 | 33 | $1.40 | $1.40 | $4.21 |
| default | opus | 3 | 6.9min | 6.9min | 952 | 1.0 | 32 | $1.38 | $1.38 | $4.14 |
| bash | opus | 3 | 8.3min | 7.5min | 1012 | 2.0 | 49 | $1.44 | $1.30 | $4.31 |
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
| default | opus | 3 | 6.9min | 6.9min | 952 | 1.0 | 32 | $1.38 | $1.38 | $4.14 |
| bash | opus | 3 | 8.3min | 7.5min | 1012 | 2.0 | 49 | $1.44 | $1.30 | $4.31 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| powershell | opus | 3 | 8.1min | 8.1min | 852 | 1.7 | 33 | $1.40 | $1.40 | $4.21 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | opus | 3 | 6.9min | 6.9min | 952 | 1.0 | 32 | $1.38 | $1.38 | $4.14 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| powershell | opus | 3 | 8.1min | 8.1min | 852 | 1.7 | 33 | $1.40 | $1.40 | $4.21 |
| bash | opus | 3 | 8.3min | 7.5min | 1012 | 2.0 | 49 | $1.44 | $1.30 | $4.31 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| powershell | opus | 3 | 8.1min | 8.1min | 852 | 1.7 | 33 | $1.40 | $1.40 | $4.21 |
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |
| default | opus | 3 | 6.9min | 6.9min | 952 | 1.0 | 32 | $1.38 | $1.38 | $4.14 |
| bash | opus | 3 | 8.3min | 7.5min | 1012 | 2.0 | 49 | $1.44 | $1.30 | $4.31 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Avg Cost Net | Total Cost |
|------|-------|------|-------------|-----------------|-----------|------------|-----------|----------|-------------|------------|
| default | opus | 3 | 6.9min | 6.9min | 952 | 1.0 | 32 | $1.38 | $1.38 | $4.14 |
| typescript-bun | opus | 2 | 7.7min | 6.8min | 1072 | 1.5 | 32 | $1.28 | $1.11 | $2.55 |
| powershell | opus | 3 | 8.1min | 8.1min | 852 | 1.7 | 33 | $1.40 | $1.40 | $4.21 |
| powershell | sonnet | 2 | 10.1min | 8.5min | 1027 | 2.0 | 36 | $1.01 | $0.83 | $2.01 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1366 | 1.0 | 36 | $0.93 | $0.77 | $1.86 |
| default | sonnet | 2 | 8.8min | 8.1min | 1074 | 2.5 | 44 | $1.26 | $1.15 | $2.51 |
| bash | sonnet | 2 | 11.1min | 10.7min | 906 | 6.0 | 48 | $1.55 | $1.50 | $3.11 |
| bash | opus | 3 | 8.3min | 7.5min | 1012 | 2.0 | 49 | $1.44 | $1.30 | $4.31 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 39 | 2 | 5.1% | 0.4min | 0.2% | 0.7min | 0.5% | -0.3min | -0.2% | 5.6min | -6.1% |
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.6% | 0.5min | 0.3% | 0.5min | 0.3% | 1.5min | 30.9% |
| default | opus | 25 | 2 | 8.0% | 0.3min | 0.2% | 0.3min | 0.2% | -0.0min | -0.0% | 0.8min | -1.7% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.1% | -0.1min | -0.1% | 0.6min | -17.8% |
| powershell | opus | 33 | 2 | 6.1% | 1.2min | 0.7% | 0.6min | 0.4% | 0.6min | 0.4% | 3.5min | 16.4% |
| powershell | sonnet | 20 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.2% | -0.4min | -0.2% | 5.5min | -6.5% |
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 0.7% | 3.0min | 1.9% | -1.8min | -1.1% | 2.5min | -71.7% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.7% | 3.2min | 2.0% | -2.1min | -1.3% | 0.0min | -7355.4% |
| **Total** | | **205** | **29** | **14.1%** | **5.2min** | **3.2%** | **8.9min** | **5.5%** | **-3.7min** | **-2.3%** | **20.1min** | **-18.2%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | opus | 33 | 2 | 6.1% | 1.2min | 0.7% | 0.6min | 0.4% | 0.6min | 0.4% | 3.5min | 16.4% |
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.6% | 0.5min | 0.3% | 0.5min | 0.3% | 1.5min | 30.9% |
| default | opus | 25 | 2 | 8.0% | 0.3min | 0.2% | 0.3min | 0.2% | -0.0min | -0.0% | 0.8min | -1.7% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.1% | -0.1min | -0.1% | 0.6min | -17.8% |
| bash | opus | 39 | 2 | 5.1% | 0.4min | 0.2% | 0.7min | 0.5% | -0.3min | -0.2% | 5.6min | -6.1% |
| powershell | sonnet | 20 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.2% | -0.4min | -0.2% | 5.5min | -6.5% |
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 0.7% | 3.0min | 1.9% | -1.8min | -1.1% | 2.5min | -71.7% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.7% | 3.2min | 2.0% | -2.1min | -1.3% | 0.0min | -7355.4% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.6% | 0.5min | 0.3% | 0.5min | 0.3% | 1.5min | 30.9% |
| powershell | opus | 33 | 2 | 6.1% | 1.2min | 0.7% | 0.6min | 0.4% | 0.6min | 0.4% | 3.5min | 16.4% |
| default | opus | 25 | 2 | 8.0% | 0.3min | 0.2% | 0.3min | 0.2% | -0.0min | -0.0% | 0.8min | -1.7% |
| bash | opus | 39 | 2 | 5.1% | 0.4min | 0.2% | 0.7min | 0.5% | -0.3min | -0.2% | 5.6min | -6.1% |
| powershell | sonnet | 20 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.2% | -0.4min | -0.2% | 5.5min | -6.5% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.1% | -0.1min | -0.1% | 0.6min | -17.8% |
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 0.7% | 3.0min | 1.9% | -1.8min | -1.1% | 2.5min | -71.7% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.7% | 3.2min | 2.0% | -2.1min | -1.3% | 0.0min | -7355.4% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 19 | 9 | 47.4% | 1.2min | 0.7% | 3.0min | 1.9% | -1.8min | -1.1% | 2.5min | -71.7% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.7% | 3.2min | 2.0% | -2.1min | -1.3% | 0.0min | -7355.4% |
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.6% | 0.5min | 0.3% | 0.5min | 0.3% | 1.5min | 30.9% |
| default | opus | 25 | 2 | 8.0% | 0.3min | 0.2% | 0.3min | 0.2% | -0.0min | -0.0% | 0.8min | -1.7% |
| powershell | opus | 33 | 2 | 6.1% | 1.2min | 0.7% | 0.6min | 0.4% | 0.6min | 0.4% | 3.5min | 16.4% |
| bash | opus | 39 | 2 | 5.1% | 0.4min | 0.2% | 0.7min | 0.5% | -0.3min | -0.2% | 5.6min | -6.1% |
| default | sonnet | 21 | 1 | 4.8% | 0.1min | 0.1% | 0.2min | 0.1% | -0.1min | -0.1% | 0.6min | -17.8% |
| powershell | sonnet | 20 | 0 | 0.0% | 0.0min | 0.0% | 0.4min | 0.2% | -0.4min | -0.2% | 5.5min | -6.5% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.5% | $0.11 | 0.45% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.0% | $0.21 | 0.84% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.7% | $0.13 | 0.53% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.1% | $0.33 | 1.32% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 1.0% | $0.18 | 0.74% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.4% | $0.28 | 1.13% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.6% | $0.08 | 0.33% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.6% | $0.22 | 0.87% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.5% | $0.11 | 0.47% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.4% | $0.09 | 0.36% |
| **Total** | | | **10 runs** | **12.7min** | **7.8%** | **$1.74** | **7.05%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.4% | $0.09 | 0.36% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.5% | $0.11 | 0.47% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.5% | $0.11 | 0.45% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.6% | $0.08 | 0.33% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.6% | $0.22 | 0.87% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.7% | $0.13 | 0.53% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.0% | $0.21 | 0.84% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 1.0% | $0.18 | 0.74% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.1% | $0.33 | 1.32% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.4% | $0.28 | 1.13% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.6% | $0.08 | 0.33% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.4% | $0.09 | 0.36% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.5% | $0.11 | 0.45% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.5% | $0.11 | 0.47% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.7% | $0.13 | 0.53% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 1.0% | $0.18 | 0.74% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.0% | $0.21 | 0.84% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.6% | $0.22 | 0.87% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.4% | $0.28 | 1.13% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.1% | $0.33 | 1.32% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.5% | $0.11 | 0.45% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 1.0% | $0.21 | 0.84% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.7% | $0.13 | 0.53% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.4% | $0.28 | 1.13% |
| repeated-test-reruns | powershell | sonnet | 1 | 1.0min | 0.6% | $0.08 | 0.33% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.6% | $0.22 | 0.87% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.5% | $0.11 | 0.47% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.4% | $0.09 | 0.36% |
| ts-type-error-fix-cycles | typescript-bun | opus | 2 | 1.8min | 1.1% | $0.33 | 1.32% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 1.0% | $0.18 | 0.74% |

</details>

#### Trap Descriptions

- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **actionlint-fix-cycles**: Workflow YAML required 3+ actionlint runs and 2+ fixes to pass.
- **bats-setup-issues**: Agent struggled with bats-core test framework setup or load helpers.
- **docker-pwsh-install**: Multiple Docker test runs trying to figure out how to install PowerShell in act's container.
- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
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
| bash | opus | 3 | 2 | 67% | 3 | 2.5min | 1.5% | $0.42 | 1.69% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.5% | $0.11 | 0.47% |
| default | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.0% | $0.21 | 0.84% |
| powershell | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 2 | 2 | 100% | 2 | 3.2min | 2.0% | $0.36 | 1.46% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.1% | $0.33 | 1.32% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 1.7% | $0.32 | 1.28% |
| **Total** | | **19** | **10** | **53%** | **12** | **12.7min** | **7.8%** | **$1.74** | **7.05%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.5% | $0.11 | 0.47% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.0% | $0.21 | 0.84% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.1% | $0.33 | 1.32% |
| bash | opus | 3 | 2 | 67% | 3 | 2.5min | 1.5% | $0.42 | 1.69% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 1.7% | $0.32 | 1.28% |
| powershell | sonnet | 2 | 2 | 100% | 2 | 3.2min | 2.0% | $0.36 | 1.46% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.5% | $0.11 | 0.47% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.0% | $0.21 | 0.84% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 1.7% | $0.32 | 1.28% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.1% | $0.33 | 1.32% |
| powershell | sonnet | 2 | 2 | 100% | 2 | 3.2min | 2.0% | $0.36 | 1.46% |
| bash | opus | 3 | 2 | 67% | 3 | 2.5min | 1.5% | $0.42 | 1.69% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.5% | $0.11 | 0.47% |
| default | sonnet | 2 | 1 | 50% | 1 | 1.5min | 1.0% | $0.21 | 0.84% |
| bash | opus | 3 | 2 | 67% | 3 | 2.5min | 1.5% | $0.42 | 1.69% |
| powershell | sonnet | 2 | 2 | 100% | 2 | 3.2min | 2.0% | $0.36 | 1.46% |
| typescript-bun | opus | 2 | 2 | 100% | 2 | 1.8min | 1.1% | $0.33 | 1.32% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 1.7% | $0.32 | 1.28% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 17 | $2.24 | 9.08% |
| Miss | 2 | $0.00 | 0.00% |
| **Total** | **19** | **$2.24** | **9.08%** |

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
| Dependency License Checker | default | opus | 5.9min | 39 | 1054 | 0 | $1.24 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 1100 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 839 | 3 | $1.50 | bash | ok |


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
| Dependency License Checker | bash | opus | 6.9min | 55 | 839 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 1054 | 0 | $1.24 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 1100 | 3 | $1.24 | powershell | ok |
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
| Dependency License Checker | bash | opus | 6.9min | 55 | 839 | 3 | $1.50 | bash | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 1100 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 1054 | 0 | $1.24 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 618 | 0 | $1.04 | powershell | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 1054 | 0 | $1.24 | python | ok |
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
| Dependency License Checker | powershell | opus | 6.0min | 38 | 1100 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 839 | 3 | $1.50 | bash | ok |
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
| Dependency License Checker | bash | opus | 6.9min | 55 | 839 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 878 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 923 | 2 | $1.57 | python | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 923 | 6 | $1.73 | bash | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1034 | 1 | $0.97 | typescript | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 1054 | 0 | $1.24 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1071 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 1073 | 2 | $1.01 | typescript | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 1100 | 3 | $1.24 | powershell | ok |
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
| Dependency License Checker | powershell | opus | 6.0min | 38 | 1100 | 3 | $1.24 | powershell | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 923 | 6 | $1.73 | bash | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 1054 | 0 | $1.24 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 486 | 2 | $1.16 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 1255 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 836 | 4 | $1.52 | python | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1699 | 1 | $0.89 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1311 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1710 | 1 | $1.65 | bash | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 839 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 889 | 6 | $1.38 | bash | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*