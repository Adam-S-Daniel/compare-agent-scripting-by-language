# Benchmark Results: PowerShell vs Default Language

**Last updated:** 2026-04-09 01:05:01 AM ET

**Status:** 29/64 runs completed, 35 remaining
**Total cost so far:** $38.0371
**Total agent time so far:** 19905s (331.7 min)

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

## Comparison by Language Mode

| Mode | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|------|------|-------------|-----------|------------|-----------|------------|
| bash | 7 | 433s | 885 | 2.6 | 38 | $8.1726 |
| default | 8 | 704s | 1526 | 1.2 | 33 | $10.7926 |
| powershell | 7 | 1013s | 1413 | 1.0 | 24 | $10.6960 |
| typescript-bun | 7 | 592s | 1569 | 1.9 | 40 | $8.3760 |

## Comparison by Model

| Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|-------|------|-------------|-----------|------------|-----------|------------|
| opus | 16 | 528s | 1153 | 1.2 | 37 | $20.8082 |
| sonnet | 13 | 881s | 1603 | 2.2 | 30 | $17.2288 |

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
| Docker Image Tag Generato | opus | powershell | python | 873s | 449s | -49% | 1 | 1 | +0 | 1638 | 1737 |
| Docker Image Tag Generato | opus | bash | python | 873s | 868s | -1% | 1 | 2 | +1 | 1638 | 698 |
| Docker Image Tag Generato | opus | typescript-bun | python | 873s | 666s | -24% | 1 | 1 | +0 | 1638 | 913 |

## Observations

- **Fastest run:** PR Label Assigner / default / opus — 278s
- **Slowest run:** Dependency License Checker / powershell / sonnet — 1682s
- **Most errors:** PR Label Assigner / typescript-bun / sonnet — 6 errors
- **Fewest errors:** Semantic Version Bumper / default / opus — 0 errors

- **Avg cost per run (opus):** $1.3005
- **Avg cost per run (sonnet):** $1.3253

- **Estimated time remaining:** 6.7 hours (based on avg 686s per run)
- **Estimated total cost:** $83.94

---
*Generated by runner.py, instructions version v3*