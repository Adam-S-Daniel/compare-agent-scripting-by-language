# Benchmark Results: Language Comparison

**Last updated:** 2026-04-17 06:16:07 PM ET

**Status:** 111/144 runs completed, 33 remaining
**Total cost so far:** $76.34
**Total agent time so far:** 459.2 min

## Rankings by Language/Model/Effort

*Lower rank = better on that axis (1 = fastest / cheapest / highest LLM score).*
*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| csharp-script | opus46 | 2 | 4 | 4 |
| csharp-script | sonnet46 | 1 | 1 | 5 |
| default | opus46 | 4 | 6 | 1 |
| default | sonnet46 | 3 | 2 | 2 |
| powershell | opus46 | 6 | 7 | 3 |
| powershell | sonnet46 | 5 | 3 | 8 |
| powershell-strict | opus46 | 7 | 8 | 7 |
| powershell-strict | sonnet46 | 8 | 5 | 6 |


<details>
<summary>Sorted by Duration rank (fastest first)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| csharp-script | sonnet46 | 1 | 1 | 5 |
| csharp-script | opus46 | 2 | 4 | 4 |
| default | sonnet46 | 3 | 2 | 2 |
| default | opus46 | 4 | 6 | 1 |
| powershell | sonnet46 | 5 | 3 | 8 |
| powershell | opus46 | 6 | 7 | 3 |
| powershell-strict | opus46 | 7 | 8 | 7 |
| powershell-strict | sonnet46 | 8 | 5 | 6 |

</details>

<details>
<summary>Sorted by Cost rank (cheapest first)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| csharp-script | sonnet46 | 1 | 1 | 5 |
| default | sonnet46 | 3 | 2 | 2 |
| powershell | sonnet46 | 5 | 3 | 8 |
| csharp-script | opus46 | 2 | 4 | 4 |
| powershell-strict | sonnet46 | 8 | 5 | 6 |
| default | opus46 | 4 | 6 | 1 |
| powershell | opus46 | 6 | 7 | 3 |
| powershell-strict | opus46 | 7 | 8 | 7 |

</details>

<details>
<summary>Sorted by LLM Score rank (best first; no-data last)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| default | opus46 | 4 | 6 | 1 |
| default | sonnet46 | 3 | 2 | 2 |
| powershell | opus46 | 6 | 7 | 3 |
| csharp-script | opus46 | 2 | 4 | 4 |
| csharp-script | sonnet46 | 1 | 1 | 5 |
| powershell-strict | sonnet46 | 8 | 5 | 6 |
| powershell-strict | opus46 | 7 | 8 | 7 |
| powershell | sonnet46 | 5 | 3 | 8 |

</details>

## Tiers by Language/Model/Effort

*Duration / Cost tier = ratio of this combo's average to the best combo's average on that axis (lower ratio = better). Bands: **A** ≤1.15×, **B** ≤1.40×, **C** ≤1.80×, **D** ≤2.50×, **E** >2.50×.*
*LLM Score tier = absolute Overall score band. **A** ≥4.5, **B** ≥3.5, **C** ≥2.5, **D** ≥1.5, **E** <1.5, `—` = no data.*
*If every row in a column is tier A, those combos are effectively tied on that axis.*

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| csharp-script | opus46 | E (1.8min) | E ($0.42) | B (4.0) |
| csharp-script | sonnet46 | A (0.6min) | A ($0.12) | B (4.0) |
| default | opus46 | E (3.5min) | E ($0.88) | B (4.2) |
| default | sonnet46 | E (2.8min) | E ($0.35) | B (4.2) |
| powershell | opus46 | E (4.3min) | E ($0.97) | B (4.1) |
| powershell | sonnet46 | E (3.6min) | E ($0.39) | B (3.9) |
| powershell-strict | opus46 | E (4.9min) | E ($1.20) | B (3.9) |
| powershell-strict | sonnet46 | E (6.1min) | E ($0.74) | B (4.0) |

- **Estimated time remaining:** 0.0min
- **Estimated total cost:** $99.03

## Failed / Timed-Out Runs

| Task | Language | Model | Duration | Reason | Lines | actionlint | act-result.txt |
|------|------|-------|----------|--------|-------|------------|----------------|
| Database Seed Script | default | sonnet46 | 3.9min | exit_code=1 | 0 | n/a | no |
| Database Seed Script | powershell | sonnet46 | 3.8min | exit_code=1 | 0 | n/a | no |
| Database Seed Script | powershell-strict | sonnet46 | 3.6min | exit_code=1 | 0 | n/a | no |
| Error Retry Pipeline | default | sonnet46 | 3.7min | exit_code=1 | 0 | n/a | no |
| Error Retry Pipeline | powershell | sonnet46 | 3.8min | exit_code=1 | 0 | n/a | no |
| Error Retry Pipeline | powershell-strict | opus46 | 9.7min | exit_code=143 | 425 | n/a | no |
| Error Retry Pipeline | powershell-strict | sonnet46 | 3.8min | exit_code=1 | 0 | n/a | no |
| Multi-file Search and Replace | default | sonnet46 | 3.9min | exit_code=1 | 0 | n/a | no |
| Multi-file Search and Replace | powershell-strict | sonnet46 | 3.8min | exit_code=1 | 0 | n/a | no |
| Semantic Version Bumper | powershell-strict | sonnet46 | 5.3min | exit_code=1 | 353 | n/a | no |
| Dependency License Checker | default | sonnet46 | 4.0min | exit_code=1 | 0 | n/a | no |

*11 run(s) excluded from averages below.*

## Comparison by Language/Model/Effort
*(averages exclude failed/timed-out runs)*
*Avg LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| csharp-script | opus46 | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 | 4.0 |
| csharp-script | sonnet46 | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 | 4.0 |
| default | opus46 | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 | 4.2 |
| default | sonnet46 | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 | 4.2 |
| powershell | opus46 | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 | 4.1 |
| powershell | sonnet46 | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 | 3.9 |
| powershell-strict | opus46 | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 | 3.9 |
| powershell-strict | sonnet46 | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 | 4.0 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| csharp-script | sonnet46 | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 | 4.0 |
| default | sonnet46 | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 | 4.2 |
| powershell | sonnet46 | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 | 3.9 |
| csharp-script | opus46 | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 | 4.0 |
| powershell-strict | sonnet46 | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 | 4.0 |
| default | opus46 | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 | 4.2 |
| powershell | opus46 | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 | 4.1 |
| powershell-strict | opus46 | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 | 3.9 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| csharp-script | sonnet46 | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 | 4.0 |
| csharp-script | opus46 | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 | 4.0 |
| default | sonnet46 | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 | 4.2 |
| default | opus46 | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 | 4.2 |
| powershell | sonnet46 | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 | 3.9 |
| powershell | opus46 | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 | 4.1 |
| powershell-strict | opus46 | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 | 3.9 |
| powershell-strict | sonnet46 | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 | 4.0 |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| csharp-script | sonnet46 | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 | 4.0 |
| csharp-script | opus46 | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 | 4.0 |
| powershell | opus46 | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 | 4.1 |
| default | opus46 | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 | 4.2 |
| powershell-strict | opus46 | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 | 3.9 |
| default | sonnet46 | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 | 4.2 |
| powershell | sonnet46 | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 | 3.9 |
| powershell-strict | sonnet46 | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 | 4.0 |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| csharp-script | opus46 | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 | 4.0 |
| csharp-script | sonnet46 | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 | 4.0 |
| powershell | sonnet46 | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 | 3.9 |
| powershell-strict | sonnet46 | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 | 4.0 |
| powershell | opus46 | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 | 4.1 |
| powershell-strict | opus46 | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 | 3.9 |
| default | sonnet46 | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 | 4.2 |
| default | opus46 | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 | 4.2 |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| csharp-script | sonnet46 | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 | 4.0 |
| csharp-script | opus46 | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 | 4.0 |
| powershell | sonnet46 | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 | 3.9 |
| default | sonnet46 | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 | 4.2 |
| powershell-strict | sonnet46 | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 | 4.0 |
| default | opus46 | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 | 4.2 |
| powershell | opus46 | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 | 4.1 |
| powershell-strict | opus46 | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 | 3.9 |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| default | opus46 | 18 | 3.5min | 2.0min | 1.1 | 32 | $0.88 | $15.75 | 4.2 |
| default | sonnet46 | 14 | 2.8min | 2.8min | 0.9 | 12 | $0.35 | $4.91 | 4.2 |
| powershell | opus46 | 18 | 4.3min | 1.9min | 0.4 | 32 | $0.97 | $17.49 | 4.1 |
| csharp-script | opus46 | 2 | 1.8min | 1.8min | 0.0 | 10 | $0.42 | $0.84 | 4.0 |
| csharp-script | sonnet46 | 1 | 0.6min | 0.6min | 0.0 | 7 | $0.12 | $0.12 | 4.0 |
| powershell-strict | sonnet46 | 14 | 6.1min | 5.7min | 0.1 | 17 | $0.74 | $10.31 | 4.0 |
| powershell-strict | opus46 | 17 | 4.9min | 2.0min | 0.8 | 37 | $1.20 | $20.45 | 3.9 |
| powershell | sonnet46 | 16 | 3.6min | 3.5min | 0.0 | 11 | $0.39 | $6.32 | 3.9 |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | default | opus46 | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| repeated-test-reruns | powershell | opus46 | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| repeated-test-reruns | powershell | sonnet46 | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| repeated-test-reruns | powershell-strict | opus46 | 17 | 48.7min | 10.6% | $12.19 | 15.97% |
| repeated-test-reruns | powershell-strict | sonnet46 | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| fixture-rework | powershell-strict | opus46 | 1 | 0.5min | 0.1% | $0.12 | 0.15% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | powershell-strict | opus46 | 1 | 0.5min | 0.1% | $0.12 | 0.15% |
| repeated-test-reruns | powershell | sonnet46 | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| repeated-test-reruns | powershell-strict | sonnet46 | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| repeated-test-reruns | default | opus46 | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| repeated-test-reruns | powershell | opus46 | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| repeated-test-reruns | powershell-strict | opus46 | 17 | 48.7min | 10.6% | $12.19 | 15.97% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | powershell-strict | opus46 | 1 | 0.5min | 0.1% | $0.12 | 0.15% |
| repeated-test-reruns | powershell | sonnet46 | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| repeated-test-reruns | powershell-strict | sonnet46 | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| repeated-test-reruns | default | opus46 | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| repeated-test-reruns | powershell | opus46 | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| repeated-test-reruns | powershell-strict | opus46 | 17 | 48.7min | 10.6% | $12.19 | 15.97% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | powershell-strict | opus46 | 1 | 0.5min | 0.1% | $0.12 | 0.15% |
| repeated-test-reruns | powershell | sonnet46 | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| repeated-test-reruns | powershell-strict | sonnet46 | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| repeated-test-reruns | default | opus46 | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| repeated-test-reruns | powershell | opus46 | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| repeated-test-reruns | powershell-strict | opus46 | 17 | 48.7min | 10.6% | $12.19 | 15.97% |

</details>

#### Trap Descriptions

- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
- **repeated-test-reruns**: Same test command executed 4+ times without the underlying code changing.

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
| csharp-script | opus46 | 2 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| csharp-script | sonnet46 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus46 | 18 | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| default | sonnet46 | 18 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | opus46 | 18 | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| powershell | sonnet46 | 18 | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| powershell-strict | opus46 | 18 | 18 | 49.2min | 10.7% | $12.30 | 16.12% |
| powershell-strict | sonnet46 | 18 | 6 | 5.7min | 1.2% | $0.76 | 1.00% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| csharp-script | opus46 | 2 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| csharp-script | sonnet46 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet46 | 18 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet46 | 18 | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| powershell-strict | sonnet46 | 18 | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| default | opus46 | 18 | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| powershell | opus46 | 18 | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| powershell-strict | opus46 | 18 | 18 | 49.2min | 10.7% | $12.30 | 16.12% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| csharp-script | opus46 | 2 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| csharp-script | sonnet46 | 1 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | sonnet46 | 18 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| powershell | sonnet46 | 18 | 2 | 1.3min | 0.3% | $0.17 | 0.23% |
| powershell-strict | sonnet46 | 18 | 6 | 5.7min | 1.2% | $0.76 | 1.00% |
| default | opus46 | 18 | 13 | 27.0min | 5.9% | $6.90 | 9.04% |
| powershell | opus46 | 18 | 17 | 43.0min | 9.4% | $9.89 | 12.95% |
| powershell-strict | opus46 | 18 | 18 | 49.2min | 10.7% | $12.30 | 16.12% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 102 | $5.46 | 7.15% |
| Miss | 9 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| csharp-script | opus46 | 56.0 | 56.0 | 1.0 | 2.08 |
| csharp-script | sonnet46 | 0.0 | 0.0 | 0.0 | 1.76 |
| default | opus46 | 25.1 | 43.6 | 1.7 | 1.49 |
| default | sonnet46 | 19.6 | 30.6 | 1.6 | 0.97 |
| powershell | opus46 | 23.8 | 44.2 | 1.9 | 1.39 |
| powershell | sonnet46 | 21.2 | 36.6 | 1.7 | 1.11 |
| powershell-strict | opus46 | 22.3 | 48.1 | 2.2 | 1.40 |
| powershell-strict | sonnet46 | 27.0 | 45.6 | 1.7 | 0.51 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| csharp-script | opus46 | 56.0 | 56.0 | 1.0 | 2.08 |
| powershell-strict | sonnet46 | 27.0 | 45.6 | 1.7 | 0.51 |
| default | opus46 | 25.1 | 43.6 | 1.7 | 1.49 |
| powershell | opus46 | 23.8 | 44.2 | 1.9 | 1.39 |
| powershell-strict | opus46 | 22.3 | 48.1 | 2.2 | 1.40 |
| powershell | sonnet46 | 21.2 | 36.6 | 1.7 | 1.11 |
| default | sonnet46 | 19.6 | 30.6 | 1.6 | 0.97 |
| csharp-script | sonnet46 | 0.0 | 0.0 | 0.0 | 1.76 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| csharp-script | opus46 | 56.0 | 56.0 | 1.0 | 2.08 |
| powershell-strict | opus46 | 22.3 | 48.1 | 2.2 | 1.40 |
| powershell-strict | sonnet46 | 27.0 | 45.6 | 1.7 | 0.51 |
| powershell | opus46 | 23.8 | 44.2 | 1.9 | 1.39 |
| default | opus46 | 25.1 | 43.6 | 1.7 | 1.49 |
| powershell | sonnet46 | 21.2 | 36.6 | 1.7 | 1.11 |
| default | sonnet46 | 19.6 | 30.6 | 1.6 | 0.97 |
| csharp-script | sonnet46 | 0.0 | 0.0 | 0.0 | 1.76 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| csharp-script | opus46 | 56.0 | 56.0 | 1.0 | 2.08 |
| csharp-script | sonnet46 | 0.0 | 0.0 | 0.0 | 1.76 |
| default | opus46 | 25.1 | 43.6 | 1.7 | 1.49 |
| powershell-strict | opus46 | 22.3 | 48.1 | 2.2 | 1.40 |
| powershell | opus46 | 23.8 | 44.2 | 1.9 | 1.39 |
| powershell | sonnet46 | 21.2 | 36.6 | 1.7 | 1.11 |
| default | sonnet46 | 19.6 | 30.6 | 1.6 | 0.97 |
| powershell-strict | sonnet46 | 27.0 | 45.6 | 1.7 | 0.51 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Language | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| CSV Report Generator | csharp-script | opus46 | 59 | 59 | 1.0 | 471 | 227 | 2.07 |
| CSV Report Generator | csharp-script | sonnet46 | 0 | 0 | 0.0 | 450 | 256 | 1.76 |
| CSV Report Generator | default | opus46 | 24 | 39 | 1.6 | 309 | 158 | 1.96 |
| CSV Report Generator | default | sonnet46 | 38 | 43 | 1.1 | 314 | 220 | 1.43 |
| CSV Report Generator | powershell | opus46 | 21 | 35 | 1.7 | 185 | 145 | 1.28 |
| CSV Report Generator | powershell | sonnet46 | 25 | 34 | 1.4 | 243 | 178 | 1.37 |
| CSV Report Generator | powershell-strict | opus46 | 24 | 37 | 1.5 | 223 | 218 | 1.02 |
| CSV Report Generator | powershell-strict | sonnet46 | 30 | 44 | 1.5 | 272 | 0 | 0.00 |
| Log File Analyzer | csharp-script | opus46 | 53 | 53 | 1.0 | 548 | 263 | 2.08 |
| Log File Analyzer | default | opus46 | 21 | 52 | 2.5 | 262 | 194 | 1.35 |
| Log File Analyzer | default | sonnet46 | 51 | 67 | 1.3 | 405 | 306 | 1.32 |
| Log File Analyzer | powershell | opus46 | 18 | 55 | 3.1 | 216 | 227 | 0.95 |
| Log File Analyzer | powershell | sonnet46 | 34 | 57 | 1.7 | 341 | 312 | 1.09 |
| Log File Analyzer | powershell-strict | opus46 | 15 | 39 | 2.6 | 181 | 351 | 0.52 |
| Log File Analyzer | powershell-strict | sonnet46 | 26 | 57 | 2.2 | 342 | 0 | 0.00 |
| Directory Tree Sync | default | opus46 | 27 | 47 | 1.7 | 294 | 217 | 1.35 |
| Directory Tree Sync | default | sonnet46 | 25 | 56 | 2.2 | 345 | 409 | 0.84 |
| Directory Tree Sync | powershell | opus46 | 30 | 49 | 1.6 | 320 | 222 | 1.44 |
| Directory Tree Sync | powershell | sonnet46 | 32 | 69 | 2.2 | 447 | 310 | 1.44 |
| Directory Tree Sync | powershell-strict | opus46 | 28 | 65 | 2.3 | 384 | 244 | 1.57 |
| Directory Tree Sync | powershell-strict | sonnet46 | 31 | 49 | 1.6 | 391 | 0 | 0.00 |
| REST API Client | default | opus46 | 16 | 29 | 1.8 | 329 | 130 | 2.53 |
| REST API Client | default | sonnet46 | 14 | 26 | 1.9 | 303 | 191 | 1.59 |
| REST API Client | powershell | opus46 | 27 | 30 | 1.1 | 351 | 186 | 1.89 |
| REST API Client | powershell | sonnet46 | 12 | 19 | 1.6 | 194 | 233 | 0.83 |
| REST API Client | powershell-strict | opus46 | 21 | 22 | 1.0 | 353 | 45 | 7.84 |
| REST API Client | powershell-strict | sonnet46 | 24 | 40 | 1.7 | 391 | 0 | 0.00 |
| Process Monitor | default | opus46 | 16 | 40 | 2.5 | 184 | 220 | 0.84 |
| Process Monitor | default | sonnet46 | 20 | 39 | 1.9 | 198 | 209 | 0.95 |
| Process Monitor | powershell | opus46 | 19 | 48 | 2.5 | 197 | 195 | 1.01 |
| Process Monitor | powershell | sonnet46 | 17 | 36 | 2.1 | 203 | 186 | 1.09 |
| Process Monitor | powershell-strict | opus46 | 22 | 50 | 2.3 | 217 | 194 | 1.12 |
| Process Monitor | powershell-strict | sonnet46 | 24 | 42 | 1.8 | 254 | 0 | 0.00 |
| Config File Migrator | default | opus46 | 31 | 66 | 2.1 | 480 | 340 | 1.41 |
| Config File Migrator | default | sonnet46 | 28 | 41 | 1.5 | 404 | 309 | 1.31 |
| Config File Migrator | powershell | opus46 | 31 | 56 | 1.8 | 259 | 337 | 0.77 |
| Config File Migrator | powershell | sonnet46 | 39 | 63 | 1.6 | 450 | 417 | 1.08 |
| Config File Migrator | powershell-strict | opus46 | 27 | 63 | 2.3 | 415 | 321 | 1.29 |
| Config File Migrator | powershell-strict | sonnet46 | 66 | 116 | 1.8 | 627 | 0 | 0.00 |
| Batch File Renamer | default | opus46 | 20 | 40 | 2.0 | 269 | 173 | 1.55 |
| Batch File Renamer | default | sonnet46 | 17 | 35 | 2.1 | 320 | 212 | 1.51 |
| Batch File Renamer | powershell | opus46 | 14 | 38 | 2.7 | 252 | 99 | 2.55 |
| Batch File Renamer | powershell | sonnet46 | 11 | 23 | 2.1 | 181 | 170 | 1.06 |
| Batch File Renamer | powershell-strict | opus46 | 20 | 45 | 2.2 | 281 | 189 | 1.49 |
| Batch File Renamer | powershell-strict | sonnet46 | 22 | 45 | 2.0 | 287 | 0 | 0.00 |
| Database Seed Script | default | opus46 | 37 | 66 | 1.8 | 339 | 293 | 1.16 |
| Database Seed Script | default | sonnet46 | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Database Seed Script | powershell | opus46 | 37 | 60 | 1.6 | 334 | 464 | 0.72 |
| Database Seed Script | powershell | sonnet46 | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Database Seed Script | powershell-strict | opus46 | 28 | 79 | 2.8 | 398 | 558 | 0.71 |
| Database Seed Script | powershell-strict | sonnet46 | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Error Retry Pipeline | default | opus46 | 15 | 37 | 2.5 | 229 | 144 | 1.59 |
| Error Retry Pipeline | default | sonnet46 | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Error Retry Pipeline | powershell | opus46 | 16 | 44 | 2.8 | 233 | 135 | 1.73 |
| Error Retry Pipeline | powershell | sonnet46 | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Error Retry Pipeline | powershell-strict | opus46 | 18 | 42 | 2.3 | 196 | 229 | 0.86 |
| Error Retry Pipeline | powershell-strict | sonnet46 | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Multi-file Search and Replace | default | opus46 | 24 | 36 | 1.5 | 220 | 182 | 1.21 |
| Multi-file Search and Replace | default | sonnet46 | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Multi-file Search and Replace | powershell | opus46 | 21 | 38 | 1.8 | 298 | 151 | 1.97 |
| Multi-file Search and Replace | powershell | sonnet46 | 17 | 31 | 1.8 | 214 | 125 | 1.71 |
| Multi-file Search and Replace | powershell-strict | opus46 | 17 | 39 | 2.3 | 286 | 213 | 1.34 |
| Multi-file Search and Replace | powershell-strict | sonnet46 | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Semantic Version Bumper | default | opus46 | 44 | 52 | 1.2 | 310 | 196 | 1.58 |
| Semantic Version Bumper | default | sonnet46 | 31 | 31 | 1.0 | 231 | 293 | 0.79 |
| Semantic Version Bumper | powershell | opus46 | 24 | 52 | 2.2 | 241 | 201 | 1.20 |
| Semantic Version Bumper | powershell | sonnet46 | 29 | 40 | 1.4 | 308 | 303 | 1.02 |
| Semantic Version Bumper | powershell-strict | opus46 | 26 | 57 | 2.2 | 268 | 338 | 0.79 |
| Semantic Version Bumper | powershell-strict | sonnet46 | 32 | 38 | 1.2 | 353 | 0 | 0.00 |
| PR Label Assigner | default | opus46 | 24 | 22 | 0.9 | 218 | 160 | 1.36 |
| PR Label Assigner | default | sonnet46 | 21 | 26 | 1.2 | 232 | 195 | 1.19 |
| PR Label Assigner | powershell | opus46 | 18 | 33 | 1.8 | 212 | 146 | 1.45 |
| PR Label Assigner | powershell | sonnet46 | 27 | 46 | 1.7 | 313 | 202 | 1.55 |
| PR Label Assigner | powershell-strict | opus46 | 18 | 32 | 1.8 | 248 | 148 | 1.68 |
| PR Label Assigner | powershell-strict | sonnet46 | 30 | 56 | 1.9 | 275 | 0 | 0.00 |
| Dependency License Checker | default | opus46 | 29 | 51 | 1.8 | 367 | 227 | 1.62 |
| Dependency License Checker | default | sonnet46 | 0 | 0 | 0.0 | 0 | 0 | 0.00 |
| Dependency License Checker | powershell | opus46 | 17 | 52 | 3.1 | 319 | 228 | 1.40 |
| Dependency License Checker | powershell | sonnet46 | 27 | 50 | 1.9 | 403 | 257 | 1.57 |
| Dependency License Checker | powershell-strict | opus46 | 18 | 54 | 3.0 | 336 | 381 | 0.88 |
| Dependency License Checker | powershell-strict | sonnet46 | 35 | 59 | 1.7 | 343 | 0 | 0.00 |
| Docker Image Tag Generator | default | opus46 | 20 | 35 | 1.8 | 167 | 129 | 1.29 |
| Docker Image Tag Generator | default | sonnet46 | 22 | 21 | 1.0 | 147 | 101 | 1.46 |
| Docker Image Tag Generator | powershell | opus46 | 21 | 24 | 1.1 | 132 | 90 | 1.47 |
| Docker Image Tag Generator | powershell | sonnet46 | 20 | 22 | 1.1 | 133 | 120 | 1.11 |
| Docker Image Tag Generator | powershell-strict | opus46 | 17 | 23 | 1.4 | 202 | 147 | 1.37 |
| Docker Image Tag Generator | powershell-strict | sonnet46 | 22 | 23 | 1.0 | 167 | 62 | 2.69 |
| Test Results Aggregator | default | opus46 | 28 | 43 | 1.5 | 391 | 227 | 1.72 |
| Test Results Aggregator | default | sonnet46 | 10 | 47 | 4.7 | 301 | 375 | 0.80 |
| Test Results Aggregator | powershell | opus46 | 50 | 63 | 1.3 | 372 | 330 | 1.13 |
| Test Results Aggregator | powershell | sonnet46 | 24 | 44 | 1.8 | 341 | 260 | 1.31 |
| Test Results Aggregator | powershell-strict | opus46 | 35 | 60 | 1.7 | 343 | 0 | 0.00 |
| Test Results Aggregator | powershell-strict | sonnet46 | 67 | 77 | 1.1 | 498 | 0 | 0.00 |
| Environment Matrix Generator | default | opus46 | 37 | 57 | 1.5 | 441 | 215 | 2.05 |
| Environment Matrix Generator | default | sonnet46 | 37 | 40 | 1.1 | 300 | 218 | 1.38 |
| Environment Matrix Generator | powershell | opus46 | 21 | 33 | 1.6 | 293 | 161 | 1.82 |
| Environment Matrix Generator | powershell | sonnet46 | 17 | 24 | 1.4 | 242 | 234 | 1.03 |
| Environment Matrix Generator | powershell-strict | opus46 | 21 | 37 | 1.8 | 303 | 337 | 0.90 |
| Environment Matrix Generator | powershell-strict | sonnet46 | 22 | 63 | 2.9 | 337 | 52 | 6.48 |
| Artifact Cleanup Script | default | opus46 | 17 | 32 | 1.9 | 265 | 269 | 0.99 |
| Artifact Cleanup Script | default | sonnet46 | 19 | 40 | 2.1 | 318 | 239 | 1.33 |
| Artifact Cleanup Script | powershell | opus46 | 23 | 50 | 2.2 | 360 | 277 | 1.30 |
| Artifact Cleanup Script | powershell | sonnet46 | 19 | 39 | 2.1 | 220 | 237 | 0.93 |
| Artifact Cleanup Script | powershell-strict | opus46 | 28 | 73 | 2.6 | 348 | 373 | 0.93 |
| Artifact Cleanup Script | powershell-strict | sonnet46 | 30 | 59 | 2.0 | 313 | 0 | 0.00 |
| Secret Rotation Validator | default | opus46 | 22 | 41 | 1.9 | 268 | 203 | 1.32 |
| Secret Rotation Validator | default | sonnet46 | 20 | 39 | 1.9 | 232 | 157 | 1.48 |
| Secret Rotation Validator | powershell | opus46 | 21 | 35 | 1.7 | 239 | 241 | 0.99 |
| Secret Rotation Validator | powershell | sonnet46 | 32 | 62 | 1.9 | 468 | 250 | 1.87 |
| Secret Rotation Validator | powershell-strict | opus46 | 18 | 49 | 2.7 | 295 | 367 | 0.80 |
| Secret Rotation Validator | powershell-strict | sonnet46 | 25 | 53 | 2.1 | 298 | 0 | 0.00 |

</details>

### LLM-as-Judge Scores

An LLM evaluates each test suite on four dimensions (1-5 scale):

- **Coverage** (1-5): Do tests exercise the key requirements? 1 = most untested, 5 = all covered.
- **Rigor** (1-5): Edge cases, error handling, boundary conditions? 1 = happy path only, 5 = thorough.
- **Design** (1-5): Test organization, fixtures, readability? 1 = messy/brittle, 5 = well-structured.
- **Overall** (1-5): Holistic quality — would you trust this suite to catch regressions? 1 = no, 5 = absolutely. Use this as the primary ranking metric.

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| csharp-script | opus46 | **4.0** | 5.0 | 4.0 | 4.0 | $0.1328 |
| csharp-script | sonnet46 | **4.0** | 5.0 | 3.0 | 4.0 | $0.0662 |
| default | opus46 | **4.2** | 4.9 | 3.9 | 4.4 | $0.8973 |
| default | sonnet46 | **4.2** | 4.6 | 3.5 | 4.5 | $0.7411 |
| powershell | opus46 | **4.1** | 4.8 | 3.7 | 4.2 | $1.0395 |
| powershell | sonnet46 | **3.9** | 4.2 | 3.2 | 4.1 | $0.9164 |
| powershell-strict | opus46 | **3.9** | 4.7 | 3.6 | 3.9 | $1.1270 |
| powershell-strict | sonnet46 | **4.0** | 4.9 | 3.7 | 4.3 | $0.7898 |
| **Total** | | | | | | **$5.7101** |


