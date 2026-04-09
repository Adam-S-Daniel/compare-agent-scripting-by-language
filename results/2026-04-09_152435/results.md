# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 06:47:41 PM ET

**Status:** 22/64 runs completed, 42 remaining
**Total cost so far:** $29.28
**Total agent time so far:** 189.9 min

## Observations

- **Fastest (avg):** default/opus — 6.9min, then typescript-bun/opus — 7.4min
- **Slowest (avg):** bash/sonnet — 11.1min, then powershell/sonnet — 10.8min
- **Cheapest (avg):** typescript-bun/sonnet — $0.93, then default/sonnet — $1.27
- **Most expensive (avg):** bash/sonnet — $1.55, then bash/opus — $1.44

- **Estimated time remaining:** 362.6min
- **Estimated total cost:** $85.18

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| bash | opus | 3 | 8.3min | 7.5min | 2.0 | 49 | $1.44 | $4.31 |
| bash | sonnet | 2 | 11.1min | 10.7min | 6.0 | 48 | $1.55 | $3.11 |
| default | opus | 3 | 6.9min | 6.9min | 1.0 | 32 | $1.38 | $4.14 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| powershell | opus | 3 | 8.1min | 8.1min | 1.7 | 33 | $1.40 | $4.21 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| typescript-bun | opus | 3 | 7.4min | 6.7min | 2.0 | 38 | $1.30 | $3.90 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1.0 | 36 | $0.93 | $1.86 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1.0 | 36 | $0.93 | $1.86 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| typescript-bun | opus | 3 | 7.4min | 6.7min | 2.0 | 38 | $1.30 | $3.90 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| default | opus | 3 | 6.9min | 6.9min | 1.0 | 32 | $1.38 | $4.14 |
| powershell | opus | 3 | 8.1min | 8.1min | 1.7 | 33 | $1.40 | $4.21 |
| bash | opus | 3 | 8.3min | 7.5min | 2.0 | 49 | $1.44 | $4.31 |
| bash | sonnet | 2 | 11.1min | 10.7min | 6.0 | 48 | $1.55 | $3.11 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 3 | 6.9min | 6.9min | 1.0 | 32 | $1.38 | $4.14 |
| typescript-bun | opus | 3 | 7.4min | 6.7min | 2.0 | 38 | $1.30 | $3.90 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1.0 | 36 | $0.93 | $1.86 |
| powershell | opus | 3 | 8.1min | 8.1min | 1.7 | 33 | $1.40 | $4.21 |
| bash | opus | 3 | 8.3min | 7.5min | 2.0 | 49 | $1.44 | $4.31 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| bash | sonnet | 2 | 11.1min | 10.7min | 6.0 | 48 | $1.55 | $3.11 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| typescript-bun | opus | 3 | 7.4min | 6.7min | 2.0 | 38 | $1.30 | $3.90 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1.0 | 36 | $0.93 | $1.86 |
| default | opus | 3 | 6.9min | 6.9min | 1.0 | 32 | $1.38 | $4.14 |
| bash | opus | 3 | 8.3min | 7.5min | 2.0 | 49 | $1.44 | $4.31 |
| powershell | opus | 3 | 8.1min | 8.1min | 1.7 | 33 | $1.40 | $4.21 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| bash | sonnet | 2 | 11.1min | 10.7min | 6.0 | 48 | $1.55 | $3.11 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 3 | 6.9min | 6.9min | 1.0 | 32 | $1.38 | $4.14 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1.0 | 36 | $0.93 | $1.86 |
| powershell | opus | 3 | 8.1min | 8.1min | 1.7 | 33 | $1.40 | $4.21 |
| bash | opus | 3 | 8.3min | 7.5min | 2.0 | 49 | $1.44 | $4.31 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| typescript-bun | opus | 3 | 7.4min | 6.7min | 2.0 | 38 | $1.30 | $3.90 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| bash | sonnet | 2 | 11.1min | 10.7min | 6.0 | 48 | $1.55 | $3.11 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|--------------------------|------------|-----------|----------|------------|
| default | opus | 3 | 6.9min | 6.9min | 1.0 | 32 | $1.38 | $4.14 |
| powershell | opus | 3 | 8.1min | 8.1min | 1.7 | 33 | $1.40 | $4.21 |
| typescript-bun | sonnet | 2 | 8.1min | 6.7min | 1.0 | 36 | $0.93 | $1.86 |
| typescript-bun | opus | 3 | 7.4min | 6.7min | 2.0 | 38 | $1.30 | $3.90 |
| default | sonnet | 3 | 9.0min | 8.5min | 2.7 | 43 | $1.27 | $3.81 |
| powershell | sonnet | 3 | 10.8min | 8.6min | 2.0 | 43 | $1.31 | $3.94 |
| bash | sonnet | 2 | 11.1min | 10.7min | 6.0 | 48 | $1.55 | $3.11 |
| bash | opus | 3 | 8.3min | 7.5min | 2.0 | 49 | $1.44 | $4.31 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus | 39 | 2 | 5.1% | 0.4min | 0.2% | 0.7min | 0.4% | -0.3min | -0.2% | 5.6min | -6.1% |
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.5% | 0.5min | 0.3% | 0.5min | 0.2% | 1.5min | 30.9% |
| default | opus | 25 | 2 | 8.0% | 0.3min | 0.1% | 0.3min | 0.1% | -0.0min | -0.0% | 1.3min | -1.2% |
| default | sonnet | 32 | 1 | 3.1% | 0.1min | 0.1% | 0.4min | 0.2% | -0.2min | -0.1% | 1.0min | -22.4% |
| powershell | opus | 33 | 2 | 6.1% | 1.2min | 0.6% | 0.6min | 0.3% | 0.6min | 0.3% | 3.5min | 16.4% |
| powershell | sonnet | 37 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.4% | -0.7min | -0.4% | 6.9min | -9.7% |
| typescript-bun | opus | 22 | 11 | 50.0% | 1.5min | 0.8% | 3.3min | 1.8% | -1.9min | -1.0% | 3.4min | -55.9% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.6% | 3.0min | 1.6% | -2.0min | -1.0% | 0.0min | -6934.0% |
| **Total** | | **236** | **31** | **13.1%** | **5.5min** | **2.9%** | **9.5min** | **5.0%** | **-4.0min** | **-2.1%** | **23.1min** | **-17.5%** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell | opus | 33 | 2 | 6.1% | 1.2min | 0.6% | 0.6min | 0.3% | 0.6min | 0.3% | 3.5min | 16.4% |
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.5% | 0.5min | 0.3% | 0.5min | 0.2% | 1.5min | 30.9% |
| default | opus | 25 | 2 | 8.0% | 0.3min | 0.1% | 0.3min | 0.1% | -0.0min | -0.0% | 1.3min | -1.2% |
| default | sonnet | 32 | 1 | 3.1% | 0.1min | 0.1% | 0.4min | 0.2% | -0.2min | -0.1% | 1.0min | -22.4% |
| bash | opus | 39 | 2 | 5.1% | 0.4min | 0.2% | 0.7min | 0.4% | -0.3min | -0.2% | 5.6min | -6.1% |
| powershell | sonnet | 37 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.4% | -0.7min | -0.4% | 6.9min | -9.7% |
| typescript-bun | opus | 22 | 11 | 50.0% | 1.5min | 0.8% | 3.3min | 1.8% | -1.9min | -1.0% | 3.4min | -55.9% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.6% | 3.0min | 1.6% | -2.0min | -1.0% | 0.0min | -6934.0% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.5% | 0.5min | 0.3% | 0.5min | 0.2% | 1.5min | 30.9% |
| powershell | opus | 33 | 2 | 6.1% | 1.2min | 0.6% | 0.6min | 0.3% | 0.6min | 0.3% | 3.5min | 16.4% |
| default | opus | 25 | 2 | 8.0% | 0.3min | 0.1% | 0.3min | 0.1% | -0.0min | -0.0% | 1.3min | -1.2% |
| bash | opus | 39 | 2 | 5.1% | 0.4min | 0.2% | 0.7min | 0.4% | -0.3min | -0.2% | 5.6min | -6.1% |
| powershell | sonnet | 37 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.4% | -0.7min | -0.4% | 6.9min | -9.7% |
| default | sonnet | 32 | 1 | 3.1% | 0.1min | 0.1% | 0.4min | 0.2% | -0.2min | -0.1% | 1.0min | -22.4% |
| typescript-bun | opus | 22 | 11 | 50.0% | 1.5min | 0.8% | 3.3min | 1.8% | -1.9min | -1.0% | 3.4min | -55.9% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.6% | 3.0min | 1.6% | -2.0min | -1.0% | 0.0min | -6934.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus | 22 | 11 | 50.0% | 1.5min | 0.8% | 3.3min | 1.8% | -1.9min | -1.0% | 3.4min | -55.9% |
| typescript-bun | sonnet | 20 | 8 | 40.0% | 1.1min | 0.6% | 3.0min | 1.6% | -2.0min | -1.0% | 0.0min | -6934.0% |
| bash | sonnet | 28 | 5 | 17.9% | 1.0min | 0.5% | 0.5min | 0.3% | 0.5min | 0.2% | 1.5min | 30.9% |
| default | opus | 25 | 2 | 8.0% | 0.3min | 0.1% | 0.3min | 0.1% | -0.0min | -0.0% | 1.3min | -1.2% |
| powershell | opus | 33 | 2 | 6.1% | 1.2min | 0.6% | 0.6min | 0.3% | 0.6min | 0.3% | 3.5min | 16.4% |
| bash | opus | 39 | 2 | 5.1% | 0.4min | 0.2% | 0.7min | 0.4% | -0.3min | -0.2% | 5.6min | -6.1% |
| default | sonnet | 32 | 1 | 3.1% | 0.1min | 0.1% | 0.4min | 0.2% | -0.2min | -0.1% | 1.0min | -22.4% |
| powershell | sonnet | 37 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.4% | -0.7min | -0.4% | 6.9min | -9.7% |

