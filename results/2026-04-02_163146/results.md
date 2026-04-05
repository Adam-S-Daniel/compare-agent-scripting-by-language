# Benchmark Results: PowerShell vs Default Language

**Last updated:** 2026-04-05 09:15:19 AM ET

**Status:** 54/144 runs completed, 90 remaining
**Total cost so far:** $165.2107
**Total agent time so far:** 232401s (3873.4 min)

## Per-Run Results

| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language |
|------|------|-------|----------|-------|-------|--------|------|----------|
| CSV Report Generator | default | opus | 1430s | 222 | 371 | 225 | $4.9207 | python |
| CSV Report Generator | powershell | opus | 686s | 97 | 479 | 89 | $3.0525 | powershell |
| CSV Report Generator | powershell-strict | opus | 971s | 168 | 604 | 176 | $5.7927 | powershell |
| CSV Report Generator | csharp-script | opus | 16271s | 0 | 165 | 0 | $0.0000 | csharp |
| CSV Report Generator | default | sonnet | 3190s | 37 | 511 | 25 | $0.6518 | python |
| CSV Report Generator | powershell | sonnet | 3368s | 52 | 439 | 27 | $0.9730 | powershell |
| CSV Report Generator | powershell-strict | sonnet | 7297s | 74 | 604 | 41 | $1.7480 | powershell |
| CSV Report Generator | csharp-script | sonnet | 6765s | 48 | 669 | 26 | $1.1291 | csharp |
| Log File Analyzer | default | opus | 6317s | 195 | 843 | 205 | $5.4331 | javascript |
| Log File Analyzer | powershell | opus | 8633s | 123 | 612 | 105 | $3.8801 | powershell |
| Log File Analyzer | powershell-strict | opus | 7731s | 155 | 795 | 134 | $5.4362 | powershell |
| Log File Analyzer | csharp-script | opus | 10102s | 221 | 1302 | 193 | $8.6591 | csharp |
| Log File Analyzer | default | sonnet | 634s | 72 | 1204 | 48 | $1.8364 | python |
| Log File Analyzer | powershell | sonnet | 634s | 62 | 784 | 51 | $1.7798 | powershell |
| Log File Analyzer | powershell-strict | sonnet | 1513s | 52 | 863 | 22 | $1.3743 | powershell |
| Log File Analyzer | csharp-script | sonnet | 1525s | 131 | 1446 | 73 | $4.1058 | csharp |
| Directory Tree Sync | default | opus | 2661s | 122 | 659 | 107 | $3.2416 | python |
| Directory Tree Sync | powershell | opus | 6736s | 93 | 759 | 91 | $2.9674 | powershell |
| Directory Tree Sync | powershell-strict | opus | 8683s | 140 | 810 | 140 | $4.7107 | powershell |
| Directory Tree Sync | csharp-script | opus | 12122s | 229 | 851 | 205 | $7.5406 | csharp |
| Directory Tree Sync | default | sonnet | 1566s | 17 | 679 | 9 | $0.4190 | python |
| Directory Tree Sync | powershell | sonnet | 4174s | 60 | 648 | 41 | $1.5409 | powershell |
| Directory Tree Sync | powershell-strict | sonnet | 1423s | 31 | 786 | 19 | $0.5687 | powershell |
| Directory Tree Sync | csharp-script | sonnet | 8628s | 83 | 1468 | 49 | $2.4250 | csharp |
| REST API Client | default | opus | 9428s | 113 | 579 | 118 | $3.0777 | python |
| REST API Client | powershell | opus | 15450s | 0 | 629 | 0 | $0.0000 | powershell |
| REST API Client | powershell-strict | opus | 22713s | 101 | 1073 | 87 | $4.0578 | powershell |
| REST API Client | csharp-script | opus | 1358s | 195 | 1615 | 177 | $7.3198 | csharp |
| REST API Client | default | sonnet | 648s | 54 | 707 | 33 | $1.4887 | python |
| REST API Client | powershell | sonnet | 832s | 56 | 699 | 35 | $1.9341 | powershell |
| REST API Client | powershell-strict | sonnet | 805s | 41 | 678 | 27 | $1.8197 | powershell |
| REST API Client | csharp-script | sonnet | 1394s | 74 | 1133 | 63 | $3.9074 | csharp |
| Process Monitor | default | opus | 591s | 115 | 580 | 109 | $2.3380 | python |
| Process Monitor | powershell | opus | 875s | 96 | 598 | 78 | $3.2832 | powershell |
| Process Monitor | powershell-strict | opus | 918s | 126 | 720 | 114 | $3.9954 | powershell |
| Process Monitor | csharp-script | opus | 1299s | 182 | 832 | 188 | $5.9977 | csharp |
| Process Monitor | default | sonnet | 589s | 76 | 578 | 61 | $1.6030 | python |
| Process Monitor | powershell | sonnet | 397s | 53 | 476 | 33 | $1.1127 | powershell |
| Process Monitor | powershell-strict | sonnet | 846s | 46 | 721 | 39 | $2.1097 | powershell |
| Process Monitor | csharp-script | sonnet | 791s | 61 | 971 | 33 | $1.8942 | csharp |
| Config File Migrator | default | opus | 1004s | 165 | 1053 | 150 | $5.1106 | python |
| Config File Migrator | powershell | opus | 753s | 115 | 1063 | 90 | $3.6505 | powershell |
| Config File Migrator | powershell-strict | opus | 972s | 154 | 1244 | 130 | $5.7712 | powershell |
| Config File Migrator | csharp-script | opus | 3254s | 0 | 1899 | 0 | $0.0000 | csharp |
| Config File Migrator | default | sonnet | 3510s | 102 | 992 | 65 | $2.4425 | python |
| Config File Migrator | powershell | sonnet | 3123s | 81 | 1018 | 60 | $2.5735 | powershell |
| Config File Migrator | powershell-strict | sonnet | 2694s | 69 | 779 | 40 | $1.8438 | powershell |
| Config File Migrator | csharp-script | sonnet | 4419s | 138 | 1947 | 58 | $5.3177 | csharp |
| Batch File Renamer | default | opus | 2033s | 106 | 716 | 109 | $2.7642 | python |
| Batch File Renamer | powershell | opus | 4044s | 104 | 900 | 117 | $3.3200 | powershell |
| Batch File Renamer | powershell-strict | opus | 4577s | 163 | 647 | 148 | $5.5986 | powershell |
| Batch File Renamer | csharp-script | opus | 2425s | 108 | 1009 | 134 | $3.3431 | csharp |
| Batch File Renamer | default | sonnet | 2802s | 58 | 555 | 44 | $1.2746 | python |
| Batch File Renamer | powershell | sonnet | 14801s | 67 | 481 | 37 | $2.0749 | powershell |

