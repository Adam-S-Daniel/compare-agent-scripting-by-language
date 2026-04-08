# Benchmark Results: PowerShell vs Default Language

**Last updated:** 2026-04-08 06:43:48 AM ET

**Status:** 108/144 runs completed, 36 remaining
**Total cost so far:** $75.3806
**Total agent time so far:** 27302s (455.0 min)

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language |
|------|------|-------|----------|-------|-------|--------|------|----------|
| CSV Report Generator | default | opus | 102s | 12 | 960 | 0 | $0.3757 | python |
| CSV Report Generator | default | sonnet | 376s | 1 | 1760 | 3 | $0.7093 | python |
| CSV Report Generator | powershell | opus | 255s | 37 | 330 | 0 | $1.0452 | powershell |
| CSV Report Generator | powershell | sonnet | 124s | 9 | 464 | 0 | $0.3065 | powershell |
| CSV Report Generator | powershell-strict | opus | 256s | 40 | 486 | 1 | $1.0450 | powershell |
| CSV Report Generator | powershell-strict | sonnet | 392s | 29 | 535 | 0 | $0.9737 | powershell |
| Log File Analyzer | default | opus | 249s | 43 | 1464 | 0 | $1.1836 | python |
| Log File Analyzer | default | sonnet | 176s | 19 | 2268 | 0 | $0.4822 | python |
| Log File Analyzer | powershell | opus | 273s | 41 | 558 | 0 | $1.1400 | powershell |
| Log File Analyzer | powershell | sonnet | 232s | 10 | 681 | 0 | $0.4408 | powershell |
| Log File Analyzer | powershell-strict | opus | 267s | 31 | 552 | 1 | $0.9488 | powershell |
| Log File Analyzer | powershell-strict | sonnet | 228s | 14 | 802 | 1 | $0.5046 | powershell |
| Directory Tree Sync | default | opus | 227s | 43 | 1877 | 0 | $1.1794 | python |
| Directory Tree Sync | default | sonnet | 234s | 11 | 1723 | 1 | $0.4491 | python |
| Directory Tree Sync | powershell | opus | 318s | 42 | 542 | 0 | $1.1256 | powershell |
| Directory Tree Sync | powershell | sonnet | 179s | 11 | 757 | 0 | $0.3690 | powershell |
| Directory Tree Sync | powershell-strict | opus | 323s | 34 | 628 | 0 | $1.2117 | powershell |
| Directory Tree Sync | powershell-strict | sonnet | 259s | 13 | 621 | 0 | $0.4912 | powershell |
| REST API Client | default | opus | 315s | 45 | 1399 | 0 | $1.2150 | python |
| REST API Client | default | sonnet | 109s | 9 | 1065 | 1 | $0.2302 | python |
| REST API Client | powershell | opus | 430s | 51 | 537 | 1 | $1.8175 | powershell |
| REST API Client | powershell | sonnet | 758s | 13 | 427 | 0 | $0.9570 | powershell |
| REST API Client | powershell-strict | opus | 308s | 19 | 673 | 0 | $0.9416 | powershell |
| REST API Client | powershell-strict | sonnet | 552s | 14 | 686 | 0 | $0.9926 | powershell |
| Process Monitor | default | opus | 201s | 40 | 1305 | 1 | $1.0020 | python |
| Process Monitor | default | sonnet | 120s | 12 | 865 | 0 | $0.2472 | python |
| Process Monitor | powershell | opus | 323s | 39 | 392 | 0 | $1.2114 | powershell |
| Process Monitor | powershell | sonnet | 227s | 13 | 389 | 0 | $0.4025 | powershell |
| Process Monitor | powershell-strict | opus | 339s | 53 | 411 | 0 | $1.6143 | powershell |
| Process Monitor | powershell-strict | sonnet | 274s | 19 | 461 | 0 | $0.5378 | powershell |
| Config File Migrator | default | opus | 166s | 14 | 2361 | 1 | $0.5923 | python |
| Config File Migrator | default | sonnet | 203s | 18 | 1806 | 1 | $0.4700 | python |
| Config File Migrator | powershell | opus | 225s | 20 | 666 | 0 | $0.6864 | powershell |
| Config File Migrator | powershell | sonnet | 204s | 15 | 894 | 0 | $0.3763 | powershell |
| Config File Migrator | powershell-strict | opus | 162s | 12 | 754 | 0 | $0.4873 | powershell |
| Config File Migrator | powershell-strict | sonnet | 831s | 21 | 1161 | 0 | $1.6028 | powershell |
| Batch File Renamer | default | opus | 169s | 30 | 1069 | 2 | $0.8066 | python |
| Batch File Renamer | default | sonnet | 136s | 8 | 1462 | 0 | $0.2221 | python |
| Batch File Renamer | powershell | opus | 179s | 21 | 351 | 0 | $0.5923 | powershell |
| Batch File Renamer | powershell | sonnet | 84s | 6 | 351 | 0 | $0.1575 | powershell |
| Batch File Renamer | powershell-strict | opus | 269s | 35 | 470 | 0 | $1.0489 | powershell |
| Batch File Renamer | powershell-strict | sonnet | 220s | 16 | 536 | 1 | $0.5014 | powershell |
| Database Seed Script | default | opus | 257s | 36 | 2359 | 1 | $1.0377 | python |
| Database Seed Script | default | sonnet | 232s | 1 | 0 | 0 | $0.0000 |  |
| Database Seed Script | powershell | opus | 349s | 42 | 1334560 | 4 | $1.3223 | powershell |
| Database Seed Script | powershell | sonnet | 226s | 1 | 0 | 0 | $0.0000 | powershell |
| Database Seed Script | powershell-strict | opus | 520s | 56 | 956 | 2 | $2.0318 | powershell |
| Database Seed Script | powershell-strict | sonnet | 214s | 1 | 0 | 0 | $0.0000 | powershell |
| Error Retry Pipeline | default | opus | 141s | 24 | 1364 | 0 | $0.5407 | python |
| Error Retry Pipeline | default | sonnet | 222s | 1 | 0 | 0 | $0.0000 |  |
| Error Retry Pipeline | powershell | opus | 229s | 34 | 368 | 0 | $0.9345 | powershell |
| Error Retry Pipeline | powershell | sonnet | 230s | 1 | 0 | 0 | $0.0000 | powershell |
| Error Retry Pipeline | powershell-strict | opus | 582s | 0 | 425 | 1 | $0.0000 | powershell |
| Error Retry Pipeline | powershell-strict | sonnet | 230s | 1 | 0 | 0 | $0.0000 | powershell |
| Multi-file Search and Replace | default | opus | 187s | 25 | 1388 | 3 | $0.6984 | python |
| Multi-file Search and Replace | default | sonnet | 233s | 1 | 0 | 0 | $0.0000 |  |
| Multi-file Search and Replace | powershell | opus | 217s | 21 | 449 | 0 | $0.6532 | powershell |
| Multi-file Search and Replace | powershell | sonnet | 84s | 10 | 339 | 0 | $0.1878 | powershell |
| Multi-file Search and Replace | powershell-strict | opus | 246s | 34 | 499 | 0 | $1.0863 | powershell |
| Multi-file Search and Replace | powershell-strict | sonnet | 228s | 1 | 0 | 0 | $0.0000 | powershell |
| Semantic Version Bumper | default | opus | 289s | 47 | 1747 | 5 | $1.2263 | python |
| Semantic Version Bumper | default | sonnet | 149s | 11 | 1356 | 0 | $0.2463 | python |
| Semantic Version Bumper | powershell | opus | 213s | 27 | 462 | 0 | $0.7660 | powershell |
| Semantic Version Bumper | powershell | sonnet | 160s | 16 | 647 | 0 | $0.3266 | powershell |
| Semantic Version Bumper | powershell-strict | opus | 347s | 52 | 620 | 0 | $1.5745 | powershell |
| Semantic Version Bumper | powershell-strict | sonnet | 317s | 5 | 353 | 0 | $0.1545 | powershell |
| PR Label Assigner | default | opus | 115s | 11 | 991 | 1 | $0.3754 | python |
| PR Label Assigner | default | sonnet | 106s | 8 | 1189 | 0 | $0.2131 | python |
| PR Label Assigner | powershell | opus | 187s | 23 | 358 | 0 | $0.6116 | powershell |
| PR Label Assigner | powershell | sonnet | 220s | 10 | 515 | 0 | $0.3819 | powershell |
| PR Label Assigner | powershell-strict | opus | 241s | 37 | 396 | 0 | $1.0323 | powershell |
| PR Label Assigner | powershell-strict | sonnet | 196s | 12 | 526 | 0 | $0.3534 | powershell |
| Dependency License Checker | default | opus | 339s | 64 | 1836 | 4 | $1.7285 | python |
| Dependency License Checker | default | sonnet | 239s | 1 | 0 | 0 | $0.0000 |  |
| Dependency License Checker | powershell | opus | 346s | 45 | 547 | 1 | $1.3678 | powershell |
| Dependency License Checker | powershell | sonnet | 154s | 11 | 660 | 0 | $0.3637 | powershell |
| Dependency License Checker | powershell-strict | opus | 326s | 52 | 717 | 4 | $1.5926 | powershell |
| Dependency License Checker | powershell-strict | sonnet | 569s | 18 | 655 | 0 | $0.9721 | powershell |
| Docker Image Tag Generator | default | opus | 161s | 30 | 969 | 0 | $0.6692 | python |
| Docker Image Tag Generator | default | sonnet | 108s | 10 | 685 | 1 | $0.2314 | python |
| Docker Image Tag Generator | powershell | opus | 208s | 32 | 222 | 0 | $0.8429 | powershell |
| Docker Image Tag Generator | powershell | sonnet | 177s | 9 | 253 | 0 | $0.3074 | powershell |
| Docker Image Tag Generator | powershell-strict | opus | 299s | 44 | 349 | 0 | $1.2849 | powershell |
| Docker Image Tag Generator | powershell-strict | sonnet | 152s | 13 | 371 | 0 | $0.3266 | powershell |
| Test Results Aggregator | default | opus | 140s | 15 | 2245 | 1 | $0.5118 | python |
| Test Results Aggregator | default | sonnet | 240s | 20 | 2252 | 1 | $0.4928 | python |
| Test Results Aggregator | powershell | opus | 256s | 33 | 789 | 0 | $0.9494 | powershell |
| Test Results Aggregator | powershell | sonnet | 298s | 15 | 654 | 0 | $0.5537 | powershell |
| Test Results Aggregator | powershell-strict | opus | 237s | 24 | 791 | 0 | $0.9494 | powershell |
| Test Results Aggregator | powershell-strict | sonnet | 690s | 20 | 1119 | 0 | $1.4181 | powershell |
| Environment Matrix Generator | default | opus | 281s | 38 | 1757 | 1 | $1.1135 | python |
| Environment Matrix Generator | default | sonnet | 121s | 9 | 1543 | 0 | $0.2634 | python |
| Environment Matrix Generator | powershell | opus | 141s | 18 | 454 | 0 | $0.5393 | powershell |
| Environment Matrix Generator | powershell | sonnet | 169s | 13 | 476 | 0 | $0.3558 | powershell |
| Environment Matrix Generator | powershell-strict | opus | 251s | 31 | 658 | 2 | $0.9627 | powershell |
| Environment Matrix Generator | powershell-strict | sonnet | 325s | 16 | 748 | 0 | $0.6199 | powershell |
| Artifact Cleanup Script | default | opus | 262s | 34 | 1472 | 0 | $0.9818 | python |
| Artifact Cleanup Script | default | sonnet | 157s | 17 | 1378 | 4 | $0.4354 | python |
| Artifact Cleanup Script | powershell | opus | 295s | 30 | 637 | 0 | $1.1647 | powershell |
| Artifact Cleanup Script | powershell | sonnet | 156s | 9 | 457 | 0 | $0.3505 | powershell |
| Artifact Cleanup Script | powershell-strict | opus | 332s | 37 | 721 | 1 | $1.3660 | powershell |
| Artifact Cleanup Script | powershell-strict | sonnet | 217s | 15 | 647 | 0 | $0.4864 | powershell |
| Secret Rotation Validator | default | opus | 158s | 17 | 1100 | 0 | $0.5135 | python |
| Secret Rotation Validator | default | sonnet | 92s | 11 | 1220 | 0 | $0.2218 | python |
| Secret Rotation Validator | powershell | opus | 197s | 23 | 518 | 1 | $0.7197 | powershell |
| Secret Rotation Validator | powershell | sonnet | 212s | 11 | 718 | 0 | $0.4808 | powershell |
| Secret Rotation Validator | powershell-strict | opus | 318s | 39 | 662 | 2 | $1.2671 | powershell |
| Secret Rotation Validator | powershell-strict | sonnet | 238s | 20 | 553 | 0 | $0.5268 | powershell |

