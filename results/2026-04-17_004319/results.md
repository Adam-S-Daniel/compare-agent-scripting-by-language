# Benchmark Results: Language Comparison

**Last updated:** 2026-04-19 01:15:13 AM ET

**Status:** 80/105 runs completed, 25 remaining
**Total cost so far:** $155.18
**Total agent time so far:** 779.1 min

## Tiers by Language/Model/Effort

*Duration / Cost tier = ratio of this combo's average to the best combo's average on that axis (lower ratio = better). Bands: **A** ≤1.15×, **B** ≤1.40×, **C** ≤1.80×, **D** ≤2.50×, **E** >2.50×.*
*LLM Score tier = absolute Overall score band. **A** ≥4.5, **B** ≥3.5, **C** ≥2.5, **D** ≥1.5, **E** <1.5, `—` = no data.*
*If every row in a column is tier A, those combos are effectively tied on that axis.*

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | haiku45 | B (6.7min) | A ($0.48) | — |
| bash | opus47-1m-medium | A (4.9min) | D ($1.11) | C (2.6) |
| bash | opus47-1m-xhigh | E (16.5min) | E ($2.87) | B (3.6) |
| default | haiku45 | E (31.0min) | A ($0.54) | — |
| default | opus47-1m-medium | A (5.4min) | D ($1.03) | C (3.3) |
| default | opus47-1m-xhigh | C (7.8min) | E ($2.29) | B (3.9) |
| powershell | haiku45 | B (5.8min) | A ($0.48) | — |
| powershell | opus47-1m-medium | D (10.2min) | E ($1.52) | B (3.6) |
| powershell | opus47-1m-xhigh | D (11.5min) | E ($3.21) | B (3.9) |
| powershell-tool | haiku45 | D (9.1min) | B ($0.58) | — |
| powershell-tool | opus47-1m-medium | C (8.0min) | E ($1.43) | C (3.4) |
| powershell-tool | opus47-1m-xhigh | D (10.6min) | E ($3.16) | B (3.9) |
| typescript-bun | haiku45 | B (6.8min) | A ($0.50) | — |
| typescript-bun | opus47-1m-medium | C (7.6min) | E ($1.29) | C (3.4) |
| typescript-bun | opus47-1m-xhigh | D (12.0min) | E ($3.54) | B (4.0) |


<details>
<summary>Sorted by Duration tier (A-first), then avg of Cost/LLM tiers</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | opus47-1m-medium | A (4.9min) | D ($1.11) | C (2.6) |
| default | opus47-1m-medium | A (5.4min) | D ($1.03) | C (3.3) |
| bash | haiku45 | B (6.7min) | A ($0.48) | — |
| powershell | haiku45 | B (5.8min) | A ($0.48) | — |
| typescript-bun | haiku45 | B (6.8min) | A ($0.50) | — |
| default | opus47-1m-xhigh | C (7.8min) | E ($2.29) | B (3.9) |
| powershell-tool | opus47-1m-medium | C (8.0min) | E ($1.43) | C (3.4) |
| typescript-bun | opus47-1m-medium | C (7.6min) | E ($1.29) | C (3.4) |
| powershell | opus47-1m-medium | D (10.2min) | E ($1.52) | B (3.6) |
| powershell | opus47-1m-xhigh | D (11.5min) | E ($3.21) | B (3.9) |
| powershell-tool | opus47-1m-xhigh | D (10.6min) | E ($3.16) | B (3.9) |
| typescript-bun | opus47-1m-xhigh | D (12.0min) | E ($3.54) | B (4.0) |
| powershell-tool | haiku45 | D (9.1min) | B ($0.58) | — |
| bash | opus47-1m-xhigh | E (16.5min) | E ($2.87) | B (3.6) |
| default | haiku45 | E (31.0min) | A ($0.54) | — |

</details>

<details>
<summary>Sorted by Cost tier (A-first), then avg of Duration/LLM tiers</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | haiku45 | B (6.7min) | A ($0.48) | — |
| powershell | haiku45 | B (5.8min) | A ($0.48) | — |
| typescript-bun | haiku45 | B (6.8min) | A ($0.50) | — |
| default | haiku45 | E (31.0min) | A ($0.54) | — |
| powershell-tool | haiku45 | D (9.1min) | B ($0.58) | — |
| bash | opus47-1m-medium | A (4.9min) | D ($1.11) | C (2.6) |
| default | opus47-1m-medium | A (5.4min) | D ($1.03) | C (3.3) |
| default | opus47-1m-xhigh | C (7.8min) | E ($2.29) | B (3.9) |
| powershell | opus47-1m-medium | D (10.2min) | E ($1.52) | B (3.6) |
| powershell | opus47-1m-xhigh | D (11.5min) | E ($3.21) | B (3.9) |
| powershell-tool | opus47-1m-medium | C (8.0min) | E ($1.43) | C (3.4) |
| powershell-tool | opus47-1m-xhigh | D (10.6min) | E ($3.16) | B (3.9) |
| typescript-bun | opus47-1m-medium | C (7.6min) | E ($1.29) | C (3.4) |
| typescript-bun | opus47-1m-xhigh | D (12.0min) | E ($3.54) | B (4.0) |
| bash | opus47-1m-xhigh | E (16.5min) | E ($2.87) | B (3.6) |

</details>

<details>
<summary>Sorted by LLM Score tier (A-first; no-data last), then avg of Duration/Cost tiers</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| default | opus47-1m-xhigh | C (7.8min) | E ($2.29) | B (3.9) |
| powershell | opus47-1m-medium | D (10.2min) | E ($1.52) | B (3.6) |
| powershell | opus47-1m-xhigh | D (11.5min) | E ($3.21) | B (3.9) |
| powershell-tool | opus47-1m-xhigh | D (10.6min) | E ($3.16) | B (3.9) |
| typescript-bun | opus47-1m-xhigh | D (12.0min) | E ($3.54) | B (4.0) |
| bash | opus47-1m-xhigh | E (16.5min) | E ($2.87) | B (3.6) |
| bash | opus47-1m-medium | A (4.9min) | D ($1.11) | C (2.6) |
| default | opus47-1m-medium | A (5.4min) | D ($1.03) | C (3.3) |
| powershell-tool | opus47-1m-medium | C (8.0min) | E ($1.43) | C (3.4) |
| typescript-bun | opus47-1m-medium | C (7.6min) | E ($1.29) | C (3.4) |
| bash | haiku45 | B (6.7min) | A ($0.48) | — |
| powershell | haiku45 | B (5.8min) | A ($0.48) | — |
| typescript-bun | haiku45 | B (6.8min) | A ($0.50) | — |
| default | haiku45 | E (31.0min) | A ($0.54) | — |
| powershell-tool | haiku45 | D (9.1min) | B ($0.58) | — |

</details>

## Rankings by Language/Model/Effort

*Lower rank = better on that axis (1 = fastest / cheapest / highest LLM score).*
*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | haiku45 | 4 (6.7min) | 2 ($0.48) | — |
| bash | opus47-1m-medium | 1 (4.9min) | 7 ($1.11) | 10 (2.6) |
| bash | opus47-1m-xhigh | 14 (16.5min) | 12 ($2.87) | 5 (3.6) |
| default | haiku45 | 15 (31.0min) | 4 ($0.54) | — |
| default | opus47-1m-medium | 2 (5.4min) | 6 ($1.03) | 9 (3.3) |
| default | opus47-1m-xhigh | 7 (7.8min) | 11 ($2.29) | 2 (3.9) |
| powershell | haiku45 | 3 (5.8min) | 1 ($0.48) | — |
| powershell | opus47-1m-medium | 10 (10.2min) | 10 ($1.52) | 6 (3.6) |
| powershell | opus47-1m-xhigh | 12 (11.5min) | 14 ($3.21) | 3 (3.9) |
| powershell-tool | haiku45 | 9 (9.1min) | 5 ($0.58) | — |
| powershell-tool | opus47-1m-medium | 8 (8.0min) | 9 ($1.43) | 7 (3.4) |
| powershell-tool | opus47-1m-xhigh | 11 (10.6min) | 13 ($3.16) | 4 (3.9) |
| typescript-bun | haiku45 | 5 (6.8min) | 3 ($0.50) | — |
| typescript-bun | opus47-1m-medium | 6 (7.6min) | 8 ($1.29) | 8 (3.4) |
| typescript-bun | opus47-1m-xhigh | 13 (12.0min) | 15 ($3.54) | 1 (4.0) |


<details>
<summary>Sorted by Duration rank (fastest first)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| bash | opus47-1m-medium | 1 (4.9min) | 7 ($1.11) | 10 (2.6) |
| default | opus47-1m-medium | 2 (5.4min) | 6 ($1.03) | 9 (3.3) |
| powershell | haiku45 | 3 (5.8min) | 1 ($0.48) | — |
| bash | haiku45 | 4 (6.7min) | 2 ($0.48) | — |
| typescript-bun | haiku45 | 5 (6.8min) | 3 ($0.50) | — |
| typescript-bun | opus47-1m-medium | 6 (7.6min) | 8 ($1.29) | 8 (3.4) |
| default | opus47-1m-xhigh | 7 (7.8min) | 11 ($2.29) | 2 (3.9) |
| powershell-tool | opus47-1m-medium | 8 (8.0min) | 9 ($1.43) | 7 (3.4) |
| powershell-tool | haiku45 | 9 (9.1min) | 5 ($0.58) | — |
| powershell | opus47-1m-medium | 10 (10.2min) | 10 ($1.52) | 6 (3.6) |
| powershell-tool | opus47-1m-xhigh | 11 (10.6min) | 13 ($3.16) | 4 (3.9) |
| powershell | opus47-1m-xhigh | 12 (11.5min) | 14 ($3.21) | 3 (3.9) |
| typescript-bun | opus47-1m-xhigh | 13 (12.0min) | 15 ($3.54) | 1 (4.0) |
| bash | opus47-1m-xhigh | 14 (16.5min) | 12 ($2.87) | 5 (3.6) |
| default | haiku45 | 15 (31.0min) | 4 ($0.54) | — |

</details>

<details>
<summary>Sorted by Cost rank (cheapest first)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| powershell | haiku45 | 3 (5.8min) | 1 ($0.48) | — |
| bash | haiku45 | 4 (6.7min) | 2 ($0.48) | — |
| typescript-bun | haiku45 | 5 (6.8min) | 3 ($0.50) | — |
| default | haiku45 | 15 (31.0min) | 4 ($0.54) | — |
| powershell-tool | haiku45 | 9 (9.1min) | 5 ($0.58) | — |
| default | opus47-1m-medium | 2 (5.4min) | 6 ($1.03) | 9 (3.3) |
| bash | opus47-1m-medium | 1 (4.9min) | 7 ($1.11) | 10 (2.6) |
| typescript-bun | opus47-1m-medium | 6 (7.6min) | 8 ($1.29) | 8 (3.4) |
| powershell-tool | opus47-1m-medium | 8 (8.0min) | 9 ($1.43) | 7 (3.4) |
| powershell | opus47-1m-medium | 10 (10.2min) | 10 ($1.52) | 6 (3.6) |
| default | opus47-1m-xhigh | 7 (7.8min) | 11 ($2.29) | 2 (3.9) |
| bash | opus47-1m-xhigh | 14 (16.5min) | 12 ($2.87) | 5 (3.6) |
| powershell-tool | opus47-1m-xhigh | 11 (10.6min) | 13 ($3.16) | 4 (3.9) |
| powershell | opus47-1m-xhigh | 12 (11.5min) | 14 ($3.21) | 3 (3.9) |
| typescript-bun | opus47-1m-xhigh | 13 (12.0min) | 15 ($3.54) | 1 (4.0) |

</details>

<details>
<summary>Sorted by LLM Score rank (best first; no-data last)</summary>

| Language | Model | Duration | Cost | LLM Score |
|----------|-------|----------|------|-----------|
| typescript-bun | opus47-1m-xhigh | 13 (12.0min) | 15 ($3.54) | 1 (4.0) |
| default | opus47-1m-xhigh | 7 (7.8min) | 11 ($2.29) | 2 (3.9) |
| powershell | opus47-1m-xhigh | 12 (11.5min) | 14 ($3.21) | 3 (3.9) |
| powershell-tool | opus47-1m-xhigh | 11 (10.6min) | 13 ($3.16) | 4 (3.9) |
| bash | opus47-1m-xhigh | 14 (16.5min) | 12 ($2.87) | 5 (3.6) |
| powershell | opus47-1m-medium | 10 (10.2min) | 10 ($1.52) | 6 (3.6) |
| powershell-tool | opus47-1m-medium | 8 (8.0min) | 9 ($1.43) | 7 (3.4) |
| typescript-bun | opus47-1m-medium | 6 (7.6min) | 8 ($1.29) | 8 (3.4) |
| default | opus47-1m-medium | 2 (5.4min) | 6 ($1.03) | 9 (3.3) |
| bash | opus47-1m-medium | 1 (4.9min) | 7 ($1.11) | 10 (2.6) |
| bash | haiku45 | 4 (6.7min) | 2 ($0.48) | — |
| default | haiku45 | 15 (31.0min) | 4 ($0.54) | — |
| powershell | haiku45 | 3 (5.8min) | 1 ($0.48) | — |
| powershell-tool | haiku45 | 9 (9.1min) | 5 ($0.58) | — |
| typescript-bun | haiku45 | 5 (6.8min) | 3 ($0.50) | — |

</details>

- **Estimated time remaining:** 925.2min
- **Estimated total cost:** $203.68

