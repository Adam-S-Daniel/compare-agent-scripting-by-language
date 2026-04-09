# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 07:28:14 PM ET

**Status:** 28/64 runs completed, 36 remaining
**Total cost so far:** $37.37
**Total agent time so far:** 239.3 min

## Observations

- **Fastest (avg):** default/opus — 6.6min, then bash/opus — 7.1min
- **Slowest (avg):** bash/sonnet — 12.1min, then powershell/sonnet — 10.8min
- **Cheapest (avg):** typescript-bun/sonnet — $1.11, then default/sonnet — $1.27
- **Most expensive (avg):** bash/sonnet — $1.59, then powershell/opus — $1.40

- **Estimated time remaining:** 307.6min
- **Estimated total cost:** $85.42

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| bash | sonnet | 3 | 12.1min | 11.7min | 5.0 | 46 | $1.59 | $4.78 |
| default | opus | 4 | 6.6min | 6.6min | 1.2 | 31 | $1.35 | $5.39 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| typescript-bun | sonnet | 3 | 8.5min | 7.3min | 1.3 | 39 | $1.11 | $3.33 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | sonnet | 3 | 8.5min | 7.3min | 1.3 | 39 | $1.11 | $3.33 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| default | opus | 4 | 6.6min | 6.6min | 1.2 | 31 | $1.35 | $5.39 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| bash | sonnet | 3 | 12.1min | 11.7min | 5.0 | 46 | $1.59 | $4.78 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 4 | 6.6min | 6.6min | 1.2 | 31 | $1.35 | $5.39 |
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| typescript-bun | sonnet | 3 | 8.5min | 7.3min | 1.3 | 39 | $1.11 | $3.33 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| bash | sonnet | 3 | 12.1min | 11.7min | 5.0 | 46 | $1.59 | $4.78 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| default | opus | 4 | 6.6min | 6.6min | 1.2 | 31 | $1.35 | $5.39 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| typescript-bun | sonnet | 3 | 8.5min | 7.3min | 1.3 | 39 | $1.11 | $3.33 |
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| bash | sonnet | 3 | 12.1min | 11.7min | 5.0 | 46 | $1.59 | $4.78 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 4 | 6.6min | 6.6min | 1.2 | 31 | $1.35 | $5.39 |
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| typescript-bun | sonnet | 3 | 8.5min | 7.3min | 1.3 | 39 | $1.11 | $3.33 |
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| bash | sonnet | 3 | 12.1min | 11.7min | 5.0 | 46 | $1.59 | $4.78 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 4 | 6.6min | 6.6min | 1.2 | 31 | $1.35 | $5.39 |
| powershell | opus | 4 | 8.1min | 8.1min | 1.2 | 31 | $1.40 | $5.60 |
| typescript-bun | opus | 4 | 7.7min | 6.7min | 1.8 | 38 | $1.36 | $5.43 |
| typescript-bun | sonnet | 3 | 8.5min | 7.3min | 1.3 | 39 | $1.11 | $3.33 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| bash | opus | 4 | 7.1min | 6.5min | 1.8 | 44 | $1.27 | $5.08 |
| bash | sonnet | 3 | 12.1min | 11.7min | 5.0 | 46 | $1.59 | $4.78 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus | 44 | 2 | 4.5% | 0.4min | 0.2% | 0.7min | 0.3% | -0.3min | -0.1% | 5.8min | -4.4% |
| bash | sonnet | 44 | 7 | 15.9% | 1.4min | 0.6% | 0.7min | 0.3% | 0.7min | 0.3% | 2.7min | 27.4% |
| default | opus | 31 | 3 | 9.7% | 0.4min | 0.2% | 0.3min | 0.1% | 0.1min | 0.0% | 1.4min | 7.4% |
| default | sonnet | 32 | 1 | 3.1% | 0.1min | 0.1% | 0.3min | 0.1% | -0.2min | -0.1% | 1.0min | -16.7% |
| powershell | opus | 40 | 2 | 5.0% | 1.2min | 0.5% | 0.7min | 0.3% | 0.5min | 0.2% | 4.1min | 11.8% |
| powershell | sonnet | 37 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.3% | -0.6min | -0.3% | 6.9min | -9.2% |
| typescript-bun | opus | 30 | 17 | 56.7% | 2.3min | 0.9% | 3.4min | 1.4% | -1.2min | -0.5% | 3.7min | -31.7% |
| typescript-bun | sonnet | 34 | 13 | 38.2% | 1.7min | 0.7% | 3.9min | 1.6% | -2.2min | -0.9% | 0.0min | -5858.6% |
| **Total** | | **292** | **45** | **15.4%** | **7.5min** | **3.1%** | **10.6min** | **4.4%** | **-3.1min** | **-1.3%** | **25.7min** | **-12.0%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | sonnet | 44 | 7 | 15.9% | 1.4min | 0.6% | 0.7min | 0.3% | 0.7min | 0.3% | 2.7min | 27.4% |
| powershell | opus | 40 | 2 | 5.0% | 1.2min | 0.5% | 0.7min | 0.3% | 0.5min | 0.2% | 4.1min | 11.8% |
| default | opus | 31 | 3 | 9.7% | 0.4min | 0.2% | 0.3min | 0.1% | 0.1min | 0.0% | 1.4min | 7.4% |
| default | sonnet | 32 | 1 | 3.1% | 0.1min | 0.1% | 0.3min | 0.1% | -0.2min | -0.1% | 1.0min | -16.7% |
| bash | opus | 44 | 2 | 4.5% | 0.4min | 0.2% | 0.7min | 0.3% | -0.3min | -0.1% | 5.8min | -4.4% |
| powershell | sonnet | 37 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.3% | -0.6min | -0.3% | 6.9min | -9.2% |
| typescript-bun | opus | 30 | 17 | 56.7% | 2.3min | 0.9% | 3.4min | 1.4% | -1.2min | -0.5% | 3.7min | -31.7% |
| typescript-bun | sonnet | 34 | 13 | 38.2% | 1.7min | 0.7% | 3.9min | 1.6% | -2.2min | -0.9% | 0.0min | -5858.6% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | sonnet | 44 | 7 | 15.9% | 1.4min | 0.6% | 0.7min | 0.3% | 0.7min | 0.3% | 2.7min | 27.4% |
| powershell | opus | 40 | 2 | 5.0% | 1.2min | 0.5% | 0.7min | 0.3% | 0.5min | 0.2% | 4.1min | 11.8% |
| default | opus | 31 | 3 | 9.7% | 0.4min | 0.2% | 0.3min | 0.1% | 0.1min | 0.0% | 1.4min | 7.4% |
| bash | opus | 44 | 2 | 4.5% | 0.4min | 0.2% | 0.7min | 0.3% | -0.3min | -0.1% | 5.8min | -4.4% |
| powershell | sonnet | 37 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.3% | -0.6min | -0.3% | 6.9min | -9.2% |
| default | sonnet | 32 | 1 | 3.1% | 0.1min | 0.1% | 0.3min | 0.1% | -0.2min | -0.1% | 1.0min | -16.7% |
| typescript-bun | opus | 30 | 17 | 56.7% | 2.3min | 0.9% | 3.4min | 1.4% | -1.2min | -0.5% | 3.7min | -31.7% |
| typescript-bun | sonnet | 34 | 13 | 38.2% | 1.7min | 0.7% | 3.9min | 1.6% | -2.2min | -0.9% | 0.0min | -5858.6% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus | 30 | 17 | 56.7% | 2.3min | 0.9% | 3.4min | 1.4% | -1.2min | -0.5% | 3.7min | -31.7% |
| typescript-bun | sonnet | 34 | 13 | 38.2% | 1.7min | 0.7% | 3.9min | 1.6% | -2.2min | -0.9% | 0.0min | -5858.6% |
| bash | sonnet | 44 | 7 | 15.9% | 1.4min | 0.6% | 0.7min | 0.3% | 0.7min | 0.3% | 2.7min | 27.4% |
| default | opus | 31 | 3 | 9.7% | 0.4min | 0.2% | 0.3min | 0.1% | 0.1min | 0.0% | 1.4min | 7.4% |
| powershell | opus | 40 | 2 | 5.0% | 1.2min | 0.5% | 0.7min | 0.3% | 0.5min | 0.2% | 4.1min | 11.8% |
| bash | opus | 44 | 2 | 4.5% | 0.4min | 0.2% | 0.7min | 0.3% | -0.3min | -0.1% | 5.8min | -4.4% |
| default | sonnet | 32 | 1 | 3.1% | 0.1min | 0.1% | 0.3min | 0.1% | -0.2min | -0.1% | 1.0min | -16.7% |
| powershell | sonnet | 37 | 0 | 0.0% | 0.0min | 0.0% | 0.6min | 0.3% | -0.6min | -0.3% | 6.9min | -9.2% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.4% | $0.62 | 1.65% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 3 | 2.6min | 1.1% | $0.34 | 0.91% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.30% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 0.6% | $0.21 | 0.56% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.25% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.5% | $0.13 | 0.35% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.4% | $0.22 | 0.58% |
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.16% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.7% | $0.27 | 0.73% |
| repeated-test-reruns | powershell | sonnet | 2 | 2.7min | 1.1% | $0.34 | 0.91% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.9% | $0.28 | 0.75% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.3% | $0.11 | 0.31% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.3% | $0.09 | 0.24% |
| **Total** | | | **15 runs** | **19.7min** | **8.2%** | **$2.88** | **7.69%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.16% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.25% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.3% | $0.09 | 0.24% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.3% | $0.11 | 0.31% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.30% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.4% | $0.22 | 0.58% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.5% | $0.13 | 0.35% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 0.6% | $0.21 | 0.56% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.7% | $0.27 | 0.73% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.9% | $0.28 | 0.75% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 3 | 2.6min | 1.1% | $0.34 | 0.91% |
| repeated-test-reruns | powershell | sonnet | 2 | 2.7min | 1.1% | $0.34 | 0.91% |
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.4% | $0.62 | 1.65% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.16% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.3% | $0.09 | 0.24% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.25% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.30% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.3% | $0.11 | 0.31% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.5% | $0.13 | 0.35% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 0.6% | $0.21 | 0.56% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.4% | $0.22 | 0.58% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.7% | $0.27 | 0.73% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.9% | $0.28 | 0.75% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 3 | 2.6min | 1.1% | $0.34 | 0.91% |
| repeated-test-reruns | powershell | sonnet | 2 | 2.7min | 1.1% | $0.34 | 0.91% |
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.4% | $0.62 | 1.65% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.3% | $0.11 | 0.30% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 0.6% | $0.21 | 0.56% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.2% | $0.09 | 0.25% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.5% | $0.13 | 0.35% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.4% | $0.22 | 0.58% |
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.2% | $0.06 | 0.16% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.7% | $0.27 | 0.73% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 0.9% | $0.28 | 0.75% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.3% | $0.11 | 0.31% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.3% | $0.09 | 0.24% |
| repeated-test-reruns | powershell | sonnet | 2 | 2.7min | 1.1% | $0.34 | 0.91% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 3 | 2.6min | 1.1% | $0.34 | 0.91% |
| ts-type-error-fix-cycles | typescript-bun | opus | 4 | 3.4min | 1.4% | $0.62 | 1.65% |

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
| bash | opus | 4 | 2 | 50% | 3 | 2.5min | 1.0% | $0.42 | 1.11% |
| bash | sonnet | 3 | 2 | 67% | 2 | 1.2min | 0.5% | $0.17 | 0.47% |
| default | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 3 | 1 | 33% | 1 | 1.5min | 0.6% | $0.21 | 0.56% |
| powershell | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 3 | 3 | 100% | 4 | 6.7min | 2.8% | $0.90 | 2.40% |
| typescript-bun | opus | 4 | 4 | 100% | 5 | 3.9min | 1.6% | $0.71 | 1.90% |
| typescript-bun | sonnet | 3 | 3 | 100% | 4 | 3.8min | 1.6% | $0.47 | 1.26% |
| **Total** | | **28** | **15** | **54%** | **19** | **19.7min** | **8.2%** | **$2.88** | **7.69%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 3 | 2 | 67% | 2 | 1.2min | 0.5% | $0.17 | 0.47% |
| default | sonnet | 3 | 1 | 33% | 1 | 1.5min | 0.6% | $0.21 | 0.56% |
| bash | opus | 4 | 2 | 50% | 3 | 2.5min | 1.0% | $0.42 | 1.11% |
| typescript-bun | sonnet | 3 | 3 | 100% | 4 | 3.8min | 1.6% | $0.47 | 1.26% |
| typescript-bun | opus | 4 | 4 | 100% | 5 | 3.9min | 1.6% | $0.71 | 1.90% |
| powershell | sonnet | 3 | 3 | 100% | 4 | 6.7min | 2.8% | $0.90 | 2.40% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 3 | 2 | 67% | 2 | 1.2min | 0.5% | $0.17 | 0.47% |
| default | sonnet | 3 | 1 | 33% | 1 | 1.5min | 0.6% | $0.21 | 0.56% |
| bash | opus | 4 | 2 | 50% | 3 | 2.5min | 1.0% | $0.42 | 1.11% |
| typescript-bun | sonnet | 3 | 3 | 100% | 4 | 3.8min | 1.6% | $0.47 | 1.26% |
| typescript-bun | opus | 4 | 4 | 100% | 5 | 3.9min | 1.6% | $0.71 | 1.90% |
| powershell | sonnet | 3 | 3 | 100% | 4 | 6.7min | 2.8% | $0.90 | 2.40% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 4 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 3 | 1 | 33% | 1 | 1.5min | 0.6% | $0.21 | 0.56% |
| bash | opus | 4 | 2 | 50% | 3 | 2.5min | 1.0% | $0.42 | 1.11% |
| bash | sonnet | 3 | 2 | 67% | 2 | 1.2min | 0.5% | $0.17 | 0.47% |
| powershell | sonnet | 3 | 3 | 100% | 4 | 6.7min | 2.8% | $0.90 | 2.40% |
| typescript-bun | opus | 4 | 4 | 100% | 5 | 3.9min | 1.6% | $0.71 | 1.90% |
| typescript-bun | sonnet | 3 | 3 | 100% | 4 | 3.8min | 1.6% | $0.47 | 1.26% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 26 | $3.39 | 9.06% |
| Miss | 2 | $0.00 | 0.00% |
| **Total** | **28** | **$3.39** | **9.06%** |

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


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Docker Image Tag Generator | bash | opus | 3.7min | 28 | 1 | $0.78 | bash | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
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
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
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
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
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
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| Dependency License Checker | typescript-bun | sonnet | 9.5min | 43 | 2 | $1.47 | typescript | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Dependency License Checker | bash | sonnet | 14.1min | 42 | 3 | $1.68 | bash | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Docker Image Tag Generator | powershell | opus | 7.9min | 24 | 0 | $1.39 | powershell | ok |
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