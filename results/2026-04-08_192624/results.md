# Benchmark Results: Language Comparison

**Last updated:** 2026-04-18 07:13:12 AM ET

**Status:** 64/64 runs completed, 0 remaining
**Total cost so far:** $84.25
**Total agent time so far:** 726.1 min

## Tiers by Language/Model/Effort

*Duration / Cost tier = ratio of this combo's average to the best combo's average on that axis (lower ratio = better). Bands: **A** ≤1.15×, **B** ≤1.40×, **C** ≤1.80×, **D** ≤2.50×, **E** >2.50×.*
*LLM Score tier = absolute Overall score band. **A** ≥4.5, **B** ≥3.5, **C** ≥2.5, **D** ≥1.5, **E** <1.5, `—` = no data.*
*If every row in a column is tier A, those combos are effectively tied on that axis.*

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | opus46 | B (8.7min) | B ($1.37) | C (3.0) |
| bash | sonnet46 | C (10.2min) | A ($1.06) | C (3.4) |
| default | opus46 | A (7.0min) | B ($1.29) | C (3.1) |
| default | sonnet46 | D (14.6min) | B ($1.38) | B (4.2) |
| powershell | opus46 | B (9.1min) | A ($1.20) | C (2.9) |
| powershell | sonnet46 | E (21.0min) | C ($1.67) | C (3.4) |
| typescript-bun | opus46 | B (8.9min) | B ($1.35) | C (3.1) |
| typescript-bun | sonnet46 | C (11.3min) | B ($1.22) | C (3.4) |


<details>
<summary>Sorted by Duration tier (A-first), then avg of Cost/LLM tiers</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| default | opus46 | A (7.0min) | B ($1.29) | C (3.1) |
| powershell | opus46 | B (9.1min) | A ($1.20) | C (2.9) |
| bash | opus46 | B (8.7min) | B ($1.37) | C (3.0) |
| typescript-bun | opus46 | B (8.9min) | B ($1.35) | C (3.1) |
| bash | sonnet46 | C (10.2min) | A ($1.06) | C (3.4) |
| typescript-bun | sonnet46 | C (11.3min) | B ($1.22) | C (3.4) |
| default | sonnet46 | D (14.6min) | B ($1.38) | B (4.2) |
| powershell | sonnet46 | E (21.0min) | C ($1.67) | C (3.4) |

</details>

<details>
<summary>Sorted by Cost tier (A-first), then avg of Duration/LLM tiers</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| powershell | opus46 | B (9.1min) | A ($1.20) | C (2.9) |
| bash | sonnet46 | C (10.2min) | A ($1.06) | C (3.4) |
| default | opus46 | A (7.0min) | B ($1.29) | C (3.1) |
| bash | opus46 | B (8.7min) | B ($1.37) | C (3.0) |
| typescript-bun | opus46 | B (8.9min) | B ($1.35) | C (3.1) |
| default | sonnet46 | D (14.6min) | B ($1.38) | B (4.2) |
| typescript-bun | sonnet46 | C (11.3min) | B ($1.22) | C (3.4) |
| powershell | sonnet46 | E (21.0min) | C ($1.67) | C (3.4) |

</details>

<details>
<summary>Sorted by LLM Score tier (A-first; no-data last), then avg of Duration/Cost tiers</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| default | sonnet46 | D (14.6min) | B ($1.38) | B (4.2) |
| default | opus46 | A (7.0min) | B ($1.29) | C (3.1) |
| powershell | opus46 | B (9.1min) | A ($1.20) | C (2.9) |
| bash | opus46 | B (8.7min) | B ($1.37) | C (3.0) |
| bash | sonnet46 | C (10.2min) | A ($1.06) | C (3.4) |
| typescript-bun | opus46 | B (8.9min) | B ($1.35) | C (3.1) |
| typescript-bun | sonnet46 | C (11.3min) | B ($1.22) | C (3.4) |
| powershell | sonnet46 | E (21.0min) | C ($1.67) | C (3.4) |

</details>

## Rankings by Language/Model/Effort

*Lower rank = better on that axis (1 = fastest / cheapest / highest LLM score).*
*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | opus46 | 2 (8.7min) | 6 ($1.37) | 7 (3.0) |
| bash | sonnet46 | 5 (10.2min) | 1 ($1.06) | 2 (3.4) |
| default | opus46 | 1 (7.0min) | 4 ($1.29) | 5 (3.1) |
| default | sonnet46 | 7 (14.6min) | 7 ($1.38) | 1 (4.2) |
| powershell | opus46 | 4 (9.1min) | 2 ($1.20) | 8 (2.9) |
| powershell | sonnet46 | 8 (21.0min) | 8 ($1.67) | 3 (3.4) |
| typescript-bun | opus46 | 3 (8.9min) | 5 ($1.35) | 6 (3.1) |
| typescript-bun | sonnet46 | 6 (11.3min) | 3 ($1.22) | 4 (3.4) |


<details>
<summary>Sorted by Duration rank (fastest first)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| default | opus46 | 1 (7.0min) | 4 ($1.29) | 5 (3.1) |
| bash | opus46 | 2 (8.7min) | 6 ($1.37) | 7 (3.0) |
| typescript-bun | opus46 | 3 (8.9min) | 5 ($1.35) | 6 (3.1) |
| powershell | opus46 | 4 (9.1min) | 2 ($1.20) | 8 (2.9) |
| bash | sonnet46 | 5 (10.2min) | 1 ($1.06) | 2 (3.4) |
| typescript-bun | sonnet46 | 6 (11.3min) | 3 ($1.22) | 4 (3.4) |
| default | sonnet46 | 7 (14.6min) | 7 ($1.38) | 1 (4.2) |
| powershell | sonnet46 | 8 (21.0min) | 8 ($1.67) | 3 (3.4) |

</details>

<details>
<summary>Sorted by Cost rank (cheapest first)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | sonnet46 | 5 (10.2min) | 1 ($1.06) | 2 (3.4) |
| powershell | opus46 | 4 (9.1min) | 2 ($1.20) | 8 (2.9) |
| typescript-bun | sonnet46 | 6 (11.3min) | 3 ($1.22) | 4 (3.4) |
| default | opus46 | 1 (7.0min) | 4 ($1.29) | 5 (3.1) |
| typescript-bun | opus46 | 3 (8.9min) | 5 ($1.35) | 6 (3.1) |
| bash | opus46 | 2 (8.7min) | 6 ($1.37) | 7 (3.0) |
| default | sonnet46 | 7 (14.6min) | 7 ($1.38) | 1 (4.2) |
| powershell | sonnet46 | 8 (21.0min) | 8 ($1.67) | 3 (3.4) |

</details>

<details>
<summary>Sorted by LLM Score rank (best first; no-data last)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| default | sonnet46 | 7 (14.6min) | 7 ($1.38) | 1 (4.2) |
| bash | sonnet46 | 5 (10.2min) | 1 ($1.06) | 2 (3.4) |
| powershell | sonnet46 | 8 (21.0min) | 8 ($1.67) | 3 (3.4) |
| typescript-bun | sonnet46 | 6 (11.3min) | 3 ($1.22) | 4 (3.4) |
| default | opus46 | 1 (7.0min) | 4 ($1.29) | 5 (3.1) |
| typescript-bun | opus46 | 3 (8.9min) | 5 ($1.35) | 6 (3.1) |
| bash | opus46 | 2 (8.7min) | 6 ($1.37) | 7 (3.0) |
| powershell | opus46 | 4 (9.1min) | 2 ($1.20) | 8 (2.9) |

</details>

