# Benchmark Results: Language Comparison

**Last updated:** 2026-04-18 07:13:20 AM ET

**Status:** 64/64 runs completed, 0 remaining
**Total cost so far:** $86.90
**Total agent time so far:** 550.6 min

## Tiers by Language/Model/Effort

*Duration / Cost tier = ratio of this combo's average to the best combo's average on that axis (lower ratio = better). Bands: **A** ≤1.15×, **B** ≤1.40×, **C** ≤1.80×, **D** ≤2.50×, **E** >2.50×.*
*LLM Score tier = absolute Overall score band. **A** ≥4.5, **B** ≥3.5, **C** ≥2.5, **D** ≥1.5, **E** <1.5, `—` = no data.*
*If every row in a column is tier A, those combos are effectively tied on that axis.*

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | opus46 | A (7.7min) | B ($1.52) | C (3.0) |
| bash | sonnet46 | C (10.4min) | B ($1.40) | B (3.9) |
| default | opus46 | A (6.9min) | B ($1.45) | C (3.1) |
| default | sonnet46 | B (8.3min) | A ($1.14) | B (3.8) |
| powershell | opus46 | B (8.2min) | B ($1.55) | C (3.1) |
| powershell | sonnet46 | C (11.0min) | A ($1.30) | B (3.5) |
| typescript-bun | opus46 | A (6.9min) | B ($1.32) | C (2.9) |
| typescript-bun | sonnet46 | B (9.5min) | A ($1.17) | B (3.9) |


<details>
<summary>Sorted by Duration tier (A-first), then avg of Cost/LLM tiers</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | opus46 | A (7.7min) | B ($1.52) | C (3.0) |
| default | opus46 | A (6.9min) | B ($1.45) | C (3.1) |
| typescript-bun | opus46 | A (6.9min) | B ($1.32) | C (2.9) |
| default | sonnet46 | B (8.3min) | A ($1.14) | B (3.8) |
| typescript-bun | sonnet46 | B (9.5min) | A ($1.17) | B (3.9) |
| powershell | opus46 | B (8.2min) | B ($1.55) | C (3.1) |
| powershell | sonnet46 | C (11.0min) | A ($1.30) | B (3.5) |
| bash | sonnet46 | C (10.4min) | B ($1.40) | B (3.9) |

</details>

<details>
<summary>Sorted by Cost tier (A-first), then avg of Duration/LLM tiers</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| default | sonnet46 | B (8.3min) | A ($1.14) | B (3.8) |
| typescript-bun | sonnet46 | B (9.5min) | A ($1.17) | B (3.9) |
| powershell | sonnet46 | C (11.0min) | A ($1.30) | B (3.5) |
| bash | opus46 | A (7.7min) | B ($1.52) | C (3.0) |
| default | opus46 | A (6.9min) | B ($1.45) | C (3.1) |
| typescript-bun | opus46 | A (6.9min) | B ($1.32) | C (2.9) |
| bash | sonnet46 | C (10.4min) | B ($1.40) | B (3.9) |
| powershell | opus46 | B (8.2min) | B ($1.55) | C (3.1) |

</details>

<details>
<summary>Sorted by LLM Score tier (A-first; no-data last), then avg of Duration/Cost tiers</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| default | sonnet46 | B (8.3min) | A ($1.14) | B (3.8) |
| typescript-bun | sonnet46 | B (9.5min) | A ($1.17) | B (3.9) |
| powershell | sonnet46 | C (11.0min) | A ($1.30) | B (3.5) |
| bash | sonnet46 | C (10.4min) | B ($1.40) | B (3.9) |
| bash | opus46 | A (7.7min) | B ($1.52) | C (3.0) |
| default | opus46 | A (6.9min) | B ($1.45) | C (3.1) |
| typescript-bun | opus46 | A (6.9min) | B ($1.32) | C (2.9) |
| powershell | opus46 | B (8.2min) | B ($1.55) | C (3.1) |

</details>

## Rankings by Language/Model/Effort

*Lower rank = better on that axis (1 = fastest / cheapest / highest LLM score).*
*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | opus46 | 3 (7.7min) | 7 ($1.52) | 7 (3.0) |
| bash | sonnet46 | 7 (10.4min) | 5 ($1.40) | 1 (3.9) |
| default | opus46 | 2 (6.9min) | 6 ($1.45) | 5 (3.1) |
| default | sonnet46 | 5 (8.3min) | 1 ($1.14) | 3 (3.8) |
| powershell | opus46 | 4 (8.2min) | 8 ($1.55) | 6 (3.1) |
| powershell | sonnet46 | 8 (11.0min) | 3 ($1.30) | 4 (3.5) |
| typescript-bun | opus46 | 1 (6.9min) | 4 ($1.32) | 8 (2.9) |
| typescript-bun | sonnet46 | 6 (9.5min) | 2 ($1.17) | 2 (3.9) |


<details>
<summary>Sorted by Duration rank (fastest first)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| typescript-bun | opus46 | 1 (6.9min) | 4 ($1.32) | 8 (2.9) |
| default | opus46 | 2 (6.9min) | 6 ($1.45) | 5 (3.1) |
| bash | opus46 | 3 (7.7min) | 7 ($1.52) | 7 (3.0) |
| powershell | opus46 | 4 (8.2min) | 8 ($1.55) | 6 (3.1) |
| default | sonnet46 | 5 (8.3min) | 1 ($1.14) | 3 (3.8) |
| typescript-bun | sonnet46 | 6 (9.5min) | 2 ($1.17) | 2 (3.9) |
| bash | sonnet46 | 7 (10.4min) | 5 ($1.40) | 1 (3.9) |
| powershell | sonnet46 | 8 (11.0min) | 3 ($1.30) | 4 (3.5) |

</details>

<details>
<summary>Sorted by Cost rank (cheapest first)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| default | sonnet46 | 5 (8.3min) | 1 ($1.14) | 3 (3.8) |
| typescript-bun | sonnet46 | 6 (9.5min) | 2 ($1.17) | 2 (3.9) |
| powershell | sonnet46 | 8 (11.0min) | 3 ($1.30) | 4 (3.5) |
| typescript-bun | opus46 | 1 (6.9min) | 4 ($1.32) | 8 (2.9) |
| bash | sonnet46 | 7 (10.4min) | 5 ($1.40) | 1 (3.9) |
| default | opus46 | 2 (6.9min) | 6 ($1.45) | 5 (3.1) |
| bash | opus46 | 3 (7.7min) | 7 ($1.52) | 7 (3.0) |
| powershell | opus46 | 4 (8.2min) | 8 ($1.55) | 6 (3.1) |

</details>

<details>
<summary>Sorted by LLM Score rank (best first; no-data last)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | sonnet46 | 7 (10.4min) | 5 ($1.40) | 1 (3.9) |
| typescript-bun | sonnet46 | 6 (9.5min) | 2 ($1.17) | 2 (3.9) |
| default | sonnet46 | 5 (8.3min) | 1 ($1.14) | 3 (3.8) |
| powershell | sonnet46 | 8 (11.0min) | 3 ($1.30) | 4 (3.5) |
| default | opus46 | 2 (6.9min) | 6 ($1.45) | 5 (3.1) |
| powershell | opus46 | 4 (8.2min) | 8 ($1.55) | 6 (3.1) |
| bash | opus46 | 3 (7.7min) | 7 ($1.52) | 7 (3.0) |
| typescript-bun | opus46 | 1 (6.9min) | 4 ($1.32) | 8 (2.9) |

</details>

