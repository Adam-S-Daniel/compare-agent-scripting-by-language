# Benchmark Results: Language Mode Comparison

**Last updated:** 2026-04-09 09:41:01 AM ET

**Status:** 64/64 runs completed, 0 remaining
**Total cost so far:** $84.2473
**Total agent time so far:** 43566s (726.1 min)

## Comparison by Language × Model

| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |
|------|-------|------|-------------|-----------|------------|-----------|----------|------------|
| bash | opus | 8 | 519s | 1796 | 1.8 | 39 | $1.3663 | $10.9304 |
| bash | sonnet | 8 | 613s | 1212 | 4.1 | 38 | $1.0560 | $8.4483 |
| default | opus | 8 | 421s | 1318 | 1.2 | 36 | $1.2887 | $10.3098 |
| default | sonnet | 8 | 878s | 2070 | 1.1 | 32 | $1.3826 | $11.0605 |
| powershell | opus | 8 | 543s | 1317 | 1.2 | 34 | $1.2021 | $9.6170 |
| powershell | sonnet | 8 | 1259s | 1527 | 0.5 | 42 | $1.6711 | $13.3688 |
| typescript-bun | opus | 8 | 536s | 1191 | 1.5 | 39 | $1.3471 | $10.7764 |
| typescript-bun | sonnet | 8 | 677s | 2124 | 2.2 | 33 | $1.2170 | $9.7360 |

## Savings Analysis

### Hook Savings by Language × Model

Each hook-caught error avoids one test run that would otherwise have been needed to discover it.

| Mode | Model | Fires | Caught | Rate | Time Saved | % of Time | Turns Saved |
|------|-------|-------|--------|------|-----------|-----------|-------------|
| bash | opus | 93 | 5 | 5.4% | 1.0min | 0.1% | 5 |
| bash | sonnet | 98 | 14 | 14.3% | 2.8min | 0.4% | 14 |
| default | opus | 90 | 5 | 5.6% | 0.7min | 0.1% | 5 |
| default | sonnet | 81 | 4 | 4.9% | 0.5min | 0.1% | 4 |
| powershell | opus | 68 | 2 | 2.9% | 1.2min | 0.2% | 2 |
| powershell | sonnet | 82 | 1 | 1.2% | 0.6min | 0.1% | 1 |
| typescript-bun | opus | 94 | 50 | 53.2% | 6.7min | 0.9% | 50 |
| typescript-bun | sonnet | 99 | 46 | 46.5% | 6.1min | 0.8% | 46 |
| **Total** | | **705** | **127** | **18.0%** | **19.6min** | **2.7%** | **127** |

### Prompt Cache Savings

| Status | Runs | $ Saved | % of $ |
|--------|------|---------|--------|
| Full hit (100%) | 1 | $0.0588 | 0.07% |
| Partial | 62 | $7.3027 | 8.67% |
| Miss | 1 | $0.0000 | 0.00% |
| **Total** | **64** | **$7.3615** | **8.74%** |

### Trap Analysis by Category

| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |
|------|-----------|---------|---------|------|-----------|-----------|--------|--------|
| act-push-debug-loops | 64 | 9 | 55 | 14% | 24.1min | 3.3% | $1.86 | 2.21% |
| ts-type-error-fix-cycles | 16 | 16 | 0 | 100% | 19.2min | 2.6% | $2.70 | 3.21% |
| fixture-rework | 64 | 15 | 49 | 23% | 17.8min | 2.4% | $2.83 | 3.36% |
| repeated-test-reruns | 64 | 12 | 52 | 19% | 11.3min | 1.6% | $1.17 | 1.39% |
| docker-pwsh-install | 16 | 3 | 13 | 19% | 7.5min | 1.0% | $0.82 | 0.97% |
| act-permission-path-errors | 64 | 5 | 59 | 8% | 4.2min | 0.6% | $0.60 | 0.71% |
| docker-pkg-install | 64 | 1 | 63 | 2% | 1.5min | 0.2% | $0.17 | 0.20% |
| actionlint-fix-cycles | 64 | 2 | 62 | 3% | 1.3min | 0.2% | $0.17 | 0.20% |
| **Total** | | **44 runs** | | **69%** | **87.0min** | **12.0%** | **$10.31** | **12.24%** |

