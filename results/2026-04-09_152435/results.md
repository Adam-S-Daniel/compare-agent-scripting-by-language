# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-10 01:34:50 AM ET

**Status:** 57/64 runs completed, 7 remaining
**Total cost so far:** $74.67
**Total agent time so far:** 478.7 min

## Observations

- **Fastest (avg):** typescript-bun/opus — 6.7min, then default/opus — 6.9min
- **Slowest (avg):** powershell/sonnet — 11.0min, then bash/sonnet — 9.6min
- **Cheapest (avg):** default/sonnet — $1.13, then typescript-bun/sonnet — $1.16
- **Most expensive (avg):** bash/opus — $1.49, then powershell/opus — $1.48

- **Estimated time remaining:** 58.8min
- **Estimated total cost:** $83.84

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus | 7 | 7.7min | 7.1min | 1.7 | 44 | $1.49 | $10.41 |
| bash | sonnet | 7 | 9.6min | 9.3min | 3.4 | 36 | $1.23 | $8.61 |
| default | opus | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 |
| default | sonnet | 7 | 8.5min | 7.9min | 2.6 | 36 | $1.13 | $7.90 |
| powershell | opus | 7 | 7.6min | 7.4min | 1.7 | 34 | $1.48 | $10.38 |
| powershell | sonnet | 7 | 11.0min | 9.4min | 1.4 | 38 | $1.27 | $8.88 |
| typescript-bun | opus | 7 | 6.7min | 5.7min | 1.7 | 37 | $1.26 | $8.81 |
| typescript-bun | sonnet | 7 | 9.5min | 7.9min | 1.9 | 37 | $1.16 | $8.11 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | sonnet | 7 | 8.5min | 7.9min | 2.6 | 36 | $1.13 | $7.90 |
| typescript-bun | sonnet | 7 | 9.5min | 7.9min | 1.9 | 37 | $1.16 | $8.11 |
| bash | sonnet | 7 | 9.6min | 9.3min | 3.4 | 36 | $1.23 | $8.61 |
| typescript-bun | opus | 7 | 6.7min | 5.7min | 1.7 | 37 | $1.26 | $8.81 |
| powershell | sonnet | 7 | 11.0min | 9.4min | 1.4 | 38 | $1.27 | $8.88 |
| default | opus | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 |
| powershell | opus | 7 | 7.6min | 7.4min | 1.7 | 34 | $1.48 | $10.38 |
| bash | opus | 7 | 7.7min | 7.1min | 1.7 | 44 | $1.49 | $10.41 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | opus | 7 | 6.7min | 5.7min | 1.7 | 37 | $1.26 | $8.81 |
| default | opus | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 |
| powershell | opus | 7 | 7.6min | 7.4min | 1.7 | 34 | $1.48 | $10.38 |
| bash | opus | 7 | 7.7min | 7.1min | 1.7 | 44 | $1.49 | $10.41 |
| default | sonnet | 7 | 8.5min | 7.9min | 2.6 | 36 | $1.13 | $7.90 |
| typescript-bun | sonnet | 7 | 9.5min | 7.9min | 1.9 | 37 | $1.16 | $8.11 |
| bash | sonnet | 7 | 9.6min | 9.3min | 3.4 | 36 | $1.23 | $8.61 |
| powershell | sonnet | 7 | 11.0min | 9.4min | 1.4 | 38 | $1.27 | $8.88 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | opus | 7 | 6.7min | 5.7min | 1.7 | 37 | $1.26 | $8.81 |
| default | opus | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 |
| bash | opus | 7 | 7.7min | 7.1min | 1.7 | 44 | $1.49 | $10.41 |
| powershell | opus | 7 | 7.6min | 7.4min | 1.7 | 34 | $1.48 | $10.38 |
| default | sonnet | 7 | 8.5min | 7.9min | 2.6 | 36 | $1.13 | $7.90 |
| typescript-bun | sonnet | 7 | 9.5min | 7.9min | 1.9 | 37 | $1.16 | $8.11 |
| bash | sonnet | 7 | 9.6min | 9.3min | 3.4 | 36 | $1.23 | $8.61 |
| powershell | sonnet | 7 | 11.0min | 9.4min | 1.4 | 38 | $1.27 | $8.88 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | sonnet | 7 | 11.0min | 9.4min | 1.4 | 38 | $1.27 | $8.88 |
| default | opus | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 |
| bash | opus | 7 | 7.7min | 7.1min | 1.7 | 44 | $1.49 | $10.41 |
| powershell | opus | 7 | 7.6min | 7.4min | 1.7 | 34 | $1.48 | $10.38 |
| typescript-bun | opus | 7 | 6.7min | 5.7min | 1.7 | 37 | $1.26 | $8.81 |
| typescript-bun | sonnet | 7 | 9.5min | 7.9min | 1.9 | 37 | $1.16 | $8.11 |
| default | sonnet | 7 | 8.5min | 7.9min | 2.6 | 36 | $1.13 | $7.90 |
| bash | sonnet | 7 | 9.6min | 9.3min | 3.4 | 36 | $1.23 | $8.61 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| powershell | opus | 7 | 7.6min | 7.4min | 1.7 | 34 | $1.48 | $10.38 |
| default | opus | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 |
| default | sonnet | 7 | 8.5min | 7.9min | 2.6 | 36 | $1.13 | $7.90 |
| bash | sonnet | 7 | 9.6min | 9.3min | 3.4 | 36 | $1.23 | $8.61 |
| typescript-bun | opus | 7 | 6.7min | 5.7min | 1.7 | 37 | $1.26 | $8.81 |
| typescript-bun | sonnet | 7 | 9.5min | 7.9min | 1.9 | 37 | $1.16 | $8.11 |
| powershell | sonnet | 7 | 11.0min | 9.4min | 1.4 | 38 | $1.27 | $8.88 |
| bash | opus | 7 | 7.7min | 7.1min | 1.7 | 44 | $1.49 | $10.41 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus | 82 | 3 | 3.7% | 0.6min | 0.1% | 0.6min | 0.1% | 0.0min | 0.0% | 6.8min | 0.4% |
| bash | sonnet | 78 | 7 | 9.0% | 1.4min | 0.3% | 0.2min | 0.0% | 1.2min | 0.3% | 6.4min | 19.2% |
| default | opus | 77 | 14 | 18.2% | 1.9min | 0.4% | 0.2min | 0.1% | 1.6min | 0.3% | 3.0min | 54.2% |
| default | sonnet | 69 | 1 | 1.4% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 3.3min | -1.8% |
| powershell | opus | 79 | 10 | 12.7% | 5.8min | 1.2% | 0.6min | 0.1% | 5.2min | 1.1% | 5.5min | 94.3% |
| powershell | sonnet | 75 | 1 | 1.3% | 0.6min | 0.1% | 0.7min | 0.2% | -0.1min | -0.0% | 8.8min | -1.6% |
| typescript-bun | opus | 51 | 27 | 52.9% | 3.6min | 0.8% | 3.6min | 0.8% | -0.0min | -0.0% | 4.5min | -0.8% |
| typescript-bun | sonnet | 82 | 42 | 51.2% | 5.6min | 1.2% | 2.1min | 0.4% | 3.5min | 0.7% | 4.9min | 71.3% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell | opus | 79 | 10 | 12.7% | 5.8min | 1.2% | 0.6min | 0.1% | 5.2min | 1.1% | 5.5min | 94.3% |
| typescript-bun | sonnet | 82 | 42 | 51.2% | 5.6min | 1.2% | 2.1min | 0.4% | 3.5min | 0.7% | 4.9min | 71.3% |
| default | opus | 77 | 14 | 18.2% | 1.9min | 0.4% | 0.2min | 0.1% | 1.6min | 0.3% | 3.0min | 54.2% |
| bash | sonnet | 78 | 7 | 9.0% | 1.4min | 0.3% | 0.2min | 0.0% | 1.2min | 0.3% | 6.4min | 19.2% |
| bash | opus | 82 | 3 | 3.7% | 0.6min | 0.1% | 0.6min | 0.1% | 0.0min | 0.0% | 6.8min | 0.4% |
| typescript-bun | opus | 51 | 27 | 52.9% | 3.6min | 0.8% | 3.6min | 0.8% | -0.0min | -0.0% | 4.5min | -0.8% |
| default | sonnet | 69 | 1 | 1.4% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 3.3min | -1.8% |
| powershell | sonnet | 75 | 1 | 1.3% | 0.6min | 0.1% | 0.7min | 0.2% | -0.1min | -0.0% | 8.8min | -1.6% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell | opus | 79 | 10 | 12.7% | 5.8min | 1.2% | 0.6min | 0.1% | 5.2min | 1.1% | 5.5min | 94.3% |
| typescript-bun | sonnet | 82 | 42 | 51.2% | 5.6min | 1.2% | 2.1min | 0.4% | 3.5min | 0.7% | 4.9min | 71.3% |
| default | opus | 77 | 14 | 18.2% | 1.9min | 0.4% | 0.2min | 0.1% | 1.6min | 0.3% | 3.0min | 54.2% |
| bash | sonnet | 78 | 7 | 9.0% | 1.4min | 0.3% | 0.2min | 0.0% | 1.2min | 0.3% | 6.4min | 19.2% |
| bash | opus | 82 | 3 | 3.7% | 0.6min | 0.1% | 0.6min | 0.1% | 0.0min | 0.0% | 6.8min | 0.4% |
| typescript-bun | opus | 51 | 27 | 52.9% | 3.6min | 0.8% | 3.6min | 0.8% | -0.0min | -0.0% | 4.5min | -0.8% |
| powershell | sonnet | 75 | 1 | 1.3% | 0.6min | 0.1% | 0.7min | 0.2% | -0.1min | -0.0% | 8.8min | -1.6% |
| default | sonnet | 69 | 1 | 1.4% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 3.3min | -1.8% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus | 51 | 27 | 52.9% | 3.6min | 0.8% | 3.6min | 0.8% | -0.0min | -0.0% | 4.5min | -0.8% |
| typescript-bun | sonnet | 82 | 42 | 51.2% | 5.6min | 1.2% | 2.1min | 0.4% | 3.5min | 0.7% | 4.9min | 71.3% |
| default | opus | 77 | 14 | 18.2% | 1.9min | 0.4% | 0.2min | 0.1% | 1.6min | 0.3% | 3.0min | 54.2% |
| powershell | opus | 79 | 10 | 12.7% | 5.8min | 1.2% | 0.6min | 0.1% | 5.2min | 1.1% | 5.5min | 94.3% |
| bash | sonnet | 78 | 7 | 9.0% | 1.4min | 0.3% | 0.2min | 0.0% | 1.2min | 0.3% | 6.4min | 19.2% |
| bash | opus | 82 | 3 | 3.7% | 0.6min | 0.1% | 0.6min | 0.1% | 0.0min | 0.0% | 6.8min | 0.4% |
| default | sonnet | 69 | 1 | 1.4% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 3.3min | -1.8% |
| powershell | sonnet | 75 | 1 | 1.3% | 0.6min | 0.1% | 0.7min | 0.2% | -0.1min | -0.0% | 8.8min | -1.6% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus | 6 | 5.4min | 1.1% | $1.01 | 1.36% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 7 | 8.4min | 1.8% | $1.05 | 1.40% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.6% | $0.59 | 0.79% |
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.08% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.3% | $0.37 | 0.49% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.5% | $0.36 | 0.48% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.19% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.1% | $0.08 | 0.11% |
| repeated-test-reruns | powershell | sonnet | 4 | 4.3min | 0.9% | $0.55 | 0.74% |
| repeated-test-reruns | typescript-bun | sonnet | 1 | 1.0min | 0.2% | $0.14 | 0.19% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.15% |
| act-push-debug-loops | bash | sonnet | 1 | 0.4min | 0.1% | $0.05 | 0.06% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.5% | $0.28 | 0.38% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.12% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.18% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 0.9% | $0.57 | 0.76% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.4% | $0.25 | 0.34% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.1% | $0.09 | 0.12% |
| actionlint-fix-cycles | default | sonnet | 1 | 0.7min | 0.1% | $0.09 | 0.12% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.12% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | sonnet | 1 | 0.4min | 0.1% | $0.05 | 0.06% |
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.08% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.12% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.1% | $0.08 | 0.11% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.1% | $0.09 | 0.12% |
| actionlint-fix-cycles | default | sonnet | 1 | 0.7min | 0.1% | $0.09 | 0.12% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.19% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.12% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.15% |
| repeated-test-reruns | typescript-bun | sonnet | 1 | 1.0min | 0.2% | $0.14 | 0.19% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.18% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.3% | $0.37 | 0.49% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.4% | $0.25 | 0.34% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.5% | $0.28 | 0.38% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.5% | $0.36 | 0.48% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.6% | $0.59 | 0.79% |
| repeated-test-reruns | powershell | sonnet | 4 | 4.3min | 0.9% | $0.55 | 0.74% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 0.9% | $0.57 | 0.76% |
| ts-type-error-fix-cycles | typescript-bun | opus | 6 | 5.4min | 1.1% | $1.01 | 1.36% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 7 | 8.4min | 1.8% | $1.05 | 1.40% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | sonnet | 1 | 0.4min | 0.1% | $0.05 | 0.06% |
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.08% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.1% | $0.08 | 0.11% |
| actionlint-fix-cycles | default | sonnet | 1 | 0.7min | 0.1% | $0.09 | 0.12% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.1% | $0.09 | 0.12% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.12% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.12% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.15% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.18% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.19% |
| repeated-test-reruns | typescript-bun | sonnet | 1 | 1.0min | 0.2% | $0.14 | 0.19% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.4% | $0.25 | 0.34% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.5% | $0.28 | 0.38% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.5% | $0.36 | 0.48% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.3% | $0.37 | 0.49% |
| repeated-test-reruns | powershell | sonnet | 4 | 4.3min | 0.9% | $0.55 | 0.74% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 0.9% | $0.57 | 0.76% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.6% | $0.59 | 0.79% |
| ts-type-error-fix-cycles | typescript-bun | opus | 6 | 5.4min | 1.1% | $1.01 | 1.36% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 7 | 8.4min | 1.8% | $1.05 | 1.40% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | bash | sonnet | 1 | 0.5min | 0.1% | $0.06 | 0.08% |
| fixture-rework | powershell | opus | 1 | 1.5min | 0.3% | $0.37 | 0.49% |
| fixture-rework | typescript-bun | opus | 1 | 0.8min | 0.2% | $0.14 | 0.19% |
| repeated-test-reruns | default | sonnet | 1 | 0.7min | 0.1% | $0.08 | 0.11% |
| repeated-test-reruns | typescript-bun | sonnet | 1 | 1.0min | 0.2% | $0.14 | 0.19% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.2% | $0.11 | 0.15% |
| act-push-debug-loops | bash | sonnet | 1 | 0.4min | 0.1% | $0.05 | 0.06% |
| act-push-debug-loops | typescript-bun | opus | 1 | 0.5min | 0.1% | $0.09 | 0.12% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.3% | $0.13 | 0.18% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.1% | $0.09 | 0.12% |
| actionlint-fix-cycles | default | sonnet | 1 | 0.7min | 0.1% | $0.09 | 0.12% |
| act-permission-path-errors | default | sonnet | 1 | 0.8min | 0.2% | $0.09 | 0.12% |
| fixture-rework | powershell | sonnet | 2 | 2.5min | 0.5% | $0.36 | 0.48% |
| act-push-debug-loops | default | sonnet | 2 | 2.2min | 0.5% | $0.28 | 0.38% |
| docker-pwsh-install | powershell | sonnet | 2 | 4.5min | 0.9% | $0.57 | 0.76% |
| bats-setup-issues | bash | sonnet | 2 | 1.8min | 0.4% | $0.25 | 0.34% |
| fixture-rework | bash | opus | 3 | 2.8min | 0.6% | $0.59 | 0.79% |
| repeated-test-reruns | powershell | sonnet | 4 | 4.3min | 0.9% | $0.55 | 0.74% |
| ts-type-error-fix-cycles | typescript-bun | opus | 6 | 5.4min | 1.1% | $1.01 | 1.36% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 7 | 8.4min | 1.8% | $1.05 | 1.40% |

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
| bash | opus | 7 | 4 | 57% | 5 | 4.2min | 0.9% | $0.79 | 1.06% |
| bash | sonnet | 7 | 4 | 57% | 4 | 2.7min | 0.6% | $0.36 | 0.48% |
| default | opus | 8 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 7 | 3 | 43% | 5 | 4.2min | 0.9% | $0.54 | 0.72% |
| powershell | opus | 7 | 1 | 14% | 1 | 1.5min | 0.3% | $0.37 | 0.49% |
| powershell | sonnet | 7 | 6 | 86% | 8 | 11.3min | 2.4% | $1.48 | 1.98% |
| typescript-bun | opus | 7 | 6 | 86% | 8 | 6.7min | 1.4% | $1.24 | 1.67% |
| typescript-bun | sonnet | 7 | 7 | 100% | 9 | 10.6min | 2.2% | $1.32 | 1.77% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 8 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 7 | 1 | 14% | 1 | 1.5min | 0.3% | $0.37 | 0.49% |
| bash | sonnet | 7 | 4 | 57% | 4 | 2.7min | 0.6% | $0.36 | 0.48% |
| default | sonnet | 7 | 3 | 43% | 5 | 4.2min | 0.9% | $0.54 | 0.72% |
| bash | opus | 7 | 4 | 57% | 5 | 4.2min | 0.9% | $0.79 | 1.06% |
| typescript-bun | opus | 7 | 6 | 86% | 8 | 6.7min | 1.4% | $1.24 | 1.67% |
| typescript-bun | sonnet | 7 | 7 | 100% | 9 | 10.6min | 2.2% | $1.32 | 1.77% |
| powershell | sonnet | 7 | 6 | 86% | 8 | 11.3min | 2.4% | $1.48 | 1.98% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 8 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 7 | 4 | 57% | 4 | 2.7min | 0.6% | $0.36 | 0.48% |
| powershell | opus | 7 | 1 | 14% | 1 | 1.5min | 0.3% | $0.37 | 0.49% |
| default | sonnet | 7 | 3 | 43% | 5 | 4.2min | 0.9% | $0.54 | 0.72% |
| bash | opus | 7 | 4 | 57% | 5 | 4.2min | 0.9% | $0.79 | 1.06% |
| typescript-bun | opus | 7 | 6 | 86% | 8 | 6.7min | 1.4% | $1.24 | 1.67% |
| typescript-bun | sonnet | 7 | 7 | 100% | 9 | 10.6min | 2.2% | $1.32 | 1.77% |
| powershell | sonnet | 7 | 6 | 86% | 8 | 11.3min | 2.4% | $1.48 | 1.98% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 8 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 7 | 1 | 14% | 1 | 1.5min | 0.3% | $0.37 | 0.49% |
| default | sonnet | 7 | 3 | 43% | 5 | 4.2min | 0.9% | $0.54 | 0.72% |
| bash | opus | 7 | 4 | 57% | 5 | 4.2min | 0.9% | $0.79 | 1.06% |
| bash | sonnet | 7 | 4 | 57% | 4 | 2.7min | 0.6% | $0.36 | 0.48% |
| powershell | sonnet | 7 | 6 | 86% | 8 | 11.3min | 2.4% | $1.48 | 1.98% |
| typescript-bun | opus | 7 | 6 | 86% | 8 | 6.7min | 1.4% | $1.24 | 1.67% |
| typescript-bun | sonnet | 7 | 7 | 100% | 9 | 10.6min | 2.2% | $1.32 | 1.77% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 1 | $0.06 | 0.08% |
| Partial | 54 | $6.54 | 8.75% |
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
| Artifact Cleanup Script | powershell | opus | 5.4min | 29 | 2 | $1.07 | powershell | ok |
| Artifact Cleanup Script | bash | opus | 5.7min | 50 | 2 | $1.50 | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus | 7.7min | 34 | 1 | $1.68 | typescript | ok |
| Artifact Cleanup Script | default | sonnet | 6.3min | 31 | 2 | $0.83 | python | ok |
| Artifact Cleanup Script | powershell | sonnet | 12.0min | 15 | 0 | $0.99 | powershell | ok |
| Artifact Cleanup Script | bash | sonnet | 7.2min | 35 | 1 | $0.77 | bash | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 9.2min | 38 | 2 | $1.17 | typescript | ok |
| Secret Rotation Validator | default | opus | 7.3min | 38 | 1 | $1.51 | python | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Docker Image Tag Generator | bash | sonnet | 4.5min | 26 | 2 | $0.61 | bash | ok |
| Test Results Aggregator | typescript-bun | opus | 2.3min | 29 | 1 | $0.61 | typescript | ok |
| Artifact Cleanup Script | bash | sonnet | 7.2min | 35 | 1 | $0.77 | bash | ok |
| Docker Image Tag Generator | bash | opus | 3.7min | 28 | 1 | $0.78 | bash | ok |
| Artifact Cleanup Script | default | sonnet | 6.3min | 31 | 2 | $0.83 | python | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| Environment Matrix Generator | bash | opus | 4.1min | 42 | 1 | $0.98 | bash | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 12.0min | 25 | 3 | $0.98 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| Artifact Cleanup Script | powershell | sonnet | 12.0min | 15 | 0 | $0.99 | powershell | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Environment Matrix Generator | default | sonnet | 7.8min | 36 | 5 | $1.05 | python | ok |
| Artifact Cleanup Script | powershell | opus | 5.4min | 29 | 2 | $1.07 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus | 6.0min | 42 | 3 | $1.10 | typescript | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 9.2min | 38 | 2 | $1.17 | typescript | ok |
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
| Artifact Cleanup Script | bash | opus | 5.7min | 50 | 2 | $1.50 | bash | ok |
| Secret Rotation Validator | default | opus | 7.3min | 38 | 1 | $1.51 | python | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus | 7.7min | 34 | 1 | $1.68 | typescript | ok |
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
| Artifact Cleanup Script | powershell | opus | 5.4min | 29 | 2 | $1.07 | powershell | ok |
| Docker Image Tag Generator | default | opus | 5.5min | 27 | 2 | $1.25 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Artifact Cleanup Script | bash | opus | 5.7min | 50 | 2 | $1.50 | bash | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Environment Matrix Generator | typescript-bun | opus | 6.0min | 42 | 3 | $1.10 | typescript | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Artifact Cleanup Script | default | sonnet | 6.3min | 31 | 2 | $0.83 | python | ok |
| Environment Matrix Generator | default | opus | 6.4min | 29 | 1 | $1.21 | python | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Artifact Cleanup Script | bash | sonnet | 7.2min | 35 | 1 | $0.77 | bash | ok |
| Secret Rotation Validator | default | opus | 7.3min | 38 | 1 | $1.51 | python | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| Artifact Cleanup Script | typescript-bun | opus | 7.7min | 34 | 1 | $1.68 | typescript | ok |
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
| Artifact Cleanup Script | typescript-bun | sonnet | 9.2min | 38 | 2 | $1.17 | typescript | ok |
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
| Artifact Cleanup Script | powershell | sonnet | 12.0min | 15 | 0 | $0.99 | powershell | ok |
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
| Artifact Cleanup Script | powershell | sonnet | 12.0min | 15 | 0 | $0.99 | powershell | ok |
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
| Artifact Cleanup Script | typescript-bun | opus | 7.7min | 34 | 1 | $1.68 | typescript | ok |
| Artifact Cleanup Script | bash | sonnet | 7.2min | 35 | 1 | $0.77 | bash | ok |
| Secret Rotation Validator | default | opus | 7.3min | 38 | 1 | $1.51 | python | ok |
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
| Artifact Cleanup Script | powershell | opus | 5.4min | 29 | 2 | $1.07 | powershell | ok |
| Artifact Cleanup Script | bash | opus | 5.7min | 50 | 2 | $1.50 | bash | ok |
| Artifact Cleanup Script | default | sonnet | 6.3min | 31 | 2 | $0.83 | python | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 9.2min | 38 | 2 | $1.17 | typescript | ok |
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
| Artifact Cleanup Script | powershell | sonnet | 12.0min | 15 | 0 | $0.99 | powershell | ok |
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
| Artifact Cleanup Script | powershell | opus | 5.4min | 29 | 2 | $1.07 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| Test Results Aggregator | bash | sonnet | 9.0min | 31 | 3 | $1.22 | bash | ok |
| Artifact Cleanup Script | default | sonnet | 6.3min | 31 | 2 | $0.83 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus | 7.7min | 34 | 1 | $1.68 | typescript | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| Docker Image Tag Generator | default | sonnet | 8.4min | 35 | 1 | $1.00 | python | ok |
| Docker Image Tag Generator | powershell | sonnet | 9.2min | 35 | 2 | $1.13 | powershell | ok |
| Test Results Aggregator | default | opus | 5.7min | 35 | 3 | $1.27 | python | ok |
| Test Results Aggregator | typescript-bun | sonnet | 10.9min | 35 | 1 | $1.41 | typescript | ok |
| Artifact Cleanup Script | bash | sonnet | 7.2min | 35 | 1 | $0.77 | bash | ok |
| Environment Matrix Generator | default | sonnet | 7.8min | 36 | 5 | $1.05 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus | 8.6min | 38 | 1 | $1.53 | typescript | ok |
| Environment Matrix Generator | powershell | opus | 5.3min | 38 | 3 | $1.25 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 9.2min | 38 | 2 | $1.17 | typescript | ok |
| Secret Rotation Validator | default | opus | 7.3min | 38 | 1 | $1.51 | python | ok |
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
| Artifact Cleanup Script | bash | opus | 5.7min | 50 | 2 | $1.50 | bash | ok |
| Environment Matrix Generator | powershell | sonnet | 11.5min | 54 | 1 | $1.46 | powershell | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*