## Comparison by Language/Model/Effort
*Avg LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| bash | opus46 | 8 | 7.7min | 7.1min | 1.6 | 43 | $1.52 | $12.19 | 3.0 |
| bash | sonnet46 | 8 | 10.4min | 9.9min | 4.0 | 42 | $1.40 | $11.21 | 3.9 |
| default | opus46 | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 | 3.1 |
| default | sonnet46 | 8 | 8.3min | 7.8min | 2.8 | 38 | $1.14 | $9.14 | 3.8 |
| powershell | opus46 | 8 | 8.2min | 8.0min | 1.5 | 34 | $1.55 | $12.37 | 3.1 |
| powershell | sonnet46 | 8 | 11.0min | 9.6min | 1.6 | 38 | $1.30 | $10.43 | 3.5 |
| typescript-bun | opus46 | 8 | 6.9min | 5.7min | 2.0 | 39 | $1.32 | $10.60 | 2.9 |
| typescript-bun | sonnet46 | 8 | 9.5min | 8.1min | 1.6 | 37 | $1.17 | $9.39 | 3.9 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| default | sonnet46 | 8 | 8.3min | 7.8min | 2.8 | 38 | $1.14 | $9.14 | 3.8 |
| typescript-bun | sonnet46 | 8 | 9.5min | 8.1min | 1.6 | 37 | $1.17 | $9.39 | 3.9 |
| powershell | sonnet46 | 8 | 11.0min | 9.6min | 1.6 | 38 | $1.30 | $10.43 | 3.5 |
| typescript-bun | opus46 | 8 | 6.9min | 5.7min | 2.0 | 39 | $1.32 | $10.60 | 2.9 |
| bash | sonnet46 | 8 | 10.4min | 9.9min | 4.0 | 42 | $1.40 | $11.21 | 3.9 |
| default | opus46 | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 | 3.1 |
| bash | opus46 | 8 | 7.7min | 7.1min | 1.6 | 43 | $1.52 | $12.19 | 3.0 |
| powershell | opus46 | 8 | 8.2min | 8.0min | 1.5 | 34 | $1.55 | $12.37 | 3.1 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| typescript-bun | opus46 | 8 | 6.9min | 5.7min | 2.0 | 39 | $1.32 | $10.60 | 2.9 |
| default | opus46 | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 | 3.1 |
| bash | opus46 | 8 | 7.7min | 7.1min | 1.6 | 43 | $1.52 | $12.19 | 3.0 |
| powershell | opus46 | 8 | 8.2min | 8.0min | 1.5 | 34 | $1.55 | $12.37 | 3.1 |
| default | sonnet46 | 8 | 8.3min | 7.8min | 2.8 | 38 | $1.14 | $9.14 | 3.8 |
| typescript-bun | sonnet46 | 8 | 9.5min | 8.1min | 1.6 | 37 | $1.17 | $9.39 | 3.9 |
| bash | sonnet46 | 8 | 10.4min | 9.9min | 4.0 | 42 | $1.40 | $11.21 | 3.9 |
| powershell | sonnet46 | 8 | 11.0min | 9.6min | 1.6 | 38 | $1.30 | $10.43 | 3.5 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| typescript-bun | opus46 | 8 | 6.9min | 5.7min | 2.0 | 39 | $1.32 | $10.60 | 2.9 |
| default | opus46 | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 | 3.1 |
| bash | opus46 | 8 | 7.7min | 7.1min | 1.6 | 43 | $1.52 | $12.19 | 3.0 |
| default | sonnet46 | 8 | 8.3min | 7.8min | 2.8 | 38 | $1.14 | $9.14 | 3.8 |
| powershell | opus46 | 8 | 8.2min | 8.0min | 1.5 | 34 | $1.55 | $12.37 | 3.1 |
| typescript-bun | sonnet46 | 8 | 9.5min | 8.1min | 1.6 | 37 | $1.17 | $9.39 | 3.9 |
| powershell | sonnet46 | 8 | 11.0min | 9.6min | 1.6 | 38 | $1.30 | $10.43 | 3.5 |
| bash | sonnet46 | 8 | 10.4min | 9.9min | 4.0 | 42 | $1.40 | $11.21 | 3.9 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| default | opus46 | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 | 3.1 |
| powershell | opus46 | 8 | 8.2min | 8.0min | 1.5 | 34 | $1.55 | $12.37 | 3.1 |
| bash | opus46 | 8 | 7.7min | 7.1min | 1.6 | 43 | $1.52 | $12.19 | 3.0 |
| powershell | sonnet46 | 8 | 11.0min | 9.6min | 1.6 | 38 | $1.30 | $10.43 | 3.5 |
| typescript-bun | sonnet46 | 8 | 9.5min | 8.1min | 1.6 | 37 | $1.17 | $9.39 | 3.9 |
| typescript-bun | opus46 | 8 | 6.9min | 5.7min | 2.0 | 39 | $1.32 | $10.60 | 2.9 |
| default | sonnet46 | 8 | 8.3min | 7.8min | 2.8 | 38 | $1.14 | $9.14 | 3.8 |
| bash | sonnet46 | 8 | 10.4min | 9.9min | 4.0 | 42 | $1.40 | $11.21 | 3.9 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| powershell | opus46 | 8 | 8.2min | 8.0min | 1.5 | 34 | $1.55 | $12.37 | 3.1 |
| default | opus46 | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 | 3.1 |
| typescript-bun | sonnet46 | 8 | 9.5min | 8.1min | 1.6 | 37 | $1.17 | $9.39 | 3.9 |
| default | sonnet46 | 8 | 8.3min | 7.8min | 2.8 | 38 | $1.14 | $9.14 | 3.8 |
| powershell | sonnet46 | 8 | 11.0min | 9.6min | 1.6 | 38 | $1.30 | $10.43 | 3.5 |
| typescript-bun | opus46 | 8 | 6.9min | 5.7min | 2.0 | 39 | $1.32 | $10.60 | 2.9 |
| bash | sonnet46 | 8 | 10.4min | 9.9min | 4.0 | 42 | $1.40 | $11.21 | 3.9 |
| bash | opus46 | 8 | 7.7min | 7.1min | 1.6 | 43 | $1.52 | $12.19 | 3.0 |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| bash | sonnet46 | 8 | 10.4min | 9.9min | 4.0 | 42 | $1.40 | $11.21 | 3.9 |
| typescript-bun | sonnet46 | 8 | 9.5min | 8.1min | 1.6 | 37 | $1.17 | $9.39 | 3.9 |
| default | sonnet46 | 8 | 8.3min | 7.8min | 2.8 | 38 | $1.14 | $9.14 | 3.8 |
| powershell | sonnet46 | 8 | 11.0min | 9.6min | 1.6 | 38 | $1.30 | $10.43 | 3.5 |
| default | opus46 | 8 | 6.9min | 6.9min | 1.5 | 34 | $1.45 | $11.57 | 3.1 |
| powershell | opus46 | 8 | 8.2min | 8.0min | 1.5 | 34 | $1.55 | $12.37 | 3.1 |
| bash | opus46 | 8 | 7.7min | 7.1min | 1.6 | 43 | $1.52 | $12.19 | 3.0 |
| typescript-bun | opus46 | 8 | 6.9min | 5.7min | 2.0 | 39 | $1.32 | $10.60 | 2.9 |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | opus46 | 91 | 3 | 3.3% | 0.6min | 0.1% | 0.6min | 0.1% | 0.0min | 0.0% | 7.1min | 0.1% |
| bash | sonnet46 | 107 | 9 | 8.4% | 1.8min | 0.3% | 0.2min | 0.0% | 1.6min | 0.3% | 9.0min | 17.7% |
| default | opus46 | 77 | 14 | 18.2% | 1.9min | 0.3% | 0.2min | 0.0% | 1.6min | 0.3% | 3.0min | 54.2% |
| default | sonnet46 | 81 | 3 | 3.7% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 3.6min | 5.4% |
| powershell | opus46 | 86 | 10 | 11.6% | 5.8min | 1.1% | 0.7min | 0.1% | 5.2min | 0.9% | 5.9min | 87.1% |
| powershell | sonnet46 | 86 | 1 | 1.2% | 0.6min | 0.1% | 0.8min | 0.1% | -0.2min | -0.0% | 9.6min | -2.0% |
| typescript-bun | opus46 | 66 | 36 | 54.5% | 4.8min | 0.9% | 4.3min | 0.8% | 0.5min | 0.1% | 5.3min | 10.1% |
| typescript-bun | sonnet46 | 94 | 46 | 48.9% | 6.1min | 1.1% | 2.4min | 0.4% | 3.7min | 0.7% | 5.3min | 70.3% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell | opus46 | 86 | 10 | 11.6% | 5.8min | 1.1% | 0.7min | 0.1% | 5.2min | 0.9% | 5.9min | 87.1% |
| typescript-bun | sonnet46 | 94 | 46 | 48.9% | 6.1min | 1.1% | 2.4min | 0.4% | 3.7min | 0.7% | 5.3min | 70.3% |
| default | opus46 | 77 | 14 | 18.2% | 1.9min | 0.3% | 0.2min | 0.0% | 1.6min | 0.3% | 3.0min | 54.2% |
| bash | sonnet46 | 107 | 9 | 8.4% | 1.8min | 0.3% | 0.2min | 0.0% | 1.6min | 0.3% | 9.0min | 17.7% |
| typescript-bun | opus46 | 66 | 36 | 54.5% | 4.8min | 0.9% | 4.3min | 0.8% | 0.5min | 0.1% | 5.3min | 10.1% |
| default | sonnet46 | 81 | 3 | 3.7% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 3.6min | 5.4% |
| bash | opus46 | 91 | 3 | 3.3% | 0.6min | 0.1% | 0.6min | 0.1% | 0.0min | 0.0% | 7.1min | 0.1% |
| powershell | sonnet46 | 86 | 1 | 1.2% | 0.6min | 0.1% | 0.8min | 0.1% | -0.2min | -0.0% | 9.6min | -2.0% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| powershell | opus46 | 86 | 10 | 11.6% | 5.8min | 1.1% | 0.7min | 0.1% | 5.2min | 0.9% | 5.9min | 87.1% |
| typescript-bun | sonnet46 | 94 | 46 | 48.9% | 6.1min | 1.1% | 2.4min | 0.4% | 3.7min | 0.7% | 5.3min | 70.3% |
| default | opus46 | 77 | 14 | 18.2% | 1.9min | 0.3% | 0.2min | 0.0% | 1.6min | 0.3% | 3.0min | 54.2% |
| bash | sonnet46 | 107 | 9 | 8.4% | 1.8min | 0.3% | 0.2min | 0.0% | 1.6min | 0.3% | 9.0min | 17.7% |
| typescript-bun | opus46 | 66 | 36 | 54.5% | 4.8min | 0.9% | 4.3min | 0.8% | 0.5min | 0.1% | 5.3min | 10.1% |
| default | sonnet46 | 81 | 3 | 3.7% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 3.6min | 5.4% |
| bash | opus46 | 91 | 3 | 3.3% | 0.6min | 0.1% | 0.6min | 0.1% | 0.0min | 0.0% | 7.1min | 0.1% |
| powershell | sonnet46 | 86 | 1 | 1.2% | 0.6min | 0.1% | 0.8min | 0.1% | -0.2min | -0.0% | 9.6min | -2.0% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus46 | 66 | 36 | 54.5% | 4.8min | 0.9% | 4.3min | 0.8% | 0.5min | 0.1% | 5.3min | 10.1% |
| typescript-bun | sonnet46 | 94 | 46 | 48.9% | 6.1min | 1.1% | 2.4min | 0.4% | 3.7min | 0.7% | 5.3min | 70.3% |
| default | opus46 | 77 | 14 | 18.2% | 1.9min | 0.3% | 0.2min | 0.0% | 1.6min | 0.3% | 3.0min | 54.2% |
| powershell | opus46 | 86 | 10 | 11.6% | 5.8min | 1.1% | 0.7min | 0.1% | 5.2min | 0.9% | 5.9min | 87.1% |
| bash | sonnet46 | 107 | 9 | 8.4% | 1.8min | 0.3% | 0.2min | 0.0% | 1.6min | 0.3% | 9.0min | 17.7% |
| default | sonnet46 | 81 | 3 | 3.7% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 3.6min | 5.4% |
| bash | opus46 | 91 | 3 | 3.3% | 0.6min | 0.1% | 0.6min | 0.1% | 0.0min | 0.0% | 7.1min | 0.1% |
| powershell | sonnet46 | 86 | 1 | 1.2% | 0.6min | 0.1% | 0.8min | 0.1% | -0.2min | -0.0% | 9.6min | -2.0% |

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| ts-type-error-fix-cycles | typescript-bun | opus46 | 7 | 7.2min | 1.3% | $1.41 | 1.63% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46 | 8 | 9.2min | 1.7% | $1.15 | 1.32% |
| fixture-rework | bash | opus46 | 4 | 3.5min | 0.6% | $0.76 | 0.88% |
| fixture-rework | bash | sonnet46 | 2 | 1.0min | 0.2% | $0.14 | 0.16% |
| fixture-rework | powershell | opus46 | 1 | 1.5min | 0.3% | $0.37 | 0.42% |
| fixture-rework | powershell | sonnet46 | 2 | 2.5min | 0.5% | $0.36 | 0.41% |
| fixture-rework | typescript-bun | opus46 | 1 | 0.8min | 0.1% | $0.14 | 0.16% |
| repeated-test-reruns | bash | sonnet46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | default | sonnet46 | 1 | 0.7min | 0.1% | $0.08 | 0.09% |
| repeated-test-reruns | powershell | sonnet46 | 4 | 4.3min | 0.8% | $0.55 | 0.63% |
| repeated-test-reruns | typescript-bun | opus46 | 1 | 0.7min | 0.1% | $0.15 | 0.17% |
| repeated-test-reruns | typescript-bun | sonnet46 | 1 | 1.0min | 0.2% | $0.14 | 0.17% |
| act-push-debug-loops | bash | opus46 | 1 | 0.8min | 0.2% | $0.11 | 0.13% |
| act-push-debug-loops | bash | sonnet46 | 1 | 0.4min | 0.1% | $0.05 | 0.05% |
| act-push-debug-loops | default | sonnet46 | 2 | 2.2min | 0.4% | $0.28 | 0.32% |
| act-push-debug-loops | typescript-bun | opus46 | 1 | 0.5min | 0.1% | $0.09 | 0.11% |
| act-push-debug-loops | typescript-bun | sonnet46 | 1 | 1.2min | 0.2% | $0.13 | 0.15% |
| docker-pwsh-install | powershell | sonnet46 | 2 | 4.5min | 0.8% | $0.57 | 0.65% |
| bats-setup-issues | bash | sonnet46 | 2 | 1.8min | 0.3% | $0.25 | 0.29% |
| actionlint-fix-cycles | bash | opus46 | 1 | 0.7min | 0.1% | $0.09 | 0.10% |
| actionlint-fix-cycles | default | sonnet46 | 1 | 0.7min | 0.1% | $0.09 | 0.10% |
| act-permission-path-errors | default | sonnet46 | 1 | 0.8min | 0.1% | $0.09 | 0.10% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | sonnet46 | 1 | 0.4min | 0.1% | $0.05 | 0.05% |
| act-push-debug-loops | typescript-bun | opus46 | 1 | 0.5min | 0.1% | $0.09 | 0.11% |
| repeated-test-reruns | bash | sonnet46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | default | sonnet46 | 1 | 0.7min | 0.1% | $0.08 | 0.09% |
| repeated-test-reruns | typescript-bun | opus46 | 1 | 0.7min | 0.1% | $0.15 | 0.17% |
| actionlint-fix-cycles | bash | opus46 | 1 | 0.7min | 0.1% | $0.09 | 0.10% |
| actionlint-fix-cycles | default | sonnet46 | 1 | 0.7min | 0.1% | $0.09 | 0.10% |
| fixture-rework | typescript-bun | opus46 | 1 | 0.8min | 0.1% | $0.14 | 0.16% |
| act-permission-path-errors | default | sonnet46 | 1 | 0.8min | 0.1% | $0.09 | 0.10% |
| act-push-debug-loops | bash | opus46 | 1 | 0.8min | 0.2% | $0.11 | 0.13% |
| fixture-rework | bash | sonnet46 | 2 | 1.0min | 0.2% | $0.14 | 0.16% |
| repeated-test-reruns | typescript-bun | sonnet46 | 1 | 1.0min | 0.2% | $0.14 | 0.17% |
| act-push-debug-loops | typescript-bun | sonnet46 | 1 | 1.2min | 0.2% | $0.13 | 0.15% |
| fixture-rework | powershell | opus46 | 1 | 1.5min | 0.3% | $0.37 | 0.42% |
| bats-setup-issues | bash | sonnet46 | 2 | 1.8min | 0.3% | $0.25 | 0.29% |
| act-push-debug-loops | default | sonnet46 | 2 | 2.2min | 0.4% | $0.28 | 0.32% |
| fixture-rework | powershell | sonnet46 | 2 | 2.5min | 0.5% | $0.36 | 0.41% |
| fixture-rework | bash | opus46 | 4 | 3.5min | 0.6% | $0.76 | 0.88% |
| repeated-test-reruns | powershell | sonnet46 | 4 | 4.3min | 0.8% | $0.55 | 0.63% |
| docker-pwsh-install | powershell | sonnet46 | 2 | 4.5min | 0.8% | $0.57 | 0.65% |
| ts-type-error-fix-cycles | typescript-bun | opus46 | 7 | 7.2min | 1.3% | $1.41 | 1.63% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46 | 8 | 9.2min | 1.7% | $1.15 | 1.32% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | bash | sonnet46 | 1 | 0.4min | 0.1% | $0.05 | 0.05% |
| repeated-test-reruns | default | sonnet46 | 1 | 0.7min | 0.1% | $0.08 | 0.09% |
| actionlint-fix-cycles | default | sonnet46 | 1 | 0.7min | 0.1% | $0.09 | 0.10% |
| actionlint-fix-cycles | bash | opus46 | 1 | 0.7min | 0.1% | $0.09 | 0.10% |
| act-permission-path-errors | default | sonnet46 | 1 | 0.8min | 0.1% | $0.09 | 0.10% |
| act-push-debug-loops | typescript-bun | opus46 | 1 | 0.5min | 0.1% | $0.09 | 0.11% |
| repeated-test-reruns | bash | sonnet46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| act-push-debug-loops | bash | opus46 | 1 | 0.8min | 0.2% | $0.11 | 0.13% |
| act-push-debug-loops | typescript-bun | sonnet46 | 1 | 1.2min | 0.2% | $0.13 | 0.15% |
| fixture-rework | typescript-bun | opus46 | 1 | 0.8min | 0.1% | $0.14 | 0.16% |
| fixture-rework | bash | sonnet46 | 2 | 1.0min | 0.2% | $0.14 | 0.16% |
| repeated-test-reruns | typescript-bun | sonnet46 | 1 | 1.0min | 0.2% | $0.14 | 0.17% |
| repeated-test-reruns | typescript-bun | opus46 | 1 | 0.7min | 0.1% | $0.15 | 0.17% |
| bats-setup-issues | bash | sonnet46 | 2 | 1.8min | 0.3% | $0.25 | 0.29% |
| act-push-debug-loops | default | sonnet46 | 2 | 2.2min | 0.4% | $0.28 | 0.32% |
| fixture-rework | powershell | sonnet46 | 2 | 2.5min | 0.5% | $0.36 | 0.41% |
| fixture-rework | powershell | opus46 | 1 | 1.5min | 0.3% | $0.37 | 0.42% |
| repeated-test-reruns | powershell | sonnet46 | 4 | 4.3min | 0.8% | $0.55 | 0.63% |
| docker-pwsh-install | powershell | sonnet46 | 2 | 4.5min | 0.8% | $0.57 | 0.65% |
| fixture-rework | bash | opus46 | 4 | 3.5min | 0.6% | $0.76 | 0.88% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46 | 8 | 9.2min | 1.7% | $1.15 | 1.32% |
| ts-type-error-fix-cycles | typescript-bun | opus46 | 7 | 7.2min | 1.3% | $1.41 | 1.63% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | powershell | opus46 | 1 | 1.5min | 0.3% | $0.37 | 0.42% |
| fixture-rework | typescript-bun | opus46 | 1 | 0.8min | 0.1% | $0.14 | 0.16% |
| repeated-test-reruns | bash | sonnet46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | default | sonnet46 | 1 | 0.7min | 0.1% | $0.08 | 0.09% |
| repeated-test-reruns | typescript-bun | opus46 | 1 | 0.7min | 0.1% | $0.15 | 0.17% |
| repeated-test-reruns | typescript-bun | sonnet46 | 1 | 1.0min | 0.2% | $0.14 | 0.17% |
| act-push-debug-loops | bash | opus46 | 1 | 0.8min | 0.2% | $0.11 | 0.13% |
| act-push-debug-loops | bash | sonnet46 | 1 | 0.4min | 0.1% | $0.05 | 0.05% |
| act-push-debug-loops | typescript-bun | opus46 | 1 | 0.5min | 0.1% | $0.09 | 0.11% |
| act-push-debug-loops | typescript-bun | sonnet46 | 1 | 1.2min | 0.2% | $0.13 | 0.15% |
| actionlint-fix-cycles | bash | opus46 | 1 | 0.7min | 0.1% | $0.09 | 0.10% |
| actionlint-fix-cycles | default | sonnet46 | 1 | 0.7min | 0.1% | $0.09 | 0.10% |
| act-permission-path-errors | default | sonnet46 | 1 | 0.8min | 0.1% | $0.09 | 0.10% |
| fixture-rework | bash | sonnet46 | 2 | 1.0min | 0.2% | $0.14 | 0.16% |
| fixture-rework | powershell | sonnet46 | 2 | 2.5min | 0.5% | $0.36 | 0.41% |
| act-push-debug-loops | default | sonnet46 | 2 | 2.2min | 0.4% | $0.28 | 0.32% |
| docker-pwsh-install | powershell | sonnet46 | 2 | 4.5min | 0.8% | $0.57 | 0.65% |
| bats-setup-issues | bash | sonnet46 | 2 | 1.8min | 0.3% | $0.25 | 0.29% |
| fixture-rework | bash | opus46 | 4 | 3.5min | 0.6% | $0.76 | 0.88% |
| repeated-test-reruns | powershell | sonnet46 | 4 | 4.3min | 0.8% | $0.55 | 0.63% |
| ts-type-error-fix-cycles | typescript-bun | opus46 | 7 | 7.2min | 1.3% | $1.41 | 1.63% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46 | 8 | 9.2min | 1.7% | $1.15 | 1.32% |

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

