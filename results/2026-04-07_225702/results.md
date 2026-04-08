# Benchmark Results: PowerShell vs Default Language

**Last updated:** 2026-04-08 02:47:53 AM ET

**Status:** 50/144 runs completed, 78 remaining
**Total cost so far:** $38.5616
**Total agent time so far:** 13443s (224.0 min)

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
| Config File Migrator | powershell-strict | sonnet | 831s | 21 | 1161 | 0 | $1.6028 | powershell |
| Batch File Renamer | default | opus | 169s | 30 | 1069 | 2 | $0.8066 | python |
| Batch File Renamer | powershell | opus | 179s | 21 | 351 | 0 | $0.5923 | powershell |
| Batch File Renamer | powershell-strict | opus | 269s | 35 | 470 | 0 | $1.0489 | powershell |
| Batch File Renamer | default | sonnet | 136s | 8 | 1462 | 0 | $0.2221 | python |
| Batch File Renamer | powershell | sonnet | 84s | 6 | 351 | 0 | $0.1575 | powershell |
| Batch File Renamer | powershell-strict | sonnet | 220s | 16 | 536 | 1 | $0.5014 | powershell |
| Database Seed Script | default | opus | 257s | 36 | 2359 | 1 | $1.0377 | python |
| Database Seed Script | powershell | opus | 349s | 42 | 1334560 | 4 | $1.3223 | powershell |
| Database Seed Script | powershell-strict | opus | 520s | 56 | 956 | 2 | $2.0318 | powershell |
| Database Seed Script | default | sonnet | 232s | 1 | 0 | 0 | $0.0000 |  |
| Database Seed Script | powershell | sonnet | 226s | 1 | 0 | 0 | $0.0000 | powershell |
| Database Seed Script | powershell-strict | sonnet | 214s | 1 | 0 | 0 | $0.0000 | powershell |
| Error Retry Pipeline | default | opus | 141s | 24 | 1364 | 0 | $0.5407 | python |
| Error Retry Pipeline | powershell | opus | 229s | 34 | 368 | 0 | $0.9345 | powershell |

## Comparison by Language Mode

| Mode | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|------|------|-------------|-----------|------------|-----------|------------|
| default | 17 | 201s | 1477 | 0.6 | 22 | $10.7433 |
| powershell | 17 | 272s | 78957 | 0.3 | 24 | $12.8848 |
| powershell-strict | 16 | 338s | 608 | 0.4 | 25 | $14.9335 |

## Comparison by Model

| Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|-------|------|-------------|-----------|------------|-----------|------------|
| opus | 26 | 264s | 52207 | 0.5 | 34 | $27.1377 |
| sonnet | 24 | 275s | 821 | 0.3 | 12 | $11.4239 |

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
| Config File Migrator | sonnet | powershell-strict | python | 203s | 831s | +309% | 1 | 0 | -1 | 1806 | 1161 |
| Batch File Renamer | sonnet | powershell | python | 136s | 84s | -38% | 0 | 0 | +0 | 1462 | 351 |
| Batch File Renamer | sonnet | powershell-strict | python | 136s | 220s | +62% | 0 | 1 | +1 | 1462 | 536 |
| Database Seed Script | sonnet | powershell |  | 232s | 226s | -2% | 0 | 0 | +0 | 0 | 0 |
| Database Seed Script | sonnet | powershell-strict |  | 232s | 214s | -8% | 0 | 0 | +0 | 0 | 0 |
| Error Retry Pipeline | opus | powershell | python | 141s | 229s | +63% | 0 | 0 | +0 | 1364 | 368 |

## Observations

- **Fastest run:** Batch File Renamer / powershell / sonnet — 84s
- **Slowest run:** Config File Migrator / powershell-strict / sonnet — 831s
- **Most errors:** Database Seed Script / powershell / opus — 4 errors
- **Fewest errors:** CSV Report Generator / default / opus — 0 errors

- **Avg cost per run (opus):** $1.0438
- **Avg cost per run (sonnet):** $0.4760

- **Estimated time remaining:** 5.8 hours (based on avg 269s per run)
- **Estimated total cost:** $111.06

---
*Generated by runner.py, instructions version v2*