## Comparison by Language/Model/Effort
*Avg LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| bash | opus46 | 8 | 8.7min | 7.9min | 1.8 | 39 | $1.37 | $10.93 | 3.0 |
| bash | sonnet46 | 8 | 10.2min | 9.6min | 4.1 | 38 | $1.06 | $8.45 | 3.4 |
| default | opus46 | 8 | 7.0min | 6.8min | 1.2 | 36 | $1.29 | $10.31 | 3.1 |
| default | sonnet46 | 8 | 14.6min | 13.6min | 1.1 | 32 | $1.38 | $11.06 | 4.2 |
| powershell | opus46 | 8 | 9.1min | 6.9min | 1.2 | 34 | $1.20 | $9.62 | 2.9 |
| powershell | sonnet46 | 8 | 21.0min | 15.0min | 0.5 | 42 | $1.67 | $13.37 | 3.4 |
| typescript-bun | opus46 | 8 | 8.9min | 7.2min | 1.5 | 39 | $1.35 | $10.78 | 3.1 |
| typescript-bun | sonnet46 | 8 | 11.3min | 9.4min | 2.2 | 33 | $1.22 | $9.74 | 3.4 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| bash | sonnet46 | 8 | 10.2min | 9.6min | 4.1 | 38 | $1.06 | $8.45 | 3.4 |
| powershell | opus46 | 8 | 9.1min | 6.9min | 1.2 | 34 | $1.20 | $9.62 | 2.9 |
| typescript-bun | sonnet46 | 8 | 11.3min | 9.4min | 2.2 | 33 | $1.22 | $9.74 | 3.4 |
| default | opus46 | 8 | 7.0min | 6.8min | 1.2 | 36 | $1.29 | $10.31 | 3.1 |
| typescript-bun | opus46 | 8 | 8.9min | 7.2min | 1.5 | 39 | $1.35 | $10.78 | 3.1 |
| bash | opus46 | 8 | 8.7min | 7.9min | 1.8 | 39 | $1.37 | $10.93 | 3.0 |
| default | sonnet46 | 8 | 14.6min | 13.6min | 1.1 | 32 | $1.38 | $11.06 | 4.2 |
| powershell | sonnet46 | 8 | 21.0min | 15.0min | 0.5 | 42 | $1.67 | $13.37 | 3.4 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| default | opus46 | 8 | 7.0min | 6.8min | 1.2 | 36 | $1.29 | $10.31 | 3.1 |
| bash | opus46 | 8 | 8.7min | 7.9min | 1.8 | 39 | $1.37 | $10.93 | 3.0 |
| typescript-bun | opus46 | 8 | 8.9min | 7.2min | 1.5 | 39 | $1.35 | $10.78 | 3.1 |
| powershell | opus46 | 8 | 9.1min | 6.9min | 1.2 | 34 | $1.20 | $9.62 | 2.9 |
| bash | sonnet46 | 8 | 10.2min | 9.6min | 4.1 | 38 | $1.06 | $8.45 | 3.4 |
| typescript-bun | sonnet46 | 8 | 11.3min | 9.4min | 2.2 | 33 | $1.22 | $9.74 | 3.4 |
| default | sonnet46 | 8 | 14.6min | 13.6min | 1.1 | 32 | $1.38 | $11.06 | 4.2 |
| powershell | sonnet46 | 8 | 21.0min | 15.0min | 0.5 | 42 | $1.67 | $13.37 | 3.4 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| default | opus46 | 8 | 7.0min | 6.8min | 1.2 | 36 | $1.29 | $10.31 | 3.1 |
| powershell | opus46 | 8 | 9.1min | 6.9min | 1.2 | 34 | $1.20 | $9.62 | 2.9 |
| typescript-bun | opus46 | 8 | 8.9min | 7.2min | 1.5 | 39 | $1.35 | $10.78 | 3.1 |
| bash | opus46 | 8 | 8.7min | 7.9min | 1.8 | 39 | $1.37 | $10.93 | 3.0 |
| typescript-bun | sonnet46 | 8 | 11.3min | 9.4min | 2.2 | 33 | $1.22 | $9.74 | 3.4 |
| bash | sonnet46 | 8 | 10.2min | 9.6min | 4.1 | 38 | $1.06 | $8.45 | 3.4 |
| default | sonnet46 | 8 | 14.6min | 13.6min | 1.1 | 32 | $1.38 | $11.06 | 4.2 |
| powershell | sonnet46 | 8 | 21.0min | 15.0min | 0.5 | 42 | $1.67 | $13.37 | 3.4 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| powershell | sonnet46 | 8 | 21.0min | 15.0min | 0.5 | 42 | $1.67 | $13.37 | 3.4 |
| default | sonnet46 | 8 | 14.6min | 13.6min | 1.1 | 32 | $1.38 | $11.06 | 4.2 |
| default | opus46 | 8 | 7.0min | 6.8min | 1.2 | 36 | $1.29 | $10.31 | 3.1 |
| powershell | opus46 | 8 | 9.1min | 6.9min | 1.2 | 34 | $1.20 | $9.62 | 2.9 |
| typescript-bun | opus46 | 8 | 8.9min | 7.2min | 1.5 | 39 | $1.35 | $10.78 | 3.1 |
| bash | opus46 | 8 | 8.7min | 7.9min | 1.8 | 39 | $1.37 | $10.93 | 3.0 |
| typescript-bun | sonnet46 | 8 | 11.3min | 9.4min | 2.2 | 33 | $1.22 | $9.74 | 3.4 |
| bash | sonnet46 | 8 | 10.2min | 9.6min | 4.1 | 38 | $1.06 | $8.45 | 3.4 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| default | sonnet46 | 8 | 14.6min | 13.6min | 1.1 | 32 | $1.38 | $11.06 | 4.2 |
| typescript-bun | sonnet46 | 8 | 11.3min | 9.4min | 2.2 | 33 | $1.22 | $9.74 | 3.4 |
| powershell | opus46 | 8 | 9.1min | 6.9min | 1.2 | 34 | $1.20 | $9.62 | 2.9 |
| default | opus46 | 8 | 7.0min | 6.8min | 1.2 | 36 | $1.29 | $10.31 | 3.1 |
| bash | sonnet46 | 8 | 10.2min | 9.6min | 4.1 | 38 | $1.06 | $8.45 | 3.4 |
| bash | opus46 | 8 | 8.7min | 7.9min | 1.8 | 39 | $1.37 | $10.93 | 3.0 |
| typescript-bun | opus46 | 8 | 8.9min | 7.2min | 1.5 | 39 | $1.35 | $10.78 | 3.1 |
| powershell | sonnet46 | 8 | 21.0min | 15.0min | 0.5 | 42 | $1.67 | $13.37 | 3.4 |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| default | sonnet46 | 8 | 14.6min | 13.6min | 1.1 | 32 | $1.38 | $11.06 | 4.2 |
| bash | sonnet46 | 8 | 10.2min | 9.6min | 4.1 | 38 | $1.06 | $8.45 | 3.4 |
| powershell | sonnet46 | 8 | 21.0min | 15.0min | 0.5 | 42 | $1.67 | $13.37 | 3.4 |
| typescript-bun | sonnet46 | 8 | 11.3min | 9.4min | 2.2 | 33 | $1.22 | $9.74 | 3.4 |
| default | opus46 | 8 | 7.0min | 6.8min | 1.2 | 36 | $1.29 | $10.31 | 3.1 |
| typescript-bun | opus46 | 8 | 8.9min | 7.2min | 1.5 | 39 | $1.35 | $10.78 | 3.1 |
| bash | opus46 | 8 | 8.7min | 7.9min | 1.8 | 39 | $1.37 | $10.93 | 3.0 |
| powershell | opus46 | 8 | 9.1min | 6.9min | 1.2 | 34 | $1.20 | $9.62 | 2.9 |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|
| bash | opus46 | 93 | 5 | 5.4% | 1.0min | 0.1% | 0.9min | 0.1% | 0.1min | 0.0% |
| bash | sonnet46 | 98 | 14 | 14.3% | 2.8min | 0.4% | 0.8min | 0.1% | 2.0min | 0.3% |
| default | opus46 | 90 | 5 | 5.6% | 0.7min | 0.1% | 0.8min | 0.1% | -0.1min | -0.0% |
| default | sonnet46 | 81 | 4 | 4.9% | 0.5min | 0.1% | 0.2min | 0.0% | 0.3min | 0.0% |
| powershell | opus46 | 68 | 2 | 2.9% | 1.2min | 0.2% | 2.1min | 0.3% | -0.9min | -0.1% |
| powershell | sonnet46 | 82 | 1 | 1.2% | 0.6min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% |
| typescript-bun | opus46 | 94 | 50 | 53.2% | 6.7min | 0.9% | 3.2min | 0.4% | 3.5min | 0.5% |
| typescript-bun | sonnet46 | 99 | 46 | 46.5% | 6.1min | 0.8% | 6.0min | 0.8% | 0.2min | 0.0% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|
| typescript-bun | opus46 | 94 | 50 | 53.2% | 6.7min | 0.9% | 3.2min | 0.4% | 3.5min | 0.5% |
| bash | sonnet46 | 98 | 14 | 14.3% | 2.8min | 0.4% | 0.8min | 0.1% | 2.0min | 0.3% |
| default | sonnet46 | 81 | 4 | 4.9% | 0.5min | 0.1% | 0.2min | 0.0% | 0.3min | 0.0% |
| typescript-bun | sonnet46 | 99 | 46 | 46.5% | 6.1min | 0.8% | 6.0min | 0.8% | 0.2min | 0.0% |
| bash | opus46 | 93 | 5 | 5.4% | 1.0min | 0.1% | 0.9min | 0.1% | 0.1min | 0.0% |
| powershell | sonnet46 | 82 | 1 | 1.2% | 0.6min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% |
| default | opus46 | 90 | 5 | 5.6% | 0.7min | 0.1% | 0.8min | 0.1% | -0.1min | -0.0% |
| powershell | opus46 | 68 | 2 | 2.9% | 1.2min | 0.2% | 2.1min | 0.3% | -0.9min | -0.1% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|
| typescript-bun | opus46 | 94 | 50 | 53.2% | 6.7min | 0.9% | 3.2min | 0.4% | 3.5min | 0.5% |
| typescript-bun | sonnet46 | 99 | 46 | 46.5% | 6.1min | 0.8% | 6.0min | 0.8% | 0.2min | 0.0% |
| bash | sonnet46 | 98 | 14 | 14.3% | 2.8min | 0.4% | 0.8min | 0.1% | 2.0min | 0.3% |
| default | opus46 | 90 | 5 | 5.6% | 0.7min | 0.1% | 0.8min | 0.1% | -0.1min | -0.0% |
| bash | opus46 | 93 | 5 | 5.4% | 1.0min | 0.1% | 0.9min | 0.1% | 0.1min | 0.0% |
| default | sonnet46 | 81 | 4 | 4.9% | 0.5min | 0.1% | 0.2min | 0.0% | 0.3min | 0.0% |
| powershell | opus46 | 68 | 2 | 2.9% | 1.2min | 0.2% | 2.1min | 0.3% | -0.9min | -0.1% |
| powershell | sonnet46 | 82 | 1 | 1.2% | 0.6min | 0.1% | 0.7min | 0.1% | -0.1min | -0.0% |

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| pwsh-runtime-install-overhead | powershell | opus46 | 7 | 10.2min | 1.4% | $1.13 | 1.34% |
| pwsh-runtime-install-overhead | powershell | sonnet46 | 8 | 16.0min | 2.2% | $1.31 | 1.56% |
| act-push-debug-loops | default | sonnet46 | 3 | 4.7min | 0.7% | $0.50 | 0.60% |
| act-push-debug-loops | powershell | opus46 | 1 | 0.8min | 0.1% | $0.13 | 0.16% |
| act-push-debug-loops | powershell | sonnet46 | 3 | 15.7min | 2.2% | $0.93 | 1.10% |
| act-push-debug-loops | typescript-bun | sonnet46 | 2 | 2.8min | 0.4% | $0.29 | 0.35% |
| ts-type-error-fix-cycles | typescript-bun | opus46 | 8 | 10.0min | 1.4% | $1.64 | 1.94% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46 | 8 | 9.2min | 1.3% | $1.07 | 1.26% |
| fixture-rework | bash | opus46 | 4 | 5.2min | 0.7% | $0.95 | 1.13% |
| fixture-rework | bash | sonnet46 | 3 | 3.5min | 0.5% | $0.37 | 0.44% |
| fixture-rework | default | opus46 | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| fixture-rework | default | sonnet46 | 2 | 1.8min | 0.2% | $0.18 | 0.22% |
| fixture-rework | powershell | opus46 | 1 | 2.8min | 0.4% | $0.41 | 0.48% |
| fixture-rework | typescript-bun | opus46 | 3 | 3.0min | 0.4% | $0.62 | 0.74% |
| repeated-test-reruns | bash | sonnet46 | 2 | 1.7min | 0.2% | $0.19 | 0.23% |
| repeated-test-reruns | default | sonnet46 | 1 | 0.7min | 0.1% | $0.06 | 0.07% |
| repeated-test-reruns | powershell | opus46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | powershell | sonnet46 | 5 | 5.0min | 0.7% | $0.38 | 0.45% |
| repeated-test-reruns | typescript-bun | opus46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | typescript-bun | sonnet46 | 2 | 2.7min | 0.4% | $0.31 | 0.36% |
| docker-pwsh-install | powershell | opus46 | 1 | 3.0min | 0.4% | $0.42 | 0.50% |
| docker-pwsh-install | powershell | sonnet46 | 2 | 4.5min | 0.6% | $0.40 | 0.47% |
| pwsh-invoked-from-bash | powershell | sonnet46 | 1 | 5.6min | 0.8% | $0.52 | 0.62% |
| docker-pkg-install | default | sonnet46 | 1 | 1.5min | 0.2% | $0.17 | 0.20% |
| actionlint-fix-cycles | bash | opus46 | 1 | 0.7min | 0.1% | $0.09 | 0.11% |
| actionlint-fix-cycles | powershell | sonnet46 | 1 | 0.7min | 0.1% | $0.07 | 0.08% |
| act-permission-path-errors | powershell | sonnet46 | 1 | 0.5min | 0.1% | $0.04 | 0.05% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-permission-path-errors | powershell | sonnet46 | 1 | 0.5min | 0.1% | $0.04 | 0.05% |
| repeated-test-reruns | default | sonnet46 | 1 | 0.7min | 0.1% | $0.06 | 0.07% |
| repeated-test-reruns | powershell | opus46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | typescript-bun | opus46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| actionlint-fix-cycles | bash | opus46 | 1 | 0.7min | 0.1% | $0.09 | 0.11% |
| actionlint-fix-cycles | powershell | sonnet46 | 1 | 0.7min | 0.1% | $0.07 | 0.08% |
| act-push-debug-loops | powershell | opus46 | 1 | 0.8min | 0.1% | $0.13 | 0.16% |
| fixture-rework | default | opus46 | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| docker-pkg-install | default | sonnet46 | 1 | 1.5min | 0.2% | $0.17 | 0.20% |
| repeated-test-reruns | bash | sonnet46 | 2 | 1.7min | 0.2% | $0.19 | 0.23% |
| fixture-rework | default | sonnet46 | 2 | 1.8min | 0.2% | $0.18 | 0.22% |
| repeated-test-reruns | typescript-bun | sonnet46 | 2 | 2.7min | 0.4% | $0.31 | 0.36% |
| fixture-rework | powershell | opus46 | 1 | 2.8min | 0.4% | $0.41 | 0.48% |
| act-push-debug-loops | typescript-bun | sonnet46 | 2 | 2.8min | 0.4% | $0.29 | 0.35% |
| fixture-rework | typescript-bun | opus46 | 3 | 3.0min | 0.4% | $0.62 | 0.74% |
| docker-pwsh-install | powershell | opus46 | 1 | 3.0min | 0.4% | $0.42 | 0.50% |
| fixture-rework | bash | sonnet46 | 3 | 3.5min | 0.5% | $0.37 | 0.44% |
| docker-pwsh-install | powershell | sonnet46 | 2 | 4.5min | 0.6% | $0.40 | 0.47% |
| act-push-debug-loops | default | sonnet46 | 3 | 4.7min | 0.7% | $0.50 | 0.60% |
| repeated-test-reruns | powershell | sonnet46 | 5 | 5.0min | 0.7% | $0.38 | 0.45% |
| fixture-rework | bash | opus46 | 4 | 5.2min | 0.7% | $0.95 | 1.13% |
| pwsh-invoked-from-bash | powershell | sonnet46 | 1 | 5.6min | 0.8% | $0.52 | 0.62% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46 | 8 | 9.2min | 1.3% | $1.07 | 1.26% |
| ts-type-error-fix-cycles | typescript-bun | opus46 | 8 | 10.0min | 1.4% | $1.64 | 1.94% |
| pwsh-runtime-install-overhead | powershell | opus46 | 7 | 10.2min | 1.4% | $1.13 | 1.34% |
| act-push-debug-loops | powershell | sonnet46 | 3 | 15.7min | 2.2% | $0.93 | 1.10% |
| pwsh-runtime-install-overhead | powershell | sonnet46 | 8 | 16.0min | 2.2% | $1.31 | 1.56% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-permission-path-errors | powershell | sonnet46 | 1 | 0.5min | 0.1% | $0.04 | 0.05% |
| repeated-test-reruns | default | sonnet46 | 1 | 0.7min | 0.1% | $0.06 | 0.07% |
| actionlint-fix-cycles | powershell | sonnet46 | 1 | 0.7min | 0.1% | $0.07 | 0.08% |
| actionlint-fix-cycles | bash | opus46 | 1 | 0.7min | 0.1% | $0.09 | 0.11% |
| repeated-test-reruns | typescript-bun | opus46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | powershell | opus46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| act-push-debug-loops | powershell | opus46 | 1 | 0.8min | 0.1% | $0.13 | 0.16% |
| docker-pkg-install | default | sonnet46 | 1 | 1.5min | 0.2% | $0.17 | 0.20% |
| fixture-rework | default | sonnet46 | 2 | 1.8min | 0.2% | $0.18 | 0.22% |
| repeated-test-reruns | bash | sonnet46 | 2 | 1.7min | 0.2% | $0.19 | 0.23% |
| act-push-debug-loops | typescript-bun | sonnet46 | 2 | 2.8min | 0.4% | $0.29 | 0.35% |
| fixture-rework | default | opus46 | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| repeated-test-reruns | typescript-bun | sonnet46 | 2 | 2.7min | 0.4% | $0.31 | 0.36% |
| fixture-rework | bash | sonnet46 | 3 | 3.5min | 0.5% | $0.37 | 0.44% |
| repeated-test-reruns | powershell | sonnet46 | 5 | 5.0min | 0.7% | $0.38 | 0.45% |
| docker-pwsh-install | powershell | sonnet46 | 2 | 4.5min | 0.6% | $0.40 | 0.47% |
| fixture-rework | powershell | opus46 | 1 | 2.8min | 0.4% | $0.41 | 0.48% |
| docker-pwsh-install | powershell | opus46 | 1 | 3.0min | 0.4% | $0.42 | 0.50% |
| act-push-debug-loops | default | sonnet46 | 3 | 4.7min | 0.7% | $0.50 | 0.60% |
| pwsh-invoked-from-bash | powershell | sonnet46 | 1 | 5.6min | 0.8% | $0.52 | 0.62% |
| fixture-rework | typescript-bun | opus46 | 3 | 3.0min | 0.4% | $0.62 | 0.74% |
| act-push-debug-loops | powershell | sonnet46 | 3 | 15.7min | 2.2% | $0.93 | 1.10% |
| fixture-rework | bash | opus46 | 4 | 5.2min | 0.7% | $0.95 | 1.13% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46 | 8 | 9.2min | 1.3% | $1.07 | 1.26% |
| pwsh-runtime-install-overhead | powershell | opus46 | 7 | 10.2min | 1.4% | $1.13 | 1.34% |
| pwsh-runtime-install-overhead | powershell | sonnet46 | 8 | 16.0min | 2.2% | $1.31 | 1.56% |
| ts-type-error-fix-cycles | typescript-bun | opus46 | 8 | 10.0min | 1.4% | $1.64 | 1.94% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | powershell | opus46 | 1 | 0.8min | 0.1% | $0.13 | 0.16% |
| fixture-rework | powershell | opus46 | 1 | 2.8min | 0.4% | $0.41 | 0.48% |
| repeated-test-reruns | default | sonnet46 | 1 | 0.7min | 0.1% | $0.06 | 0.07% |
| repeated-test-reruns | powershell | opus46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| repeated-test-reruns | typescript-bun | opus46 | 1 | 0.7min | 0.1% | $0.11 | 0.13% |
| docker-pwsh-install | powershell | opus46 | 1 | 3.0min | 0.4% | $0.42 | 0.50% |
| pwsh-invoked-from-bash | powershell | sonnet46 | 1 | 5.6min | 0.8% | $0.52 | 0.62% |
| docker-pkg-install | default | sonnet46 | 1 | 1.5min | 0.2% | $0.17 | 0.20% |
| actionlint-fix-cycles | bash | opus46 | 1 | 0.7min | 0.1% | $0.09 | 0.11% |
| actionlint-fix-cycles | powershell | sonnet46 | 1 | 0.7min | 0.1% | $0.07 | 0.08% |
| act-permission-path-errors | powershell | sonnet46 | 1 | 0.5min | 0.1% | $0.04 | 0.05% |
| act-push-debug-loops | typescript-bun | sonnet46 | 2 | 2.8min | 0.4% | $0.29 | 0.35% |
| fixture-rework | default | opus46 | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| fixture-rework | default | sonnet46 | 2 | 1.8min | 0.2% | $0.18 | 0.22% |
| repeated-test-reruns | bash | sonnet46 | 2 | 1.7min | 0.2% | $0.19 | 0.23% |
| repeated-test-reruns | typescript-bun | sonnet46 | 2 | 2.7min | 0.4% | $0.31 | 0.36% |
| docker-pwsh-install | powershell | sonnet46 | 2 | 4.5min | 0.6% | $0.40 | 0.47% |
| act-push-debug-loops | default | sonnet46 | 3 | 4.7min | 0.7% | $0.50 | 0.60% |
| act-push-debug-loops | powershell | sonnet46 | 3 | 15.7min | 2.2% | $0.93 | 1.10% |
| fixture-rework | bash | sonnet46 | 3 | 3.5min | 0.5% | $0.37 | 0.44% |
| fixture-rework | typescript-bun | opus46 | 3 | 3.0min | 0.4% | $0.62 | 0.74% |
| fixture-rework | bash | opus46 | 4 | 5.2min | 0.7% | $0.95 | 1.13% |
| repeated-test-reruns | powershell | sonnet46 | 5 | 5.0min | 0.7% | $0.38 | 0.45% |
| pwsh-runtime-install-overhead | powershell | opus46 | 7 | 10.2min | 1.4% | $1.13 | 1.34% |
| pwsh-runtime-install-overhead | powershell | sonnet46 | 8 | 16.0min | 2.2% | $1.31 | 1.56% |
| ts-type-error-fix-cycles | typescript-bun | opus46 | 8 | 10.0min | 1.4% | $1.64 | 1.94% |
| ts-type-error-fix-cycles | typescript-bun | sonnet46 | 8 | 9.2min | 1.3% | $1.07 | 1.26% |

