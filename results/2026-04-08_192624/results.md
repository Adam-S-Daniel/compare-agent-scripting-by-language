# Benchmark Results: PowerShell vs Default Language

**Last updated:** 2026-04-09 05:08:56 AM ET

**Status:** 50/64 runs completed, 14 remaining
**Total cost so far:** $66.6934
**Total agent time so far:** 34465s (574.4 min)

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language |
|------|------|-------|----------|-------|-------|--------|------|----------|
| Semantic Version Bumper | default | opus | 542s | 29 | 1115 | 0 | $1.2676 | python |
| Semantic Version Bumper | powershell | opus | 550s | 31 | 1665 | 0 | $0.8210 | powershell |
| Semantic Version Bumper | bash | opus | 410s | 46 | 831 | 2 | $1.4538 | bash |
| Semantic Version Bumper | typescript-bun | opus | 794s | 35 | 987 | 0 | $1.8876 | typescript |
| Semantic Version Bumper | default | sonnet | 1032s | 38 | 1595 | 1 | $1.6232 | python |
| Semantic Version Bumper | powershell | sonnet | 1632s | 42 | 1714 | 0 | $1.4390 | powershell |
| Semantic Version Bumper | bash | sonnet | 297s | 30 | 1074 | 2 | $0.6759 | bash |
| Semantic Version Bumper | typescript-bun | sonnet | 484s | 28 | 2296 | 0 | $0.7248 | typescript |
| PR Label Assigner | default | opus | 278s | 23 | 1111 | 0 | $0.6939 | python |
| PR Label Assigner | powershell | opus | 488s | 32 | 949 | 2 | $1.1248 | powershell |
| PR Label Assigner | bash | opus | 390s | 42 | 929 | 2 | $1.2234 | bash |
| PR Label Assigner | typescript-bun | opus | 548s | 31 | 1228 | 1 | $0.9612 | typescript |
| PR Label Assigner | default | sonnet | 989s | 23 | 2264 | 1 | $1.2463 | python |
| PR Label Assigner | powershell | sonnet | 1624s | 1 | 1157 | 3 | $2.8948 | powershell |
| PR Label Assigner | bash | sonnet | 407s | 39 | 921 | 5 | $0.8953 | bash |
| PR Label Assigner | typescript-bun | sonnet | 820s | 46 | 2944 | 6 | $1.3540 | typescript |
| Dependency License Checker | default | opus | 639s | 65 | 1630 | 4 | $2.3524 | python |
| Dependency License Checker | powershell | opus | 665s | 38 | 1292 | 1 | $1.5453 | powershell |
| Dependency License Checker | bash | opus | 326s | 40 | 1060 | 1 | $1.1150 | bash |
| Dependency License Checker | typescript-bun | opus | 372s | 51 | 1206 | 1 | $1.3380 | typescript |
| Dependency License Checker | default | sonnet | 813s | 40 | 1764 | 1 | $1.1305 | python |
| Dependency License Checker | powershell | sonnet | 1682s | 3 | 1374 | 0 | $2.2644 | powershell |
| Dependency License Checker | bash | sonnet | 334s | 37 | 682 | 4 | $0.7504 | bash |
| Dependency License Checker | typescript-bun | sonnet | 462s | 47 | 1411 | 4 | $1.0952 | typescript |
| Docker Image Tag Generator | default | opus | 469s | 36 | 1092 | 2 | $1.3435 | python |
| Docker Image Tag Generator | powershell | opus | 449s | 20 | 1737 | 1 | $0.6067 | powershell |
| Docker Image Tag Generator | bash | opus | 868s | 33 | 698 | 2 | $2.0586 | bash |
| Docker Image Tag Generator | typescript-bun | opus | 666s | 40 | 913 | 1 | $1.0152 | typescript |
| Docker Image Tag Generator | default | sonnet | 873s | 13 | 1638 | 1 | $1.1350 | python |
| Docker Image Tag Generator | powershell | sonnet | 1462s | 51 | 2480 | 1 | $2.1269 | powershell |
| Docker Image Tag Generator | bash | sonnet | 961s | 34 | 982 | 4 | $1.4891 | bash |
| Docker Image Tag Generator | typescript-bun | sonnet | 614s | 19 | 1221 | 1 | $1.0276 | typescript |
| Test Results Aggregator | default | opus | 455s | 40 | 1463 | 2 | $1.4331 | python |
| Test Results Aggregator | powershell | opus | 588s | 31 | 821 | 1 | $1.5754 | powershell |
| Test Results Aggregator | bash | opus | 403s | 44 | 784 | 3 | $1.3595 | bash |
| Test Results Aggregator | typescript-bun | opus | 423s | 40 | 1801 | 0 | $1.1849 | typescript |
| Test Results Aggregator | default | sonnet | 951s | 58 | 4114 | 2 | $1.7751 | python |
| Test Results Aggregator | powershell | sonnet | 1195s | 43 | 1501 | 0 | $1.7717 | powershell |
| Test Results Aggregator | bash | sonnet | 718s | 43 | 701 | 5 | $1.2587 | bash |
| Test Results Aggregator | typescript-bun | sonnet | 731s | 72 | 2469 | 3 | $1.8588 | typescript |
| Environment Matrix Generator | default | opus | 274s | 36 | 1298 | 1 | $0.9839 | bash |
| Environment Matrix Generator | powershell | opus | 401s | 44 | 954 | 5 | $0.9925 | powershell |
| Environment Matrix Generator | bash | opus | 579s | 36 | 6933 | 1 | $0.8671 | bash |
| Environment Matrix Generator | typescript-bun | opus | 422s | 41 | 1183 | 4 | $1.1545 | typescript |
| Environment Matrix Generator | default | sonnet | 719s | 23 | 1330 | 0 | $1.1316 | python |
| Environment Matrix Generator | powershell | sonnet | 1325s | 1 | 1020 | 0 | $1.9873 | powershell |
| Environment Matrix Generator | bash | sonnet | 586s | 40 | 1425 | 6 | $0.8417 | bash |
| Environment Matrix Generator | typescript-bun | sonnet | 811s | 24 | 1518 | 0 | $1.1903 | typescript |
| Artifact Cleanup Script | default | opus | 378s | 29 | 1249 | 0 | $1.0492 | python |
| Artifact Cleanup Script | powershell | opus | 563s | 39 | 1264 | 0 | $1.5972 | powershell |

