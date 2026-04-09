# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 10:36:04 AM ET

**Status:** 3/3 runs completed, 0 remaining
**Total cost so far:** $2.91
**Total agent time so far:** 878s (14.6 min)

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | opus | 1 | 144s | 420 | 1.0 | 22 | $0.51 | $0.51 |
| default | opus | 1 | 297s | 692 | 1.0 | 39 | $0.92 | $0.92 |
| powershell | opus | 1 | 438s | 692 | 0.0 | 54 | $1.48 | $1.48 |


<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | opus | 1 | 144s | 420 | 1.0 | 22 | $0.51 | $0.51 |
| default | opus | 1 | 297s | 692 | 1.0 | 39 | $0.92 | $0.92 |
| powershell | opus | 1 | 438s | 692 | 0.0 | 54 | $1.48 | $1.48 |

</details>

<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | opus | 1 | 144s | 420 | 1.0 | 22 | $0.51 | $0.51 |
| default | opus | 1 | 297s | 692 | 1.0 | 39 | $0.92 | $0.92 |
| powershell | opus | 1 | 438s | 692 | 0.0 | 54 | $1.48 | $1.48 |

</details>

<details>
<summary>Sorted by avg errors (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | opus | 1 | 144s | 420 | 1.0 | 22 | $0.51 | $0.51 |
| default | opus | 1 | 297s | 692 | 1.0 | 39 | $0.92 | $0.92 |
| powershell | opus | 1 | 438s | 692 | 0.0 | 54 | $1.48 | $1.48 |

</details>

<details>
<summary>Sorted by total cost (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| powershell | opus | 1 | 438s | 692 | 0.0 | 54 | $1.48 | $1.48 |
| default | opus | 1 | 297s | 692 | 1.0 | 39 | $0.92 | $0.92 |
| bash | opus | 1 | 144s | 420 | 1.0 | 22 | $0.51 | $0.51 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 11 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 0.0min | 0.0% |
| default | opus | 15 | 3 | 20.0% | 0.4min | 2.7% | 0.1min | 0.9% | 0.3min | 1.9% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 1.3% | -0.2min | -1.3% | 0.0min | 0.0% |
| **—** | **—** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 15 | 3 | 20.0% | 0.4min | 2.7% | 0.1min | 0.9% | 0.3min | 1.9% | 0.0min | 0.0% |
| bash | opus | 11 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 1.3% | -0.2min | -1.3% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 15 | 3 | 20.0% | 0.4min | 2.7% | 0.1min | 0.9% | 0.3min | 1.9% | 0.0min | 0.0% |
| bash | opus | 11 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 1.3% | -0.2min | -1.3% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by overhead (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 1.3% | -0.2min | -1.3% | 0.0min | 0.0% |
| default | opus | 15 | 3 | 20.0% | 0.4min | 2.7% | 0.1min | 0.9% | 0.3min | 1.9% | 0.0min | 0.0% |
| bash | opus | 11 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by test run time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 11 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.6% | -0.1min | -0.6% | 0.0min | 0.0% |
| default | opus | 15 | 3 | 20.0% | 0.4min | 2.7% | 0.1min | 0.9% | 0.3min | 1.9% | 0.0min | 0.0% |
| powershell | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 1.3% | -0.2min | -1.3% | 0.0min | 0.0% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 3 | $0.59 | 20.30% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **3** | **$0.59** | **20.30%** |

### Trap Analysis by Category

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 3 | 2 | 1 | 67% | 4.7min | 31.9% | $0.93 | 31.97% |
| **Total** | | **2 runs** | | **67%** | **4.7min** | **31.9%** | **$0.93** | **31.97%** |


<details>
<summary>Sorted by $ lost (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 3 | 2 | 1 | 67% | 4.7min | 31.9% | $0.93 | 31.97% |

</details>

<details>
<summary>Sorted by rate (highest first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 3 | 2 | 1 | 67% | 4.7min | 31.9% | $0.93 | 31.97% |

</details>

<details>
<summary>Sorted by runs affected (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 3 | 2 | 1 | 67% | 4.7min | 31.9% | $0.93 | 31.97% |

</details>

### Traps by Language/Model

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| powershell | opus | 1 | 1 | 100% | 1 | 3.7min | 25.0% | $0.74 | 25.55% |
| **Total** | | **3** | **2** | **67%** | **2** | **4.7min** | **31.9%** | **$0.93** | **31.97%** |


<details>
<summary>Sorted by time lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell | opus | 1 | 1 | 100% | 1 | 3.7min | 25.0% | $0.74 | 25.55% |
| default | opus | 1 | 1 | 100% | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

<details>
<summary>Sorted by $ lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| powershell | opus | 1 | 1 | 100% | 1 | 3.7min | 25.0% | $0.74 | 25.55% |
| default | opus | 1 | 1 | 100% | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

<details>
<summary>Sorted by trap rate (highest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 1.0min | 6.8% | $0.19 | 6.41% |
| powershell | opus | 1 | 1 | 100% | 1 | 3.7min | 25.0% | $0.74 | 25.55% |
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 144s | 22 | 420 | 1 | $0.51 | bash | ok |
| Semantic Version Bumper | default | opus | 297s | 39 | 692 | 1 | $0.92 | typescript | ok |
| Semantic Version Bumper | powershell | opus | 438s | 54 | 692 | 0 | $1.48 | powershell | ok |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Δ | Def Cost | Mode Cost | Cost Δ | Err Δ |
|------|-------|------|-------------|---------|----------|-------|----------|-----------|--------|-------|
| Semantic Version Bumper | opus | bash | typescript | 297s | 144s | -52% | $0.92 | $0.51 | -45% | +0 |
| Semantic Version Bumper | opus | powershell | typescript | 297s | 438s | +48% | $0.92 | $1.48 | +61% | -1 |

## Observations

- **Fastest run:** Semantic Version Bumper / bash / opus — 144s
- **Slowest run:** Semantic Version Bumper / powershell / opus — 438s
- **Most errors:** Semantic Version Bumper / bash / opus — 1 errors
- **Fewest errors:** Semantic Version Bumper / powershell / opus — 0 errors

- **Avg cost per run (opus):** $0.97


---
*Generated by runner.py, instructions version v3*