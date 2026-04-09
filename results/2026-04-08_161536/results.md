# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 10:36:04 AM ET

**Status:** 7/7 runs completed, 0 remaining
**Total cost so far:** $6.59
**Total agent time so far:** 2605s (43.4 min)

## Comparison by Language/Model

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | opus | 1 | 202s | 691 | 2.0 | 27 | $0.76 | $0.76 |
| bash | sonnet | 1 | 163s | 586 | 3.0 | 24 | $0.40 | $0.40 |
| default | opus | 1 | 856s | 649 | 2.0 | 39 | $1.12 | $1.12 |
| default | sonnet | 1 | 176s | 693 | 1.0 | 19 | $0.45 | $0.45 |
| powershell | opus | 1 | 473s | 656 | 2.0 | 50 | $1.51 | $1.51 |
| powershell | sonnet | 1 | 192s | 593 | 0.0 | 22 | $0.50 | $0.50 |
| typescript-bun | opus | 1 | 543s | 1205 | 8.0 | 65 | $1.84 | $1.84 |


<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | sonnet | 1 | 163s | 586 | 3.0 | 24 | $0.40 | $0.40 |
| default | sonnet | 1 | 176s | 693 | 1.0 | 19 | $0.45 | $0.45 |
| powershell | sonnet | 1 | 192s | 593 | 0.0 | 22 | $0.50 | $0.50 |
| bash | opus | 1 | 202s | 691 | 2.0 | 27 | $0.76 | $0.76 |
| powershell | opus | 1 | 473s | 656 | 2.0 | 50 | $1.51 | $1.51 |
| typescript-bun | opus | 1 | 543s | 1205 | 8.0 | 65 | $1.84 | $1.84 |
| default | opus | 1 | 856s | 649 | 2.0 | 39 | $1.12 | $1.12 |

</details>

<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | sonnet | 1 | 163s | 586 | 3.0 | 24 | $0.40 | $0.40 |
| default | sonnet | 1 | 176s | 693 | 1.0 | 19 | $0.45 | $0.45 |
| powershell | sonnet | 1 | 192s | 593 | 0.0 | 22 | $0.50 | $0.50 |
| bash | opus | 1 | 202s | 691 | 2.0 | 27 | $0.76 | $0.76 |
| default | opus | 1 | 856s | 649 | 2.0 | 39 | $1.12 | $1.12 |
| powershell | opus | 1 | 473s | 656 | 2.0 | 50 | $1.51 | $1.51 |
| typescript-bun | opus | 1 | 543s | 1205 | 8.0 | 65 | $1.84 | $1.84 |

</details>