## Comparison by Language Mode

| Mode | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|------|------|-------------|-----------|------------|-----------|------------|
| bash | 12 | 523s | 1418 | 3.1 | 39 | $13.9886 |
| default | 13 | 647s | 1666 | 1.2 | 35 | $17.1655 |
| powershell | 13 | 971s | 1379 | 1.1 | 29 | $20.7471 |
| typescript-bun | 12 | 596s | 1598 | 1.8 | 40 | $14.7922 |

## Comparison by Model

| Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|-------|------|-------------|-----------|------------|-----------|------------|
| opus | 26 | 498s | 1392 | 1.4 | 37 | $33.0057 |
| sonnet | 24 | 897s | 1650 | 2.1 | 33 | $33.6878 |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Delta | Def Err | Mode Err | Err Delta | Def Lines | Mode Lines |
|------|-------|------|-------------|---------|----------|-----------|---------|----------|-----------|-----------|------------|
| Semantic Version Bumper | sonnet | powershell | python | 1032s | 1632s | +58% | 1 | 0 | -1 | 1595 | 1714 |
| Semantic Version Bumper | sonnet | bash | python | 1032s | 297s | -71% | 1 | 2 | +1 | 1595 | 1074 |
| Semantic Version Bumper | sonnet | typescript-bun | python | 1032s | 484s | -53% | 1 | 0 | -1 | 1595 | 2296 |
| PR Label Assigner | sonnet | powershell | python | 989s | 1624s | +64% | 1 | 3 | +2 | 2264 | 1157 |
| PR Label Assigner | sonnet | bash | python | 989s | 407s | -59% | 1 | 5 | +4 | 2264 | 921 |
| PR Label Assigner | sonnet | typescript-bun | python | 989s | 820s | -17% | 1 | 6 | +5 | 2264 | 2944 |
| Dependency License Checke | sonnet | powershell | python | 813s | 1682s | +107% | 1 | 0 | -1 | 1764 | 1374 |
| Dependency License Checke | sonnet | bash | python | 813s | 334s | -59% | 1 | 4 | +3 | 1764 | 682 |
| Dependency License Checke | sonnet | typescript-bun | python | 813s | 462s | -43% | 1 | 4 | +3 | 1764 | 1411 |
| Docker Image Tag Generato | sonnet | powershell | python | 873s | 1462s | +67% | 1 | 1 | +0 | 1638 | 2480 |
| Docker Image Tag Generato | sonnet | bash | python | 873s | 961s | +10% | 1 | 4 | +3 | 1638 | 982 |
| Docker Image Tag Generato | sonnet | typescript-bun | python | 873s | 614s | -30% | 1 | 1 | +0 | 1638 | 1221 |
| Test Results Aggregator | sonnet | powershell | python | 951s | 1195s | +26% | 2 | 0 | -2 | 4114 | 1501 |
| Test Results Aggregator | sonnet | bash | python | 951s | 718s | -25% | 2 | 5 | +3 | 4114 | 701 |
| Test Results Aggregator | sonnet | typescript-bun | python | 951s | 731s | -23% | 2 | 3 | +1 | 4114 | 2469 |
| Environment Matrix Genera | sonnet | powershell | python | 719s | 1325s | +84% | 0 | 0 | +0 | 1330 | 1020 |
| Environment Matrix Genera | sonnet | bash | python | 719s | 586s | -19% | 0 | 6 | +6 | 1330 | 1425 |
| Environment Matrix Genera | sonnet | typescript-bun | python | 719s | 811s | +13% | 0 | 0 | +0 | 1330 | 1518 |
| Artifact Cleanup Script | opus | powershell | python | 378s | 563s | +49% | 0 | 0 | +0 | 1249 | 1264 |

## Observations

- **Fastest run:** Environment Matrix Generator / default / opus — 274s
- **Slowest run:** Dependency License Checker / powershell / sonnet — 1682s
- **Most errors:** PR Label Assigner / typescript-bun / sonnet — 6 errors
- **Fewest errors:** Semantic Version Bumper / default / opus — 0 errors

- **Avg cost per run (opus):** $1.2694
- **Avg cost per run (sonnet):** $1.4037

- **Estimated time remaining:** 2.7 hours (based on avg 689s per run)
- **Estimated total cost:** $85.37

---
*Generated by runner.py, instructions version v3*