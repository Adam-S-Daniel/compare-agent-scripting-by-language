# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 10:36:04 AM ET

**Status:** 4/4 runs completed, 0 remaining
**Total cost so far:** $6.95
**Total agent time so far:** 1903s (31.7 min)

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | opus | 1 | 331s | 1016 | 2.0 | 45 | $1.22 | $1.22 |
| default | opus | 1 | 496s | 896 | 1.0 | 77 | $2.39 | $2.39 |
| powershell | opus | 1 | 751s | 1033 | 0.0 | 71 | $2.40 | $2.40 |
| typescript-bun | opus | 1 | 325s | 1029 | 2.0 | 33 | $0.93 | $0.93 |


<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| typescript-bun | opus | 1 | 325s | 1029 | 2.0 | 33 | $0.93 | $0.93 |
| bash | opus | 1 | 331s | 1016 | 2.0 | 45 | $1.22 | $1.22 |
| default | opus | 1 | 496s | 896 | 1.0 | 77 | $2.39 | $2.39 |
| powershell | opus | 1 | 751s | 1033 | 0.0 | 71 | $2.40 | $2.40 |

</details>

<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| typescript-bun | opus | 1 | 325s | 1029 | 2.0 | 33 | $0.93 | $0.93 |
| bash | opus | 1 | 331s | 1016 | 2.0 | 45 | $1.22 | $1.22 |
| default | opus | 1 | 496s | 896 | 1.0 | 77 | $2.39 | $2.39 |
| powershell | opus | 1 | 751s | 1033 | 0.0 | 71 | $2.40 | $2.40 |

</details>

