# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 08:13:38 PM ET

**Status:** 33/64 runs completed, 31 remaining
**Total cost so far:** $42.36
**Total agent time so far:** 279.0 min

## Observations

- **Fastest (avg):** default/opus — 6.4min, then bash/opus — 7.1min
- **Slowest (avg):** powershell/sonnet — 10.4min, then bash/sonnet — 10.2min
- **Cheapest (avg):** typescript-bun/sonnet — $1.08, then default/sonnet — $1.20
- **Most expensive (avg):** powershell/opus — $1.40, then typescript-bun/opus — $1.36

- **Estimated time remaining:** 262.1min
- **Estimated total cost:** $82.15

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus | 44 | 2 | 4.5% | 0.4min | 0.1% | 0.6min | 0.2% | -0.2min | -0.1% | 5.8min | -3.1% |
| bash | sonnet | 50 | 7 | 14.0% | 1.4min | 0.5% | 0.7min | 0.2% | 0.7min | 0.3% | 3.4min | 21.6% |
| default | opus | 40 | 3 | 7.5% | 0.4min | 0.1% | 0.4min | 0.1% | 0.0min | 0.0% | 1.6min | 2.7% |
| default | sonnet | 39 | 1 | 2.6% | 0.1min | 0.0% | 0.3min | 0.1% | -0.2min | -0.1% | 2.3min | -9.5% |
| powershell | opus | 40 | 2 | 5.0% | 1.2min | 0.4% | 0.7min | 0.2% | 0.5min | 0.2% | 4.1min | 12.0% |
| powershell | sonnet | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.3% | -0.8min | -0.3% | 7.7min | -10.7% |
| typescript-bun | opus | 30 | 17 | 56.7% | 2.3min | 0.8% | 3.2min | 1.2% | -1.0min | -0.3% | 3.7min | -25.7% |
| typescript-bun | sonnet | 42 | 19 | 45.2% | 2.5min | 0.9% | 4.5min | 1.6% | -2.0min | -0.7% | 0.0min | -4904.6% |
| **Total** | | **334** | **51** | **15.3%** | **8.3min** | **3.0%** | **11.2min** | **4.0%** | **-2.9min** | **-1.0%** | **28.7min** | **-10.0%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | sonnet | 50 | 7 | 14.0% | 1.4min | 0.5% | 0.7min | 0.2% | 0.7min | 0.3% | 3.4min | 21.6% |
| powershell | opus | 40 | 2 | 5.0% | 1.2min | 0.4% | 0.7min | 0.2% | 0.5min | 0.2% | 4.1min | 12.0% |
| default | opus | 40 | 3 | 7.5% | 0.4min | 0.1% | 0.4min | 0.1% | 0.0min | 0.0% | 1.6min | 2.7% |
| bash | opus | 44 | 2 | 4.5% | 0.4min | 0.1% | 0.6min | 0.2% | -0.2min | -0.1% | 5.8min | -3.1% |
| default | sonnet | 39 | 1 | 2.6% | 0.1min | 0.0% | 0.3min | 0.1% | -0.2min | -0.1% | 2.3min | -9.5% |
| powershell | sonnet | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.3% | -0.8min | -0.3% | 7.7min | -10.7% |
| typescript-bun | opus | 30 | 17 | 56.7% | 2.3min | 0.8% | 3.2min | 1.2% | -1.0min | -0.3% | 3.7min | -25.7% |
| typescript-bun | sonnet | 42 | 19 | 45.2% | 2.5min | 0.9% | 4.5min | 1.6% | -2.0min | -0.7% | 0.0min | -4904.6% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | sonnet | 50 | 7 | 14.0% | 1.4min | 0.5% | 0.7min | 0.2% | 0.7min | 0.3% | 3.4min | 21.6% |
| powershell | opus | 40 | 2 | 5.0% | 1.2min | 0.4% | 0.7min | 0.2% | 0.5min | 0.2% | 4.1min | 12.0% |
| default | opus | 40 | 3 | 7.5% | 0.4min | 0.1% | 0.4min | 0.1% | 0.0min | 0.0% | 1.6min | 2.7% |
| bash | opus | 44 | 2 | 4.5% | 0.4min | 0.1% | 0.6min | 0.2% | -0.2min | -0.1% | 5.8min | -3.1% |
| default | sonnet | 39 | 1 | 2.6% | 0.1min | 0.0% | 0.3min | 0.1% | -0.2min | -0.1% | 2.3min | -9.5% |
| powershell | sonnet | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.3% | -0.8min | -0.3% | 7.7min | -10.7% |
| typescript-bun | opus | 30 | 17 | 56.7% | 2.3min | 0.8% | 3.2min | 1.2% | -1.0min | -0.3% | 3.7min | -25.7% |
| typescript-bun | sonnet | 42 | 19 | 45.2% | 2.5min | 0.9% | 4.5min | 1.6% | -2.0min | -0.7% | 0.0min | -4904.6% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus | 30 | 17 | 56.7% | 2.3min | 0.8% | 3.2min | 1.2% | -1.0min | -0.3% | 3.7min | -25.7% |
| typescript-bun | sonnet | 42 | 19 | 45.2% | 2.5min | 0.9% | 4.5min | 1.6% | -2.0min | -0.7% | 0.0min | -4904.6% |
| bash | sonnet | 50 | 7 | 14.0% | 1.4min | 0.5% | 0.7min | 0.2% | 0.7min | 0.3% | 3.4min | 21.6% |
| default | opus | 40 | 3 | 7.5% | 0.4min | 0.1% | 0.4min | 0.1% | 0.0min | 0.0% | 1.6min | 2.7% |
| powershell | opus | 40 | 2 | 5.0% | 1.2min | 0.4% | 0.7min | 0.2% | 0.5min | 0.2% | 4.1min | 12.0% |
| bash | opus | 44 | 2 | 4.5% | 0.4min | 0.1% | 0.6min | 0.2% | -0.2min | -0.1% | 5.8min | -3.1% |
| default | sonnet | 39 | 1 | 2.6% | 0.1min | 0.0% | 0.3min | 0.1% | -0.2min | -0.1% | 2.3min | -9.5% |
| powershell | sonnet | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.3% | -0.8min | -0.3% | 7.7min | -10.7% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.2% | $0.62 | 1.46% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 4 | 3.8min | 1.4% | $0.44 | 1.03% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.26% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.8% | $0.28 | 0.66% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.22% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.4% | $0.13 | 0.31% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.19% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 1.2% | $0.42 | 1.00% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.4% | $0.22 | 0.51% |
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.14% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.6% | $0.27 | 0.65% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.8% | $0.28 | 0.66% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.3% | $0.11 | 0.27% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.3% | $0.09 | 0.21% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.21% |
| **Total** | | | **18 runs** | **23.6min** | **8.5%** | **$3.30** | **7.79%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.14% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.22% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.19% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.21% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.3% | $0.11 | 0.27% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.3% | $0.09 | 0.21% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.26% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.4% | $0.22 | 0.51% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.4% | $0.13 | 0.31% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.6% | $0.27 | 0.65% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.8% | $0.28 | 0.66% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.8% | $0.28 | 0.66% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 1.2% | $0.42 | 1.00% |
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.2% | $0.62 | 1.46% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 4 | 3.8min | 1.4% | $0.44 | 1.03% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.14% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.19% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.21% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.3% | $0.09 | 0.21% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.22% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.26% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.3% | $0.11 | 0.27% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.4% | $0.13 | 0.31% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.4% | $0.22 | 0.51% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.6% | $0.27 | 0.65% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.8% | $0.28 | 0.66% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.8% | $0.28 | 0.66% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 1.2% | $0.42 | 1.00% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 4 | 3.8min | 1.4% | $0.44 | 1.03% |
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.2% | $0.62 | 1.46% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.26% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.22% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.4% | $0.13 | 0.31% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.19% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.4% | $0.22 | 0.51% |
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.14% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.6% | $0.27 | 0.65% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.8% | $0.28 | 0.66% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.3% | $0.11 | 0.27% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.3% | $0.09 | 0.21% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.21% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.8% | $0.28 | 0.66% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 1.2% | $0.42 | 1.00% |
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.2% | $0.62 | 1.46% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 4 | 3.8min | 1.4% | $0.44 | 1.03% |

