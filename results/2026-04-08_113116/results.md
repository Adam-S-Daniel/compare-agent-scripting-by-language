# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 10:36:04 AM ET

**Status:** 1/1 runs completed, 0 remaining
**Total cost so far:** $1.16
**Total agent time so far:** 317s (5.3 min)

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 3.5% | -0.2min | -3.5% | 0.0min | 0.0% |
| **—** | **—** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 3.5% | -0.2min | -3.5% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 3.5% | -0.2min | -3.5% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by overhead (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 3.5% | -0.2min | -3.5% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by test run time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| default | opus | 22 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 3.5% | -0.2min | -3.5% | 0.0min | 0.0% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 1 | $0.20 | 16.94% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **1** | **$0.20** | **16.94%** |

### Trap Analysis by Category

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 1 | 1 | 0 | 100% | 2.3min | 44.1% | $0.51 | 44.09% |
| **Total** | | **1 runs** | | **100%** | **2.3min** | **44.1%** | **$0.51** | **44.09%** |


<details>
<summary>Sorted by $ lost (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 1 | 1 | 0 | 100% | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

<details>
<summary>Sorted by rate (highest first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 1 | 1 | 0 | 100% | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

<details>
<summary>Sorted by runs affected (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 1 | 1 | 0 | 100% | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

### Traps by Language/Model

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 44.1% | $0.51 | 44.09% |
| **Total** | | **1** | **1** | **100%** | **1** | **2.3min** | **44.1%** | **$0.51** | **44.09%** |


<details>
<summary>Sorted by time lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

<details>
<summary>Sorted by $ lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

<details>
<summary>Sorted by trap rate (highest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 2.3min | 44.1% | $0.51 | 44.09% |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | default | opus | 317s | 42 | 504 | 1 | $1.16 | python | ok |

## Observations


---
*Generated by runner.py, instructions version v3*