### Traps by Language × Model

| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |
|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|
| bash | opus | 8 | 6 | 75% | 6 | 6.7min | 0.9% | $1.21 | 1.43% |
| bash | sonnet | 8 | 5 | 62% | 8 | 7.9min | 1.1% | $0.89 | 1.06% |
| default | opus | 8 | 2 | 25% | 2 | 1.5min | 0.2% | $0.30 | 0.35% |
| default | sonnet | 8 | 4 | 50% | 7 | 8.7min | 1.2% | $0.92 | 1.09% |
| powershell | opus | 8 | 4 | 50% | 5 | 8.0min | 1.1% | $1.18 | 1.40% |
| powershell | sonnet | 8 | 7 | 88% | 11 | 25.9min | 3.6% | $1.78 | 2.12% |
| typescript-bun | opus | 8 | 8 | 100% | 12 | 13.7min | 1.9% | $2.37 | 2.81% |
| typescript-bun | sonnet | 8 | 8 | 100% | 12 | 14.7min | 2.0% | $1.67 | 1.98% |
| **Total** | | **64** | **44** | **69%** | **63** | **87.0min** | **12.0%** | **$10.31** | **12.24%** |

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |
|------|------|-------|----------|-------|-------|--------|------|----------|--------|
| Semantic Version Bumper | bash | opus | 410s | 46 | 831 | 2 | $1.4538 | bash | ok |
| Semantic Version Bumper | bash | sonnet | 297s | 30 | 1074 | 2 | $0.6759 | bash | ok |
| Semantic Version Bumper | default | opus | 542s | 29 | 1115 | 0 | $1.2676 | python | ok |
| Semantic Version Bumper | default | sonnet | 1032s | 38 | 1595 | 1 | $1.6232 | python | ok |
| Semantic Version Bumper | powershell | opus | 550s | 31 | 1665 | 0 | $0.8210 | powershell | ok |
| Semantic Version Bumper | powershell | sonnet | 1632s | 42 | 1714 | 0 | $1.4390 | powershell | ok |
| Semantic Version Bumper | typescript-bun | opus | 794s | 35 | 987 | 0 | $1.8876 | typescript | ok |
| Semantic Version Bumper | typescript-bun | sonnet | 484s | 28 | 2296 | 0 | $0.7248 | typescript | ok |
| PR Label Assigner | bash | opus | 390s | 42 | 929 | 2 | $1.2234 | bash | ok |
| PR Label Assigner | bash | sonnet | 407s | 39 | 921 | 5 | $0.8953 | bash | ok |
| PR Label Assigner | default | opus | 278s | 23 | 1111 | 0 | $0.6939 | python | ok |
| PR Label Assigner | default | sonnet | 989s | 23 | 2264 | 1 | $1.2463 | python | ok |
| PR Label Assigner | powershell | opus | 488s | 32 | 949 | 2 | $1.1248 | powershell | ok |
| PR Label Assigner | powershell | sonnet | 1624s | 50 | 1157 | 3 | $2.5129 | powershell | ok |
| PR Label Assigner | typescript-bun | opus | 548s | 31 | 1228 | 1 | $0.9612 | typescript | ok |
| PR Label Assigner | typescript-bun | sonnet | 820s | 46 | 2944 | 6 | $1.3540 | typescript | ok |
| Dependency License Checker | bash | opus | 326s | 40 | 1060 | 1 | $1.1150 | bash | ok |
| Dependency License Checker | bash | sonnet | 334s | 37 | 682 | 4 | $0.7504 | bash | ok |
| Dependency License Checker | default | opus | 639s | 65 | 1630 | 4 | $2.3524 | python | ok |
| Dependency License Checker | default | sonnet | 813s | 40 | 1764 | 1 | $1.1305 | python | ok |
| Dependency License Checker | powershell | opus | 665s | 38 | 1292 | 1 | $1.5453 | powershell | ok |
| Dependency License Checker | powershell | sonnet | 1682s | 59 | 1374 | 0 | $1.8519 | powershell | ok |
| Dependency License Checker | typescript-bun | opus | 372s | 51 | 1206 | 1 | $1.3380 | typescript | ok |
| Dependency License Checker | typescript-bun | sonnet | 462s | 47 | 1411 | 4 | $1.0952 | typescript | ok |
| Docker Image Tag Generator | bash | opus | 868s | 33 | 698 | 2 | $2.0586 | bash | ok |
| Docker Image Tag Generator | bash | sonnet | 961s | 34 | 982 | 4 | $1.4891 | bash | ok |
| Docker Image Tag Generator | default | opus | 469s | 36 | 1092 | 2 | $1.3435 | python | ok |
| Docker Image Tag Generator | default | sonnet | 873s | 13 | 1638 | 1 | $1.1350 | python | ok |
| Docker Image Tag Generator | powershell | opus | 449s | 20 | 1737 | 1 | $0.6067 | powershell | ok |
| Docker Image Tag Generator | powershell | sonnet | 1462s | 51 | 2480 | 1 | $2.1269 | powershell | ok |
| Docker Image Tag Generator | typescript-bun | opus | 666s | 40 | 913 | 1 | $1.0152 | typescript | ok |
| Docker Image Tag Generator | typescript-bun | sonnet | 614s | 19 | 1221 | 1 | $1.0276 | typescript | ok |
| Test Results Aggregator | bash | opus | 403s | 44 | 784 | 3 | $1.3595 | bash | ok |
| Test Results Aggregator | bash | sonnet | 718s | 43 | 701 | 5 | $1.2587 | bash | ok |
| Test Results Aggregator | default | opus | 455s | 40 | 1463 | 2 | $1.4331 | python | ok |
| Test Results Aggregator | default | sonnet | 951s | 58 | 4114 | 2 | $1.7751 | python | ok |
| Test Results Aggregator | powershell | opus | 588s | 31 | 821 | 1 | $1.5754 | powershell | ok |
| Test Results Aggregator | powershell | sonnet | 1195s | 43 | 1501 | 0 | $1.7717 | powershell | ok |
| Test Results Aggregator | typescript-bun | opus | 423s | 40 | 1801 | 0 | $1.1849 | typescript | ok |
| Test Results Aggregator | typescript-bun | sonnet | 731s | 72 | 2469 | 3 | $1.8588 | typescript | ok |
| Environment Matrix Generator | bash | opus | 579s | 36 | 6933 | 1 | $0.8671 | bash | ok |
| Environment Matrix Generator | bash | sonnet | 586s | 40 | 1425 | 6 | $0.8417 | bash | ok |
| Environment Matrix Generator | default | opus | 274s | 36 | 1298 | 1 | $0.9839 | bash | ok |
| Environment Matrix Generator | default | sonnet | 719s | 23 | 1330 | 0 | $1.1316 | python | ok |
| Environment Matrix Generator | powershell | opus | 401s | 44 | 954 | 5 | $0.9925 | powershell | ok |
| Environment Matrix Generator | powershell | sonnet | 1325s | 42 | 1020 | 0 | $1.9270 | powershell | ok |
| Environment Matrix Generator | typescript-bun | opus | 422s | 41 | 1183 | 4 | $1.1545 | typescript | ok |
| Environment Matrix Generator | typescript-bun | sonnet | 811s | 24 | 1518 | 0 | $1.1903 | typescript | ok |
| Artifact Cleanup Script | bash | opus | 486s | 38 | 1566 | 2 | $1.5090 | bash | ok |
| Artifact Cleanup Script | bash | sonnet | 927s | 47 | 1894 | 3 | $1.5949 | bash | ok |
| Artifact Cleanup Script | default | opus | 378s | 29 | 1249 | 0 | $1.0492 | python | ok |
| Artifact Cleanup Script | default | sonnet | 955s | 25 | 1766 | 1 | $1.4925 | python | ok |
| Artifact Cleanup Script | powershell | opus | 563s | 39 | 1264 | 0 | $1.5972 | powershell | ok |
| Artifact Cleanup Script | powershell | sonnet | 391s | 31 | 975 | 0 | $0.6954 | powershell | ok |
| Artifact Cleanup Script | typescript-bun | opus | 737s | 30 | 1119 | 0 | $2.0602 | typescript | ok |
| Artifact Cleanup Script | typescript-bun | sonnet | 702s | 30 | 718 | 1 | $1.1760 | typescript | ok |
| Secret Rotation Validator | bash | opus | 690s | 33 | 1565 | 1 | $1.3439 | bash | ok |
| Secret Rotation Validator | bash | sonnet | 673s | 31 | 2014 | 4 | $0.9423 | bash | ok |
| Secret Rotation Validator | default | opus | 332s | 32 | 1589 | 1 | $1.1860 | python | ok |
| Secret Rotation Validator | default | sonnet | 691s | 37 | 2093 | 2 | $1.5263 | python | ok |
| Secret Rotation Validator | powershell | opus | 640s | 34 | 1857 | 0 | $1.3539 | powershell | ok |
| Secret Rotation Validator | powershell | sonnet | 762s | 22 | 1994 | 0 | $1.0440 | powershell | ok |
| Secret Rotation Validator | typescript-bun | opus | 325s | 44 | 1089 | 5 | $1.1749 | typescript | ok |
| Secret Rotation Validator | typescript-bun | sonnet | 789s | 1 | 4417 | 3 | $1.3092 | typescript | ok |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Δ | Def Cost | Mode Cost | Cost Δ | Err Δ |
|------|-------|------|-------------|---------|----------|-------|----------|-----------|--------|-------|
| Semantic Version Bumper | opus | bash | python | 542s | 410s | -24% | $1.2676 | $1.4538 | +15% | +2 |
| Semantic Version Bumper | opus | powershell | python | 542s | 550s | +1% | $1.2676 | $0.8210 | -35% | +0 |
| Semantic Version Bumper | opus | typescript-bun | python | 542s | 794s | +46% | $1.2676 | $1.8876 | +49% | +0 |
| Semantic Version Bumper | sonnet | bash | python | 1032s | 297s | -71% | $1.6232 | $0.6759 | -58% | +1 |
| Semantic Version Bumper | sonnet | powershell | python | 1032s | 1632s | +58% | $1.6232 | $1.4390 | -11% | -1 |
| Semantic Version Bumper | sonnet | typescript-bun | python | 1032s | 484s | -53% | $1.6232 | $0.7248 | -55% | -1 |
| PR Label Assigner | opus | bash | python | 278s | 390s | +40% | $0.6939 | $1.2234 | +76% | +2 |
| PR Label Assigner | opus | powershell | python | 278s | 488s | +75% | $0.6939 | $1.1248 | +62% | +2 |
| PR Label Assigner | opus | typescript-bun | python | 278s | 548s | +97% | $0.6939 | $0.9612 | +39% | +1 |
| PR Label Assigner | sonnet | bash | python | 989s | 407s | -59% | $1.2463 | $0.8953 | -28% | +4 |
| PR Label Assigner | sonnet | powershell | python | 989s | 1624s | +64% | $1.2463 | $2.5129 | +102% | +2 |
| PR Label Assigner | sonnet | typescript-bun | python | 989s | 820s | -17% | $1.2463 | $1.3540 | +9% | +5 |
| Dependency License Checke | opus | bash | python | 639s | 326s | -49% | $2.3524 | $1.1150 | -53% | -3 |
| Dependency License Checke | opus | powershell | python | 639s | 665s | +4% | $2.3524 | $1.5453 | -34% | -3 |
| Dependency License Checke | opus | typescript-bun | python | 639s | 372s | -42% | $2.3524 | $1.3380 | -43% | -3 |
| Dependency License Checke | sonnet | bash | python | 813s | 334s | -59% | $1.1305 | $0.7504 | -34% | +3 |
| Dependency License Checke | sonnet | powershell | python | 813s | 1682s | +107% | $1.1305 | $1.8519 | +64% | -1 |
| Dependency License Checke | sonnet | typescript-bun | python | 813s | 462s | -43% | $1.1305 | $1.0952 | -3% | +3 |
| Docker Image Tag Generato | opus | bash | python | 469s | 868s | +85% | $1.3435 | $2.0586 | +53% | +0 |
| Docker Image Tag Generato | opus | powershell | python | 469s | 449s | -4% | $1.3435 | $0.6067 | -55% | -1 |
| Docker Image Tag Generato | opus | typescript-bun | python | 469s | 666s | +42% | $1.3435 | $1.0152 | -24% | -1 |
| Docker Image Tag Generato | sonnet | bash | python | 873s | 961s | +10% | $1.1350 | $1.4891 | +31% | +3 |
| Docker Image Tag Generato | sonnet | powershell | python | 873s | 1462s | +67% | $1.1350 | $2.1269 | +87% | +0 |
| Docker Image Tag Generato | sonnet | typescript-bun | python | 873s | 614s | -30% | $1.1350 | $1.0276 | -9% | +0 |
| Test Results Aggregator | opus | bash | python | 455s | 403s | -11% | $1.4331 | $1.3595 | -5% | +1 |
| Test Results Aggregator | opus | powershell | python | 455s | 588s | +29% | $1.4331 | $1.5754 | +10% | -1 |
| Test Results Aggregator | opus | typescript-bun | python | 455s | 423s | -7% | $1.4331 | $1.1849 | -17% | -2 |
| Test Results Aggregator | sonnet | bash | python | 951s | 718s | -25% | $1.7751 | $1.2587 | -29% | +3 |
| Test Results Aggregator | sonnet | powershell | python | 951s | 1195s | +26% | $1.7751 | $1.7717 | -0% | -2 |
| Test Results Aggregator | sonnet | typescript-bun | python | 951s | 731s | -23% | $1.7751 | $1.8588 | +5% | +1 |
| Environment Matrix Genera | opus | bash | bash | 274s | 579s | +111% | $0.9839 | $0.8671 | -12% | +0 |
| Environment Matrix Genera | opus | powershell | bash | 274s | 401s | +46% | $0.9839 | $0.9925 | +1% | +4 |
| Environment Matrix Genera | opus | typescript-bun | bash | 274s | 422s | +54% | $0.9839 | $1.1545 | +17% | +3 |
| Environment Matrix Genera | sonnet | bash | python | 719s | 586s | -19% | $1.1316 | $0.8417 | -26% | +6 |
| Environment Matrix Genera | sonnet | powershell | python | 719s | 1325s | +84% | $1.1316 | $1.9270 | +70% | +0 |
| Environment Matrix Genera | sonnet | typescript-bun | python | 719s | 811s | +13% | $1.1316 | $1.1903 | +5% | +0 |
| Artifact Cleanup Script | opus | bash | python | 378s | 486s | +29% | $1.0492 | $1.5090 | +44% | +2 |
| Artifact Cleanup Script | opus | powershell | python | 378s | 563s | +49% | $1.0492 | $1.5972 | +52% | +0 |
| Artifact Cleanup Script | opus | typescript-bun | python | 378s | 737s | +95% | $1.0492 | $2.0602 | +96% | +0 |
| Artifact Cleanup Script | sonnet | bash | python | 955s | 927s | -3% | $1.4925 | $1.5949 | +7% | +2 |
| Artifact Cleanup Script | sonnet | powershell | python | 955s | 391s | -59% | $1.4925 | $0.6954 | -53% | -1 |
| Artifact Cleanup Script | sonnet | typescript-bun | python | 955s | 702s | -26% | $1.4925 | $1.1760 | -21% | +0 |
| Secret Rotation Validator | opus | bash | python | 332s | 690s | +108% | $1.1860 | $1.3439 | +13% | +0 |
| Secret Rotation Validator | opus | powershell | python | 332s | 640s | +93% | $1.1860 | $1.3539 | +14% | -1 |
| Secret Rotation Validator | opus | typescript-bun | python | 332s | 325s | -2% | $1.1860 | $1.1749 | -1% | +4 |
| Secret Rotation Validator | sonnet | bash | python | 691s | 673s | -3% | $1.5263 | $0.9423 | -38% | +2 |
| Secret Rotation Validator | sonnet | powershell | python | 691s | 762s | +10% | $1.5263 | $1.0440 | -32% | -2 |
| Secret Rotation Validator | sonnet | typescript-bun | python | 691s | 789s | +14% | $1.5263 | $1.3092 | -14% | +1 |

## Observations

- **Fastest run:** Environment Matrix Generator / default / opus — 274s
- **Slowest run:** Dependency License Checker / powershell / sonnet — 1682s
- **Most errors:** PR Label Assigner / typescript-bun / sonnet — 6 errors
- **Fewest errors:** Semantic Version Bumper / default / opus — 0 errors

- **Avg cost per run (opus):** $1.3011
- **Avg cost per run (sonnet):** $1.3317


---
*Generated by runner.py, instructions version v3*