</details>

### Trap Analysis by Language/Model/Category

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus | 3 | 2.2min | 1.2% | $0.41 | 1.39% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 0.8% | $0.18 | 0.63% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.4% | $0.11 | 0.38% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 0.8% | $0.21 | 0.71% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.6% | $0.13 | 0.45% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.5% | $0.22 | 0.74% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.9% | $0.27 | 0.94% |
| repeated-test-reruns | powershell | sonnet | 2 | 2.7min | 1.4% | $0.34 | 1.17% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.2% | $0.28 | 0.96% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.4% | $0.11 | 0.39% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.4% | $0.09 | 0.30% |
| **Total** | | | **12 runs** | **16.5min** | **8.7%** | **$2.36** | **8.05%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.4% | $0.09 | 0.30% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.4% | $0.11 | 0.39% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.4% | $0.11 | 0.38% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.5% | $0.22 | 0.74% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.6% | $0.13 | 0.45% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 0.8% | $0.21 | 0.71% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 0.8% | $0.18 | 0.63% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.9% | $0.27 | 0.94% |
| ts-type-error-fix-cycles | typescript-bun | opus | 3 | 2.2min | 1.2% | $0.41 | 1.39% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.2% | $0.28 | 0.96% |
| repeated-test-reruns | powershell | sonnet | 2 | 2.7min | 1.4% | $0.34 | 1.17% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.4% | $0.09 | 0.30% |
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.4% | $0.11 | 0.38% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.4% | $0.11 | 0.39% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.6% | $0.13 | 0.45% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 0.8% | $0.18 | 0.63% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 0.8% | $0.21 | 0.71% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.5% | $0.22 | 0.74% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.9% | $0.27 | 0.94% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.2% | $0.28 | 0.96% |
| repeated-test-reruns | powershell | sonnet | 2 | 2.7min | 1.4% | $0.34 | 1.17% |
| ts-type-error-fix-cycles | typescript-bun | opus | 3 | 2.2min | 1.2% | $0.41 | 1.39% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Mode | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | opus | 1 | 0.8min | 0.4% | $0.11 | 0.38% |
| act-push-debug-loops | default | sonnet | 1 | 1.5min | 0.8% | $0.21 | 0.71% |
| act-push-debug-loops | typescript-bun | sonnet | 1 | 1.2min | 0.6% | $0.13 | 0.45% |
| fixture-rework | bash | opus | 1 | 1.0min | 0.5% | $0.22 | 0.74% |
| fixture-rework | powershell | sonnet | 1 | 1.8min | 0.9% | $0.27 | 0.94% |
| docker-pwsh-install | powershell | sonnet | 1 | 2.2min | 1.2% | $0.28 | 0.96% |
| bats-setup-issues | bash | sonnet | 1 | 0.8min | 0.4% | $0.11 | 0.39% |
| actionlint-fix-cycles | bash | opus | 1 | 0.7min | 0.4% | $0.09 | 0.30% |
| ts-type-error-fix-cycles | typescript-bun | sonnet | 2 | 1.6min | 0.8% | $0.18 | 0.63% |
| repeated-test-reruns | powershell | sonnet | 2 | 2.7min | 1.4% | $0.34 | 1.17% |
| ts-type-error-fix-cycles | typescript-bun | opus | 3 | 2.2min | 1.2% | $0.41 | 1.39% |

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
| bash | opus | 3 | 2 | 67% | 3 | 2.5min | 1.3% | $0.42 | 1.42% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.4% | $0.11 | 0.39% |
| default | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 3 | 1 | 33% | 1 | 1.5min | 0.8% | $0.21 | 0.71% |
| powershell | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 3 | 3 | 100% | 4 | 6.7min | 3.5% | $0.90 | 3.06% |
| typescript-bun | opus | 3 | 3 | 100% | 3 | 2.2min | 1.2% | $0.41 | 1.39% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 1.5% | $0.32 | 1.08% |
| **Total** | | **22** | **12** | **55%** | **15** | **16.5min** | **8.7%** | **$2.36** | **8.05%** |