</details>

#### Trap Descriptions

- **act-permission-path-errors**: Files not found or permission denied inside the act Docker container.
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
| bash | opus | 4 | 2 | 50% | 3 | 2.5min | 0.9% | $0.42 | 0.98% |
| bash | sonnet | 4 | 2 | 50% | 2 | 1.2min | 0.4% | $0.17 | 0.41% |
| default | opus | 5 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 4 | 2 | 50% | 4 | 3.6min | 1.3% | $0.45 | 1.06% |
| powershell | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 4 | 4 | 100% | 5 | 7.3min | 2.6% | $0.98 | 2.31% |
| typescript-bun | opus | 4 | 4 | 100% | 5 | 3.9min | 1.4% | $0.71 | 1.68% |
| typescript-bun | sonnet | 4 | 4 | 100% | 5 | 5.0min | 1.8% | $0.57 | 1.34% |
| **Total** | | **33** | **18** | **55%** | **24** | **23.6min** | **8.5%** | **$3.30** | **7.79%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 5 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 4 | 2 | 50% | 2 | 1.2min | 0.4% | $0.17 | 0.41% |
| bash | opus | 4 | 2 | 50% | 3 | 2.5min | 0.9% | $0.42 | 0.98% |
| default | sonnet | 4 | 2 | 50% | 4 | 3.6min | 1.3% | $0.45 | 1.06% |
| typescript-bun | opus | 4 | 4 | 100% | 5 | 3.9min | 1.4% | $0.71 | 1.68% |
| typescript-bun | sonnet | 4 | 4 | 100% | 5 | 5.0min | 1.8% | $0.57 | 1.34% |
| powershell | sonnet | 4 | 4 | 100% | 5 | 7.3min | 2.6% | $0.98 | 2.31% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 5 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 4 | 2 | 50% | 2 | 1.2min | 0.4% | $0.17 | 0.41% |
| bash | opus | 4 | 2 | 50% | 3 | 2.5min | 0.9% | $0.42 | 0.98% |
| default | sonnet | 4 | 2 | 50% | 4 | 3.6min | 1.3% | $0.45 | 1.06% |
| typescript-bun | sonnet | 4 | 4 | 100% | 5 | 5.0min | 1.8% | $0.57 | 1.34% |
| typescript-bun | opus | 4 | 4 | 100% | 5 | 3.9min | 1.4% | $0.71 | 1.68% |
| powershell | sonnet | 4 | 4 | 100% | 5 | 7.3min | 2.6% | $0.98 | 2.31% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 5 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | opus | 4 | 2 | 50% | 3 | 2.5min | 0.9% | $0.42 | 0.98% |
| bash | sonnet | 4 | 2 | 50% | 2 | 1.2min | 0.4% | $0.17 | 0.41% |
| default | sonnet | 4 | 2 | 50% | 4 | 3.6min | 1.3% | $0.45 | 1.06% |
| powershell | sonnet | 4 | 4 | 100% | 5 | 7.3min | 2.6% | $0.98 | 2.31% |
| typescript-bun | opus | 4 | 4 | 100% | 5 | 3.9min | 1.4% | $0.71 | 1.68% |
| typescript-bun | sonnet | 4 | 4 | 100% | 5 | 5.0min | 1.8% | $0.57 | 1.34% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 31 | $3.74 | 8.83% |
| Miss | 2 | $0.00 | 0.00% |
| **Total** | **33** | **$3.74** | **8.83%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| Docker Image Tag Generator | powershell | opus | 7.9min | 24 | 0 | $1.39 | powershell | ok |
| Docker Image Tag Generator | bash | opus | 3.7min | 28 | 1 | $0.78 | bash | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| Docker Image Tag Generator | bash | opus | 3.7min | 28 | 1 | $0.78 | bash | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Docker Image Tag Generator | powershell | opus | 7.9min | 24 | 0 | $1.39 | powershell | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Docker Image Tag Generator | bash | opus | 3.7min | 28 | 1 | $0.78 | bash | ok |
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| Docker Image Tag Generator | powershell | opus | 7.9min | 24 | 0 | $1.39 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Docker Image Tag Generator | powershell | opus | 7.9min | 24 | 0 | $1.39 | powershell | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| Docker Image Tag Generator | bash | opus | 3.7min | 28 | 1 | $0.78 | bash | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Docker Image Tag Generator | powershell | opus | 7.9min | 24 | 0 | $1.39 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Docker Image Tag Generator | bash | opus | 3.7min | 28 | 1 | $0.78 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*