- **Fell In**: Number of runs (within that language/model) where this trap was detected.
- **Time Lost**: Estimated wall-clock seconds wasted on the trap, based on the number of
  wasted commands multiplied by a per-command cost (15–25s for typical Bash, 45s for Docker runs, 50s for act push).
- **% of Time**: Time Lost as a percentage of total benchmark duration.
- **$ Lost**: Proportional cost impact, calculated as (Time Lost / Run Duration) × Run Cost for each affected run.
- **% of $**: $ Lost as a percentage of total benchmark cost.

### Traps by Language/Model/Effort

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| bash | opus46 | 8 | 6 | 5.0min | 0.9% | $0.96 | 1.11% |
| bash | sonnet46 | 8 | 6 | 3.9min | 0.7% | $0.55 | 0.63% |
| default | opus46 | 8 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet46 | 8 | 5 | 4.2min | 0.8% | $0.54 | 0.62% |
| powershell | opus46 | 8 | 1 | 1.5min | 0.3% | $0.37 | 0.42% |
| powershell | sonnet46 | 8 | 8 | 11.3min | 2.1% | $1.48 | 1.70% |
| typescript-bun | opus46 | 8 | 10 | 9.1min | 1.7% | $1.79 | 2.06% |
| typescript-bun | sonnet46 | 8 | 10 | 11.4min | 2.1% | $1.42 | 1.64% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus46 | 8 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus46 | 8 | 1 | 1.5min | 0.3% | $0.37 | 0.42% |
| bash | sonnet46 | 8 | 6 | 3.9min | 0.7% | $0.55 | 0.63% |
| default | sonnet46 | 8 | 5 | 4.2min | 0.8% | $0.54 | 0.62% |
| bash | opus46 | 8 | 6 | 5.0min | 0.9% | $0.96 | 1.11% |
| typescript-bun | opus46 | 8 | 10 | 9.1min | 1.7% | $1.79 | 2.06% |
| powershell | sonnet46 | 8 | 8 | 11.3min | 2.1% | $1.48 | 1.70% |
| typescript-bun | sonnet46 | 8 | 10 | 11.4min | 2.1% | $1.42 | 1.64% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus46 | 8 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus46 | 8 | 1 | 1.5min | 0.3% | $0.37 | 0.42% |
| default | sonnet46 | 8 | 5 | 4.2min | 0.8% | $0.54 | 0.62% |
| bash | sonnet46 | 8 | 6 | 3.9min | 0.7% | $0.55 | 0.63% |
| bash | opus46 | 8 | 6 | 5.0min | 0.9% | $0.96 | 1.11% |
| typescript-bun | sonnet46 | 8 | 10 | 11.4min | 2.1% | $1.42 | 1.64% |
| powershell | sonnet46 | 8 | 8 | 11.3min | 2.1% | $1.48 | 1.70% |
| typescript-bun | opus46 | 8 | 10 | 9.1min | 1.7% | $1.79 | 2.06% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 1 | $0.06 | 0.07% |
| Partial | 60 | $3.14 | 3.61% |
| Miss | 3 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | opus46 | 26.1 | 35.1 | 1.3 | 1.12 |
| bash | sonnet46 | 27.2 | 43.5 | 1.6 | 0.91 |
| default | opus46 | 17.8 | 26.8 | 1.5 | 2.21 |
| default | sonnet46 | 34.5 | 47.5 | 1.4 | 1.76 |
| powershell | opus46 | 24.0 | 41.1 | 1.7 | 1.30 |
| powershell | sonnet46 | 37.9 | 51.8 | 1.4 | 0.78 |
| typescript-bun | opus46 | 24.8 | 48.4 | 2.0 | 1.00 |
| typescript-bun | sonnet46 | 33.2 | 62.5 | 1.9 | 1.01 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell | sonnet46 | 37.9 | 51.8 | 1.4 | 0.78 |
| default | sonnet46 | 34.5 | 47.5 | 1.4 | 1.76 |
| typescript-bun | sonnet46 | 33.2 | 62.5 | 1.9 | 1.01 |
| bash | sonnet46 | 27.2 | 43.5 | 1.6 | 0.91 |
| bash | opus46 | 26.1 | 35.1 | 1.3 | 1.12 |
| typescript-bun | opus46 | 24.8 | 48.4 | 2.0 | 1.00 |
| powershell | opus46 | 24.0 | 41.1 | 1.7 | 1.30 |
| default | opus46 | 17.8 | 26.8 | 1.5 | 2.21 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | sonnet46 | 33.2 | 62.5 | 1.9 | 1.01 |
| powershell | sonnet46 | 37.9 | 51.8 | 1.4 | 0.78 |
| typescript-bun | opus46 | 24.8 | 48.4 | 2.0 | 1.00 |
| default | sonnet46 | 34.5 | 47.5 | 1.4 | 1.76 |
| bash | sonnet46 | 27.2 | 43.5 | 1.6 | 0.91 |
| powershell | opus46 | 24.0 | 41.1 | 1.7 | 1.30 |
| bash | opus46 | 26.1 | 35.1 | 1.3 | 1.12 |
| default | opus46 | 17.8 | 26.8 | 1.5 | 2.21 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus46 | 17.8 | 26.8 | 1.5 | 2.21 |
| default | sonnet46 | 34.5 | 47.5 | 1.4 | 1.76 |
| powershell | opus46 | 24.0 | 41.1 | 1.7 | 1.30 |
| bash | opus46 | 26.1 | 35.1 | 1.3 | 1.12 |
| typescript-bun | sonnet46 | 33.2 | 62.5 | 1.9 | 1.01 |
| typescript-bun | opus46 | 24.8 | 48.4 | 2.0 | 1.00 |
| bash | sonnet46 | 27.2 | 43.5 | 1.6 | 0.91 |
| powershell | sonnet46 | 37.9 | 51.8 | 1.4 | 0.78 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Language | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | bash | opus46 | 20 | 37 | 1.9 | 206 | 530 | 0.39 |
| Semantic Version Bumper | bash | sonnet46 | 29 | 42 | 1.4 | 270 | 473 | 0.57 |
| Semantic Version Bumper | default | opus46 | 1 | 2 | 2.0 | 352 | 288 | 1.22 |
| Semantic Version Bumper | default | sonnet46 | 44 | 42 | 1.0 | 289 | 243 | 1.19 |
| Semantic Version Bumper | powershell | opus46 | 13 | 31 | 2.4 | 203 | 203 | 1.00 |
| Semantic Version Bumper | powershell | sonnet46 | 32 | 43 | 1.3 | 267 | 482 | 0.55 |
| Semantic Version Bumper | typescript-bun | opus46 | 14 | 27 | 1.9 | 245 | 251 | 0.98 |
| Semantic Version Bumper | typescript-bun | sonnet46 | 37 | 43 | 1.2 | 276 | 423 | 0.65 |
| PR Label Assigner | bash | opus46 | 12 | 5 | 0.4 | 147 | 279 | 0.53 |
| PR Label Assigner | bash | sonnet46 | 33 | 60 | 1.8 | 287 | 336 | 0.85 |
| PR Label Assigner | default | opus46 | 17 | 18 | 1.1 | 622 | 169 | 3.68 |
| PR Label Assigner | default | sonnet46 | 26 | 32 | 1.2 | 508 | 217 | 2.34 |
| PR Label Assigner | powershell | opus46 | 34 | 49 | 1.4 | 294 | 159 | 1.85 |
| PR Label Assigner | powershell | sonnet46 | 38 | 47 | 1.2 | 273 | 378 | 0.72 |
| PR Label Assigner | typescript-bun | opus46 | 21 | 51 | 2.4 | 268 | 226 | 1.19 |
| PR Label Assigner | typescript-bun | sonnet46 | 22 | 33 | 1.5 | 191 | 424 | 0.45 |
| Dependency License Checker | bash | opus46 | 52 | 51 | 1.0 | 378 | 252 | 1.50 |
| Dependency License Checker | bash | sonnet46 | 44 | 67 | 1.5 | 443 | 309 | 1.43 |
| Dependency License Checker | default | opus46 | 28 | 45 | 1.6 | 369 | 219 | 1.68 |
| Dependency License Checker | default | sonnet46 | 31 | 70 | 2.3 | 589 | 260 | 2.27 |
| Dependency License Checker | powershell | opus46 | 23 | 49 | 2.1 | 205 | 316 | 0.65 |
| Dependency License Checker | powershell | sonnet46 | 26 | 52 | 2.0 | 305 | 481 | 0.63 |
| Dependency License Checker | typescript-bun | opus46 | 65 | 112 | 1.7 | 707 | 363 | 1.95 |
| Dependency License Checker | typescript-bun | sonnet46 | 36 | 51 | 1.4 | 318 | 289 | 1.10 |
| Docker Image Tag Generator | bash | opus46 | 25 | 6 | 0.2 | 167 | 108 | 1.55 |
| Docker Image Tag Generator | bash | sonnet46 | 15 | 25 | 1.7 | 128 | 373 | 0.34 |
| Docker Image Tag Generator | default | opus46 | 26 | 36 | 1.4 | 251 | 128 | 1.96 |
| Docker Image Tag Generator | default | sonnet46 | 36 | 42 | 1.2 | 605 | 176 | 3.44 |
| Docker Image Tag Generator | powershell | opus46 | 13 | 40 | 3.1 | 170 | 72 | 2.36 |
| Docker Image Tag Generator | powershell | sonnet46 | 34 | 37 | 1.1 | 209 | 338 | 0.62 |
| Docker Image Tag Generator | typescript-bun | opus46 | 23 | 27 | 1.2 | 217 | 136 | 1.60 |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 13 | 14 | 1.1 | 73 | 289 | 0.25 |
| Test Results Aggregator | bash | opus46 | 14 | 43 | 3.1 | 168 | 241 | 0.70 |
| Test Results Aggregator | bash | sonnet46 | 25 | 26 | 1.0 | 173 | 307 | 0.56 |
| Test Results Aggregator | default | opus46 | 9 | 27 | 3.0 | 468 | 337 | 1.39 |
| Test Results Aggregator | default | sonnet46 | 33 | 41 | 1.2 | 266 | 377 | 0.71 |
| Test Results Aggregator | powershell | opus46 | 28 | 30 | 1.1 | 264 | 244 | 1.08 |
| Test Results Aggregator | powershell | sonnet46 | 99 | 111 | 1.1 | 701 | 994 | 0.71 |
| Test Results Aggregator | typescript-bun | opus46 | 22 | 45 | 2.0 | 265 | 552 | 0.48 |
| Test Results Aggregator | typescript-bun | sonnet46 | 46 | 110 | 2.4 | 611 | 387 | 1.58 |
| Environment Matrix Generator | bash | opus46 | 24 | 9 | 0.4 | 233 | 134 | 1.74 |
| Environment Matrix Generator | bash | sonnet46 | 22 | 38 | 1.7 | 233 | 321 | 0.73 |
| Environment Matrix Generator | default | opus46 | 16 | 16 | 1.0 | 515 | 185 | 2.78 |
| Environment Matrix Generator | default | sonnet46 | 37 | 51 | 1.4 | 592 | 207 | 2.86 |
| Environment Matrix Generator | powershell | opus46 | 19 | 43 | 2.3 | 279 | 139 | 2.01 |
| Environment Matrix Generator | powershell | sonnet46 | 24 | 41 | 1.7 | 284 | 244 | 1.16 |
| Environment Matrix Generator | typescript-bun | opus46 | 23 | 28 | 1.2 | 207 | 347 | 0.60 |
| Environment Matrix Generator | typescript-bun | sonnet46 | 28 | 42 | 1.5 | 292 | 427 | 0.68 |
| Artifact Cleanup Script | bash | opus46 | 24 | 103 | 4.3 | 339 | 347 | 0.98 |
| Artifact Cleanup Script | bash | sonnet46 | 27 | 47 | 1.7 | 323 | 238 | 1.36 |
| Artifact Cleanup Script | default | opus46 | 21 | 30 | 1.4 | 384 | 209 | 1.84 |
| Artifact Cleanup Script | default | sonnet46 | 30 | 47 | 1.6 | 333 | 542 | 0.61 |
| Artifact Cleanup Script | powershell | opus46 | 15 | 39 | 2.6 | 220 | 0 | 0.00 |
| Artifact Cleanup Script | powershell | sonnet46 | 16 | 30 | 1.9 | 197 | 170 | 1.16 |
| Artifact Cleanup Script | typescript-bun | opus46 | 17 | 48 | 2.8 | 261 | 341 | 0.77 |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 35 | 78 | 2.2 | 497 | 392 | 1.27 |
| Secret Rotation Validator | bash | opus46 | 38 | 27 | 0.7 | 273 | 177 | 1.54 |
| Secret Rotation Validator | bash | sonnet46 | 23 | 43 | 1.9 | 422 | 302 | 1.40 |
| Secret Rotation Validator | default | opus46 | 24 | 40 | 1.7 | 659 | 212 | 3.11 |
| Secret Rotation Validator | default | sonnet46 | 39 | 55 | 1.4 | 430 | 611 | 0.70 |
| Secret Rotation Validator | powershell | opus46 | 47 | 48 | 1.0 | 325 | 220 | 1.48 |
| Secret Rotation Validator | powershell | sonnet46 | 34 | 53 | 1.6 | 323 | 464 | 0.70 |
| Secret Rotation Validator | typescript-bun | opus46 | 13 | 49 | 3.8 | 217 | 548 | 0.40 |
| Secret Rotation Validator | typescript-bun | sonnet46 | 49 | 129 | 2.6 | 616 | 293 | 2.10 |