<details>
<summary>Sorted by avg errors (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | opus | 1 | 331s | 1016 | 2.0 | 45 | $1.22 | $1.22 |
| typescript-bun | opus | 1 | 325s | 1029 | 2.0 | 33 | $0.93 | $0.93 |
| default | opus | 1 | 496s | 896 | 1.0 | 77 | $2.39 | $2.39 |
| powershell | opus | 1 | 751s | 1033 | 0.0 | 71 | $2.40 | $2.40 |

</details>

<details>
<summary>Sorted by total cost (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | opus | 1 | 751s | 1033 | 0.0 | 71 | $2.40 | $2.40 |
| default | opus | 1 | 496s | 896 | 1.0 | 77 | $2.39 | $2.39 |
| bash | opus | 1 | 331s | 1016 | 2.0 | 45 | $1.22 | $1.22 |
| typescript-bun | opus | 1 | 325s | 1029 | 2.0 | 33 | $0.93 | $0.93 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| default | opus | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.7% | -0.2min | -0.7% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.6% | -0.2min | -0.6% | 0.0min | 0.0% |
| typescript-bun | opus | 12 | 6 | 50.0% | 0.8min | 2.5% | 0.1min | 0.3% | 0.7min | 2.2% | 0.0min | 0.0% |
| **—** | **—** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 12 | 6 | 50.0% | 0.8min | 2.5% | 0.1min | 0.3% | 0.7min | 2.2% | 0.0min | 0.0% |
| bash | opus | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.6% | -0.2min | -0.6% | 0.0min | 0.0% |
| default | opus | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.7% | -0.2min | -0.7% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 12 | 6 | 50.0% | 0.8min | 2.5% | 0.1min | 0.3% | 0.7min | 2.2% | 0.0min | 0.0% |
| bash | opus | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| default | opus | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.7% | -0.2min | -0.7% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.6% | -0.2min | -0.6% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by overhead (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.7% | -0.2min | -0.7% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.6% | -0.2min | -0.6% | 0.0min | 0.0% |
| bash | opus | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| typescript-bun | opus | 12 | 6 | 50.0% | 0.8min | 2.5% | 0.1min | 0.3% | 0.7min | 2.2% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by test run time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 14 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.4% | -0.1min | -0.4% | 0.0min | 0.0% |
| default | opus | 25 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.7% | -0.2min | -0.7% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.6% | -0.2min | -0.6% | 0.0min | 0.0% |
| typescript-bun | opus | 12 | 6 | 50.0% | 0.8min | 2.5% | 0.1min | 0.3% | 0.7min | 2.2% | 0.0min | 0.0% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 4 | $0.79 | 11.33% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **4** | **$0.79** | **11.33%** |

### Trap Analysis by Category

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 4 | 2 | 2 | 50% | 5.0min | 15.8% | $1.19 | 17.10% |
| ts-type-error-fix-cycles | 1 | 1 | 0 | 100% | 1.2min | 3.8% | $0.21 | 2.97% |
| act-push-debug-loops | 4 | 1 | 3 | 25% | 0.8min | 2.6% | $0.16 | 2.31% |
| **Total** | | **3 runs** | | **75%** | **7.0min** | **22.2%** | **$1.55** | **22.38%** |


<details>
<summary>Sorted by $ lost (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 4 | 2 | 2 | 50% | 5.0min | 15.8% | $1.19 | 17.10% |
| ts-type-error-fix-cycles | 1 | 1 | 0 | 100% | 1.2min | 3.8% | $0.21 | 2.97% |
| act-push-debug-loops | 4 | 1 | 3 | 25% | 0.8min | 2.6% | $0.16 | 2.31% |

</details>

<details>
<summary>Sorted by rate (highest first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | 1 | 1 | 0 | 100% | 1.2min | 3.8% | $0.21 | 2.97% |
| repeated-test-reruns | 4 | 2 | 2 | 50% | 5.0min | 15.8% | $1.19 | 17.10% |
| act-push-debug-loops | 4 | 1 | 3 | 25% | 0.8min | 2.6% | $0.16 | 2.31% |

</details>

<details>
<summary>Sorted by runs affected (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 4 | 2 | 2 | 50% | 5.0min | 15.8% | $1.19 | 17.10% |
| ts-type-error-fix-cycles | 1 | 1 | 0 | 100% | 1.2min | 3.8% | $0.21 | 2.97% |
| act-push-debug-loops | 4 | 1 | 3 | 25% | 0.8min | 2.6% | $0.16 | 2.31% |

</details>

### Traps by Language/Model

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 7.4% | $0.68 | 9.72% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.5min | 11.0% | $0.67 | 9.69% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| **Total** | | **4** | **3** | **75%** | **4** | **7.0min** | **22.2%** | **$1.55** | **22.38%** |


<details>
<summary>Sorted by time lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell | opus | 1 | 1 | 100% | 2 | 3.5min | 11.0% | $0.67 | 9.69% |
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 7.4% | $0.68 | 9.72% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

<details>
<summary>Sorted by $ lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 7.4% | $0.68 | 9.72% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.5min | 11.0% | $0.67 | 9.69% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

<details>
<summary>Sorted by trap rate (highest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 7.4% | $0.68 | 9.72% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.5min | 11.0% | $0.67 | 9.69% |
| typescript-bun | opus | 1 | 1 | 100% | 1 | 1.2min | 3.8% | $0.21 | 2.97% |
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 331s | 45 | 1016 | 2 | $1.22 | bash | ok |
| Semantic Version Bumper | default | opus | 496s | 77 | 896 | 1 | $2.39 | python | ok |
| Semantic Version Bumper | powershell | opus | 751s | 71 | 1033 | 0 | $2.40 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 325s | 33 | 1029 | 2 | $0.93 | typescript | ok |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Δ | Def Cost | Mode Cost | Cost Δ | Err Δ |
|------|-------|------|-------------|---------|----------|-------|----------|-----------|--------|-------|
| Semantic Version Bumper | opus | bash | python | 496s | 331s | -33% | $2.39 | $1.22 | -49% | +1 |
| Semantic Version Bumper | opus | powershell | python | 496s | 751s | +51% | $2.39 | $2.40 | +1% | -1 |
| Semantic Version Bumper | opus | typescript-bun | python | 496s | 325s | -34% | $2.39 | $0.93 | -61% | +1 |

## Observations

- **Fastest run:** Semantic Version Bumper / typescript-bun / opus — 325s
- **Slowest run:** Semantic Version Bumper / powershell / opus — 751s
- **Most errors:** Semantic Version Bumper / bash / opus — 2 errors
- **Fewest errors:** Semantic Version Bumper / powershell / opus — 0 errors

- **Avg cost per run (opus):** $1.74


---
*Generated by runner.py, instructions version v3*