# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 12:15:25 PM ET

**Status:** 64/64 runs completed, 0 remaining
**Total cost so far:** $84.25
**Total agent time so far:** 726.1 min

## Observations

- **Fastest (avg):** default/opus — 7.0min, then bash/opus — 8.7min
- **Slowest (avg):** powershell/sonnet — 21.0min, then default/sonnet — 14.6min
- **Cheapest (avg):** bash/sonnet — $1.06, then powershell/opus — $1.20
- **Most expensive (avg):** powershell/sonnet — $1.67, then default/sonnet — $1.38

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | opus | 8 | 8.7min | 1796 | 1.8 | 39 | $1.37 | $10.93 |
| bash | sonnet | 8 | 10.2min | 1212 | 4.1 | 38 | $1.06 | $8.45 |
| default | opus | 8 | 7.0min | 1318 | 1.2 | 36 | $1.29 | $10.31 |
| default | sonnet | 8 | 14.6min | 2070 | 1.1 | 32 | $1.38 | $11.06 |
| powershell | opus | 8 | 9.1min | 1317 | 1.2 | 34 | $1.20 | $9.62 |
| powershell | sonnet | 8 | 21.0min | 1527 | 0.5 | 42 | $1.67 | $13.37 |
| typescript-bun | opus | 8 | 8.9min | 1191 | 1.5 | 39 | $1.35 | $10.78 |
| typescript-bun | sonnet | 8 | 11.3min | 2124 | 2.2 | 33 | $1.22 | $9.74 |


