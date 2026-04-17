# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-17 12:41:37 PM ET

**Status:** 69/35 runs completed, 1 remaining
**Total cost so far:** $148.58
**Total agent time so far:** 653.2 min

## Observations

- **Fastest (avg):** bash/opus47-1m-medium — 4.9min, then default/opus47-1m-medium — 5.4min
- **Slowest (avg):** bash/opus47-1m-xhigh — 16.5min, then typescript-bun/opus47-1m-xhigh — 12.0min
- **Cheapest (avg):** default/opus47-1m-medium — $1.03, then bash/opus47-1m-medium — $1.11
- **Most expensive (avg):** typescript-bun/opus47-1m-xhigh — $3.54, then powershell/opus47-1m-xhigh — $3.21

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 |
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 |
| typescript-bun | opus47-1m-medium | 6 | 7.6min | 6.4min | 0.2 | 31 | $1.26 | $7.54 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 |
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 |
| typescript-bun | opus47-1m-medium | 6 | 7.6min | 6.4min | 0.2 | 31 | $1.26 | $7.54 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 |
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 |
| typescript-bun | opus47-1m-medium | 6 | 7.6min | 6.4min | 0.2 | 31 | $1.26 | $7.54 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 |
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 |
| typescript-bun | opus47-1m-medium | 6 | 7.6min | 6.4min | 0.2 | 31 | $1.26 | $7.54 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 |
| typescript-bun | opus47-1m-medium | 6 | 7.6min | 6.4min | 0.2 | 31 | $1.26 | $7.54 |
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 |
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 |
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 |
| typescript-bun | opus47-1m-medium | 6 | 7.6min | 6.4min | 0.2 | 31 | $1.26 | $7.54 |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus47-1m-medium | 70 | 3 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 7.6min | 5.2% |
| bash | opus47-1m-xhigh | 112 | 4 | 3.6% | 0.8min | 0.1% | 0.1min | 0.0% | 0.7min | 0.1% | 28.8min | 2.4% |
| default | opus47-1m-medium | 75 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 13.4min | -0.7% |
| default | opus47-1m-xhigh | 103 | 3 | 2.9% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 7.0min | 2.3% |
| powershell | opus47-1m-medium | 110 | 0 | 0.0% | 0.0min | 0.0% | 2.5min | 0.4% | -2.5min | -0.4% | 32.3min | -7.8% |
| powershell | opus47-1m-xhigh | 116 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.1% | -0.8min | -0.1% | 11.9min | -6.8% |
| powershell-tool | opus47-1m-medium | 85 | 0 | 0.0% | 0.0min | 0.0% | 1.5min | 0.2% | -1.5min | -0.2% | 18.9min | -7.9% |
| powershell-tool | opus47-1m-xhigh | 122 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.1% | -0.7min | -0.1% | 8.4min | -8.9% |
| typescript-bun | opus47-1m-medium | 76 | 32 | 42.1% | 4.3min | 0.7% | 2.2min | 0.3% | 2.0min | 0.3% | 15.4min | 13.3% |
| typescript-bun | opus47-1m-xhigh | 159 | 86 | 54.1% | 11.5min | 1.8% | 4.8min | 0.7% | 6.7min | 1.0% | 14.7min | 45.5% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m-xhigh | 159 | 86 | 54.1% | 11.5min | 1.8% | 4.8min | 0.7% | 6.7min | 1.0% | 14.7min | 45.5% |
| typescript-bun | opus47-1m-medium | 76 | 32 | 42.1% | 4.3min | 0.7% | 2.2min | 0.3% | 2.0min | 0.3% | 15.4min | 13.3% |
| bash | opus47-1m-xhigh | 112 | 4 | 3.6% | 0.8min | 0.1% | 0.1min | 0.0% | 0.7min | 0.1% | 28.8min | 2.4% |
| bash | opus47-1m-medium | 70 | 3 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 7.6min | 5.2% |
| default | opus47-1m-xhigh | 103 | 3 | 2.9% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 7.0min | 2.3% |
| default | opus47-1m-medium | 75 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 13.4min | -0.7% |
| powershell-tool | opus47-1m-xhigh | 122 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.1% | -0.7min | -0.1% | 8.4min | -8.9% |
| powershell | opus47-1m-xhigh | 116 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.1% | -0.8min | -0.1% | 11.9min | -6.8% |
| powershell-tool | opus47-1m-medium | 85 | 0 | 0.0% | 0.0min | 0.0% | 1.5min | 0.2% | -1.5min | -0.2% | 18.9min | -7.9% |
| powershell | opus47-1m-medium | 110 | 0 | 0.0% | 0.0min | 0.0% | 2.5min | 0.4% | -2.5min | -0.4% | 32.3min | -7.8% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m-xhigh | 159 | 86 | 54.1% | 11.5min | 1.8% | 4.8min | 0.7% | 6.7min | 1.0% | 14.7min | 45.5% |
| typescript-bun | opus47-1m-medium | 76 | 32 | 42.1% | 4.3min | 0.7% | 2.2min | 0.3% | 2.0min | 0.3% | 15.4min | 13.3% |
| bash | opus47-1m-medium | 70 | 3 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 7.6min | 5.2% |
| bash | opus47-1m-xhigh | 112 | 4 | 3.6% | 0.8min | 0.1% | 0.1min | 0.0% | 0.7min | 0.1% | 28.8min | 2.4% |
| default | opus47-1m-xhigh | 103 | 3 | 2.9% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 7.0min | 2.3% |
| default | opus47-1m-medium | 75 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 13.4min | -0.7% |
| powershell | opus47-1m-xhigh | 116 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.1% | -0.8min | -0.1% | 11.9min | -6.8% |
| powershell | opus47-1m-medium | 110 | 0 | 0.0% | 0.0min | 0.0% | 2.5min | 0.4% | -2.5min | -0.4% | 32.3min | -7.8% |
| powershell-tool | opus47-1m-medium | 85 | 0 | 0.0% | 0.0min | 0.0% | 1.5min | 0.2% | -1.5min | -0.2% | 18.9min | -7.9% |
| powershell-tool | opus47-1m-xhigh | 122 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.1% | -0.7min | -0.1% | 8.4min | -8.9% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m-xhigh | 159 | 86 | 54.1% | 11.5min | 1.8% | 4.8min | 0.7% | 6.7min | 1.0% | 14.7min | 45.5% |
| typescript-bun | opus47-1m-medium | 76 | 32 | 42.1% | 4.3min | 0.7% | 2.2min | 0.3% | 2.0min | 0.3% | 15.4min | 13.3% |
| bash | opus47-1m-medium | 70 | 3 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 7.6min | 5.2% |
| bash | opus47-1m-xhigh | 112 | 4 | 3.6% | 0.8min | 0.1% | 0.1min | 0.0% | 0.7min | 0.1% | 28.8min | 2.4% |
| default | opus47-1m-xhigh | 103 | 3 | 2.9% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 7.0min | 2.3% |
| default | opus47-1m-medium | 75 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 13.4min | -0.7% |
| powershell | opus47-1m-medium | 110 | 0 | 0.0% | 0.0min | 0.0% | 2.5min | 0.4% | -2.5min | -0.4% | 32.3min | -7.8% |
| powershell | opus47-1m-xhigh | 116 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.1% | -0.8min | -0.1% | 11.9min | -6.8% |
| powershell-tool | opus47-1m-medium | 85 | 0 | 0.0% | 0.0min | 0.0% | 1.5min | 0.2% | -1.5min | -0.2% | 18.9min | -7.9% |
| powershell-tool | opus47-1m-xhigh | 122 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.1% | -0.7min | -0.1% | 8.4min | -8.9% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium | 6 | 6.4min | 1.0% | $1.08 | 0.72% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh | 7 | 17.2min | 2.6% | $5.12 | 3.44% |
| repeated-test-reruns | bash | opus47-1m-medium | 1 | 1.0min | 0.2% | $0.25 | 0.17% |
| repeated-test-reruns | bash | opus47-1m-xhigh | 1 | 1.7min | 0.3% | $0.52 | 0.35% |
| repeated-test-reruns | default | opus47-1m-xhigh | 1 | 0.7min | 0.1% | $0.18 | 0.12% |
| repeated-test-reruns | powershell | opus47-1m-medium | 2 | 2.7min | 0.4% | $0.57 | 0.39% |
| repeated-test-reruns | powershell | opus47-1m-xhigh | 4 | 3.3min | 0.5% | $0.93 | 0.62% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium | 1 | 1.0min | 0.2% | $0.18 | 0.12% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh | 2 | 1.7min | 0.3% | $0.60 | 0.41% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium | 1 | 0.7min | 0.1% | $0.16 | 0.11% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh | 5 | 7.7min | 1.2% | $2.28 | 1.53% |
| fixture-rework | bash | opus47-1m-medium | 3 | 2.2min | 0.3% | $0.55 | 0.37% |
| fixture-rework | default | opus47-1m-xhigh | 3 | 1.8min | 0.3% | $0.50 | 0.34% |
| fixture-rework | powershell | opus47-1m-xhigh | 3 | 3.0min | 0.5% | $0.82 | 0.55% |
| fixture-rework | powershell-tool | opus47-1m-medium | 1 | 0.5min | 0.1% | $0.11 | 0.07% |
| fixture-rework | powershell-tool | opus47-1m-xhigh | 2 | 1.8min | 0.3% | $0.60 | 0.41% |
| fixture-rework | typescript-bun | opus47-1m-xhigh | 3 | 2.5min | 0.4% | $0.74 | 0.50% |
| mid-run-module-restructure | powershell-tool | opus47-1m-medium | 1 | 2.0min | 0.3% | $0.44 | 0.29% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh | 2 | 4.0min | 0.6% | $1.06 | 0.71% |
| docker-pwsh-install | powershell | opus47-1m-xhigh | 1 | 1.5min | 0.2% | $0.42 | 0.28% |
| act-push-debug-loops | typescript-bun | opus47-1m-xhigh | 1 | 0.8min | 0.1% | $0.24 | 0.16% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | powershell-tool | opus47-1m-medium | 1 | 0.5min | 0.1% | $0.11 | 0.07% |
| repeated-test-reruns | default | opus47-1m-xhigh | 1 | 0.7min | 0.1% | $0.18 | 0.12% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium | 1 | 0.7min | 0.1% | $0.16 | 0.11% |
| act-push-debug-loops | typescript-bun | opus47-1m-xhigh | 1 | 0.8min | 0.1% | $0.24 | 0.16% |
| repeated-test-reruns | bash | opus47-1m-medium | 1 | 1.0min | 0.2% | $0.25 | 0.17% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium | 1 | 1.0min | 0.2% | $0.18 | 0.12% |
| docker-pwsh-install | powershell | opus47-1m-xhigh | 1 | 1.5min | 0.2% | $0.42 | 0.28% |
| repeated-test-reruns | bash | opus47-1m-xhigh | 1 | 1.7min | 0.3% | $0.52 | 0.35% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh | 2 | 1.7min | 0.3% | $0.60 | 0.41% |
| fixture-rework | default | opus47-1m-xhigh | 3 | 1.8min | 0.3% | $0.50 | 0.34% |
| fixture-rework | powershell-tool | opus47-1m-xhigh | 2 | 1.8min | 0.3% | $0.60 | 0.41% |
| mid-run-module-restructure | powershell-tool | opus47-1m-medium | 1 | 2.0min | 0.3% | $0.44 | 0.29% |
| fixture-rework | bash | opus47-1m-medium | 3 | 2.2min | 0.3% | $0.55 | 0.37% |
| fixture-rework | typescript-bun | opus47-1m-xhigh | 3 | 2.5min | 0.4% | $0.74 | 0.50% |
| repeated-test-reruns | powershell | opus47-1m-medium | 2 | 2.7min | 0.4% | $0.57 | 0.39% |
| fixture-rework | powershell | opus47-1m-xhigh | 3 | 3.0min | 0.5% | $0.82 | 0.55% |
| repeated-test-reruns | powershell | opus47-1m-xhigh | 4 | 3.3min | 0.5% | $0.93 | 0.62% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh | 2 | 4.0min | 0.6% | $1.06 | 0.71% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium | 6 | 6.4min | 1.0% | $1.08 | 0.72% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh | 5 | 7.7min | 1.2% | $2.28 | 1.53% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh | 7 | 17.2min | 2.6% | $5.12 | 3.44% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | powershell-tool | opus47-1m-medium | 1 | 0.5min | 0.1% | $0.11 | 0.07% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium | 1 | 0.7min | 0.1% | $0.16 | 0.11% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium | 1 | 1.0min | 0.2% | $0.18 | 0.12% |
| repeated-test-reruns | default | opus47-1m-xhigh | 1 | 0.7min | 0.1% | $0.18 | 0.12% |
| act-push-debug-loops | typescript-bun | opus47-1m-xhigh | 1 | 0.8min | 0.1% | $0.24 | 0.16% |
| repeated-test-reruns | bash | opus47-1m-medium | 1 | 1.0min | 0.2% | $0.25 | 0.17% |
| docker-pwsh-install | powershell | opus47-1m-xhigh | 1 | 1.5min | 0.2% | $0.42 | 0.28% |
| mid-run-module-restructure | powershell-tool | opus47-1m-medium | 1 | 2.0min | 0.3% | $0.44 | 0.29% |
| fixture-rework | default | opus47-1m-xhigh | 3 | 1.8min | 0.3% | $0.50 | 0.34% |
| repeated-test-reruns | bash | opus47-1m-xhigh | 1 | 1.7min | 0.3% | $0.52 | 0.35% |
| fixture-rework | bash | opus47-1m-medium | 3 | 2.2min | 0.3% | $0.55 | 0.37% |
| repeated-test-reruns | powershell | opus47-1m-medium | 2 | 2.7min | 0.4% | $0.57 | 0.39% |
| fixture-rework | powershell-tool | opus47-1m-xhigh | 2 | 1.8min | 0.3% | $0.60 | 0.41% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh | 2 | 1.7min | 0.3% | $0.60 | 0.41% |
| fixture-rework | typescript-bun | opus47-1m-xhigh | 3 | 2.5min | 0.4% | $0.74 | 0.50% |
| fixture-rework | powershell | opus47-1m-xhigh | 3 | 3.0min | 0.5% | $0.82 | 0.55% |
| repeated-test-reruns | powershell | opus47-1m-xhigh | 4 | 3.3min | 0.5% | $0.93 | 0.62% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh | 2 | 4.0min | 0.6% | $1.06 | 0.71% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium | 6 | 6.4min | 1.0% | $1.08 | 0.72% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh | 5 | 7.7min | 1.2% | $2.28 | 1.53% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh | 7 | 17.2min | 2.6% | $5.12 | 3.44% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | bash | opus47-1m-medium | 1 | 1.0min | 0.2% | $0.25 | 0.17% |
| repeated-test-reruns | bash | opus47-1m-xhigh | 1 | 1.7min | 0.3% | $0.52 | 0.35% |
| repeated-test-reruns | default | opus47-1m-xhigh | 1 | 0.7min | 0.1% | $0.18 | 0.12% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium | 1 | 1.0min | 0.2% | $0.18 | 0.12% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium | 1 | 0.7min | 0.1% | $0.16 | 0.11% |
| fixture-rework | powershell-tool | opus47-1m-medium | 1 | 0.5min | 0.1% | $0.11 | 0.07% |
| mid-run-module-restructure | powershell-tool | opus47-1m-medium | 1 | 2.0min | 0.3% | $0.44 | 0.29% |
| docker-pwsh-install | powershell | opus47-1m-xhigh | 1 | 1.5min | 0.2% | $0.42 | 0.28% |
| act-push-debug-loops | typescript-bun | opus47-1m-xhigh | 1 | 0.8min | 0.1% | $0.24 | 0.16% |
| repeated-test-reruns | powershell | opus47-1m-medium | 2 | 2.7min | 0.4% | $0.57 | 0.39% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh | 2 | 1.7min | 0.3% | $0.60 | 0.41% |
| fixture-rework | powershell-tool | opus47-1m-xhigh | 2 | 1.8min | 0.3% | $0.60 | 0.41% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh | 2 | 4.0min | 0.6% | $1.06 | 0.71% |
| fixture-rework | bash | opus47-1m-medium | 3 | 2.2min | 0.3% | $0.55 | 0.37% |
| fixture-rework | default | opus47-1m-xhigh | 3 | 1.8min | 0.3% | $0.50 | 0.34% |
| fixture-rework | powershell | opus47-1m-xhigh | 3 | 3.0min | 0.5% | $0.82 | 0.55% |
| fixture-rework | typescript-bun | opus47-1m-xhigh | 3 | 2.5min | 0.4% | $0.74 | 0.50% |
| repeated-test-reruns | powershell | opus47-1m-xhigh | 4 | 3.3min | 0.5% | $0.93 | 0.62% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh | 5 | 7.7min | 1.2% | $2.28 | 1.53% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium | 6 | 6.4min | 1.0% | $1.08 | 0.72% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh | 7 | 17.2min | 2.6% | $5.12 | 3.44% |

