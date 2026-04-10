# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 11:54:28 PM ET

**Status:** 45/64 runs completed, 19 remaining
**Total cost so far:** $59.06
**Total agent time so far:** 378.3 min

## Observations

- **Fastest (avg):** default/opus — 6.4min, then typescript-bun/opus — 6.5min
- **Slowest (avg):** powershell/sonnet — 10.7min, then bash/sonnet — 10.0min
- **Cheapest (avg):** typescript-bun/sonnet — $1.14, then default/sonnet — $1.18
- **Most expensive (avg):** powershell/opus — $1.55, then bash/opus — $1.49

- **Estimated time remaining:** 159.7min
- **Estimated total cost:** $84.00

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |
| bash | sonnet | 5 | 10.0min | 9.5min | 4.0 | 39 | $1.32 | $6.61 |
| default | opus | 6 | 6.4min | 6.4min | 1.5 | 31 | $1.31 | $7.87 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |
| powershell | sonnet | 5 | 10.7min | 9.1min | 1.8 | 39 | $1.29 | $6.43 |
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| typescript-bun | sonnet | 5 | 9.7min | 8.3min | 1.6 | 35 | $1.14 | $5.72 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | sonnet | 5 | 9.7min | 8.3min | 1.6 | 35 | $1.14 | $5.72 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| powershell | sonnet | 5 | 10.7min | 9.1min | 1.8 | 39 | $1.29 | $6.43 |
| default | opus | 6 | 6.4min | 6.4min | 1.5 | 31 | $1.31 | $7.87 |
| bash | sonnet | 5 | 10.0min | 9.5min | 4.0 | 39 | $1.32 | $6.61 |
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 6 | 6.4min | 6.4min | 1.5 | 31 | $1.31 | $7.87 |
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| typescript-bun | sonnet | 5 | 9.7min | 8.3min | 1.6 | 35 | $1.14 | $5.72 |
| bash | sonnet | 5 | 10.0min | 9.5min | 4.0 | 39 | $1.32 | $6.61 |
| powershell | sonnet | 5 | 10.7min | 9.1min | 1.8 | 39 | $1.29 | $6.43 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| default | opus | 6 | 6.4min | 6.4min | 1.5 | 31 | $1.31 | $7.87 |
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| typescript-bun | sonnet | 5 | 9.7min | 8.3min | 1.6 | 35 | $1.14 | $5.72 |
| powershell | sonnet | 5 | 10.7min | 9.1min | 1.8 | 39 | $1.29 | $6.43 |
| bash | sonnet | 5 | 10.0min | 9.5min | 4.0 | 39 | $1.32 | $6.61 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 6 | 6.4min | 6.4min | 1.5 | 31 | $1.31 | $7.87 |
| typescript-bun | sonnet | 5 | 9.7min | 8.3min | 1.6 | 35 | $1.14 | $5.72 |
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |
| powershell | sonnet | 5 | 10.7min | 9.1min | 1.8 | 39 | $1.29 | $6.43 |
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| bash | sonnet | 5 | 10.0min | 9.5min | 4.0 | 39 | $1.32 | $6.61 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 6 | 6.4min | 6.4min | 1.5 | 31 | $1.31 | $7.87 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |
| typescript-bun | sonnet | 5 | 9.7min | 8.3min | 1.6 | 35 | $1.14 | $5.72 |
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| powershell | sonnet | 5 | 10.7min | 9.1min | 1.8 | 39 | $1.29 | $6.43 |
| bash | sonnet | 5 | 10.0min | 9.5min | 4.0 | 39 | $1.32 | $6.61 |
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus | 65 | 2 | 3.1% | 0.4min | 0.1% | 0.5min | 0.1% | -0.1min | -0.0% | 6.4min | -1.5% |
| bash | sonnet | 60 | 7 | 11.7% | 1.4min | 0.4% | 0.2min | 0.0% | 1.2min | 0.3% | 5.5min | 22.7% |
| default | opus | 50 | 3 | 6.0% | 0.4min | 0.1% | 0.2min | 0.1% | 0.2min | 0.1% | 1.7min | 11.9% |
| default | sonnet | 60 | 1 | 1.7% | 0.1min | 0.0% | 0.2min | 0.0% | -0.0min | -0.0% | 3.0min | -1.6% |
| powershell | opus | 68 | 8 | 11.8% | 4.7min | 1.2% | 0.5min | 0.1% | 4.1min | 1.1% | 5.2min | 79.3% |
| powershell | sonnet | 56 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 7.9min | -7.6% |
| typescript-bun | opus | 42 | 23 | 54.8% | 3.1min | 0.8% | 3.4min | 0.9% | -0.3min | -0.1% | 4.3min | -7.0% |
| typescript-bun | sonnet | 58 | 29 | 50.0% | 3.9min | 1.0% | 1.7min | 0.4% | 2.2min | 0.6% | 3.3min | 67.9% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell | opus | 68 | 8 | 11.8% | 4.7min | 1.2% | 0.5min | 0.1% | 4.1min | 1.1% | 5.2min | 79.3% |
| typescript-bun | sonnet | 58 | 29 | 50.0% | 3.9min | 1.0% | 1.7min | 0.4% | 2.2min | 0.6% | 3.3min | 67.9% |
| bash | sonnet | 60 | 7 | 11.7% | 1.4min | 0.4% | 0.2min | 0.0% | 1.2min | 0.3% | 5.5min | 22.7% |
| default | opus | 50 | 3 | 6.0% | 0.4min | 0.1% | 0.2min | 0.1% | 0.2min | 0.1% | 1.7min | 11.9% |
| default | sonnet | 60 | 1 | 1.7% | 0.1min | 0.0% | 0.2min | 0.0% | -0.0min | -0.0% | 3.0min | -1.6% |
| bash | opus | 65 | 2 | 3.1% | 0.4min | 0.1% | 0.5min | 0.1% | -0.1min | -0.0% | 6.4min | -1.5% |
| typescript-bun | opus | 42 | 23 | 54.8% | 3.1min | 0.8% | 3.4min | 0.9% | -0.3min | -0.1% | 4.3min | -7.0% |
| powershell | sonnet | 56 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 7.9min | -7.6% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell | opus | 68 | 8 | 11.8% | 4.7min | 1.2% | 0.5min | 0.1% | 4.1min | 1.1% | 5.2min | 79.3% |
| typescript-bun | sonnet | 58 | 29 | 50.0% | 3.9min | 1.0% | 1.7min | 0.4% | 2.2min | 0.6% | 3.3min | 67.9% |
| bash | sonnet | 60 | 7 | 11.7% | 1.4min | 0.4% | 0.2min | 0.0% | 1.2min | 0.3% | 5.5min | 22.7% |
| default | opus | 50 | 3 | 6.0% | 0.4min | 0.1% | 0.2min | 0.1% | 0.2min | 0.1% | 1.7min | 11.9% |
| bash | opus | 65 | 2 | 3.1% | 0.4min | 0.1% | 0.5min | 0.1% | -0.1min | -0.0% | 6.4min | -1.5% |
| default | sonnet | 60 | 1 | 1.7% | 0.1min | 0.0% | 0.2min | 0.0% | -0.0min | -0.0% | 3.0min | -1.6% |
| typescript-bun | opus | 42 | 23 | 54.8% | 3.1min | 0.8% | 3.4min | 0.9% | -0.3min | -0.1% | 4.3min | -7.0% |
| powershell | sonnet | 56 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 7.9min | -7.6% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus | 42 | 23 | 54.8% | 3.1min | 0.8% | 3.4min | 0.9% | -0.3min | -0.1% | 4.3min | -7.0% |
| typescript-bun | sonnet | 58 | 29 | 50.0% | 3.9min | 1.0% | 1.7min | 0.4% | 2.2min | 0.6% | 3.3min | 67.9% |
| powershell | opus | 68 | 8 | 11.8% | 4.7min | 1.2% | 0.5min | 0.1% | 4.1min | 1.1% | 5.2min | 79.3% |
| bash | sonnet | 60 | 7 | 11.7% | 1.4min | 0.4% | 0.2min | 0.0% | 1.2min | 0.3% | 5.5min | 22.7% |
| default | opus | 50 | 3 | 6.0% | 0.4min | 0.1% | 0.2min | 0.1% | 0.2min | 0.1% | 1.7min | 11.9% |
| bash | opus | 65 | 2 | 3.1% | 0.4min | 0.1% | 0.5min | 0.1% | -0.1min | -0.0% | 6.4min | -1.5% |
| default | sonnet | 60 | 1 | 1.7% | 0.1min | 0.0% | 0.2min | 0.0% | -0.0min | -0.0% | 3.0min | -1.6% |
| powershell | sonnet | 56 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.2% | -0.6min | -0.2% | 7.9min | -7.6% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus | 5 | 4.6min | 1.2% | $0.84 | 1.42% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 5 | 5.8min | 1.5% | $0.70 | 1.18% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.7% | $0.59 | 1.00% |
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.10% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.4% | $0.37 | 0.62% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.7% | $0.36 | 0.61% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.23% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.19% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.6% | $0.28 | 0.48% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.16% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.22% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.14% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 0.9% | $0.42 | 0.72% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.6% | $0.28 | 0.47% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.5% | $0.25 | 0.42% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.15% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.15% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.10% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.16% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.14% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.15% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.23% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.15% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.19% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.22% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.4% | $0.37 | 0.62% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.5% | $0.25 | 0.42% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.6% | $0.28 | 0.48% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.6% | $0.28 | 0.47% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.7% | $0.36 | 0.61% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.7% | $0.59 | 1.00% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 0.9% | $0.42 | 0.72% |
| ts-type-error-fix-cycles | typescript-bun | opus | 5 | 4.6min | 1.2% | $0.84 | 1.42% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 5 | 5.8min | 1.5% | $0.70 | 1.18% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.10% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.14% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.15% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.15% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.16% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.19% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.22% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.23% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.5% | $0.25 | 0.42% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.6% | $0.28 | 0.47% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.6% | $0.28 | 0.48% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.7% | $0.36 | 0.61% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.4% | $0.37 | 0.62% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 0.9% | $0.42 | 0.72% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.7% | $0.59 | 1.00% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 5 | 5.8min | 1.5% | $0.70 | 1.18% |
| ts-type-error-fix-cycles | typescript-bun | opus | 5 | 4.6min | 1.2% | $0.84 | 1.42% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.10% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.4% | $0.37 | 0.62% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.23% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.19% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.16% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.22% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.14% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.6% | $0.28 | 0.47% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.15% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.15% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.7% | $0.36 | 0.61% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.6% | $0.28 | 0.48% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.5% | $0.25 | 0.42% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.7% | $0.59 | 1.00% |
| repeated-test-reruns | powershell | sonnet | 3 | 3.3min | 0.9% | $0.42 | 0.72% |
| ts-type-error-fix-cycles | typescript-bun | opus | 5 | 4.6min | 1.2% | $0.84 | 1.42% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 5 | 5.8min | 1.5% | $0.70 | 1.18% |

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
| bash | opus | 6 | 4 | 67% | 5 | 4.2min | 1.1% | $0.79 | 1.34% |
| bash | sonnet | 5 | 3 | 60% | 3 | 2.2min | 0.6% | $0.31 | 0.52% |
| default | opus | 6 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 6 | 2 | 33% | 4 | 3.6min | 0.9% | $0.45 | 0.76% |
| powershell | opus | 6 | 1 | 17% | 1 | 1.5min | 0.4% | $0.37 | 0.62% |
| powershell | sonnet | 5 | 5 | 100% | 6 | 8.1min | 2.1% | $1.06 | 1.80% |
| typescript-bun | opus | 6 | 5 | 83% | 7 | 5.9min | 1.6% | $1.07 | 1.81% |
| typescript-bun | sonnet | 5 | 5 | 100% | 6 | 7.0min | 1.9% | $0.83 | 1.40% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 6 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 6 | 1 | 17% | 1 | 1.5min | 0.4% | $0.37 | 0.62% |
| bash | sonnet | 5 | 3 | 60% | 3 | 2.2min | 0.6% | $0.31 | 0.52% |
| default | sonnet | 6 | 2 | 33% | 4 | 3.6min | 0.9% | $0.45 | 0.76% |
| bash | opus | 6 | 4 | 67% | 5 | 4.2min | 1.1% | $0.79 | 1.34% |
| typescript-bun | opus | 6 | 5 | 83% | 7 | 5.9min | 1.6% | $1.07 | 1.81% |
| typescript-bun | sonnet | 5 | 5 | 100% | 6 | 7.0min | 1.9% | $0.83 | 1.40% |
| powershell | sonnet | 5 | 5 | 100% | 6 | 8.1min | 2.1% | $1.06 | 1.80% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 6 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 5 | 3 | 60% | 3 | 2.2min | 0.6% | $0.31 | 0.52% |
| powershell | opus | 6 | 1 | 17% | 1 | 1.5min | 0.4% | $0.37 | 0.62% |
| default | sonnet | 6 | 2 | 33% | 4 | 3.6min | 0.9% | $0.45 | 0.76% |
| bash | opus | 6 | 4 | 67% | 5 | 4.2min | 1.1% | $0.79 | 1.34% |
| typescript-bun | sonnet | 5 | 5 | 100% | 6 | 7.0min | 1.9% | $0.83 | 1.40% |
| powershell | sonnet | 5 | 5 | 100% | 6 | 8.1min | 2.1% | $1.06 | 1.80% |
| typescript-bun | opus | 6 | 5 | 83% | 7 | 5.9min | 1.6% | $1.07 | 1.81% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 6 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 6 | 1 | 17% | 1 | 1.5min | 0.4% | $0.37 | 0.62% |
| default | sonnet | 6 | 2 | 33% | 4 | 3.6min | 0.9% | $0.45 | 0.76% |
| bash | sonnet | 5 | 3 | 60% | 3 | 2.2min | 0.6% | $0.31 | 0.52% |
| bash | opus | 6 | 4 | 67% | 5 | 4.2min | 1.1% | $0.79 | 1.34% |
| typescript-bun | opus | 6 | 5 | 83% | 7 | 5.9min | 1.6% | $1.07 | 1.81% |
| powershell | sonnet | 5 | 5 | 100% | 6 | 8.1min | 2.1% | $1.06 | 1.80% |
| typescript-bun | sonnet | 5 | 5 | 100% | 6 | 7.0min | 1.9% | $0.83 | 1.40% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 1 | $0.06 | 0.10% |
| Partial | 42 | $5.28 | 8.93% |
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
| Test Results Aggregator | default | sonnet | 9.9min | 24 | 2 | $1.20 | python | ok |
| Test Results Aggregator | powershell | opus | 10.0min | 48 | 2 | $2.45 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus | 2.3min | 29 | 1 | $0.61 | typescript | ok |
| Test Results Aggregator | powershell | sonnet | 11.8min | 29 | 1 | $1.36 | powershell | ok |
| Test Results Aggregator | bash | sonnet | 9.0min | 31 | 3 | $1.22 | bash | ok |
| Test Results Aggregator | typescript-bun | sonnet | 10.9min | 35 | 1 | $1.41 | typescript | ok |
| Environment Matrix Generator | default | opus | 6.4min | 29 | 1 | $1.21 | python | ok |
| Environment Matrix Generator | powershell | opus | 5.3min | 38 | 3 | $1.25 | powershell | ok |
| Environment Matrix Generator | bash | opus | 4.1min | 42 | 1 | $0.98 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus | 6.0min | 42 | 3 | $1.10 | typescript | ok |
| Environment Matrix Generator | default | sonnet | 7.8min | 36 | 5 | $1.05 | python | ok |


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
| Environment Matrix Generator | bash | opus | 4.1min | 42 | 1 | $0.98 | bash | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Environment Matrix Generator | default | sonnet | 7.8min | 36 | 5 | $1.05 | python | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus | 6.0min | 42 | 3 | $1.10 | typescript | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Test Results Aggregator | default | sonnet | 9.9min | 24 | 2 | $1.20 | python | ok |
| Environment Matrix Generator | default | opus | 6.4min | 29 | 1 | $1.21 | python | ok |
| Test Results Aggregator | bash | sonnet | 9.0min | 31 | 3 | $1.22 | bash | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Environment Matrix Generator | powershell | opus | 5.3min | 38 | 3 | $1.25 | powershell | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Test Results Aggregator | powershell | sonnet | 11.8min | 29 | 1 | $1.36 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Docker Image Tag Generator | powershell | opus | 7.9min | 24 | 0 | $1.39 | powershell | ok |
| Test Results Aggregator | typescript-bun | sonnet | 10.9min | 35 | 1 | $1.41 | typescript | ok |
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
| Environment Matrix Generator | bash | opus | 4.1min | 42 | 1 | $0.98 | bash | ok |
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Environment Matrix Generator | powershell | opus | 5.3min | 38 | 3 | $1.25 | powershell | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Environment Matrix Generator | typescript-bun | opus | 6.0min | 42 | 3 | $1.10 | typescript | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Environment Matrix Generator | default | opus | 6.4min | 29 | 1 | $1.21 | python | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| Environment Matrix Generator | default | sonnet | 7.8min | 36 | 5 | $1.05 | python | ok |
| Docker Image Tag Generator | powershell | opus | 7.9min | 24 | 0 | $1.39 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Test Results Aggregator | bash | sonnet | 9.0min | 31 | 3 | $1.22 | bash | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Test Results Aggregator | default | sonnet | 9.9min | 24 | 2 | $1.20 | python | ok |
| Test Results Aggregator | powershell | opus | 10.0min | 48 | 2 | $2.45 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| Test Results Aggregator | typescript-bun | sonnet | 10.9min | 35 | 1 | $1.41 | typescript | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 11.8min | 29 | 1 | $1.36 | powershell | ok |
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
| Test Results Aggregator | powershell | sonnet | 11.8min | 29 | 1 | $1.36 | powershell | ok |
| Test Results Aggregator | typescript-bun | sonnet | 10.9min | 35 | 1 | $1.41 | typescript | ok |
| Environment Matrix Generator | default | opus | 6.4min | 29 | 1 | $1.21 | python | ok |
| Environment Matrix Generator | bash | opus | 4.1min | 42 | 1 | $0.98 | bash | ok |
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
| Test Results Aggregator | default | sonnet | 9.9min | 24 | 2 | $1.20 | python | ok |
| Test Results Aggregator | powershell | opus | 10.0min | 48 | 2 | $2.45 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| Test Results Aggregator | bash | sonnet | 9.0min | 31 | 3 | $1.22 | bash | ok |
| Environment Matrix Generator | powershell | opus | 5.3min | 38 | 3 | $1.25 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus | 6.0min | 42 | 3 | $1.10 | typescript | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| Environment Matrix Generator | default | sonnet | 7.8min | 36 | 5 | $1.05 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Docker Image Tag Generator | powershell | opus | 7.9min | 24 | 0 | $1.39 | powershell | ok |
| Test Results Aggregator | default | sonnet | 9.9min | 24 | 2 | $1.20 | python | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Docker Image Tag Generator | bash | opus | 3.7min | 28 | 1 | $0.78 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus | 2.3min | 29 | 1 | $0.61 | typescript | ok |
| Test Results Aggregator | powershell | sonnet | 11.8min | 29 | 1 | $1.36 | powershell | ok |
| Environment Matrix Generator | default | opus | 6.4min | 29 | 1 | $1.21 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| Test Results Aggregator | bash | sonnet | 9.0min | 31 | 3 | $1.22 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| Test Results Aggregator | typescript-bun | sonnet | 10.9min | 35 | 1 | $1.41 | typescript | ok |
| Environment Matrix Generator | default | sonnet | 7.8min | 36 | 5 | $1.05 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| Environment Matrix Generator | powershell | opus | 5.3min | 38 | 3 | $1.25 | powershell | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |
| Test Results Aggregator | bash | opus | 15.8min | 42 | 2 | $2.85 | bash | ok |
| Environment Matrix Generator | bash | opus | 4.1min | 42 | 1 | $0.98 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus | 6.0min | 42 | 3 | $1.10 | typescript | ok |
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