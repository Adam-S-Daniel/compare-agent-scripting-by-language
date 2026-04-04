# Benchmark Results: PowerShell vs Default Language

**Last updated:** 2026-04-04 12:25:35 AM ET

**Status:** 23/144 runs completed, 121 remaining
**Total cost so far:** $71.7614
**Total agent time so far:** 114431s (1907.2 min)

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

## Comparison by Language Mode

| Mode | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|------|------|-------------|-----------|------------|-----------|------------|
| csharp-script | 5 | 9357s | 887 | 99.4 | 126 | $21.4345 |
| default | 6 | 2633s | 711 | 103.2 | 111 | $16.5026 |
| powershell | 6 | 4038s | 620 | 67.3 | 81 | $14.1937 |
| powershell-strict | 6 | 4603s | 744 | 88.7 | 103 | $19.6305 |

## Comparison by Model

| Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|-------|------|-------------|-----------|------------|-----------|------------|
| opus | 12 | 6862s | 688 | 139.2 | 147 | $55.6348 |
| sonnet | 11 | 2917s | 785 | 34.7 | 58 | $16.1266 |

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
| Directory Tree Sync | opus | csharp-script | python | 1566s | 12122s | +674% | 9 | 205 | +196 | 679 | 851 |

## Observations

- **Fastest run:** Log File Analyzer / default / sonnet — 634s
- **Slowest run:** CSV Report Generator / csharp-script / opus — 16271s
- **Most errors:** CSV Report Generator / default / opus — 225 errors
- **Fewest errors:** CSV Report Generator / csharp-script / opus — 0 errors

- **Avg cost per run (opus):** $4.6362
- **Avg cost per run (sonnet):** $1.4661

- **Estimated time remaining:** 167.2 hours (based on avg 4975s per run)
- **Estimated total cost:** $449.29

---
*Generated by runner.py, instructions version v1*