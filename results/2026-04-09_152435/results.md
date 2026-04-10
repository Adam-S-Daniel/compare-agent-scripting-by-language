# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 10:36:05 PM ET

**Status:** 36/64 runs completed, 28 remaining
**Total cost so far:** $48.27
**Total agent time so far:** 307.0 min

## Observations

- **Fastest (avg):** default/opus — 6.4min, then typescript-bun/opus — 6.6min
- **Slowest (avg):** powershell/sonnet — 10.4min, then bash/sonnet — 10.2min
- **Cheapest (avg):** typescript-bun/sonnet — $1.08, then default/sonnet — $1.20
- **Most expensive (avg):** powershell/opus — $1.61, then bash/opus — $1.59

- **Estimated time remaining:** 238.8min
- **Estimated total cost:** $85.82

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus | 5 | 8.9min | 8.2min | 1.8 | 43 | $1.59 | $7.94 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| powershell | opus | 5 | 8.4min | 8.1min | 1.4 | 34 | $1.61 | $8.05 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |
| typescript-bun | opus | 5 | 6.6min | 5.8min | 1.6 | 36 | $1.21 | $6.04 |
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| typescript-bun | opus | 5 | 6.6min | 5.8min | 1.6 | 36 | $1.21 | $6.04 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |
| bash | opus | 5 | 8.9min | 8.2min | 1.8 | 43 | $1.59 | $7.94 |
| powershell | opus | 5 | 8.4min | 8.1min | 1.4 | 34 | $1.61 | $8.05 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| typescript-bun | opus | 5 | 6.6min | 5.8min | 1.6 | 36 | $1.21 | $6.04 |
| powershell | opus | 5 | 8.4min | 8.1min | 1.4 | 34 | $1.61 | $8.05 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| bash | opus | 5 | 8.9min | 8.2min | 1.8 | 43 | $1.59 | $7.94 |
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | opus | 5 | 6.6min | 5.8min | 1.6 | 36 | $1.21 | $6.04 |
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| powershell | opus | 5 | 8.4min | 8.1min | 1.4 | 34 | $1.61 | $8.05 |
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |
| bash | opus | 5 | 8.9min | 8.2min | 1.8 | 43 | $1.59 | $7.94 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus | 5 | 8.4min | 8.1min | 1.4 | 34 | $1.61 | $8.05 |
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| typescript-bun | opus | 5 | 6.6min | 5.8min | 1.6 | 36 | $1.21 | $6.04 |
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |
| bash | opus | 5 | 8.9min | 8.2min | 1.8 | 43 | $1.59 | $7.94 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 5 | 6.4min | 6.4min | 1.6 | 32 | $1.33 | $6.66 |
| powershell | opus | 5 | 8.4min | 8.1min | 1.4 | 34 | $1.61 | $8.05 |
| typescript-bun | sonnet | 4 | 9.4min | 8.1min | 1.8 | 35 | $1.08 | $4.31 |
| typescript-bun | opus | 5 | 6.6min | 5.8min | 1.6 | 36 | $1.21 | $6.04 |
| default | sonnet | 4 | 8.8min | 7.9min | 2.2 | 41 | $1.20 | $4.82 |
| bash | sonnet | 4 | 10.2min | 9.9min | 4.2 | 41 | $1.35 | $5.39 |
| powershell | sonnet | 4 | 10.4min | 8.6min | 2.0 | 41 | $1.27 | $5.07 |
| bash | opus | 5 | 8.9min | 8.2min | 1.8 | 43 | $1.59 | $7.94 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus | 55 | 2 | 3.6% | 0.4min | 0.1% | 0.8min | 0.3% | -0.4min | -0.1% | 6.0min | -6.3% |
| bash | sonnet | 50 | 7 | 14.0% | 1.4min | 0.5% | 0.7min | 0.2% | 0.7min | 0.2% | 5.0min | 14.0% |
| default | opus | 40 | 3 | 7.5% | 0.4min | 0.1% | 0.4min | 0.1% | 0.0min | 0.0% | 1.6min | 2.7% |
| default | sonnet | 39 | 1 | 2.6% | 0.1min | 0.0% | 0.3min | 0.1% | -0.2min | -0.1% | 2.3min | -9.5% |
| powershell | opus | 56 | 2 | 3.6% | 1.2min | 0.4% | 0.9min | 0.3% | 0.2min | 0.1% | 4.7min | 4.7% |
| powershell | sonnet | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.3% | -0.8min | -0.3% | 7.7min | -10.7% |
| typescript-bun | opus | 31 | 17 | 54.8% | 2.3min | 0.7% | 3.3min | 1.1% | -1.1min | -0.3% | 4.1min | -26.2% |
| typescript-bun | sonnet | 42 | 19 | 45.2% | 2.5min | 0.8% | 4.5min | 1.5% | -2.0min | -0.6% | 2.7min | -72.7% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | sonnet | 50 | 7 | 14.0% | 1.4min | 0.5% | 0.7min | 0.2% | 0.7min | 0.2% | 5.0min | 14.0% |
| powershell | opus | 56 | 2 | 3.6% | 1.2min | 0.4% | 0.9min | 0.3% | 0.2min | 0.1% | 4.7min | 4.7% |
| default | opus | 40 | 3 | 7.5% | 0.4min | 0.1% | 0.4min | 0.1% | 0.0min | 0.0% | 1.6min | 2.7% |
| default | sonnet | 39 | 1 | 2.6% | 0.1min | 0.0% | 0.3min | 0.1% | -0.2min | -0.1% | 2.3min | -9.5% |
| bash | opus | 55 | 2 | 3.6% | 0.4min | 0.1% | 0.8min | 0.3% | -0.4min | -0.1% | 6.0min | -6.3% |
| powershell | sonnet | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.3% | -0.8min | -0.3% | 7.7min | -10.7% |
| typescript-bun | opus | 31 | 17 | 54.8% | 2.3min | 0.7% | 3.3min | 1.1% | -1.1min | -0.3% | 4.1min | -26.2% |
| typescript-bun | sonnet | 42 | 19 | 45.2% | 2.5min | 0.8% | 4.5min | 1.5% | -2.0min | -0.6% | 2.7min | -72.7% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | sonnet | 50 | 7 | 14.0% | 1.4min | 0.5% | 0.7min | 0.2% | 0.7min | 0.2% | 5.0min | 14.0% |
| powershell | opus | 56 | 2 | 3.6% | 1.2min | 0.4% | 0.9min | 0.3% | 0.2min | 0.1% | 4.7min | 4.7% |
| default | opus | 40 | 3 | 7.5% | 0.4min | 0.1% | 0.4min | 0.1% | 0.0min | 0.0% | 1.6min | 2.7% |
| bash | opus | 55 | 2 | 3.6% | 0.4min | 0.1% | 0.8min | 0.3% | -0.4min | -0.1% | 6.0min | -6.3% |
| default | sonnet | 39 | 1 | 2.6% | 0.1min | 0.0% | 0.3min | 0.1% | -0.2min | -0.1% | 2.3min | -9.5% |
| powershell | sonnet | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.3% | -0.8min | -0.3% | 7.7min | -10.7% |
| typescript-bun | opus | 31 | 17 | 54.8% | 2.3min | 0.7% | 3.3min | 1.1% | -1.1min | -0.3% | 4.1min | -26.2% |
| typescript-bun | sonnet | 42 | 19 | 45.2% | 2.5min | 0.8% | 4.5min | 1.5% | -2.0min | -0.6% | 2.7min | -72.7% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus | 31 | 17 | 54.8% | 2.3min | 0.7% | 3.3min | 1.1% | -1.1min | -0.3% | 4.1min | -26.2% |
| typescript-bun | sonnet | 42 | 19 | 45.2% | 2.5min | 0.8% | 4.5min | 1.5% | -2.0min | -0.6% | 2.7min | -72.7% |
| bash | sonnet | 50 | 7 | 14.0% | 1.4min | 0.5% | 0.7min | 0.2% | 0.7min | 0.2% | 5.0min | 14.0% |
| default | opus | 40 | 3 | 7.5% | 0.4min | 0.1% | 0.4min | 0.1% | 0.0min | 0.0% | 1.6min | 2.7% |
| bash | opus | 55 | 2 | 3.6% | 0.4min | 0.1% | 0.8min | 0.3% | -0.4min | -0.1% | 6.0min | -6.3% |
| powershell | opus | 56 | 2 | 3.6% | 1.2min | 0.4% | 0.9min | 0.3% | 0.2min | 0.1% | 4.7min | 4.7% |
| default | sonnet | 39 | 1 | 2.6% | 0.1min | 0.0% | 0.3min | 0.1% | -0.2min | -0.1% | 2.3min | -9.5% |
| powershell | sonnet | 49 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.3% | -0.8min | -0.3% | 7.7min | -10.7% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.1% | $0.62 | 1.28% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 4 | 3.8min | 1.2% | $0.44 | 0.91% |
| fixture-rework | bash | opus | 2 | 1.8min | 0.6% | $0.35 | 0.73% |
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.12% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.5% | $0.37 | 0.76% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.6% | $0.27 | 0.57% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.23% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.7% | $0.28 | 0.58% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.19% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.4% | $0.13 | 0.27% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.17% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 1.1% | $0.42 | 0.88% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.7% | $0.28 | 0.58% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.2% | $0.11 | 0.24% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.19% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.18% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.12% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.19% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.17% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.18% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.2% | $0.11 | 0.24% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.19% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.23% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.4% | $0.13 | 0.27% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.5% | $0.37 | 0.76% |
| fixture-rework | bash | opus | 2 | 1.8min | 0.6% | $0.35 | 0.73% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.6% | $0.27 | 0.57% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.7% | $0.28 | 0.58% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.7% | $0.28 | 0.58% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 1.1% | $0.42 | 0.88% |
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.1% | $0.62 | 1.28% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 4 | 3.8min | 1.2% | $0.44 | 0.91% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.12% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.17% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.18% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.19% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.19% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.23% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.2% | $0.11 | 0.24% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.4% | $0.13 | 0.27% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.6% | $0.27 | 0.57% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.7% | $0.28 | 0.58% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.7% | $0.28 | 0.58% |
| fixture-rework | bash | opus | 2 | 1.8min | 0.6% | $0.35 | 0.73% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.5% | $0.37 | 0.76% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 1.1% | $0.42 | 0.88% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 4 | 3.8min | 1.2% | $0.44 | 0.91% |
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.1% | $0.62 | 1.28% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.12% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.5% | $0.37 | 0.76% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.6% | $0.27 | 0.57% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.23% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.19% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.4% | $0.13 | 0.27% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.17% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.7% | $0.28 | 0.58% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.2% | $0.11 | 0.24% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.19% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.18% |
| fixture-rework | bash | opus | 2 | 1.8min | 0.6% | $0.35 | 0.73% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.7% | $0.28 | 0.58% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 1.1% | $0.42 | 0.88% |
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.1% | $0.62 | 1.28% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 4 | 3.8min | 1.2% | $0.44 | 0.91% |

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
| bash | opus | 5 | 3 | 60% | 4 | 3.2min | 1.1% | $0.55 | 1.14% |
| bash | sonnet | 4 | 2 | 50% | 2 | 1.2min | 0.4% | $0.17 | 0.36% |
| default | opus | 5 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 4 | 2 | 50% | 4 | 3.6min | 1.2% | $0.45 | 0.93% |
| powershell | opus | 5 | 1 | 20% | 1 | 1.5min | 0.5% | $0.37 | 0.76% |
| powershell | sonnet | 4 | 4 | 100% | 5 | 7.3min | 2.4% | $0.98 | 2.03% |
| typescript-bun | opus | 5 | 4 | 80% | 5 | 3.9min | 1.3% | $0.71 | 1.47% |
| typescript-bun | sonnet | 4 | 4 | 100% | 5 | 5.0min | 1.6% | $0.57 | 1.18% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 5 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 4 | 2 | 50% | 2 | 1.2min | 0.4% | $0.17 | 0.36% |
| powershell | opus | 5 | 1 | 20% | 1 | 1.5min | 0.5% | $0.37 | 0.76% |
| bash | opus | 5 | 3 | 60% | 4 | 3.2min | 1.1% | $0.55 | 1.14% |
| default | sonnet | 4 | 2 | 50% | 4 | 3.6min | 1.2% | $0.45 | 0.93% |
| typescript-bun | opus | 5 | 4 | 80% | 5 | 3.9min | 1.3% | $0.71 | 1.47% |
| typescript-bun | sonnet | 4 | 4 | 100% | 5 | 5.0min | 1.6% | $0.57 | 1.18% |
| powershell | sonnet | 4 | 4 | 100% | 5 | 7.3min | 2.4% | $0.98 | 2.03% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 5 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 4 | 2 | 50% | 2 | 1.2min | 0.4% | $0.17 | 0.36% |
| powershell | opus | 5 | 1 | 20% | 1 | 1.5min | 0.5% | $0.37 | 0.76% |
| default | sonnet | 4 | 2 | 50% | 4 | 3.6min | 1.2% | $0.45 | 0.93% |
| bash | opus | 5 | 3 | 60% | 4 | 3.2min | 1.1% | $0.55 | 1.14% |
| typescript-bun | sonnet | 4 | 4 | 100% | 5 | 5.0min | 1.6% | $0.57 | 1.18% |
| typescript-bun | opus | 5 | 4 | 80% | 5 | 3.9min | 1.3% | $0.71 | 1.47% |
| powershell | sonnet | 4 | 4 | 100% | 5 | 7.3min | 2.4% | $0.98 | 2.03% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 5 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 5 | 1 | 20% | 1 | 1.5min | 0.5% | $0.37 | 0.76% |
| bash | sonnet | 4 | 2 | 50% | 2 | 1.2min | 0.4% | $0.17 | 0.36% |
| default | sonnet | 4 | 2 | 50% | 4 | 3.6min | 1.2% | $0.45 | 0.93% |
| bash | opus | 5 | 3 | 60% | 4 | 3.2min | 1.1% | $0.55 | 1.14% |
| typescript-bun | opus | 5 | 4 | 80% | 5 | 3.9min | 1.3% | $0.71 | 1.47% |
| powershell | sonnet | 4 | 4 | 100% | 5 | 7.3min | 2.4% | $0.98 | 2.03% |
| typescript-bun | sonnet | 4 | 4 | 100% | 5 | 5.0min | 1.6% | $0.57 | 1.18% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 34 | $4.33 | 8.97% |
| Miss | 2 | $0.00 | 0.00% |

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
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Docker Image Tag Generator | bash | opus | 3.7min | 28 | 1 | $0.78 | bash | ok |
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| Docker Image Tag Generator | powershell | opus | 7.9min | 24 | 0 | $1.39 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Test Results Aggregator | bash | opus | 15.8min | 42 | 2 | $2.85 | bash | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| Test Results Aggregator | powershell | opus | 10.0min | 48 | 2 | $2.45 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus | 2.3min | 29 | 1 | $0.61 | typescript | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| Test Results Aggregator | typescript-bun | opus | 2.3min | 29 | 1 | $0.61 | typescript | ok |
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
| Test Results Aggregator | powershell | opus | 10.0min | 48 | 2 | $2.45 | powershell | ok |
| Test Results Aggregator | bash | opus | 15.8min | 42 | 2 | $2.85 | bash | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Test Results Aggregator | typescript-bun | opus | 2.3min | 29 | 1 | $0.61 | typescript | ok |
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
| Test Results Aggregator | powershell | opus | 10.0min | 48 | 2 | $2.45 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |
| Test Results Aggregator | bash | opus | 15.8min | 42 | 2 | $2.85 | bash | ok |

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
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| Test Results Aggregator | typescript-bun | opus | 2.3min | 29 | 1 | $0.61 | typescript | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| Test Results Aggregator | bash | opus | 15.8min | 42 | 2 | $2.85 | bash | ok |
| Test Results Aggregator | powershell | opus | 10.0min | 48 | 2 | $2.45 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
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
| Test Results Aggregator | typescript-bun | opus | 2.3min | 29 | 1 | $0.61 | typescript | ok |
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
| Test Results Aggregator | bash | opus | 15.8min | 42 | 2 | $2.85 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Test Results Aggregator | powershell | opus | 10.0min | 48 | 2 | $2.45 | powershell | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*