## Comparison by Language/Model/Effort
*Avg LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| bash | haiku45 | 2 | 6.7min | 6.0min | 2.5 | 55 | $0.48 | $0.95 | — |
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 | 2.6 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 | 3.6 |
| default | haiku45 | 2 | 31.0min | 26.9min | 7.5 | 62 | $0.54 | $1.09 | — |
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 | 3.3 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 | 3.9 |
| powershell | haiku45 | 2 | 5.8min | 2.0min | 2.5 | 54 | $0.48 | $0.95 | — |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 | 3.6 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 | 3.9 |
| powershell-tool | haiku45 | 2 | 9.1min | 5.9min | 4.0 | 59 | $0.58 | $1.15 | — |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 | 3.4 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 | 3.9 |
| typescript-bun | haiku45 | 2 | 6.8min | 3.5min | 6.0 | 58 | $0.50 | $0.99 | — |
| typescript-bun | opus47-1m-medium | 7 | 7.6min | 6.4min | 0.4 | 32 | $1.29 | $9.00 | 3.4 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 | 4.0 |


<details>
<summary>Sorted by avg cost (cheapest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| powershell | haiku45 | 2 | 5.8min | 2.0min | 2.5 | 54 | $0.48 | $0.95 | — |
| bash | haiku45 | 2 | 6.7min | 6.0min | 2.5 | 55 | $0.48 | $0.95 | — |
| typescript-bun | haiku45 | 2 | 6.8min | 3.5min | 6.0 | 58 | $0.50 | $0.99 | — |
| default | haiku45 | 2 | 31.0min | 26.9min | 7.5 | 62 | $0.54 | $1.09 | — |
| powershell-tool | haiku45 | 2 | 9.1min | 5.9min | 4.0 | 59 | $0.58 | $1.15 | — |
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 | 3.3 |
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 | 2.6 |
| typescript-bun | opus47-1m-medium | 7 | 7.6min | 6.4min | 0.4 | 32 | $1.29 | $9.00 | 3.4 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 | 3.4 |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 | 3.6 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 | 3.9 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 | 3.6 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 | 3.9 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 | 3.9 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 | 4.0 |

</details>

<details>
<summary>Sorted by avg duration (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 | 2.6 |
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 | 3.3 |
| powershell | haiku45 | 2 | 5.8min | 2.0min | 2.5 | 54 | $0.48 | $0.95 | — |
| bash | haiku45 | 2 | 6.7min | 6.0min | 2.5 | 55 | $0.48 | $0.95 | — |
| typescript-bun | haiku45 | 2 | 6.8min | 3.5min | 6.0 | 58 | $0.50 | $0.99 | — |
| typescript-bun | opus47-1m-medium | 7 | 7.6min | 6.4min | 0.4 | 32 | $1.29 | $9.00 | 3.4 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 | 3.9 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 | 3.4 |
| powershell-tool | haiku45 | 2 | 9.1min | 5.9min | 4.0 | 59 | $0.58 | $1.15 | — |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 | 3.6 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 | 3.9 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 | 3.9 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 | 4.0 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 | 3.6 |
| default | haiku45 | 2 | 31.0min | 26.9min | 7.5 | 62 | $0.54 | $1.09 | — |

</details>

<details>
<summary>Sorted by avg duration net of traps (fastest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| powershell | haiku45 | 2 | 5.8min | 2.0min | 2.5 | 54 | $0.48 | $0.95 | — |
| typescript-bun | haiku45 | 2 | 6.8min | 3.5min | 6.0 | 58 | $0.50 | $0.99 | — |
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 | 2.6 |
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 | 3.3 |
| powershell-tool | haiku45 | 2 | 9.1min | 5.9min | 4.0 | 59 | $0.58 | $1.15 | — |
| bash | haiku45 | 2 | 6.7min | 6.0min | 2.5 | 55 | $0.48 | $0.95 | — |
| typescript-bun | opus47-1m-medium | 7 | 7.6min | 6.4min | 0.4 | 32 | $1.29 | $9.00 | 3.4 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 | 3.9 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 | 3.4 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 | 4.0 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 | 3.9 |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 | 3.6 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 | 3.9 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 | 3.6 |
| default | haiku45 | 2 | 31.0min | 26.9min | 7.5 | 62 | $0.54 | $1.09 | — |

</details>

<details>
<summary>Sorted by avg errors (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 | 3.6 |
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 | 3.3 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 | 3.9 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 | 3.9 |
| typescript-bun | opus47-1m-medium | 7 | 7.6min | 6.4min | 0.4 | 32 | $1.29 | $9.00 | 3.4 |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 | 4.0 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 | 3.9 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 | 3.4 |
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 | 2.6 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 | 3.6 |
| bash | haiku45 | 2 | 6.7min | 6.0min | 2.5 | 55 | $0.48 | $0.95 | — |
| powershell | haiku45 | 2 | 5.8min | 2.0min | 2.5 | 54 | $0.48 | $0.95 | — |
| powershell-tool | haiku45 | 2 | 9.1min | 5.9min | 4.0 | 59 | $0.58 | $1.15 | — |
| typescript-bun | haiku45 | 2 | 6.8min | 3.5min | 6.0 | 58 | $0.50 | $0.99 | — |
| default | haiku45 | 2 | 31.0min | 26.9min | 7.5 | 62 | $0.54 | $1.09 | — |

</details>

<details>
<summary>Sorted by avg turns (fewest first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 | 3.3 |
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 | 2.6 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 | 3.4 |
| typescript-bun | opus47-1m-medium | 7 | 7.6min | 6.4min | 0.4 | 32 | $1.29 | $9.00 | 3.4 |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 | 3.6 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 | 3.9 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 | 3.9 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 | 3.6 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 | 3.9 |
| powershell | haiku45 | 2 | 5.8min | 2.0min | 2.5 | 54 | $0.48 | $0.95 | — |
| bash | haiku45 | 2 | 6.7min | 6.0min | 2.5 | 55 | $0.48 | $0.95 | — |
| typescript-bun | haiku45 | 2 | 6.8min | 3.5min | 6.0 | 58 | $0.50 | $0.99 | — |
| powershell-tool | haiku45 | 2 | 9.1min | 5.9min | 4.0 | 59 | $0.58 | $1.15 | — |
| default | haiku45 | 2 | 31.0min | 26.9min | 7.5 | 62 | $0.54 | $1.09 | — |
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 | 4.0 |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Language | Model | Runs | Avg Duration | Avg Duration Net of Traps | Avg Errors | Avg Turns | Avg Cost | Total Cost | Avg LLM Score |
|----------|-------|------|--------------|---------------------------|------------|-----------|----------|------------|---------------|
| typescript-bun | opus47-1m-xhigh | 7 | 12.0min | 7.9min | 0.4 | 66 | $3.54 | $24.75 | 4.0 |
| default | opus47-1m-xhigh | 7 | 7.8min | 7.4min | 0.6 | 42 | $2.29 | $16.00 | 3.9 |
| powershell | opus47-1m-xhigh | 7 | 11.5min | 10.3min | 0.4 | 49 | $3.21 | $22.48 | 3.9 |
| powershell-tool | opus47-1m-xhigh | 7 | 10.6min | 9.5min | 0.3 | 47 | $3.16 | $22.13 | 3.9 |
| bash | opus47-1m-xhigh | 7 | 16.5min | 16.2min | 1.4 | 49 | $2.87 | $20.11 | 3.6 |
| powershell | opus47-1m-medium | 7 | 10.2min | 9.8min | 0.0 | 32 | $1.52 | $10.61 | 3.6 |
| powershell-tool | opus47-1m-medium | 7 | 8.0min | 7.5min | 0.7 | 31 | $1.43 | $9.99 | 3.4 |
| typescript-bun | opus47-1m-medium | 7 | 7.6min | 6.4min | 0.4 | 32 | $1.29 | $9.00 | 3.4 |
| default | opus47-1m-medium | 7 | 5.4min | 5.4min | 0.3 | 25 | $1.03 | $7.24 | 3.3 |
| bash | opus47-1m-medium | 7 | 4.9min | 4.5min | 1.1 | 27 | $1.11 | $7.74 | 2.6 |
| bash | haiku45 | 2 | 6.7min | 6.0min | 2.5 | 55 | $0.48 | $0.95 | — |
| default | haiku45 | 2 | 31.0min | 26.9min | 7.5 | 62 | $0.54 | $1.09 | — |
| powershell | haiku45 | 2 | 5.8min | 2.0min | 2.5 | 54 | $0.48 | $0.95 | — |
| powershell-tool | haiku45 | 2 | 9.1min | 5.9min | 4.0 | 59 | $0.58 | $1.15 | — |
| typescript-bun | haiku45 | 2 | 6.8min | 3.5min | 6.0 | 58 | $0.50 | $0.99 | — |

</details>

## Savings Analysis

### Hook Savings by Language/Model/Effort

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.
Every hook fire (hit or miss) costs execution time for the syntax/type checker.

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| bash | haiku45 | 32 | 12 | 37.5% | 2.4min | 0.3% | 0.0min | 0.0% | 2.4min | 0.3% | 4.8min | 49.8% |
| bash | opus47-1m-medium | 70 | 3 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 7.6min | 5.2% |
| bash | opus47-1m-xhigh | 112 | 4 | 3.6% | 0.8min | 0.1% | 0.1min | 0.0% | 0.7min | 0.1% | 28.8min | 2.4% |
| default | haiku45 | 29 | 6 | 20.7% | 0.8min | 0.1% | 0.0min | 0.0% | 0.8min | 0.1% | 4.1min | 18.8% |
| default | opus47-1m-medium | 75 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 13.4min | -0.7% |
| default | opus47-1m-xhigh | 103 | 3 | 2.9% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 7.0min | 2.3% |
| powershell | haiku45 | 24 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 1.6min | -10.5% |
| powershell | opus47-1m-medium | 110 | 0 | 0.0% | 0.0min | 0.0% | 2.5min | 0.3% | -2.5min | -0.3% | 32.3min | -7.8% |
| powershell | opus47-1m-xhigh | 116 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.1% | -0.8min | -0.1% | 11.9min | -6.8% |
| powershell-tool | haiku45 | 40 | 3 | 7.5% | 1.8min | 0.2% | 0.2min | 0.0% | 1.5min | 0.2% | 2.8min | 55.3% |
| powershell-tool | opus47-1m-medium | 85 | 0 | 0.0% | 0.0min | 0.0% | 1.5min | 0.2% | -1.5min | -0.2% | 18.9min | -7.9% |
| powershell-tool | opus47-1m-xhigh | 122 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.1% | -0.7min | -0.1% | 8.4min | -8.9% |
| typescript-bun | haiku45 | 48 | 22 | 45.8% | 2.9min | 0.4% | 1.0min | 0.1% | 2.0min | 0.3% | 2.1min | 93.7% |
| typescript-bun | opus47-1m-medium | 87 | 38 | 43.7% | 5.1min | 0.7% | 2.6min | 0.3% | 2.4min | 0.3% | 17.7min | 13.7% |
| typescript-bun | opus47-1m-xhigh | 159 | 86 | 54.1% | 11.5min | 1.5% | 4.8min | 0.6% | 6.7min | 0.9% | 14.7min | 45.5% |


<details>
<summary>Sorted by net saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m-xhigh | 159 | 86 | 54.1% | 11.5min | 1.5% | 4.8min | 0.6% | 6.7min | 0.9% | 14.7min | 45.5% |
| typescript-bun | opus47-1m-medium | 87 | 38 | 43.7% | 5.1min | 0.7% | 2.6min | 0.3% | 2.4min | 0.3% | 17.7min | 13.7% |
| bash | haiku45 | 32 | 12 | 37.5% | 2.4min | 0.3% | 0.0min | 0.0% | 2.4min | 0.3% | 4.8min | 49.8% |
| typescript-bun | haiku45 | 48 | 22 | 45.8% | 2.9min | 0.4% | 1.0min | 0.1% | 2.0min | 0.3% | 2.1min | 93.7% |
| powershell-tool | haiku45 | 40 | 3 | 7.5% | 1.8min | 0.2% | 0.2min | 0.0% | 1.5min | 0.2% | 2.8min | 55.3% |
| default | haiku45 | 29 | 6 | 20.7% | 0.8min | 0.1% | 0.0min | 0.0% | 0.8min | 0.1% | 4.1min | 18.8% |
| bash | opus47-1m-xhigh | 112 | 4 | 3.6% | 0.8min | 0.1% | 0.1min | 0.0% | 0.7min | 0.1% | 28.8min | 2.4% |
| bash | opus47-1m-medium | 70 | 3 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 7.6min | 5.2% |
| default | opus47-1m-xhigh | 103 | 3 | 2.9% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 7.0min | 2.3% |
| default | opus47-1m-medium | 75 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 13.4min | -0.7% |
| powershell | haiku45 | 24 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 1.6min | -10.5% |
| powershell-tool | opus47-1m-xhigh | 122 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.1% | -0.7min | -0.1% | 8.4min | -8.9% |
| powershell | opus47-1m-xhigh | 116 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.1% | -0.8min | -0.1% | 11.9min | -6.8% |
| powershell-tool | opus47-1m-medium | 85 | 0 | 0.0% | 0.0min | 0.0% | 1.5min | 0.2% | -1.5min | -0.2% | 18.9min | -7.9% |
| powershell | opus47-1m-medium | 110 | 0 | 0.0% | 0.0min | 0.0% | 2.5min | 0.3% | -2.5min | -0.3% | 32.3min | -7.8% |

</details>

<details>
<summary>Sorted by net % of test time saved (most first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | haiku45 | 48 | 22 | 45.8% | 2.9min | 0.4% | 1.0min | 0.1% | 2.0min | 0.3% | 2.1min | 93.7% |
| powershell-tool | haiku45 | 40 | 3 | 7.5% | 1.8min | 0.2% | 0.2min | 0.0% | 1.5min | 0.2% | 2.8min | 55.3% |
| bash | haiku45 | 32 | 12 | 37.5% | 2.4min | 0.3% | 0.0min | 0.0% | 2.4min | 0.3% | 4.8min | 49.8% |
| typescript-bun | opus47-1m-xhigh | 159 | 86 | 54.1% | 11.5min | 1.5% | 4.8min | 0.6% | 6.7min | 0.9% | 14.7min | 45.5% |
| default | haiku45 | 29 | 6 | 20.7% | 0.8min | 0.1% | 0.0min | 0.0% | 0.8min | 0.1% | 4.1min | 18.8% |
| typescript-bun | opus47-1m-medium | 87 | 38 | 43.7% | 5.1min | 0.7% | 2.6min | 0.3% | 2.4min | 0.3% | 17.7min | 13.7% |
| bash | opus47-1m-medium | 70 | 3 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 7.6min | 5.2% |
| bash | opus47-1m-xhigh | 112 | 4 | 3.6% | 0.8min | 0.1% | 0.1min | 0.0% | 0.7min | 0.1% | 28.8min | 2.4% |
| default | opus47-1m-xhigh | 103 | 3 | 2.9% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 7.0min | 2.3% |
| default | opus47-1m-medium | 75 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 13.4min | -0.7% |
| powershell | opus47-1m-xhigh | 116 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.1% | -0.8min | -0.1% | 11.9min | -6.8% |
| powershell | opus47-1m-medium | 110 | 0 | 0.0% | 0.0min | 0.0% | 2.5min | 0.3% | -2.5min | -0.3% | 32.3min | -7.8% |
| powershell-tool | opus47-1m-medium | 85 | 0 | 0.0% | 0.0min | 0.0% | 1.5min | 0.2% | -1.5min | -0.2% | 18.9min | -7.9% |
| powershell-tool | opus47-1m-xhigh | 122 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.1% | -0.7min | -0.1% | 8.4min | -8.9% |
| powershell | haiku45 | 24 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 1.6min | -10.5% |

</details>

<details>
<summary>Sorted by catch rate (highest first)</summary>

| Language | Model | Fires | Caught | Rate | Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time | Test Run Time | % of Test Time Saved |
|------|-------|-------|--------|------|------------|-----------|----------|-----------|-----------|-----------|---------------|----------------------|
| typescript-bun | opus47-1m-xhigh | 159 | 86 | 54.1% | 11.5min | 1.5% | 4.8min | 0.6% | 6.7min | 0.9% | 14.7min | 45.5% |
| typescript-bun | haiku45 | 48 | 22 | 45.8% | 2.9min | 0.4% | 1.0min | 0.1% | 2.0min | 0.3% | 2.1min | 93.7% |
| typescript-bun | opus47-1m-medium | 87 | 38 | 43.7% | 5.1min | 0.7% | 2.6min | 0.3% | 2.4min | 0.3% | 17.7min | 13.7% |
| bash | haiku45 | 32 | 12 | 37.5% | 2.4min | 0.3% | 0.0min | 0.0% | 2.4min | 0.3% | 4.8min | 49.8% |
| default | haiku45 | 29 | 6 | 20.7% | 0.8min | 0.1% | 0.0min | 0.0% | 0.8min | 0.1% | 4.1min | 18.8% |
| powershell-tool | haiku45 | 40 | 3 | 7.5% | 1.8min | 0.2% | 0.2min | 0.0% | 1.5min | 0.2% | 2.8min | 55.3% |
| bash | opus47-1m-medium | 70 | 3 | 4.3% | 0.6min | 0.1% | 0.2min | 0.0% | 0.4min | 0.1% | 7.6min | 5.2% |
| bash | opus47-1m-xhigh | 112 | 4 | 3.6% | 0.8min | 0.1% | 0.1min | 0.0% | 0.7min | 0.1% | 28.8min | 2.4% |
| default | opus47-1m-xhigh | 103 | 3 | 2.9% | 0.4min | 0.1% | 0.2min | 0.0% | 0.2min | 0.0% | 7.0min | 2.3% |
| default | opus47-1m-medium | 75 | 1 | 1.3% | 0.1min | 0.0% | 0.2min | 0.0% | -0.1min | -0.0% | 13.4min | -0.7% |
| powershell | haiku45 | 24 | 0 | 0.0% | 0.0min | 0.0% | 0.2min | 0.0% | -0.2min | -0.0% | 1.6min | -10.5% |
| powershell | opus47-1m-medium | 110 | 0 | 0.0% | 0.0min | 0.0% | 2.5min | 0.3% | -2.5min | -0.3% | 32.3min | -7.8% |
| powershell | opus47-1m-xhigh | 116 | 0 | 0.0% | 0.0min | 0.0% | 0.8min | 0.1% | -0.8min | -0.1% | 11.9min | -6.8% |
| powershell-tool | opus47-1m-medium | 85 | 0 | 0.0% | 0.0min | 0.0% | 1.5min | 0.2% | -1.5min | -0.2% | 18.9min | -7.9% |
| powershell-tool | opus47-1m-xhigh | 122 | 0 | 0.0% | 0.0min | 0.0% | 0.7min | 0.1% | -0.7min | -0.1% | 8.4min | -8.9% |

</details>

### Trap Analysis by Language/Model/Effort/Category

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | bash | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.03% |
| repeated-test-reruns | bash | opus47-1m-medium | 1 | 1.0min | 0.1% | $0.25 | 0.16% |
| repeated-test-reruns | bash | opus47-1m-xhigh | 1 | 1.7min | 0.2% | $0.52 | 0.33% |
| repeated-test-reruns | default | opus47-1m-xhigh | 1 | 0.7min | 0.1% | $0.18 | 0.12% |
| repeated-test-reruns | powershell | haiku45 | 3 | 4.0min | 0.5% | $0.34 | 0.22% |
| repeated-test-reruns | powershell | opus47-1m-medium | 2 | 2.7min | 0.3% | $0.57 | 0.37% |
| repeated-test-reruns | powershell | opus47-1m-xhigh | 4 | 3.3min | 0.4% | $0.93 | 0.60% |
| repeated-test-reruns | powershell-tool | haiku45 | 2 | 3.7min | 0.5% | $0.23 | 0.15% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium | 1 | 1.0min | 0.1% | $0.18 | 0.12% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh | 2 | 1.7min | 0.2% | $0.60 | 0.39% |
| repeated-test-reruns | typescript-bun | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.04% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium | 1 | 0.7min | 0.1% | $0.16 | 0.10% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh | 5 | 7.7min | 1.0% | $2.28 | 1.47% |
| ts-type-error-fix-cycles | typescript-bun | haiku45 | 2 | 4.4min | 0.6% | $0.32 | 0.21% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium | 7 | 7.6min | 1.0% | $1.31 | 0.85% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh | 7 | 17.2min | 2.2% | $5.12 | 3.30% |
| fixture-rework | bash | haiku45 | 1 | 0.8min | 0.1% | $0.05 | 0.03% |
| fixture-rework | bash | opus47-1m-medium | 3 | 2.2min | 0.3% | $0.55 | 0.35% |
| fixture-rework | default | haiku45 | 1 | 3.8min | 0.5% | $0.05 | 0.03% |
| fixture-rework | default | opus47-1m-xhigh | 3 | 1.8min | 0.2% | $0.50 | 0.32% |
| fixture-rework | powershell | opus47-1m-xhigh | 3 | 3.0min | 0.4% | $0.82 | 0.53% |
| fixture-rework | powershell-tool | opus47-1m-medium | 1 | 0.5min | 0.1% | $0.11 | 0.07% |
| fixture-rework | powershell-tool | opus47-1m-xhigh | 2 | 1.8min | 0.2% | $0.60 | 0.39% |
| fixture-rework | typescript-bun | opus47-1m-xhigh | 3 | 2.5min | 0.3% | $0.74 | 0.47% |
| act-push-debug-loops | default | haiku45 | 1 | 2.0min | 0.3% | $0.03 | 0.02% |
| act-push-debug-loops | powershell | haiku45 | 2 | 2.3min | 0.3% | $0.18 | 0.11% |
| act-push-debug-loops | powershell-tool | haiku45 | 2 | 1.4min | 0.2% | $0.09 | 0.06% |
| act-push-debug-loops | typescript-bun | haiku45 | 1 | 0.8min | 0.1% | $0.07 | 0.04% |
| act-push-debug-loops | typescript-bun | opus47-1m-xhigh | 1 | 0.8min | 0.1% | $0.24 | 0.15% |
| mid-run-module-restructure | powershell-tool | opus47-1m-medium | 1 | 2.0min | 0.3% | $0.44 | 0.28% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh | 2 | 4.0min | 0.5% | $1.06 | 0.68% |
| actionlint-fix-cycles | default | haiku45 | 1 | 2.3min | 0.3% | $0.03 | 0.02% |
| actionlint-fix-cycles | powershell | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.03% |
| actionlint-fix-cycles | typescript-bun | haiku45 | 1 | 0.7min | 0.1% | $0.04 | 0.03% |
| pwsh-runtime-install-overhead | powershell | haiku45 | 1 | 0.6min | 0.1% | $0.04 | 0.03% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45 | 1 | 1.1min | 0.1% | $0.07 | 0.05% |
| docker-pwsh-install | powershell | opus47-1m-xhigh | 1 | 1.5min | 0.2% | $0.42 | 0.27% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| fixture-rework | powershell-tool | opus47-1m-medium | 1 | 0.5min | 0.1% | $0.11 | 0.07% |
| pwsh-runtime-install-overhead | powershell | haiku45 | 1 | 0.6min | 0.1% | $0.04 | 0.03% |
| repeated-test-reruns | bash | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.03% |
| repeated-test-reruns | default | opus47-1m-xhigh | 1 | 0.7min | 0.1% | $0.18 | 0.12% |
| repeated-test-reruns | typescript-bun | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.04% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium | 1 | 0.7min | 0.1% | $0.16 | 0.10% |
| actionlint-fix-cycles | powershell | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.03% |
| actionlint-fix-cycles | typescript-bun | haiku45 | 1 | 0.7min | 0.1% | $0.04 | 0.03% |
| fixture-rework | bash | haiku45 | 1 | 0.8min | 0.1% | $0.05 | 0.03% |
| act-push-debug-loops | typescript-bun | haiku45 | 1 | 0.8min | 0.1% | $0.07 | 0.04% |
| act-push-debug-loops | typescript-bun | opus47-1m-xhigh | 1 | 0.8min | 0.1% | $0.24 | 0.15% |
| repeated-test-reruns | bash | opus47-1m-medium | 1 | 1.0min | 0.1% | $0.25 | 0.16% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium | 1 | 1.0min | 0.1% | $0.18 | 0.12% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45 | 1 | 1.1min | 0.1% | $0.07 | 0.05% |
| act-push-debug-loops | powershell-tool | haiku45 | 2 | 1.4min | 0.2% | $0.09 | 0.06% |
| docker-pwsh-install | powershell | opus47-1m-xhigh | 1 | 1.5min | 0.2% | $0.42 | 0.27% |
| repeated-test-reruns | bash | opus47-1m-xhigh | 1 | 1.7min | 0.2% | $0.52 | 0.33% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh | 2 | 1.7min | 0.2% | $0.60 | 0.39% |
| fixture-rework | default | opus47-1m-xhigh | 3 | 1.8min | 0.2% | $0.50 | 0.32% |
| fixture-rework | powershell-tool | opus47-1m-xhigh | 2 | 1.8min | 0.2% | $0.60 | 0.39% |
| mid-run-module-restructure | powershell-tool | opus47-1m-medium | 1 | 2.0min | 0.3% | $0.44 | 0.28% |
| act-push-debug-loops | default | haiku45 | 1 | 2.0min | 0.3% | $0.03 | 0.02% |
| fixture-rework | bash | opus47-1m-medium | 3 | 2.2min | 0.3% | $0.55 | 0.35% |
| actionlint-fix-cycles | default | haiku45 | 1 | 2.3min | 0.3% | $0.03 | 0.02% |
| act-push-debug-loops | powershell | haiku45 | 2 | 2.3min | 0.3% | $0.18 | 0.11% |
| fixture-rework | typescript-bun | opus47-1m-xhigh | 3 | 2.5min | 0.3% | $0.74 | 0.47% |
| repeated-test-reruns | powershell | opus47-1m-medium | 2 | 2.7min | 0.3% | $0.57 | 0.37% |
| fixture-rework | powershell | opus47-1m-xhigh | 3 | 3.0min | 0.4% | $0.82 | 0.53% |
| repeated-test-reruns | powershell | opus47-1m-xhigh | 4 | 3.3min | 0.4% | $0.93 | 0.60% |
| repeated-test-reruns | powershell-tool | haiku45 | 2 | 3.7min | 0.5% | $0.23 | 0.15% |
| fixture-rework | default | haiku45 | 1 | 3.8min | 0.5% | $0.05 | 0.03% |
| repeated-test-reruns | powershell | haiku45 | 3 | 4.0min | 0.5% | $0.34 | 0.22% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh | 2 | 4.0min | 0.5% | $1.06 | 0.68% |
| ts-type-error-fix-cycles | typescript-bun | haiku45 | 2 | 4.4min | 0.6% | $0.32 | 0.21% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium | 7 | 7.6min | 1.0% | $1.31 | 0.85% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh | 5 | 7.7min | 1.0% | $2.28 | 1.47% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh | 7 | 17.2min | 2.2% | $5.12 | 3.30% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| act-push-debug-loops | default | haiku45 | 1 | 2.0min | 0.3% | $0.03 | 0.02% |
| actionlint-fix-cycles | default | haiku45 | 1 | 2.3min | 0.3% | $0.03 | 0.02% |
| actionlint-fix-cycles | typescript-bun | haiku45 | 1 | 0.7min | 0.1% | $0.04 | 0.03% |
| pwsh-runtime-install-overhead | powershell | haiku45 | 1 | 0.6min | 0.1% | $0.04 | 0.03% |
| repeated-test-reruns | bash | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.03% |
| actionlint-fix-cycles | powershell | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.03% |
| fixture-rework | bash | haiku45 | 1 | 0.8min | 0.1% | $0.05 | 0.03% |
| fixture-rework | default | haiku45 | 1 | 3.8min | 0.5% | $0.05 | 0.03% |
| repeated-test-reruns | typescript-bun | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.04% |
| act-push-debug-loops | typescript-bun | haiku45 | 1 | 0.8min | 0.1% | $0.07 | 0.04% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45 | 1 | 1.1min | 0.1% | $0.07 | 0.05% |
| act-push-debug-loops | powershell-tool | haiku45 | 2 | 1.4min | 0.2% | $0.09 | 0.06% |
| fixture-rework | powershell-tool | opus47-1m-medium | 1 | 0.5min | 0.1% | $0.11 | 0.07% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium | 1 | 0.7min | 0.1% | $0.16 | 0.10% |
| act-push-debug-loops | powershell | haiku45 | 2 | 2.3min | 0.3% | $0.18 | 0.11% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium | 1 | 1.0min | 0.1% | $0.18 | 0.12% |
| repeated-test-reruns | default | opus47-1m-xhigh | 1 | 0.7min | 0.1% | $0.18 | 0.12% |
| repeated-test-reruns | powershell-tool | haiku45 | 2 | 3.7min | 0.5% | $0.23 | 0.15% |
| act-push-debug-loops | typescript-bun | opus47-1m-xhigh | 1 | 0.8min | 0.1% | $0.24 | 0.15% |
| repeated-test-reruns | bash | opus47-1m-medium | 1 | 1.0min | 0.1% | $0.25 | 0.16% |
| ts-type-error-fix-cycles | typescript-bun | haiku45 | 2 | 4.4min | 0.6% | $0.32 | 0.21% |
| repeated-test-reruns | powershell | haiku45 | 3 | 4.0min | 0.5% | $0.34 | 0.22% |
| docker-pwsh-install | powershell | opus47-1m-xhigh | 1 | 1.5min | 0.2% | $0.42 | 0.27% |
| mid-run-module-restructure | powershell-tool | opus47-1m-medium | 1 | 2.0min | 0.3% | $0.44 | 0.28% |
| fixture-rework | default | opus47-1m-xhigh | 3 | 1.8min | 0.2% | $0.50 | 0.32% |
| repeated-test-reruns | bash | opus47-1m-xhigh | 1 | 1.7min | 0.2% | $0.52 | 0.33% |
| fixture-rework | bash | opus47-1m-medium | 3 | 2.2min | 0.3% | $0.55 | 0.35% |
| repeated-test-reruns | powershell | opus47-1m-medium | 2 | 2.7min | 0.3% | $0.57 | 0.37% |
| fixture-rework | powershell-tool | opus47-1m-xhigh | 2 | 1.8min | 0.2% | $0.60 | 0.39% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh | 2 | 1.7min | 0.2% | $0.60 | 0.39% |
| fixture-rework | typescript-bun | opus47-1m-xhigh | 3 | 2.5min | 0.3% | $0.74 | 0.47% |
| fixture-rework | powershell | opus47-1m-xhigh | 3 | 3.0min | 0.4% | $0.82 | 0.53% |
| repeated-test-reruns | powershell | opus47-1m-xhigh | 4 | 3.3min | 0.4% | $0.93 | 0.60% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh | 2 | 4.0min | 0.5% | $1.06 | 0.68% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium | 7 | 7.6min | 1.0% | $1.31 | 0.85% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh | 5 | 7.7min | 1.0% | $2.28 | 1.47% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh | 7 | 17.2min | 2.2% | $5.12 | 3.30% |

</details>

<details>
<summary>Sorted by fell-in count (fewest first)</summary>

| Trap | Language | Model | Fell In | Time Lost | % of Time | $ Lost | % of $ |
|------|------|-------|---------|-----------|-----------|--------|--------|
| repeated-test-reruns | bash | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.03% |
| repeated-test-reruns | bash | opus47-1m-medium | 1 | 1.0min | 0.1% | $0.25 | 0.16% |
| repeated-test-reruns | bash | opus47-1m-xhigh | 1 | 1.7min | 0.2% | $0.52 | 0.33% |
| repeated-test-reruns | default | opus47-1m-xhigh | 1 | 0.7min | 0.1% | $0.18 | 0.12% |
| repeated-test-reruns | powershell-tool | opus47-1m-medium | 1 | 1.0min | 0.1% | $0.18 | 0.12% |
| repeated-test-reruns | typescript-bun | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.04% |
| repeated-test-reruns | typescript-bun | opus47-1m-medium | 1 | 0.7min | 0.1% | $0.16 | 0.10% |
| fixture-rework | bash | haiku45 | 1 | 0.8min | 0.1% | $0.05 | 0.03% |
| fixture-rework | default | haiku45 | 1 | 3.8min | 0.5% | $0.05 | 0.03% |
| fixture-rework | powershell-tool | opus47-1m-medium | 1 | 0.5min | 0.1% | $0.11 | 0.07% |
| act-push-debug-loops | default | haiku45 | 1 | 2.0min | 0.3% | $0.03 | 0.02% |
| act-push-debug-loops | typescript-bun | haiku45 | 1 | 0.8min | 0.1% | $0.07 | 0.04% |
| act-push-debug-loops | typescript-bun | opus47-1m-xhigh | 1 | 0.8min | 0.1% | $0.24 | 0.15% |
| mid-run-module-restructure | powershell-tool | opus47-1m-medium | 1 | 2.0min | 0.3% | $0.44 | 0.28% |
| actionlint-fix-cycles | default | haiku45 | 1 | 2.3min | 0.3% | $0.03 | 0.02% |
| actionlint-fix-cycles | powershell | haiku45 | 1 | 0.7min | 0.1% | $0.05 | 0.03% |
| actionlint-fix-cycles | typescript-bun | haiku45 | 1 | 0.7min | 0.1% | $0.04 | 0.03% |
| pwsh-runtime-install-overhead | powershell | haiku45 | 1 | 0.6min | 0.1% | $0.04 | 0.03% |
| pwsh-runtime-install-overhead | powershell-tool | haiku45 | 1 | 1.1min | 0.1% | $0.07 | 0.05% |
| docker-pwsh-install | powershell | opus47-1m-xhigh | 1 | 1.5min | 0.2% | $0.42 | 0.27% |
| repeated-test-reruns | powershell | opus47-1m-medium | 2 | 2.7min | 0.3% | $0.57 | 0.37% |
| repeated-test-reruns | powershell-tool | haiku45 | 2 | 3.7min | 0.5% | $0.23 | 0.15% |
| repeated-test-reruns | powershell-tool | opus47-1m-xhigh | 2 | 1.7min | 0.2% | $0.60 | 0.39% |
| ts-type-error-fix-cycles | typescript-bun | haiku45 | 2 | 4.4min | 0.6% | $0.32 | 0.21% |
| fixture-rework | powershell-tool | opus47-1m-xhigh | 2 | 1.8min | 0.2% | $0.60 | 0.39% |
| act-push-debug-loops | powershell | haiku45 | 2 | 2.3min | 0.3% | $0.18 | 0.11% |
| act-push-debug-loops | powershell-tool | haiku45 | 2 | 1.4min | 0.2% | $0.09 | 0.06% |
| mid-run-module-restructure | powershell-tool | opus47-1m-xhigh | 2 | 4.0min | 0.5% | $1.06 | 0.68% |
| repeated-test-reruns | powershell | haiku45 | 3 | 4.0min | 0.5% | $0.34 | 0.22% |
| fixture-rework | bash | opus47-1m-medium | 3 | 2.2min | 0.3% | $0.55 | 0.35% |
| fixture-rework | default | opus47-1m-xhigh | 3 | 1.8min | 0.2% | $0.50 | 0.32% |
| fixture-rework | powershell | opus47-1m-xhigh | 3 | 3.0min | 0.4% | $0.82 | 0.53% |
| fixture-rework | typescript-bun | opus47-1m-xhigh | 3 | 2.5min | 0.3% | $0.74 | 0.47% |
| repeated-test-reruns | powershell | opus47-1m-xhigh | 4 | 3.3min | 0.4% | $0.93 | 0.60% |
| repeated-test-reruns | typescript-bun | opus47-1m-xhigh | 5 | 7.7min | 1.0% | $2.28 | 1.47% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-medium | 7 | 7.6min | 1.0% | $1.31 | 0.85% |
| ts-type-error-fix-cycles | typescript-bun | opus47-1m-xhigh | 7 | 17.2min | 2.2% | $5.12 | 3.30% |

</details>

#### Trap Descriptions

- **act-push-debug-loops**: Agent ran `act push` more than twice, indicating repeated workflow debugging.
- **actionlint-fix-cycles**: Workflow YAML required 3+ actionlint runs and 2+ fixes to pass.
- **docker-pwsh-install**: Multiple Docker test runs trying to figure out how to install PowerShell in act's container.
- **fixture-rework**: Agent wrote, broke, and rewrote test fixture data (4+ fixture-related commands).
- **mid-run-module-restructure**: Agent restructured from a flat .ps1 script to a .psm1 module mid-run.
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
| bash | haiku45 | 2 | 2 | 1.4min | 0.2% | $0.10 | 0.06% |
| bash | opus47-1m-medium | 7 | 4 | 3.2min | 0.4% | $0.80 | 0.52% |
| bash | opus47-1m-xhigh | 7 | 1 | 1.7min | 0.2% | $0.52 | 0.33% |
| default | haiku45 | 2 | 3 | 8.1min | 1.0% | $0.12 | 0.07% |
| default | opus47-1m-medium | 7 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| default | opus47-1m-xhigh | 7 | 4 | 2.4min | 0.3% | $0.68 | 0.44% |
| powershell | haiku45 | 2 | 7 | 7.6min | 1.0% | $0.61 | 0.39% |
| powershell | opus47-1m-medium | 7 | 2 | 2.7min | 0.3% | $0.57 | 0.37% |
| powershell | opus47-1m-xhigh | 7 | 8 | 7.8min | 1.0% | $2.17 | 1.40% |
| powershell-tool | haiku45 | 2 | 5 | 6.2min | 0.8% | $0.39 | 0.25% |
| powershell-tool | opus47-1m-medium | 7 | 3 | 3.5min | 0.4% | $0.73 | 0.47% |
| powershell-tool | opus47-1m-xhigh | 7 | 6 | 7.4min | 1.0% | $2.26 | 1.46% |
| typescript-bun | haiku45 | 2 | 5 | 6.6min | 0.8% | $0.49 | 0.31% |
| typescript-bun | opus47-1m-medium | 7 | 8 | 8.3min | 1.1% | $1.47 | 0.95% |
| typescript-bun | opus47-1m-xhigh | 7 | 16 | 28.2min | 3.6% | $8.37 | 5.39% |


<details>
<summary>Sorted by time lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m-medium | 7 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | haiku45 | 2 | 2 | 1.4min | 0.2% | $0.10 | 0.06% |
| bash | opus47-1m-xhigh | 7 | 1 | 1.7min | 0.2% | $0.52 | 0.33% |
| default | opus47-1m-xhigh | 7 | 4 | 2.4min | 0.3% | $0.68 | 0.44% |
| powershell | opus47-1m-medium | 7 | 2 | 2.7min | 0.3% | $0.57 | 0.37% |
| bash | opus47-1m-medium | 7 | 4 | 3.2min | 0.4% | $0.80 | 0.52% |
| powershell-tool | opus47-1m-medium | 7 | 3 | 3.5min | 0.4% | $0.73 | 0.47% |
| powershell-tool | haiku45 | 2 | 5 | 6.2min | 0.8% | $0.39 | 0.25% |
| typescript-bun | haiku45 | 2 | 5 | 6.6min | 0.8% | $0.49 | 0.31% |
| powershell-tool | opus47-1m-xhigh | 7 | 6 | 7.4min | 1.0% | $2.26 | 1.46% |
| powershell | haiku45 | 2 | 7 | 7.6min | 1.0% | $0.61 | 0.39% |
| powershell | opus47-1m-xhigh | 7 | 8 | 7.8min | 1.0% | $2.17 | 1.40% |
| default | haiku45 | 2 | 3 | 8.1min | 1.0% | $0.12 | 0.07% |
| typescript-bun | opus47-1m-medium | 7 | 8 | 8.3min | 1.1% | $1.47 | 0.95% |
| typescript-bun | opus47-1m-xhigh | 7 | 16 | 28.2min | 3.6% | $8.37 | 5.39% |

</details>

<details>
<summary>Sorted by $ lost (least first)</summary>

| Language | Model | Runs | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|-------|-----------|-----------|--------|--------|
| default | opus47-1m-medium | 7 | 0 | 0.0min | 0.0% | $0.00 | 0.00% |
| bash | haiku45 | 2 | 2 | 1.4min | 0.2% | $0.10 | 0.06% |
| default | haiku45 | 2 | 3 | 8.1min | 1.0% | $0.12 | 0.07% |
| powershell-tool | haiku45 | 2 | 5 | 6.2min | 0.8% | $0.39 | 0.25% |
| typescript-bun | haiku45 | 2 | 5 | 6.6min | 0.8% | $0.49 | 0.31% |
| bash | opus47-1m-xhigh | 7 | 1 | 1.7min | 0.2% | $0.52 | 0.33% |
| powershell | opus47-1m-medium | 7 | 2 | 2.7min | 0.3% | $0.57 | 0.37% |
| powershell | haiku45 | 2 | 7 | 7.6min | 1.0% | $0.61 | 0.39% |
| default | opus47-1m-xhigh | 7 | 4 | 2.4min | 0.3% | $0.68 | 0.44% |
| powershell-tool | opus47-1m-medium | 7 | 3 | 3.5min | 0.4% | $0.73 | 0.47% |
| bash | opus47-1m-medium | 7 | 4 | 3.2min | 0.4% | $0.80 | 0.52% |
| typescript-bun | opus47-1m-medium | 7 | 8 | 8.3min | 1.1% | $1.47 | 0.95% |
| powershell | opus47-1m-xhigh | 7 | 8 | 7.8min | 1.0% | $2.17 | 1.40% |
| powershell-tool | opus47-1m-xhigh | 7 | 6 | 7.4min | 1.0% | $2.26 | 1.46% |
| typescript-bun | opus47-1m-xhigh | 7 | 16 | 28.2min | 3.6% | $8.37 | 5.39% |

</details>

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 0 | $0.00 | 0.00% |
| Partial | 75 | $6.65 | 4.28% |
| Miss | 5 | $0.00 | 0.00% |

## Test Quality Evaluation

### Structural Metrics by Language/Model/Effort

Automated analysis of test files: test count, assertion count, and test-to-code line ratio.

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| bash | haiku45 | 12.5 | 19.5 | 1.6 | 0.46 |
| bash | opus47-1m-medium | 11.9 | 31.7 | 2.7 | 1.21 |
| bash | opus47-1m-xhigh | 25.9 | 47.3 | 1.8 | 1.26 |
| default | haiku45 | 10.5 | 14.0 | 1.3 | 0.81 |
| default | opus47-1m-medium | 17.0 | 33.3 | 2.0 | 1.64 |
| default | opus47-1m-xhigh | 24.0 | 50.6 | 2.1 | 1.55 |
| powershell | haiku45 | 5.0 | 6.5 | 1.3 | 0.38 |
| powershell | opus47-1m-medium | 20.0 | 38.9 | 1.9 | 3.38 |
| powershell | opus47-1m-xhigh | 28.1 | 56.7 | 2.0 | 0.99 |
| powershell-tool | haiku45 | 6.5 | 9.5 | 1.5 | 0.73 |
| powershell-tool | opus47-1m-medium | 18.9 | 40.6 | 2.2 | 3.47 |
| powershell-tool | opus47-1m-xhigh | 29.3 | 53.7 | 1.8 | 3.37 |
| typescript-bun | haiku45 | 20.5 | 36.0 | 1.8 | 0.36 |
| typescript-bun | opus47-1m-medium | 18.0 | 42.0 | 2.3 | 1.54 |
| typescript-bun | opus47-1m-xhigh | 30.7 | 65.6 | 2.1 | 1.73 |


<details>
<summary>Sorted by avg tests (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m-xhigh | 30.7 | 65.6 | 2.1 | 1.73 |
| powershell-tool | opus47-1m-xhigh | 29.3 | 53.7 | 1.8 | 3.37 |
| powershell | opus47-1m-xhigh | 28.1 | 56.7 | 2.0 | 0.99 |
| bash | opus47-1m-xhigh | 25.9 | 47.3 | 1.8 | 1.26 |
| default | opus47-1m-xhigh | 24.0 | 50.6 | 2.1 | 1.55 |
| typescript-bun | haiku45 | 20.5 | 36.0 | 1.8 | 0.36 |
| powershell | opus47-1m-medium | 20.0 | 38.9 | 1.9 | 3.38 |
| powershell-tool | opus47-1m-medium | 18.9 | 40.6 | 2.2 | 3.47 |
| typescript-bun | opus47-1m-medium | 18.0 | 42.0 | 2.3 | 1.54 |
| default | opus47-1m-medium | 17.0 | 33.3 | 2.0 | 1.64 |
| bash | haiku45 | 12.5 | 19.5 | 1.6 | 0.46 |
| bash | opus47-1m-medium | 11.9 | 31.7 | 2.7 | 1.21 |
| default | haiku45 | 10.5 | 14.0 | 1.3 | 0.81 |
| powershell-tool | haiku45 | 6.5 | 9.5 | 1.5 | 0.73 |
| powershell | haiku45 | 5.0 | 6.5 | 1.3 | 0.38 |

</details>

<details>
<summary>Sorted by avg assertions (most first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| typescript-bun | opus47-1m-xhigh | 30.7 | 65.6 | 2.1 | 1.73 |
| powershell | opus47-1m-xhigh | 28.1 | 56.7 | 2.0 | 0.99 |
| powershell-tool | opus47-1m-xhigh | 29.3 | 53.7 | 1.8 | 3.37 |
| default | opus47-1m-xhigh | 24.0 | 50.6 | 2.1 | 1.55 |
| bash | opus47-1m-xhigh | 25.9 | 47.3 | 1.8 | 1.26 |
| typescript-bun | opus47-1m-medium | 18.0 | 42.0 | 2.3 | 1.54 |
| powershell-tool | opus47-1m-medium | 18.9 | 40.6 | 2.2 | 3.47 |
| powershell | opus47-1m-medium | 20.0 | 38.9 | 1.9 | 3.38 |
| typescript-bun | haiku45 | 20.5 | 36.0 | 1.8 | 0.36 |
| default | opus47-1m-medium | 17.0 | 33.3 | 2.0 | 1.64 |
| bash | opus47-1m-medium | 11.9 | 31.7 | 2.7 | 1.21 |
| bash | haiku45 | 12.5 | 19.5 | 1.6 | 0.46 |
| default | haiku45 | 10.5 | 14.0 | 1.3 | 0.81 |
| powershell-tool | haiku45 | 6.5 | 9.5 | 1.5 | 0.73 |
| powershell | haiku45 | 5.0 | 6.5 | 1.3 | 0.38 |

</details>

<details>
<summary>Sorted by avg test:code ratio (highest first)</summary>

| Language | Model | Avg Tests | Avg Assertions | Avg Assert/Test | Avg Test:Code Ratio |
|------|-------|-----------|----------------|-----------------|---------------------|
| powershell-tool | opus47-1m-medium | 18.9 | 40.6 | 2.2 | 3.47 |
| powershell | opus47-1m-medium | 20.0 | 38.9 | 1.9 | 3.38 |
| powershell-tool | opus47-1m-xhigh | 29.3 | 53.7 | 1.8 | 3.37 |
| typescript-bun | opus47-1m-xhigh | 30.7 | 65.6 | 2.1 | 1.73 |
| default | opus47-1m-medium | 17.0 | 33.3 | 2.0 | 1.64 |
| default | opus47-1m-xhigh | 24.0 | 50.6 | 2.1 | 1.55 |
| typescript-bun | opus47-1m-medium | 18.0 | 42.0 | 2.3 | 1.54 |
| bash | opus47-1m-xhigh | 25.9 | 47.3 | 1.8 | 1.26 |
| bash | opus47-1m-medium | 11.9 | 31.7 | 2.7 | 1.21 |
| powershell | opus47-1m-xhigh | 28.1 | 56.7 | 2.0 | 0.99 |
| default | haiku45 | 10.5 | 14.0 | 1.3 | 0.81 |
| powershell-tool | haiku45 | 6.5 | 9.5 | 1.5 | 0.73 |
| bash | haiku45 | 12.5 | 19.5 | 1.6 | 0.46 |
| powershell | haiku45 | 5.0 | 6.5 | 1.3 | 0.38 |
| typescript-bun | haiku45 | 20.5 | 36.0 | 1.8 | 0.36 |

</details>


<details>
<summary>Per-run structural metrics</summary>

| Task | Language | Model | Tests | Assertions | Assert/Test | Test Lines | Impl Lines | Test:Code |
|------|------|-------|-------|------------|-------------|------------|------------|-----------|
| Semantic Version Bumper | bash | opus47-1m-medium | 6 | 7 | 1.2 | 96 | 152 | 0.63 |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 35 | 67 | 1.9 | 374 | 298 | 1.26 |
| Semantic Version Bumper | default | opus47-1m-medium | 22 | 39 | 1.8 | 319 | 180 | 1.77 |
| Semantic Version Bumper | default | opus47-1m-xhigh | 30 | 70 | 2.3 | 505 | 280 | 1.80 |
| Semantic Version Bumper | powershell | opus47-1m-medium | 36 | 66 | 1.8 | 315 | 54 | 5.83 |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 27 | 46 | 1.7 | 261 | 248 | 1.05 |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 31 | 56 | 1.8 | 243 | 22 | 11.05 |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 33 | 54 | 1.6 | 396 | 42 | 9.43 |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 23 | 49 | 2.1 | 279 | 248 | 1.12 |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 45 | 95 | 2.1 | 805 | 504 | 1.60 |
| PR Label Assigner | bash | opus47-1m-medium | 16 | 31 | 1.9 | 201 | 136 | 1.48 |
| PR Label Assigner | bash | opus47-1m-xhigh | 28 | 43 | 1.5 | 303 | 360 | 0.84 |
| PR Label Assigner | default | opus47-1m-medium | 0 | 9 | 0.0 | 194 | 132 | 1.47 |
| PR Label Assigner | default | opus47-1m-xhigh | 27 | 43 | 1.6 | 431 | 224 | 1.92 |
| PR Label Assigner | powershell | opus47-1m-medium | 22 | 23 | 1.0 | 153 | 229 | 0.67 |
| PR Label Assigner | powershell | opus47-1m-xhigh | 39 | 47 | 1.2 | 319 | 386 | 0.83 |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 27 | 49 | 1.8 | 315 | 39 | 8.08 |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 31 | 62 | 2.0 | 324 | 202 | 1.60 |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 16 | 35 | 2.2 | 271 | 138 | 1.96 |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 32 | 51 | 1.6 | 620 | 263 | 2.36 |
| Dependency License Checker | bash | opus47-1m-medium | 10 | 43 | 4.3 | 169 | 174 | 0.97 |
| Dependency License Checker | bash | opus47-1m-xhigh | 14 | 14 | 1.0 | 152 | 171 | 0.89 |
| Dependency License Checker | default | opus47-1m-medium | 21 | 35 | 1.7 | 400 | 166 | 2.41 |
| Dependency License Checker | default | opus47-1m-xhigh | 24 | 36 | 1.5 | 284 | 578 | 0.49 |
| Dependency License Checker | powershell | opus47-1m-medium | 11 | 24 | 2.2 | 127 | 208 | 0.61 |
| Dependency License Checker | powershell | opus47-1m-xhigh | 22 | 79 | 3.6 | 456 | 277 | 1.65 |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 11 | 23 | 2.1 | 116 | 250 | 0.46 |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 19 | 32 | 1.7 | 223 | 440 | 0.51 |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 16 | 32 | 2.0 | 343 | 166 | 2.07 |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 29 | 50 | 1.7 | 402 | 559 | 0.72 |
| Test Results Aggregator | bash | opus47-1m-medium | 11 | 46 | 4.2 | 237 | 189 | 1.25 |
| Test Results Aggregator | bash | opus47-1m-xhigh | 37 | 95 | 2.6 | 385 | 101 | 3.81 |
| Test Results Aggregator | default | opus47-1m-medium | 19 | 43 | 2.3 | 353 | 185 | 1.91 |
| Test Results Aggregator | default | opus47-1m-xhigh | 30 | 70 | 2.3 | 543 | 334 | 1.63 |
| Test Results Aggregator | powershell | opus47-1m-medium | 17 | 46 | 2.7 | 294 | 21 | 14.00 |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 27 | 73 | 2.7 | 343 | 372 | 0.92 |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 20 | 45 | 2.2 | 202 | 179 | 1.13 |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 37 | 65 | 1.8 | 337 | 265 | 1.27 |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 17 | 42 | 2.5 | 379 | 244 | 1.55 |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 33 | 88 | 2.7 | 658 | 481 | 1.37 |
| Environment Matrix Generator | bash | opus47-1m-medium | 19 | 38 | 2.0 | 221 | 90 | 2.46 |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 27 | 30 | 1.1 | 186 | 304 | 0.61 |
| Environment Matrix Generator | default | opus47-1m-medium | 20 | 27 | 1.4 | 281 | 337 | 0.83 |
| Environment Matrix Generator | default | opus47-1m-xhigh | 23 | 35 | 1.5 | 283 | 202 | 1.40 |
| Environment Matrix Generator | powershell | opus47-1m-medium | 24 | 49 | 2.0 | 252 | 267 | 0.94 |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 39 | 54 | 1.4 | 334 | 411 | 0.81 |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 11 | 18 | 1.6 | 129 | 150 | 0.86 |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 42 | 59 | 1.4 | 294 | 437 | 0.67 |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 13 | 38 | 2.9 | 238 | 145 | 1.64 |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 31 | 59 | 1.9 | 622 | 305 | 2.04 |
| Artifact Cleanup Script | bash | opus47-1m-medium | 16 | 36 | 2.2 | 223 | 199 | 1.12 |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 15 | 63 | 4.2 | 183 | 398 | 0.46 |
| Artifact Cleanup Script | default | opus47-1m-medium | 16 | 37 | 2.3 | 293 | 196 | 1.49 |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 18 | 39 | 2.2 | 525 | 321 | 1.64 |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 9 | 18 | 2.0 | 133 | 166 | 0.80 |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 19 | 44 | 2.3 | 267 | 374 | 0.71 |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 8 | 25 | 3.1 | 135 | 186 | 0.73 |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 17 | 35 | 2.1 | 205 | 373 | 0.55 |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 21 | 56 | 2.7 | 271 | 334 | 0.81 |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 18 | 40 | 2.2 | 459 | 271 | 1.69 |
| Secret Rotation Validator | bash | opus47-1m-medium | 5 | 21 | 4.2 | 120 | 209 | 0.57 |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 25 | 19 | 0.8 | 258 | 280 | 0.92 |
| Secret Rotation Validator | default | opus47-1m-medium | 21 | 43 | 2.0 | 397 | 244 | 1.63 |
| Secret Rotation Validator | default | opus47-1m-xhigh | 16 | 61 | 3.8 | 645 | 330 | 1.95 |
| Secret Rotation Validator | powershell | opus47-1m-medium | 21 | 46 | 2.2 | 184 | 225 | 0.82 |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 24 | 54 | 2.2 | 315 | 326 | 0.97 |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 24 | 68 | 2.8 | 310 | 159 | 1.95 |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 26 | 69 | 2.7 | 468 | 49 | 9.55 |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 20 | 42 | 2.1 | 349 | 213 | 1.64 |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 27 | 76 | 2.8 | 820 | 354 | 2.32 |
| Semantic Version Bumper | default | haiku45 | 0 | 0 | 0.0 | 0 | 270 | 0.00 |
| Semantic Version Bumper | powershell | haiku45 | 0 | 0 | 0.0 | 0 | 702 | 0.00 |
| Semantic Version Bumper | powershell-tool | haiku45 | 0 | 0 | 0.0 | 0 | 711 | 0.00 |
| Semantic Version Bumper | bash | haiku45 | 12 | 14 | 1.2 | 165 | 580 | 0.28 |
| Semantic Version Bumper | typescript-bun | haiku45 | 31 | 55 | 1.8 | 287 | 690 | 0.42 |
| PR Label Assigner | default | haiku45 | 21 | 28 | 1.3 | 255 | 156 | 1.63 |
| PR Label Assigner | powershell | haiku45 | 10 | 13 | 1.3 | 107 | 142 | 0.75 |
| PR Label Assigner | powershell-tool | haiku45 | 13 | 19 | 1.5 | 189 | 129 | 1.47 |
| PR Label Assigner | bash | haiku45 | 13 | 25 | 1.9 | 241 | 381 | 0.63 |
| PR Label Assigner | typescript-bun | haiku45 | 10 | 17 | 1.7 | 120 | 384 | 0.31 |

</details>

### LLM-as-Judge Scores

An LLM evaluates each test suite on four dimensions (1-5 scale):

- **Coverage** (1-5): Do tests exercise the key requirements? 1 = most untested, 5 = all covered.
- **Rigor** (1-5): Edge cases, error handling, boundary conditions? 1 = happy path only, 5 = thorough.
- **Design** (1-5): Test organization, fixtures, readability? 1 = messy/brittle, 5 = well-structured.
- **Overall** (1-5): Holistic quality — would you trust this suite to catch regressions? 1 = no, 5 = absolutely. Use this as the primary ranking metric.

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| bash | opus47-1m-medium | **2.6** | 3.3 | 2.4 | 2.9 | $0.4305 |
| bash | opus47-1m-xhigh | **3.6** | 4.0 | 3.0 | 3.6 | $0.4323 |
| default | opus47-1m-medium | **3.3** | 3.7 | 2.9 | 3.7 | $0.4655 |
| default | opus47-1m-xhigh | **3.9** | 4.1 | 3.3 | 4.0 | $0.5248 |
| powershell | opus47-1m-medium | **3.6** | 4.0 | 3.1 | 3.7 | $0.4241 |
| powershell | opus47-1m-xhigh | **3.9** | 4.1 | 3.6 | 3.9 | $0.5354 |
| powershell-tool | opus47-1m-medium | **3.4** | 4.0 | 3.3 | 3.6 | $0.4090 |
| powershell-tool | opus47-1m-xhigh | **3.9** | 4.1 | 3.4 | 3.9 | $0.5091 |
| typescript-bun | opus47-1m-medium | **3.4** | 3.9 | 3.0 | 3.7 | $0.4425 |
| typescript-bun | opus47-1m-xhigh | **4.0** | 4.6 | 3.6 | 4.3 | $0.6243 |
| **Total** | | | | | | **$4.7975** |


<details>
<summary>Sorted by avg overall (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| typescript-bun | opus47-1m-xhigh | **4.0** | 4.6 | 3.6 | 4.3 | $0.6243 |
| default | opus47-1m-xhigh | **3.9** | 4.1 | 3.3 | 4.0 | $0.5248 |
| powershell | opus47-1m-xhigh | **3.9** | 4.1 | 3.6 | 3.9 | $0.5354 |
| powershell-tool | opus47-1m-xhigh | **3.9** | 4.1 | 3.4 | 3.9 | $0.5091 |
| bash | opus47-1m-xhigh | **3.6** | 4.0 | 3.0 | 3.6 | $0.4323 |
| powershell | opus47-1m-medium | **3.6** | 4.0 | 3.1 | 3.7 | $0.4241 |
| powershell-tool | opus47-1m-medium | **3.4** | 4.0 | 3.3 | 3.6 | $0.4090 |
| typescript-bun | opus47-1m-medium | **3.4** | 3.9 | 3.0 | 3.7 | $0.4425 |
| default | opus47-1m-medium | **3.3** | 3.7 | 2.9 | 3.7 | $0.4655 |
| bash | opus47-1m-medium | **2.6** | 3.3 | 2.4 | 2.9 | $0.4305 |

</details>

<details>
<summary>Sorted by avg coverage (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| typescript-bun | opus47-1m-xhigh | **4.0** | 4.6 | 3.6 | 4.3 | $0.6243 |
| default | opus47-1m-xhigh | **3.9** | 4.1 | 3.3 | 4.0 | $0.5248 |
| powershell | opus47-1m-xhigh | **3.9** | 4.1 | 3.6 | 3.9 | $0.5354 |
| powershell-tool | opus47-1m-xhigh | **3.9** | 4.1 | 3.4 | 3.9 | $0.5091 |
| bash | opus47-1m-xhigh | **3.6** | 4.0 | 3.0 | 3.6 | $0.4323 |
| powershell | opus47-1m-medium | **3.6** | 4.0 | 3.1 | 3.7 | $0.4241 |
| powershell-tool | opus47-1m-medium | **3.4** | 4.0 | 3.3 | 3.6 | $0.4090 |
| typescript-bun | opus47-1m-medium | **3.4** | 3.9 | 3.0 | 3.7 | $0.4425 |
| default | opus47-1m-medium | **3.3** | 3.7 | 2.9 | 3.7 | $0.4655 |
| bash | opus47-1m-medium | **2.6** | 3.3 | 2.4 | 2.9 | $0.4305 |

</details>

<details>
<summary>Sorted by avg rigor (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| powershell | opus47-1m-xhigh | **3.9** | 4.1 | 3.6 | 3.9 | $0.5354 |
| typescript-bun | opus47-1m-xhigh | **4.0** | 4.6 | 3.6 | 4.3 | $0.6243 |
| powershell-tool | opus47-1m-xhigh | **3.9** | 4.1 | 3.4 | 3.9 | $0.5091 |
| default | opus47-1m-xhigh | **3.9** | 4.1 | 3.3 | 4.0 | $0.5248 |
| powershell-tool | opus47-1m-medium | **3.4** | 4.0 | 3.3 | 3.6 | $0.4090 |
| powershell | opus47-1m-medium | **3.6** | 4.0 | 3.1 | 3.7 | $0.4241 |
| bash | opus47-1m-xhigh | **3.6** | 4.0 | 3.0 | 3.6 | $0.4323 |
| typescript-bun | opus47-1m-medium | **3.4** | 3.9 | 3.0 | 3.7 | $0.4425 |
| default | opus47-1m-medium | **3.3** | 3.7 | 2.9 | 3.7 | $0.4655 |
| bash | opus47-1m-medium | **2.6** | 3.3 | 2.4 | 2.9 | $0.4305 |

</details>

<details>
<summary>Sorted by avg design (highest first)</summary>

| Language | Model | Avg Overall | Avg Coverage | Avg Rigor | Avg Design | Judge Cost |
|------|-------|-------------|-------------|-----------|------------|------------|
| typescript-bun | opus47-1m-xhigh | **4.0** | 4.6 | 3.6 | 4.3 | $0.6243 |
| default | opus47-1m-xhigh | **3.9** | 4.1 | 3.3 | 4.0 | $0.5248 |
| powershell | opus47-1m-xhigh | **3.9** | 4.1 | 3.6 | 3.9 | $0.5354 |
| powershell-tool | opus47-1m-xhigh | **3.9** | 4.1 | 3.4 | 3.9 | $0.5091 |
| default | opus47-1m-medium | **3.3** | 3.7 | 2.9 | 3.7 | $0.4655 |
| powershell | opus47-1m-medium | **3.6** | 4.0 | 3.1 | 3.7 | $0.4241 |
| typescript-bun | opus47-1m-medium | **3.4** | 3.9 | 3.0 | 3.7 | $0.4425 |
| bash | opus47-1m-xhigh | **3.6** | 4.0 | 3.0 | 3.6 | $0.4323 |
| powershell-tool | opus47-1m-medium | **3.4** | 4.0 | 3.3 | 3.6 | $0.4090 |
| bash | opus47-1m-medium | **2.6** | 3.3 | 2.4 | 2.9 | $0.4305 |

</details>


<details>
<summary>Per-run LLM judge scores</summary>

| Task | Language | Model | Cov | Rig | Des | Ovr | Summary |
|------|------|-------|-----|-----|-----|-----|---------|
| Semantic Version Bumper | bash | opus47-1m-medium | 3 | 2 | 2 | 2 | The suite covers the three core bump scenarios (feat->minor, |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 4 | 3 | 3 | 3 | The suite covers all major functional areas well: every publ |
| Semantic Version Bumper | default | opus47-1m-medium | 4 | 3 | 4 | 4 | The test suite covers all major requirements: reading versio |
| Semantic Version Bumper | default | opus47-1m-xhigh | 5 | 4 | 4 | 4 | The test suite is comprehensive and well-structured. Coverag |
| Semantic Version Bumper | powershell | opus47-1m-medium | 5 | 4 | 4 | 4 | The test suite is comprehensive and covers all major require |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 4 | 4 | 4 | 4 | The test suite is well-rounded and covers all key requiremen |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 5 | 4 | 3 | 4 | The test suite covers all stated requirements comprehensivel |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The test suite comprehensively covers the core requirements: |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 4 | 3 | 4 | 4 | The test suite is well-layered across three tiers (unit, int |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 5 | 4 | 5 | 4 | This is a thorough, well-organized test suite that covers ev |
| PR Label Assigner | bash | opus47-1m-medium | 4 | 3 | 3 | 3 | The suite covers the core requirements well: glob matching ( |
| PR Label Assigner | bash | opus47-1m-xhigh | 5 | 4 | 4 | 4 | The test suite is comprehensive and well-structured. label_a |
| PR Label Assigner | default | opus47-1m-medium | 2 | 2 | 3 | 2 | The test suite is a pure integration harness that routes eve |
| PR Label Assigner | default | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The test suite is well-rounded and covers the core requireme |
| PR Label Assigner | powershell | opus47-1m-medium | 4 | 3 | 4 | 4 | The test suite covers the core requirements well: glob patte |
| PR Label Assigner | powershell | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The test suite is well-organized and covers the core require |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 4 | 4 | 4 | 4 | The test suite is strong and covers the primary requirements |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 5 | 4 | 4 | 4 | The test suite is comprehensive and well-structured. Coverag |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 4 | 3 | 4 | 3 | The test suite covers the core requirements well: glob match |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 5 | 4 | 4 | 4 | The test suite is impressively comprehensive, covering all m |
| Dependency License Checker | bash | opus47-1m-medium | 3 | 2 | 3 | 2 | The suite covers the main happy-path scenarios (package.json |
| Dependency License Checker | bash | opus47-1m-xhigh | 3 | 2 | 3 | 3 | The suite covers the three main license-status scenarios (AP |
| Dependency License Checker | default | opus47-1m-medium | 4 | 3 | 4 | 4 | The test suite is thorough across its stated layers. Unit te |
| Dependency License Checker | default | opus47-1m-xhigh | 5 | 4 | 5 | 4 | The test suite is comprehensive and well-structured, followi |
| Dependency License Checker | powershell | opus47-1m-medium | 3 | 3 | 3 | 3 | The test suite covers the core requirements reasonably well: |
| Dependency License Checker | powershell | opus47-1m-xhigh | 4 | 4 | 4 | 4 | The test suite is comprehensive and well-structured across t |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 3 | 3 | 4 | 3 | The Pester suite covers the four core functions (Get-Depende |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 4 | 4 | 4 | 4 | The Pester suite thoroughly covers the three core module fun |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 3 | 3 | 4 | 3 | The suite is well-organized across three purposeful files (u |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The test suite achieves strong coverage across all key requi |
| Test Results Aggregator | bash | opus47-1m-medium | 3 | 2 | 3 | 3 | The unit tests in aggregate.bats cover the main happy paths  |
| Test Results Aggregator | bash | opus47-1m-xhigh | 4 | 4 | 4 | 4 | The test suite is comprehensive and well-structured, coverin |
| Test Results Aggregator | default | opus47-1m-medium | 4 | 3 | 4 | 4 | The suite covers all six core requirements (JUnit XML parsin |
| Test Results Aggregator | default | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The test suite does a solid job covering the core requiremen |
| Test Results Aggregator | powershell | opus47-1m-medium | 4 | 3 | 4 | 4 | The suite covers all major requirements — JUnit XML parsing, |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 4 | 4 | 3 | 4 | The suite covers all major requirements with a commendable t |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 4 | 3 | 3 | 3 | The suite covers all six major functional areas (JUnit parsi |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 4 | 3 | 3 | 3 | The test suite covers the main module functions (XML parsing |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 4 | 3 | 3 | 3 | The suite covers all six core requirements (XML parsing, JSO |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 4 | 3 | 5 | 4 | The test suite is well-structured and covers all major requi |
| Environment Matrix Generator | bash | opus47-1m-medium | 4 | 3 | 3 | 3 | The suite covers most core requirements well: cartesian prod |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The test suite demonstrates solid breadth across the require |
| Environment Matrix Generator | default | opus47-1m-medium | 4 | 3 | 3 | 3 | The suite covers the primary requirements well: cartesian pr |
| Environment Matrix Generator | default | opus47-1m-xhigh | 3 | 3 | 4 | 3 | The unit-test layer covers the core Python API well: cartesi |
| Environment Matrix Generator | powershell | opus47-1m-medium | 4 | 3 | 3 | 3 | The unit tests cover all the main functional requirements —  |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 4 | 3 | 3 | 3 | The unit test suite in MatrixGenerator.Tests.ps1 covers the  |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4 | 3 | 4 | 3 | The test suite covers the core module's main functional requ |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 4 | 4 | 4 | 4 | The test suite is comprehensive and well-structured. Coverag |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 4 | 3 | 3 | 3 | The unit test suite in matrix.test.ts covers the core requir |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 5 | 4 | 4 | 4 | This is a strong, layered test suite that genuinely covers a |
| Artifact Cleanup Script | bash | opus47-1m-medium | 4 | 3 | 3 | 3 | The unit test suite (cleanup.bats) covers all three retentio |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 5 | 3 | 4 | 4 | The suite covers all five major requirement areas: all three |
| Artifact Cleanup Script | default | opus47-1m-medium | 4 | 3 | 4 | 3 | The suite covers all three retention policies (max_age, keep |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 4 | 3 | 3 | 4 | The unit test suite covers all three retention rules (max_ag |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4 | 3 | 4 | 3 | The test suite covers all four primary retention policies (a |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The test suite covers all major requirements: MaxAgeDays, Ma |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4 | 3 | 4 | 4 | The suite covers all five core policy requirements (max age, |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The suite covers all primary requirements well: each policy  |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 4 | 3 | 4 | 4 | The test suite covers all three retention policies (maxAgeDa |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The suite covers all three retention policies (max-age, keep |
| Secret Rotation Validator | bash | opus47-1m-medium | 2 | 2 | 3 | 2 | The suite has three functional act-based test cases (mixed,  |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 3 | 2 | 3 | 3 | The test suite demonstrates a thoughtful architecture that s |
| Secret Rotation Validator | default | opus47-1m-medium | 4 | 3 | 4 | 3 | The test suite covers the main functional requirements well: |
| Secret Rotation Validator | default | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The suite combines well-focused unit tests (classify_secret, |
| Secret Rotation Validator | powershell | opus47-1m-medium | 4 | 3 | 4 | 4 | The suite covers the main functional requirements well: secr |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 5 | 4 | 5 | 4 | The test suite is comprehensive and well-structured. Coverag |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 4 | 3 | 3 | 3 | The unit tests cover all major functional requirements well: |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 4 | 3 | 4 | 4 | The test suite covers most task requirements well: secret st |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 4 | 3 | 4 | 4 | The suite covers all major functional requirements — classif |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 5 | 4 | 4 | 4 | The test suite is thorough and well-layered: unit tests (val |

</details>

### Correlation: Structural Metrics vs LLM Scores

Spearman rank correlation between automated counts and LLM judge scores.
Values near +1.0 indicate the LLM agrees with the structural signal; near 0 means no relationship.

| Structural Metric | vs Coverage | vs Rigor | vs Design | vs Overall |
|-------------------|------------|---------|----------|-----------|
| Test count | 0.55 | 0.6 | 0.31 | 0.52 |
| Assertion count | 0.55 | 0.54 | 0.26 | 0.5 |
| Test:code ratio | 0.25 | 0.24 | 0.07 | 0.18 |

*Based on 70 runs with both structural and LLM scores.*

### LLM vs Structural Discrepancies

**Qualitative disagreements** — structural metrics look reasonable; the LLM judge is weighing factors the counters can't measure.

| Task | Language | Model | Tests | Asserts | Cov | Rig | Des | Ovr | Flag | Justification |
|------|------|-------|-------|---------|-----|-----|-----|-----|------|---------------|
| Dependency License Checker | bash | opus47-1m-medium | 10 | 43 | 3 | 2 | 3 | 2 | LLM says low rigor (2/5) but 43 assertions detected | The suite covers the main happy-path scenarios (package.json with mixed statuses, requirements.txt with mixed statuses, all-approved) through act-based e2e tests, and adds genuine value with struct... |
| Test Results Aggregator | bash | opus47-1m-medium | 11 | 46 | 3 | 2 | 3 | 3 | LLM says low rigor (2/5) but 46 assertions detected | The unit tests in aggregate.bats cover the main happy paths for all four subcommands (parse_junit, parse_json, aggregate, summary) plus one error case (missing file for parse_junit) and an unknown-... |

## Per-Run Results

*LLM Score = Overall (1-5) from LLM-as-judge of generated test code (dimensions: coverage, rigor, design). `—` = no judge data.*

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | 3.0 | bash | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | 4.0 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | 3.0 | python | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | 3.0 | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | 4.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | 4.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | 4.0 | typescript | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | 2.0 | bash | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | 3.0 | bash | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | 4.0 | python | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | 3.0 | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | 3.0 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | 3.0 | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | 4.0 | typescript | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | 3.0 | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | 4.0 | bash | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | 3.0 | python | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | 3.0 | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | 3.0 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | 3.0 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | 3.0 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | 4.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | 3.0 | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | 4.0 | typescript | ok |
| PR Label Assigner | bash | haiku45 | 7.1min | 62 | 4 | $0.50 | — | bash | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | 3.0 | bash | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | 4.0 | bash | ok |
| PR Label Assigner | default | haiku45 | 2.9min | 27 | 3 | $0.25 | — | python | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | 2.0 | python | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | 4.0 | python | ok |
| PR Label Assigner | powershell | haiku45 | 5.2min | 44 | 1 | $0.38 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45 | 3.0min | 26 | 1 | $0.23 | — | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45 | 6.0min | 43 | 2 | $0.37 | — | typescript | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | 3.0 | typescript | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | 4.0 | typescript | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | 2.0 | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | 3.0 | python | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | 3.0 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | 4.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 7.4min | 35 | 2 | $1.46 | 4.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | 4.0 | typescript | ok |
| Semantic Version Bumper | bash | haiku45 | 6.3min | 48 | 1 | $0.45 | — | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | 2.0 | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | 3.0 | bash | ok |
| Semantic Version Bumper | default | haiku45 | 59.1min | 97 | 12 | $0.84 | — | javascript | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | 4.0 | python | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | haiku45 | 6.3min | 65 | 4 | $0.57 | — | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45 | 15.1min | 92 | 7 | $0.93 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | 4.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45 | 7.6min | 74 | 10 | $0.62 | — | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | 4.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | 4.0 | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | 3.0 | bash | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | 4.0 | bash | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | 4.0 | python | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | 4.0 | python | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | 3.0 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | 3.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | 3.0 | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | 4.0 | typescript | ok |


<details>
<summary>Sorted by cost (cheapest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | powershell-tool | haiku45 | 3.0min | 26 | 1 | $0.23 | — | powershell | ok |
| PR Label Assigner | default | haiku45 | 2.9min | 27 | 3 | $0.25 | — | python | ok |
| PR Label Assigner | typescript-bun | haiku45 | 6.0min | 43 | 2 | $0.37 | — | typescript | ok |
| PR Label Assigner | powershell | haiku45 | 5.2min | 44 | 1 | $0.38 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45 | 6.3min | 48 | 1 | $0.45 | — | bash | ok |
| PR Label Assigner | bash | haiku45 | 7.1min | 62 | 4 | $0.50 | — | bash | ok |
| Semantic Version Bumper | powershell | haiku45 | 6.3min | 65 | 4 | $0.57 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45 | 7.6min | 74 | 10 | $0.62 | — | typescript | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | 2.0 | python | ok |
| Semantic Version Bumper | default | haiku45 | 59.1min | 97 | 12 | $0.84 | — | javascript | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | 3.0 | python | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | 3.0 | bash | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | 3.0 | python | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | 3.0 | bash | ok |
| Semantic Version Bumper | powershell-tool | haiku45 | 15.1min | 92 | 7 | $0.93 | — | powershell | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | 4.0 | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | 3.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | 3.0 | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | 2.0 | bash | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | 3.0 | typescript | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | 3.0 | powershell | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | 2.0 | bash | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | 4.0 | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | 3.0 | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | 3.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | 4.0 | typescript | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | 4.0 | powershell | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | 4.0 | python | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | 3.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | 4.0 | typescript | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | 4.0 | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | 3.0 | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | 3.0 | bash | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | 4.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 7.4min | 35 | 2 | $1.46 | 4.0 | typescript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | 3.0 | typescript | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | 2.0 | bash | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | 3.0 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | 3.0 | powershell | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | 4.0 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | 4.0 | python | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | 3.0 | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | 4.0 | powershell | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | 4.0 | python | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | 3.0 | bash | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | 4.0 | powershell | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | 3.0 | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | 4.0 | typescript | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | 4.0 | python | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | 4.0 | bash | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | 4.0 | typescript | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | 4.0 | python | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | 4.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | 4.0 | typescript | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | 4.0 | powershell | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | 4.0 | python | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | 4.0 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | 3.0 | bash | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | 3.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | 4.0 | typescript | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | 4.0 | powershell | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | 4.0 | bash | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | 4.0 | typescript | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | 3.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | 4.0 | typescript | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | 4.0 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | 4.0 | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | 3.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | 4.0 | typescript | ok |

</details>

<details>
<summary>Sorted by duration (fastest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| PR Label Assigner | default | haiku45 | 2.9min | 27 | 3 | $0.25 | — | python | ok |
| PR Label Assigner | powershell-tool | haiku45 | 3.0min | 26 | 1 | $0.23 | — | powershell | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | 2.0 | python | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | 3.0 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | 3.0 | python | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | 3.0 | bash | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | 4.0 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | 2.0 | bash | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | 3.0 | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | 3.0 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | 3.0 | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | haiku45 | 5.2min | 44 | 1 | $0.38 | — | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | 3.0 | python | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | 2.0 | bash | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | 2.0 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | 4.0 | typescript | ok |
| PR Label Assigner | typescript-bun | haiku45 | 6.0min | 43 | 2 | $0.37 | — | typescript | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | 3.0 | bash | ok |
| Semantic Version Bumper | bash | haiku45 | 6.3min | 48 | 1 | $0.45 | — | bash | ok |
| Semantic Version Bumper | powershell | haiku45 | 6.3min | 65 | 4 | $0.57 | — | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | 3.0 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | 3.0 | bash | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | 3.0 | python | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | 4.0 | python | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | 4.0 | python | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | 3.0 | python | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | 4.0 | python | ok |
| PR Label Assigner | bash | haiku45 | 7.1min | 62 | 4 | $0.50 | — | bash | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | 4.0 | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | 3.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 7.4min | 35 | 2 | $1.46 | 4.0 | typescript | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | 4.0 | powershell | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | 4.0 | python | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | 4.0 | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45 | 7.6min | 74 | 10 | $0.62 | — | typescript | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | 4.0 | powershell | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | 4.0 | python | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | 4.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | 4.0 | typescript | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | 3.0 | typescript | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | 4.0 | python | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | 4.0 | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | 3.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | 4.0 | typescript | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | 3.0 | typescript | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | 4.0 | python | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | 4.0 | python | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | 3.0 | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | 3.0 | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | 4.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | 4.0 | typescript | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | 4.0 | powershell | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | 4.0 | typescript | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | 4.0 | typescript | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | 3.0 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | 3.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | 4.0 | typescript | ok |
| Semantic Version Bumper | powershell-tool | haiku45 | 15.1min | 92 | 7 | $0.93 | — | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | 3.0 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | 4.0 | bash | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | 4.0 | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | 3.0 | bash | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | 3.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | 4.0 | typescript | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | 4.0 | powershell | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | 3.0 | bash | ok |
| Semantic Version Bumper | default | haiku45 | 59.1min | 97 | 12 | $0.84 | — | javascript | ok |

</details>

<details>
<summary>Sorted by errors (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | 4.0 | python | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | 4.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | 4.0 | typescript | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | 2.0 | python | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | 4.0 | python | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | 3.0 | typescript | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | 4.0 | typescript | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | 3.0 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | 3.0 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | 4.0 | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | 3.0 | bash | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | 4.0 | python | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | 3.0 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | 3.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | 3.0 | typescript | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | 3.0 | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | 3.0 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | 3.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | 3.0 | typescript | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | 4.0 | typescript | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | 3.0 | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | 3.0 | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | 4.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | 4.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | 4.0 | typescript | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | 2.0 | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | 3.0 | python | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | 4.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | 4.0 | typescript | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | 3.0 | bash | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | 2.0 | bash | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | 3.0 | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | 4.0 | bash | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | 4.0 | python | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | 4.0 | typescript | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | 3.0 | bash | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | 4.0 | powershell | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | 4.0 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | 4.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | 4.0 | typescript | ok |
| Semantic Version Bumper | bash | haiku45 | 6.3min | 48 | 1 | $0.45 | — | bash | ok |
| PR Label Assigner | powershell | haiku45 | 5.2min | 44 | 1 | $0.38 | — | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45 | 3.0min | 26 | 1 | $0.23 | — | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | 2.0 | bash | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | 3.0 | bash | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | 4.0 | bash | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | 3.0 | bash | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | 4.0 | python | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | 4.0 | bash | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | 3.0 | python | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | 3.0 | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | 3.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 7.4min | 35 | 2 | $1.46 | 4.0 | typescript | ok |
| PR Label Assigner | typescript-bun | haiku45 | 6.0min | 43 | 2 | $0.37 | — | typescript | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | 3.0 | bash | ok |
| PR Label Assigner | default | haiku45 | 2.9min | 27 | 3 | $0.25 | — | python | ok |
| Semantic Version Bumper | powershell | haiku45 | 6.3min | 65 | 4 | $0.57 | — | powershell | ok |
| PR Label Assigner | bash | haiku45 | 7.1min | 62 | 4 | $0.50 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | haiku45 | 15.1min | 92 | 7 | $0.93 | — | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45 | 7.6min | 74 | 10 | $0.62 | — | typescript | ok |
| Semantic Version Bumper | default | haiku45 | 59.1min | 97 | 12 | $0.84 | — | javascript | ok |

</details>

<details>
<summary>Sorted by turns (fewest first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | 3.0 | python | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | 3.0 | python | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | 4.0 | powershell | ok |
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | 3.0 | powershell | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | 3.0 | bash | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | 2.0 | python | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | 3.0 | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | 3.0 | bash | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | 3.0 | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | 2.0 | bash | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | 3.0 | powershell | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | 3.0 | python | ok |
| PR Label Assigner | powershell-tool | haiku45 | 3.0min | 26 | 1 | $0.23 | — | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | 4.0 | powershell | ok |
| PR Label Assigner | default | haiku45 | 2.9min | 27 | 3 | $0.25 | — | python | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | 3.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | 3.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | 4.0 | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | 2.0 | bash | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | 3.0 | typescript | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | 2.0 | bash | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | 3.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | 4.0 | typescript | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | 4.0 | python | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | 3.0 | python | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | 4.0 | bash | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | 4.0 | powershell | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | 3.0 | bash | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | 3.0 | typescript | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | 4.0 | python | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | 3.0 | bash | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 7.4min | 35 | 2 | $1.46 | 4.0 | typescript | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | 3.0 | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | 4.0 | powershell | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | 3.0 | bash | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | 3.0 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | 4.0 | powershell | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | 4.0 | python | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | 4.0 | python | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | 4.0 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | haiku45 | 6.0min | 43 | 2 | $0.37 | — | typescript | ok |
| PR Label Assigner | powershell | haiku45 | 5.2min | 44 | 1 | $0.38 | — | powershell | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | 4.0 | python | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | 4.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | 4.0 | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | 3.0 | bash | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | 4.0 | powershell | ok |
| Semantic Version Bumper | bash | haiku45 | 6.3min | 48 | 1 | $0.45 | — | bash | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | 4.0 | powershell | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | 4.0 | bash | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | 4.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | 4.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | 4.0 | typescript | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | 4.0 | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | 3.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | 4.0 | typescript | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | 3.0 | powershell | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | 4.0 | bash | ok |
| PR Label Assigner | bash | haiku45 | 7.1min | 62 | 4 | $0.50 | — | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | 3.0 | powershell | ok |
| Semantic Version Bumper | powershell | haiku45 | 6.3min | 65 | 4 | $0.57 | — | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | 4.0 | typescript | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | 4.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | haiku45 | 7.6min | 74 | 10 | $0.62 | — | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | 4.0 | bash | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | 4.0 | typescript | ok |
| Semantic Version Bumper | powershell-tool | haiku45 | 15.1min | 92 | 7 | $0.93 | — | powershell | ok |
| Semantic Version Bumper | default | haiku45 | 59.1min | 97 | 12 | $0.84 | — | javascript | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | 4.0 | typescript | ok |

</details>

<details>
<summary>Sorted by LLM-as-judge score (best first)</summary>

| Task | Language | Model | Duration | Turns | Errors | Cost | LLM Score | Chosen | Status |
|------|----------|-------|----------|-------|--------|------|-----------|--------|--------|
| Semantic Version Bumper | default | opus47-1m-medium | 4.1min | 22 | 0 | $0.93 | 4.0 | python | ok |
| Semantic Version Bumper | default | opus47-1m-xhigh | 6.8min | 45 | 0 | $2.45 | 4.0 | python | ok |
| Semantic Version Bumper | powershell | opus47-1m-medium | 8.6min | 35 | 0 | $1.69 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell | opus47-1m-xhigh | 7.7min | 38 | 0 | $2.27 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-medium | 8.0min | 37 | 1 | $1.75 | 4.0 | powershell | ok |
| Semantic Version Bumper | powershell-tool | opus47-1m-xhigh | 8.0min | 49 | 0 | $2.90 | 4.0 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-medium | 5.6min | 33 | 0 | $1.31 | 4.0 | typescript | ok |
| Semantic Version Bumper | typescript-bun | opus47-1m-xhigh | 14.3min | 80 | 1 | $4.21 | 4.0 | typescript | ok |
| PR Label Assigner | bash | opus47-1m-xhigh | 16.7min | 61 | 2 | $3.14 | 4.0 | bash | ok |
| PR Label Assigner | default | opus47-1m-xhigh | 7.8min | 43 | 0 | $2.25 | 4.0 | python | ok |
| PR Label Assigner | powershell | opus47-1m-medium | 5.1min | 27 | 0 | $1.11 | 4.0 | powershell | ok |
| PR Label Assigner | powershell | opus47-1m-xhigh | 9.6min | 43 | 0 | $2.60 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-medium | 7.4min | 29 | 0 | $1.33 | 4.0 | powershell | ok |
| PR Label Assigner | powershell-tool | opus47-1m-xhigh | 7.7min | 37 | 0 | $2.01 | 4.0 | powershell | ok |
| PR Label Assigner | typescript-bun | opus47-1m-xhigh | 10.4min | 57 | 0 | $3.05 | 4.0 | typescript | ok |
| Dependency License Checker | default | opus47-1m-medium | 8.2min | 34 | 2 | $1.33 | 4.0 | python | ok |
| Dependency License Checker | default | opus47-1m-xhigh | 7.5min | 40 | 0 | $2.04 | 4.0 | python | ok |
| Dependency License Checker | powershell | opus47-1m-xhigh | 10.2min | 48 | 1 | $2.95 | 4.0 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-xhigh | 11.2min | 48 | 0 | $2.86 | 4.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-xhigh | 11.8min | 74 | 0 | $3.64 | 4.0 | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-xhigh | 16.5min | 79 | 1 | $5.09 | 4.0 | bash | ok |
| Test Results Aggregator | default | opus47-1m-medium | 6.9min | 31 | 0 | $1.28 | 4.0 | python | ok |
| Test Results Aggregator | default | opus47-1m-xhigh | 9.2min | 54 | 1 | $2.81 | 4.0 | python | ok |
| Test Results Aggregator | powershell | opus47-1m-medium | 9.6min | 27 | 0 | $1.44 | 4.0 | powershell | ok |
| Test Results Aggregator | powershell | opus47-1m-xhigh | 17.3min | 74 | 0 | $4.47 | 4.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-xhigh | 20.8min | 103 | 1 | $6.31 | 4.0 | typescript | ok |
| Environment Matrix Generator | bash | opus47-1m-xhigh | 8.3min | 51 | 2 | $2.49 | 4.0 | bash | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-xhigh | 10.2min | 43 | 1 | $3.08 | 4.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-xhigh | 9.8min | 52 | 0 | $2.60 | 4.0 | typescript | ok |
| Artifact Cleanup Script | bash | opus47-1m-xhigh | 7.6min | 34 | 1 | $1.84 | 4.0 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-xhigh | 7.1min | 35 | 1 | $1.91 | 4.0 | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m-xhigh | 10.9min | 43 | 0 | $3.19 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-medium | 4.1min | 20 | 0 | $0.96 | 4.0 | powershell | ok |
| Artifact Cleanup Script | powershell-tool | opus47-1m-xhigh | 12.0min | 51 | 1 | $3.21 | 4.0 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-medium | 7.2min | 29 | 0 | $1.25 | 4.0 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | opus47-1m-xhigh | 8.5min | 53 | 0 | $2.41 | 4.0 | typescript | ok |
| Secret Rotation Validator | default | opus47-1m-xhigh | 9.1min | 45 | 0 | $2.54 | 4.0 | python | ok |
| Secret Rotation Validator | powershell | opus47-1m-medium | 22.5min | 31 | 0 | $1.27 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell | opus47-1m-xhigh | 11.0min | 46 | 2 | $3.07 | 4.0 | powershell | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-xhigh | 9.9min | 38 | 0 | $2.58 | 4.0 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-medium | 7.4min | 35 | 2 | $1.46 | 4.0 | typescript | ok |
| Secret Rotation Validator | typescript-bun | opus47-1m-xhigh | 8.2min | 46 | 1 | $2.52 | 4.0 | typescript | ok |
| Semantic Version Bumper | bash | opus47-1m-xhigh | 17.2min | 48 | 2 | $2.95 | 3.0 | bash | ok |
| PR Label Assigner | bash | opus47-1m-medium | 6.2min | 23 | 1 | $0.87 | 3.0 | bash | ok |
| PR Label Assigner | typescript-bun | opus47-1m-medium | 9.0min | 30 | 0 | $1.06 | 3.0 | typescript | ok |
| Dependency License Checker | bash | opus47-1m-xhigh | 39.8min | 38 | 2 | $2.19 | 3.0 | bash | ok |
| Dependency License Checker | powershell | opus47-1m-medium | 6.6min | 23 | 0 | $1.00 | 3.0 | powershell | ok |
| Dependency License Checker | powershell-tool | opus47-1m-medium | 4.9min | 26 | 0 | $1.18 | 3.0 | powershell | ok |
| Dependency License Checker | typescript-bun | opus47-1m-medium | 8.2min | 32 | 1 | $1.34 | 3.0 | typescript | ok |
| Test Results Aggregator | bash | opus47-1m-medium | 6.7min | 35 | 0 | $1.36 | 3.0 | bash | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-medium | 9.4min | 37 | 0 | $1.76 | 3.0 | powershell | ok |
| Test Results Aggregator | powershell-tool | opus47-1m-xhigh | 15.2min | 63 | 0 | $5.47 | 3.0 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus47-1m-medium | 8.4min | 35 | 0 | $1.49 | 3.0 | typescript | ok |
| Environment Matrix Generator | bash | opus47-1m-medium | 3.5min | 23 | 1 | $0.88 | 3.0 | bash | ok |
| Environment Matrix Generator | default | opus47-1m-medium | 5.4min | 26 | 0 | $1.12 | 3.0 | python | ok |
| Environment Matrix Generator | default | opus47-1m-xhigh | 6.8min | 34 | 2 | $2.01 | 3.0 | python | ok |
| Environment Matrix Generator | powershell | opus47-1m-medium | 14.0min | 59 | 0 | $3.01 | 3.0 | powershell | ok |
| Environment Matrix Generator | powershell | opus47-1m-xhigh | 13.5min | 54 | 0 | $3.93 | 3.0 | powershell | ok |
| Environment Matrix Generator | powershell-tool | opus47-1m-medium | 4.6min | 29 | 2 | $1.30 | 3.0 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus47-1m-medium | 7.4min | 29 | 0 | $1.07 | 3.0 | typescript | ok |
| Artifact Cleanup Script | bash | opus47-1m-medium | 3.1min | 24 | 3 | $0.92 | 3.0 | bash | ok |
| Artifact Cleanup Script | default | opus47-1m-medium | 3.2min | 19 | 0 | $0.85 | 3.0 | python | ok |
| Artifact Cleanup Script | powershell | opus47-1m-medium | 4.7min | 22 | 0 | $1.08 | 3.0 | powershell | ok |
| Secret Rotation Validator | bash | opus47-1m-xhigh | 9.4min | 35 | 0 | $2.40 | 3.0 | bash | ok |
| Secret Rotation Validator | default | opus47-1m-medium | 7.0min | 19 | 0 | $0.88 | 3.0 | python | ok |
| Secret Rotation Validator | powershell-tool | opus47-1m-medium | 17.8min | 38 | 2 | $1.70 | 3.0 | powershell | ok |
| Semantic Version Bumper | bash | opus47-1m-medium | 4.2min | 30 | 2 | $1.07 | 2.0 | bash | ok |
| PR Label Assigner | default | opus47-1m-medium | 3.1min | 23 | 0 | $0.83 | 2.0 | python | ok |
| Dependency License Checker | bash | opus47-1m-medium | 5.5min | 30 | 1 | $1.55 | 2.0 | bash | ok |
| Secret Rotation Validator | bash | opus47-1m-medium | 5.4min | 24 | 0 | $1.09 | 2.0 | bash | ok |
| Semantic Version Bumper | default | haiku45 | 59.1min | 97 | 12 | $0.84 | — | javascript | ok |
| Semantic Version Bumper | powershell | haiku45 | 6.3min | 65 | 4 | $0.57 | — | powershell | ok |
| Semantic Version Bumper | powershell-tool | haiku45 | 15.1min | 92 | 7 | $0.93 | — | powershell | ok |
| Semantic Version Bumper | bash | haiku45 | 6.3min | 48 | 1 | $0.45 | — | bash | ok |
| Semantic Version Bumper | typescript-bun | haiku45 | 7.6min | 74 | 10 | $0.62 | — | typescript | ok |
| PR Label Assigner | default | haiku45 | 2.9min | 27 | 3 | $0.25 | — | python | ok |
| PR Label Assigner | powershell | haiku45 | 5.2min | 44 | 1 | $0.38 | — | powershell | ok |
| PR Label Assigner | powershell-tool | haiku45 | 3.0min | 26 | 1 | $0.23 | — | powershell | ok |
| PR Label Assigner | bash | haiku45 | 7.1min | 62 | 4 | $0.50 | — | bash | ok |
| PR Label Assigner | typescript-bun | haiku45 | 6.0min | 43 | 2 | $0.37 | — | typescript | ok |

</details>

---
*Generated by generate_results.py — benchmark instructions v4*