## Comparison by Language Mode

| Mode | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|------|------|-------------|-----------|------------|-----------|------------|
| default | 36 | 195s | 1340 | 0.9 | 20 | $20.6659 |
| powershell | 36 | 237s | 37540 | 0.2 | 21 | $23.8075 |
| powershell-strict | 36 | 327s | 571 | 0.4 | 24 | $30.9072 |

## Comparison by Model

| Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|-------|------|-------------|-----------|------------|-----------|------------|
| opus | 54 | 260s | 25577 | 0.8 | 33 | $53.6866 |
| sonnet | 54 | 246s | 723 | 0.3 | 11 | $21.6940 |

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
| Error Retry Pipeline | sonnet | powershell |  | 222s | 230s | +4% | 0 | 0 | +0 | 0 | 0 |
| Error Retry Pipeline | sonnet | powershell-strict |  | 222s | 230s | +4% | 0 | 0 | +0 | 0 | 0 |
| Multi-file Search and Rep | sonnet | powershell |  | 233s | 84s | -64% | 0 | 0 | +0 | 0 | 339 |
| Multi-file Search and Rep | sonnet | powershell-strict |  | 233s | 228s | -2% | 0 | 0 | +0 | 0 | 0 |
| Semantic Version Bumper | sonnet | powershell | python | 149s | 160s | +8% | 0 | 0 | +0 | 1356 | 647 |
| Semantic Version Bumper | sonnet | powershell-strict | python | 149s | 317s | +112% | 0 | 0 | +0 | 1356 | 353 |
| PR Label Assigner | sonnet | powershell | python | 106s | 220s | +108% | 0 | 0 | +0 | 1189 | 515 |
| PR Label Assigner | sonnet | powershell-strict | python | 106s | 196s | +86% | 0 | 0 | +0 | 1189 | 526 |
| Dependency License Checke | sonnet | powershell |  | 239s | 154s | -36% | 0 | 0 | +0 | 0 | 660 |
| Dependency License Checke | sonnet | powershell-strict |  | 239s | 569s | +138% | 0 | 0 | +0 | 0 | 655 |
| Docker Image Tag Generato | sonnet | powershell | python | 108s | 177s | +64% | 1 | 0 | -1 | 685 | 253 |
| Docker Image Tag Generato | sonnet | powershell-strict | python | 108s | 152s | +42% | 1 | 0 | -1 | 685 | 371 |
| Test Results Aggregator | sonnet | powershell | python | 240s | 298s | +24% | 1 | 0 | -1 | 2252 | 654 |
| Test Results Aggregator | sonnet | powershell-strict | python | 240s | 690s | +187% | 1 | 0 | -1 | 2252 | 1119 |
| Environment Matrix Genera | sonnet | powershell | python | 121s | 169s | +40% | 0 | 0 | +0 | 1543 | 476 |
| Environment Matrix Genera | sonnet | powershell-strict | python | 121s | 325s | +169% | 0 | 0 | +0 | 1543 | 748 |
| Artifact Cleanup Script | sonnet | powershell | python | 157s | 156s | -1% | 4 | 0 | -4 | 1378 | 457 |
| Artifact Cleanup Script | sonnet | powershell-strict | python | 157s | 217s | +39% | 4 | 0 | -4 | 1378 | 647 |
| Secret Rotation Validator | sonnet | powershell | python | 92s | 212s | +131% | 0 | 0 | +0 | 1220 | 718 |
| Secret Rotation Validator | sonnet | powershell-strict | python | 92s | 238s | +160% | 0 | 0 | +0 | 1220 | 553 |

## Observations

- **Fastest run:** Batch File Renamer / powershell / sonnet — 84s
- **Slowest run:** Config File Migrator / powershell-strict / sonnet — 831s
- **Most errors:** Semantic Version Bumper / default / opus — 5 errors
- **Fewest errors:** CSV Report Generator / default / opus — 0 errors

- **Avg cost per run (opus):** $0.9942
- **Avg cost per run (sonnet):** $0.4017

- **Estimated time remaining:** 2.5 hours (based on avg 253s per run)
- **Estimated total cost:** $100.51

---
*Generated by runner.py, instructions version v2*