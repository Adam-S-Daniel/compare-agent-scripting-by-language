# Benchmark Results: PowerShell vs Default Language

**Last updated:** 2026-04-04 03:57:37 PM ET

**Status:** 26/144 runs completed, 118 remaining
**Total cost so far:** $77.2641
**Total agent time so far:** 147937s (2465.6 min)

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

## Comparison by Language Mode

| Mode | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|------|------|-------------|-----------|------------|-----------|------------|
| csharp-script | 6 | 9236s | 984 | 91.0 | 119 | $23.8595 |
| default | 7 | 3604s | 692 | 105.3 | 111 | $19.5804 |
| powershell | 7 | 5669s | 621 | 57.7 | 70 | $14.1937 |
| powershell-strict | 6 | 4603s | 744 | 88.7 | 103 | $19.6305 |

## Comparison by Model

| Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|-------|------|-------------|-----------|------------|-----------|------------|
| opus | 14 | 7658s | 676 | 127.7 | 134 | $58.7125 |
| sonnet | 12 | 3393s | 842 | 35.9 | 60 | $18.5516 |

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
| REST API Client | opus | powershell | python | 9428s | 15450s | +64% | 118 | 0 | -118 | 579 | 629 |

## Observations

- **Fastest run:** Log File Analyzer / default / sonnet — 634s
- **Slowest run:** CSV Report Generator / csharp-script / opus — 16271s
- **Most errors:** CSV Report Generator / default / opus — 225 errors
- **Fewest errors:** CSV Report Generator / csharp-script / opus — 0 errors

- **Avg cost per run (opus):** $4.1938
- **Avg cost per run (sonnet):** $1.5460

- **Estimated time remaining:** 186.5 hours (based on avg 5690s per run)
- **Estimated total cost:** $427.92

---
*Generated by runner.py, instructions version v1*