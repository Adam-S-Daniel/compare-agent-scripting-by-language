# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 10:36:04 AM ET

**Status:** 2/2 runs completed, 0 remaining
**Total cost so far:** $2.28
**Total agent time so far:** 1399s (23.3 min)

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | sonnet | 1 | 818s | 1300 | 5.0 | 33 | $1.33 | $1.33 |
| powershell | sonnet | 1 | 581s | 1181 | 1.0 | 38 | $0.96 | $0.96 |


<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | sonnet | 1 | 581s | 1181 | 1.0 | 38 | $0.96 | $0.96 |
| default | sonnet | 1 | 818s | 1300 | 5.0 | 33 | $1.33 | $1.33 |

</details>

<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | sonnet | 1 | 581s | 1181 | 1.0 | 38 | $0.96 | $0.96 |
| default | sonnet | 1 | 818s | 1300 | 5.0 | 33 | $1.33 | $1.33 |

</details>

<details>
<summary>Sorted by avg errors (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | sonnet | 1 | 818s | 1300 | 5.0 | 33 | $1.33 | $1.33 |
| powershell | sonnet | 1 | 581s | 1181 | 1.0 | 38 | $0.96 | $0.96 |

</details>

<details>
<summary>Sorted by total cost (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| default | sonnet | 1 | 818s | 1300 | 5.0 | 33 | $1.33 | $1.33 |
| powershell | sonnet | 1 | 581s | 1181 | 1.0 | 38 | $0.96 | $0.96 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | sonnet | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.0min | 0.0% |
| powershell | sonnet | 14 | 1 | 7.1% | 0.6min | 2.5% | 0.1min | 0.5% | 0.5min | 2.0% | 0.0min | 0.0% |
| **—** | **—** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | sonnet | 14 | 1 | 7.1% | 0.6min | 2.5% | 0.1min | 0.5% | 0.5min | 2.0% | 0.0min | 0.0% |
| default | sonnet | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | sonnet | 14 | 1 | 7.1% | 0.6min | 2.5% | 0.1min | 0.5% | 0.5min | 2.0% | 0.0min | 0.0% |
| default | sonnet | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by overhead (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | sonnet | 14 | 1 | 7.1% | 0.6min | 2.5% | 0.1min | 0.5% | 0.5min | 2.0% | 0.0min | 0.0% |
| default | sonnet | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by test run time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | sonnet | 13 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.5% | -0.1min | -0.5% | 0.0min | 0.0% |
| powershell | sonnet | 14 | 1 | 7.1% | 0.6min | 2.5% | 0.1min | 0.5% | 0.5min | 2.0% | 0.0min | 0.0% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 2 | $0.08 | 3.41% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **2** | **$0.08** | **3.41%** |

### Trap Analysis by Category

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 2 | 1 | 1 | 50% | 1.0min | 4.3% | $0.10 | 4.26% |
| **Total** | | **1 runs** | | **50%** | **1.0min** | **4.3%** | **$0.10** | **4.26%** |


<details>
<summary>Sorted by $ lost (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 2 | 1 | 1 | 50% | 1.0min | 4.3% | $0.10 | 4.26% |

</details>

<details>
<summary>Sorted by rate (highest first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 2 | 1 | 1 | 50% | 1.0min | 4.3% | $0.10 | 4.26% |

</details>

<details>
<summary>Sorted by runs affected (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 2 | 1 | 1 | 50% | 1.0min | 4.3% | $0.10 | 4.26% |

</details>

### Traps by Language/Model

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | sonnet | 1 | 1 | 100% | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| **Total** | | **2** | **1** | **50%** | **1** | **1.0min** | **4.3%** | **$0.10** | **4.26%** |


<details>
<summary>Sorted by time lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | sonnet | 1 | 1 | 100% | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

<details>
<summary>Sorted by $ lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | sonnet | 1 | 1 | 100% | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

<details>
<summary>Sorted by trap rate (highest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | sonnet | 1 | 1 | 100% | 1 | 1.0min | 4.3% | $0.10 | 4.26% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | sonnet | 818s | 33 | 1300 | 5 | $1.33 | python | ok |
| Semantic Version Bumper | powershell | sonnet | 581s | 38 | 1181 | 1 | $0.96 | powershell | ok |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Δ | Def Cost | Mode Cost | Cost Δ | Err Δ |
|------|-------|------|-------------|---------|----------|-------|----------|-----------|--------|-------|
| Semantic Version Bumper | sonnet | powershell | python | 818s | 581s | -29% | $1.33 | $0.96 | -28% | -4 |

## Observations

- **Fastest run:** Semantic Version Bumper / powershell / sonnet — 581s
- **Slowest run:** Semantic Version Bumper / default / sonnet — 818s
- **Most errors:** Semantic Version Bumper / default / sonnet — 5 errors
- **Fewest errors:** Semantic Version Bumper / powershell / sonnet — 1 errors

- **Avg cost per run (sonnet):** $1.14


---
*Generated by runner.py, instructions version v3*