</details>

#### Trap Descriptions

- **act-permission-path-errors**: Files not found or permission denied inside the act Docker container.
- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **actionlint-fix-cycles**: Workflow YAML required 3+ actionlint runs and 2+ fixes to pass.
- **docker-pkg-install**: Multiple Docker test runs exploring non-PowerShell package installation for act.
- **docker-pwsh-install**: Multiple Docker test runs trying to figure out how to install PowerShell in act's container.
- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
- **pwsh-invoked-from-bash**: Agent used `pwsh -Command`/`-File` from bash `run:` steps instead of `shell: pwsh`, causing cross-shell debugging (parse errors, quoting issues, scope problems, late pwsh discovery in act).
- **pwsh-runtime-install-overhead**: Time spent installing PowerShell and Pester inside act containers. Both are pre-installed on real GitHub runners but must be downloaded (~56MB) and installed in each act job. Measured from act step durations.
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
| bash | opus46 | 8 | 5 | 5.9min | 0.8% | $1.05 | 1.24% |
| bash | sonnet46 | 8 | 5 | 5.2min | 0.7% | $0.56 | 0.67% |
| default | opus46 | 8 | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| default | sonnet46 | 8 | 7 | 8.7min | 1.2% | $0.92 | 1.09% |
| powershell | opus46 | 8 | 11 | 17.5min | 2.4% | $2.20 | 2.61% |
| powershell | sonnet46 | 8 | 21 | 48.0min | 6.6% | $3.66 | 4.34% |
| typescript-bun | opus46 | 8 | 12 | 13.7min | 1.9% | $2.37 | 2.81% |
| typescript-bun | sonnet46 | 8 | 12 | 14.7min | 2.0% | $1.67 | 1.98% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus46 | 8 | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| bash | sonnet46 | 8 | 5 | 5.2min | 0.7% | $0.56 | 0.67% |
| bash | opus46 | 8 | 5 | 5.9min | 0.8% | $1.05 | 1.24% |
| default | sonnet46 | 8 | 7 | 8.7min | 1.2% | $0.92 | 1.09% |
| typescript-bun | opus46 | 8 | 12 | 13.7min | 1.9% | $2.37 | 2.81% |
| typescript-bun | sonnet46 | 8 | 12 | 14.7min | 2.0% | $1.67 | 1.98% |
| powershell | opus46 | 8 | 11 | 17.5min | 2.4% | $2.20 | 2.61% |
| powershell | sonnet46 | 8 | 21 | 48.0min | 6.6% | $3.66 | 4.34% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus46 | 8 | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| bash | sonnet46 | 8 | 5 | 5.2min | 0.7% | $0.56 | 0.67% |
| default | sonnet46 | 8 | 7 | 8.7min | 1.2% | $0.92 | 1.09% |
| bash | opus46 | 8 | 5 | 5.9min | 0.8% | $1.05 | 1.24% |
| typescript-bun | sonnet46 | 8 | 12 | 14.7min | 2.0% | $1.67 | 1.98% |
| powershell | opus46 | 8 | 11 | 17.5min | 2.4% | $2.20 | 2.61% |
| typescript-bun | opus46 | 8 | 12 | 13.7min | 1.9% | $2.37 | 2.81% |
| powershell | sonnet46 | 8 | 21 | 48.0min | 6.6% | $3.66 | 4.34% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 1 | $0.06 | 0.07% |
| Partial | 62 | $3.24 | 3.84% |
| Miss | 1 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | opus46 | 18.5 | 28.2 | 1.5 | 1.45 |
| bash | sonnet46 | 16.8 | 33.9 | 2.0 | 0.67 |
| default | opus46 | 9.0 | 24.6 | 2.7 | 1.64 |
| default | sonnet46 | 33.1 | 49.8 | 1.5 | 1.10 |
| powershell | opus46 | 32.6 | 48.0 | 1.5 | 0.96 |
| powershell | sonnet46 | 40.0 | 57.9 | 1.4 | 1.34 |
| typescript-bun | opus46 | 10.1 | 40.2 | 4.0 | 1.02 |
| typescript-bun | sonnet46 | 34.6 | 60.1 | 1.7 | 1.55 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell | sonnet46 | 40.0 | 57.9 | 1.4 | 1.34 |
| typescript-bun | sonnet46 | 34.6 | 60.1 | 1.7 | 1.55 |
| default | sonnet46 | 33.1 | 49.8 | 1.5 | 1.10 |
| powershell | opus46 | 32.6 | 48.0 | 1.5 | 0.96 |
| bash | opus46 | 18.5 | 28.2 | 1.5 | 1.45 |
| bash | sonnet46 | 16.8 | 33.9 | 2.0 | 0.67 |
| typescript-bun | opus46 | 10.1 | 40.2 | 4.0 | 1.02 |
| default | opus46 | 9.0 | 24.6 | 2.7 | 1.64 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | sonnet46 | 34.6 | 60.1 | 1.7 | 1.55 |
| powershell | sonnet46 | 40.0 | 57.9 | 1.4 | 1.34 |
| default | sonnet46 | 33.1 | 49.8 | 1.5 | 1.10 |
| powershell | opus46 | 32.6 | 48.0 | 1.5 | 0.96 |
| typescript-bun | opus46 | 10.1 | 40.2 | 4.0 | 1.02 |
| bash | sonnet46 | 16.8 | 33.9 | 2.0 | 0.67 |
| bash | opus46 | 18.5 | 28.2 | 1.5 | 1.45 |
| default | opus46 | 9.0 | 24.6 | 2.7 | 1.64 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| default | opus46 | 9.0 | 24.6 | 2.7 | 1.64 |
| typescript-bun | sonnet46 | 34.6 | 60.1 | 1.7 | 1.55 |
| bash | opus46 | 18.5 | 28.2 | 1.5 | 1.45 |
| powershell | sonnet46 | 40.0 | 57.9 | 1.4 | 1.34 |
| default | sonnet46 | 33.1 | 49.8 | 1.5 | 1.10 |
| typescript-bun | opus46 | 10.1 | 40.2 | 4.0 | 1.02 |
| powershell | opus46 | 32.6 | 48.0 | 1.5 | 0.96 |
| bash | sonnet46 | 16.8 | 33.9 | 2.0 | 0.67 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Language | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | bash | opus46 | 30 | 19 | 0.6 | 268 | 268 | 1.00 |
| Semantic Version Bumper | bash | sonnet46 | 17 | 41 | 2.4 | 275 | 521 | 0.53 |
| Semantic Version Bumper | default | opus46 | 9 | 0 | 0.0 | 421 | 284 | 1.48 |
| Semantic Version Bumper | default | sonnet46 | 52 | 57 | 1.1 | 599 | 291 | 2.06 |
| Semantic Version Bumper | powershell | opus46 | 34 | 44 | 1.3 | 340 | 361 | 0.94 |
| Semantic Version Bumper | powershell | sonnet46 | 36 | 45 | 1.2 | 273 | 279 | 0.98 |
| Semantic Version Bumper | typescript-bun | opus46 | 8 | 28 | 3.5 | 310 | 282 | 1.10 |
| Semantic Version Bumper | typescript-bun | sonnet46 | 28 | 39 | 1.4 | 253 | 434 | 0.58 |
| PR Label Assigner | bash | opus46 | 11 | 17 | 1.5 | 272 | 208 | 1.31 |
| PR Label Assigner | bash | sonnet46 | 15 | 34 | 2.3 | 258 | 500 | 0.52 |
| PR Label Assigner | default | opus46 | 10 | 0 | 0.0 | 333 | 180 | 1.85 |
| PR Label Assigner | default | sonnet46 | 17 | 25 | 1.5 | 274 | 328 | 0.84 |
| PR Label Assigner | powershell | opus46 | 17 | 41 | 2.4 | 182 | 332 | 0.55 |
| PR Label Assigner | powershell | sonnet46 | 45 | 64 | 1.4 | 484 | 210 | 2.30 |
| PR Label Assigner | typescript-bun | opus46 | 6 | 20 | 3.3 | 404 | 252 | 1.60 |
| PR Label Assigner | typescript-bun | sonnet46 | 20 | 31 | 1.6 | 208 | 483 | 0.43 |
| Dependency License Checker | bash | opus46 | 18 | 46 | 2.6 | 159 | 498 | 0.32 |
| Dependency License Checker | bash | sonnet46 | 17 | 28 | 1.6 | 167 | 257 | 0.65 |
| Dependency License Checker | default | opus46 | 25 | 32 | 1.3 | 277 | 212 | 1.31 |
| Dependency License Checker | default | sonnet46 | 26 | 55 | 2.1 | 364 | 750 | 0.49 |
| Dependency License Checker | powershell | opus46 | 37 | 43 | 1.2 | 257 | 754 | 0.34 |
| Dependency License Checker | powershell | sonnet46 | 38 | 84 | 2.2 | 448 | 281 | 1.59 |
| Dependency License Checker | typescript-bun | opus46 | 19 | 37 | 1.9 | 203 | 588 | 0.35 |
| Dependency License Checker | typescript-bun | sonnet46 | 39 | 72 | 1.8 | 537 | 393 | 1.37 |
| Docker Image Tag Generator | bash | opus46 | 17 | 31 | 1.8 | 299 | 87 | 3.44 |
| Docker Image Tag Generator | bash | sonnet46 | 17 | 12 | 0.7 | 250 | 150 | 1.67 |
| Docker Image Tag Generator | default | opus46 | 6 | 2 | 0.3 | 414 | 149 | 2.78 |
| Docker Image Tag Generator | default | sonnet46 | 35 | 36 | 1.0 | 265 | 555 | 0.48 |
| Docker Image Tag Generator | powershell | opus46 | 21 | 24 | 1.1 | 136 | 441 | 0.31 |
| Docker Image Tag Generator | powershell | sonnet46 | 39 | 58 | 1.5 | 295 | 474 | 0.62 |
| Docker Image Tag Generator | typescript-bun | opus46 | 8 | 18 | 2.2 | 322 | 164 | 1.96 |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 46 | 59 | 1.3 | 653 | 170 | 3.84 |
| Test Results Aggregator | bash | opus46 | 24 | 9 | 0.4 | 257 | 295 | 0.87 |
| Test Results Aggregator | bash | sonnet46 | 23 | 36 | 1.6 | 137 | 335 | 0.41 |
| Test Results Aggregator | default | opus46 | 6 | 49 | 8.2 | 462 | 371 | 1.25 |
| Test Results Aggregator | default | sonnet46 | 29 | 77 | 2.7 | 393 | 950 | 0.41 |
| Test Results Aggregator | powershell | opus46 | 41 | 43 | 1.0 | 335 | 205 | 1.63 |
| Test Results Aggregator | powershell | sonnet46 | 69 | 83 | 1.2 | 588 | 442 | 1.33 |
| Test Results Aggregator | typescript-bun | opus46 | 8 | 59 | 7.4 | 302 | 679 | 0.44 |
| Test Results Aggregator | typescript-bun | sonnet46 | 45 | 94 | 2.1 | 685 | 585 | 1.17 |
| Environment Matrix Generator | bash | opus46 | 17 | 24 | 1.4 | 327 | 166 | 1.97 |
| Environment Matrix Generator | bash | sonnet46 | 18 | 29 | 1.6 | 291 | 323 | 0.90 |
| Environment Matrix Generator | default | opus46 | 0 | 0 | 0.0 | 0 | 235 | 0.00 |
| Environment Matrix Generator | default | sonnet46 | 38 | 46 | 1.2 | 352 | 165 | 2.13 |
| Environment Matrix Generator | powershell | opus46 | 43 | 62 | 1.4 | 324 | 286 | 1.13 |
| Environment Matrix Generator | powershell | sonnet46 | 36 | 37 | 1.0 | 403 | 170 | 2.37 |
| Environment Matrix Generator | typescript-bun | opus46 | 12 | 50 | 4.2 | 340 | 284 | 1.20 |
| Environment Matrix Generator | typescript-bun | sonnet46 | 35 | 62 | 1.8 | 611 | 231 | 2.65 |
| Artifact Cleanup Script | bash | opus46 | 15 | 29 | 1.9 | 540 | 296 | 1.82 |
| Artifact Cleanup Script | bash | sonnet46 | 12 | 48 | 4.0 | 247 | 556 | 0.44 |
| Artifact Cleanup Script | default | opus46 | 8 | 55 | 6.9 | 396 | 264 | 1.50 |
| Artifact Cleanup Script | default | sonnet46 | 23 | 50 | 2.2 | 705 | 372 | 1.90 |
| Artifact Cleanup Script | powershell | opus46 | 19 | 53 | 2.8 | 242 | 306 | 0.79 |
| Artifact Cleanup Script | powershell | sonnet46 | 22 | 41 | 1.9 | 226 | 224 | 1.01 |
| Artifact Cleanup Script | typescript-bun | opus46 | 13 | 33 | 2.5 | 201 | 531 | 0.38 |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 18 | 35 | 1.9 | 276 | 280 | 0.99 |
| Secret Rotation Validator | bash | opus46 | 16 | 51 | 3.2 | 212 | 250 | 0.85 |
| Secret Rotation Validator | bash | sonnet46 | 15 | 43 | 2.9 | 215 | 871 | 0.25 |
| Secret Rotation Validator | default | opus46 | 8 | 59 | 7.4 | 663 | 225 | 2.95 |
| Secret Rotation Validator | default | sonnet46 | 45 | 52 | 1.2 | 359 | 735 | 0.49 |
| Secret Rotation Validator | powershell | opus46 | 49 | 74 | 1.5 | 396 | 197 | 2.01 |
| Secret Rotation Validator | powershell | sonnet46 | 35 | 51 | 1.5 | 382 | 717 | 0.53 |
| Secret Rotation Validator | typescript-bun | opus46 | 7 | 77 | 11.0 | 299 | 271 | 1.10 |
| Secret Rotation Validator | typescript-bun | sonnet46 | 46 | 89 | 1.9 | 559 | 399 | 1.40 |