<details>
<summary>Sorted by avg cost (most expensive first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | sonnet | 8 | 21.0min | 1527 | 0.5 | 42 | $1.67 | $13.37 |
| default | sonnet | 8 | 14.6min | 2070 | 1.1 | 32 | $1.38 | $11.06 |
| bash | opus | 8 | 8.7min | 1796 | 1.8 | 39 | $1.37 | $10.93 |
| typescript-bun | opus | 8 | 8.9min | 1191 | 1.5 | 39 | $1.35 | $10.78 |
| default | opus | 8 | 7.0min | 1318 | 1.2 | 36 | $1.29 | $10.31 |
| typescript-bun | sonnet | 8 | 11.3min | 2124 | 2.2 | 33 | $1.22 | $9.74 |
| powershell | opus | 8 | 9.1min | 1317 | 1.2 | 34 | $1.20 | $9.62 |
| bash | sonnet | 8 | 10.2min | 1212 | 4.1 | 38 | $1.06 | $8.45 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | sonnet | 8 | 21.0min | 1527 | 0.5 | 42 | $1.67 | $13.37 |
| default | sonnet | 8 | 14.6min | 2070 | 1.1 | 32 | $1.38 | $11.06 |
| default | opus | 8 | 7.0min | 1318 | 1.2 | 36 | $1.29 | $10.31 |
| powershell | opus | 8 | 9.1min | 1317 | 1.2 | 34 | $1.20 | $9.62 |
| typescript-bun | opus | 8 | 8.9min | 1191 | 1.5 | 39 | $1.35 | $10.78 |
| bash | opus | 8 | 8.7min | 1796 | 1.8 | 39 | $1.37 | $10.93 |
| typescript-bun | sonnet | 8 | 11.3min | 2124 | 2.2 | 33 | $1.22 | $9.74 |
| bash | sonnet | 8 | 10.2min | 1212 | 4.1 | 38 | $1.06 | $8.45 |

</details>

<details>
<summary>Sorted by avg lines (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| typescript-bun | opus | 8 | 8.9min | 1191 | 1.5 | 39 | $1.35 | $10.78 |
| bash | sonnet | 8 | 10.2min | 1212 | 4.1 | 38 | $1.06 | $8.45 |
| powershell | opus | 8 | 9.1min | 1317 | 1.2 | 34 | $1.20 | $9.62 |
| default | opus | 8 | 7.0min | 1318 | 1.2 | 36 | $1.29 | $10.31 |
| powershell | sonnet | 8 | 21.0min | 1527 | 0.5 | 42 | $1.67 | $13.37 |
| bash | opus | 8 | 8.7min | 1796 | 1.8 | 39 | $1.37 | $10.93 |
| default | sonnet | 8 | 14.6min | 2070 | 1.1 | 32 | $1.38 | $11.06 |
| typescript-bun | sonnet | 8 | 11.3min | 2124 | 2.2 | 33 | $1.22 | $9.74 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | sonnet | 8 | 14.6min | 2070 | 1.1 | 32 | $1.38 | $11.06 |
| typescript-bun | sonnet | 8 | 11.3min | 2124 | 2.2 | 33 | $1.22 | $9.74 |
| powershell | opus | 8 | 9.1min | 1317 | 1.2 | 34 | $1.20 | $9.62 |
| default | opus | 8 | 7.0min | 1318 | 1.2 | 36 | $1.29 | $10.31 |
| bash | sonnet | 8 | 10.2min | 1212 | 4.1 | 38 | $1.06 | $8.45 |
| bash | opus | 8 | 8.7min | 1796 | 1.8 | 39 | $1.37 | $10.93 |
| typescript-bun | opus | 8 | 8.9min | 1191 | 1.5 | 39 | $1.35 | $10.78 |
| powershell | sonnet | 8 | 21.0min | 1527 | 0.5 | 42 | $1.67 | $13.37 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 93 | 5 | 5.4% | 1.0min | 0.1% | 0.9min | 0.1% | 0.1min | 0.0% | 16.6min | 0.7% |
| bash | sonnet | 98 | 14 | 14.3% | 2.8min | 0.4% | 0.9min | 0.1% | 1.9min | 0.3% | 3.5min | 53.7% |
| default | opus | 90 | 5 | 5.6% | 0.7min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% | 7.3min | -0.8% |
| default | sonnet | 81 | 4 | 4.9% | 0.5min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% | 3.2min | -3.6% |
| powershell | opus | 68 | 2 | 2.9% | 1.2min | 0.2% | 2.1min | 0.3% | -0.9min | -0.1% | 20.4min | -4.5% |
| powershell | sonnet | 82 | 1 | 1.2% | 0.6min | 0.1% | 2.5min | 0.3% | -1.9min | -0.3% | 34.6min | -5.6% |
| typescript-bun | opus | 94 | 50 | 53.2% | 6.7min | 0.9% | 4.2min | 0.6% | 2.4min | 0.3% | 11.4min | 21.4% |
| typescript-bun | sonnet | 99 | 46 | 46.5% | 6.1min | 0.8% | 4.4min | 0.6% | 1.7min | 0.2% | 10.1min | 16.7% |
| **Total** | | **705** | **127** | **18.0%** | **19.6min** | **2.7%** | **16.5min** | **2.3%** | **3.1min** | **0.4%** | **107.0min** | **2.9%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 94 | 50 | 53.2% | 6.7min | 0.9% | 4.2min | 0.6% | 2.4min | 0.3% | 11.4min | 21.4% |
| bash | sonnet | 98 | 14 | 14.3% | 2.8min | 0.4% | 0.9min | 0.1% | 1.9min | 0.3% | 3.5min | 53.7% |
| typescript-bun | sonnet | 99 | 46 | 46.5% | 6.1min | 0.8% | 4.4min | 0.6% | 1.7min | 0.2% | 10.1min | 16.7% |
| bash | opus | 93 | 5 | 5.4% | 1.0min | 0.1% | 0.9min | 0.1% | 0.1min | 0.0% | 16.6min | 0.7% |
| default | opus | 90 | 5 | 5.6% | 0.7min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% | 7.3min | -0.8% |
| default | sonnet | 81 | 4 | 4.9% | 0.5min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% | 3.2min | -3.6% |
| powershell | opus | 68 | 2 | 2.9% | 1.2min | 0.2% | 2.1min | 0.3% | -0.9min | -0.1% | 20.4min | -4.5% |
| powershell | sonnet | 82 | 1 | 1.2% | 0.6min | 0.1% | 2.5min | 0.3% | -1.9min | -0.3% | 34.6min | -5.6% |

</details>

<details>
<summary>Sorted by net % of test time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | sonnet | 98 | 14 | 14.3% | 2.8min | 0.4% | 0.9min | 0.1% | 1.9min | 0.3% | 3.5min | 53.7% |
| typescript-bun | opus | 94 | 50 | 53.2% | 6.7min | 0.9% | 4.2min | 0.6% | 2.4min | 0.3% | 11.4min | 21.4% |
| typescript-bun | sonnet | 99 | 46 | 46.5% | 6.1min | 0.8% | 4.4min | 0.6% | 1.7min | 0.2% | 10.1min | 16.7% |
| bash | opus | 93 | 5 | 5.4% | 1.0min | 0.1% | 0.9min | 0.1% | 0.1min | 0.0% | 16.6min | 0.7% |
| default | opus | 90 | 5 | 5.6% | 0.7min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% | 7.3min | -0.8% |
| default | sonnet | 81 | 4 | 4.9% | 0.5min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% | 3.2min | -3.6% |
| powershell | opus | 68 | 2 | 2.9% | 1.2min | 0.2% | 2.1min | 0.3% | -0.9min | -0.1% | 20.4min | -4.5% |
| powershell | sonnet | 82 | 1 | 1.2% | 0.6min | 0.1% | 2.5min | 0.3% | -1.9min | -0.3% | 34.6min | -5.6% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 94 | 50 | 53.2% | 6.7min | 0.9% | 4.2min | 0.6% | 2.4min | 0.3% | 11.4min | 21.4% |
| typescript-bun | sonnet | 99 | 46 | 46.5% | 6.1min | 0.8% | 4.4min | 0.6% | 1.7min | 0.2% | 10.1min | 16.7% |
| bash | sonnet | 98 | 14 | 14.3% | 2.8min | 0.4% | 0.9min | 0.1% | 1.9min | 0.3% | 3.5min | 53.7% |
| default | opus | 90 | 5 | 5.6% | 0.7min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% | 7.3min | -0.8% |
| bash | opus | 93 | 5 | 5.4% | 1.0min | 0.1% | 0.9min | 0.1% | 0.1min | 0.0% | 16.6min | 0.7% |
| default | sonnet | 81 | 4 | 4.9% | 0.5min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% | 3.2min | -3.6% |
| powershell | opus | 68 | 2 | 2.9% | 1.2min | 0.2% | 2.1min | 0.3% | -0.9min | -0.1% | 20.4min | -4.5% |
| powershell | sonnet | 82 | 1 | 1.2% | 0.6min | 0.1% | 2.5min | 0.3% | -1.9min | -0.3% | 34.6min | -5.6% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | default | sonnet | 3 | 4.7min | 0.7% | $0.50 | 0.60% |
| act-push-debug-loops | powershell | opus | 1 | 0.8min | 0.1% | $0.13 | 0.16% |
| act-push-debug-loops | powershell | sonnet | 3 | 15.7min | 2.2% | $0.93 | 1.10% |
| act-push-debug-loops | typescript-bun | sonnet | 2 | 2.8min | 0.4% | $0.29 | 0.35% |
| ts-type-error-fix-cycles | typescript-bun | opus | 8 | 10.0min | 1.4% | $1.64 | 1.94% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 8 | 9.2min | 1.3% | $1.07 | 1.26% |
| fixture-rework | bash | opus | 4 | 5.2min | 0.7% | $0.95 | 1.13% |
| fixture-rework | bash | sonnet | 3 | 3.5min | 0.5% | $0.37 | 0.44% |
| fixture-rework | default | opus | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| fixture-rework | default | sonnet | 2 | 1.8min | 0.2% | $0.18 | 0.22% |
| fixture-rework | powershell | opus | 1 | 2.8min | 0.4% | $0.41 | 0.48% |
| fixture-rework | typescript-bun | opus | 3 | 3.0min | 0.4% | $0.62 | 0.74% |
| repeated-test-reruns | bash | sonnet | 2 | 1.7min | 0.2% | $0.19 | 0.23% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.1% | $0.06 | 0.07% |
| repeated-test-reruns | powershell | opus | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | powershell | sonnet | 5 | 5.0min | 0.7% | $0.38 | 0.45% |
| repeated-test-reruns | typescript-bun | opus | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | typescript-bun | sonnet | 2 | 2.7min | 0.4% | $0.31 | 0.36% |
| docker-pwsh-install | powershell | opus | 1 | 3.0min | 0.4% | $0.42 | 0.50% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 0.6% | $0.40 | 0.47% |
| act-permission-path-errors | bash | opus | 1 | 0.8min | 0.1% | $0.16 | 0.19% |
| act-permission-path-errors | bash | sonnet | 3 | 2.8min | 0.4% | $0.33 | 0.39% |
| act-permission-path-errors | powershell | opus | 1 | 0.8min | 0.1% | $0.10 | 0.12% |
| docker-pkg-install | default | sonnet | 1 | 1.5min | 0.2% | $0.17 | 0.20% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.1% | $0.09 | 0.11% |
| actionlint-fix-cycles | powershell | sonnet | 1 | 0.7min | 0.1% | $0.07 | 0.08% |
| **Total** | | | **44 runs** | **87.0min** | **12.0%** | **$10.31** | **12.24%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.1% | $0.06 | 0.07% |
| repeated-test-reruns | powershell | opus | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | typescript-bun | opus | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.1% | $0.09 | 0.11% |
| actionlint-fix-cycles | powershell | sonnet | 1 | 0.7min | 0.1% | $0.07 | 0.08% |
| act-permission-path-errors | bash | opus | 1 | 0.8min | 0.1% | $0.16 | 0.19% |
| act-permission-path-errors | powershell | opus | 1 | 0.8min | 0.1% | $0.10 | 0.12% |
| act-push-debug-loops | powershell | opus | 1 | 0.8min | 0.1% | $0.13 | 0.16% |
| fixture-rework | default | opus | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| docker-pkg-install | default | sonnet | 1 | 1.5min | 0.2% | $0.17 | 0.20% |
| repeated-test-reruns | bash | sonnet | 2 | 1.7min | 0.2% | $0.19 | 0.23% |
| fixture-rework | default | sonnet | 2 | 1.8min | 0.2% | $0.18 | 0.22% |
| repeated-test-reruns | typescript-bun | sonnet | 2 | 2.7min | 0.4% | $0.31 | 0.36% |
| fixture-rework | powershell | opus | 1 | 2.8min | 0.4% | $0.41 | 0.48% |
| act-permission-path-errors | bash | sonnet | 3 | 2.8min | 0.4% | $0.33 | 0.39% |
| act-push-debug-loops | typescript-bun | sonnet | 2 | 2.8min | 0.4% | $0.29 | 0.35% |
| fixture-rework | typescript-bun | opus | 3 | 3.0min | 0.4% | $0.62 | 0.74% |
| docker-pwsh-install | powershell | opus | 1 | 3.0min | 0.4% | $0.42 | 0.50% |
| fixture-rework | bash | sonnet | 3 | 3.5min | 0.5% | $0.37 | 0.44% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 0.6% | $0.40 | 0.47% |
| act-push-debug-loops | default | sonnet | 3 | 4.7min | 0.7% | $0.50 | 0.60% |
| repeated-test-reruns | powershell | sonnet | 5 | 5.0min | 0.7% | $0.38 | 0.45% |
| fixture-rework | bash | opus | 4 | 5.2min | 0.7% | $0.95 | 1.13% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 8 | 9.2min | 1.3% | $1.07 | 1.26% |
| ts-type-error-fix-cycles | typescript-bun | opus | 8 | 10.0min | 1.4% | $1.64 | 1.94% |
| act-push-debug-loops | powershell | sonnet | 3 | 15.7min | 2.2% | $0.93 | 1.10% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.1% | $0.06 | 0.07% |
| actionlint-fix-cycles | powershell | sonnet | 1 | 0.7min | 0.1% | $0.07 | 0.08% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.1% | $0.09 | 0.11% |
| act-permission-path-errors | powershell | opus | 1 | 0.8min | 0.1% | $0.10 | 0.12% |
| repeated-test-reruns | typescript-bun | opus | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | powershell | opus | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| act-push-debug-loops | powershell | opus | 1 | 0.8min | 0.1% | $0.13 | 0.16% |
| act-permission-path-errors | bash | opus | 1 | 0.8min | 0.1% | $0.16 | 0.19% |
| docker-pkg-install | default | sonnet | 1 | 1.5min | 0.2% | $0.17 | 0.20% |
| fixture-rework | default | sonnet | 2 | 1.8min | 0.2% | $0.18 | 0.22% |
| repeated-test-reruns | bash | sonnet | 2 | 1.7min | 0.2% | $0.19 | 0.23% |
| act-push-debug-loops | typescript-bun | sonnet | 2 | 2.8min | 0.4% | $0.29 | 0.35% |
| fixture-rework | default | opus | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| repeated-test-reruns | typescript-bun | sonnet | 2 | 2.7min | 0.4% | $0.31 | 0.36% |
| act-permission-path-errors | bash | sonnet | 3 | 2.8min | 0.4% | $0.33 | 0.39% |
| fixture-rework | bash | sonnet | 3 | 3.5min | 0.5% | $0.37 | 0.44% |
| repeated-test-reruns | powershell | sonnet | 5 | 5.0min | 0.7% | $0.38 | 0.45% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 0.6% | $0.40 | 0.47% |
| fixture-rework | powershell | opus | 1 | 2.8min | 0.4% | $0.41 | 0.48% |
| docker-pwsh-install | powershell | opus | 1 | 3.0min | 0.4% | $0.42 | 0.50% |
| act-push-debug-loops | default | sonnet | 3 | 4.7min | 0.7% | $0.50 | 0.60% |
| fixture-rework | typescript-bun | opus | 3 | 3.0min | 0.4% | $0.62 | 0.74% |
| act-push-debug-loops | powershell | sonnet | 3 | 15.7min | 2.2% | $0.93 | 1.10% |
| fixture-rework | bash | opus | 4 | 5.2min | 0.7% | $0.95 | 1.13% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 8 | 9.2min | 1.3% | $1.07 | 1.26% |
| ts-type-error-fix-cycles | typescript-bun | opus | 8 | 10.0min | 1.4% | $1.64 | 1.94% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | powershell | opus | 1 | 0.8min | 0.1% | $0.13 | 0.16% |
| fixture-rework | powershell | opus | 1 | 2.8min | 0.4% | $0.41 | 0.48% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.1% | $0.06 | 0.07% |
| repeated-test-reruns | powershell | opus | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | typescript-bun | opus | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| docker-pwsh-install | powershell | opus | 1 | 3.0min | 0.4% | $0.42 | 0.50% |
| act-permission-path-errors | bash | opus | 1 | 0.8min | 0.1% | $0.16 | 0.19% |
| act-permission-path-errors | powershell | opus | 1 | 0.8min | 0.1% | $0.10 | 0.12% |
| docker-pkg-install | default | sonnet | 1 | 1.5min | 0.2% | $0.17 | 0.20% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.1% | $0.09 | 0.11% |
| actionlint-fix-cycles | powershell | sonnet | 1 | 0.7min | 0.1% | $0.07 | 0.08% |
| act-push-debug-loops | typescript-bun | sonnet | 2 | 2.8min | 0.4% | $0.29 | 0.35% |
| fixture-rework | default | opus | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| fixture-rework | default | sonnet | 2 | 1.8min | 0.2% | $0.18 | 0.22% |
| repeated-test-reruns | bash | sonnet | 2 | 1.7min | 0.2% | $0.19 | 0.23% |
| repeated-test-reruns | typescript-bun | sonnet | 2 | 2.7min | 0.4% | $0.31 | 0.36% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 0.6% | $0.40 | 0.47% |
| act-push-debug-loops | default | sonnet | 3 | 4.7min | 0.7% | $0.50 | 0.60% |
| act-push-debug-loops | powershell | sonnet | 3 | 15.7min | 2.2% | $0.93 | 1.10% |
| fixture-rework | bash | sonnet | 3 | 3.5min | 0.5% | $0.37 | 0.44% |
| fixture-rework | typescript-bun | opus | 3 | 3.0min | 0.4% | $0.62 | 0.74% |
| act-permission-path-errors | bash | sonnet | 3 | 2.8min | 0.4% | $0.33 | 0.39% |
| fixture-rework | bash | opus | 4 | 5.2min | 0.7% | $0.95 | 1.13% |
| repeated-test-reruns | powershell | sonnet | 5 | 5.0min | 0.7% | $0.38 | 0.45% |
| ts-type-error-fix-cycles | typescript-bun | opus | 8 | 10.0min | 1.4% | $1.64 | 1.94% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 8 | 9.2min | 1.3% | $1.07 | 1.26% |

</details>

#### Trap Descriptions

- **act-permission-path-errors**: Files not found or permission denied inside the act Docker container.
- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **actionlint-fix-cycles**: Workflow YAML required 3+ actionlint runs and 2+ fixes to pass.
- **docker-pkg-install**: Multiple Docker test runs exploring non-PowerShell package installation for act.
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
| bash | opus | 8 | 6 | 75% | 6 | 6.7min | 0.9% | $1.21 | 1.43% |
| bash | sonnet | 8 | 5 | 62% | 8 | 7.9min | 1.1% | $0.89 | 1.06% |
| default | opus | 8 | 2 | 25% | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| default | sonnet | 8 | 4 | 50% | 7 | 8.7min | 1.2% | $0.92 | 1.09% |
| powershell | opus | 8 | 4 | 50% | 5 | 8.0min | 1.1% | $1.18 | 1.40% |
| powershell | sonnet | 8 | 7 | 88% | 11 | 25.9min | 3.6% | $1.78 | 2.12% |
| typescript-bun | opus | 8 | 8 | 100% | 12 | 13.7min | 1.9% | $2.37 | 2.81% |
| typescript-bun | sonnet | 8 | 8 | 100% | 12 | 14.7min | 2.0% | $1.67 | 1.98% |
| **Total** | | **64** | **44** | **69%** | **63** | **87.0min** | **12.0%** | **$10.31** | **12.24%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 8 | 2 | 25% | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| bash | opus | 8 | 6 | 75% | 6 | 6.7min | 0.9% | $1.21 | 1.43% |
| bash | sonnet | 8 | 5 | 62% | 8 | 7.9min | 1.1% | $0.89 | 1.06% |
| powershell | opus | 8 | 4 | 50% | 5 | 8.0min | 1.1% | $1.18 | 1.40% |
| default | sonnet | 8 | 4 | 50% | 7 | 8.7min | 1.2% | $0.92 | 1.09% |
| typescript-bun | opus | 8 | 8 | 100% | 12 | 13.7min | 1.9% | $2.37 | 2.81% |
| typescript-bun | sonnet | 8 | 8 | 100% | 12 | 14.7min | 2.0% | $1.67 | 1.98% |
| powershell | sonnet | 8 | 7 | 88% | 11 | 25.9min | 3.6% | $1.78 | 2.12% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 8 | 2 | 25% | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| bash | sonnet | 8 | 5 | 62% | 8 | 7.9min | 1.1% | $0.89 | 1.06% |
| default | sonnet | 8 | 4 | 50% | 7 | 8.7min | 1.2% | $0.92 | 1.09% |
| powershell | opus | 8 | 4 | 50% | 5 | 8.0min | 1.1% | $1.18 | 1.40% |
| bash | opus | 8 | 6 | 75% | 6 | 6.7min | 0.9% | $1.21 | 1.43% |
| typescript-bun | sonnet | 8 | 8 | 100% | 12 | 14.7min | 2.0% | $1.67 | 1.98% |
| powershell | sonnet | 8 | 7 | 88% | 11 | 25.9min | 3.6% | $1.78 | 2.12% |
| typescript-bun | opus | 8 | 8 | 100% | 12 | 13.7min | 1.9% | $2.37 | 2.81% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 8 | 2 | 25% | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| default | sonnet | 8 | 4 | 50% | 7 | 8.7min | 1.2% | $0.92 | 1.09% |
| powershell | opus | 8 | 4 | 50% | 5 | 8.0min | 1.1% | $1.18 | 1.40% |
| bash | sonnet | 8 | 5 | 62% | 8 | 7.9min | 1.1% | $0.89 | 1.06% |
| bash | opus | 8 | 6 | 75% | 6 | 6.7min | 0.9% | $1.21 | 1.43% |
| powershell | sonnet | 8 | 7 | 88% | 11 | 25.9min | 3.6% | $1.78 | 2.12% |
| typescript-bun | opus | 8 | 8 | 100% | 12 | 13.7min | 1.9% | $2.37 | 2.81% |
| typescript-bun | sonnet | 8 | 8 | 100% | 12 | 14.7min | 2.0% | $1.67 | 1.98% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 1 | $0.06 | 0.07% |
| Partial | 62 | $7.30 | 8.67% |
| Miss | 1 | $0.00 | 0.00% |
| **Total** | **64** | **$7.36** | **8.74%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 6.8min | 46 | 831 | 2 | $1.45 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 4.9min | 30 | 1074 | 2 | $0.68 | bash | ok |
| Semantic Version Bumper | default | opus | 9.0min | 29 | 1115 | 0 | $1.27 | python | ok |
| Semantic Version Bumper | default | sonnet | 17.2min | 38 | 1595 | 1 | $1.62 | python | ok |
| Semantic Version Bumper | powershell | opus | 9.2min | 31 | 1665 | 0 | $0.82 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 27.2min | 42 | 1714 | 0 | $1.44 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 13.2min | 35 | 987 | 0 | $1.89 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 28 | 2296 | 0 | $0.72 | typescript | ok |
| PR Label Assigner | bash | opus | 6.5min | 42 | 929 | 2 | $1.22 | bash | ok |
| PR Label Assigner | bash | sonnet | 6.8min | 39 | 921 | 5 | $0.90 | bash | ok |
| PR Label Assigner | default | opus | 4.6min | 23 | 1111 | 0 | $0.69 | python | ok |
| PR Label Assigner | default | sonnet | 16.5min | 23 | 2264 | 1 | $1.25 | python | ok |
| PR Label Assigner | powershell | opus | 8.1min | 32 | 949 | 2 | $1.12 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 27.1min | 50 | 1157 | 3 | $2.51 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 9.1min | 31 | 1228 | 1 | $0.96 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet | 13.7min | 46 | 2944 | 6 | $1.35 | typescript | ok |
| Dependency License Checker | bash | opus | 5.4min | 40 | 1060 | 1 | $1.12 | bash | ok |
| Dependency License Checker | bash | sonnet | 5.6min | 37 | 682 | 4 | $0.75 | bash | ok |
| Dependency License Checker | default | opus | 10.6min | 65 | 1630 | 4 | $2.35 | python | ok |
| Dependency License Checker | default | sonnet | 13.5min | 40 | 1764 | 1 | $1.13 | python | ok |
| Dependency License Checker | powershell | opus | 11.1min | 38 | 1292 | 1 | $1.55 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 28.0min | 59 | 1374 | 0 | $1.85 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.2min | 51 | 1206 | 1 | $1.34 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet | 7.7min | 47 | 1411 | 4 | $1.10 | typescript | ok |
| Docker Image Tag Generator | bash | opus | 14.5min | 33 | 698 | 2 | $2.06 | bash | ok |
| Docker Image Tag Generator | bash | sonnet | 16.0min | 34 | 982 | 4 | $1.49 | bash | ok |
| Docker Image Tag Generator | default | opus | 7.8min | 36 | 1092 | 2 | $1.34 | python | ok |
| Docker Image Tag Generator | default | sonnet | 14.6min | 13 | 1638 | 1 | $1.14 | python | ok |
| Docker Image Tag Generator | powershell | opus | 7.5min | 20 | 1737 | 1 | $0.61 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 24.4min | 51 | 2480 | 1 | $2.13 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus | 11.1min | 40 | 913 | 1 | $1.02 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 10.2min | 19 | 1221 | 1 | $1.03 | typescript | ok |
| Test Results Aggregator | bash | opus | 6.7min | 44 | 784 | 3 | $1.36 | bash | ok |
| Test Results Aggregator | bash | sonnet | 12.0min | 43 | 701 | 5 | $1.26 | bash | ok |
| Test Results Aggregator | default | opus | 7.6min | 40 | 1463 | 2 | $1.43 | python | ok |
| Test Results Aggregator | default | sonnet | 15.9min | 58 | 4114 | 2 | $1.78 | python | ok |
| Test Results Aggregator | powershell | opus | 9.8min | 31 | 821 | 1 | $1.58 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 19.9min | 43 | 1501 | 0 | $1.77 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus | 7.1min | 40 | 1801 | 0 | $1.18 | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet | 12.2min | 72 | 2469 | 3 | $1.86 | typescript | ok |
| Environment Matrix Generator | bash | opus | 9.6min | 36 | 6933 | 1 | $0.87 | bash | ok |
| Environment Matrix Generator | bash | sonnet | 9.8min | 40 | 1425 | 6 | $0.84 | bash | ok |
| Environment Matrix Generator | default | opus | 4.6min | 36 | 1298 | 1 | $0.98 | bash | ok |
| Environment Matrix Generator | default | sonnet | 12.0min | 23 | 1330 | 0 | $1.13 | python | ok |
| Environment Matrix Generator | powershell | opus | 6.7min | 44 | 954 | 5 | $0.99 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 22.1min | 42 | 1020 | 0 | $1.93 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus | 7.0min | 41 | 1183 | 4 | $1.15 | typescript | ok |
| Environment Matrix Generator | typescript-bun | sonnet | 13.5min | 24 | 1518 | 0 | $1.19 | typescript | ok |
| Artifact Cleanup Script | bash | opus | 8.1min | 38 | 1566 | 2 | $1.51 | bash | ok |
| Artifact Cleanup Script | bash | sonnet | 15.4min | 47 | 1894 | 3 | $1.59 | bash | ok |
| Artifact Cleanup Script | default | opus | 6.3min | 29 | 1249 | 0 | $1.05 | python | ok |
| Artifact Cleanup Script | default | sonnet | 15.9min | 25 | 1766 | 1 | $1.49 | python | ok |
| Artifact Cleanup Script | powershell | opus | 9.4min | 39 | 1264 | 0 | $1.60 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 6.5min | 31 | 975 | 0 | $0.70 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus | 12.3min | 30 | 1119 | 0 | $2.06 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 11.7min | 30 | 718 | 1 | $1.18 | typescript | ok |
| Secret Rotation Validator | bash | opus | 11.5min | 33 | 1565 | 1 | $1.34 | bash | ok |
| Secret Rotation Validator | bash | sonnet | 11.2min | 31 | 2014 | 4 | $0.94 | bash | ok |
| Secret Rotation Validator | default | opus | 5.5min | 32 | 1589 | 1 | $1.19 | python | ok |
| Secret Rotation Validator | default | sonnet | 11.5min | 37 | 2093 | 2 | $1.53 | python | ok |
| Secret Rotation Validator | powershell | opus | 10.7min | 34 | 1857 | 0 | $1.35 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 12.7min | 22 | 1994 | 0 | $1.04 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus | 5.4min | 44 | 1089 | 5 | $1.17 | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet | 13.1min | 1 | 4417 | 3 | $1.31 | typescript | ok |


<details>
<summary>Sorted by cost (most expensive first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| PR Label Assigner | powershell | sonnet | 27.1min | 50 | 1157 | 3 | $2.51 | powershell | ok |
| Dependency License Checker | default | opus | 10.6min | 65 | 1630 | 4 | $2.35 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 24.4min | 51 | 2480 | 1 | $2.13 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus | 12.3min | 30 | 1119 | 0 | $2.06 | typescript | ok |
| Docker Image Tag Generator | bash | opus | 14.5min | 33 | 698 | 2 | $2.06 | bash | ok |
| Environment Matrix Generator | powershell | sonnet | 22.1min | 42 | 1020 | 0 | $1.93 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 13.2min | 35 | 987 | 0 | $1.89 | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet | 12.2min | 72 | 2469 | 3 | $1.86 | typescript | ok |
| Dependency License Checker | powershell | sonnet | 28.0min | 59 | 1374 | 0 | $1.85 | powershell | ok |
| Test Results Aggregator | default | sonnet | 15.9min | 58 | 4114 | 2 | $1.78 | python | ok |
| Test Results Aggregator | powershell | sonnet | 19.9min | 43 | 1501 | 0 | $1.77 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 17.2min | 38 | 1595 | 1 | $1.62 | python | ok |
| Artifact Cleanup Script | powershell | opus | 9.4min | 39 | 1264 | 0 | $1.60 | powershell | ok |
| Artifact Cleanup Script | bash | sonnet | 15.4min | 47 | 1894 | 3 | $1.59 | bash | ok |
| Test Results Aggregator | powershell | opus | 9.8min | 31 | 821 | 1 | $1.58 | powershell | ok |
| Dependency License Checker | powershell | opus | 11.1min | 38 | 1292 | 1 | $1.55 | powershell | ok |
| Secret Rotation Validator | default | sonnet | 11.5min | 37 | 2093 | 2 | $1.53 | python | ok |
| Artifact Cleanup Script | bash | opus | 8.1min | 38 | 1566 | 2 | $1.51 | bash | ok |
| Artifact Cleanup Script | default | sonnet | 15.9min | 25 | 1766 | 1 | $1.49 | python | ok |
| Docker Image Tag Generator | bash | sonnet | 16.0min | 34 | 982 | 4 | $1.49 | bash | ok |
| Semantic Version Bumper | bash | opus | 6.8min | 46 | 831 | 2 | $1.45 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 27.2min | 42 | 1714 | 0 | $1.44 | powershell | ok |
| Test Results Aggregator | default | opus | 7.6min | 40 | 1463 | 2 | $1.43 | python | ok |
| Test Results Aggregator | bash | opus | 6.7min | 44 | 784 | 3 | $1.36 | bash | ok |
| PR Label Assigner | typescript-bun | sonnet | 13.7min | 46 | 2944 | 6 | $1.35 | typescript | ok |
| Secret Rotation Validator | powershell | opus | 10.7min | 34 | 1857 | 0 | $1.35 | powershell | ok |
| Secret Rotation Validator | bash | opus | 11.5min | 33 | 1565 | 1 | $1.34 | bash | ok |
| Docker Image Tag Generator | default | opus | 7.8min | 36 | 1092 | 2 | $1.34 | python | ok |
| Dependency License Checker | typescript-bun | opus | 6.2min | 51 | 1206 | 1 | $1.34 | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet | 13.1min | 1 | 4417 | 3 | $1.31 | typescript | ok |
| Semantic Version Bumper | default | opus | 9.0min | 29 | 1115 | 0 | $1.27 | python | ok |
| Test Results Aggregator | bash | sonnet | 12.0min | 43 | 701 | 5 | $1.26 | bash | ok |
| PR Label Assigner | default | sonnet | 16.5min | 23 | 2264 | 1 | $1.25 | python | ok |
| PR Label Assigner | bash | opus | 6.5min | 42 | 929 | 2 | $1.22 | bash | ok |
| Environment Matrix Generator | typescript-bun | sonnet | 13.5min | 24 | 1518 | 0 | $1.19 | typescript | ok |
| Secret Rotation Validator | default | opus | 5.5min | 32 | 1589 | 1 | $1.19 | python | ok |
| Test Results Aggregator | typescript-bun | opus | 7.1min | 40 | 1801 | 0 | $1.18 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 11.7min | 30 | 718 | 1 | $1.18 | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus | 5.4min | 44 | 1089 | 5 | $1.17 | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus | 7.0min | 41 | 1183 | 4 | $1.15 | typescript | ok |
| Docker Image Tag Generator | default | sonnet | 14.6min | 13 | 1638 | 1 | $1.14 | python | ok |
| Environment Matrix Generator | default | sonnet | 12.0min | 23 | 1330 | 0 | $1.13 | python | ok |
| Dependency License Checker | default | sonnet | 13.5min | 40 | 1764 | 1 | $1.13 | python | ok |
| PR Label Assigner | powershell | opus | 8.1min | 32 | 949 | 2 | $1.12 | powershell | ok |
| Dependency License Checker | bash | opus | 5.4min | 40 | 1060 | 1 | $1.12 | bash | ok |
| Dependency License Checker | typescript-bun | sonnet | 7.7min | 47 | 1411 | 4 | $1.10 | typescript | ok |
| Artifact Cleanup Script | default | opus | 6.3min | 29 | 1249 | 0 | $1.05 | python | ok |
| Secret Rotation Validator | powershell | sonnet | 12.7min | 22 | 1994 | 0 | $1.04 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 10.2min | 19 | 1221 | 1 | $1.03 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | opus | 11.1min | 40 | 913 | 1 | $1.02 | typescript | ok |
| Environment Matrix Generator | powershell | opus | 6.7min | 44 | 954 | 5 | $0.99 | powershell | ok |
| Environment Matrix Generator | default | opus | 4.6min | 36 | 1298 | 1 | $0.98 | bash | ok |
| PR Label Assigner | typescript-bun | opus | 9.1min | 31 | 1228 | 1 | $0.96 | typescript | ok |
| Secret Rotation Validator | bash | sonnet | 11.2min | 31 | 2014 | 4 | $0.94 | bash | ok |
| PR Label Assigner | bash | sonnet | 6.8min | 39 | 921 | 5 | $0.90 | bash | ok |
| Environment Matrix Generator | bash | opus | 9.6min | 36 | 6933 | 1 | $0.87 | bash | ok |
| Environment Matrix Generator | bash | sonnet | 9.8min | 40 | 1425 | 6 | $0.84 | bash | ok |
| Semantic Version Bumper | powershell | opus | 9.2min | 31 | 1665 | 0 | $0.82 | powershell | ok |
| Dependency License Checker | bash | sonnet | 5.6min | 37 | 682 | 4 | $0.75 | bash | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 28 | 2296 | 0 | $0.72 | typescript | ok |
| Artifact Cleanup Script | powershell | sonnet | 6.5min | 31 | 975 | 0 | $0.70 | powershell | ok |
| PR Label Assigner | default | opus | 4.6min | 23 | 1111 | 0 | $0.69 | python | ok |
| Semantic Version Bumper | bash | sonnet | 4.9min | 30 | 1074 | 2 | $0.68 | bash | ok |
| Docker Image Tag Generator | powershell | opus | 7.5min | 20 | 1737 | 1 | $0.61 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (longest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Dependency License Checker | powershell | sonnet | 28.0min | 59 | 1374 | 0 | $1.85 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 27.2min | 42 | 1714 | 0 | $1.44 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 27.1min | 50 | 1157 | 3 | $2.51 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 24.4min | 51 | 2480 | 1 | $2.13 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 22.1min | 42 | 1020 | 0 | $1.93 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 19.9min | 43 | 1501 | 0 | $1.77 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 17.2min | 38 | 1595 | 1 | $1.62 | python | ok |
| PR Label Assigner | default | sonnet | 16.5min | 23 | 2264 | 1 | $1.25 | python | ok |
| Docker Image Tag Generator | bash | sonnet | 16.0min | 34 | 982 | 4 | $1.49 | bash | ok |
| Artifact Cleanup Script | default | sonnet | 15.9min | 25 | 1766 | 1 | $1.49 | python | ok |
| Test Results Aggregator | default | sonnet | 15.9min | 58 | 4114 | 2 | $1.78 | python | ok |
| Artifact Cleanup Script | bash | sonnet | 15.4min | 47 | 1894 | 3 | $1.59 | bash | ok |
| Docker Image Tag Generator | default | sonnet | 14.6min | 13 | 1638 | 1 | $1.14 | python | ok |
| Docker Image Tag Generator | bash | opus | 14.5min | 33 | 698 | 2 | $2.06 | bash | ok |
| PR Label Assigner | typescript-bun | sonnet | 13.7min | 46 | 2944 | 6 | $1.35 | typescript | ok |
| Dependency License Checker | default | sonnet | 13.5min | 40 | 1764 | 1 | $1.13 | python | ok |
| Environment Matrix Generator | typescript-bun | sonnet | 13.5min | 24 | 1518 | 0 | $1.19 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 13.2min | 35 | 987 | 0 | $1.89 | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet | 13.1min | 1 | 4417 | 3 | $1.31 | typescript | ok |
| Secret Rotation Validator | powershell | sonnet | 12.7min | 22 | 1994 | 0 | $1.04 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus | 12.3min | 30 | 1119 | 0 | $2.06 | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet | 12.2min | 72 | 2469 | 3 | $1.86 | typescript | ok |
| Environment Matrix Generator | default | sonnet | 12.0min | 23 | 1330 | 0 | $1.13 | python | ok |
| Test Results Aggregator | bash | sonnet | 12.0min | 43 | 701 | 5 | $1.26 | bash | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 11.7min | 30 | 718 | 1 | $1.18 | typescript | ok |
| Secret Rotation Validator | default | sonnet | 11.5min | 37 | 2093 | 2 | $1.53 | python | ok |
| Secret Rotation Validator | bash | opus | 11.5min | 33 | 1565 | 1 | $1.34 | bash | ok |
| Secret Rotation Validator | bash | sonnet | 11.2min | 31 | 2014 | 4 | $0.94 | bash | ok |
| Docker Image Tag Generator | typescript-bun | opus | 11.1min | 40 | 913 | 1 | $1.02 | typescript | ok |
| Dependency License Checker | powershell | opus | 11.1min | 38 | 1292 | 1 | $1.55 | powershell | ok |
| Secret Rotation Validator | powershell | opus | 10.7min | 34 | 1857 | 0 | $1.35 | powershell | ok |
| Dependency License Checker | default | opus | 10.6min | 65 | 1630 | 4 | $2.35 | python | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 10.2min | 19 | 1221 | 1 | $1.03 | typescript | ok |
| Test Results Aggregator | powershell | opus | 9.8min | 31 | 821 | 1 | $1.58 | powershell | ok |
| Environment Matrix Generator | bash | sonnet | 9.8min | 40 | 1425 | 6 | $0.84 | bash | ok |
| Environment Matrix Generator | bash | opus | 9.6min | 36 | 6933 | 1 | $0.87 | bash | ok |
| Artifact Cleanup Script | powershell | opus | 9.4min | 39 | 1264 | 0 | $1.60 | powershell | ok |
| Semantic Version Bumper | powershell | opus | 9.2min | 31 | 1665 | 0 | $0.82 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 9.1min | 31 | 1228 | 1 | $0.96 | typescript | ok |
| Semantic Version Bumper | default | opus | 9.0min | 29 | 1115 | 0 | $1.27 | python | ok |
| PR Label Assigner | powershell | opus | 8.1min | 32 | 949 | 2 | $1.12 | powershell | ok |
| Artifact Cleanup Script | bash | opus | 8.1min | 38 | 1566 | 2 | $1.51 | bash | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 28 | 2296 | 0 | $0.72 | typescript | ok |
| Docker Image Tag Generator | default | opus | 7.8min | 36 | 1092 | 2 | $1.34 | python | ok |
| Dependency License Checker | typescript-bun | sonnet | 7.7min | 47 | 1411 | 4 | $1.10 | typescript | ok |
| Test Results Aggregator | default | opus | 7.6min | 40 | 1463 | 2 | $1.43 | python | ok |
| Docker Image Tag Generator | powershell | opus | 7.5min | 20 | 1737 | 1 | $0.61 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus | 7.1min | 40 | 1801 | 0 | $1.18 | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus | 7.0min | 41 | 1183 | 4 | $1.15 | typescript | ok |
| Semantic Version Bumper | bash | opus | 6.8min | 46 | 831 | 2 | $1.45 | bash | ok |
| PR Label Assigner | bash | sonnet | 6.8min | 39 | 921 | 5 | $0.90 | bash | ok |
| Test Results Aggregator | bash | opus | 6.7min | 44 | 784 | 3 | $1.36 | bash | ok |
| Environment Matrix Generator | powershell | opus | 6.7min | 44 | 954 | 5 | $0.99 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 6.5min | 31 | 975 | 0 | $0.70 | powershell | ok |
| PR Label Assigner | bash | opus | 6.5min | 42 | 929 | 2 | $1.22 | bash | ok |
| Artifact Cleanup Script | default | opus | 6.3min | 29 | 1249 | 0 | $1.05 | python | ok |
| Dependency License Checker | typescript-bun | opus | 6.2min | 51 | 1206 | 1 | $1.34 | typescript | ok |
| Dependency License Checker | bash | sonnet | 5.6min | 37 | 682 | 4 | $0.75 | bash | ok |
| Secret Rotation Validator | default | opus | 5.5min | 32 | 1589 | 1 | $1.19 | python | ok |
| Dependency License Checker | bash | opus | 5.4min | 40 | 1060 | 1 | $1.12 | bash | ok |
| Secret Rotation Validator | typescript-bun | opus | 5.4min | 44 | 1089 | 5 | $1.17 | typescript | ok |
| Semantic Version Bumper | bash | sonnet | 4.9min | 30 | 1074 | 2 | $0.68 | bash | ok |
| PR Label Assigner | default | opus | 4.6min | 23 | 1111 | 0 | $0.69 | python | ok |
| Environment Matrix Generator | default | opus | 4.6min | 36 | 1298 | 1 | $0.98 | bash | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 9.0min | 29 | 1115 | 0 | $1.27 | python | ok |
| Semantic Version Bumper | powershell | opus | 9.2min | 31 | 1665 | 0 | $0.82 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 27.2min | 42 | 1714 | 0 | $1.44 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 13.2min | 35 | 987 | 0 | $1.89 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 28 | 2296 | 0 | $0.72 | typescript | ok |
| PR Label Assigner | default | opus | 4.6min | 23 | 1111 | 0 | $0.69 | python | ok |
| Dependency License Checker | powershell | sonnet | 28.0min | 59 | 1374 | 0 | $1.85 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 19.9min | 43 | 1501 | 0 | $1.77 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus | 7.1min | 40 | 1801 | 0 | $1.18 | typescript | ok |
| Environment Matrix Generator | default | sonnet | 12.0min | 23 | 1330 | 0 | $1.13 | python | ok |
| Environment Matrix Generator | powershell | sonnet | 22.1min | 42 | 1020 | 0 | $1.93 | powershell | ok |
| Environment Matrix Generator | typescript-bun | sonnet | 13.5min | 24 | 1518 | 0 | $1.19 | typescript | ok |
| Artifact Cleanup Script | default | opus | 6.3min | 29 | 1249 | 0 | $1.05 | python | ok |
| Artifact Cleanup Script | powershell | opus | 9.4min | 39 | 1264 | 0 | $1.60 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 6.5min | 31 | 975 | 0 | $0.70 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus | 12.3min | 30 | 1119 | 0 | $2.06 | typescript | ok |
| Secret Rotation Validator | powershell | opus | 10.7min | 34 | 1857 | 0 | $1.35 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 12.7min | 22 | 1994 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | sonnet | 17.2min | 38 | 1595 | 1 | $1.62 | python | ok |
| PR Label Assigner | default | sonnet | 16.5min | 23 | 2264 | 1 | $1.25 | python | ok |
| PR Label Assigner | typescript-bun | opus | 9.1min | 31 | 1228 | 1 | $0.96 | typescript | ok |
| Dependency License Checker | bash | opus | 5.4min | 40 | 1060 | 1 | $1.12 | bash | ok |
| Dependency License Checker | default | sonnet | 13.5min | 40 | 1764 | 1 | $1.13 | python | ok |
| Dependency License Checker | powershell | opus | 11.1min | 38 | 1292 | 1 | $1.55 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.2min | 51 | 1206 | 1 | $1.34 | typescript | ok |
| Docker Image Tag Generator | default | sonnet | 14.6min | 13 | 1638 | 1 | $1.14 | python | ok |
| Docker Image Tag Generator | powershell | opus | 7.5min | 20 | 1737 | 1 | $0.61 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 24.4min | 51 | 2480 | 1 | $2.13 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus | 11.1min | 40 | 913 | 1 | $1.02 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 10.2min | 19 | 1221 | 1 | $1.03 | typescript | ok |
| Test Results Aggregator | powershell | opus | 9.8min | 31 | 821 | 1 | $1.58 | powershell | ok |
| Environment Matrix Generator | bash | opus | 9.6min | 36 | 6933 | 1 | $0.87 | bash | ok |
| Environment Matrix Generator | default | opus | 4.6min | 36 | 1298 | 1 | $0.98 | bash | ok |
| Artifact Cleanup Script | default | sonnet | 15.9min | 25 | 1766 | 1 | $1.49 | python | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 11.7min | 30 | 718 | 1 | $1.18 | typescript | ok |
| Secret Rotation Validator | bash | opus | 11.5min | 33 | 1565 | 1 | $1.34 | bash | ok |
| Secret Rotation Validator | default | opus | 5.5min | 32 | 1589 | 1 | $1.19 | python | ok |
| Semantic Version Bumper | bash | opus | 6.8min | 46 | 831 | 2 | $1.45 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 4.9min | 30 | 1074 | 2 | $0.68 | bash | ok |
| PR Label Assigner | bash | opus | 6.5min | 42 | 929 | 2 | $1.22 | bash | ok |
| PR Label Assigner | powershell | opus | 8.1min | 32 | 949 | 2 | $1.12 | powershell | ok |
| Docker Image Tag Generator | bash | opus | 14.5min | 33 | 698 | 2 | $2.06 | bash | ok |
| Docker Image Tag Generator | default | opus | 7.8min | 36 | 1092 | 2 | $1.34 | python | ok |
| Test Results Aggregator | default | opus | 7.6min | 40 | 1463 | 2 | $1.43 | python | ok |
| Test Results Aggregator | default | sonnet | 15.9min | 58 | 4114 | 2 | $1.78 | python | ok |
| Artifact Cleanup Script | bash | opus | 8.1min | 38 | 1566 | 2 | $1.51 | bash | ok |
| Secret Rotation Validator | default | sonnet | 11.5min | 37 | 2093 | 2 | $1.53 | python | ok |
| PR Label Assigner | powershell | sonnet | 27.1min | 50 | 1157 | 3 | $2.51 | powershell | ok |
| Test Results Aggregator | bash | opus | 6.7min | 44 | 784 | 3 | $1.36 | bash | ok |
| Test Results Aggregator | typescript-bun | sonnet | 12.2min | 72 | 2469 | 3 | $1.86 | typescript | ok |
| Artifact Cleanup Script | bash | sonnet | 15.4min | 47 | 1894 | 3 | $1.59 | bash | ok |
| Secret Rotation Validator | typescript-bun | sonnet | 13.1min | 1 | 4417 | 3 | $1.31 | typescript | ok |
| Dependency License Checker | bash | sonnet | 5.6min | 37 | 682 | 4 | $0.75 | bash | ok |
| Dependency License Checker | default | opus | 10.6min | 65 | 1630 | 4 | $2.35 | python | ok |
| Dependency License Checker | typescript-bun | sonnet | 7.7min | 47 | 1411 | 4 | $1.10 | typescript | ok |
| Docker Image Tag Generator | bash | sonnet | 16.0min | 34 | 982 | 4 | $1.49 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus | 7.0min | 41 | 1183 | 4 | $1.15 | typescript | ok |
| Secret Rotation Validator | bash | sonnet | 11.2min | 31 | 2014 | 4 | $0.94 | bash | ok |
| PR Label Assigner | bash | sonnet | 6.8min | 39 | 921 | 5 | $0.90 | bash | ok |
| Test Results Aggregator | bash | sonnet | 12.0min | 43 | 701 | 5 | $1.26 | bash | ok |
| Environment Matrix Generator | powershell | opus | 6.7min | 44 | 954 | 5 | $0.99 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus | 5.4min | 44 | 1089 | 5 | $1.17 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet | 13.7min | 46 | 2944 | 6 | $1.35 | typescript | ok |
| Environment Matrix Generator | bash | sonnet | 9.8min | 40 | 1425 | 6 | $0.84 | bash | ok |

</details>

<details>
<summary>Sorted by lines (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Dependency License Checker | bash | sonnet | 5.6min | 37 | 682 | 4 | $0.75 | bash | ok |
| Docker Image Tag Generator | bash | opus | 14.5min | 33 | 698 | 2 | $2.06 | bash | ok |
| Test Results Aggregator | bash | sonnet | 12.0min | 43 | 701 | 5 | $1.26 | bash | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 11.7min | 30 | 718 | 1 | $1.18 | typescript | ok |
| Test Results Aggregator | bash | opus | 6.7min | 44 | 784 | 3 | $1.36 | bash | ok |
| Test Results Aggregator | powershell | opus | 9.8min | 31 | 821 | 1 | $1.58 | powershell | ok |
| Semantic Version Bumper | bash | opus | 6.8min | 46 | 831 | 2 | $1.45 | bash | ok |
| Docker Image Tag Generator | typescript-bun | opus | 11.1min | 40 | 913 | 1 | $1.02 | typescript | ok |
| PR Label Assigner | bash | sonnet | 6.8min | 39 | 921 | 5 | $0.90 | bash | ok |
| PR Label Assigner | bash | opus | 6.5min | 42 | 929 | 2 | $1.22 | bash | ok |
| PR Label Assigner | powershell | opus | 8.1min | 32 | 949 | 2 | $1.12 | powershell | ok |
| Environment Matrix Generator | powershell | opus | 6.7min | 44 | 954 | 5 | $0.99 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 6.5min | 31 | 975 | 0 | $0.70 | powershell | ok |
| Docker Image Tag Generator | bash | sonnet | 16.0min | 34 | 982 | 4 | $1.49 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus | 13.2min | 35 | 987 | 0 | $1.89 | typescript | ok |
| Environment Matrix Generator | powershell | sonnet | 22.1min | 42 | 1020 | 0 | $1.93 | powershell | ok |
| Dependency License Checker | bash | opus | 5.4min | 40 | 1060 | 1 | $1.12 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 4.9min | 30 | 1074 | 2 | $0.68 | bash | ok |
| Secret Rotation Validator | typescript-bun | opus | 5.4min | 44 | 1089 | 5 | $1.17 | typescript | ok |
| Docker Image Tag Generator | default | opus | 7.8min | 36 | 1092 | 2 | $1.34 | python | ok |
| PR Label Assigner | default | opus | 4.6min | 23 | 1111 | 0 | $0.69 | python | ok |
| Semantic Version Bumper | default | opus | 9.0min | 29 | 1115 | 0 | $1.27 | python | ok |
| Artifact Cleanup Script | typescript-bun | opus | 12.3min | 30 | 1119 | 0 | $2.06 | typescript | ok |
| PR Label Assigner | powershell | sonnet | 27.1min | 50 | 1157 | 3 | $2.51 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus | 7.0min | 41 | 1183 | 4 | $1.15 | typescript | ok |
| Dependency License Checker | typescript-bun | opus | 6.2min | 51 | 1206 | 1 | $1.34 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 10.2min | 19 | 1221 | 1 | $1.03 | typescript | ok |
| PR Label Assigner | typescript-bun | opus | 9.1min | 31 | 1228 | 1 | $0.96 | typescript | ok |
| Artifact Cleanup Script | default | opus | 6.3min | 29 | 1249 | 0 | $1.05 | python | ok |
| Artifact Cleanup Script | powershell | opus | 9.4min | 39 | 1264 | 0 | $1.60 | powershell | ok |
| Dependency License Checker | powershell | opus | 11.1min | 38 | 1292 | 1 | $1.55 | powershell | ok |
| Environment Matrix Generator | default | opus | 4.6min | 36 | 1298 | 1 | $0.98 | bash | ok |
| Environment Matrix Generator | default | sonnet | 12.0min | 23 | 1330 | 0 | $1.13 | python | ok |
| Dependency License Checker | powershell | sonnet | 28.0min | 59 | 1374 | 0 | $1.85 | powershell | ok |
| Dependency License Checker | typescript-bun | sonnet | 7.7min | 47 | 1411 | 4 | $1.10 | typescript | ok |
| Environment Matrix Generator | bash | sonnet | 9.8min | 40 | 1425 | 6 | $0.84 | bash | ok |
| Test Results Aggregator | default | opus | 7.6min | 40 | 1463 | 2 | $1.43 | python | ok |
| Test Results Aggregator | powershell | sonnet | 19.9min | 43 | 1501 | 0 | $1.77 | powershell | ok |
| Environment Matrix Generator | typescript-bun | sonnet | 13.5min | 24 | 1518 | 0 | $1.19 | typescript | ok |
| Secret Rotation Validator | bash | opus | 11.5min | 33 | 1565 | 1 | $1.34 | bash | ok |
| Artifact Cleanup Script | bash | opus | 8.1min | 38 | 1566 | 2 | $1.51 | bash | ok |
| Secret Rotation Validator | default | opus | 5.5min | 32 | 1589 | 1 | $1.19 | python | ok |
| Semantic Version Bumper | default | sonnet | 17.2min | 38 | 1595 | 1 | $1.62 | python | ok |
| Dependency License Checker | default | opus | 10.6min | 65 | 1630 | 4 | $2.35 | python | ok |
| Docker Image Tag Generator | default | sonnet | 14.6min | 13 | 1638 | 1 | $1.14 | python | ok |
| Semantic Version Bumper | powershell | opus | 9.2min | 31 | 1665 | 0 | $0.82 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 27.2min | 42 | 1714 | 0 | $1.44 | powershell | ok |
| Docker Image Tag Generator | powershell | opus | 7.5min | 20 | 1737 | 1 | $0.61 | powershell | ok |
| Dependency License Checker | default | sonnet | 13.5min | 40 | 1764 | 1 | $1.13 | python | ok |
| Artifact Cleanup Script | default | sonnet | 15.9min | 25 | 1766 | 1 | $1.49 | python | ok |
| Test Results Aggregator | typescript-bun | opus | 7.1min | 40 | 1801 | 0 | $1.18 | typescript | ok |
| Secret Rotation Validator | powershell | opus | 10.7min | 34 | 1857 | 0 | $1.35 | powershell | ok |
| Artifact Cleanup Script | bash | sonnet | 15.4min | 47 | 1894 | 3 | $1.59 | bash | ok |
| Secret Rotation Validator | powershell | sonnet | 12.7min | 22 | 1994 | 0 | $1.04 | powershell | ok |
| Secret Rotation Validator | bash | sonnet | 11.2min | 31 | 2014 | 4 | $0.94 | bash | ok |
| Secret Rotation Validator | default | sonnet | 11.5min | 37 | 2093 | 2 | $1.53 | python | ok |
| PR Label Assigner | default | sonnet | 16.5min | 23 | 2264 | 1 | $1.25 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 28 | 2296 | 0 | $0.72 | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet | 12.2min | 72 | 2469 | 3 | $1.86 | typescript | ok |
| Docker Image Tag Generator | powershell | sonnet | 24.4min | 51 | 2480 | 1 | $2.13 | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet | 13.7min | 46 | 2944 | 6 | $1.35 | typescript | ok |
| Test Results Aggregator | default | sonnet | 15.9min | 58 | 4114 | 2 | $1.78 | python | ok |
| Secret Rotation Validator | typescript-bun | sonnet | 13.1min | 1 | 4417 | 3 | $1.31 | typescript | ok |
| Environment Matrix Generator | bash | opus | 9.6min | 36 | 6933 | 1 | $0.87 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Secret Rotation Validator | typescript-bun | sonnet | 13.1min | 1 | 4417 | 3 | $1.31 | typescript | ok |
| Docker Image Tag Generator | default | sonnet | 14.6min | 13 | 1638 | 1 | $1.14 | python | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 10.2min | 19 | 1221 | 1 | $1.03 | typescript | ok |
| Docker Image Tag Generator | powershell | opus | 7.5min | 20 | 1737 | 1 | $0.61 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 12.7min | 22 | 1994 | 0 | $1.04 | powershell | ok |
| PR Label Assigner | default | opus | 4.6min | 23 | 1111 | 0 | $0.69 | python | ok |
| PR Label Assigner | default | sonnet | 16.5min | 23 | 2264 | 1 | $1.25 | python | ok |
| Environment Matrix Generator | default | sonnet | 12.0min | 23 | 1330 | 0 | $1.13 | python | ok |
| Environment Matrix Generator | typescript-bun | sonnet | 13.5min | 24 | 1518 | 0 | $1.19 | typescript | ok |
| Artifact Cleanup Script | default | sonnet | 15.9min | 25 | 1766 | 1 | $1.49 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 28 | 2296 | 0 | $0.72 | typescript | ok |
| Semantic Version Bumper | default | opus | 9.0min | 29 | 1115 | 0 | $1.27 | python | ok |
| Artifact Cleanup Script | default | opus | 6.3min | 29 | 1249 | 0 | $1.05 | python | ok |
| Semantic Version Bumper | bash | sonnet | 4.9min | 30 | 1074 | 2 | $0.68 | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus | 12.3min | 30 | 1119 | 0 | $2.06 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 11.7min | 30 | 718 | 1 | $1.18 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 9.2min | 31 | 1665 | 0 | $0.82 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 9.1min | 31 | 1228 | 1 | $0.96 | typescript | ok |
| Test Results Aggregator | powershell | opus | 9.8min | 31 | 821 | 1 | $1.58 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 6.5min | 31 | 975 | 0 | $0.70 | powershell | ok |
| Secret Rotation Validator | bash | sonnet | 11.2min | 31 | 2014 | 4 | $0.94 | bash | ok |
| PR Label Assigner | powershell | opus | 8.1min | 32 | 949 | 2 | $1.12 | powershell | ok |
| Secret Rotation Validator | default | opus | 5.5min | 32 | 1589 | 1 | $1.19 | python | ok |
| Docker Image Tag Generator | bash | opus | 14.5min | 33 | 698 | 2 | $2.06 | bash | ok |
| Secret Rotation Validator | bash | opus | 11.5min | 33 | 1565 | 1 | $1.34 | bash | ok |
| Docker Image Tag Generator | bash | sonnet | 16.0min | 34 | 982 | 4 | $1.49 | bash | ok |
| Secret Rotation Validator | powershell | opus | 10.7min | 34 | 1857 | 0 | $1.35 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 13.2min | 35 | 987 | 0 | $1.89 | typescript | ok |
| Docker Image Tag Generator | default | opus | 7.8min | 36 | 1092 | 2 | $1.34 | python | ok |
| Environment Matrix Generator | bash | opus | 9.6min | 36 | 6933 | 1 | $0.87 | bash | ok |
| Environment Matrix Generator | default | opus | 4.6min | 36 | 1298 | 1 | $0.98 | bash | ok |
| Dependency License Checker | bash | sonnet | 5.6min | 37 | 682 | 4 | $0.75 | bash | ok |
| Secret Rotation Validator | default | sonnet | 11.5min | 37 | 2093 | 2 | $1.53 | python | ok |
| Semantic Version Bumper | default | sonnet | 17.2min | 38 | 1595 | 1 | $1.62 | python | ok |
| Dependency License Checker | powershell | opus | 11.1min | 38 | 1292 | 1 | $1.55 | powershell | ok |
| Artifact Cleanup Script | bash | opus | 8.1min | 38 | 1566 | 2 | $1.51 | bash | ok |
| PR Label Assigner | bash | sonnet | 6.8min | 39 | 921 | 5 | $0.90 | bash | ok |
| Artifact Cleanup Script | powershell | opus | 9.4min | 39 | 1264 | 0 | $1.60 | powershell | ok |
| Dependency License Checker | bash | opus | 5.4min | 40 | 1060 | 1 | $1.12 | bash | ok |
| Dependency License Checker | default | sonnet | 13.5min | 40 | 1764 | 1 | $1.13 | python | ok |
| Docker Image Tag Generator | typescript-bun | opus | 11.1min | 40 | 913 | 1 | $1.02 | typescript | ok |
| Test Results Aggregator | default | opus | 7.6min | 40 | 1463 | 2 | $1.43 | python | ok |
| Test Results Aggregator | typescript-bun | opus | 7.1min | 40 | 1801 | 0 | $1.18 | typescript | ok |
| Environment Matrix Generator | bash | sonnet | 9.8min | 40 | 1425 | 6 | $0.84 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus | 7.0min | 41 | 1183 | 4 | $1.15 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 27.2min | 42 | 1714 | 0 | $1.44 | powershell | ok |
| PR Label Assigner | bash | opus | 6.5min | 42 | 929 | 2 | $1.22 | bash | ok |
| Environment Matrix Generator | powershell | sonnet | 22.1min | 42 | 1020 | 0 | $1.93 | powershell | ok |
| Test Results Aggregator | bash | sonnet | 12.0min | 43 | 701 | 5 | $1.26 | bash | ok |
| Test Results Aggregator | powershell | sonnet | 19.9min | 43 | 1501 | 0 | $1.77 | powershell | ok |
| Test Results Aggregator | bash | opus | 6.7min | 44 | 784 | 3 | $1.36 | bash | ok |
| Environment Matrix Generator | powershell | opus | 6.7min | 44 | 954 | 5 | $0.99 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus | 5.4min | 44 | 1089 | 5 | $1.17 | typescript | ok |
| Semantic Version Bumper | bash | opus | 6.8min | 46 | 831 | 2 | $1.45 | bash | ok |
| PR Label Assigner | typescript-bun | sonnet | 13.7min | 46 | 2944 | 6 | $1.35 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet | 7.7min | 47 | 1411 | 4 | $1.10 | typescript | ok |
| Artifact Cleanup Script | bash | sonnet | 15.4min | 47 | 1894 | 3 | $1.59 | bash | ok |
| PR Label Assigner | powershell | sonnet | 27.1min | 50 | 1157 | 3 | $2.51 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.2min | 51 | 1206 | 1 | $1.34 | typescript | ok |
| Docker Image Tag Generator | powershell | sonnet | 24.4min | 51 | 2480 | 1 | $2.13 | powershell | ok |
| Test Results Aggregator | default | sonnet | 15.9min | 58 | 4114 | 2 | $1.78 | python | ok |
| Dependency License Checker | powershell | sonnet | 28.0min | 59 | 1374 | 0 | $1.85 | powershell | ok |
| Dependency License Checker | default | opus | 10.6min | 65 | 1630 | 4 | $2.35 | python | ok |
| Test Results Aggregator | typescript-bun | sonnet | 12.2min | 72 | 2469 | 3 | $1.86 | typescript | ok |

</details>

---
*Generated by generate_results.py, instructions version v3*