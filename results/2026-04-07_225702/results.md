# Benchmark Results: PowerShell vs Default Language

**Last updated:** 2026-04-08 01:34:03 AM ET

**Status:** 35/144 runs completed, 98 remaining
**Total cost so far:** $27.7630
**Total agent time so far:** 9387s (156.4 min)

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language |
|------|------|-------|----------|-------|-------|--------|------|----------|
| CSV Report Generator | default | opus | 102s | 12 | 960 | 0 | $0.3757 | python |
| CSV Report Generator | powershell | opus | 255s | 37 | 330 | 0 | $1.0452 | powershell |
| CSV Report Generator | powershell-strict | opus | 256s | 40 | 486 | 1 | $1.0450 | powershell |
| CSV Report Generator | default | sonnet | 376s | 1 | 1760 | 3 | $0.7093 | python |
| CSV Report Generator | powershell | sonnet | 124s | 9 | 464 | 0 | $0.3065 | powershell |
| CSV Report Generator | powershell-strict | sonnet | 392s | 29 | 535 | 0 | $0.9737 | powershell |
| Log File Analyzer | default | opus | 249s | 43 | 1464 | 0 | $1.1836 | python |
| Log File Analyzer | powershell | opus | 273s | 41 | 558 | 0 | $1.1400 | powershell |
| Log File Analyzer | powershell-strict | opus | 267s | 31 | 552 | 1 | $0.9488 | powershell |
| Log File Analyzer | default | sonnet | 176s | 19 | 2268 | 0 | $0.4822 | python |
| Log File Analyzer | powershell | sonnet | 232s | 10 | 681 | 0 | $0.4408 | powershell |
| Log File Analyzer | powershell-strict | sonnet | 228s | 14 | 802 | 1 | $0.5046 | powershell |
| Directory Tree Sync | default | opus | 227s | 43 | 1877 | 0 | $1.1794 | python |
| Directory Tree Sync | powershell | opus | 318s | 42 | 542 | 0 | $1.1256 | powershell |
| Directory Tree Sync | powershell-strict | opus | 323s | 34 | 628 | 0 | $1.2117 | powershell |
| Directory Tree Sync | default | sonnet | 234s | 11 | 1723 | 1 | $0.4491 | python |
| Directory Tree Sync | powershell | sonnet | 179s | 11 | 757 | 0 | $0.3690 | powershell |
| Directory Tree Sync | powershell-strict | sonnet | 259s | 13 | 621 | 0 | $0.4912 | powershell |
| REST API Client | default | opus | 315s | 45 | 1399 | 0 | $1.2150 | python |
| REST API Client | powershell | opus | 430s | 51 | 537 | 1 | $1.8175 | powershell |
| REST API Client | powershell-strict | opus | 308s | 19 | 673 | 0 | $0.9416 | powershell |
| REST API Client | default | sonnet | 109s | 9 | 1065 | 1 | $0.2302 | python |
| REST API Client | powershell | sonnet | 758s | 13 | 427 | 0 | $0.9570 | powershell |
| REST API Client | powershell-strict | sonnet | 552s | 14 | 686 | 0 | $0.9926 | powershell |
| Process Monitor | default | opus | 201s | 40 | 1305 | 1 | $1.0020 | python |
| Process Monitor | powershell | opus | 323s | 39 | 392 | 0 | $1.2114 | powershell |
| Process Monitor | powershell-strict | opus | 339s | 53 | 411 | 0 | $1.6143 | powershell |
| Process Monitor | default | sonnet | 120s | 12 | 865 | 0 | $0.2472 | python |
| Process Monitor | powershell | sonnet | 227s | 13 | 389 | 0 | $0.4025 | powershell |
| Process Monitor | powershell-strict | sonnet | 274s | 19 | 461 | 0 | $0.5378 | powershell |
| Config File Migrator | default | opus | 166s | 14 | 2361 | 1 | $0.5923 | python |
| Config File Migrator | powershell | opus | 225s | 20 | 666 | 0 | $0.6864 | powershell |
| Config File Migrator | powershell-strict | opus | 162s | 12 | 754 | 0 | $0.4873 | powershell |
| Config File Migrator | default | sonnet | 203s | 18 | 1806 | 1 | $0.4700 | python |
| Config File Migrator | powershell | sonnet | 204s | 15 | 894 | 0 | $0.3763 | powershell |

## Comparison by Language Mode

| Mode | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|------|------|-------------|-----------|------------|-----------|------------|
| default | 12 | 207s | 1571 | 0.7 | 22 | $8.1361 |
| powershell | 12 | 296s | 553 | 0.1 | 25 | $9.8782 |
| powershell-strict | 11 | 305s | 601 | 0.3 | 25 | $9.7487 |

## Comparison by Model

| Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|-------|------|-------------|-----------|------------|-----------|------------|
| opus | 18 | 263s | 883 | 0.3 | 34 | $18.8228 |
| sonnet | 17 | 273s | 953 | 0.4 | 14 | $8.9401 |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Delta | Def Err | Mode Err | Err Delta | Def Lines | Mode Lines |
|------|-------|------|-------------|---------|----------|-----------|---------|----------|-----------|-----------|------------|
| CSV Report Generator | sonnet | powershell | python | 376s | 124s | -67% | 3 | 0 | -3 | 1760 | 464 |
| CSV Report Generator | sonnet | powershell-strict | python | 376s | 392s | +4% | 3 | 0 | -3 | 1760 | 535 |
| Log File Analyzer | sonnet | powershell | python | 176s | 232s | +32% | 0 | 0 | +0 | 2268 | 681 |
| Log File Analyzer | sonnet | powershell-strict | python | 176s | 228s | +30% | 0 | 1 | +1 | 2268 | 802 |
| Directory Tree Sync | sonnet | powershell | python | 234s | 179s | -23% | 1 | 0 | -1 | 1723 | 757 |
| Directory Tree Sync | sonnet | powershell-strict | python | 234s | 259s | +11% | 1 | 0 | -1 | 1723 | 621 |
| REST API Client | sonnet | powershell | python | 109s | 758s | +594% | 1 | 0 | -1 | 1065 | 427 |
| REST API Client | sonnet | powershell-strict | python | 109s | 552s | +405% | 1 | 0 | -1 | 1065 | 686 |
| Process Monitor | sonnet | powershell | python | 120s | 227s | +89% | 0 | 0 | +0 | 865 | 389 |
| Process Monitor | sonnet | powershell-strict | python | 120s | 274s | +128% | 0 | 0 | +0 | 865 | 461 |
| Config File Migrator | sonnet | powershell | python | 203s | 204s | +0% | 1 | 0 | -1 | 1806 | 894 |
| Config File Migrator | opus | powershell-strict | python | 203s | 162s | -20% | 1 | 0 | -1 | 1806 | 754 |

## Observations

- **Fastest run:** CSV Report Generator / default / opus — 102s
- **Slowest run:** REST API Client / powershell / sonnet — 758s
- **Most errors:** CSV Report Generator / default / sonnet — 3 errors
- **Fewest errors:** CSV Report Generator / default / opus — 0 errors

- **Avg cost per run (opus):** $1.0457
- **Avg cost per run (sonnet):** $0.5259

- **Estimated time remaining:** 7.3 hours (based on avg 268s per run)
- **Estimated total cost:** $114.22

---
*Generated by runner.py, instructions version v2*