</details>

### LLM-as-Judge Scores

An LLM evaluates each test suite on four dimensions (1-5 scale):

- **Coverage** (1-5): Do tests exercise the key requirements? 1 = most untested, 5 = all covered.
- **Rigor** (1-5): Edge cases, error handling, boundary conditions? 1 = happy path only, 5 = thorough.
- **Design** (1-5): Test organization, fixtures, readability? 1 = messy/brittle, 5 = well-structured.
- **Overall** (1-5): Holistic quality — would you trust this suite to catch regressions? 1 = no, 5 = absolutely. Use this as the primary ranking metric.

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| bash | opus46 | **3.0** | 3.9 | 3.0 | 2.9 | $0.3609 |
| bash | sonnet46 | **3.4** | 3.9 | 2.9 | 3.6 | $0.3842 |
| default | opus46 | **3.1** | 3.8 | 2.6 | 3.2 | $0.3557 |
| default | sonnet46 | **4.2** | 4.6 | 4.1 | 4.6 | $0.3986 |
| powershell | opus46 | **2.9** | 3.5 | 2.6 | 3.4 | $0.4482 |
| powershell | sonnet46 | **3.4** | 4.4 | 3.0 | 3.2 | $0.5469 |
| typescript-bun | opus46 | **3.1** | 3.6 | 2.8 | 3.5 | $0.4148 |
| typescript-bun | sonnet46 | **3.4** | 3.8 | 3.1 | 3.8 | $0.4911 |
| **Total** | | | | | | **$3.4004** |


