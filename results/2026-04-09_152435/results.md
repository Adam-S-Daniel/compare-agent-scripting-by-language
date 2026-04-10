# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-10 12:26:58 AM ET

**Status:** 49/64 runs completed, 15 remaining
**Total cost so far:** $65.15
**Total agent time so far:** 418.0 min

## Observations

- **Fastest (avg):** typescript-bun/opus — 6.5min, then default/opus — 6.8min
- **Slowest (avg):** powershell/sonnet — 10.8min, then bash/sonnet — 10.1min
- **Cheapest (avg):** typescript-bun/sonnet — $1.16, then default/sonnet — $1.18
- **Most expensive (avg):** powershell/opus — $1.55, then bash/opus — $1.49

- **Estimated time remaining:** 127.9min
- **Estimated total cost:** $85.10

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |
| bash | sonnet | 6 | 10.1min | 9.7min | 3.8 | 37 | $1.31 | $7.84 |
| default | opus | 7 | 6.8min | 6.8min | 1.6 | 34 | $1.44 | $10.06 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |
| powershell | sonnet | 6 | 10.8min | 8.9min | 1.7 | 41 | $1.31 | $7.89 |
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| typescript-bun | sonnet | 6 | 9.5min | 8.0min | 1.8 | 37 | $1.16 | $6.94 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | sonnet | 6 | 9.5min | 8.0min | 1.8 | 37 | $1.16 | $6.94 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| bash | sonnet | 6 | 10.1min | 9.7min | 3.8 | 37 | $1.31 | $7.84 |
| powershell | sonnet | 6 | 10.8min | 8.9min | 1.7 | 41 | $1.31 | $7.89 |
| default | opus | 7 | 6.8min | 6.8min | 1.6 | 34 | $1.44 | $10.06 |
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| default | opus | 7 | 6.8min | 6.8min | 1.6 | 34 | $1.44 | $10.06 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| typescript-bun | sonnet | 6 | 9.5min | 8.0min | 1.8 | 37 | $1.16 | $6.94 |
| bash | sonnet | 6 | 10.1min | 9.7min | 3.8 | 37 | $1.31 | $7.84 |
| powershell | sonnet | 6 | 10.8min | 8.9min | 1.7 | 41 | $1.31 | $7.89 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| default | opus | 7 | 6.8min | 6.8min | 1.6 | 34 | $1.44 | $10.06 |
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |
| typescript-bun | sonnet | 6 | 9.5min | 8.0min | 1.8 | 37 | $1.16 | $6.94 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| powershell | sonnet | 6 | 10.8min | 8.9min | 1.7 | 41 | $1.31 | $7.89 |
| bash | sonnet | 6 | 10.1min | 9.7min | 3.8 | 37 | $1.31 | $7.84 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 7 | 6.8min | 6.8min | 1.6 | 34 | $1.44 | $10.06 |
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |
| powershell | sonnet | 6 | 10.8min | 8.9min | 1.7 | 41 | $1.31 | $7.89 |
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| typescript-bun | sonnet | 6 | 9.5min | 8.0min | 1.8 | 37 | $1.16 | $6.94 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| bash | sonnet | 6 | 10.1min | 9.7min | 3.8 | 37 | $1.31 | $7.84 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 7 | 6.8min | 6.8min | 1.6 | 34 | $1.44 | $10.06 |
| powershell | opus | 6 | 7.9min | 7.7min | 1.7 | 35 | $1.55 | $9.30 |
| bash | sonnet | 6 | 10.1min | 9.7min | 3.8 | 37 | $1.31 | $7.84 |
| typescript-bun | opus | 6 | 6.5min | 5.5min | 1.8 | 37 | $1.19 | $7.14 |
| default | sonnet | 6 | 8.8min | 8.2min | 2.7 | 37 | $1.18 | $7.07 |
| typescript-bun | sonnet | 6 | 9.5min | 8.0min | 1.8 | 37 | $1.16 | $6.94 |
| powershell | sonnet | 6 | 10.8min | 8.9min | 1.7 | 41 | $1.31 | $7.89 |
| bash | opus | 6 | 8.1min | 7.4min | 1.7 | 43 | $1.49 | $8.92 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus | 65 | 2 | 3.1% | 0.4min | 0.1% | 0.5min | 0.1% | -0.1min | -0.0% | 6.4min | -1.5% |
| bash | sonnet | 69 | 7 | 10.1% | 1.4min | 0.3% | 0.2min | 0.0% | 1.2min | 0.3% | 6.2min | 19.9% |
| default | opus | 68 | 14 | 20.6% | 1.9min | 0.4% | 0.2min | 0.1% | 1.6min | 0.4% | 2.5min | 65.2% |
| default | sonnet | 60 | 1 | 1.7% | 0.1min | 0.0% | 0.2min | 0.0% | -0.0min | -0.0% | 3.0min | -1.6% |
| powershell | opus | 68 | 8 | 11.8% | 4.7min | 1.1% | 0.5min | 0.1% | 4.1min | 1.0% | 5.2min | 79.3% |
| powershell | sonnet | 71 | 1 | 1.4% | 0.6min | 0.1% | 0.7min | 0.2% | -0.1min | -0.0% | 8.8min | -1.1% |
| typescript-bun | opus | 42 | 23 | 54.8% | 3.1min | 0.7% | 3.4min | 0.8% | -0.3min | -0.1% | 4.3min | -7.0% |
| typescript-bun | sonnet | 69 | 35 | 50.7% | 4.7min | 1.1% | 2.0min | 0.5% | 2.7min | 0.6% | 4.1min | 65.4% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell | opus | 68 | 8 | 11.8% | 4.7min | 1.1% | 0.5min | 0.1% | 4.1min | 1.0% | 5.2min | 79.3% |
| typescript-bun | sonnet | 69 | 35 | 50.7% | 4.7min | 1.1% | 2.0min | 0.5% | 2.7min | 0.6% | 4.1min | 65.4% |
| default | opus | 68 | 14 | 20.6% | 1.9min | 0.4% | 0.2min | 0.1% | 1.6min | 0.4% | 2.5min | 65.2% |
| bash | sonnet | 69 | 7 | 10.1% | 1.4min | 0.3% | 0.2min | 0.0% | 1.2min | 0.3% | 6.2min | 19.9% |
| default | sonnet | 60 | 1 | 1.7% | 0.1min | 0.0% | 0.2min | 0.0% | -0.0min | -0.0% | 3.0min | -1.6% |
| bash | opus | 65 | 2 | 3.1% | 0.4min | 0.1% | 0.5min | 0.1% | -0.1min | -0.0% | 6.4min | -1.5% |
| powershell | sonnet | 71 | 1 | 1.4% | 0.6min | 0.1% | 0.7min | 0.2% | -0.1min | -0.0% | 8.8min | -1.1% |
| typescript-bun | opus | 42 | 23 | 54.8% | 3.1min | 0.7% | 3.4min | 0.8% | -0.3min | -0.1% | 4.3min | -7.0% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell | opus | 68 | 8 | 11.8% | 4.7min | 1.1% | 0.5min | 0.1% | 4.1min | 1.0% | 5.2min | 79.3% |
| typescript-bun | sonnet | 69 | 35 | 50.7% | 4.7min | 1.1% | 2.0min | 0.5% | 2.7min | 0.6% | 4.1min | 65.4% |
| default | opus | 68 | 14 | 20.6% | 1.9min | 0.4% | 0.2min | 0.1% | 1.6min | 0.4% | 2.5min | 65.2% |
| bash | sonnet | 69 | 7 | 10.1% | 1.4min | 0.3% | 0.2min | 0.0% | 1.2min | 0.3% | 6.2min | 19.9% |
| powershell | sonnet | 71 | 1 | 1.4% | 0.6min | 0.1% | 0.7min | 0.2% | -0.1min | -0.0% | 8.8min | -1.1% |
| bash | opus | 65 | 2 | 3.1% | 0.4min | 0.1% | 0.5min | 0.1% | -0.1min | -0.0% | 6.4min | -1.5% |
| default | sonnet | 60 | 1 | 1.7% | 0.1min | 0.0% | 0.2min | 0.0% | -0.0min | -0.0% | 3.0min | -1.6% |
| typescript-bun | opus | 42 | 23 | 54.8% | 3.1min | 0.7% | 3.4min | 0.8% | -0.3min | -0.1% | 4.3min | -7.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus | 42 | 23 | 54.8% | 3.1min | 0.7% | 3.4min | 0.8% | -0.3min | -0.1% | 4.3min | -7.0% |
| typescript-bun | sonnet | 69 | 35 | 50.7% | 4.7min | 1.1% | 2.0min | 0.5% | 2.7min | 0.6% | 4.1min | 65.4% |
| default | opus | 68 | 14 | 20.6% | 1.9min | 0.4% | 0.2min | 0.1% | 1.6min | 0.4% | 2.5min | 65.2% |
| powershell | opus | 68 | 8 | 11.8% | 4.7min | 1.1% | 0.5min | 0.1% | 4.1min | 1.0% | 5.2min | 79.3% |
| bash | sonnet | 69 | 7 | 10.1% | 1.4min | 0.3% | 0.2min | 0.0% | 1.2min | 0.3% | 6.2min | 19.9% |
| bash | opus | 65 | 2 | 3.1% | 0.4min | 0.1% | 0.5min | 0.1% | -0.1min | -0.0% | 6.4min | -1.5% |
| default | sonnet | 60 | 1 | 1.7% | 0.1min | 0.0% | 0.2min | 0.0% | -0.0min | -0.0% | 3.0min | -1.6% |
| powershell | sonnet | 71 | 1 | 1.4% | 0.6min | 0.1% | 0.7min | 0.2% | -0.1min | -0.0% | 8.8min | -1.1% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus | 5 | 4.6min | 1.1% | $0.84 | 1.29% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 6 | 7.0min | 1.7% | $0.87 | 1.33% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.7% | $0.59 | 0.91% |
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.09% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.4% | $0.37 | 0.57% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.6% | $0.36 | 0.55% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.21% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.12% |
| repeated-test-reruns | powershell | sonnet | 4 | 4.3min | 1.0% | $0.55 | 0.85% |
| repeated-test-reruns | typescript-bun | sonnet | 1 | 1.0min | 0.2% | $0.14 | 0.22% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.17% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.5% | $0.28 | 0.43% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.14% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.20% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 1.1% | $0.57 | 0.87% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.4% | $0.25 | 0.38% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.14% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.14% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.09% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.14% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.12% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.14% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.21% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.14% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.17% |
| repeated-test-reruns | typescript-bun | sonnet | 1 | 1.0min | 0.2% | $0.14 | 0.22% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.20% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.4% | $0.37 | 0.57% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.4% | $0.25 | 0.38% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.5% | $0.28 | 0.43% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.6% | $0.36 | 0.55% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.7% | $0.59 | 0.91% |
| repeated-test-reruns | powershell | sonnet | 4 | 4.3min | 1.0% | $0.55 | 0.85% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 1.1% | $0.57 | 0.87% |
| ts-type-error-fix-cycles | typescript-bun | opus | 5 | 4.6min | 1.1% | $0.84 | 1.29% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 6 | 7.0min | 1.7% | $0.87 | 1.33% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.09% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.12% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.14% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.14% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.14% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.17% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.20% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.21% |
| repeated-test-reruns | typescript-bun | sonnet | 1 | 1.0min | 0.2% | $0.14 | 0.22% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.4% | $0.25 | 0.38% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.5% | $0.28 | 0.43% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.6% | $0.36 | 0.55% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.4% | $0.37 | 0.57% |
| repeated-test-reruns | powershell | sonnet | 4 | 4.3min | 1.0% | $0.55 | 0.85% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 1.1% | $0.57 | 0.87% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.7% | $0.59 | 0.91% |
| ts-type-error-fix-cycles | typescript-bun | opus | 5 | 4.6min | 1.1% | $0.84 | 1.29% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 6 | 7.0min | 1.7% | $0.87 | 1.33% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.09% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.4% | $0.37 | 0.57% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.21% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.2% | $0.08 | 0.12% |
| repeated-test-reruns | typescript-bun | sonnet | 1 | 1.0min | 0.2% | $0.14 | 0.22% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.17% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.14% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.20% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.14% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.2% | $0.09 | 0.14% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.6% | $0.36 | 0.55% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.5% | $0.28 | 0.43% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 1.1% | $0.57 | 0.87% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.4% | $0.25 | 0.38% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.7% | $0.59 | 0.91% |
| repeated-test-reruns | powershell | sonnet | 4 | 4.3min | 1.0% | $0.55 | 0.85% |
| ts-type-error-fix-cycles | typescript-bun | opus | 5 | 4.6min | 1.1% | $0.84 | 1.29% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 6 | 7.0min | 1.7% | $0.87 | 1.33% |

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
| bash | opus | 6 | 4 | 67% | 5 | 4.2min | 1.0% | $0.79 | 1.22% |
| bash | sonnet | 6 | 3 | 50% | 3 | 2.2min | 0.5% | $0.31 | 0.48% |
| default | opus | 7 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 6 | 2 | 33% | 4 | 3.6min | 0.9% | $0.45 | 0.69% |
| powershell | opus | 6 | 1 | 17% | 1 | 1.5min | 0.4% | $0.37 | 0.57% |
| powershell | sonnet | 6 | 6 | 100% | 8 | 11.3min | 2.7% | $1.48 | 2.27% |
| typescript-bun | opus | 6 | 5 | 83% | 7 | 5.9min | 1.4% | $1.07 | 1.64% |
| typescript-bun | sonnet | 6 | 6 | 100% | 8 | 9.2min | 2.2% | $1.14 | 1.76% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 7 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 6 | 1 | 17% | 1 | 1.5min | 0.4% | $0.37 | 0.57% |
| bash | sonnet | 6 | 3 | 50% | 3 | 2.2min | 0.5% | $0.31 | 0.48% |
| default | sonnet | 6 | 2 | 33% | 4 | 3.6min | 0.9% | $0.45 | 0.69% |
| bash | opus | 6 | 4 | 67% | 5 | 4.2min | 1.0% | $0.79 | 1.22% |
| typescript-bun | opus | 6 | 5 | 83% | 7 | 5.9min | 1.4% | $1.07 | 1.64% |
| typescript-bun | sonnet | 6 | 6 | 100% | 8 | 9.2min | 2.2% | $1.14 | 1.76% |
| powershell | sonnet | 6 | 6 | 100% | 8 | 11.3min | 2.7% | $1.48 | 2.27% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 7 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 6 | 3 | 50% | 3 | 2.2min | 0.5% | $0.31 | 0.48% |
| powershell | opus | 6 | 1 | 17% | 1 | 1.5min | 0.4% | $0.37 | 0.57% |
| default | sonnet | 6 | 2 | 33% | 4 | 3.6min | 0.9% | $0.45 | 0.69% |
| bash | opus | 6 | 4 | 67% | 5 | 4.2min | 1.0% | $0.79 | 1.22% |
| typescript-bun | opus | 6 | 5 | 83% | 7 | 5.9min | 1.4% | $1.07 | 1.64% |
| typescript-bun | sonnet | 6 | 6 | 100% | 8 | 9.2min | 2.2% | $1.14 | 1.76% |
| powershell | sonnet | 6 | 6 | 100% | 8 | 11.3min | 2.7% | $1.48 | 2.27% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 7 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 6 | 1 | 17% | 1 | 1.5min | 0.4% | $0.37 | 0.57% |
| default | sonnet | 6 | 2 | 33% | 4 | 3.6min | 0.9% | $0.45 | 0.69% |
| bash | sonnet | 6 | 3 | 50% | 3 | 2.2min | 0.5% | $0.31 | 0.48% |
| bash | opus | 6 | 4 | 67% | 5 | 4.2min | 1.0% | $0.79 | 1.22% |
| typescript-bun | opus | 6 | 5 | 83% | 7 | 5.9min | 1.4% | $1.07 | 1.64% |
| powershell | sonnet | 6 | 6 | 100% | 8 | 11.3min | 2.7% | $1.48 | 2.27% |
| typescript-bun | sonnet | 6 | 6 | 100% | 8 | 9.2min | 2.2% | $1.14 | 1.76% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 1 | $0.06 | 0.09% |
| Partial | 46 | $5.59 | 8.58% |
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
| Environment Matrix Generator | powershell | sonnet | 11.5min | 54 | 1 | $1.46 | powershell | ok |
| Environment Matrix Generator | bash | sonnet | 10.5min | 25 | 3 | $1.22 | bash | ok |
| Environment Matrix Generator | typescript-bun | sonnet | 8.5min | 48 | 3 | $1.22 | typescript | ok |
| Artifact Cleanup Script | default | opus | 9.2min | 49 | 2 | $2.19 | python | ok |


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
| Environment Matrix Generator | typescript-bun | sonnet | 8.5min | 48 | 3 | $1.22 | typescript | ok |
| Environment Matrix Generator | bash | sonnet | 10.5min | 25 | 3 | $1.22 | bash | ok |
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
| Environment Matrix Generator | powershell | sonnet | 11.5min | 54 | 1 | $1.46 | powershell | ok |
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
| Artifact Cleanup Script | default | opus | 9.2min | 49 | 2 | $2.19 | python | ok |
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
| Environment Matrix Generator | typescript-bun | sonnet | 8.5min | 48 | 3 | $1.22 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Test Results Aggregator | bash | sonnet | 9.0min | 31 | 3 | $1.22 | bash | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Artifact Cleanup Script | default | opus | 9.2min | 49 | 2 | $2.19 | python | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Test Results Aggregator | default | sonnet | 9.9min | 24 | 2 | $1.20 | python | ok |
| Test Results Aggregator | powershell | opus | 10.0min | 48 | 2 | $2.45 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| Environment Matrix Generator | bash | sonnet | 10.5min | 25 | 3 | $1.22 | bash | ok |
| Test Results Aggregator | typescript-bun | sonnet | 10.9min | 35 | 1 | $1.41 | typescript | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 11.5min | 54 | 1 | $1.46 | powershell | ok |
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
| Environment Matrix Generator | powershell | sonnet | 11.5min | 54 | 1 | $1.46 | powershell | ok |
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
| Artifact Cleanup Script | default | opus | 9.2min | 49 | 2 | $2.19 | python | ok |
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
| Environment Matrix Generator | bash | sonnet | 10.5min | 25 | 3 | $1.22 | bash | ok |
| Environment Matrix Generator | typescript-bun | sonnet | 8.5min | 48 | 3 | $1.22 | typescript | ok |
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
| Environment Matrix Generator | bash | sonnet | 10.5min | 25 | 3 | $1.22 | bash | ok |
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
| Environment Matrix Generator | typescript-bun | sonnet | 8.5min | 48 | 3 | $1.22 | typescript | ok |
| Artifact Cleanup Script | default | opus | 9.2min | 49 | 2 | $2.19 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| Environment Matrix Generator | powershell | sonnet | 11.5min | 54 | 1 | $1.46 | powershell | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*