<details>
<summary>Sorted by avg errors (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| typescript-bun | opus | 1 | 543s | 1205 | 8.0 | 65 | $1.84 | $1.84 |
| bash | sonnet | 1 | 163s | 586 | 3.0 | 24 | $0.40 | $0.40 |
| bash | opus | 1 | 202s | 691 | 2.0 | 27 | $0.76 | $0.76 |
| default | opus | 1 | 856s | 649 | 2.0 | 39 | $1.12 | $1.12 |
| powershell | opus | 1 | 473s | 656 | 2.0 | 50 | $1.51 | $1.51 |
| default | sonnet | 1 | 176s | 693 | 1.0 | 19 | $0.45 | $0.45 |
| powershell | sonnet | 1 | 192s | 593 | 0.0 | 22 | $0.50 | $0.50 |

</details>

<details>
<summary>Sorted by total cost (most first)</summary>

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| typescript-bun | opus | 1 | 543s | 1205 | 8.0 | 65 | $1.84 | $1.84 |
| powershell | opus | 1 | 473s | 656 | 2.0 | 50 | $1.51 | $1.51 |
| default | opus | 1 | 856s | 649 | 2.0 | 39 | $1.12 | $1.12 |
| bash | opus | 1 | 202s | 691 | 2.0 | 27 | $0.76 | $0.76 |
| powershell | sonnet | 1 | 192s | 593 | 0.0 | 22 | $0.50 | $0.50 |
| default | sonnet | 1 | 176s | 693 | 1.0 | 19 | $0.45 | $0.45 |
| bash | sonnet | 1 | 163s | 586 | 3.0 | 24 | $0.40 | $0.40 |

</details>

## Savings Analysis

### Hook Savings by Language/Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 8 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| bash | sonnet | 11 | 2 | 18.2% | 0.4min | 0.9% | 0.1min | 0.2% | 0.3min | 0.7% | 0.0min | 0.0% |
| default | opus | 15 | 2 | 13.3% | 0.3min | 0.6% | 0.1min | 0.3% | 0.1min | 0.3% | 0.0min | 0.0% |
| default | sonnet | 4 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.0min | 0.0% |
| powershell | opus | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 0.0min | 0.0% |
| powershell | sonnet | 9 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| typescript-bun | opus | 23 | 9 | 39.1% | 1.2min | 2.8% | 0.2min | 0.4% | 1.0min | 2.3% | 0.0min | 0.0% |
| **—** | **—** |


<details>
<summary>Sorted by net saved (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 23 | 9 | 39.1% | 1.2min | 2.8% | 0.2min | 0.4% | 1.0min | 2.3% | 0.0min | 0.0% |
| bash | sonnet | 11 | 2 | 18.2% | 0.4min | 0.9% | 0.1min | 0.2% | 0.3min | 0.7% | 0.0min | 0.0% |
| default | opus | 15 | 2 | 13.3% | 0.3min | 0.6% | 0.1min | 0.3% | 0.1min | 0.3% | 0.0min | 0.0% |
| default | sonnet | 4 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.0min | 0.0% |
| bash | opus | 8 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| powershell | sonnet | 9 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| powershell | opus | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 23 | 9 | 39.1% | 1.2min | 2.8% | 0.2min | 0.4% | 1.0min | 2.3% | 0.0min | 0.0% |
| bash | sonnet | 11 | 2 | 18.2% | 0.4min | 0.9% | 0.1min | 0.2% | 0.3min | 0.7% | 0.0min | 0.0% |
| default | opus | 15 | 2 | 13.3% | 0.3min | 0.6% | 0.1min | 0.3% | 0.1min | 0.3% | 0.0min | 0.0% |
| bash | opus | 8 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| default | sonnet | 4 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.0min | 0.0% |
| powershell | opus | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 0.0min | 0.0% |
| powershell | sonnet | 9 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by overhead (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| typescript-bun | opus | 23 | 9 | 39.1% | 1.2min | 2.8% | 0.2min | 0.4% | 1.0min | 2.3% | 0.0min | 0.0% |
| powershell | opus | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 0.0min | 0.0% |
| default | opus | 15 | 2 | 13.3% | 0.3min | 0.6% | 0.1min | 0.3% | 0.1min | 0.3% | 0.0min | 0.0% |
| bash | sonnet | 11 | 2 | 18.2% | 0.4min | 0.9% | 0.1min | 0.2% | 0.3min | 0.7% | 0.0min | 0.0% |
| powershell | sonnet | 9 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| bash | opus | 8 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| default | sonnet | 4 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.0min | 0.0% |

</details>

<details>
<summary>Sorted by test run time (most first)</summary>

| Mode | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------|
| bash | opus | 8 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| bash | sonnet | 11 | 2 | 18.2% | 0.4min | 0.9% | 0.1min | 0.2% | 0.3min | 0.7% | 0.0min | 0.0% |
| default | opus | 15 | 2 | 13.3% | 0.3min | 0.6% | 0.1min | 0.3% | 0.1min | 0.3% | 0.0min | 0.0% |
| default | sonnet | 4 | 0 | 0.0% | 0.0min | 0.0% | 0.0min | 0.1% | -0.0min | -0.1% | 0.0min | 0.0% |
| powershell | opus | 16 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.3% | -0.1min | -0.3% | 0.0min | 0.0% |
| powershell | sonnet | 9 | 0 | 0.0% | 0.0min | 0.0% | 0.1min | 0.2% | -0.1min | -0.2% | 0.0min | 0.0% |
| typescript-bun | opus | 23 | 9 | 39.1% | 1.2min | 2.8% | 0.2min | 0.4% | 1.0min | 2.3% | 0.0min | 0.0% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 7 | $0.90 | 13.71% |
| Miss | 0 | $0.00 | 0.00% |
| **Total** | **7** | **$0.90** | **13.71%** |

### Trap Analysis by Category

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 7 | 4 | 3 | 57% | 6.0min | 13.8% | $0.99 | 15.03% |
| ts-type-error-fix-cycles | 1 | 1 | 0 | 100% | 1.8min | 4.1% | $0.37 | 5.56% |
| act-push-debug-loops | 7 | 1 | 6 | 14% | 1.7min | 3.8% | $0.32 | 4.86% |
| **Total** | | **3 runs** | | **43%** | **9.5min** | **21.8%** | **$1.68** | **25.45%** |


<details>
<summary>Sorted by $ lost (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 7 | 4 | 3 | 57% | 6.0min | 13.8% | $0.99 | 15.03% |
| ts-type-error-fix-cycles | 1 | 1 | 0 | 100% | 1.8min | 4.1% | $0.37 | 5.56% |
| act-push-debug-loops | 7 | 1 | 6 | 14% | 1.7min | 3.8% | $0.32 | 4.86% |

</details>

<details>
<summary>Sorted by rate (highest first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | 1 | 1 | 0 | 100% | 1.8min | 4.1% | $0.37 | 5.56% |
| repeated-test-reruns | 7 | 4 | 3 | 57% | 6.0min | 13.8% | $0.99 | 15.03% |
| act-push-debug-loops | 7 | 1 | 6 | 14% | 1.7min | 3.8% | $0.32 | 4.86% |

</details>

<details>
<summary>Sorted by runs affected (most first)</summary>

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| repeated-test-reruns | 7 | 4 | 3 | 57% | 6.0min | 13.8% | $0.99 | 15.03% |
| ts-type-error-fix-cycles | 1 | 1 | 0 | 100% | 1.8min | 4.1% | $0.37 | 5.56% |
| act-push-debug-loops | 7 | 1 | 6 | 14% | 1.7min | 3.8% | $0.32 | 4.86% |

</details>

### Traps by Language/Model

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus | 1 | 1 | 100% | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| default | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.7min | 8.4% | $0.70 | 10.69% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| typescript-bun | opus | 1 | 1 | 100% | 3 | 4.1min | 9.5% | $0.84 | 12.77% |
| **Total** | | **7** | **3** | **43%** | **6** | **9.5min** | **21.8%** | **$1.68** | **25.45%** |


<details>
<summary>Sorted by time lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| typescript-bun | opus | 1 | 1 | 100% | 3 | 4.1min | 9.5% | $0.84 | 12.77% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.7min | 8.4% | $0.70 | 10.69% |
| default | opus | 1 | 1 | 100% | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

<details>
<summary>Sorted by $ lost (most first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| typescript-bun | opus | 1 | 1 | 100% | 3 | 4.1min | 9.5% | $0.84 | 12.77% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.7min | 8.4% | $0.70 | 10.69% |
| default | opus | 1 | 1 | 100% | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

<details>
<summary>Sorted by trap rate (highest first)</summary>

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| default | opus | 1 | 1 | 100% | 1 | 1.7min | 3.8% | $0.13 | 1.99% |
| powershell | opus | 1 | 1 | 100% | 2 | 3.7min | 8.4% | $0.70 | 10.69% |
| typescript-bun | opus | 1 | 1 | 100% | 3 | 4.1min | 9.5% | $0.84 | 12.77% |
| bash | opus | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet | 1 | 0 | 0% | 0 | 0.0min | 0.0% | $0.00 | 0.00% |

</details>

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 202s | 27 | 691 | 2 | $0.76 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 163s | 24 | 586 | 3 | $0.40 | bash | ok |
| Semantic Version Bumper | default | opus | 856s | 39 | 649 | 2 | $1.12 | python | ok |
| Semantic Version Bumper | default | sonnet | 176s | 19 | 693 | 1 | $0.45 | python | ok |
| Semantic Version Bumper | powershell | opus | 473s | 50 | 656 | 2 | $1.51 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 192s | 22 | 593 | 0 | $0.50 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 543s | 65 | 1205 | 8 | $1.84 | typescript | ok |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Δ | Def Cost | Mode Cost | Cost Δ | Err Δ |
|------|-------|------|-------------|---------|----------|-------|----------|-----------|--------|-------|
| Semantic Version Bumper | opus | bash | python | 856s | 202s | -76% | $1.12 | $0.76 | -32% | +0 |
| Semantic Version Bumper | opus | powershell | python | 856s | 473s | -45% | $1.12 | $1.51 | +35% | +0 |
| Semantic Version Bumper | opus | typescript-bun | python | 856s | 543s | -37% | $1.12 | $1.84 | +64% | +6 |
| Semantic Version Bumper | sonnet | bash | python | 176s | 163s | -7% | $0.45 | $0.40 | -11% | +2 |
| Semantic Version Bumper | sonnet | powershell | python | 176s | 192s | +9% | $0.45 | $0.50 | +13% | -1 |

## Observations

- **Fastest run:** Semantic Version Bumper / bash / sonnet — 163s
- **Slowest run:** Semantic Version Bumper / default / opus — 856s
- **Most errors:** Semantic Version Bumper / typescript-bun / opus — 8 errors
- **Fewest errors:** Semantic Version Bumper / powershell / sonnet — 0 errors

- **Avg cost per run (opus):** $1.31
- **Avg cost per run (sonnet):** $0.45


---
*Generated by runner.py, instructions version v3*