<details>
<summary>Sorted by avg overall (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| default | sonnet46 | **4.2** | 4.6 | 4.1 | 4.6 | $0.3986 |
| bash | sonnet46 | **3.4** | 3.9 | 2.9 | 3.6 | $0.3842 |
| powershell | sonnet46 | **3.4** | 4.4 | 3.0 | 3.2 | $0.5469 |
| typescript-bun | sonnet46 | **3.4** | 3.8 | 3.1 | 3.8 | $0.4911 |
| default | opus46 | **3.1** | 3.8 | 2.6 | 3.2 | $0.3557 |
| typescript-bun | opus46 | **3.1** | 3.6 | 2.8 | 3.5 | $0.4148 |
| bash | opus46 | **3.0** | 3.9 | 3.0 | 2.9 | $0.3609 |
| powershell | opus46 | **2.9** | 3.5 | 2.6 | 3.4 | $0.4482 |

</details>

<details>
<summary>Sorted by avg coverage (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| default | sonnet46 | **4.2** | 4.6 | 4.1 | 4.6 | $0.3986 |
| powershell | sonnet46 | **3.4** | 4.4 | 3.0 | 3.2 | $0.5469 |
| bash | opus46 | **3.0** | 3.9 | 3.0 | 2.9 | $0.3609 |
| bash | sonnet46 | **3.4** | 3.9 | 2.9 | 3.6 | $0.3842 |
| default | opus46 | **3.1** | 3.8 | 2.6 | 3.2 | $0.3557 |
| typescript-bun | sonnet46 | **3.4** | 3.8 | 3.1 | 3.8 | $0.4911 |
| typescript-bun | opus46 | **3.1** | 3.6 | 2.8 | 3.5 | $0.4148 |
| powershell | opus46 | **2.9** | 3.5 | 2.6 | 3.4 | $0.4482 |

</details>

<details>
<summary>Sorted by avg rigor (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| default | sonnet46 | **4.2** | 4.6 | 4.1 | 4.6 | $0.3986 |
| typescript-bun | sonnet46 | **3.4** | 3.8 | 3.1 | 3.8 | $0.4911 |
| bash | opus46 | **3.0** | 3.9 | 3.0 | 2.9 | $0.3609 |
| powershell | sonnet46 | **3.4** | 4.4 | 3.0 | 3.2 | $0.5469 |
| bash | sonnet46 | **3.4** | 3.9 | 2.9 | 3.6 | $0.3842 |
| typescript-bun | opus46 | **3.1** | 3.6 | 2.8 | 3.5 | $0.4148 |
| default | opus46 | **3.1** | 3.8 | 2.6 | 3.2 | $0.3557 |
| powershell | opus46 | **2.9** | 3.5 | 2.6 | 3.4 | $0.4482 |

</details>

<details>
<summary>Sorted by avg design (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| default | sonnet46 | **4.2** | 4.6 | 4.1 | 4.6 | $0.3986 |
| typescript-bun | sonnet46 | **3.4** | 3.8 | 3.1 | 3.8 | $0.4911 |
| bash | sonnet46 | **3.4** | 3.9 | 2.9 | 3.6 | $0.3842 |
| typescript-bun | opus46 | **3.1** | 3.6 | 2.8 | 3.5 | $0.4148 |
| powershell | opus46 | **2.9** | 3.5 | 2.6 | 3.4 | $0.4482 |
| default | opus46 | **3.1** | 3.8 | 2.6 | 3.2 | $0.3557 |
| powershell | sonnet46 | **3.4** | 4.4 | 3.0 | 3.2 | $0.5469 |
| bash | opus46 | **3.0** | 3.9 | 3.0 | 2.9 | $0.3609 |

</details>


<details>
<summary>Per-run LLM judge scores</summary>

| Task | Language | Model | Cov | Rig | Des | Ovr | Summary |
|------|------|-------|-----|-----|-----|-----|---------|
| Semantic Version Bumper | bash | opus46 | 4 | 3 | 3 | 3 | The suite covers all five core requirements (VERSION file, p |
| Semantic Version Bumper | bash | sonnet46 | 5 | 4 | 4 | 4 | The test suite covers all key requirements thoroughly: versi |
| Semantic Version Bumper | default | opus46 | 2 | 2 | 2 | 2 | The test harness is infrastructure-heavy but functionally sh |
| Semantic Version Bumper | default | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all six core requirements well: versio |
| Semantic Version Bumper | powershell | opus46 | 3 | 2 | 3 | 2 | The suite covers the five primary bump scenarios (patch, min |
| Semantic Version Bumper | powershell | sonnet46 | 4 | 3 | 3 | 3 | The suite covers the primary requirements well: Get-BumpType |
| Semantic Version Bumper | typescript-bun | opus46 | 3 | 2 | 4 | 3 | The test suite is well-organized and correctly routes all te |
| Semantic Version Bumper | typescript-bun | sonnet46 | 3 | 3 | 4 | 3 | The suite thoroughly covers the core algorithmic modules (pa |
| PR Label Assigner | bash | opus46 | 3 | 2 | 2 | 2 | The suite covers the happy-path label-assignment scenarios ( |
| PR Label Assigner | bash | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers the core requirements well: glob patte |
| PR Label Assigner | default | opus46 | 4 | 2 | 3 | 3 | The test suite defines 10 functional end-to-end cases that c |
| PR Label Assigner | default | sonnet46 | 5 | 4 | 4 | 4 | The test suite demonstrates strong coverage of the stated re |
| PR Label Assigner | powershell | opus46 | 4 | 3 | 4 | 3 | The test suite covers all major requirements: glob-to-regex  |
| PR Label Assigner | powershell | sonnet46 | 5 | 4 | 4 | 4 | The test suite is comprehensive and well-structured. Coverag |
| PR Label Assigner | typescript-bun | opus46 | 3 | 2 | 3 | 3 | The test suite covers the six main business-logic scenarios  |
| PR Label Assigner | typescript-bun | sonnet46 | 5 | 4 | 4 | 4 | The test suite demonstrates strong coverage of the stated re |
| Dependency License Checker | bash | opus46 | 4 | 4 | 4 | 4 | The bats test suite is solid and covers the primary requirem |
| Dependency License Checker | bash | sonnet46 | 3 | 2 | 3 | 2 | The suite hits the main happy paths — both manifest formats, |
| Dependency License Checker | default | opus46 | 5 | 4 | 5 | 5 | The test suite is comprehensive and well-organized, covering |
| Dependency License Checker | default | sonnet46 | 4 | 4 | 4 | 4 | The test suite demonstrates solid TDD structure across 8 cle |
| Dependency License Checker | powershell | opus46 | 4 | 3 | 4 | 3 | The suite covers all five core functions and three manifest  |
| Dependency License Checker | powershell | sonnet46 | 4 | 2 | 3 | 3 | The unit test layer (LicenseChecker.Tests.ps1) is comprehens |
| Dependency License Checker | typescript-bun | opus46 | 5 | 4 | 5 | 4 | The unit test suite covers all core requirements well: manif |
| Dependency License Checker | typescript-bun | sonnet46 | 3 | 3 | 3 | 3 | The suite covers the core happy paths well — parsing, licens |
| Docker Image Tag Generator | bash | opus46 | 4 | 3 | 3 | 3 | The test suite covers the core happy-path requirements well: |
| Docker Image Tag Generator | bash | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all primary requirements (main→latest, |
| Docker Image Tag Generator | default | opus46 | 3 | 2 | 3 | 3 | The suite covers the four main tag-generation conventions (m |
| Docker Image Tag Generator | default | sonnet46 | 5 | 4 | 5 | 4 | The test suite demonstrates strong coverage of all stated re |
| Docker Image Tag Generator | powershell | opus46 | 4 | 3 | 3 | 3 | The Pester test suite covers the main requirements well: san |
| Docker Image Tag Generator | powershell | sonnet46 | 5 | 4 | 3 | 4 | The test suite comprehensively maps to every key requirement |
| Docker Image Tag Generator | typescript-bun | opus46 | 4 | 3 | 3 | 3 | The suite covers all core requirements well: main/master→lat |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 5 | 4 | 4 | 4 | The test suite is comprehensive and well-structured, coverin |
| Test Results Aggregator | bash | opus46 | 4 | 3 | 2 | 3 | The test suite covers most task requirements well: XML parsi |
| Test Results Aggregator | bash | sonnet46 | 3 | 2 | 3 | 3 | The test suite covers the main happy-path requirements reaso |
| Test Results Aggregator | default | opus46 | 4 | 3 | 4 | 3 | The test suite covers the main requirements well: JUnit XML  |
| Test Results Aggregator | default | sonnet46 | 5 | 4 | 5 | 4 | The test suite is well-structured and covers all five major  |
| Test Results Aggregator | powershell | opus46 | 3 | 3 | 4 | 3 | The test suite covers the main happy paths well — full aggre |
| Test Results Aggregator | powershell | sonnet46 | 5 | 3 | 4 | 4 | The test suite comprehensively covers all task requirements: |
| Test Results Aggregator | typescript-bun | opus46 | 4 | 2 | 3 | 3 | The suite covers all major happy-path requirements: JUnit XM |
| Test Results Aggregator | typescript-bun | sonnet46 | 3 | 3 | 4 | 3 | The test suite provides solid unit coverage for the four cor |
| Environment Matrix Generator | bash | opus46 | 4 | 3 | 3 | 3 | The test suite covers the main requirements well: basic Cart |
| Environment Matrix Generator | bash | sonnet46 | 4 | 3 | 3 | 3 | The bats suite covers all major task requirements well: basi |
| Environment Matrix Generator | default | opus46 | 3 | 2 | 2 | 2 | The test harness has reasonable structural ambition — it cov |
| Environment Matrix Generator | default | sonnet46 | 5 | 5 | 5 | 5 | This is an exemplary test suite. Coverage is comprehensive:  |
| Environment Matrix Generator | powershell | opus46 | 3 | 2 | 2 | 2 | The suite addresses the main task requirements (basic matrix |
| Environment Matrix Generator | powershell | sonnet46 | 4 | 2 | 3 | 3 | The suite covers all eight primary requirements (OS, languag |
| Environment Matrix Generator | typescript-bun | opus46 | 4 | 3 | 3 | 3 | The suite covers all major requirements (basic cartesian pro |
| Environment Matrix Generator | typescript-bun | sonnet46 | 4 | 3 | 4 | 4 | The unit test suite in matrix-generator.test.ts covers all m |
| Artifact Cleanup Script | bash | opus46 | 4 | 3 | 3 | 3 | The test suite covers the main functional requirements well: |
| Artifact Cleanup Script | bash | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all five key requirement areas — max-a |
| Artifact Cleanup Script | default | opus46 | 5 | 4 | 4 | 4 | The test suite covers all six major functional requirements  |
| Artifact Cleanup Script | default | sonnet46 | 4 | 4 | 5 | 4 | The test suite is well-structured and covers all five functi |
| Artifact Cleanup Script | powershell | opus46 | 4 | 3 | 4 | 4 | The suite covers all five main requirement areas (max-age, k |
| Artifact Cleanup Script | powershell | sonnet46 | 4 | 3 | 3 | 3 | The suite covers all six functions and all three policy type |
| Artifact Cleanup Script | typescript-bun | opus46 | 4 | 4 | 5 | 4 | The test suite thoroughly covers the core retention engine ( |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 3 | 2 | 3 | 2 | The test suite covers the core business logic reasonably wel |
| Secret Rotation Validator | bash | opus46 | 4 | 3 | 3 | 3 | The suite covers all major scenarios — mixed status, all-ok, |
| Secret Rotation Validator | bash | sonnet46 | 4 | 3 | 4 | 3 | The test suite covers most key requirements well: expired/wa |
| Secret Rotation Validator | default | opus46 | 4 | 2 | 3 | 3 | The test suite covers the core functional requirements well  |
| Secret Rotation Validator | default | sonnet46 | 5 | 5 | 5 | 5 | Exceptional test suite. Coverage is comprehensive: every pub |
| Secret Rotation Validator | powershell | opus46 | 3 | 2 | 3 | 3 | The suite covers the main happy-path scenarios well — mixed, |
| Secret Rotation Validator | powershell | sonnet46 | 4 | 3 | 3 | 3 | The test suite covers the core requirements well: secret cla |
| Secret Rotation Validator | typescript-bun | opus46 | 2 | 2 | 2 | 2 | The test suite is almost entirely composed of end-to-end act |
| Secret Rotation Validator | typescript-bun | sonnet46 | 4 | 3 | 4 | 4 | The test suite demonstrates solid coverage of the core domai |

</details>

### Correlation: Structural Metrics vs LLM Scores

Spearman rank correlation between automated counts and LLM judge scores.
Values near +1.0 indicate the LLM agrees with the structural signal; near 0 means no relationship.

| Structural Metric | vs Coverage | vs Rigor | vs Design | vs Overall |
|-------------------|------------|---------|----------|-----------|
| Test count | 0.24 | 0.31 | 0.27 | 0.32 |
| Assertion count | 0.18 | 0.18 | 0.25 | 0.27 |
| Test:code ratio | -0.09 | -0.2 | -0.16 | -0.04 |

*Based on 64 runs with both structural and LLM scores.*

### LLM vs Structural Discrepancies

**Qualitative disagreements** — structural metrics look reasonable; the LLM judge is weighing factors the counters can't measure.

| Task | Language | Model | Tests | Asserts | Cov | Rig | Des | Ovr | Flag | Justification |
|------|------|-------|-------|---------|-----|-----|-----|-----|------|---------------|
| Semantic Version Bumper | powershell | opus46 | 34 | 44 | 3 | 2 | 3 | 2 | LLM says low rigor (2/5) but 44 assertions detected | The suite covers the five primary bump scenarios (patch, minor, major-bang, major-BREAKING, no-bump) plus workflow-structure validation and actionlint, which addresses most of the stated requiremen... |
| Dependency License Checker | powershell | sonnet46 | 38 | 84 | 4 | 2 | 3 | 3 | LLM says low rigor (2/5) but 84 assertions detected | The unit test layer (LicenseChecker.Tests.ps1) is comprehensive and covers all eight public functions with both happy-path and basic file-not-found error cases. WorkflowStructure.Tests.ps1 is clean... |
| Test Results Aggregator | typescript-bun | opus46 | 8 | 59 | 4 | 2 | 3 | 3 | LLM says low rigor (2/5) but 59 assertions detected | The suite covers all major happy-path requirements: JUnit XML parsing, JSON parsing, multi-file aggregation, flaky test detection, markdown output, workflow structure validation, and actionlint. Ex... |
| Environment Matrix Generator | powershell | opus46 | 43 | 62 | 3 | 2 | 2 | 2 | LLM says low rigor (2/5) but 62 assertions detected | The suite addresses the main task requirements (basic matrix, include/exclude rules, fail-fast, max-parallel, size validation, missing-file error) and validates workflow structure. However, several... |
| Secret Rotation Validator | default | opus46 | 8 | 59 | 4 | 2 | 3 | 3 | LLM says low rigor (2/5) but 59 assertions detected | The test suite covers the core functional requirements well — all urgency categories (expired, warning, ok), both output formats (JSON and markdown), configurable warning windows, and workflow stru... |
| Secret Rotation Validator | powershell | opus46 | 49 | 74 | 3 | 2 | 3 | 3 | LLM says low rigor (2/5) but 74 assertions detected | The suite covers the main happy-path scenarios well — mixed, all-ok, all-expired, and the warning-window boundary flip — and checks both markdown and JSON output formats with exact expected values ... |
| Secret Rotation Validator | typescript-bun | opus46 | 7 | 77 | 2 | 2 | 2 | 2 | LLM says low rigor (2/5) but 77 assertions detected | The test suite is almost entirely composed of end-to-end act/Docker integration tests, leaving the core library functions (daysBetween, evaluateSecret, buildReport, formatReport, parseArgs) complet... |

## Per-Run Results

*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Artifact Cleanup Script | bash | opus46 | 8.1min | 38 | 2 | $1.51 | 3.0 | bash | ok |
| Artifact Cleanup Script | bash | sonnet46 | 15.4min | 47 | 3 | $1.59 | 4.0 | bash | ok |
| Artifact Cleanup Script | default | opus46 | 6.3min | 29 | 0 | $1.05 | 4.0 | python | ok |
| Artifact Cleanup Script | default | sonnet46 | 15.9min | 25 | 1 | $1.49 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 9.4min | 39 | 0 | $1.60 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 6.5min | 31 | 0 | $0.70 | 3.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 12.3min | 30 | 0 | $2.06 | 4.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 11.7min | 30 | 1 | $1.18 | 2.0 | typescript | ok |
| Dependency License Checker | bash | opus46 | 5.4min | 40 | 1 | $1.12 | 4.0 | bash | ok |
| Dependency License Checker | bash | sonnet46 | 5.6min | 37 | 4 | $0.75 | 2.0 | bash | ok |
| Dependency License Checker | default | opus46 | 10.6min | 65 | 4 | $2.35 | 5.0 | python | ok |
| Dependency License Checker | default | sonnet46 | 13.5min | 40 | 1 | $1.13 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 11.1min | 38 | 1 | $1.55 | 3.0 | powershell | ok |
| Dependency License Checker | powershell | sonnet46 | 28.0min | 59 | 0 | $1.85 | 3.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.2min | 51 | 1 | $1.34 | 4.0 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 7.7min | 47 | 4 | $1.10 | 3.0 | typescript | ok |
| Docker Image Tag Generator | bash | opus46 | 14.5min | 33 | 2 | $2.06 | 3.0 | bash | ok |
| Docker Image Tag Generator | bash | sonnet46 | 16.0min | 34 | 4 | $1.49 | 4.0 | bash | ok |
| Docker Image Tag Generator | default | opus46 | 7.8min | 36 | 2 | $1.34 | 3.0 | python | ok |
| Docker Image Tag Generator | default | sonnet46 | 14.6min | 13 | 1 | $1.14 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.5min | 20 | 1 | $0.61 | 3.0 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 24.4min | 51 | 1 | $2.13 | 4.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 11.1min | 40 | 1 | $1.02 | 3.0 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 10.2min | 19 | 1 | $1.03 | 4.0 | typescript | ok |
| Environment Matrix Generator | bash | opus46 | 9.6min | 36 | 1 | $0.87 | 3.0 | bash | ok |
| Environment Matrix Generator | bash | sonnet46 | 9.8min | 40 | 6 | $0.84 | 3.0 | bash | ok |
| Environment Matrix Generator | default | opus46 | 4.6min | 36 | 1 | $0.98 | 2.0 | bash | ok |
| Environment Matrix Generator | default | sonnet46 | 12.0min | 23 | 0 | $1.13 | 5.0 | python | ok |
| Environment Matrix Generator | powershell | opus46 | 6.7min | 44 | 5 | $0.99 | 2.0 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46 | 22.1min | 42 | 0 | $1.93 | 3.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 7.0min | 41 | 4 | $1.15 | 3.0 | typescript | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 13.5min | 24 | 0 | $1.19 | 4.0 | typescript | ok |
| PR Label Assigner | bash | opus46 | 6.5min | 42 | 2 | $1.22 | 2.0 | bash | ok |
| PR Label Assigner | bash | sonnet46 | 6.8min | 39 | 5 | $0.90 | 4.0 | bash | ok |
| PR Label Assigner | default | opus46 | 4.6min | 23 | 0 | $0.69 | 3.0 | python | ok |
| PR Label Assigner | default | sonnet46 | 16.5min | 23 | 1 | $1.25 | 4.0 | python | ok |
| PR Label Assigner | powershell | opus46 | 8.1min | 32 | 2 | $1.12 | 3.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 27.1min | 50 | 3 | $2.51 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus46 | 9.1min | 31 | 1 | $0.96 | 3.0 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 13.7min | 46 | 6 | $1.35 | 4.0 | typescript | ok |
| Secret Rotation Validator | bash | opus46 | 11.5min | 33 | 1 | $1.34 | 3.0 | bash | ok |
| Secret Rotation Validator | bash | sonnet46 | 11.2min | 31 | 4 | $0.94 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus46 | 5.5min | 32 | 1 | $1.19 | 3.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 11.5min | 37 | 2 | $1.53 | 5.0 | python | ok |
| Secret Rotation Validator | powershell | opus46 | 10.7min | 34 | 0 | $1.35 | 3.0 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46 | 12.7min | 22 | 0 | $1.04 | 3.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 5.4min | 44 | 5 | $1.17 | 2.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 13.1min | 1 | 3 | $1.31 | 4.0 | typescript | ok |
| Semantic Version Bumper | bash | opus46 | 6.8min | 46 | 2 | $1.45 | 3.0 | bash | ok |
| Semantic Version Bumper | bash | sonnet46 | 4.9min | 30 | 2 | $0.68 | 4.0 | bash | ok |
| Semantic Version Bumper | default | opus46 | 9.0min | 29 | 0 | $1.27 | 2.0 | python | ok |
| Semantic Version Bumper | default | sonnet46 | 17.2min | 38 | 1 | $1.62 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | opus46 | 9.2min | 31 | 0 | $0.82 | 2.0 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46 | 27.2min | 42 | 0 | $1.44 | 3.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 13.2min | 35 | 0 | $1.89 | 3.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 28 | 0 | $0.72 | 3.0 | typescript | ok |
| Test Results Aggregator | bash | opus46 | 6.7min | 44 | 3 | $1.36 | 3.0 | bash | ok |
| Test Results Aggregator | bash | sonnet46 | 12.0min | 43 | 5 | $1.26 | 3.0 | bash | ok |
| Test Results Aggregator | default | opus46 | 7.6min | 40 | 2 | $1.43 | 3.0 | python | ok |
| Test Results Aggregator | default | sonnet46 | 15.9min | 58 | 2 | $1.78 | 4.0 | python | ok |
| Test Results Aggregator | powershell | opus46 | 9.8min | 31 | 1 | $1.58 | 3.0 | powershell | ok |
| Test Results Aggregator | powershell | sonnet46 | 19.9min | 43 | 0 | $1.77 | 4.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus46 | 7.1min | 40 | 0 | $1.18 | 3.0 | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 12.2min | 72 | 3 | $1.86 | 3.0 | typescript | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Docker Image Tag Generator | powershell | opus46 | 7.5min | 20 | 1 | $0.61 | 3.0 | powershell | ok |
| Semantic Version Bumper | bash | sonnet46 | 4.9min | 30 | 2 | $0.68 | 4.0 | bash | ok |
| PR Label Assigner | default | opus46 | 4.6min | 23 | 0 | $0.69 | 3.0 | python | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 6.5min | 31 | 0 | $0.70 | 3.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 28 | 0 | $0.72 | 3.0 | typescript | ok |
| Dependency License Checker | bash | sonnet46 | 5.6min | 37 | 4 | $0.75 | 2.0 | bash | ok |
| Semantic Version Bumper | powershell | opus46 | 9.2min | 31 | 0 | $0.82 | 2.0 | powershell | ok |
| Environment Matrix Generator | bash | sonnet46 | 9.8min | 40 | 6 | $0.84 | 3.0 | bash | ok |
| Environment Matrix Generator | bash | opus46 | 9.6min | 36 | 1 | $0.87 | 3.0 | bash | ok |
| PR Label Assigner | bash | sonnet46 | 6.8min | 39 | 5 | $0.90 | 4.0 | bash | ok |
| Secret Rotation Validator | bash | sonnet46 | 11.2min | 31 | 4 | $0.94 | 3.0 | bash | ok |
| PR Label Assigner | typescript-bun | opus46 | 9.1min | 31 | 1 | $0.96 | 3.0 | typescript | ok |
| Environment Matrix Generator | default | opus46 | 4.6min | 36 | 1 | $0.98 | 2.0 | bash | ok |
| Environment Matrix Generator | powershell | opus46 | 6.7min | 44 | 5 | $0.99 | 2.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 11.1min | 40 | 1 | $1.02 | 3.0 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 10.2min | 19 | 1 | $1.03 | 4.0 | typescript | ok |
| Secret Rotation Validator | powershell | sonnet46 | 12.7min | 22 | 0 | $1.04 | 3.0 | powershell | ok |
| Artifact Cleanup Script | default | opus46 | 6.3min | 29 | 0 | $1.05 | 4.0 | python | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 7.7min | 47 | 4 | $1.10 | 3.0 | typescript | ok |
| Dependency License Checker | bash | opus46 | 5.4min | 40 | 1 | $1.12 | 4.0 | bash | ok |
| PR Label Assigner | powershell | opus46 | 8.1min | 32 | 2 | $1.12 | 3.0 | powershell | ok |
| Dependency License Checker | default | sonnet46 | 13.5min | 40 | 1 | $1.13 | 4.0 | python | ok |
| Environment Matrix Generator | default | sonnet46 | 12.0min | 23 | 0 | $1.13 | 5.0 | python | ok |
| Docker Image Tag Generator | default | sonnet46 | 14.6min | 13 | 1 | $1.14 | 4.0 | python | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 7.0min | 41 | 4 | $1.15 | 3.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 5.4min | 44 | 5 | $1.17 | 2.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 11.7min | 30 | 1 | $1.18 | 2.0 | typescript | ok |
| Test Results Aggregator | typescript-bun | opus46 | 7.1min | 40 | 0 | $1.18 | 3.0 | typescript | ok |
| Secret Rotation Validator | default | opus46 | 5.5min | 32 | 1 | $1.19 | 3.0 | python | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 13.5min | 24 | 0 | $1.19 | 4.0 | typescript | ok |
| PR Label Assigner | bash | opus46 | 6.5min | 42 | 2 | $1.22 | 2.0 | bash | ok |
| PR Label Assigner | default | sonnet46 | 16.5min | 23 | 1 | $1.25 | 4.0 | python | ok |
| Test Results Aggregator | bash | sonnet46 | 12.0min | 43 | 5 | $1.26 | 3.0 | bash | ok |
| Semantic Version Bumper | default | opus46 | 9.0min | 29 | 0 | $1.27 | 2.0 | python | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 13.1min | 1 | 3 | $1.31 | 4.0 | typescript | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.2min | 51 | 1 | $1.34 | 4.0 | typescript | ok |
| Docker Image Tag Generator | default | opus46 | 7.8min | 36 | 2 | $1.34 | 3.0 | python | ok |
| Secret Rotation Validator | bash | opus46 | 11.5min | 33 | 1 | $1.34 | 3.0 | bash | ok |
| Secret Rotation Validator | powershell | opus46 | 10.7min | 34 | 0 | $1.35 | 3.0 | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 13.7min | 46 | 6 | $1.35 | 4.0 | typescript | ok |
| Test Results Aggregator | bash | opus46 | 6.7min | 44 | 3 | $1.36 | 3.0 | bash | ok |
| Test Results Aggregator | default | opus46 | 7.6min | 40 | 2 | $1.43 | 3.0 | python | ok |
| Semantic Version Bumper | powershell | sonnet46 | 27.2min | 42 | 0 | $1.44 | 3.0 | powershell | ok |
| Semantic Version Bumper | bash | opus46 | 6.8min | 46 | 2 | $1.45 | 3.0 | bash | ok |
| Docker Image Tag Generator | bash | sonnet46 | 16.0min | 34 | 4 | $1.49 | 4.0 | bash | ok |
| Artifact Cleanup Script | default | sonnet46 | 15.9min | 25 | 1 | $1.49 | 4.0 | python | ok |
| Artifact Cleanup Script | bash | opus46 | 8.1min | 38 | 2 | $1.51 | 3.0 | bash | ok |
| Secret Rotation Validator | default | sonnet46 | 11.5min | 37 | 2 | $1.53 | 5.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 11.1min | 38 | 1 | $1.55 | 3.0 | powershell | ok |
| Test Results Aggregator | powershell | opus46 | 9.8min | 31 | 1 | $1.58 | 3.0 | powershell | ok |
| Artifact Cleanup Script | bash | sonnet46 | 15.4min | 47 | 3 | $1.59 | 4.0 | bash | ok |
| Artifact Cleanup Script | powershell | opus46 | 9.4min | 39 | 0 | $1.60 | 4.0 | powershell | ok |
| Semantic Version Bumper | default | sonnet46 | 17.2min | 38 | 1 | $1.62 | 4.0 | python | ok |
| Test Results Aggregator | powershell | sonnet46 | 19.9min | 43 | 0 | $1.77 | 4.0 | powershell | ok |
| Test Results Aggregator | default | sonnet46 | 15.9min | 58 | 2 | $1.78 | 4.0 | python | ok |
| Dependency License Checker | powershell | sonnet46 | 28.0min | 59 | 0 | $1.85 | 3.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 12.2min | 72 | 3 | $1.86 | 3.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 13.2min | 35 | 0 | $1.89 | 3.0 | typescript | ok |
| Environment Matrix Generator | powershell | sonnet46 | 22.1min | 42 | 0 | $1.93 | 3.0 | powershell | ok |
| Docker Image Tag Generator | bash | opus46 | 14.5min | 33 | 2 | $2.06 | 3.0 | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 12.3min | 30 | 0 | $2.06 | 4.0 | typescript | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 24.4min | 51 | 1 | $2.13 | 4.0 | powershell | ok |
| Dependency License Checker | default | opus46 | 10.6min | 65 | 4 | $2.35 | 5.0 | python | ok |
| PR Label Assigner | powershell | sonnet46 | 27.1min | 50 | 3 | $2.51 | 4.0 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Environment Matrix Generator | default | opus46 | 4.6min | 36 | 1 | $0.98 | 2.0 | bash | ok |
| PR Label Assigner | default | opus46 | 4.6min | 23 | 0 | $0.69 | 3.0 | python | ok |
| Semantic Version Bumper | bash | sonnet46 | 4.9min | 30 | 2 | $0.68 | 4.0 | bash | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 5.4min | 44 | 5 | $1.17 | 2.0 | typescript | ok |
| Dependency License Checker | bash | opus46 | 5.4min | 40 | 1 | $1.12 | 4.0 | bash | ok |
| Secret Rotation Validator | default | opus46 | 5.5min | 32 | 1 | $1.19 | 3.0 | python | ok |
| Dependency License Checker | bash | sonnet46 | 5.6min | 37 | 4 | $0.75 | 2.0 | bash | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.2min | 51 | 1 | $1.34 | 4.0 | typescript | ok |
| Artifact Cleanup Script | default | opus46 | 6.3min | 29 | 0 | $1.05 | 4.0 | python | ok |
| PR Label Assigner | bash | opus46 | 6.5min | 42 | 2 | $1.22 | 2.0 | bash | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 6.5min | 31 | 0 | $0.70 | 3.0 | powershell | ok |
| Environment Matrix Generator | powershell | opus46 | 6.7min | 44 | 5 | $0.99 | 2.0 | powershell | ok |
| Test Results Aggregator | bash | opus46 | 6.7min | 44 | 3 | $1.36 | 3.0 | bash | ok |
| PR Label Assigner | bash | sonnet46 | 6.8min | 39 | 5 | $0.90 | 4.0 | bash | ok |
| Semantic Version Bumper | bash | opus46 | 6.8min | 46 | 2 | $1.45 | 3.0 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 7.0min | 41 | 4 | $1.15 | 3.0 | typescript | ok |
| Test Results Aggregator | typescript-bun | opus46 | 7.1min | 40 | 0 | $1.18 | 3.0 | typescript | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.5min | 20 | 1 | $0.61 | 3.0 | powershell | ok |
| Test Results Aggregator | default | opus46 | 7.6min | 40 | 2 | $1.43 | 3.0 | python | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 7.7min | 47 | 4 | $1.10 | 3.0 | typescript | ok |
| Docker Image Tag Generator | default | opus46 | 7.8min | 36 | 2 | $1.34 | 3.0 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 28 | 0 | $0.72 | 3.0 | typescript | ok |
| Artifact Cleanup Script | bash | opus46 | 8.1min | 38 | 2 | $1.51 | 3.0 | bash | ok |
| PR Label Assigner | powershell | opus46 | 8.1min | 32 | 2 | $1.12 | 3.0 | powershell | ok |
| Semantic Version Bumper | default | opus46 | 9.0min | 29 | 0 | $1.27 | 2.0 | python | ok |
| PR Label Assigner | typescript-bun | opus46 | 9.1min | 31 | 1 | $0.96 | 3.0 | typescript | ok |
| Semantic Version Bumper | powershell | opus46 | 9.2min | 31 | 0 | $0.82 | 2.0 | powershell | ok |
| Artifact Cleanup Script | powershell | opus46 | 9.4min | 39 | 0 | $1.60 | 4.0 | powershell | ok |
| Environment Matrix Generator | bash | opus46 | 9.6min | 36 | 1 | $0.87 | 3.0 | bash | ok |
| Environment Matrix Generator | bash | sonnet46 | 9.8min | 40 | 6 | $0.84 | 3.0 | bash | ok |
| Test Results Aggregator | powershell | opus46 | 9.8min | 31 | 1 | $1.58 | 3.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 10.2min | 19 | 1 | $1.03 | 4.0 | typescript | ok |
| Dependency License Checker | default | opus46 | 10.6min | 65 | 4 | $2.35 | 5.0 | python | ok |
| Secret Rotation Validator | powershell | opus46 | 10.7min | 34 | 0 | $1.35 | 3.0 | powershell | ok |
| Dependency License Checker | powershell | opus46 | 11.1min | 38 | 1 | $1.55 | 3.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 11.1min | 40 | 1 | $1.02 | 3.0 | typescript | ok |
| Secret Rotation Validator | bash | sonnet46 | 11.2min | 31 | 4 | $0.94 | 3.0 | bash | ok |
| Secret Rotation Validator | bash | opus46 | 11.5min | 33 | 1 | $1.34 | 3.0 | bash | ok |
| Secret Rotation Validator | default | sonnet46 | 11.5min | 37 | 2 | $1.53 | 5.0 | python | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 11.7min | 30 | 1 | $1.18 | 2.0 | typescript | ok |
| Test Results Aggregator | bash | sonnet46 | 12.0min | 43 | 5 | $1.26 | 3.0 | bash | ok |
| Environment Matrix Generator | default | sonnet46 | 12.0min | 23 | 0 | $1.13 | 5.0 | python | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 12.2min | 72 | 3 | $1.86 | 3.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 12.3min | 30 | 0 | $2.06 | 4.0 | typescript | ok |
| Secret Rotation Validator | powershell | sonnet46 | 12.7min | 22 | 0 | $1.04 | 3.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 13.1min | 1 | 3 | $1.31 | 4.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 13.2min | 35 | 0 | $1.89 | 3.0 | typescript | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 13.5min | 24 | 0 | $1.19 | 4.0 | typescript | ok |
| Dependency License Checker | default | sonnet46 | 13.5min | 40 | 1 | $1.13 | 4.0 | python | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 13.7min | 46 | 6 | $1.35 | 4.0 | typescript | ok |
| Docker Image Tag Generator | bash | opus46 | 14.5min | 33 | 2 | $2.06 | 3.0 | bash | ok |
| Docker Image Tag Generator | default | sonnet46 | 14.6min | 13 | 1 | $1.14 | 4.0 | python | ok |
| Artifact Cleanup Script | bash | sonnet46 | 15.4min | 47 | 3 | $1.59 | 4.0 | bash | ok |
| Test Results Aggregator | default | sonnet46 | 15.9min | 58 | 2 | $1.78 | 4.0 | python | ok |
| Artifact Cleanup Script | default | sonnet46 | 15.9min | 25 | 1 | $1.49 | 4.0 | python | ok |
| Docker Image Tag Generator | bash | sonnet46 | 16.0min | 34 | 4 | $1.49 | 4.0 | bash | ok |
| PR Label Assigner | default | sonnet46 | 16.5min | 23 | 1 | $1.25 | 4.0 | python | ok |
| Semantic Version Bumper | default | sonnet46 | 17.2min | 38 | 1 | $1.62 | 4.0 | python | ok |
| Test Results Aggregator | powershell | sonnet46 | 19.9min | 43 | 0 | $1.77 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46 | 22.1min | 42 | 0 | $1.93 | 3.0 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 24.4min | 51 | 1 | $2.13 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 27.1min | 50 | 3 | $2.51 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46 | 27.2min | 42 | 0 | $1.44 | 3.0 | powershell | ok |
| Dependency License Checker | powershell | sonnet46 | 28.0min | 59 | 0 | $1.85 | 3.0 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Semantic Version Bumper | default | opus46 | 9.0min | 29 | 0 | $1.27 | 2.0 | python | ok |
| Semantic Version Bumper | powershell | opus46 | 9.2min | 31 | 0 | $0.82 | 2.0 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46 | 27.2min | 42 | 0 | $1.44 | 3.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 13.2min | 35 | 0 | $1.89 | 3.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 28 | 0 | $0.72 | 3.0 | typescript | ok |
| PR Label Assigner | default | opus46 | 4.6min | 23 | 0 | $0.69 | 3.0 | python | ok |
| Dependency License Checker | powershell | sonnet46 | 28.0min | 59 | 0 | $1.85 | 3.0 | powershell | ok |
| Test Results Aggregator | powershell | sonnet46 | 19.9min | 43 | 0 | $1.77 | 4.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus46 | 7.1min | 40 | 0 | $1.18 | 3.0 | typescript | ok |
| Environment Matrix Generator | default | sonnet46 | 12.0min | 23 | 0 | $1.13 | 5.0 | python | ok |
| Environment Matrix Generator | powershell | sonnet46 | 22.1min | 42 | 0 | $1.93 | 3.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 13.5min | 24 | 0 | $1.19 | 4.0 | typescript | ok |
| Artifact Cleanup Script | default | opus46 | 6.3min | 29 | 0 | $1.05 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 9.4min | 39 | 0 | $1.60 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 6.5min | 31 | 0 | $0.70 | 3.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 12.3min | 30 | 0 | $2.06 | 4.0 | typescript | ok |
| Secret Rotation Validator | powershell | opus46 | 10.7min | 34 | 0 | $1.35 | 3.0 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46 | 12.7min | 22 | 0 | $1.04 | 3.0 | powershell | ok |
| Semantic Version Bumper | default | sonnet46 | 17.2min | 38 | 1 | $1.62 | 4.0 | python | ok |
| PR Label Assigner | default | sonnet46 | 16.5min | 23 | 1 | $1.25 | 4.0 | python | ok |
| PR Label Assigner | typescript-bun | opus46 | 9.1min | 31 | 1 | $0.96 | 3.0 | typescript | ok |
| Dependency License Checker | bash | opus46 | 5.4min | 40 | 1 | $1.12 | 4.0 | bash | ok |
| Dependency License Checker | default | sonnet46 | 13.5min | 40 | 1 | $1.13 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 11.1min | 38 | 1 | $1.55 | 3.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.2min | 51 | 1 | $1.34 | 4.0 | typescript | ok |
| Docker Image Tag Generator | default | sonnet46 | 14.6min | 13 | 1 | $1.14 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.5min | 20 | 1 | $0.61 | 3.0 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 24.4min | 51 | 1 | $2.13 | 4.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 11.1min | 40 | 1 | $1.02 | 3.0 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 10.2min | 19 | 1 | $1.03 | 4.0 | typescript | ok |
| Test Results Aggregator | powershell | opus46 | 9.8min | 31 | 1 | $1.58 | 3.0 | powershell | ok |
| Environment Matrix Generator | bash | opus46 | 9.6min | 36 | 1 | $0.87 | 3.0 | bash | ok |
| Environment Matrix Generator | default | opus46 | 4.6min | 36 | 1 | $0.98 | 2.0 | bash | ok |
| Artifact Cleanup Script | default | sonnet46 | 15.9min | 25 | 1 | $1.49 | 4.0 | python | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 11.7min | 30 | 1 | $1.18 | 2.0 | typescript | ok |
| Secret Rotation Validator | bash | opus46 | 11.5min | 33 | 1 | $1.34 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus46 | 5.5min | 32 | 1 | $1.19 | 3.0 | python | ok |
| Semantic Version Bumper | bash | opus46 | 6.8min | 46 | 2 | $1.45 | 3.0 | bash | ok |
| Semantic Version Bumper | bash | sonnet46 | 4.9min | 30 | 2 | $0.68 | 4.0 | bash | ok |
| PR Label Assigner | bash | opus46 | 6.5min | 42 | 2 | $1.22 | 2.0 | bash | ok |
| PR Label Assigner | powershell | opus46 | 8.1min | 32 | 2 | $1.12 | 3.0 | powershell | ok |
| Docker Image Tag Generator | bash | opus46 | 14.5min | 33 | 2 | $2.06 | 3.0 | bash | ok |
| Docker Image Tag Generator | default | opus46 | 7.8min | 36 | 2 | $1.34 | 3.0 | python | ok |
| Test Results Aggregator | default | opus46 | 7.6min | 40 | 2 | $1.43 | 3.0 | python | ok |
| Test Results Aggregator | default | sonnet46 | 15.9min | 58 | 2 | $1.78 | 4.0 | python | ok |
| Artifact Cleanup Script | bash | opus46 | 8.1min | 38 | 2 | $1.51 | 3.0 | bash | ok |
| Secret Rotation Validator | default | sonnet46 | 11.5min | 37 | 2 | $1.53 | 5.0 | python | ok |
| PR Label Assigner | powershell | sonnet46 | 27.1min | 50 | 3 | $2.51 | 4.0 | powershell | ok |
| Test Results Aggregator | bash | opus46 | 6.7min | 44 | 3 | $1.36 | 3.0 | bash | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 12.2min | 72 | 3 | $1.86 | 3.0 | typescript | ok |
| Artifact Cleanup Script | bash | sonnet46 | 15.4min | 47 | 3 | $1.59 | 4.0 | bash | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 13.1min | 1 | 3 | $1.31 | 4.0 | typescript | ok |
| Dependency License Checker | bash | sonnet46 | 5.6min | 37 | 4 | $0.75 | 2.0 | bash | ok |
| Dependency License Checker | default | opus46 | 10.6min | 65 | 4 | $2.35 | 5.0 | python | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 7.7min | 47 | 4 | $1.10 | 3.0 | typescript | ok |
| Docker Image Tag Generator | bash | sonnet46 | 16.0min | 34 | 4 | $1.49 | 4.0 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 7.0min | 41 | 4 | $1.15 | 3.0 | typescript | ok |
| Secret Rotation Validator | bash | sonnet46 | 11.2min | 31 | 4 | $0.94 | 3.0 | bash | ok |
| PR Label Assigner | bash | sonnet46 | 6.8min | 39 | 5 | $0.90 | 4.0 | bash | ok |
| Test Results Aggregator | bash | sonnet46 | 12.0min | 43 | 5 | $1.26 | 3.0 | bash | ok |
| Environment Matrix Generator | powershell | opus46 | 6.7min | 44 | 5 | $0.99 | 2.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 5.4min | 44 | 5 | $1.17 | 2.0 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 13.7min | 46 | 6 | $1.35 | 4.0 | typescript | ok |
| Environment Matrix Generator | bash | sonnet46 | 9.8min | 40 | 6 | $0.84 | 3.0 | bash | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Secret Rotation Validator | typescript-bun | sonnet46 | 13.1min | 1 | 3 | $1.31 | 4.0 | typescript | ok |
| Docker Image Tag Generator | default | sonnet46 | 14.6min | 13 | 1 | $1.14 | 4.0 | python | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 10.2min | 19 | 1 | $1.03 | 4.0 | typescript | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.5min | 20 | 1 | $0.61 | 3.0 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46 | 12.7min | 22 | 0 | $1.04 | 3.0 | powershell | ok |
| PR Label Assigner | default | opus46 | 4.6min | 23 | 0 | $0.69 | 3.0 | python | ok |
| PR Label Assigner | default | sonnet46 | 16.5min | 23 | 1 | $1.25 | 4.0 | python | ok |
| Environment Matrix Generator | default | sonnet46 | 12.0min | 23 | 0 | $1.13 | 5.0 | python | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 13.5min | 24 | 0 | $1.19 | 4.0 | typescript | ok |
| Artifact Cleanup Script | default | sonnet46 | 15.9min | 25 | 1 | $1.49 | 4.0 | python | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 28 | 0 | $0.72 | 3.0 | typescript | ok |
| Semantic Version Bumper | default | opus46 | 9.0min | 29 | 0 | $1.27 | 2.0 | python | ok |
| Artifact Cleanup Script | default | opus46 | 6.3min | 29 | 0 | $1.05 | 4.0 | python | ok |
| Semantic Version Bumper | bash | sonnet46 | 4.9min | 30 | 2 | $0.68 | 4.0 | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 12.3min | 30 | 0 | $2.06 | 4.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 11.7min | 30 | 1 | $1.18 | 2.0 | typescript | ok |
| Semantic Version Bumper | powershell | opus46 | 9.2min | 31 | 0 | $0.82 | 2.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus46 | 9.1min | 31 | 1 | $0.96 | 3.0 | typescript | ok |
| Test Results Aggregator | powershell | opus46 | 9.8min | 31 | 1 | $1.58 | 3.0 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 6.5min | 31 | 0 | $0.70 | 3.0 | powershell | ok |
| Secret Rotation Validator | bash | sonnet46 | 11.2min | 31 | 4 | $0.94 | 3.0 | bash | ok |
| PR Label Assigner | powershell | opus46 | 8.1min | 32 | 2 | $1.12 | 3.0 | powershell | ok |
| Secret Rotation Validator | default | opus46 | 5.5min | 32 | 1 | $1.19 | 3.0 | python | ok |
| Docker Image Tag Generator | bash | opus46 | 14.5min | 33 | 2 | $2.06 | 3.0 | bash | ok |
| Secret Rotation Validator | bash | opus46 | 11.5min | 33 | 1 | $1.34 | 3.0 | bash | ok |
| Docker Image Tag Generator | bash | sonnet46 | 16.0min | 34 | 4 | $1.49 | 4.0 | bash | ok |
| Secret Rotation Validator | powershell | opus46 | 10.7min | 34 | 0 | $1.35 | 3.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 13.2min | 35 | 0 | $1.89 | 3.0 | typescript | ok |
| Docker Image Tag Generator | default | opus46 | 7.8min | 36 | 2 | $1.34 | 3.0 | python | ok |
| Environment Matrix Generator | bash | opus46 | 9.6min | 36 | 1 | $0.87 | 3.0 | bash | ok |
| Environment Matrix Generator | default | opus46 | 4.6min | 36 | 1 | $0.98 | 2.0 | bash | ok |
| Dependency License Checker | bash | sonnet46 | 5.6min | 37 | 4 | $0.75 | 2.0 | bash | ok |
| Secret Rotation Validator | default | sonnet46 | 11.5min | 37 | 2 | $1.53 | 5.0 | python | ok |
| Semantic Version Bumper | default | sonnet46 | 17.2min | 38 | 1 | $1.62 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 11.1min | 38 | 1 | $1.55 | 3.0 | powershell | ok |
| Artifact Cleanup Script | bash | opus46 | 8.1min | 38 | 2 | $1.51 | 3.0 | bash | ok |
| PR Label Assigner | bash | sonnet46 | 6.8min | 39 | 5 | $0.90 | 4.0 | bash | ok |
| Artifact Cleanup Script | powershell | opus46 | 9.4min | 39 | 0 | $1.60 | 4.0 | powershell | ok |
| Dependency License Checker | bash | opus46 | 5.4min | 40 | 1 | $1.12 | 4.0 | bash | ok |
| Dependency License Checker | default | sonnet46 | 13.5min | 40 | 1 | $1.13 | 4.0 | python | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 11.1min | 40 | 1 | $1.02 | 3.0 | typescript | ok |
| Test Results Aggregator | default | opus46 | 7.6min | 40 | 2 | $1.43 | 3.0 | python | ok |
| Test Results Aggregator | typescript-bun | opus46 | 7.1min | 40 | 0 | $1.18 | 3.0 | typescript | ok |
| Environment Matrix Generator | bash | sonnet46 | 9.8min | 40 | 6 | $0.84 | 3.0 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 7.0min | 41 | 4 | $1.15 | 3.0 | typescript | ok |
| Semantic Version Bumper | powershell | sonnet46 | 27.2min | 42 | 0 | $1.44 | 3.0 | powershell | ok |
| PR Label Assigner | bash | opus46 | 6.5min | 42 | 2 | $1.22 | 2.0 | bash | ok |
| Environment Matrix Generator | powershell | sonnet46 | 22.1min | 42 | 0 | $1.93 | 3.0 | powershell | ok |
| Test Results Aggregator | bash | sonnet46 | 12.0min | 43 | 5 | $1.26 | 3.0 | bash | ok |
| Test Results Aggregator | powershell | sonnet46 | 19.9min | 43 | 0 | $1.77 | 4.0 | powershell | ok |
| Test Results Aggregator | bash | opus46 | 6.7min | 44 | 3 | $1.36 | 3.0 | bash | ok |
| Environment Matrix Generator | powershell | opus46 | 6.7min | 44 | 5 | $0.99 | 2.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 5.4min | 44 | 5 | $1.17 | 2.0 | typescript | ok |
| Semantic Version Bumper | bash | opus46 | 6.8min | 46 | 2 | $1.45 | 3.0 | bash | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 13.7min | 46 | 6 | $1.35 | 4.0 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 7.7min | 47 | 4 | $1.10 | 3.0 | typescript | ok |
| Artifact Cleanup Script | bash | sonnet46 | 15.4min | 47 | 3 | $1.59 | 4.0 | bash | ok |
| PR Label Assigner | powershell | sonnet46 | 27.1min | 50 | 3 | $2.51 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.2min | 51 | 1 | $1.34 | 4.0 | typescript | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 24.4min | 51 | 1 | $2.13 | 4.0 | powershell | ok |
| Test Results Aggregator | default | sonnet46 | 15.9min | 58 | 2 | $1.78 | 4.0 | python | ok |
| Dependency License Checker | powershell | sonnet46 | 28.0min | 59 | 0 | $1.85 | 3.0 | powershell | ok |
| Dependency License Checker | default | opus46 | 10.6min | 65 | 4 | $2.35 | 5.0 | python | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 12.2min | 72 | 3 | $1.86 | 3.0 | typescript | ok |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Dependency License Checker | default | opus46 | 10.6min | 65 | 4 | $2.35 | 5.0 | python | ok |
| Environment Matrix Generator | default | sonnet46 | 12.0min | 23 | 0 | $1.13 | 5.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 11.5min | 37 | 2 | $1.53 | 5.0 | python | ok |
| Semantic Version Bumper | bash | sonnet46 | 4.9min | 30 | 2 | $0.68 | 4.0 | bash | ok |
| Semantic Version Bumper | default | sonnet46 | 17.2min | 38 | 1 | $1.62 | 4.0 | python | ok |
| PR Label Assigner | bash | sonnet46 | 6.8min | 39 | 5 | $0.90 | 4.0 | bash | ok |
| PR Label Assigner | default | sonnet46 | 16.5min | 23 | 1 | $1.25 | 4.0 | python | ok |
| PR Label Assigner | powershell | sonnet46 | 27.1min | 50 | 3 | $2.51 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | sonnet46 | 13.7min | 46 | 6 | $1.35 | 4.0 | typescript | ok |
| Dependency License Checker | bash | opus46 | 5.4min | 40 | 1 | $1.12 | 4.0 | bash | ok |
| Dependency License Checker | default | sonnet46 | 13.5min | 40 | 1 | $1.13 | 4.0 | python | ok |
| Dependency License Checker | typescript-bun | opus46 | 6.2min | 51 | 1 | $1.34 | 4.0 | typescript | ok |
| Docker Image Tag Generator | bash | sonnet46 | 16.0min | 34 | 4 | $1.49 | 4.0 | bash | ok |
| Docker Image Tag Generator | default | sonnet46 | 14.6min | 13 | 1 | $1.14 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 24.4min | 51 | 1 | $2.13 | 4.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | sonnet46 | 10.2min | 19 | 1 | $1.03 | 4.0 | typescript | ok |
| Test Results Aggregator | default | sonnet46 | 15.9min | 58 | 2 | $1.78 | 4.0 | python | ok |
| Test Results Aggregator | powershell | sonnet46 | 19.9min | 43 | 0 | $1.77 | 4.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | sonnet46 | 13.5min | 24 | 0 | $1.19 | 4.0 | typescript | ok |
| Artifact Cleanup Script | bash | sonnet46 | 15.4min | 47 | 3 | $1.59 | 4.0 | bash | ok |
| Artifact Cleanup Script | default | opus46 | 6.3min | 29 | 0 | $1.05 | 4.0 | python | ok |
| Artifact Cleanup Script | default | sonnet46 | 15.9min | 25 | 1 | $1.49 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 9.4min | 39 | 0 | $1.60 | 4.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus46 | 12.3min | 30 | 0 | $2.06 | 4.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet46 | 13.1min | 1 | 3 | $1.31 | 4.0 | typescript | ok |
| Semantic Version Bumper | bash | opus46 | 6.8min | 46 | 2 | $1.45 | 3.0 | bash | ok |
| Semantic Version Bumper | powershell | sonnet46 | 27.2min | 42 | 0 | $1.44 | 3.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus46 | 13.2min | 35 | 0 | $1.89 | 3.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet46 | 8.1min | 28 | 0 | $0.72 | 3.0 | typescript | ok |
| PR Label Assigner | default | opus46 | 4.6min | 23 | 0 | $0.69 | 3.0 | python | ok |
| PR Label Assigner | powershell | opus46 | 8.1min | 32 | 2 | $1.12 | 3.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus46 | 9.1min | 31 | 1 | $0.96 | 3.0 | typescript | ok |
| Dependency License Checker | powershell | opus46 | 11.1min | 38 | 1 | $1.55 | 3.0 | powershell | ok |
| Dependency License Checker | powershell | sonnet46 | 28.0min | 59 | 0 | $1.85 | 3.0 | powershell | ok |
| Dependency License Checker | typescript-bun | sonnet46 | 7.7min | 47 | 4 | $1.10 | 3.0 | typescript | ok |
| Docker Image Tag Generator | bash | opus46 | 14.5min | 33 | 2 | $2.06 | 3.0 | bash | ok |
| Docker Image Tag Generator | default | opus46 | 7.8min | 36 | 2 | $1.34 | 3.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 7.5min | 20 | 1 | $0.61 | 3.0 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus46 | 11.1min | 40 | 1 | $1.02 | 3.0 | typescript | ok |
| Test Results Aggregator | bash | opus46 | 6.7min | 44 | 3 | $1.36 | 3.0 | bash | ok |
| Test Results Aggregator | bash | sonnet46 | 12.0min | 43 | 5 | $1.26 | 3.0 | bash | ok |
| Test Results Aggregator | default | opus46 | 7.6min | 40 | 2 | $1.43 | 3.0 | python | ok |
| Test Results Aggregator | powershell | opus46 | 9.8min | 31 | 1 | $1.58 | 3.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus46 | 7.1min | 40 | 0 | $1.18 | 3.0 | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet46 | 12.2min | 72 | 3 | $1.86 | 3.0 | typescript | ok |
| Environment Matrix Generator | bash | opus46 | 9.6min | 36 | 1 | $0.87 | 3.0 | bash | ok |
| Environment Matrix Generator | bash | sonnet46 | 9.8min | 40 | 6 | $0.84 | 3.0 | bash | ok |
| Environment Matrix Generator | powershell | sonnet46 | 22.1min | 42 | 0 | $1.93 | 3.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus46 | 7.0min | 41 | 4 | $1.15 | 3.0 | typescript | ok |
| Artifact Cleanup Script | bash | opus46 | 8.1min | 38 | 2 | $1.51 | 3.0 | bash | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 6.5min | 31 | 0 | $0.70 | 3.0 | powershell | ok |
| Secret Rotation Validator | bash | opus46 | 11.5min | 33 | 1 | $1.34 | 3.0 | bash | ok |
| Secret Rotation Validator | bash | sonnet46 | 11.2min | 31 | 4 | $0.94 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus46 | 5.5min | 32 | 1 | $1.19 | 3.0 | python | ok |
| Secret Rotation Validator | powershell | opus46 | 10.7min | 34 | 0 | $1.35 | 3.0 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46 | 12.7min | 22 | 0 | $1.04 | 3.0 | powershell | ok |
| Semantic Version Bumper | default | opus46 | 9.0min | 29 | 0 | $1.27 | 2.0 | python | ok |
| Semantic Version Bumper | powershell | opus46 | 9.2min | 31 | 0 | $0.82 | 2.0 | powershell | ok |
| PR Label Assigner | bash | opus46 | 6.5min | 42 | 2 | $1.22 | 2.0 | bash | ok |
| Dependency License Checker | bash | sonnet46 | 5.6min | 37 | 4 | $0.75 | 2.0 | bash | ok |
| Environment Matrix Generator | default | opus46 | 4.6min | 36 | 1 | $0.98 | 2.0 | bash | ok |
| Environment Matrix Generator | powershell | opus46 | 6.7min | 44 | 5 | $0.99 | 2.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | sonnet46 | 11.7min | 30 | 1 | $1.18 | 2.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus46 | 5.4min | 44 | 5 | $1.17 | 2.0 | typescript | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v3*