</details>

### LLM-as-Judge Scores

An LLM evaluates each test suite on four dimensions (1-5 scale):

- **Coverage** (1-5): Do tests exercise the key requirements? 1 = most untested, 5 = all covered.
- **Rigor** (1-5): Edge cases, error handling, boundary conditions? 1 = happy path only, 5 = thorough.
- **Design** (1-5): Test organization, fixtures, readability? 1 = messy/brittle, 5 = well-structured.
- **Overall** (1-5): Holistic quality — would you trust this suite to catch regressions? 1 = no, 5 = absolutely. Use this as the primary ranking metric.

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| bash | opus46 | **3.0** | 3.6 | 2.6 | 3.0 | $0.4007 |
| bash | sonnet46 | **3.9** | 4.2 | 3.0 | 3.9 | $0.4460 |
| default | opus46 | **3.1** | 3.9 | 2.9 | 3.2 | $0.4427 |
| default | sonnet46 | **3.8** | 4.2 | 3.5 | 4.2 | $0.4590 |
| powershell | opus46 | **3.1** | 3.6 | 2.5 | 3.5 | $0.4040 |
| powershell | sonnet46 | **3.5** | 4.1 | 3.1 | 3.8 | $0.5214 |
| typescript-bun | opus46 | **2.9** | 3.1 | 2.8 | 3.4 | $0.4744 |
| typescript-bun | sonnet46 | **3.9** | 4.0 | 3.6 | 4.2 | $0.4455 |
| **Total** | | | | | | **$3.5937** |