## Comparison by Language Mode

| Mode | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|------|------|-------------|-----------|------------|-----------|------------|
| csharp-script | 13 | 5412s | 1177 | 92.2 | 113 | $51.6394 |
| default | 14 | 2600s | 716 | 93.4 | 104 | $36.6021 |
| powershell | 14 | 4607s | 685 | 61.0 | 76 | $32.1425 |
| powershell-strict | 13 | 4703s | 794 | 85.9 | 102 | $44.8268 |

## Comparison by Model

| Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|-------|------|-------------|-----------|------------|-----------|------------|
| opus | 28 | 5501s | 836 | 122.1 | 129 | $115.2628 |
| sonnet | 26 | 3014s | 840 | 40.7 | 65 | $49.9479 |

## Head-to-Head: Default vs Constrained Language

| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Delta | Def Err | Mode Err | Err Delta | Def Lines | Mode Lines |
|------|-------|------|-------------|---------|----------|-----------|---------|----------|-----------|-----------|------------|
| CSV Report Generator | sonnet | powershell | python | 3190s | 3368s | +6% | 25 | 27 | +2 | 511 | 439 |
| CSV Report Generator | sonnet | powershell-strict | python | 3190s | 7297s | +129% | 25 | 41 | +16 | 511 | 604 |
| CSV Report Generator | sonnet | csharp-script | python | 3190s | 6765s | +112% | 25 | 26 | +1 | 511 | 669 |
| Log File Analyzer | sonnet | powershell | python | 634s | 634s | +0% | 48 | 51 | +3 | 1204 | 784 |
| Log File Analyzer | sonnet | powershell-strict | python | 634s | 1513s | +138% | 48 | 22 | -26 | 1204 | 863 |
| Log File Analyzer | sonnet | csharp-script | python | 634s | 1525s | +140% | 48 | 73 | +25 | 1204 | 1446 |
| Directory Tree Sync | sonnet | powershell | python | 1566s | 4174s | +167% | 9 | 41 | +32 | 679 | 648 |
| Directory Tree Sync | sonnet | powershell-strict | python | 1566s | 1423s | -9% | 9 | 19 | +10 | 679 | 786 |
| Directory Tree Sync | sonnet | csharp-script | python | 1566s | 8628s | +451% | 9 | 49 | +40 | 679 | 1468 |
| REST API Client | sonnet | powershell | python | 648s | 832s | +28% | 33 | 35 | +2 | 707 | 699 |
| REST API Client | sonnet | powershell-strict | python | 648s | 805s | +24% | 33 | 27 | -6 | 707 | 678 |
| REST API Client | sonnet | csharp-script | python | 648s | 1394s | +115% | 33 | 63 | +30 | 707 | 1133 |
| Process Monitor | sonnet | powershell | python | 589s | 397s | -33% | 61 | 33 | -28 | 578 | 476 |
| Process Monitor | sonnet | powershell-strict | python | 589s | 846s | +44% | 61 | 39 | -22 | 578 | 721 |
| Process Monitor | sonnet | csharp-script | python | 589s | 791s | +34% | 61 | 33 | -28 | 578 | 971 |
| Config File Migrator | sonnet | powershell | python | 3510s | 3123s | -11% | 65 | 60 | -5 | 992 | 1018 |
| Config File Migrator | sonnet | powershell-strict | python | 3510s | 2694s | -23% | 65 | 40 | -25 | 992 | 779 |
| Config File Migrator | sonnet | csharp-script | python | 3510s | 4419s | +26% | 65 | 58 | -7 | 992 | 1947 |
| Batch File Renamer | sonnet | powershell | python | 2802s | 14801s | +428% | 44 | 37 | -7 | 555 | 481 |
| Batch File Renamer | opus | powershell-strict | python | 2802s | 4577s | +63% | 44 | 148 | +104 | 555 | 647 |
| Batch File Renamer | opus | csharp-script | python | 2802s | 2425s | -13% | 44 | 134 | +90 | 555 | 1009 |

## Observations

- **Fastest run:** Process Monitor / powershell / sonnet — 397s
- **Slowest run:** REST API Client / powershell-strict / opus — 22713s
- **Most errors:** CSV Report Generator / default / opus — 225 errors
- **Fewest errors:** CSV Report Generator / csharp-script / opus — 0 errors

- **Avg cost per run (opus):** $4.1165
- **Avg cost per run (sonnet):** $1.9211

- **Estimated time remaining:** 107.6 hours (based on avg 4304s per run)
- **Estimated total cost:** $440.56

---
*Generated by runner.py, instructions version v1*