<details>
<summary>Sorted by time lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.4% | $0.11 | 0.39% |
| default | sonnet | 3 | 1 | 33% | 1 | 1.5min | 0.8% | $0.21 | 0.71% |
| typescript-bun | opus | 3 | 3 | 100% | 3 | 2.2min | 1.2% | $0.41 | 1.39% |
| bash | opus | 3 | 2 | 67% | 3 | 2.5min | 1.3% | $0.42 | 1.42% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 1.5% | $0.32 | 1.08% |
| powershell | sonnet | 3 | 3 | 100% | 4 | 6.7min | 3.5% | $0.90 | 3.06% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.4% | $0.11 | 0.39% |
| default | sonnet | 3 | 1 | 33% | 1 | 1.5min | 0.8% | $0.21 | 0.71% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 1.5% | $0.32 | 1.08% |
| typescript-bun | opus | 3 | 3 | 100% | 3 | 2.2min | 1.2% | $0.41 | 1.39% |
| bash | opus | 3 | 2 | 67% | 3 | 2.5min | 1.3% | $0.42 | 1.42% |
| powershell | sonnet | 3 | 3 | 100% | 4 | 6.7min | 3.5% | $0.90 | 3.06% |

</details>

<details>
<summary>Sorted by trap rate (lowest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 3 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 3 | 1 | 33% | 1 | 1.5min | 0.8% | $0.21 | 0.71% |
| bash | sonnet | 2 | 1 | 50% | 1 | 0.8min | 0.4% | $0.11 | 0.39% |
| bash | opus | 3 | 2 | 67% | 3 | 2.5min | 1.3% | $0.42 | 1.42% |
| powershell | sonnet | 3 | 3 | 100% | 4 | 6.7min | 3.5% | $0.90 | 3.06% |
| typescript-bun | opus | 3 | 3 | 100% | 3 | 2.2min | 1.2% | $0.41 | 1.39% |
| typescript-bun | sonnet | 2 | 2 | 100% | 3 | 2.8min | 1.5% | $0.32 | 1.08% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 20 | $2.52 | 8.60% |
| Miss | 2 | $0.00 | 0.00% |
| **Total** | **22** | **$2.52** | **8.60%** |

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


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
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
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Mode | Model | Duration | Turns | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|--------|------|----------|--------|
| Semantic Version Bumper | powershell | opus | 6.9min | 27 | 0 | $1.04 | powershell | ok |
| Semantic Version Bumper | default | opus | 7.1min | 28 | 1 | $1.33 | python | ok |
| PR Label Assigner | default | opus | 7.7min | 29 | 2 | $1.57 | python | ok |
| PR Label Assigner | powershell | sonnet | 8.7min | 29 | 1 | $1.09 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 8.1min | 30 | 1 | $0.97 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus | 10.3min | 32 | 1 | $1.54 | typescript | ok |
| PR Label Assigner | typescript-bun | opus | 5.1min | 33 | 2 | $1.01 | typescript | ok |
| PR Label Assigner | powershell | opus | 11.4min | 35 | 2 | $1.93 | powershell | ok |
| Dependency License Checker | powershell | opus | 6.0min | 38 | 3 | $1.24 | powershell | ok |
| PR Label Assigner | bash | sonnet | 13.2min | 39 | 6 | $1.73 | bash | ok |
| Dependency License Checker | default | opus | 5.9min | 39 | 0 | $1.24 | python | ok |
| Dependency License Checker | default | sonnet | 9.2min | 39 | 3 | $1.30 | python | ok |
| PR Label Assigner | bash | opus | 5.6min | 42 | 2 | $1.16 | bash | ok |
| Semantic Version Bumper | powershell | sonnet | 11.4min | 43 | 3 | $0.92 | powershell | ok |
| PR Label Assigner | default | sonnet | 10.3min | 43 | 4 | $1.52 | python | ok |
| PR Label Assigner | typescript-bun | sonnet | 8.1min | 43 | 1 | $0.89 | typescript | ok |
| Semantic Version Bumper | default | sonnet | 7.3min | 46 | 1 | $0.99 | python | ok |
| Dependency License Checker | typescript-bun | opus | 6.8min | 48 | 3 | $1.35 | typescript | ok |
| Semantic Version Bumper | bash | opus | 12.4min | 50 | 1 | $1.65 | bash | ok |
| Dependency License Checker | bash | opus | 6.9min | 55 | 3 | $1.50 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 9.0min | 57 | 6 | $1.38 | bash | ok |
| Dependency License Checker | powershell | sonnet | 12.3min | 58 | 2 | $1.93 | powershell | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*