<details>
<summary>Sorted by avg overall (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| bash | sonnet46 | **3.9** | 4.2 | 3.0 | 3.9 | $0.4460 |
| typescript-bun | sonnet46 | **3.9** | 4.0 | 3.6 | 4.2 | $0.4455 |
| default | sonnet46 | **3.8** | 4.2 | 3.5 | 4.2 | $0.4590 |
| powershell | sonnet46 | **3.5** | 4.1 | 3.1 | 3.8 | $0.5214 |
| default | opus46 | **3.1** | 3.9 | 2.9 | 3.2 | $0.4427 |
| powershell | opus46 | **3.1** | 3.6 | 2.5 | 3.5 | $0.4040 |
| bash | opus46 | **3.0** | 3.6 | 2.6 | 3.0 | $0.4007 |
| typescript-bun | opus46 | **2.9** | 3.1 | 2.8 | 3.4 | $0.4744 |

</details>

<details>
<summary>Sorted by avg coverage (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| bash | sonnet46 | **3.9** | 4.2 | 3.0 | 3.9 | $0.4460 |
| default | sonnet46 | **3.8** | 4.2 | 3.5 | 4.2 | $0.4590 |
| powershell | sonnet46 | **3.5** | 4.1 | 3.1 | 3.8 | $0.5214 |
| typescript-bun | sonnet46 | **3.9** | 4.0 | 3.6 | 4.2 | $0.4455 |
| default | opus46 | **3.1** | 3.9 | 2.9 | 3.2 | $0.4427 |
| bash | opus46 | **3.0** | 3.6 | 2.6 | 3.0 | $0.4007 |
| powershell | opus46 | **3.1** | 3.6 | 2.5 | 3.5 | $0.4040 |
| typescript-bun | opus46 | **2.9** | 3.1 | 2.8 | 3.4 | $0.4744 |

</details>

<details>
<summary>Sorted by avg rigor (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| typescript-bun | sonnet46 | **3.9** | 4.0 | 3.6 | 4.2 | $0.4455 |
| default | sonnet46 | **3.8** | 4.2 | 3.5 | 4.2 | $0.4590 |
| powershell | sonnet46 | **3.5** | 4.1 | 3.1 | 3.8 | $0.5214 |
| bash | sonnet46 | **3.9** | 4.2 | 3.0 | 3.9 | $0.4460 |
| default | opus46 | **3.1** | 3.9 | 2.9 | 3.2 | $0.4427 |
| typescript-bun | opus46 | **2.9** | 3.1 | 2.8 | 3.4 | $0.4744 |
| bash | opus46 | **3.0** | 3.6 | 2.6 | 3.0 | $0.4007 |
| powershell | opus46 | **3.1** | 3.6 | 2.5 | 3.5 | $0.4040 |

</details>

<details>
<summary>Sorted by avg design (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| default | sonnet46 | **3.8** | 4.2 | 3.5 | 4.2 | $0.4590 |
| typescript-bun | sonnet46 | **3.9** | 4.0 | 3.6 | 4.2 | $0.4455 |
| bash | sonnet46 | **3.9** | 4.2 | 3.0 | 3.9 | $0.4460 |
| powershell | sonnet46 | **3.5** | 4.1 | 3.1 | 3.8 | $0.5214 |
| powershell | opus46 | **3.1** | 3.6 | 2.5 | 3.5 | $0.4040 |
| typescript-bun | opus46 | **2.9** | 3.1 | 2.8 | 3.4 | $0.4744 |
| default | opus46 | **3.1** | 3.9 | 2.9 | 3.2 | $0.4427 |
| bash | opus46 | **3.0** | 3.6 | 2.6 | 3.0 | $0.4007 |

</details>


<details>
<summary>Per-run LLM judge scores</summary>

| Task | Language | Model | Cov | Rig | Des | Ovr | Summary |
|------|------|-------|-----|-----|-----|-----|---------|
| Semantic Version Bumper | bash | opus46 | 4 | 3 | 4 | 4 | The test suite covers all primary requirements well: VERSION |
| Semantic Version Bumper | bash | sonnet46 | 4 | 3 | 4 | 4 | The test suite is well-organized with clear TDD cycle commen |
| Semantic Version Bumper | default | opus46 | 2 | 2 | 3 | 2 | The test suite only exercises three happy-path scenarios (pa |
| Semantic Version Bumper | default | sonnet46 | 5 | 4 | 5 | 4 | The test suite is well-structured and covers all six functio |
| Semantic Version Bumper | powershell | opus46 | 3 | 2 | 3 | 2 | The suite takes an interesting integration-first approach by |
| Semantic Version Bumper | powershell | sonnet46 | 5 | 3 | 4 | 4 | The suite covers all major requirements: reading version.txt |
| Semantic Version Bumper | typescript-bun | opus46 | 2 | 2 | 3 | 2 | The suite completely omits unit tests for all four core modu |
| Semantic Version Bumper | typescript-bun | sonnet46 | 3 | 3 | 4 | 3 | The test suite does a solid job covering the core algorithmi |
| PR Label Assigner | bash | opus46 | 3 | 2 | 2 | 2 | The test suite has a reasonable set of structural/static tes |
| PR Label Assigner | bash | sonnet46 | 5 | 4 | 5 | 5 | This is a high-quality test suite that thoroughly covers all |
| PR Label Assigner | default | opus46 | 5 | 4 | 4 | 4 | The test suite is comprehensive and covers all key requireme |
| PR Label Assigner | default | sonnet46 | 4 | 4 | 4 | 4 | The test suite is well-structured and covers the main requir |
| PR Label Assigner | powershell | opus46 | 4 | 3 | 4 | 4 | The test suite covers all major requirements well: glob-to-r |
| PR Label Assigner | powershell | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all major functional units — Test-Glob |
| PR Label Assigner | typescript-bun | opus46 | 4 | 3 | 5 | 4 | The test suite is well-structured and covers all core unit-l |
| PR Label Assigner | typescript-bun | sonnet46 | 5 | 4 | 5 | 5 | The test suite comprehensively covers all stated requirement |
| Dependency License Checker | bash | opus46 | 4 | 3 | 4 | 4 | The test suite is well-structured with a clear separation be |
| Dependency License Checker | bash | sonnet46 | 4 | 3 | 3 | 3 | The suite covers the core requirements well: script existenc |
| Dependency License Checker | default | opus46 | 4 | 3 | 4 | 4 | The suite covers all six public functions (parse_package_jso |
| Dependency License Checker | default | sonnet46 | 4 | 3 | 4 | 4 | The suite covers the main requirements well across 16 named  |
| Dependency License Checker | powershell | opus46 | 4 | 3 | 4 | 4 | The test suite covers all core requirements well: parsing bo |
| Dependency License Checker | powershell | sonnet46 | 5 | 4 | 4 | 4 | The test suite demonstrates strong coverage of all core requ |
| Dependency License Checker | typescript-bun | opus46 | 3 | 3 | 3 | 3 | The unit test suite is solid for the core modules — parser,  |
| Dependency License Checker | typescript-bun | sonnet46 | 3 | 3 | 4 | 3 | The test suite has solid coverage of the core business logic |
| Docker Image Tag Generator | bash | opus46 | 4 | 3 | 3 | 3 | The test suite covers all major requirements well: main/mast |
| Docker Image Tag Generator | bash | sonnet46 | 5 | 4 | 5 | 5 | This is a high-quality test suite that comprehensively cover |
| Docker Image Tag Generator | default | opus46 | 4 | 3 | 3 | 3 | The test suite covers all five core requirements (main→lates |
| Docker Image Tag Generator | default | sonnet46 | 5 | 4 | 5 | 4 | The test suite is comprehensive and well-structured. Coverag |
| Docker Image Tag Generator | powershell | opus46 | 4 | 2 | 3 | 3 | The suite covers six well-chosen scenarios (main, master, fe |
| Docker Image Tag Generator | powershell | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all four primary tag-generation rules  |
| Docker Image Tag Generator | typescript-bun | opus46 | 3 | 2 | 2 | 2 | The test suite is split into workflow-structure checks and a |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all primary requirements well: main/ma |
| Test Results Aggregator | bash | opus46 | 3 | 2 | 3 | 3 | The suite covers the main happy-path requirements well: it c |
| Test Results Aggregator | bash | sonnet46 | 4 | 2 | 3 | 3 | The suite covers all main requirements well: exact aggregate |
| Test Results Aggregator | default | opus46 | 3 | 2 | 2 | 2 | The test suite uses a two-layer strategy (workflow structure |
| Test Results Aggregator | default | sonnet46 | 4 | 3 | 4 | 4 | The suite covers all key requirements well: JUnit XML parsin |
| Test Results Aggregator | powershell | opus46 | 3 | 2 | 3 | 2 | The test suite validates the end-to-end pipeline through act |
| Test Results Aggregator | powershell | sonnet46 | 4 | 3 | 2 | 2 | The suite covers all five major functional areas (Parse-JUni |
| Test Results Aggregator | typescript-bun | opus46 | 3 | 3 | 3 | 3 | The suite follows the mandated act-based end-to-end approach |
| Test Results Aggregator | typescript-bun | sonnet46 | 5 | 5 | 5 | 5 | This is an exemplary test suite. Coverage is comprehensive:  |
| Environment Matrix Generator | bash | opus46 | 3 | 2 | 2 | 2 | The suite covers the main functional axes (basic cartesian p |
| Environment Matrix Generator | bash | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all major requirements: cartesian prod |
| Environment Matrix Generator | default | opus46 | 4 | 2 | 3 | 3 | The suite covers all six major requirements (cartesian produ |
| Environment Matrix Generator | default | sonnet46 | 5 | 4 | 4 | 4 | The test suite demonstrates strong coverage across all state |
| Environment Matrix Generator | powershell | opus46 | 4 | 3 | 4 | 3 | The test suite provides solid, well-organized coverage of th |
| Environment Matrix Generator | powershell | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all major requirements from the task d |
| Environment Matrix Generator | typescript-bun | opus46 | 3 | 2 | 2 | 2 | The test suite covers the major requirements (cartesian prod |
| Environment Matrix Generator | typescript-bun | sonnet46 | 3 | 3 | 3 | 3 | The unit tests in matrix-generator.test.ts cover the core ge |
| Artifact Cleanup Script | bash | opus46 | 4 | 3 | 3 | 3 | The test suite covers all three retention policies individua |
| Artifact Cleanup Script | bash | sonnet46 | 5 | 3 | 4 | 4 | The test suite covers all major requirements comprehensively |
| Artifact Cleanup Script | default | opus46 | 5 | 4 | 4 | 4 | The test suite covers all major requirements: artifact parsi |
| Artifact Cleanup Script | default | sonnet46 | 3 | 3 | 4 | 3 | The test suite covers the three core retention policies (max |
| Artifact Cleanup Script | powershell | opus46 | 4 | 3 | 4 | 4 | The test suite covers the primary requirements well: all thr |
| Artifact Cleanup Script | powershell | sonnet46 | 3 | 3 | 4 | 3 | The test suite covers the three core policy functions, the p |
| Artifact Cleanup Script | typescript-bun | opus46 | 4 | 4 | 5 | 4 | The test suite thoroughly covers all core retention policies |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 4 | 4 | 4 | 4 | The test suite thoroughly covers the three core retention po |
| Secret Rotation Validator | bash | opus46 | 4 | 3 | 3 | 3 | The test suite covers the main requirements well: both markd |
| Secret Rotation Validator | bash | sonnet46 | 3 | 2 | 3 | 3 | The suite covers the core happy-path requirements well: expi |
| Secret Rotation Validator | default | opus46 | 4 | 3 | 3 | 3 | The unit test suite (test_secret_rotation_validator.py) is w |
| Secret Rotation Validator | default | sonnet46 | 4 | 3 | 4 | 3 | The test suite covers all seven core requirement areas well: |
| Secret Rotation Validator | powershell | opus46 | 3 | 2 | 3 | 3 | The test suite covers the main happy-path requirements well: |
| Secret Rotation Validator | powershell | sonnet46 | 4 | 3 | 4 | 3 | The suite covers all major feature areas: secret classificat |
| Secret Rotation Validator | typescript-bun | opus46 | 3 | 3 | 4 | 3 | The unit tests for the core validator and formatter modules  |
| Secret Rotation Validator | typescript-bun | sonnet46 | 5 | 4 | 5 | 4 | The test suite demonstrates strong overall quality across th |

</details>

### Correlation: Structural Metrics vs LLM Scores

Spearman rank correlation between automated counts and LLM judge scores.
Values near +1.0 indicate the LLM agrees with the structural signal; near 0 means no relationship.

| Structural Metric | vs Coverage | vs Rigor | vs Design | vs Overall |
|-------------------|------------|---------|----------|-----------|
| Test count | 0.28 | 0.36 | 0.21 | 0.22 |
| Assertion count | 0.23 | 0.39 | 0.36 | 0.29 |
| Test:code ratio | 0.16 | 0.08 | -0.08 | -0.04 |

*Based on 64 runs with both structural and LLM scores.*

### LLM vs Structural Discrepancies

**Qualitative disagreements** — structural metrics look reasonable; the LLM judge is weighing factors the counters can't measure.

| Task | Language | Model | Tests | Asserts | Cov | Rig | Des | Ovr | Flag | Justification |
|------|------|-------|-------|---------|-----|-----|-----|-----|------|---------------|
| Docker Image Tag Generator | powershell | opus46 | 13 | 40 | 4 | 2 | 3 | 3 | LLM says low rigor (2/5) but 40 assertions detected | The suite covers six well-chosen scenarios (main, master, feature branch, PR, semver tag, sanitization) and adds useful workflow-structure checks (actionlint, file existence, YAML shape). Exact tag... |
| Test Results Aggregator | bash | opus46 | 14 | 43 | 3 | 2 | 3 | 3 | LLM says low rigor (2/5) but 43 assertions detected | The suite covers the main happy-path requirements well: it checks JUnit-only, JSON-only, and mixed scenarios through act with exact value assertions, verifies flaky-test detection by name, validate... |
| Secret Rotation Validator | bash | sonnet46 | 23 | 43 | 3 | 2 | 3 | 3 | LLM says low rigor (2/5) but 43 assertions detected | The suite covers the core happy-path requirements well: expired/warning/ok classification for both output formats, summary counts, report_date, required_by inclusion, the all-ok fixture, and workfl... |
| Secret Rotation Validator | powershell | opus46 | 47 | 48 | 3 | 2 | 3 | 3 | LLM says low rigor (2/5) but 48 assertions detected | The test suite covers the main happy-path requirements well: expired/warning/ok classification, both markdown and JSON output formats, workflow structure, and actionlint validation. Exact-value ass... |

## Per-Run Results

*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Artifact Cleanup Script | bash | opus46 | 5.7min | 50 | 2 | $1.50 | 3.0 | bash | ok |
| Artifact Cleanup Script | bash | sonnet46 | 7.2min | 35 | 1 | $0.77 | 4.0 | bash | ok |
| Artifact Cleanup Script | default | opus46 | 9.2min | 49 | 2 | $2.19 | 4.0 | python | ok |
| Artifact Cleanup Script | default | sonnet46 | 6.3min | 31 | 2 | $0.83 | 3.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 5.4min | 29 | 2 | $1.07 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 12.0min | 15 | 0 | $0.99 | 3.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 7.7min | 34 | 1 | $1.68 | 4.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 9.2min | 38 | 2 | $1.17 | 4.0 | typescript | ok |
| Dependency License Checker | bash | opus46 | 6.9min | 55 | 3 | $1.50 | 4.0 | bash | ok |
| Dependency License Checker | bash | sonnet46 | 14.1min | 42 | 3 | $1.68 | 3.0 | bash | ok |
| Dependency License Checker | default | opus46 | 5.9min | 39 | 0 | $1.24 | 4.0 | python | ok |
| Dependency License Checker | default | sonnet46 | 9.2min | 39 | 3 | $1.30 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 6.0min | 38 | 3 | $1.24 | 4.0 | powershell | ok |
| Dependency License Checker | powershell | sonnet46 | 12.3min | 58 | 2 | $1.93 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.8min | 48 | 3 | $1.35 | 3.0 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 9.5min | 43 | 2 | $1.47 | 3.0 | typescript | ok |
| Docker Image Tag Generator | bash | opus46 | 3.7min | 28 | 1 | $0.78 | 3.0 | bash | ok |
| Docker Image Tag Generator | bash | sonnet46 | 4.5min | 26 | 2 | $0.61 | 5.0 | bash | ok |
| Docker Image Tag Generator | default | opus46 | 5.5min | 27 | 2 | $1.25 | 3.0 | python | ok |
| Docker Image Tag Generator | default | sonnet46 | 8.4min | 35 | 1 | $1.00 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.9min | 24 | 0 | $1.39 | 3.0 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 9.2min | 35 | 2 | $1.13 | 4.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 8.6min | 38 | 1 | $1.53 | 2.0 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 12.0min | 25 | 3 | $0.98 | 4.0 | typescript | ok |
| Environment Matrix Generator | bash | opus46 | 4.1min | 42 | 1 | $0.98 | 2.0 | bash | ok |
| Environment Matrix Generator | bash | sonnet46 | 10.5min | 25 | 3 | $1.22 | 4.0 | bash | ok |
| Environment Matrix Generator | default | opus46 | 6.4min | 29 | 1 | $1.21 | 3.0 | python | ok |
| Environment Matrix Generator | default | sonnet46 | 7.8min | 36 | 5 | $1.05 | 4.0 | python | ok |
| Environment Matrix Generator | powershell | opus46 | 5.3min | 38 | 3 | $1.25 | 3.0 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46 | 11.5min | 54 | 1 | $1.46 | 4.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 6.0min | 42 | 3 | $1.10 | 2.0 | typescript | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 8.5min | 48 | 3 | $1.22 | 3.0 | typescript | ok |
| PR Label Assigner | bash | opus46 | 5.6min | 42 | 2 | $1.16 | 2.0 | bash | ok |
| PR Label Assigner | bash | sonnet46 | 13.2min | 39 | 6 | $1.73 | 5.0 | bash | ok |
| PR Label Assigner | default | opus46 | 7.7min | 29 | 2 | $1.57 | 4.0 | python | ok |
| PR Label Assigner | default | sonnet46 | 10.3min | 43 | 4 | $1.52 | 4.0 | python | ok |
| PR Label Assigner | powershell | opus46 | 11.4min | 35 | 2 | $1.93 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 8.7min | 29 | 1 | $1.09 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus46 | 5.1min | 33 | 2 | $1.01 | 4.0 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 8.1min | 43 | 1 | $0.89 | 5.0 | typescript | ok |
| Secret Rotation Validator | bash | opus46 | 7.8min | 38 | 1 | $1.78 | 3.0 | bash | ok |
| Secret Rotation Validator | bash | sonnet46 | 15.6min | 78 | 8 | $2.60 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus46 | 7.3min | 38 | 1 | $1.51 | 3.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 7.1min | 47 | 4 | $1.25 | 3.0 | python | ok |
| Secret Rotation Validator | powershell | opus46 | 12.4min | 30 | 0 | $1.99 | 3.0 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46 | 10.8min | 40 | 3 | $1.55 | 3.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 8.1min | 56 | 4 | $1.79 | 3.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 10.1min | 32 | 0 | $1.28 | 4.0 | typescript | ok |
| Semantic Version Bumper | bash | opus46 | 12.4min | 50 | 1 | $1.65 | 4.0 | bash | ok |
| Semantic Version Bumper | bash | sonnet46 | 9.0min | 57 | 6 | $1.38 | 4.0 | bash | ok |
| Semantic Version Bumper | default | opus46 | 7.1min | 28 | 1 | $1.33 | 2.0 | python | ok |
| Semantic Version Bumper | default | sonnet46 | 7.3min | 46 | 1 | $0.99 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | opus46 | 6.9min | 27 | 0 | $1.04 | 2.0 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46 | 11.4min | 43 | 3 | $0.92 | 4.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 10.3min | 32 | 1 | $1.54 | 2.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 30 | 1 | $0.97 | 3.0 | typescript | ok |
| Test Results Aggregator | bash | opus46 | 15.8min | 42 | 2 | $2.85 | 3.0 | bash | ok |
| Test Results Aggregator | bash | sonnet46 | 9.0min | 31 | 3 | $1.22 | 3.0 | bash | ok |
| Test Results Aggregator | default | opus46 | 5.7min | 35 | 3 | $1.27 | 2.0 | python | ok |
| Test Results Aggregator | default | sonnet46 | 9.9min | 24 | 2 | $1.20 | 4.0 | python | ok |
| Test Results Aggregator | powershell | opus46 | 10.0min | 48 | 2 | $2.45 | 2.0 | powershell | ok |
| Test Results Aggregator | powershell | sonnet46 | 11.8min | 29 | 1 | $1.36 | 2.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus46 | 2.3min | 29 | 1 | $0.61 | 3.0 | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 10.9min | 35 | 1 | $1.41 | 5.0 | typescript | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Docker Image Tag Generator | bash | sonnet46 | 4.5min | 26 | 2 | $0.61 | 5.0 | bash | ok |
| Test Results Aggregator | typescript-bun | opus46 | 2.3min | 29 | 1 | $0.61 | 3.0 | typescript | ok |
| Artifact Cleanup Script | bash | sonnet46 | 7.2min | 35 | 1 | $0.77 | 4.0 | bash | ok |
| Docker Image Tag Generator | bash | opus46 | 3.7min | 28 | 1 | $0.78 | 3.0 | bash | ok |
| Artifact Cleanup Script | default | sonnet46 | 6.3min | 31 | 2 | $0.83 | 3.0 | python | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 8.1min | 43 | 1 | $0.89 | 5.0 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet46 | 11.4min | 43 | 3 | $0.92 | 4.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 30 | 1 | $0.97 | 3.0 | typescript | ok |
| Environment Matrix Generator | bash | opus46 | 4.1min | 42 | 1 | $0.98 | 2.0 | bash | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 12.0min | 25 | 3 | $0.98 | 4.0 | typescript | ok |
| Semantic Version Bumper | default | sonnet46 | 7.3min | 46 | 1 | $0.99 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 12.0min | 15 | 0 | $0.99 | 3.0 | powershell | ok |
| Docker Image Tag Generator | default | sonnet46 | 8.4min | 35 | 1 | $1.00 | 4.0 | python | ok |
| PR Label Assigner | typescript-bun | opus46 | 5.1min | 33 | 2 | $1.01 | 4.0 | typescript | ok |
| Semantic Version Bumper | powershell | opus46 | 6.9min | 27 | 0 | $1.04 | 2.0 | powershell | ok |
| Environment Matrix Generator | default | sonnet46 | 7.8min | 36 | 5 | $1.05 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 5.4min | 29 | 2 | $1.07 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 8.7min | 29 | 1 | $1.09 | 4.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 6.0min | 42 | 3 | $1.10 | 2.0 | typescript | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 9.2min | 35 | 2 | $1.13 | 4.0 | powershell | ok |
| PR Label Assigner | bash | opus46 | 5.6min | 42 | 2 | $1.16 | 2.0 | bash | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 9.2min | 38 | 2 | $1.17 | 4.0 | typescript | ok |
| Test Results Aggregator | default | sonnet46 | 9.9min | 24 | 2 | $1.20 | 4.0 | python | ok |
| Environment Matrix Generator | default | opus46 | 6.4min | 29 | 1 | $1.21 | 3.0 | python | ok |
| Test Results Aggregator | bash | sonnet46 | 9.0min | 31 | 3 | $1.22 | 3.0 | bash | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 8.5min | 48 | 3 | $1.22 | 3.0 | typescript | ok |
| Environment Matrix Generator | bash | sonnet46 | 10.5min | 25 | 3 | $1.22 | 4.0 | bash | ok |
| Dependency License Checker | powershell | opus46 | 6.0min | 38 | 3 | $1.24 | 4.0 | powershell | ok |
| Dependency License Checker | default | opus46 | 5.9min | 39 | 0 | $1.24 | 4.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 7.1min | 47 | 4 | $1.25 | 3.0 | python | ok |
| Environment Matrix Generator | powershell | opus46 | 5.3min | 38 | 3 | $1.25 | 3.0 | powershell | ok |
| Docker Image Tag Generator | default | opus46 | 5.5min | 27 | 2 | $1.25 | 3.0 | python | ok |
| Test Results Aggregator | default | opus46 | 5.7min | 35 | 3 | $1.27 | 2.0 | python | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 10.1min | 32 | 0 | $1.28 | 4.0 | typescript | ok |
| Dependency License Checker | default | sonnet46 | 9.2min | 39 | 3 | $1.30 | 4.0 | python | ok |
| Semantic Version Bumper | default | opus46 | 7.1min | 28 | 1 | $1.33 | 2.0 | python | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.8min | 48 | 3 | $1.35 | 3.0 | typescript | ok |
| Test Results Aggregator | powershell | sonnet46 | 11.8min | 29 | 1 | $1.36 | 2.0 | powershell | ok |
| Semantic Version Bumper | bash | sonnet46 | 9.0min | 57 | 6 | $1.38 | 4.0 | bash | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.9min | 24 | 0 | $1.39 | 3.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 10.9min | 35 | 1 | $1.41 | 5.0 | typescript | ok |
| Environment Matrix Generator | powershell | sonnet46 | 11.5min | 54 | 1 | $1.46 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 9.5min | 43 | 2 | $1.47 | 3.0 | typescript | ok |
| Dependency License Checker | bash | opus46 | 6.9min | 55 | 3 | $1.50 | 4.0 | bash | ok |
| Artifact Cleanup Script | bash | opus46 | 5.7min | 50 | 2 | $1.50 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus46 | 7.3min | 38 | 1 | $1.51 | 3.0 | python | ok |
| PR Label Assigner | default | sonnet46 | 10.3min | 43 | 4 | $1.52 | 4.0 | python | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 8.6min | 38 | 1 | $1.53 | 2.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 10.3min | 32 | 1 | $1.54 | 2.0 | typescript | ok |
| Secret Rotation Validator | powershell | sonnet46 | 10.8min | 40 | 3 | $1.55 | 3.0 | powershell | ok |
| PR Label Assigner | default | opus46 | 7.7min | 29 | 2 | $1.57 | 4.0 | python | ok |
| Semantic Version Bumper | bash | opus46 | 12.4min | 50 | 1 | $1.65 | 4.0 | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 7.7min | 34 | 1 | $1.68 | 4.0 | typescript | ok |
| Dependency License Checker | bash | sonnet46 | 14.1min | 42 | 3 | $1.68 | 3.0 | bash | ok |
| PR Label Assigner | bash | sonnet46 | 13.2min | 39 | 6 | $1.73 | 5.0 | bash | ok |
| Secret Rotation Validator | bash | opus46 | 7.8min | 38 | 1 | $1.78 | 3.0 | bash | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 8.1min | 56 | 4 | $1.79 | 3.0 | typescript | ok |
| Dependency License Checker | powershell | sonnet46 | 12.3min | 58 | 2 | $1.93 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | opus46 | 11.4min | 35 | 2 | $1.93 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell | opus46 | 12.4min | 30 | 0 | $1.99 | 3.0 | powershell | ok |
| Artifact Cleanup Script | default | opus46 | 9.2min | 49 | 2 | $2.19 | 4.0 | python | ok |
| Test Results Aggregator | powershell | opus46 | 10.0min | 48 | 2 | $2.45 | 2.0 | powershell | ok |
| Secret Rotation Validator | bash | sonnet46 | 15.6min | 78 | 8 | $2.60 | 3.0 | bash | ok |
| Test Results Aggregator | bash | opus46 | 15.8min | 42 | 2 | $2.85 | 3.0 | bash | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Test Results Aggregator | typescript-bun | opus46 | 2.3min | 29 | 1 | $0.61 | 3.0 | typescript | ok |
| Docker Image Tag Generator | bash | opus46 | 3.7min | 28 | 1 | $0.78 | 3.0 | bash | ok |
| Environment Matrix Generator | bash | opus46 | 4.1min | 42 | 1 | $0.98 | 2.0 | bash | ok |
| Docker Image Tag Generator | bash | sonnet46 | 4.5min | 26 | 2 | $0.61 | 5.0 | bash | ok |
| PR Label Assigner | typescript-bun | opus46 | 5.1min | 33 | 2 | $1.01 | 4.0 | typescript | ok |
| Environment Matrix Generator | powershell | opus46 | 5.3min | 38 | 3 | $1.25 | 3.0 | powershell | ok |
| Artifact Cleanup Script | powershell | opus46 | 5.4min | 29 | 2 | $1.07 | 4.0 | powershell | ok |
| Docker Image Tag Generator | default | opus46 | 5.5min | 27 | 2 | $1.25 | 3.0 | python | ok |
| PR Label Assigner | bash | opus46 | 5.6min | 42 | 2 | $1.16 | 2.0 | bash | ok |
| Artifact Cleanup Script | bash | opus46 | 5.7min | 50 | 2 | $1.50 | 3.0 | bash | ok |
| Test Results Aggregator | default | opus46 | 5.7min | 35 | 3 | $1.27 | 2.0 | python | ok |
| Dependency License Checker | default | opus46 | 5.9min | 39 | 0 | $1.24 | 4.0 | python | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 6.0min | 42 | 3 | $1.10 | 2.0 | typescript | ok |
| Dependency License Checker | powershell | opus46 | 6.0min | 38 | 3 | $1.24 | 4.0 | powershell | ok |
| Artifact Cleanup Script | default | sonnet46 | 6.3min | 31 | 2 | $0.83 | 3.0 | python | ok |
| Environment Matrix Generator | default | opus46 | 6.4min | 29 | 1 | $1.21 | 3.0 | python | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.8min | 48 | 3 | $1.35 | 3.0 | typescript | ok |
| Dependency License Checker | bash | opus46 | 6.9min | 55 | 3 | $1.50 | 4.0 | bash | ok |
| Semantic Version Bumper | powershell | opus46 | 6.9min | 27 | 0 | $1.04 | 2.0 | powershell | ok |
| Secret Rotation Validator | default | sonnet46 | 7.1min | 47 | 4 | $1.25 | 3.0 | python | ok |
| Semantic Version Bumper | default | opus46 | 7.1min | 28 | 1 | $1.33 | 2.0 | python | ok |
| Artifact Cleanup Script | bash | sonnet46 | 7.2min | 35 | 1 | $0.77 | 4.0 | bash | ok |
| Secret Rotation Validator | default | opus46 | 7.3min | 38 | 1 | $1.51 | 3.0 | python | ok |
| Semantic Version Bumper | default | sonnet46 | 7.3min | 46 | 1 | $0.99 | 4.0 | python | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 7.7min | 34 | 1 | $1.68 | 4.0 | typescript | ok |
| PR Label Assigner | default | opus46 | 7.7min | 29 | 2 | $1.57 | 4.0 | python | ok |
| Secret Rotation Validator | bash | opus46 | 7.8min | 38 | 1 | $1.78 | 3.0 | bash | ok |
| Environment Matrix Generator | default | sonnet46 | 7.8min | 36 | 5 | $1.05 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.9min | 24 | 0 | $1.39 | 3.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 30 | 1 | $0.97 | 3.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 8.1min | 56 | 4 | $1.79 | 3.0 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 8.1min | 43 | 1 | $0.89 | 5.0 | typescript | ok |
| Docker Image Tag Generator | default | sonnet46 | 8.4min | 35 | 1 | $1.00 | 4.0 | python | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 8.5min | 48 | 3 | $1.22 | 3.0 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 8.6min | 38 | 1 | $1.53 | 2.0 | typescript | ok |
| PR Label Assigner | powershell | sonnet46 | 8.7min | 29 | 1 | $1.09 | 4.0 | powershell | ok |
| Semantic Version Bumper | bash | sonnet46 | 9.0min | 57 | 6 | $1.38 | 4.0 | bash | ok |
| Test Results Aggregator | bash | sonnet46 | 9.0min | 31 | 3 | $1.22 | 3.0 | bash | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 9.2min | 35 | 2 | $1.13 | 4.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 9.2min | 38 | 2 | $1.17 | 4.0 | typescript | ok |
| Dependency License Checker | default | sonnet46 | 9.2min | 39 | 3 | $1.30 | 4.0 | python | ok |
| Artifact Cleanup Script | default | opus46 | 9.2min | 49 | 2 | $2.19 | 4.0 | python | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 9.5min | 43 | 2 | $1.47 | 3.0 | typescript | ok |
| Test Results Aggregator | default | sonnet46 | 9.9min | 24 | 2 | $1.20 | 4.0 | python | ok |
| Test Results Aggregator | powershell | opus46 | 10.0min | 48 | 2 | $2.45 | 2.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 10.1min | 32 | 0 | $1.28 | 4.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 10.3min | 32 | 1 | $1.54 | 2.0 | typescript | ok |
| PR Label Assigner | default | sonnet46 | 10.3min | 43 | 4 | $1.52 | 4.0 | python | ok |
| Environment Matrix Generator | bash | sonnet46 | 10.5min | 25 | 3 | $1.22 | 4.0 | bash | ok |
| Secret Rotation Validator | powershell | sonnet46 | 10.8min | 40 | 3 | $1.55 | 3.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 10.9min | 35 | 1 | $1.41 | 5.0 | typescript | ok |
| PR Label Assigner | powershell | opus46 | 11.4min | 35 | 2 | $1.93 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46 | 11.4min | 43 | 3 | $0.92 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46 | 11.5min | 54 | 1 | $1.46 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | sonnet46 | 11.8min | 29 | 1 | $1.36 | 2.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 12.0min | 25 | 3 | $0.98 | 4.0 | typescript | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 12.0min | 15 | 0 | $0.99 | 3.0 | powershell | ok |
| Dependency License Checker | powershell | sonnet46 | 12.3min | 58 | 2 | $1.93 | 4.0 | powershell | ok |
| Semantic Version Bumper | bash | opus46 | 12.4min | 50 | 1 | $1.65 | 4.0 | bash | ok |
| Secret Rotation Validator | powershell | opus46 | 12.4min | 30 | 0 | $1.99 | 3.0 | powershell | ok |
| PR Label Assigner | bash | sonnet46 | 13.2min | 39 | 6 | $1.73 | 5.0 | bash | ok |
| Dependency License Checker | bash | sonnet46 | 14.1min | 42 | 3 | $1.68 | 3.0 | bash | ok |
| Secret Rotation Validator | bash | sonnet46 | 15.6min | 78 | 8 | $2.60 | 3.0 | bash | ok |
| Test Results Aggregator | bash | opus46 | 15.8min | 42 | 2 | $2.85 | 3.0 | bash | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Semantic Version Bumper | powershell | opus46 | 6.9min | 27 | 0 | $1.04 | 2.0 | powershell | ok |
| Dependency License Checker | default | opus46 | 5.9min | 39 | 0 | $1.24 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.9min | 24 | 0 | $1.39 | 3.0 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 12.0min | 15 | 0 | $0.99 | 3.0 | powershell | ok |
| Secret Rotation Validator | powershell | opus46 | 12.4min | 30 | 0 | $1.99 | 3.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 10.1min | 32 | 0 | $1.28 | 4.0 | typescript | ok |
| Semantic Version Bumper | bash | opus46 | 12.4min | 50 | 1 | $1.65 | 4.0 | bash | ok |
| Semantic Version Bumper | default | opus46 | 7.1min | 28 | 1 | $1.33 | 2.0 | python | ok |
| Semantic Version Bumper | default | sonnet46 | 7.3min | 46 | 1 | $0.99 | 4.0 | python | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 10.3min | 32 | 1 | $1.54 | 2.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 30 | 1 | $0.97 | 3.0 | typescript | ok |
| PR Label Assigner | powershell | sonnet46 | 8.7min | 29 | 1 | $1.09 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 8.1min | 43 | 1 | $0.89 | 5.0 | typescript | ok |
| Docker Image Tag Generator | bash | opus46 | 3.7min | 28 | 1 | $0.78 | 3.0 | bash | ok |
| Docker Image Tag Generator | default | sonnet46 | 8.4min | 35 | 1 | $1.00 | 4.0 | python | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 8.6min | 38 | 1 | $1.53 | 2.0 | typescript | ok |
| Test Results Aggregator | powershell | sonnet46 | 11.8min | 29 | 1 | $1.36 | 2.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus46 | 2.3min | 29 | 1 | $0.61 | 3.0 | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 10.9min | 35 | 1 | $1.41 | 5.0 | typescript | ok |
| Environment Matrix Generator | bash | opus46 | 4.1min | 42 | 1 | $0.98 | 2.0 | bash | ok |
| Environment Matrix Generator | default | opus46 | 6.4min | 29 | 1 | $1.21 | 3.0 | python | ok |
| Environment Matrix Generator | powershell | sonnet46 | 11.5min | 54 | 1 | $1.46 | 4.0 | powershell | ok |
| Artifact Cleanup Script | bash | sonnet46 | 7.2min | 35 | 1 | $0.77 | 4.0 | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 7.7min | 34 | 1 | $1.68 | 4.0 | typescript | ok |
| Secret Rotation Validator | bash | opus46 | 7.8min | 38 | 1 | $1.78 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus46 | 7.3min | 38 | 1 | $1.51 | 3.0 | python | ok |
| PR Label Assigner | bash | opus46 | 5.6min | 42 | 2 | $1.16 | 2.0 | bash | ok |
| PR Label Assigner | default | opus46 | 7.7min | 29 | 2 | $1.57 | 4.0 | python | ok |
| PR Label Assigner | powershell | opus46 | 11.4min | 35 | 2 | $1.93 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus46 | 5.1min | 33 | 2 | $1.01 | 4.0 | typescript | ok |
| Dependency License Checker | powershell | sonnet46 | 12.3min | 58 | 2 | $1.93 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 9.5min | 43 | 2 | $1.47 | 3.0 | typescript | ok |
| Docker Image Tag Generator | bash | sonnet46 | 4.5min | 26 | 2 | $0.61 | 5.0 | bash | ok |
| Docker Image Tag Generator | default | opus46 | 5.5min | 27 | 2 | $1.25 | 3.0 | python | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 9.2min | 35 | 2 | $1.13 | 4.0 | powershell | ok |
| Test Results Aggregator | bash | opus46 | 15.8min | 42 | 2 | $2.85 | 3.0 | bash | ok |
| Test Results Aggregator | default | sonnet46 | 9.9min | 24 | 2 | $1.20 | 4.0 | python | ok |
| Test Results Aggregator | powershell | opus46 | 10.0min | 48 | 2 | $2.45 | 2.0 | powershell | ok |
| Artifact Cleanup Script | bash | opus46 | 5.7min | 50 | 2 | $1.50 | 3.0 | bash | ok |
| Artifact Cleanup Script | default | opus46 | 9.2min | 49 | 2 | $2.19 | 4.0 | python | ok |
| Artifact Cleanup Script | default | sonnet46 | 6.3min | 31 | 2 | $0.83 | 3.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 5.4min | 29 | 2 | $1.07 | 4.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 9.2min | 38 | 2 | $1.17 | 4.0 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet46 | 11.4min | 43 | 3 | $0.92 | 4.0 | powershell | ok |
| Dependency License Checker | bash | opus46 | 6.9min | 55 | 3 | $1.50 | 4.0 | bash | ok |
| Dependency License Checker | bash | sonnet46 | 14.1min | 42 | 3 | $1.68 | 3.0 | bash | ok |
| Dependency License Checker | default | sonnet46 | 9.2min | 39 | 3 | $1.30 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 6.0min | 38 | 3 | $1.24 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.8min | 48 | 3 | $1.35 | 3.0 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 12.0min | 25 | 3 | $0.98 | 4.0 | typescript | ok |
| Test Results Aggregator | bash | sonnet46 | 9.0min | 31 | 3 | $1.22 | 3.0 | bash | ok |
| Test Results Aggregator | default | opus46 | 5.7min | 35 | 3 | $1.27 | 2.0 | python | ok |
| Environment Matrix Generator | bash | sonnet46 | 10.5min | 25 | 3 | $1.22 | 4.0 | bash | ok |
| Environment Matrix Generator | powershell | opus46 | 5.3min | 38 | 3 | $1.25 | 3.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 6.0min | 42 | 3 | $1.10 | 2.0 | typescript | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 8.5min | 48 | 3 | $1.22 | 3.0 | typescript | ok |
| Secret Rotation Validator | powershell | sonnet46 | 10.8min | 40 | 3 | $1.55 | 3.0 | powershell | ok |
| PR Label Assigner | default | sonnet46 | 10.3min | 43 | 4 | $1.52 | 4.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 7.1min | 47 | 4 | $1.25 | 3.0 | python | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 8.1min | 56 | 4 | $1.79 | 3.0 | typescript | ok |
| Environment Matrix Generator | default | sonnet46 | 7.8min | 36 | 5 | $1.05 | 4.0 | python | ok |
| Semantic Version Bumper | bash | sonnet46 | 9.0min | 57 | 6 | $1.38 | 4.0 | bash | ok |
| PR Label Assigner | bash | sonnet46 | 13.2min | 39 | 6 | $1.73 | 5.0 | bash | ok |
| Secret Rotation Validator | bash | sonnet46 | 15.6min | 78 | 8 | $2.60 | 3.0 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Artifact Cleanup Script | powershell | sonnet46 | 12.0min | 15 | 0 | $0.99 | 3.0 | powershell | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.9min | 24 | 0 | $1.39 | 3.0 | powershell | ok |
| Test Results Aggregator | default | sonnet46 | 9.9min | 24 | 2 | $1.20 | 4.0 | python | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 12.0min | 25 | 3 | $0.98 | 4.0 | typescript | ok |
| Environment Matrix Generator | bash | sonnet46 | 10.5min | 25 | 3 | $1.22 | 4.0 | bash | ok |
| Docker Image Tag Generator | bash | sonnet46 | 4.5min | 26 | 2 | $0.61 | 5.0 | bash | ok |
| Semantic Version Bumper | powershell | opus46 | 6.9min | 27 | 0 | $1.04 | 2.0 | powershell | ok |
| Docker Image Tag Generator | default | opus46 | 5.5min | 27 | 2 | $1.25 | 3.0 | python | ok |
| Semantic Version Bumper | default | opus46 | 7.1min | 28 | 1 | $1.33 | 2.0 | python | ok |
| Docker Image Tag Generator | bash | opus46 | 3.7min | 28 | 1 | $0.78 | 3.0 | bash | ok |
| PR Label Assigner | default | opus46 | 7.7min | 29 | 2 | $1.57 | 4.0 | python | ok |
| PR Label Assigner | powershell | sonnet46 | 8.7min | 29 | 1 | $1.09 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | sonnet46 | 11.8min | 29 | 1 | $1.36 | 2.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus46 | 2.3min | 29 | 1 | $0.61 | 3.0 | typescript | ok |
| Environment Matrix Generator | default | opus46 | 6.4min | 29 | 1 | $1.21 | 3.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 5.4min | 29 | 2 | $1.07 | 4.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 30 | 1 | $0.97 | 3.0 | typescript | ok |
| Secret Rotation Validator | powershell | opus46 | 12.4min | 30 | 0 | $1.99 | 3.0 | powershell | ok |
| Test Results Aggregator | bash | sonnet46 | 9.0min | 31 | 3 | $1.22 | 3.0 | bash | ok |
| Artifact Cleanup Script | default | sonnet46 | 6.3min | 31 | 2 | $0.83 | 3.0 | python | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 10.3min | 32 | 1 | $1.54 | 2.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 10.1min | 32 | 0 | $1.28 | 4.0 | typescript | ok |
| PR Label Assigner | typescript-bun | opus46 | 5.1min | 33 | 2 | $1.01 | 4.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 7.7min | 34 | 1 | $1.68 | 4.0 | typescript | ok |
| PR Label Assigner | powershell | opus46 | 11.4min | 35 | 2 | $1.93 | 4.0 | powershell | ok |
| Docker Image Tag Generator | default | sonnet46 | 8.4min | 35 | 1 | $1.00 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 9.2min | 35 | 2 | $1.13 | 4.0 | powershell | ok |
| Test Results Aggregator | default | opus46 | 5.7min | 35 | 3 | $1.27 | 2.0 | python | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 10.9min | 35 | 1 | $1.41 | 5.0 | typescript | ok |
| Artifact Cleanup Script | bash | sonnet46 | 7.2min | 35 | 1 | $0.77 | 4.0 | bash | ok |
| Environment Matrix Generator | default | sonnet46 | 7.8min | 36 | 5 | $1.05 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 6.0min | 38 | 3 | $1.24 | 4.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 8.6min | 38 | 1 | $1.53 | 2.0 | typescript | ok |
| Environment Matrix Generator | powershell | opus46 | 5.3min | 38 | 3 | $1.25 | 3.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 9.2min | 38 | 2 | $1.17 | 4.0 | typescript | ok |
| Secret Rotation Validator | bash | opus46 | 7.8min | 38 | 1 | $1.78 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus46 | 7.3min | 38 | 1 | $1.51 | 3.0 | python | ok |
| PR Label Assigner | bash | sonnet46 | 13.2min | 39 | 6 | $1.73 | 5.0 | bash | ok |
| Dependency License Checker | default | opus46 | 5.9min | 39 | 0 | $1.24 | 4.0 | python | ok |
| Dependency License Checker | default | sonnet46 | 9.2min | 39 | 3 | $1.30 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | sonnet46 | 10.8min | 40 | 3 | $1.55 | 3.0 | powershell | ok |
| PR Label Assigner | bash | opus46 | 5.6min | 42 | 2 | $1.16 | 2.0 | bash | ok |
| Dependency License Checker | bash | sonnet46 | 14.1min | 42 | 3 | $1.68 | 3.0 | bash | ok |
| Test Results Aggregator | bash | opus46 | 15.8min | 42 | 2 | $2.85 | 3.0 | bash | ok |
| Environment Matrix Generator | bash | opus46 | 4.1min | 42 | 1 | $0.98 | 2.0 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 6.0min | 42 | 3 | $1.10 | 2.0 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet46 | 11.4min | 43 | 3 | $0.92 | 4.0 | powershell | ok |
| PR Label Assigner | default | sonnet46 | 10.3min | 43 | 4 | $1.52 | 4.0 | python | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 8.1min | 43 | 1 | $0.89 | 5.0 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 9.5min | 43 | 2 | $1.47 | 3.0 | typescript | ok |
| Semantic Version Bumper | default | sonnet46 | 7.3min | 46 | 1 | $0.99 | 4.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 7.1min | 47 | 4 | $1.25 | 3.0 | python | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.8min | 48 | 3 | $1.35 | 3.0 | typescript | ok |
| Test Results Aggregator | powershell | opus46 | 10.0min | 48 | 2 | $2.45 | 2.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 8.5min | 48 | 3 | $1.22 | 3.0 | typescript | ok |
| Artifact Cleanup Script | default | opus46 | 9.2min | 49 | 2 | $2.19 | 4.0 | python | ok |
| Semantic Version Bumper | bash | opus46 | 12.4min | 50 | 1 | $1.65 | 4.0 | bash | ok |
| Artifact Cleanup Script | bash | opus46 | 5.7min | 50 | 2 | $1.50 | 3.0 | bash | ok |
| Environment Matrix Generator | powershell | sonnet46 | 11.5min | 54 | 1 | $1.46 | 4.0 | powershell | ok |
| Dependency License Checker | bash | opus46 | 6.9min | 55 | 3 | $1.50 | 4.0 | bash | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 8.1min | 56 | 4 | $1.79 | 3.0 | typescript | ok |
| Semantic Version Bumper | bash | sonnet46 | 9.0min | 57 | 6 | $1.38 | 4.0 | bash | ok |
| Dependency License Checker | powershell | sonnet46 | 12.3min | 58 | 2 | $1.93 | 4.0 | powershell | ok |
| Secret Rotation Validator | bash | sonnet46 | 15.6min | 78 | 8 | $2.60 | 3.0 | bash | ok |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | bash | sonnet46 | 13.2min | 39 | 6 | $1.73 | 5.0 | bash | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 8.1min | 43 | 1 | $0.89 | 5.0 | typescript | ok |
| Docker Image Tag Generator | bash | sonnet46 | 4.5min | 26 | 2 | $0.61 | 5.0 | bash | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 10.9min | 35 | 1 | $1.41 | 5.0 | typescript | ok |
| Semantic Version Bumper | bash | opus46 | 12.4min | 50 | 1 | $1.65 | 4.0 | bash | ok |
| Semantic Version Bumper | bash | sonnet46 | 9.0min | 57 | 6 | $1.38 | 4.0 | bash | ok |
| Semantic Version Bumper | default | sonnet46 | 7.3min | 46 | 1 | $0.99 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | sonnet46 | 11.4min | 43 | 3 | $0.92 | 4.0 | powershell | ok |
| PR Label Assigner | default | opus46 | 7.7min | 29 | 2 | $1.57 | 4.0 | python | ok |
| PR Label Assigner | default | sonnet46 | 10.3min | 43 | 4 | $1.52 | 4.0 | python | ok |
| PR Label Assigner | powershell | opus46 | 11.4min | 35 | 2 | $1.93 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 8.7min | 29 | 1 | $1.09 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus46 | 5.1min | 33 | 2 | $1.01 | 4.0 | typescript | ok |
| Dependency License Checker | bash | opus46 | 6.9min | 55 | 3 | $1.50 | 4.0 | bash | ok |
| Dependency License Checker | default | opus46 | 5.9min | 39 | 0 | $1.24 | 4.0 | python | ok |
| Dependency License Checker | default | sonnet46 | 9.2min | 39 | 3 | $1.30 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 6.0min | 38 | 3 | $1.24 | 4.0 | powershell | ok |
| Dependency License Checker | powershell | sonnet46 | 12.3min | 58 | 2 | $1.93 | 4.0 | powershell | ok |
| Docker Image Tag Generator | default | sonnet46 | 8.4min | 35 | 1 | $1.00 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 9.2min | 35 | 2 | $1.13 | 4.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 12.0min | 25 | 3 | $0.98 | 4.0 | typescript | ok |
| Test Results Aggregator | default | sonnet46 | 9.9min | 24 | 2 | $1.20 | 4.0 | python | ok |
| Environment Matrix Generator | bash | sonnet46 | 10.5min | 25 | 3 | $1.22 | 4.0 | bash | ok |
| Environment Matrix Generator | default | sonnet46 | 7.8min | 36 | 5 | $1.05 | 4.0 | python | ok |
| Environment Matrix Generator | powershell | sonnet46 | 11.5min | 54 | 1 | $1.46 | 4.0 | powershell | ok |
| Artifact Cleanup Script | bash | sonnet46 | 7.2min | 35 | 1 | $0.77 | 4.0 | bash | ok |
| Artifact Cleanup Script | default | opus46 | 9.2min | 49 | 2 | $2.19 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 5.4min | 29 | 2 | $1.07 | 4.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 7.7min | 34 | 1 | $1.68 | 4.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 9.2min | 38 | 2 | $1.17 | 4.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 10.1min | 32 | 0 | $1.28 | 4.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 30 | 1 | $0.97 | 3.0 | typescript | ok |
| Dependency License Checker | bash | sonnet46 | 14.1min | 42 | 3 | $1.68 | 3.0 | bash | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.8min | 48 | 3 | $1.35 | 3.0 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 9.5min | 43 | 2 | $1.47 | 3.0 | typescript | ok |
| Docker Image Tag Generator | bash | opus46 | 3.7min | 28 | 1 | $0.78 | 3.0 | bash | ok |
| Docker Image Tag Generator | default | opus46 | 5.5min | 27 | 2 | $1.25 | 3.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.9min | 24 | 0 | $1.39 | 3.0 | powershell | ok |
| Test Results Aggregator | bash | opus46 | 15.8min | 42 | 2 | $2.85 | 3.0 | bash | ok |
| Test Results Aggregator | bash | sonnet46 | 9.0min | 31 | 3 | $1.22 | 3.0 | bash | ok |
| Test Results Aggregator | typescript-bun | opus46 | 2.3min | 29 | 1 | $0.61 | 3.0 | typescript | ok |
| Environment Matrix Generator | default | opus46 | 6.4min | 29 | 1 | $1.21 | 3.0 | python | ok |
| Environment Matrix Generator | powershell | opus46 | 5.3min | 38 | 3 | $1.25 | 3.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 8.5min | 48 | 3 | $1.22 | 3.0 | typescript | ok |
| Artifact Cleanup Script | bash | opus46 | 5.7min | 50 | 2 | $1.50 | 3.0 | bash | ok |
| Artifact Cleanup Script | default | sonnet46 | 6.3min | 31 | 2 | $0.83 | 3.0 | python | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 12.0min | 15 | 0 | $0.99 | 3.0 | powershell | ok |
| Secret Rotation Validator | bash | opus46 | 7.8min | 38 | 1 | $1.78 | 3.0 | bash | ok |
| Secret Rotation Validator | bash | sonnet46 | 15.6min | 78 | 8 | $2.60 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus46 | 7.3min | 38 | 1 | $1.51 | 3.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 7.1min | 47 | 4 | $1.25 | 3.0 | python | ok |
| Secret Rotation Validator | powershell | opus46 | 12.4min | 30 | 0 | $1.99 | 3.0 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46 | 10.8min | 40 | 3 | $1.55 | 3.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 8.1min | 56 | 4 | $1.79 | 3.0 | typescript | ok |
| Semantic Version Bumper | default | opus46 | 7.1min | 28 | 1 | $1.33 | 2.0 | python | ok |
| Semantic Version Bumper | powershell | opus46 | 6.9min | 27 | 0 | $1.04 | 2.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 10.3min | 32 | 1 | $1.54 | 2.0 | typescript | ok |
| PR Label Assigner | bash | opus46 | 5.6min | 42 | 2 | $1.16 | 2.0 | bash | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 8.6min | 38 | 1 | $1.53 | 2.0 | typescript | ok |
| Test Results Aggregator | default | opus46 | 5.7min | 35 | 3 | $1.27 | 2.0 | python | ok |
| Test Results Aggregator | powershell | opus46 | 10.0min | 48 | 2 | $2.45 | 2.0 | powershell | ok |
| Test Results Aggregator | powershell | sonnet46 | 11.8min | 29 | 1 | $1.36 | 2.0 | powershell | ok |
| Environment Matrix Generator | bash | opus46 | 4.1min | 42 | 1 | $0.98 | 2.0 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 6.0min | 42 | 3 | $1.10 | 2.0 | typescript | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*