</details>

#### Trap Descriptions

- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **docker-pwsh-install**: Multiple Docker test runs trying to figure out how to install PowerShell in act's container.
- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
- **mid-run-module-restructure**: Agent restructured from a flat .ps1 script to a .psm1 module mid-run.
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

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| bash | opus47-1m-medium | 7 | 4 | 3.2min | 0.5% | $0.80 | 0.54% |
| bash | opus47-1m-xhigh | 7 | 1 | 1.7min | 0.3% | $0.52 | 0.35% |
| default | opus47-1m-medium | 7 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus47-1m-xhigh | 7 | 4 | 2.4min | 0.4% | $0.68 | 0.46% |
| powershell | opus47-1m-medium | 7 | 2 | 2.7min | 0.4% | $0.57 | 0.39% |
| powershell | opus47-1m-xhigh | 7 | 8 | 7.8min | 1.2% | $2.17 | 1.46% |
| powershell-tool | opus47-1m-medium | 7 | 3 | 3.5min | 0.5% | $0.73 | 0.49% |
| powershell-tool | opus47-1m-xhigh | 7 | 6 | 7.4min | 1.1% | $2.26 | 1.52% |
| typescript-bun | opus47-1m-medium | 6 | 7 | 7.1min | 1.1% | $1.23 | 0.83% |
| typescript-bun | opus47-1m-xhigh | 7 | 16 | 28.2min | 4.3% | $8.37 | 5.63% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m-medium | 7 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | opus47-1m-xhigh | 7 | 1 | 1.7min | 0.3% | $0.52 | 0.35% |
| default | opus47-1m-xhigh | 7 | 4 | 2.4min | 0.4% | $0.68 | 0.46% |
| powershell | opus47-1m-medium | 7 | 2 | 2.7min | 0.4% | $0.57 | 0.39% |
| bash | opus47-1m-medium | 7 | 4 | 3.2min | 0.5% | $0.80 | 0.54% |
| powershell-tool | opus47-1m-medium | 7 | 3 | 3.5min | 0.5% | $0.73 | 0.49% |
| typescript-bun | opus47-1m-medium | 6 | 7 | 7.1min | 1.1% | $1.23 | 0.83% |
| powershell-tool | opus47-1m-xhigh | 7 | 6 | 7.4min | 1.1% | $2.26 | 1.52% |
| powershell | opus47-1m-xhigh | 7 | 8 | 7.8min | 1.2% | $2.17 | 1.46% |
| typescript-bun | opus47-1m-xhigh | 7 | 16 | 28.2min | 4.3% | $8.37 | 5.63% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m-medium | 7 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | opus47-1m-xhigh | 7 | 1 | 1.7min | 0.3% | $0.52 | 0.35% |
| powershell | opus47-1m-medium | 7 | 2 | 2.7min | 0.4% | $0.57 | 0.39% |
| default | opus47-1m-xhigh | 7 | 4 | 2.4min | 0.4% | $0.68 | 0.46% |
| powershell-tool | opus47-1m-medium | 7 | 3 | 3.5min | 0.5% | $0.73 | 0.49% |
| bash | opus47-1m-medium | 7 | 4 | 3.2min | 0.5% | $0.80 | 0.54% |
| typescript-bun | opus47-1m-medium | 6 | 7 | 7.1min | 1.1% | $1.23 | 0.83% |
| powershell | opus47-1m-xhigh | 7 | 8 | 7.8min | 1.2% | $2.17 | 1.46% |
| powershell-tool | opus47-1m-xhigh | 7 | 6 | 7.4min | 1.1% | $2.26 | 1.52% |
| typescript-bun | opus47-1m-xhigh | 7 | 16 | 28.2min | 4.3% | $8.37 | 5.63% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 66 | $6.33 | 4.26% |
| Miss | 3 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | opus47-1m-medium | 11.9 | 31.7 | 2.7 | 1.21 |
| bash | opus47-1m-xhigh | 25.9 | 47.3 | 1.8 | 1.26 |
| default | opus47-1m-medium | 17.0 | 33.3 | 2.0 | 1.64 |
| default | opus47-1m-xhigh | 24.0 | 50.6 | 2.1 | 1.55 |
| powershell | opus47-1m-medium | 20.0 | 38.9 | 1.9 | 3.38 |
| powershell | opus47-1m-xhigh | 28.1 | 56.7 | 2.0 | 0.99 |
| powershell-tool | opus47-1m-medium | 18.9 | 40.6 | 2.2 | 3.47 |
| powershell-tool | opus47-1m-xhigh | 29.3 | 53.7 | 1.8 | 3.37 |
| typescript-bun | opus47-1m-medium | 17.7 | 42.0 | 2.4 | 1.53 |
| typescript-bun | opus47-1m-xhigh | 30.7 | 65.6 | 2.1 | 1.73 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m-xhigh | 30.7 | 65.6 | 2.1 | 1.73 |
| powershell-tool | opus47-1m-xhigh | 29.3 | 53.7 | 1.8 | 3.37 |
| powershell | opus47-1m-xhigh | 28.1 | 56.7 | 2.0 | 0.99 |
| bash | opus47-1m-xhigh | 25.9 | 47.3 | 1.8 | 1.26 |
| default | opus47-1m-xhigh | 24.0 | 50.6 | 2.1 | 1.55 |
| powershell | opus47-1m-medium | 20.0 | 38.9 | 1.9 | 3.38 |
| powershell-tool | opus47-1m-medium | 18.9 | 40.6 | 2.2 | 3.47 |
| typescript-bun | opus47-1m-medium | 17.7 | 42.0 | 2.4 | 1.53 |
| default | opus47-1m-medium | 17.0 | 33.3 | 2.0 | 1.64 |
| bash | opus47-1m-medium | 11.9 | 31.7 | 2.7 | 1.21 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m-xhigh | 30.7 | 65.6 | 2.1 | 1.73 |
| powershell | opus47-1m-xhigh | 28.1 | 56.7 | 2.0 | 0.99 |
| powershell-tool | opus47-1m-xhigh | 29.3 | 53.7 | 1.8 | 3.37 |
| default | opus47-1m-xhigh | 24.0 | 50.6 | 2.1 | 1.55 |
| bash | opus47-1m-xhigh | 25.9 | 47.3 | 1.8 | 1.26 |
| typescript-bun | opus47-1m-medium | 17.7 | 42.0 | 2.4 | 1.53 |
| powershell-tool | opus47-1m-medium | 18.9 | 40.6 | 2.2 | 3.47 |
| powershell | opus47-1m-medium | 20.0 | 38.9 | 1.9 | 3.38 |
| default | opus47-1m-medium | 17.0 | 33.3 | 2.0 | 1.64 |
| bash | opus47-1m-medium | 11.9 | 31.7 | 2.7 | 1.21 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Mode | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-tool | opus47-1m-medium | 18.9 | 40.6 | 2.2 | 3.47 |
| powershell | opus47-1m-medium | 20.0 | 38.9 | 1.9 | 3.38 |
| powershell-tool | opus47-1m-xhigh | 29.3 | 53.7 | 1.8 | 3.37 |
| typescript-bun | opus47-1m-xhigh | 30.7 | 65.6 | 2.1 | 1.73 |
| default | opus47-1m-medium | 17.0 | 33.3 | 2.0 | 1.64 |
| default | opus47-1m-xhigh | 24.0 | 50.6 | 2.1 | 1.55 |
| typescript-bun | opus47-1m-medium | 17.7 | 42.0 | 2.4 | 1.53 |
| bash | opus47-1m-xhigh | 25.9 | 47.3 | 1.8 | 1.26 |
| bash | opus47-1m-medium | 11.9 | 31.7 | 2.7 | 1.21 |
| powershell | opus47-1m-xhigh | 28.1 | 56.7 | 2.0 | 0.99 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Mode | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | bash | opus47-1m-xhigh | 35 | 67 | 1.9 | 374 | 298 | 1.26 |
| Semantic Version Bumper | default | opus47-1m-xhigh | 30 | 70 | 2.3 | 505 | 280 | 1.80 |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 27 | 46 | 1.7 | 261 | 248 | 1.05 |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 33 | 54 | 1.6 | 396 | 42 | 9.43 |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 45 | 95 | 2.1 | 805 | 504 | 1.60 |
| PR Label Assigner | bash | opus47-1m-xhigh | 28 | 43 | 1.5 | 303 | 360 | 0.84 |
| PR Label Assigner | default | opus47-1m-xhigh | 27 | 43 | 1.6 | 431 | 224 | 1.92 |
| PR Label Assigner | powershell | opus47-1m-xhigh | 39 | 47 | 1.2 | 319 | 386 | 0.83 |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 31 | 62 | 2.0 | 324 | 202 | 1.60 |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 32 | 51 | 1.6 | 620 | 263 | 2.36 |
| Dependency License Checker | bash | opus47-1m-xhigh | 14 | 14 | 1.0 | 152 | 171 | 0.89 |
| Dependency License Checker | default | opus47-1m-xhigh | 24 | 36 | 1.5 | 284 | 578 | 0.49 |
| Dependency License Checker | powershell | opus47-1m-xhigh | 22 | 79 | 3.6 | 456 | 277 | 1.65 |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 19 | 32 | 1.7 | 223 | 440 | 0.51 |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 29 | 50 | 1.7 | 402 | 559 | 0.72 |
| Test Results Aggregator | bash | opus47-1m-xhigh | 37 | 95 | 2.6 | 385 | 101 | 3.81 |
| Test Results Aggregator | default | opus47-1m-xhigh | 30 | 70 | 2.3 | 543 | 334 | 1.63 |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 27 | 73 | 2.7 | 343 | 372 | 0.92 |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 37 | 65 | 1.8 | 337 | 265 | 1.27 |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 33 | 88 | 2.7 | 658 | 481 | 1.37 |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 27 | 30 | 1.1 | 186 | 304 | 0.61 |
| Environment Matrix Generator | default | opus47-1m-xhigh | 23 | 35 | 1.5 | 283 | 202 | 1.40 |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 39 | 54 | 1.4 | 334 | 411 | 0.81 |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 42 | 59 | 1.4 | 294 | 437 | 0.67 |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 31 | 59 | 1.9 | 622 | 305 | 2.04 |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 15 | 63 | 4.2 | 183 | 398 | 0.46 |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 18 | 39 | 2.2 | 525 | 321 | 1.64 |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 19 | 44 | 2.3 | 267 | 374 | 0.71 |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 17 | 35 | 2.1 | 205 | 373 | 0.55 |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 18 | 40 | 2.2 | 459 | 271 | 1.69 |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 25 | 19 | 0.8 | 258 | 280 | 0.92 |
| Secret Rotation Validator | default | opus47-1m-xhigh | 16 | 61 | 3.8 | 645 | 330 | 1.95 |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 24 | 54 | 2.2 | 315 | 326 | 0.97 |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 26 | 69 | 2.7 | 468 | 49 | 9.55 |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 27 | 76 | 2.8 | 820 | 354 | 2.32 |
| Semantic Version Bumper | default | opus47-1m-medium | 22 | 39 | 1.8 | 319 | 180 | 1.77 |
| Semantic Version Bumper | powershell | opus47-1m-medium | 36 | 66 | 1.8 | 315 | 54 | 5.83 |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 31 | 56 | 1.8 | 243 | 22 | 11.05 |
| Semantic Version Bumper | bash | opus47-1m-medium | 6 | 7 | 1.2 | 96 | 152 | 0.63 |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 23 | 49 | 2.1 | 279 | 248 | 1.12 |
| PR Label Assigner | default | opus47-1m-medium | 0 | 9 | 0.0 | 194 | 132 | 1.47 |
| PR Label Assigner | powershell | opus47-1m-medium | 22 | 23 | 1.0 | 153 | 229 | 0.67 |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 27 | 49 | 1.8 | 315 | 39 | 8.08 |
| PR Label Assigner | bash | opus47-1m-medium | 16 | 31 | 1.9 | 201 | 136 | 1.48 |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 16 | 35 | 2.2 | 271 | 138 | 1.96 |
| Dependency License Checker | default | opus47-1m-medium | 21 | 35 | 1.7 | 400 | 166 | 2.41 |
| Dependency License Checker | powershell | opus47-1m-medium | 11 | 24 | 2.2 | 127 | 208 | 0.61 |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 11 | 23 | 2.1 | 116 | 250 | 0.46 |
| Dependency License Checker | bash | opus47-1m-medium | 10 | 43 | 4.3 | 169 | 174 | 0.97 |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 16 | 32 | 2.0 | 343 | 166 | 2.07 |
| Test Results Aggregator | default | opus47-1m-medium | 19 | 43 | 2.3 | 353 | 185 | 1.91 |
| Test Results Aggregator | powershell | opus47-1m-medium | 17 | 46 | 2.7 | 294 | 21 | 14.00 |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 20 | 45 | 2.2 | 202 | 179 | 1.13 |
| Test Results Aggregator | bash | opus47-1m-medium | 11 | 46 | 4.2 | 237 | 189 | 1.25 |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 17 | 42 | 2.5 | 379 | 244 | 1.55 |
| Environment Matrix Generator | default | opus47-1m-medium | 20 | 27 | 1.4 | 281 | 337 | 0.83 |
| Environment Matrix Generator | powershell | opus47-1m-medium | 24 | 49 | 2.0 | 252 | 267 | 0.94 |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 11 | 18 | 1.6 | 129 | 150 | 0.86 |
| Environment Matrix Generator | bash | opus47-1m-medium | 19 | 38 | 2.0 | 221 | 90 | 2.46 |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 13 | 38 | 2.9 | 238 | 145 | 1.64 |
| Artifact Cleanup Script | default | opus47-1m-medium | 16 | 37 | 2.3 | 293 | 196 | 1.49 |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 9 | 18 | 2.0 | 133 | 166 | 0.80 |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 8 | 25 | 3.1 | 135 | 186 | 0.73 |
| Artifact Cleanup Script | bash | opus47-1m-medium | 16 | 36 | 2.2 | 223 | 199 | 1.12 |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 21 | 56 | 2.7 | 271 | 334 | 0.81 |
| Secret Rotation Validator | default | opus47-1m-medium | 21 | 43 | 2.0 | 397 | 244 | 1.63 |
| Secret Rotation Validator | powershell | opus47-1m-medium | 21 | 46 | 2.2 | 184 | 225 | 0.82 |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 24 | 68 | 2.8 | 310 | 159 | 1.95 |
| Secret Rotation Validator | bash | opus47-1m-medium | 5 | 21 | 4.2 | 120 | 209 | 0.57 |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | bash | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | python | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | bash | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | python | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | bash | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | python | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | typescript | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | bash | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | typescript | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | typescript | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | bash | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | typescript | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | typescript | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | python | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | powershell | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | bash | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | typescript | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | python | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | powershell | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | bash | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | typescript | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | python | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | typescript | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | typescript | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | powershell | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | typescript | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | powershell | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | bash | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | python | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | python | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | bash | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | python | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | bash | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | typescript | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | powershell | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | bash | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | typescript | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | powershell | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | python | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | typescript | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | bash | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | typescript | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | bash | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | powershell | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | python | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | python | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | bash | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | typescript | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | python | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | bash | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | typescript | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | python | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | typescript | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | typescript | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | python | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | python | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | bash | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | bash | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | python | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | bash | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | typescript | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | bash | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | bash | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | python | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | python | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | python | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | python | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | python | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | typescript | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | powershell | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | python | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | bash | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | typescript | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | python | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | typescript | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | typescript | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | python | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | python | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | typescript | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | bash | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | typescript | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | powershell | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | bash | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | python | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | typescript | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | typescript | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | bash | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | python | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | typescript | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | python | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | typescript | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | powershell | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | python | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | typescript | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | typescript | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | typescript | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | powershell | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | bash | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | python | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | typescript | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | typescript | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | powershell | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | bash | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | bash | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | typescript | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | bash | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | bash | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | bash | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | python | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | powershell | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | python | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | powershell | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | python | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | bash | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | bash | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | bash | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | python | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | bash | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | typescript | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | bash | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | typescript | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | python | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | bash | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | python | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | python | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | bash | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | typescript | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | powershell | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | bash | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | powershell | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | python | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | python | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | python | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | bash | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | bash | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | typescript | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | typescript | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | powershell | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | typescript | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | typescript | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*