<details>
<summary>Sorted by avg overall (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| default | opus46 | **4.2** | 4.9 | 3.9 | 4.4 | $0.8973 |
| default | sonnet46 | **4.2** | 4.6 | 3.5 | 4.5 | $0.7411 |
| powershell | opus46 | **4.1** | 4.8 | 3.7 | 4.2 | $1.0395 |
| csharp-script | opus46 | **4.0** | 5.0 | 4.0 | 4.0 | $0.1328 |
| csharp-script | sonnet46 | **4.0** | 5.0 | 3.0 | 4.0 | $0.0662 |
| powershell-strict | sonnet46 | **4.0** | 4.9 | 3.7 | 4.3 | $0.7898 |
| powershell-strict | opus46 | **3.9** | 4.7 | 3.6 | 3.9 | $1.1270 |
| powershell | sonnet46 | **3.9** | 4.2 | 3.2 | 4.1 | $0.9164 |

</details>

<details>
<summary>Sorted by avg coverage (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| csharp-script | opus46 | **4.0** | 5.0 | 4.0 | 4.0 | $0.1328 |
| csharp-script | sonnet46 | **4.0** | 5.0 | 3.0 | 4.0 | $0.0662 |
| powershell-strict | sonnet46 | **4.0** | 4.9 | 3.7 | 4.3 | $0.7898 |
| default | opus46 | **4.2** | 4.9 | 3.9 | 4.4 | $0.8973 |
| powershell | opus46 | **4.1** | 4.8 | 3.7 | 4.2 | $1.0395 |
| powershell-strict | opus46 | **3.9** | 4.7 | 3.6 | 3.9 | $1.1270 |
| default | sonnet46 | **4.2** | 4.6 | 3.5 | 4.5 | $0.7411 |
| powershell | sonnet46 | **3.9** | 4.2 | 3.2 | 4.1 | $0.9164 |

</details>

<details>
<summary>Sorted by avg rigor (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| csharp-script | opus46 | **4.0** | 5.0 | 4.0 | 4.0 | $0.1328 |
| default | opus46 | **4.2** | 4.9 | 3.9 | 4.4 | $0.8973 |
| powershell | opus46 | **4.1** | 4.8 | 3.7 | 4.2 | $1.0395 |
| powershell-strict | sonnet46 | **4.0** | 4.9 | 3.7 | 4.3 | $0.7898 |
| powershell-strict | opus46 | **3.9** | 4.7 | 3.6 | 3.9 | $1.1270 |
| default | sonnet46 | **4.2** | 4.6 | 3.5 | 4.5 | $0.7411 |
| powershell | sonnet46 | **3.9** | 4.2 | 3.2 | 4.1 | $0.9164 |
| csharp-script | sonnet46 | **4.0** | 5.0 | 3.0 | 4.0 | $0.0662 |

</details>

<details>
<summary>Sorted by avg design (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| default | sonnet46 | **4.2** | 4.6 | 3.5 | 4.5 | $0.7411 |
| default | opus46 | **4.2** | 4.9 | 3.9 | 4.4 | $0.8973 |
| powershell-strict | sonnet46 | **4.0** | 4.9 | 3.7 | 4.3 | $0.7898 |
| powershell | opus46 | **4.1** | 4.8 | 3.7 | 4.2 | $1.0395 |
| powershell | sonnet46 | **3.9** | 4.2 | 3.2 | 4.1 | $0.9164 |
| csharp-script | opus46 | **4.0** | 5.0 | 4.0 | 4.0 | $0.1328 |
| csharp-script | sonnet46 | **4.0** | 5.0 | 3.0 | 4.0 | $0.0662 |
| powershell-strict | opus46 | **3.9** | 4.7 | 3.6 | 3.9 | $1.1270 |

</details>


<details>
<summary>Per-run LLM judge scores</summary>

| Task | Language | Model | Cov | Rig | Des | Ovr | Summary |
|------|------|-------|-----|-----|-----|-----|---------|
| CSV Report Generator | csharp-script | opus46 | 5 | 4 | 4 | 4 | The test suite provides thorough coverage of all major requi |
| CSV Report Generator | csharp-script | sonnet46 | 5 | 3 | 4 | 4 | The suite covers all core requirements: CSV string/file pars |
| CSV Report Generator | default | opus46 | 5 | 4 | 5 | 5 | This is a high-quality test suite that thoroughly covers all |
| CSV Report Generator | default | sonnet46 | 5 | 4 | 5 | 4 | The test suite is comprehensive and well-structured, coverin |
| CSV Report Generator | powershell | opus46 | 5 | 3 | 4 | 4 | The test suite covers every public function and all major re |
| CSV Report Generator | powershell | sonnet46 | 4 | 3 | 3 | 3 | The test suite covers all five feature areas (CSV import, ac |
| CSV Report Generator | powershell-strict | opus46 | 4 | 3 | 4 | 4 | The test suite covers the core requirements well: CSV import |
| CSV Report Generator | powershell-strict | sonnet46 | 5 | 3 | 4 | 4 | The suite comprehensively exercises every stated requirement |
| Log File Analyzer | csharp-script | opus46 | 5 | 4 | 4 | 4 | The test suite is comprehensive and maps cleanly onto every  |
| Log File Analyzer | default | opus46 | 5 | 4 | 5 | 5 | This is an excellent test suite that closely mirrors the TDD |
| Log File Analyzer | default | sonnet46 | 5 | 4 | 5 | 5 | The test suite is excellent overall. Coverage is comprehensi |
| Log File Analyzer | powershell | opus46 | 4 | 3 | 4 | 4 | The test suite covers all seven public functions and exercis |
| Log File Analyzer | powershell | sonnet46 | 5 | 3 | 4 | 4 | The suite maps one Describe block to each of the nine implem |
| Log File Analyzer | powershell-strict | opus46 | 4 | 3 | 4 | 4 | The test suite covers all seven functions, including an end- |
| Log File Analyzer | powershell-strict | sonnet46 | 5 | 3 | 4 | 4 | The suite comprehensively covers all stated requirements: sy |
| Directory Tree Sync | default | opus46 | 5 | 4 | 4 | 4 | The suite comprehensively covers all stated requirements acr |
| Directory Tree Sync | default | sonnet46 | 5 | 4 | 5 | 5 | The test suite covers all major requirements: SHA-256 hashin |
| Directory Tree Sync | powershell | opus46 | 5 | 4 | 5 | 4 | The test suite comprehensively covers all six public functio |
| Directory Tree Sync | powershell | sonnet46 | 5 | 4 | 5 | 4 | The suite covers all six required features end-to-end: SHA-2 |
| Directory Tree Sync | powershell-strict | opus46 | 5 | 4 | 4 | 4 | The test suite comprehensively covers all four public functi |
| Directory Tree Sync | powershell-strict | sonnet46 | 5 | 4 | 5 | 4 | The test suite maps directly to every stated requirement: SH |
| REST API Client | default | opus46 | 5 | 5 | 5 | 5 | Exceptional test suite that methodically covers every requir |
| REST API Client | default | sonnet46 | 5 | 4 | 5 | 5 | The test suite achieves excellent coverage across all major  |
| REST API Client | powershell | opus46 | 5 | 4 | 3 | 4 | The suite covers all major requirements well: Get-Posts, Get |
| REST API Client | powershell | sonnet46 | 4 | 3 | 3 | 3 | The test suite systematically mirrors the six TDD cycles and |
| REST API Client | powershell-strict | opus46 | 5 | 4 | 4 | 4 | The test suite comprehensively covers all five stated requir |
| REST API Client | powershell-strict | sonnet46 | 5 | 4 | 5 | 4 | This is a high-quality, well-structured test suite that full |
| Process Monitor | default | opus46 | 4 | 3 | 3 | 3 | The suite covers all five core requirements (parsing, filter |
| Process Monitor | default | sonnet46 | 5 | 3 | 4 | 4 | The suite covers all four core requirements (ProcessInfo mod |
| Process Monitor | powershell | opus46 | 4 | 4 | 4 | 4 | The test suite is solid and purposeful. All five public func |
| Process Monitor | powershell | sonnet46 | 5 | 3 | 4 | 4 | The suite covers all five features end-to-end — data ingesti |
| Process Monitor | powershell-strict | opus46 | 5 | 4 | 4 | 4 | The test suite comprehensively covers all five public functi |
| Process Monitor | powershell-strict | sonnet46 | 5 | 4 | 5 | 4 | The test suite is comprehensive and well-organized, covering |
| Config File Migrator | default | opus46 | 5 | 4 | 5 | 4 | The test suite is comprehensive and well-structured, coverin |
| Config File Migrator | default | sonnet46 | 4 | 4 | 5 | 4 | The test suite is well-structured and covers all core requir |
| Config File Migrator | powershell | opus46 | 4 | 3 | 4 | 4 | The test suite provides solid coverage of all major task req |
| Config File Migrator | powershell | sonnet46 | 4 | 3 | 4 | 4 | The suite maps cleanly to all six stated requirements—INI pa |
| Config File Migrator | powershell-strict | opus46 | 4 | 3 | 4 | 4 | The test suite covers all major requirements well: INI parsi |
| Config File Migrator | powershell-strict | sonnet46 | 5 | 4 | 4 | 4 | The test suite is comprehensive and closely mirrors the task |
| Batch File Renamer | default | opus46 | 5 | 4 | 4 | 4 | The test suite covers all four core requirements thoroughly: |
| Batch File Renamer | default | sonnet46 | 5 | 3 | 4 | 4 | The suite covers all four core requirements — preview mode,  |
| Batch File Renamer | powershell | opus46 | 5 | 4 | 5 | 4 | The test suite is comprehensive and well-structured. All thr |
| Batch File Renamer | powershell | sonnet46 | 3 | 2 | 3 | 3 | The suite covers all four primary requirements (preview, und |
| Batch File Renamer | powershell-strict | opus46 | 4 | 4 | 4 | 4 | The test suite is solid and covers all four primary function |
| Batch File Renamer | powershell-strict | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all four major requirements (preview,  |
| Database Seed Script | default | opus46 | 5 | 4 | 5 | 5 | This is a high-quality test suite that thoroughly covers all |
| Database Seed Script | powershell | opus46 | 5 | 4 | 4 | 4 | The test suite is comprehensive and well-structured, coverin |
| Database Seed Script | powershell-strict | opus46 | 5 | 4 | 4 | 4 | The test suite is impressively comprehensive, covering all m |
| Error Retry Pipeline | default | opus46 | 5 | 3 | 4 | 4 | The test suite covers all five stated requirements (exponent |
| Error Retry Pipeline | powershell | opus46 | 5 | 4 | 4 | 4 | The test suite covers all stated requirements thoroughly: mo |
| Error Retry Pipeline | powershell-strict | opus46 | 5 | 3 | 4 | 4 | The suite covers all stated requirements well: config defaul |
| Multi-file Search and Replace | default | opus46 | 5 | 4 | 4 | 4 | The suite covers all five major feature areas required by th |
| Multi-file Search and Replace | powershell | opus46 | 5 | 4 | 4 | 4 | The test suite comprehensively covers all stated requirement |
| Multi-file Search and Replace | powershell | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all four major requirements well: glob |
| Multi-file Search and Replace | powershell-strict | opus46 | 4 | 3 | 3 | 3 | The test suite covers the majority of stated requirements: r |
| Semantic Version Bumper | default | opus46 | 5 | 4 | 5 | 4 | The test suite is comprehensive and well-structured. All key |
| Semantic Version Bumper | default | sonnet46 | 5 | 4 | 4 | 4 | The test suite is thorough and well-structured, covering all |
| Semantic Version Bumper | powershell | opus46 | 5 | 3 | 4 | 4 | The test suite comprehensively covers all major requirements |
| Semantic Version Bumper | powershell | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all five public functions with both ha |
| Semantic Version Bumper | powershell-strict | opus46 | 5 | 4 | 4 | 4 | The suite comprehensively covers every public function and a |
| Semantic Version Bumper | powershell-strict | sonnet46 | 5 | 4 | 4 | 4 | The test suite covers all five major requirements: version f |
| PR Label Assigner | default | opus46 | 5 | 4 | 4 | 4 | The test suite is well-organized and comprehensively covers  |
| PR Label Assigner | default | sonnet46 | 5 | 4 | 5 | 5 | The test suite is excellent overall. Coverage is comprehensi |
| PR Label Assigner | powershell | opus46 | 5 | 4 | 4 | 4 | The test suite covers all major requirements: glob patterns  |
| PR Label Assigner | powershell | sonnet46 | 5 | 4 | 5 | 4 | The test suite is comprehensive and well-structured. Coverag |
| PR Label Assigner | powershell-strict | opus46 | 4 | 3 | 4 | 4 | The suite covers all stated requirements well: basic glob ma |
| PR Label Assigner | powershell-strict | sonnet46 | 5 | 4 | 5 | 4 | The test suite is impressively comprehensive, covering all s |
| Dependency License Checker | default | opus46 | 5 | 4 | 5 | 5 | This is an exceptionally well-structured test suite that cov |
| Dependency License Checker | powershell | opus46 | 5 | 4 | 5 | 5 | The test suite is comprehensive and well-structured. Coverag |
| Dependency License Checker | powershell | sonnet46 | 5 | 4 | 5 | 5 | The test suite is comprehensive and well-structured, coverin |
| Dependency License Checker | powershell-strict | opus46 | 5 | 3 | 4 | 4 | The test suite covers all core requirements thoroughly: both |
| Dependency License Checker | powershell-strict | sonnet46 | 5 | 4 | 5 | 4 | The test suite is comprehensive and well-structured, coverin |
| Docker Image Tag Generator | default | opus46 | 5 | 4 | 5 | 4 | A well-structured, clearly organized test suite that covers  |
| Docker Image Tag Generator | default | sonnet46 | 5 | 4 | 5 | 4 | The test suite is well-structured and covers all five major  |
| Docker Image Tag Generator | powershell | opus46 | 5 | 4 | 5 | 4 | The test suite is thorough and well-structured, covering all |
| Docker Image Tag Generator | powershell | sonnet46 | 4 | 4 | 5 | 4 | The test suite is well-structured and covers all four primar |
| Docker Image Tag Generator | powershell-strict | opus46 | 5 | 4 | 4 | 4 | The test suite covers all stated requirements: latest for ma |
| Docker Image Tag Generator | powershell-strict | sonnet46 | 5 | 3 | 4 | 4 | The test suite comprehensively covers all four core requirem |
| Test Results Aggregator | default | opus46 | 5 | 3 | 4 | 4 | The test suite covers all major requirements thoroughly: JUn |
| Test Results Aggregator | default | sonnet46 | 4 | 2 | 3 | 3 | The test suite covers all core requirements: JUnit XML parsi |
| Test Results Aggregator | powershell | opus46 | 5 | 3 | 4 | 4 | The suite covers every stated requirement: JUnit parsing, JS |
| Test Results Aggregator | powershell | sonnet46 | 4 | 3 | 4 | 4 | The suite covers all five major functions with dedicated Des |
| Test Results Aggregator | powershell-strict | opus46 | 5 | 3 | 4 | 4 | The test suite covers all stated requirements comprehensivel |
| Test Results Aggregator | powershell-strict | sonnet46 | 5 | 4 | 4 | 4 | The test suite is comprehensive and well-structured, coverin |
| Environment Matrix Generator | default | opus46 | 5 | 4 | 4 | 4 | The test suite comprehensively covers all stated requirement |
| Environment Matrix Generator | default | sonnet46 | 4 | 3 | 5 | 4 | The test suite is well-structured and covers all major requi |
| Environment Matrix Generator | powershell | opus46 | 5 | 4 | 5 | 4 | The test suite thoroughly covers every stated requirement: c |
| Environment Matrix Generator | powershell | sonnet46 | 4 | 3 | 5 | 4 | The test suite covers all seven task requirements (cartesian |
| Environment Matrix Generator | powershell-strict | opus46 | 5 | 4 | 4 | 4 | Comprehensive suite covering all task requirements: cartesia |
| Environment Matrix Generator | powershell-strict | sonnet46 | 5 | 3 | 4 | 4 | The test suite covers all key requirements from the task des |
| Artifact Cleanup Script | default | opus46 | 5 | 4 | 5 | 4 | Strong test suite covering all seven functional requirements |
| Artifact Cleanup Script | default | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all major requirements well: the Artif |
| Artifact Cleanup Script | powershell | opus46 | 5 | 4 | 4 | 4 | The test suite is comprehensive and covers all stated requir |
| Artifact Cleanup Script | powershell | sonnet46 | 4 | 3 | 4 | 4 | The test suite covers all seven public functions and exercis |
| Artifact Cleanup Script | powershell-strict | opus46 | 5 | 4 | 4 | 4 | The test suite covers all major requirements thoroughly: art |
| Artifact Cleanup Script | powershell-strict | sonnet46 | 5 | 4 | 4 | 4 | The test suite comprehensively covers all seven requirements |
| Secret Rotation Validator | default | opus46 | 4 | 4 | 4 | 4 | Solid test suite with good breadth. All major functional req |
| Secret Rotation Validator | default | sonnet46 | 4 | 3 | 4 | 4 | The test suite comprehensively covers the core functional re |
| Secret Rotation Validator | powershell | opus46 | 5 | 4 | 4 | 4 | The test suite covers all key requirements well: status clas |
| Secret Rotation Validator | powershell | sonnet46 | 4 | 4 | 4 | 4 | The test suite is comprehensive and well-structured, coverin |
| Secret Rotation Validator | powershell-strict | opus46 | 5 | 4 | 4 | 4 | The test suite comprehensively covers all task requirements: |
| Secret Rotation Validator | powershell-strict | sonnet46 | 5 | 4 | 4 | 4 | The suite covers all five functional requirements from the t |

</details>

### Correlation: Structural Metrics vs LLM Scores

Spearman rank correlation between automated counts and LLM judge scores.
Values near +1.0 indicate the LLM agrees with the structural signal; near 0 means no relationship.

| Structural Metric | vs Coverage | vs Rigor | vs Design | vs Overall |
|-------------------|------------|---------|----------|-----------|
| Test count | 0.25 | 0.27 | 0.19 | 0.16 |
| Assertion count | 0.15 | 0.11 | 0.05 | 0.15 |
| Test:code ratio | 0.1 | 0.15 | 0.13 | 0.21 |

*Based on 102 runs with both structural and LLM scores.*

### LLM vs Structural Discrepancies

**Probable counter gaps** — structural counters may be missing a test pattern. Investigate and fix `test_quality.py`.

| Task | Language | Model | Tests | Asserts | Cov | Rig | Des | Ovr | Flag |
|------|------|-------|-------|---------|-----|-----|-----|-----|------|
| CSV Report Generator | csharp-script | sonnet46 | 0 | 0 | 5 | 3 | 4 | 4 | LLM says high coverage (5/5) but only 0 tests detected |
| CSV Report Generator | csharp-script | sonnet46 | 0 | 0 | 5 | 3 | 4 | 4 | LLM says high overall (4/5) but 0 tests detected |

**Qualitative disagreements** — structural metrics look reasonable; the LLM judge is weighing factors the counters can't measure.

| Task | Language | Model | Tests | Asserts | Cov | Rig | Des | Ovr | Flag | Justification |
|------|------|-------|-------|---------|-----|-----|-----|-----|------|---------------|
| Test Results Aggregator | default | sonnet46 | 10 | 47 | 4 | 2 | 3 | 3 | LLM says low rigor (2/5) but 47 assertions detected | The test suite covers all core requirements: JUnit XML parsing (including single-testsuite root), JSON parsing, multi-run aggregation, flaky-test detection, markdown generation, file dispatch, and ... |

## Per-Run Results

*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Artifact Cleanup Script | default | opus46 | 4.4min | 34 | 0 | $0.98 | 4.0 | python | ok |
| Artifact Cleanup Script | default | sonnet46 | 2.6min | 17 | 4 | $0.44 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 4.9min | 30 | 0 | $1.16 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 2.6min | 9 | 0 | $0.35 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus46 | 5.5min | 37 | 1 | $1.37 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet46 | 3.6min | 15 | 0 | $0.49 | 4.0 | powershell | ok |
| Batch File Renamer | default | opus46 | 2.8min | 30 | 2 | $0.81 | 4.0 | python | ok |
| Batch File Renamer | default | sonnet46 | 2.3min | 8 | 0 | $0.22 | 4.0 | python | ok |
| Batch File Renamer | powershell | opus46 | 3.0min | 21 | 0 | $0.59 | 4.0 | powershell | ok |
| Batch File Renamer | powershell | sonnet46 | 1.4min | 6 | 0 | $0.16 | 3.0 | powershell | ok |
| Batch File Renamer | powershell-strict | opus46 | 4.5min | 35 | 0 | $1.05 | 4.0 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet46 | 3.7min | 16 | 1 | $0.50 | 4.0 | powershell | ok |
| CSV Report Generator | csharp-script | opus46 | 2.8min | 12 | 0 | $0.58 | 4.0 | csharp | ok |
| CSV Report Generator | csharp-script | sonnet46 | 0.6min | 7 | 0 | $0.12 | 4.0 | csharp | ok |
| CSV Report Generator | default | opus46 | 1.7min | 12 | 0 | $0.38 | 5.0 | python | ok |
| CSV Report Generator | default | sonnet46 | 6.3min | 1 | 3 | $0.71 | 4.0 | python | ok |
| CSV Report Generator | powershell | opus46 | 4.3min | 37 | 0 | $1.05 | 4.0 | powershell | ok |
| CSV Report Generator | powershell | sonnet46 | 2.1min | 9 | 0 | $0.31 | 3.0 | powershell | ok |
| CSV Report Generator | powershell-strict | opus46 | 4.3min | 40 | 1 | $1.04 | 4.0 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet46 | 6.5min | 29 | 0 | $0.97 | 4.0 | powershell | ok |
| Config File Migrator | default | opus46 | 2.8min | 14 | 1 | $0.59 | 4.0 | python | ok |
| Config File Migrator | default | sonnet46 | 3.4min | 18 | 1 | $0.47 | 4.0 | python | ok |
| Config File Migrator | powershell | opus46 | 3.7min | 20 | 0 | $0.69 | 4.0 | powershell | ok |
| Config File Migrator | powershell | sonnet46 | 3.4min | 15 | 0 | $0.38 | 4.0 | powershell | ok |
| Config File Migrator | powershell-strict | opus46 | 2.7min | 12 | 0 | $0.49 | 4.0 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet46 | 13.9min | 21 | 0 | $1.60 | 4.0 | powershell | ok |
| Database Seed Script | default | opus46 | 4.3min | 36 | 1 | $1.04 | 5.0 | python | ok |
| Database Seed Script | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Database Seed Script | powershell | opus46 | 5.8min | 42 | 4 | $1.32 | 4.0 | powershell | ok |
| Database Seed Script | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Database Seed Script | powershell-strict | opus46 | 8.7min | 56 | 2 | $2.03 | 4.0 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet46 | 3.6min | 1 | 0 | $0.00 | — | powershell | failed |
| Dependency License Checker | default | opus46 | 5.6min | 64 | 4 | $1.73 | 5.0 | python | ok |
| Dependency License Checker | default | sonnet46 | 4.0min | 1 | 0 | $0.00 | — |  | failed |
| Dependency License Checker | powershell | opus46 | 5.8min | 45 | 1 | $1.37 | 5.0 | powershell | ok |
| Dependency License Checker | powershell | sonnet46 | 2.6min | 11 | 0 | $0.36 | 5.0 | powershell | ok |
| Dependency License Checker | powershell-strict | opus46 | 5.4min | 52 | 4 | $1.59 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet46 | 9.5min | 18 | 0 | $0.97 | 4.0 | powershell | ok |
| Directory Tree Sync | default | opus46 | 3.8min | 43 | 0 | $1.18 | 4.0 | python | ok |
| Directory Tree Sync | default | sonnet46 | 3.9min | 11 | 1 | $0.45 | 5.0 | python | ok |
| Directory Tree Sync | powershell | opus46 | 5.3min | 42 | 0 | $1.13 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell | sonnet46 | 3.0min | 11 | 0 | $0.37 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus46 | 5.4min | 34 | 0 | $1.21 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet46 | 4.3min | 13 | 0 | $0.49 | 4.0 | powershell | ok |
| Docker Image Tag Generator | default | opus46 | 2.7min | 30 | 0 | $0.67 | 4.0 | python | ok |
| Docker Image Tag Generator | default | sonnet46 | 1.8min | 10 | 1 | $0.23 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 3.5min | 32 | 0 | $0.84 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 2.9min | 9 | 0 | $0.31 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus46 | 5.0min | 44 | 0 | $1.28 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet46 | 2.5min | 13 | 0 | $0.33 | 4.0 | powershell | ok |
| Environment Matrix Generator | default | opus46 | 4.7min | 38 | 1 | $1.11 | 4.0 | python | ok |
| Environment Matrix Generator | default | sonnet46 | 2.0min | 9 | 0 | $0.26 | 4.0 | python | ok |
| Environment Matrix Generator | powershell | opus46 | 2.3min | 18 | 0 | $0.54 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46 | 2.8min | 13 | 0 | $0.36 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus46 | 4.2min | 31 | 2 | $0.96 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet46 | 5.4min | 16 | 0 | $0.62 | 4.0 | powershell | ok |
| Error Retry Pipeline | default | opus46 | 2.3min | 24 | 0 | $0.54 | 4.0 | python | ok |
| Error Retry Pipeline | default | sonnet46 | 3.7min | 1 | 0 | $0.00 | — |  | failed |
| Error Retry Pipeline | powershell | opus46 | 3.8min | 34 | 0 | $0.93 | 4.0 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Error Retry Pipeline | powershell-strict | opus46 | 9.7min | 0 | 1 | $0.00 | 4.0 | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Log File Analyzer | csharp-script | opus46 | 0.7min | 9 | 0 | $0.25 | 4.0 | csharp | ok |
| Log File Analyzer | default | opus46 | 4.2min | 43 | 0 | $1.18 | 5.0 | python | ok |
| Log File Analyzer | default | sonnet46 | 2.9min | 19 | 0 | $0.48 | 5.0 | python | ok |
| Log File Analyzer | powershell | opus46 | 4.6min | 41 | 0 | $1.14 | 4.0 | powershell | ok |
| Log File Analyzer | powershell | sonnet46 | 3.9min | 10 | 0 | $0.44 | 4.0 | powershell | ok |
| Log File Analyzer | powershell-strict | opus46 | 4.5min | 31 | 1 | $0.95 | 4.0 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet46 | 3.8min | 14 | 1 | $0.50 | 4.0 | powershell | ok |
| Multi-file Search and Replace | default | opus46 | 3.1min | 25 | 3 | $0.70 | 4.0 | python | ok |
| Multi-file Search and Replace | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Multi-file Search and Replace | powershell | opus46 | 3.6min | 21 | 0 | $0.65 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet46 | 1.4min | 10 | 0 | $0.19 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus46 | 4.1min | 34 | 0 | $1.09 | 3.0 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| PR Label Assigner | default | opus46 | 1.9min | 11 | 1 | $0.38 | 4.0 | python | ok |
| PR Label Assigner | default | sonnet46 | 1.8min | 8 | 0 | $0.21 | 5.0 | python | ok |
| PR Label Assigner | powershell | opus46 | 3.1min | 23 | 0 | $0.61 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 3.7min | 10 | 0 | $0.38 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-strict | opus46 | 4.0min | 37 | 0 | $1.03 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet46 | 3.3min | 12 | 0 | $0.35 | 4.0 | powershell | ok |
| Process Monitor | default | opus46 | 3.3min | 40 | 1 | $1.00 | 3.0 | python | ok |
| Process Monitor | default | sonnet46 | 2.0min | 12 | 0 | $0.25 | 4.0 | python | ok |
| Process Monitor | powershell | opus46 | 5.4min | 39 | 0 | $1.21 | 4.0 | powershell | ok |
| Process Monitor | powershell | sonnet46 | 3.8min | 13 | 0 | $0.40 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | opus46 | 5.6min | 53 | 0 | $1.61 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | sonnet46 | 4.6min | 19 | 0 | $0.54 | 4.0 | powershell | ok |
| REST API Client | default | opus46 | 5.2min | 45 | 0 | $1.21 | 5.0 | python | ok |
| REST API Client | default | sonnet46 | 1.8min | 9 | 1 | $0.23 | 5.0 | python | ok |
| REST API Client | powershell | opus46 | 7.2min | 51 | 1 | $1.82 | 4.0 | powershell | ok |
| REST API Client | powershell | sonnet46 | 12.6min | 13 | 0 | $0.96 | 3.0 | powershell | ok |
| REST API Client | powershell-strict | opus46 | 5.1min | 19 | 0 | $0.94 | 4.0 | powershell | ok |
| REST API Client | powershell-strict | sonnet46 | 9.2min | 14 | 0 | $0.99 | 4.0 | powershell | ok |
| Secret Rotation Validator | default | opus46 | 2.6min | 17 | 0 | $0.51 | 4.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 1.5min | 11 | 0 | $0.22 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | opus46 | 3.3min | 23 | 1 | $0.72 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46 | 3.5min | 11 | 0 | $0.48 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus46 | 5.3min | 39 | 2 | $1.27 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet46 | 4.0min | 20 | 0 | $0.53 | 4.0 | powershell | ok |
| Semantic Version Bumper | default | opus46 | 4.8min | 47 | 5 | $1.23 | 4.0 | python | ok |
| Semantic Version Bumper | default | sonnet46 | 2.5min | 11 | 0 | $0.25 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | opus46 | 3.6min | 27 | 0 | $0.77 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46 | 2.7min | 16 | 0 | $0.33 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus46 | 5.8min | 52 | 0 | $1.57 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet46 | 5.3min | 5 | 0 | $0.15 | 4.0 | powershell | failed |
| Test Results Aggregator | default | opus46 | 2.3min | 15 | 1 | $0.51 | 4.0 | python | ok |
| Test Results Aggregator | default | sonnet46 | 4.0min | 20 | 1 | $0.49 | 3.0 | python | ok |
| Test Results Aggregator | powershell | opus46 | 4.3min | 33 | 0 | $0.95 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | sonnet46 | 5.0min | 15 | 0 | $0.55 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus46 | 4.0min | 24 | 0 | $0.95 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet46 | 11.5min | 20 | 0 | $1.42 | 4.0 | powershell | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Database Seed Script | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Database Seed Script | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Database Seed Script | powershell-strict | sonnet46 | 3.6min | 1 | 0 | $0.00 | — | powershell | failed |
| Error Retry Pipeline | default | sonnet46 | 3.7min | 1 | 0 | $0.00 | — |  | failed |
| Error Retry Pipeline | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Error Retry Pipeline | powershell-strict | opus46 | 9.7min | 0 | 1 | $0.00 | 4.0 | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Multi-file Search and Replace | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Multi-file Search and Replace | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Dependency License Checker | default | sonnet46 | 4.0min | 1 | 0 | $0.00 | — |  | failed |
| CSV Report Generator | csharp-script | sonnet46 | 0.6min | 7 | 0 | $0.12 | 4.0 | csharp | ok |
| Semantic Version Bumper | powershell-strict | sonnet46 | 5.3min | 5 | 0 | $0.15 | 4.0 | powershell | failed |
| Batch File Renamer | powershell | sonnet46 | 1.4min | 6 | 0 | $0.16 | 3.0 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet46 | 1.4min | 10 | 0 | $0.19 | 4.0 | powershell | ok |
| PR Label Assigner | default | sonnet46 | 1.8min | 8 | 0 | $0.21 | 5.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 1.5min | 11 | 0 | $0.22 | 4.0 | python | ok |
| Batch File Renamer | default | sonnet46 | 2.3min | 8 | 0 | $0.22 | 4.0 | python | ok |
| REST API Client | default | sonnet46 | 1.8min | 9 | 1 | $0.23 | 5.0 | python | ok |
| Docker Image Tag Generator | default | sonnet46 | 1.8min | 10 | 1 | $0.23 | 4.0 | python | ok |
| Semantic Version Bumper | default | sonnet46 | 2.5min | 11 | 0 | $0.25 | 4.0 | python | ok |
| Process Monitor | default | sonnet46 | 2.0min | 12 | 0 | $0.25 | 4.0 | python | ok |
| Log File Analyzer | csharp-script | opus46 | 0.7min | 9 | 0 | $0.25 | 4.0 | csharp | ok |
| Environment Matrix Generator | default | sonnet46 | 2.0min | 9 | 0 | $0.26 | 4.0 | python | ok |
| CSV Report Generator | powershell | sonnet46 | 2.1min | 9 | 0 | $0.31 | 3.0 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 2.9min | 9 | 0 | $0.31 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46 | 2.7min | 16 | 0 | $0.33 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet46 | 2.5min | 13 | 0 | $0.33 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 2.6min | 9 | 0 | $0.35 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet46 | 3.3min | 12 | 0 | $0.35 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46 | 2.8min | 13 | 0 | $0.36 | 4.0 | powershell | ok |
| Dependency License Checker | powershell | sonnet46 | 2.6min | 11 | 0 | $0.36 | 5.0 | powershell | ok |
| Directory Tree Sync | powershell | sonnet46 | 3.0min | 11 | 0 | $0.37 | 4.0 | powershell | ok |
| PR Label Assigner | default | opus46 | 1.9min | 11 | 1 | $0.38 | 4.0 | python | ok |
| CSV Report Generator | default | opus46 | 1.7min | 12 | 0 | $0.38 | 5.0 | python | ok |
| Config File Migrator | powershell | sonnet46 | 3.4min | 15 | 0 | $0.38 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 3.7min | 10 | 0 | $0.38 | 4.0 | powershell | ok |
| Process Monitor | powershell | sonnet46 | 3.8min | 13 | 0 | $0.40 | 4.0 | powershell | ok |
| Artifact Cleanup Script | default | sonnet46 | 2.6min | 17 | 4 | $0.44 | 4.0 | python | ok |
| Log File Analyzer | powershell | sonnet46 | 3.9min | 10 | 0 | $0.44 | 4.0 | powershell | ok |
| Directory Tree Sync | default | sonnet46 | 3.9min | 11 | 1 | $0.45 | 5.0 | python | ok |
| Config File Migrator | default | sonnet46 | 3.4min | 18 | 1 | $0.47 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | sonnet46 | 3.5min | 11 | 0 | $0.48 | 4.0 | powershell | ok |
| Log File Analyzer | default | sonnet46 | 2.9min | 19 | 0 | $0.48 | 5.0 | python | ok |
| Artifact Cleanup Script | powershell-strict | sonnet46 | 3.6min | 15 | 0 | $0.49 | 4.0 | powershell | ok |
| Config File Migrator | powershell-strict | opus46 | 2.7min | 12 | 0 | $0.49 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet46 | 4.3min | 13 | 0 | $0.49 | 4.0 | powershell | ok |
| Test Results Aggregator | default | sonnet46 | 4.0min | 20 | 1 | $0.49 | 3.0 | python | ok |
| Batch File Renamer | powershell-strict | sonnet46 | 3.7min | 16 | 1 | $0.50 | 4.0 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet46 | 3.8min | 14 | 1 | $0.50 | 4.0 | powershell | ok |
| Test Results Aggregator | default | opus46 | 2.3min | 15 | 1 | $0.51 | 4.0 | python | ok |
| Secret Rotation Validator | default | opus46 | 2.6min | 17 | 0 | $0.51 | 4.0 | python | ok |
| Secret Rotation Validator | powershell-strict | sonnet46 | 4.0min | 20 | 0 | $0.53 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | sonnet46 | 4.6min | 19 | 0 | $0.54 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | opus46 | 2.3min | 18 | 0 | $0.54 | 4.0 | powershell | ok |
| Error Retry Pipeline | default | opus46 | 2.3min | 24 | 0 | $0.54 | 4.0 | python | ok |
| Test Results Aggregator | powershell | sonnet46 | 5.0min | 15 | 0 | $0.55 | 4.0 | powershell | ok |
| CSV Report Generator | csharp-script | opus46 | 2.8min | 12 | 0 | $0.58 | 4.0 | csharp | ok |
| Config File Migrator | default | opus46 | 2.8min | 14 | 1 | $0.59 | 4.0 | python | ok |
| Batch File Renamer | powershell | opus46 | 3.0min | 21 | 0 | $0.59 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | opus46 | 3.1min | 23 | 0 | $0.61 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet46 | 5.4min | 16 | 0 | $0.62 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell | opus46 | 3.6min | 21 | 0 | $0.65 | 4.0 | powershell | ok |
| Docker Image Tag Generator | default | opus46 | 2.7min | 30 | 0 | $0.67 | 4.0 | python | ok |
| Config File Migrator | powershell | opus46 | 3.7min | 20 | 0 | $0.69 | 4.0 | powershell | ok |
| Multi-file Search and Replace | default | opus46 | 3.1min | 25 | 3 | $0.70 | 4.0 | python | ok |
| CSV Report Generator | default | sonnet46 | 6.3min | 1 | 3 | $0.71 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | opus46 | 3.3min | 23 | 1 | $0.72 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | opus46 | 3.6min | 27 | 0 | $0.77 | 4.0 | powershell | ok |
| Batch File Renamer | default | opus46 | 2.8min | 30 | 2 | $0.81 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 3.5min | 32 | 0 | $0.84 | 4.0 | powershell | ok |
| Error Retry Pipeline | powershell | opus46 | 3.8min | 34 | 0 | $0.93 | 4.0 | powershell | ok |
| REST API Client | powershell-strict | opus46 | 5.1min | 19 | 0 | $0.94 | 4.0 | powershell | ok |
| Log File Analyzer | powershell-strict | opus46 | 4.5min | 31 | 1 | $0.95 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus46 | 4.0min | 24 | 0 | $0.95 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | opus46 | 4.3min | 33 | 0 | $0.95 | 4.0 | powershell | ok |
| REST API Client | powershell | sonnet46 | 12.6min | 13 | 0 | $0.96 | 3.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus46 | 4.2min | 31 | 2 | $0.96 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet46 | 9.5min | 18 | 0 | $0.97 | 4.0 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet46 | 6.5min | 29 | 0 | $0.97 | 4.0 | powershell | ok |
| Artifact Cleanup Script | default | opus46 | 4.4min | 34 | 0 | $0.98 | 4.0 | python | ok |
| REST API Client | powershell-strict | sonnet46 | 9.2min | 14 | 0 | $0.99 | 4.0 | powershell | ok |
| Process Monitor | default | opus46 | 3.3min | 40 | 1 | $1.00 | 3.0 | python | ok |
| PR Label Assigner | powershell-strict | opus46 | 4.0min | 37 | 0 | $1.03 | 4.0 | powershell | ok |
| Database Seed Script | default | opus46 | 4.3min | 36 | 1 | $1.04 | 5.0 | python | ok |
| CSV Report Generator | powershell-strict | opus46 | 4.3min | 40 | 1 | $1.04 | 4.0 | powershell | ok |
| CSV Report Generator | powershell | opus46 | 4.3min | 37 | 0 | $1.05 | 4.0 | powershell | ok |
| Batch File Renamer | powershell-strict | opus46 | 4.5min | 35 | 0 | $1.05 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus46 | 4.1min | 34 | 0 | $1.09 | 3.0 | powershell | ok |
| Environment Matrix Generator | default | opus46 | 4.7min | 38 | 1 | $1.11 | 4.0 | python | ok |
| Directory Tree Sync | powershell | opus46 | 5.3min | 42 | 0 | $1.13 | 4.0 | powershell | ok |
| Log File Analyzer | powershell | opus46 | 4.6min | 41 | 0 | $1.14 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell | opus46 | 4.9min | 30 | 0 | $1.16 | 4.0 | powershell | ok |
| Directory Tree Sync | default | opus46 | 3.8min | 43 | 0 | $1.18 | 4.0 | python | ok |
| Log File Analyzer | default | opus46 | 4.2min | 43 | 0 | $1.18 | 5.0 | python | ok |
| Process Monitor | powershell | opus46 | 5.4min | 39 | 0 | $1.21 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus46 | 5.4min | 34 | 0 | $1.21 | 4.0 | powershell | ok |
| REST API Client | default | opus46 | 5.2min | 45 | 0 | $1.21 | 5.0 | python | ok |
| Semantic Version Bumper | default | opus46 | 4.8min | 47 | 5 | $1.23 | 4.0 | python | ok |
| Secret Rotation Validator | powershell-strict | opus46 | 5.3min | 39 | 2 | $1.27 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus46 | 5.0min | 44 | 0 | $1.28 | 4.0 | powershell | ok |
| Database Seed Script | powershell | opus46 | 5.8min | 42 | 4 | $1.32 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus46 | 5.5min | 37 | 1 | $1.37 | 4.0 | powershell | ok |
| Dependency License Checker | powershell | opus46 | 5.8min | 45 | 1 | $1.37 | 5.0 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet46 | 11.5min | 20 | 0 | $1.42 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus46 | 5.8min | 52 | 0 | $1.57 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-strict | opus46 | 5.4min | 52 | 4 | $1.59 | 4.0 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet46 | 13.9min | 21 | 0 | $1.60 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | opus46 | 5.6min | 53 | 0 | $1.61 | 4.0 | powershell | ok |
| Dependency License Checker | default | opus46 | 5.6min | 64 | 4 | $1.73 | 5.0 | python | ok |
| REST API Client | powershell | opus46 | 7.2min | 51 | 1 | $1.82 | 4.0 | powershell | ok |
| Database Seed Script | powershell-strict | opus46 | 8.7min | 56 | 2 | $2.03 | 4.0 | powershell | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| CSV Report Generator | csharp-script | sonnet46 | 0.6min | 7 | 0 | $0.12 | 4.0 | csharp | ok |
| Log File Analyzer | csharp-script | opus46 | 0.7min | 9 | 0 | $0.25 | 4.0 | csharp | ok |
| Batch File Renamer | powershell | sonnet46 | 1.4min | 6 | 0 | $0.16 | 3.0 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet46 | 1.4min | 10 | 0 | $0.19 | 4.0 | powershell | ok |
| Secret Rotation Validator | default | sonnet46 | 1.5min | 11 | 0 | $0.22 | 4.0 | python | ok |
| CSV Report Generator | default | opus46 | 1.7min | 12 | 0 | $0.38 | 5.0 | python | ok |
| PR Label Assigner | default | sonnet46 | 1.8min | 8 | 0 | $0.21 | 5.0 | python | ok |
| Docker Image Tag Generator | default | sonnet46 | 1.8min | 10 | 1 | $0.23 | 4.0 | python | ok |
| REST API Client | default | sonnet46 | 1.8min | 9 | 1 | $0.23 | 5.0 | python | ok |
| PR Label Assigner | default | opus46 | 1.9min | 11 | 1 | $0.38 | 4.0 | python | ok |
| Process Monitor | default | sonnet46 | 2.0min | 12 | 0 | $0.25 | 4.0 | python | ok |
| Environment Matrix Generator | default | sonnet46 | 2.0min | 9 | 0 | $0.26 | 4.0 | python | ok |
| CSV Report Generator | powershell | sonnet46 | 2.1min | 9 | 0 | $0.31 | 3.0 | powershell | ok |
| Batch File Renamer | default | sonnet46 | 2.3min | 8 | 0 | $0.22 | 4.0 | python | ok |
| Test Results Aggregator | default | opus46 | 2.3min | 15 | 1 | $0.51 | 4.0 | python | ok |
| Error Retry Pipeline | default | opus46 | 2.3min | 24 | 0 | $0.54 | 4.0 | python | ok |
| Environment Matrix Generator | powershell | opus46 | 2.3min | 18 | 0 | $0.54 | 4.0 | powershell | ok |
| Semantic Version Bumper | default | sonnet46 | 2.5min | 11 | 0 | $0.25 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell-strict | sonnet46 | 2.5min | 13 | 0 | $0.33 | 4.0 | powershell | ok |
| Dependency License Checker | powershell | sonnet46 | 2.6min | 11 | 0 | $0.36 | 5.0 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 2.6min | 9 | 0 | $0.35 | 4.0 | powershell | ok |
| Artifact Cleanup Script | default | sonnet46 | 2.6min | 17 | 4 | $0.44 | 4.0 | python | ok |
| Secret Rotation Validator | default | opus46 | 2.6min | 17 | 0 | $0.51 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | sonnet46 | 2.7min | 16 | 0 | $0.33 | 4.0 | powershell | ok |
| Docker Image Tag Generator | default | opus46 | 2.7min | 30 | 0 | $0.67 | 4.0 | python | ok |
| Config File Migrator | powershell-strict | opus46 | 2.7min | 12 | 0 | $0.49 | 4.0 | powershell | ok |
| Config File Migrator | default | opus46 | 2.8min | 14 | 1 | $0.59 | 4.0 | python | ok |
| Batch File Renamer | default | opus46 | 2.8min | 30 | 2 | $0.81 | 4.0 | python | ok |
| Environment Matrix Generator | powershell | sonnet46 | 2.8min | 13 | 0 | $0.36 | 4.0 | powershell | ok |
| CSV Report Generator | csharp-script | opus46 | 2.8min | 12 | 0 | $0.58 | 4.0 | csharp | ok |
| Log File Analyzer | default | sonnet46 | 2.9min | 19 | 0 | $0.48 | 5.0 | python | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 2.9min | 9 | 0 | $0.31 | 4.0 | powershell | ok |
| Batch File Renamer | powershell | opus46 | 3.0min | 21 | 0 | $0.59 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell | sonnet46 | 3.0min | 11 | 0 | $0.37 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | opus46 | 3.1min | 23 | 0 | $0.61 | 4.0 | powershell | ok |
| Multi-file Search and Replace | default | opus46 | 3.1min | 25 | 3 | $0.70 | 4.0 | python | ok |
| PR Label Assigner | powershell-strict | sonnet46 | 3.3min | 12 | 0 | $0.35 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell | opus46 | 3.3min | 23 | 1 | $0.72 | 4.0 | powershell | ok |
| Process Monitor | default | opus46 | 3.3min | 40 | 1 | $1.00 | 3.0 | python | ok |
| Config File Migrator | default | sonnet46 | 3.4min | 18 | 1 | $0.47 | 4.0 | python | ok |
| Config File Migrator | powershell | sonnet46 | 3.4min | 15 | 0 | $0.38 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell | opus46 | 3.5min | 32 | 0 | $0.84 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46 | 3.5min | 11 | 0 | $0.48 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | opus46 | 3.6min | 27 | 0 | $0.77 | 4.0 | powershell | ok |
| Database Seed Script | powershell-strict | sonnet46 | 3.6min | 1 | 0 | $0.00 | — | powershell | failed |
| Artifact Cleanup Script | powershell-strict | sonnet46 | 3.6min | 15 | 0 | $0.49 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell | opus46 | 3.6min | 21 | 0 | $0.65 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 3.7min | 10 | 0 | $0.38 | 4.0 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet46 | 3.7min | 16 | 1 | $0.50 | 4.0 | powershell | ok |
| Error Retry Pipeline | default | sonnet46 | 3.7min | 1 | 0 | $0.00 | — |  | failed |
| Config File Migrator | powershell | opus46 | 3.7min | 20 | 0 | $0.69 | 4.0 | powershell | ok |
| Database Seed Script | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Process Monitor | powershell | sonnet46 | 3.8min | 13 | 0 | $0.40 | 4.0 | powershell | ok |
| Directory Tree Sync | default | opus46 | 3.8min | 43 | 0 | $1.18 | 4.0 | python | ok |
| Multi-file Search and Replace | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Log File Analyzer | powershell-strict | sonnet46 | 3.8min | 14 | 1 | $0.50 | 4.0 | powershell | ok |
| Error Retry Pipeline | powershell | opus46 | 3.8min | 34 | 0 | $0.93 | 4.0 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Database Seed Script | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Log File Analyzer | powershell | sonnet46 | 3.9min | 10 | 0 | $0.44 | 4.0 | powershell | ok |
| Multi-file Search and Replace | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Directory Tree Sync | default | sonnet46 | 3.9min | 11 | 1 | $0.45 | 5.0 | python | ok |
| Test Results Aggregator | powershell-strict | opus46 | 4.0min | 24 | 0 | $0.95 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet46 | 4.0min | 20 | 0 | $0.53 | 4.0 | powershell | ok |
| Dependency License Checker | default | sonnet46 | 4.0min | 1 | 0 | $0.00 | — |  | failed |
| Test Results Aggregator | default | sonnet46 | 4.0min | 20 | 1 | $0.49 | 3.0 | python | ok |
| PR Label Assigner | powershell-strict | opus46 | 4.0min | 37 | 0 | $1.03 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus46 | 4.1min | 34 | 0 | $1.09 | 3.0 | powershell | ok |
| Log File Analyzer | default | opus46 | 4.2min | 43 | 0 | $1.18 | 5.0 | python | ok |
| Environment Matrix Generator | powershell-strict | opus46 | 4.2min | 31 | 2 | $0.96 | 4.0 | powershell | ok |
| CSV Report Generator | powershell | opus46 | 4.3min | 37 | 0 | $1.05 | 4.0 | powershell | ok |
| CSV Report Generator | powershell-strict | opus46 | 4.3min | 40 | 1 | $1.04 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | opus46 | 4.3min | 33 | 0 | $0.95 | 4.0 | powershell | ok |
| Database Seed Script | default | opus46 | 4.3min | 36 | 1 | $1.04 | 5.0 | python | ok |
| Directory Tree Sync | powershell-strict | sonnet46 | 4.3min | 13 | 0 | $0.49 | 4.0 | powershell | ok |
| Artifact Cleanup Script | default | opus46 | 4.4min | 34 | 0 | $0.98 | 4.0 | python | ok |
| Log File Analyzer | powershell-strict | opus46 | 4.5min | 31 | 1 | $0.95 | 4.0 | powershell | ok |
| Batch File Renamer | powershell-strict | opus46 | 4.5min | 35 | 0 | $1.05 | 4.0 | powershell | ok |
| Log File Analyzer | powershell | opus46 | 4.6min | 41 | 0 | $1.14 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | sonnet46 | 4.6min | 19 | 0 | $0.54 | 4.0 | powershell | ok |
| Environment Matrix Generator | default | opus46 | 4.7min | 38 | 1 | $1.11 | 4.0 | python | ok |
| Semantic Version Bumper | default | opus46 | 4.8min | 47 | 5 | $1.23 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 4.9min | 30 | 0 | $1.16 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | sonnet46 | 5.0min | 15 | 0 | $0.55 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus46 | 5.0min | 44 | 0 | $1.28 | 4.0 | powershell | ok |
| REST API Client | powershell-strict | opus46 | 5.1min | 19 | 0 | $0.94 | 4.0 | powershell | ok |
| REST API Client | default | opus46 | 5.2min | 45 | 0 | $1.21 | 5.0 | python | ok |
| Semantic Version Bumper | powershell-strict | sonnet46 | 5.3min | 5 | 0 | $0.15 | 4.0 | powershell | failed |
| Secret Rotation Validator | powershell-strict | opus46 | 5.3min | 39 | 2 | $1.27 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell | opus46 | 5.3min | 42 | 0 | $1.13 | 4.0 | powershell | ok |
| Process Monitor | powershell | opus46 | 5.4min | 39 | 0 | $1.21 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus46 | 5.4min | 34 | 0 | $1.21 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet46 | 5.4min | 16 | 0 | $0.62 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-strict | opus46 | 5.4min | 52 | 4 | $1.59 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus46 | 5.5min | 37 | 1 | $1.37 | 4.0 | powershell | ok |
| Dependency License Checker | default | opus46 | 5.6min | 64 | 4 | $1.73 | 5.0 | python | ok |
| Process Monitor | powershell-strict | opus46 | 5.6min | 53 | 0 | $1.61 | 4.0 | powershell | ok |
| Dependency License Checker | powershell | opus46 | 5.8min | 45 | 1 | $1.37 | 5.0 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus46 | 5.8min | 52 | 0 | $1.57 | 4.0 | powershell | ok |
| Database Seed Script | powershell | opus46 | 5.8min | 42 | 4 | $1.32 | 4.0 | powershell | ok |
| CSV Report Generator | default | sonnet46 | 6.3min | 1 | 3 | $0.71 | 4.0 | python | ok |
| CSV Report Generator | powershell-strict | sonnet46 | 6.5min | 29 | 0 | $0.97 | 4.0 | powershell | ok |
| REST API Client | powershell | opus46 | 7.2min | 51 | 1 | $1.82 | 4.0 | powershell | ok |
| Database Seed Script | powershell-strict | opus46 | 8.7min | 56 | 2 | $2.03 | 4.0 | powershell | ok |
| REST API Client | powershell-strict | sonnet46 | 9.2min | 14 | 0 | $0.99 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet46 | 9.5min | 18 | 0 | $0.97 | 4.0 | powershell | ok |
| Error Retry Pipeline | powershell-strict | opus46 | 9.7min | 0 | 1 | $0.00 | 4.0 | powershell | failed |
| Test Results Aggregator | powershell-strict | sonnet46 | 11.5min | 20 | 0 | $1.42 | 4.0 | powershell | ok |
| REST API Client | powershell | sonnet46 | 12.6min | 13 | 0 | $0.96 | 3.0 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet46 | 13.9min | 21 | 0 | $1.60 | 4.0 | powershell | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| CSV Report Generator | csharp-script | opus46 | 2.8min | 12 | 0 | $0.58 | 4.0 | csharp | ok |
| CSV Report Generator | csharp-script | sonnet46 | 0.6min | 7 | 0 | $0.12 | 4.0 | csharp | ok |
| CSV Report Generator | default | opus46 | 1.7min | 12 | 0 | $0.38 | 5.0 | python | ok |
| CSV Report Generator | powershell | opus46 | 4.3min | 37 | 0 | $1.05 | 4.0 | powershell | ok |
| CSV Report Generator | powershell | sonnet46 | 2.1min | 9 | 0 | $0.31 | 3.0 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet46 | 6.5min | 29 | 0 | $0.97 | 4.0 | powershell | ok |
| Log File Analyzer | csharp-script | opus46 | 0.7min | 9 | 0 | $0.25 | 4.0 | csharp | ok |
| Log File Analyzer | default | opus46 | 4.2min | 43 | 0 | $1.18 | 5.0 | python | ok |
| Log File Analyzer | default | sonnet46 | 2.9min | 19 | 0 | $0.48 | 5.0 | python | ok |
| Log File Analyzer | powershell | opus46 | 4.6min | 41 | 0 | $1.14 | 4.0 | powershell | ok |
| Log File Analyzer | powershell | sonnet46 | 3.9min | 10 | 0 | $0.44 | 4.0 | powershell | ok |
| Directory Tree Sync | default | opus46 | 3.8min | 43 | 0 | $1.18 | 4.0 | python | ok |
| Directory Tree Sync | powershell | opus46 | 5.3min | 42 | 0 | $1.13 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell | sonnet46 | 3.0min | 11 | 0 | $0.37 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus46 | 5.4min | 34 | 0 | $1.21 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet46 | 4.3min | 13 | 0 | $0.49 | 4.0 | powershell | ok |
| REST API Client | default | opus46 | 5.2min | 45 | 0 | $1.21 | 5.0 | python | ok |
| REST API Client | powershell | sonnet46 | 12.6min | 13 | 0 | $0.96 | 3.0 | powershell | ok |
| REST API Client | powershell-strict | opus46 | 5.1min | 19 | 0 | $0.94 | 4.0 | powershell | ok |
| REST API Client | powershell-strict | sonnet46 | 9.2min | 14 | 0 | $0.99 | 4.0 | powershell | ok |
| Process Monitor | default | sonnet46 | 2.0min | 12 | 0 | $0.25 | 4.0 | python | ok |
| Process Monitor | powershell | opus46 | 5.4min | 39 | 0 | $1.21 | 4.0 | powershell | ok |
| Process Monitor | powershell | sonnet46 | 3.8min | 13 | 0 | $0.40 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | opus46 | 5.6min | 53 | 0 | $1.61 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | sonnet46 | 4.6min | 19 | 0 | $0.54 | 4.0 | powershell | ok |
| Config File Migrator | powershell | opus46 | 3.7min | 20 | 0 | $0.69 | 4.0 | powershell | ok |
| Config File Migrator | powershell | sonnet46 | 3.4min | 15 | 0 | $0.38 | 4.0 | powershell | ok |
| Config File Migrator | powershell-strict | opus46 | 2.7min | 12 | 0 | $0.49 | 4.0 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet46 | 13.9min | 21 | 0 | $1.60 | 4.0 | powershell | ok |
| Batch File Renamer | default | sonnet46 | 2.3min | 8 | 0 | $0.22 | 4.0 | python | ok |
| Batch File Renamer | powershell | opus46 | 3.0min | 21 | 0 | $0.59 | 4.0 | powershell | ok |
| Batch File Renamer | powershell | sonnet46 | 1.4min | 6 | 0 | $0.16 | 3.0 | powershell | ok |
| Batch File Renamer | powershell-strict | opus46 | 4.5min | 35 | 0 | $1.05 | 4.0 | powershell | ok |
| Database Seed Script | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Database Seed Script | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Database Seed Script | powershell-strict | sonnet46 | 3.6min | 1 | 0 | $0.00 | — | powershell | failed |
| Error Retry Pipeline | default | opus46 | 2.3min | 24 | 0 | $0.54 | 4.0 | python | ok |
| Error Retry Pipeline | default | sonnet46 | 3.7min | 1 | 0 | $0.00 | — |  | failed |
| Error Retry Pipeline | powershell | opus46 | 3.8min | 34 | 0 | $0.93 | 4.0 | powershell | ok |
| Error Retry Pipeline | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Multi-file Search and Replace | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Multi-file Search and Replace | powershell | opus46 | 3.6min | 21 | 0 | $0.65 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet46 | 1.4min | 10 | 0 | $0.19 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus46 | 4.1min | 34 | 0 | $1.09 | 3.0 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Semantic Version Bumper | default | sonnet46 | 2.5min | 11 | 0 | $0.25 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | opus46 | 3.6min | 27 | 0 | $0.77 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46 | 2.7min | 16 | 0 | $0.33 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus46 | 5.8min | 52 | 0 | $1.57 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet46 | 5.3min | 5 | 0 | $0.15 | 4.0 | powershell | failed |
| PR Label Assigner | default | sonnet46 | 1.8min | 8 | 0 | $0.21 | 5.0 | python | ok |
| PR Label Assigner | powershell | opus46 | 3.1min | 23 | 0 | $0.61 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 3.7min | 10 | 0 | $0.38 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-strict | opus46 | 4.0min | 37 | 0 | $1.03 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet46 | 3.3min | 12 | 0 | $0.35 | 4.0 | powershell | ok |
| Dependency License Checker | default | sonnet46 | 4.0min | 1 | 0 | $0.00 | — |  | failed |
| Dependency License Checker | powershell | sonnet46 | 2.6min | 11 | 0 | $0.36 | 5.0 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet46 | 9.5min | 18 | 0 | $0.97 | 4.0 | powershell | ok |
| Docker Image Tag Generator | default | opus46 | 2.7min | 30 | 0 | $0.67 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 3.5min | 32 | 0 | $0.84 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 2.9min | 9 | 0 | $0.31 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus46 | 5.0min | 44 | 0 | $1.28 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet46 | 2.5min | 13 | 0 | $0.33 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | opus46 | 4.3min | 33 | 0 | $0.95 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | sonnet46 | 5.0min | 15 | 0 | $0.55 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus46 | 4.0min | 24 | 0 | $0.95 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet46 | 11.5min | 20 | 0 | $1.42 | 4.0 | powershell | ok |
| Environment Matrix Generator | default | sonnet46 | 2.0min | 9 | 0 | $0.26 | 4.0 | python | ok |
| Environment Matrix Generator | powershell | opus46 | 2.3min | 18 | 0 | $0.54 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46 | 2.8min | 13 | 0 | $0.36 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet46 | 5.4min | 16 | 0 | $0.62 | 4.0 | powershell | ok |
| Artifact Cleanup Script | default | opus46 | 4.4min | 34 | 0 | $0.98 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 4.9min | 30 | 0 | $1.16 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 2.6min | 9 | 0 | $0.35 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet46 | 3.6min | 15 | 0 | $0.49 | 4.0 | powershell | ok |
| Secret Rotation Validator | default | opus46 | 2.6min | 17 | 0 | $0.51 | 4.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 1.5min | 11 | 0 | $0.22 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | sonnet46 | 3.5min | 11 | 0 | $0.48 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet46 | 4.0min | 20 | 0 | $0.53 | 4.0 | powershell | ok |
| CSV Report Generator | powershell-strict | opus46 | 4.3min | 40 | 1 | $1.04 | 4.0 | powershell | ok |
| Log File Analyzer | powershell-strict | opus46 | 4.5min | 31 | 1 | $0.95 | 4.0 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet46 | 3.8min | 14 | 1 | $0.50 | 4.0 | powershell | ok |
| Directory Tree Sync | default | sonnet46 | 3.9min | 11 | 1 | $0.45 | 5.0 | python | ok |
| REST API Client | default | sonnet46 | 1.8min | 9 | 1 | $0.23 | 5.0 | python | ok |
| REST API Client | powershell | opus46 | 7.2min | 51 | 1 | $1.82 | 4.0 | powershell | ok |
| Process Monitor | default | opus46 | 3.3min | 40 | 1 | $1.00 | 3.0 | python | ok |
| Config File Migrator | default | opus46 | 2.8min | 14 | 1 | $0.59 | 4.0 | python | ok |
| Config File Migrator | default | sonnet46 | 3.4min | 18 | 1 | $0.47 | 4.0 | python | ok |
| Batch File Renamer | powershell-strict | sonnet46 | 3.7min | 16 | 1 | $0.50 | 4.0 | powershell | ok |
| Database Seed Script | default | opus46 | 4.3min | 36 | 1 | $1.04 | 5.0 | python | ok |
| Error Retry Pipeline | powershell-strict | opus46 | 9.7min | 0 | 1 | $0.00 | 4.0 | powershell | failed |
| PR Label Assigner | default | opus46 | 1.9min | 11 | 1 | $0.38 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 5.8min | 45 | 1 | $1.37 | 5.0 | powershell | ok |
| Docker Image Tag Generator | default | sonnet46 | 1.8min | 10 | 1 | $0.23 | 4.0 | python | ok |
| Test Results Aggregator | default | opus46 | 2.3min | 15 | 1 | $0.51 | 4.0 | python | ok |
| Test Results Aggregator | default | sonnet46 | 4.0min | 20 | 1 | $0.49 | 3.0 | python | ok |
| Environment Matrix Generator | default | opus46 | 4.7min | 38 | 1 | $1.11 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell-strict | opus46 | 5.5min | 37 | 1 | $1.37 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell | opus46 | 3.3min | 23 | 1 | $0.72 | 4.0 | powershell | ok |
| Batch File Renamer | default | opus46 | 2.8min | 30 | 2 | $0.81 | 4.0 | python | ok |
| Database Seed Script | powershell-strict | opus46 | 8.7min | 56 | 2 | $2.03 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus46 | 4.2min | 31 | 2 | $0.96 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus46 | 5.3min | 39 | 2 | $1.27 | 4.0 | powershell | ok |
| CSV Report Generator | default | sonnet46 | 6.3min | 1 | 3 | $0.71 | 4.0 | python | ok |
| Multi-file Search and Replace | default | opus46 | 3.1min | 25 | 3 | $0.70 | 4.0 | python | ok |
| Database Seed Script | powershell | opus46 | 5.8min | 42 | 4 | $1.32 | 4.0 | powershell | ok |
| Dependency License Checker | default | opus46 | 5.6min | 64 | 4 | $1.73 | 5.0 | python | ok |
| Dependency License Checker | powershell-strict | opus46 | 5.4min | 52 | 4 | $1.59 | 4.0 | powershell | ok |
| Artifact Cleanup Script | default | sonnet46 | 2.6min | 17 | 4 | $0.44 | 4.0 | python | ok |
| Semantic Version Bumper | default | opus46 | 4.8min | 47 | 5 | $1.23 | 4.0 | python | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Error Retry Pipeline | powershell-strict | opus46 | 9.7min | 0 | 1 | $0.00 | 4.0 | powershell | failed |
| CSV Report Generator | default | sonnet46 | 6.3min | 1 | 3 | $0.71 | 4.0 | python | ok |
| Database Seed Script | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Database Seed Script | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Database Seed Script | powershell-strict | sonnet46 | 3.6min | 1 | 0 | $0.00 | — | powershell | failed |
| Error Retry Pipeline | default | sonnet46 | 3.7min | 1 | 0 | $0.00 | — |  | failed |
| Error Retry Pipeline | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Multi-file Search and Replace | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Multi-file Search and Replace | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Dependency License Checker | default | sonnet46 | 4.0min | 1 | 0 | $0.00 | — |  | failed |
| Semantic Version Bumper | powershell-strict | sonnet46 | 5.3min | 5 | 0 | $0.15 | 4.0 | powershell | failed |
| Batch File Renamer | powershell | sonnet46 | 1.4min | 6 | 0 | $0.16 | 3.0 | powershell | ok |
| CSV Report Generator | csharp-script | sonnet46 | 0.6min | 7 | 0 | $0.12 | 4.0 | csharp | ok |
| Batch File Renamer | default | sonnet46 | 2.3min | 8 | 0 | $0.22 | 4.0 | python | ok |
| PR Label Assigner | default | sonnet46 | 1.8min | 8 | 0 | $0.21 | 5.0 | python | ok |
| CSV Report Generator | powershell | sonnet46 | 2.1min | 9 | 0 | $0.31 | 3.0 | powershell | ok |
| Log File Analyzer | csharp-script | opus46 | 0.7min | 9 | 0 | $0.25 | 4.0 | csharp | ok |
| REST API Client | default | sonnet46 | 1.8min | 9 | 1 | $0.23 | 5.0 | python | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 2.9min | 9 | 0 | $0.31 | 4.0 | powershell | ok |
| Environment Matrix Generator | default | sonnet46 | 2.0min | 9 | 0 | $0.26 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 2.6min | 9 | 0 | $0.35 | 4.0 | powershell | ok |
| Log File Analyzer | powershell | sonnet46 | 3.9min | 10 | 0 | $0.44 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet46 | 1.4min | 10 | 0 | $0.19 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 3.7min | 10 | 0 | $0.38 | 4.0 | powershell | ok |
| Docker Image Tag Generator | default | sonnet46 | 1.8min | 10 | 1 | $0.23 | 4.0 | python | ok |
| Directory Tree Sync | default | sonnet46 | 3.9min | 11 | 1 | $0.45 | 5.0 | python | ok |
| Directory Tree Sync | powershell | sonnet46 | 3.0min | 11 | 0 | $0.37 | 4.0 | powershell | ok |
| Semantic Version Bumper | default | sonnet46 | 2.5min | 11 | 0 | $0.25 | 4.0 | python | ok |
| PR Label Assigner | default | opus46 | 1.9min | 11 | 1 | $0.38 | 4.0 | python | ok |
| Dependency License Checker | powershell | sonnet46 | 2.6min | 11 | 0 | $0.36 | 5.0 | powershell | ok |
| Secret Rotation Validator | default | sonnet46 | 1.5min | 11 | 0 | $0.22 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | sonnet46 | 3.5min | 11 | 0 | $0.48 | 4.0 | powershell | ok |
| CSV Report Generator | csharp-script | opus46 | 2.8min | 12 | 0 | $0.58 | 4.0 | csharp | ok |
| CSV Report Generator | default | opus46 | 1.7min | 12 | 0 | $0.38 | 5.0 | python | ok |
| Process Monitor | default | sonnet46 | 2.0min | 12 | 0 | $0.25 | 4.0 | python | ok |
| Config File Migrator | powershell-strict | opus46 | 2.7min | 12 | 0 | $0.49 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet46 | 3.3min | 12 | 0 | $0.35 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet46 | 4.3min | 13 | 0 | $0.49 | 4.0 | powershell | ok |
| REST API Client | powershell | sonnet46 | 12.6min | 13 | 0 | $0.96 | 3.0 | powershell | ok |
| Process Monitor | powershell | sonnet46 | 3.8min | 13 | 0 | $0.40 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet46 | 2.5min | 13 | 0 | $0.33 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46 | 2.8min | 13 | 0 | $0.36 | 4.0 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet46 | 3.8min | 14 | 1 | $0.50 | 4.0 | powershell | ok |
| REST API Client | powershell-strict | sonnet46 | 9.2min | 14 | 0 | $0.99 | 4.0 | powershell | ok |
| Config File Migrator | default | opus46 | 2.8min | 14 | 1 | $0.59 | 4.0 | python | ok |
| Config File Migrator | powershell | sonnet46 | 3.4min | 15 | 0 | $0.38 | 4.0 | powershell | ok |
| Test Results Aggregator | default | opus46 | 2.3min | 15 | 1 | $0.51 | 4.0 | python | ok |
| Test Results Aggregator | powershell | sonnet46 | 5.0min | 15 | 0 | $0.55 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet46 | 3.6min | 15 | 0 | $0.49 | 4.0 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet46 | 3.7min | 16 | 1 | $0.50 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46 | 2.7min | 16 | 0 | $0.33 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet46 | 5.4min | 16 | 0 | $0.62 | 4.0 | powershell | ok |
| Artifact Cleanup Script | default | sonnet46 | 2.6min | 17 | 4 | $0.44 | 4.0 | python | ok |
| Secret Rotation Validator | default | opus46 | 2.6min | 17 | 0 | $0.51 | 4.0 | python | ok |
| Config File Migrator | default | sonnet46 | 3.4min | 18 | 1 | $0.47 | 4.0 | python | ok |
| Dependency License Checker | powershell-strict | sonnet46 | 9.5min | 18 | 0 | $0.97 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | opus46 | 2.3min | 18 | 0 | $0.54 | 4.0 | powershell | ok |
| Log File Analyzer | default | sonnet46 | 2.9min | 19 | 0 | $0.48 | 5.0 | python | ok |
| REST API Client | powershell-strict | opus46 | 5.1min | 19 | 0 | $0.94 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | sonnet46 | 4.6min | 19 | 0 | $0.54 | 4.0 | powershell | ok |
| Config File Migrator | powershell | opus46 | 3.7min | 20 | 0 | $0.69 | 4.0 | powershell | ok |
| Test Results Aggregator | default | sonnet46 | 4.0min | 20 | 1 | $0.49 | 3.0 | python | ok |
| Test Results Aggregator | powershell-strict | sonnet46 | 11.5min | 20 | 0 | $1.42 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet46 | 4.0min | 20 | 0 | $0.53 | 4.0 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet46 | 13.9min | 21 | 0 | $1.60 | 4.0 | powershell | ok |
| Batch File Renamer | powershell | opus46 | 3.0min | 21 | 0 | $0.59 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell | opus46 | 3.6min | 21 | 0 | $0.65 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | opus46 | 3.1min | 23 | 0 | $0.61 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell | opus46 | 3.3min | 23 | 1 | $0.72 | 4.0 | powershell | ok |
| Error Retry Pipeline | default | opus46 | 2.3min | 24 | 0 | $0.54 | 4.0 | python | ok |
| Test Results Aggregator | powershell-strict | opus46 | 4.0min | 24 | 0 | $0.95 | 4.0 | powershell | ok |
| Multi-file Search and Replace | default | opus46 | 3.1min | 25 | 3 | $0.70 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | opus46 | 3.6min | 27 | 0 | $0.77 | 4.0 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet46 | 6.5min | 29 | 0 | $0.97 | 4.0 | powershell | ok |
| Batch File Renamer | default | opus46 | 2.8min | 30 | 2 | $0.81 | 4.0 | python | ok |
| Docker Image Tag Generator | default | opus46 | 2.7min | 30 | 0 | $0.67 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 4.9min | 30 | 0 | $1.16 | 4.0 | powershell | ok |
| Log File Analyzer | powershell-strict | opus46 | 4.5min | 31 | 1 | $0.95 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus46 | 4.2min | 31 | 2 | $0.96 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell | opus46 | 3.5min | 32 | 0 | $0.84 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | opus46 | 4.3min | 33 | 0 | $0.95 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus46 | 5.4min | 34 | 0 | $1.21 | 4.0 | powershell | ok |
| Error Retry Pipeline | powershell | opus46 | 3.8min | 34 | 0 | $0.93 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus46 | 4.1min | 34 | 0 | $1.09 | 3.0 | powershell | ok |
| Artifact Cleanup Script | default | opus46 | 4.4min | 34 | 0 | $0.98 | 4.0 | python | ok |
| Batch File Renamer | powershell-strict | opus46 | 4.5min | 35 | 0 | $1.05 | 4.0 | powershell | ok |
| Database Seed Script | default | opus46 | 4.3min | 36 | 1 | $1.04 | 5.0 | python | ok |
| CSV Report Generator | powershell | opus46 | 4.3min | 37 | 0 | $1.05 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-strict | opus46 | 4.0min | 37 | 0 | $1.03 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus46 | 5.5min | 37 | 1 | $1.37 | 4.0 | powershell | ok |
| Environment Matrix Generator | default | opus46 | 4.7min | 38 | 1 | $1.11 | 4.0 | python | ok |
| Process Monitor | powershell | opus46 | 5.4min | 39 | 0 | $1.21 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus46 | 5.3min | 39 | 2 | $1.27 | 4.0 | powershell | ok |
| CSV Report Generator | powershell-strict | opus46 | 4.3min | 40 | 1 | $1.04 | 4.0 | powershell | ok |
| Process Monitor | default | opus46 | 3.3min | 40 | 1 | $1.00 | 3.0 | python | ok |
| Log File Analyzer | powershell | opus46 | 4.6min | 41 | 0 | $1.14 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell | opus46 | 5.3min | 42 | 0 | $1.13 | 4.0 | powershell | ok |
| Database Seed Script | powershell | opus46 | 5.8min | 42 | 4 | $1.32 | 4.0 | powershell | ok |
| Log File Analyzer | default | opus46 | 4.2min | 43 | 0 | $1.18 | 5.0 | python | ok |
| Directory Tree Sync | default | opus46 | 3.8min | 43 | 0 | $1.18 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell-strict | opus46 | 5.0min | 44 | 0 | $1.28 | 4.0 | powershell | ok |
| REST API Client | default | opus46 | 5.2min | 45 | 0 | $1.21 | 5.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 5.8min | 45 | 1 | $1.37 | 5.0 | powershell | ok |
| Semantic Version Bumper | default | opus46 | 4.8min | 47 | 5 | $1.23 | 4.0 | python | ok |
| REST API Client | powershell | opus46 | 7.2min | 51 | 1 | $1.82 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus46 | 5.8min | 52 | 0 | $1.57 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-strict | opus46 | 5.4min | 52 | 4 | $1.59 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | opus46 | 5.6min | 53 | 0 | $1.61 | 4.0 | powershell | ok |
| Database Seed Script | powershell-strict | opus46 | 8.7min | 56 | 2 | $2.03 | 4.0 | powershell | ok |
| Dependency License Checker | default | opus46 | 5.6min | 64 | 4 | $1.73 | 5.0 | python | ok |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| CSV Report Generator | default | opus46 | 1.7min | 12 | 0 | $0.38 | 5.0 | python | ok |
| Log File Analyzer | default | opus46 | 4.2min | 43 | 0 | $1.18 | 5.0 | python | ok |
| Log File Analyzer | default | sonnet46 | 2.9min | 19 | 0 | $0.48 | 5.0 | python | ok |
| Directory Tree Sync | default | sonnet46 | 3.9min | 11 | 1 | $0.45 | 5.0 | python | ok |
| REST API Client | default | opus46 | 5.2min | 45 | 0 | $1.21 | 5.0 | python | ok |
| REST API Client | default | sonnet46 | 1.8min | 9 | 1 | $0.23 | 5.0 | python | ok |
| Database Seed Script | default | opus46 | 4.3min | 36 | 1 | $1.04 | 5.0 | python | ok |
| PR Label Assigner | default | sonnet46 | 1.8min | 8 | 0 | $0.21 | 5.0 | python | ok |
| Dependency License Checker | default | opus46 | 5.6min | 64 | 4 | $1.73 | 5.0 | python | ok |
| Dependency License Checker | powershell | opus46 | 5.8min | 45 | 1 | $1.37 | 5.0 | powershell | ok |
| Dependency License Checker | powershell | sonnet46 | 2.6min | 11 | 0 | $0.36 | 5.0 | powershell | ok |
| CSV Report Generator | csharp-script | opus46 | 2.8min | 12 | 0 | $0.58 | 4.0 | csharp | ok |
| CSV Report Generator | csharp-script | sonnet46 | 0.6min | 7 | 0 | $0.12 | 4.0 | csharp | ok |
| CSV Report Generator | default | sonnet46 | 6.3min | 1 | 3 | $0.71 | 4.0 | python | ok |
| CSV Report Generator | powershell | opus46 | 4.3min | 37 | 0 | $1.05 | 4.0 | powershell | ok |
| CSV Report Generator | powershell-strict | opus46 | 4.3min | 40 | 1 | $1.04 | 4.0 | powershell | ok |
| CSV Report Generator | powershell-strict | sonnet46 | 6.5min | 29 | 0 | $0.97 | 4.0 | powershell | ok |
| Log File Analyzer | csharp-script | opus46 | 0.7min | 9 | 0 | $0.25 | 4.0 | csharp | ok |
| Log File Analyzer | powershell | opus46 | 4.6min | 41 | 0 | $1.14 | 4.0 | powershell | ok |
| Log File Analyzer | powershell | sonnet46 | 3.9min | 10 | 0 | $0.44 | 4.0 | powershell | ok |
| Log File Analyzer | powershell-strict | opus46 | 4.5min | 31 | 1 | $0.95 | 4.0 | powershell | ok |
| Log File Analyzer | powershell-strict | sonnet46 | 3.8min | 14 | 1 | $0.50 | 4.0 | powershell | ok |
| Directory Tree Sync | default | opus46 | 3.8min | 43 | 0 | $1.18 | 4.0 | python | ok |
| Directory Tree Sync | powershell | opus46 | 5.3min | 42 | 0 | $1.13 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell | sonnet46 | 3.0min | 11 | 0 | $0.37 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | opus46 | 5.4min | 34 | 0 | $1.21 | 4.0 | powershell | ok |
| Directory Tree Sync | powershell-strict | sonnet46 | 4.3min | 13 | 0 | $0.49 | 4.0 | powershell | ok |
| REST API Client | powershell | opus46 | 7.2min | 51 | 1 | $1.82 | 4.0 | powershell | ok |
| REST API Client | powershell-strict | opus46 | 5.1min | 19 | 0 | $0.94 | 4.0 | powershell | ok |
| REST API Client | powershell-strict | sonnet46 | 9.2min | 14 | 0 | $0.99 | 4.0 | powershell | ok |
| Process Monitor | default | sonnet46 | 2.0min | 12 | 0 | $0.25 | 4.0 | python | ok |
| Process Monitor | powershell | opus46 | 5.4min | 39 | 0 | $1.21 | 4.0 | powershell | ok |
| Process Monitor | powershell | sonnet46 | 3.8min | 13 | 0 | $0.40 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | opus46 | 5.6min | 53 | 0 | $1.61 | 4.0 | powershell | ok |
| Process Monitor | powershell-strict | sonnet46 | 4.6min | 19 | 0 | $0.54 | 4.0 | powershell | ok |
| Config File Migrator | default | opus46 | 2.8min | 14 | 1 | $0.59 | 4.0 | python | ok |
| Config File Migrator | default | sonnet46 | 3.4min | 18 | 1 | $0.47 | 4.0 | python | ok |
| Config File Migrator | powershell | opus46 | 3.7min | 20 | 0 | $0.69 | 4.0 | powershell | ok |
| Config File Migrator | powershell | sonnet46 | 3.4min | 15 | 0 | $0.38 | 4.0 | powershell | ok |
| Config File Migrator | powershell-strict | opus46 | 2.7min | 12 | 0 | $0.49 | 4.0 | powershell | ok |
| Config File Migrator | powershell-strict | sonnet46 | 13.9min | 21 | 0 | $1.60 | 4.0 | powershell | ok |
| Batch File Renamer | default | opus46 | 2.8min | 30 | 2 | $0.81 | 4.0 | python | ok |
| Batch File Renamer | default | sonnet46 | 2.3min | 8 | 0 | $0.22 | 4.0 | python | ok |
| Batch File Renamer | powershell | opus46 | 3.0min | 21 | 0 | $0.59 | 4.0 | powershell | ok |
| Batch File Renamer | powershell-strict | opus46 | 4.5min | 35 | 0 | $1.05 | 4.0 | powershell | ok |
| Batch File Renamer | powershell-strict | sonnet46 | 3.7min | 16 | 1 | $0.50 | 4.0 | powershell | ok |
| Database Seed Script | powershell | opus46 | 5.8min | 42 | 4 | $1.32 | 4.0 | powershell | ok |
| Database Seed Script | powershell-strict | opus46 | 8.7min | 56 | 2 | $2.03 | 4.0 | powershell | ok |
| Error Retry Pipeline | default | opus46 | 2.3min | 24 | 0 | $0.54 | 4.0 | python | ok |
| Error Retry Pipeline | powershell | opus46 | 3.8min | 34 | 0 | $0.93 | 4.0 | powershell | ok |
| Error Retry Pipeline | powershell-strict | opus46 | 9.7min | 0 | 1 | $0.00 | 4.0 | powershell | failed |
| Multi-file Search and Replace | default | opus46 | 3.1min | 25 | 3 | $0.70 | 4.0 | python | ok |
| Multi-file Search and Replace | powershell | opus46 | 3.6min | 21 | 0 | $0.65 | 4.0 | powershell | ok |
| Multi-file Search and Replace | powershell | sonnet46 | 1.4min | 10 | 0 | $0.19 | 4.0 | powershell | ok |
| Semantic Version Bumper | default | opus46 | 4.8min | 47 | 5 | $1.23 | 4.0 | python | ok |
| Semantic Version Bumper | default | sonnet46 | 2.5min | 11 | 0 | $0.25 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | opus46 | 3.6min | 27 | 0 | $0.77 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet46 | 2.7min | 16 | 0 | $0.33 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-strict | opus46 | 5.8min | 52 | 0 | $1.57 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-strict | sonnet46 | 5.3min | 5 | 0 | $0.15 | 4.0 | powershell | failed |
| PR Label Assigner | default | opus46 | 1.9min | 11 | 1 | $0.38 | 4.0 | python | ok |
| PR Label Assigner | powershell | opus46 | 3.1min | 23 | 0 | $0.61 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | sonnet46 | 3.7min | 10 | 0 | $0.38 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-strict | opus46 | 4.0min | 37 | 0 | $1.03 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-strict | sonnet46 | 3.3min | 12 | 0 | $0.35 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-strict | opus46 | 5.4min | 52 | 4 | $1.59 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-strict | sonnet46 | 9.5min | 18 | 0 | $0.97 | 4.0 | powershell | ok |
| Docker Image Tag Generator | default | opus46 | 2.7min | 30 | 0 | $0.67 | 4.0 | python | ok |
| Docker Image Tag Generator | default | sonnet46 | 1.8min | 10 | 1 | $0.23 | 4.0 | python | ok |
| Docker Image Tag Generator | powershell | opus46 | 3.5min | 32 | 0 | $0.84 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet46 | 2.9min | 9 | 0 | $0.31 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | opus46 | 5.0min | 44 | 0 | $1.28 | 4.0 | powershell | ok |
| Docker Image Tag Generator | powershell-strict | sonnet46 | 2.5min | 13 | 0 | $0.33 | 4.0 | powershell | ok |
| Test Results Aggregator | default | opus46 | 2.3min | 15 | 1 | $0.51 | 4.0 | python | ok |
| Test Results Aggregator | powershell | opus46 | 4.3min | 33 | 0 | $0.95 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | sonnet46 | 5.0min | 15 | 0 | $0.55 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-strict | opus46 | 4.0min | 24 | 0 | $0.95 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-strict | sonnet46 | 11.5min | 20 | 0 | $1.42 | 4.0 | powershell | ok |
| Environment Matrix Generator | default | opus46 | 4.7min | 38 | 1 | $1.11 | 4.0 | python | ok |
| Environment Matrix Generator | default | sonnet46 | 2.0min | 9 | 0 | $0.26 | 4.0 | python | ok |
| Environment Matrix Generator | powershell | opus46 | 2.3min | 18 | 0 | $0.54 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet46 | 2.8min | 13 | 0 | $0.36 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | opus46 | 4.2min | 31 | 2 | $0.96 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-strict | sonnet46 | 5.4min | 16 | 0 | $0.62 | 4.0 | powershell | ok |
| Artifact Cleanup Script | default | opus46 | 4.4min | 34 | 0 | $0.98 | 4.0 | python | ok |
| Artifact Cleanup Script | default | sonnet46 | 2.6min | 17 | 4 | $0.44 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus46 | 4.9min | 30 | 0 | $1.16 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet46 | 2.6min | 9 | 0 | $0.35 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | opus46 | 5.5min | 37 | 1 | $1.37 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-strict | sonnet46 | 3.6min | 15 | 0 | $0.49 | 4.0 | powershell | ok |
| Secret Rotation Validator | default | opus46 | 2.6min | 17 | 0 | $0.51 | 4.0 | python | ok |
| Secret Rotation Validator | default | sonnet46 | 1.5min | 11 | 0 | $0.22 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | opus46 | 3.3min | 23 | 1 | $0.72 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet46 | 3.5min | 11 | 0 | $0.48 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-strict | opus46 | 5.3min | 39 | 2 | $1.27 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-strict | sonnet46 | 4.0min | 20 | 0 | $0.53 | 4.0 | powershell | ok |
| CSV Report Generator | powershell | sonnet46 | 2.1min | 9 | 0 | $0.31 | 3.0 | powershell | ok |
| REST API Client | powershell | sonnet46 | 12.6min | 13 | 0 | $0.96 | 3.0 | powershell | ok |
| Process Monitor | default | opus46 | 3.3min | 40 | 1 | $1.00 | 3.0 | python | ok |
| Batch File Renamer | powershell | sonnet46 | 1.4min | 6 | 0 | $0.16 | 3.0 | powershell | ok |
| Multi-file Search and Replace | powershell-strict | opus46 | 4.1min | 34 | 0 | $1.09 | 3.0 | powershell | ok |
| Test Results Aggregator | default | sonnet46 | 4.0min | 20 | 1 | $0.49 | 3.0 | python | ok |
| Database Seed Script | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Database Seed Script | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Database Seed Script | powershell-strict | sonnet46 | 3.6min | 1 | 0 | $0.00 | — | powershell | failed |
| Error Retry Pipeline | default | sonnet46 | 3.7min | 1 | 0 | $0.00 | — |  | failed |
| Error Retry Pipeline | powershell | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Error Retry Pipeline | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Multi-file Search and Replace | default | sonnet46 | 3.9min | 1 | 0 | $0.00 | — |  | failed |
| Multi-file Search and Replace | powershell-strict | sonnet46 | 3.8min | 1 | 0 | $0.00 | — | powershell | failed |
| Dependency License Checker | default | sonnet46 | 4.0min | 1 | 0 | $0.00 | — |  | failed |

</details>

---
*Generated by generate_results.py — benchmark instructions v2*