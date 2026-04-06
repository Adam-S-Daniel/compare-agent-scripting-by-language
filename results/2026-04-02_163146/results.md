# Benchmark Results: PowerShell vs Default Language

**Last updated:** 2026-04-06 02:18:12 AM ET

**Status:** 128/144 runs completed, 16 remaining
**Total cost so far:** $391.3317
**Total agent time so far:** 293925s (4898.8 min)

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
| Batch File Renamer | powershell-strict | sonnet | 754s | 48 | 626 | 30 | $1.3831 | powershell |
| Batch File Renamer | csharp-script | sonnet | 1156s | 60 | 1088 | 121 | $3.7570 | csharp |
| Database Seed Script | default | opus | 788s | 146 | 843 | 141 | $3.8264 | python |
| Database Seed Script | powershell | opus | 863s | 167 | 1115 | 140 | $5.6064 | powershell |
| Database Seed Script | powershell-strict | opus | 1188s | 162 | 1500 | 160 | $6.5363 | powershell |
| Database Seed Script | csharp-script | opus | 684s | 122 | 1340 | 103 | $3.4942 | csharp |
| Database Seed Script | default | sonnet | 978s | 42 | 742 | 28 | $0.9774 | python |
| Database Seed Script | powershell | sonnet | 724s | 60 | 813 | 36 | $1.6658 | powershell |
| Database Seed Script | powershell-strict | sonnet | 763s | 35 | 1178 | 17 | $1.6470 | powershell |
| Database Seed Script | csharp-script | sonnet | 1687s | 0 | 2013 | 0 | $0.0000 | csharp |
| Error Retry Pipeline | default | opus | 1024s | 156 | 870 | 140 | $3.9251 |  |
| Error Retry Pipeline | powershell | opus | 877s | 80 | 665 | 90 | $3.2582 | powershell |
| Error Retry Pipeline | powershell-strict | opus | 668s | 114 | 941 | 103 | $3.1683 | powershell |
| Error Retry Pipeline | csharp-script | opus | 1562s | 173 | 1067 | 194 | $6.9673 | csharp |
| Error Retry Pipeline | default | sonnet | 530s | 69 | 636 | 42 | $1.5031 | python |
| Error Retry Pipeline | powershell | sonnet | 492s | 42 | 628 | 22 | $1.0519 | powershell |
| Error Retry Pipeline | powershell-strict | sonnet | 427s | 35 | 479 | 17 | $0.9192 | powershell |
| Error Retry Pipeline | csharp-script | sonnet | 607s | 71 | 797 | 42 | $1.4938 | csharp |
| Multi-file Search and Replace | default | opus | 953s | 181 | 656 | 171 | $4.4533 | python |
| Multi-file Search and Replace | powershell | opus | 1026s | 126 | 726 | 124 | $4.5568 | powershell |
| Multi-file Search and Replace | powershell-strict | opus | 730s | 129 | 496 | 130 | $3.5171 | powershell |
| Multi-file Search and Replace | csharp-script | opus | 1040s | 134 | 1281 | 130 | $4.5581 | csharp |
| Multi-file Search and Replace | default | sonnet | 270s | 25 | 786 | 21 | $0.7094 | python |
| Multi-file Search and Replace | powershell | sonnet | 527s | 49 | 471 | 49 | $1.1689 | powershell |
| Multi-file Search and Replace | powershell-strict | sonnet | 919s | 69 | 957 | 62 | $2.4076 | powershell |
| Multi-file Search and Replace | csharp-script | sonnet | 875s | 94 | 892 | 66 | $2.3859 | csharp |
| Semantic Version Bumper | default | opus | 719s | 129 | 829 | 115 | $3.3357 | python |
| Semantic Version Bumper | powershell | opus | 798s | 120 | 879 | 100 | $3.8446 | powershell |
| Semantic Version Bumper | powershell-strict | opus | 1111s | 225 | 866 | 210 | $7.9636 | powershell |
| Semantic Version Bumper | csharp-script | opus | 369s | 65 | 18 | 96 | $1.3860 | bash |
| Semantic Version Bumper | default | sonnet | 775s | 98 | 714 | 58 | $2.1612 | python |
| Semantic Version Bumper | powershell | sonnet | 820s | 116 | 624 | 96 | $2.5964 | powershell |
| Semantic Version Bumper | powershell-strict | sonnet | 760s | 60 | 773 | 59 | $2.0786 | powershell |
| Semantic Version Bumper | csharp-script | sonnet | 1022s | 64 | 1625 | 42 | $2.6672 | csharp |
| PR Label Assigner | default | opus | 965s | 140 | 517 | 142 | $3.7654 | python |
| PR Label Assigner | powershell | opus | 598s | 93 | 605 | 75 | $2.4805 | powershell |
| PR Label Assigner | powershell-strict | opus | 667s | 141 | 670 | 130 | $3.7189 | powershell |
| PR Label Assigner | csharp-script | opus | 1290s | 215 | 1107 | 203 | $7.3275 | csharp |
| PR Label Assigner | default | sonnet | 401s | 26 | 530 | 23 | $0.9230 | python |
| PR Label Assigner | powershell | sonnet | 467s | 44 | 454 | 33 | $1.2552 | powershell |
| PR Label Assigner | powershell-strict | sonnet | 531s | 28 | 542 | 16 | $1.0154 | powershell |
| PR Label Assigner | csharp-script | sonnet | 1259s | 143 | 957 | 95 | $4.2569 | csharp |
| Dependency License Checker | default | opus | 1032s | 217 | 889 | 220 | $5.9962 | python |
| Dependency License Checker | powershell | opus | 896s | 118 | 847 | 99 | $4.1660 | powershell |
| Dependency License Checker | powershell-strict | opus | 876s | 87 | 933 | 60 | $2.7463 | powershell |
| Dependency License Checker | csharp-script | opus | 1311s | 223 | 1316 | 197 | $8.8326 | csharp |
| Dependency License Checker | default | sonnet | 435s | 52 | 729 | 39 | $1.1835 | python |
| Dependency License Checker | powershell | sonnet | 181s | 33 | 555 | 18 | $0.5851 | powershell |
| Dependency License Checker | powershell-strict | sonnet | 943s | 70 | 1016 | 57 | $2.1989 | powershell |
| Dependency License Checker | csharp-script | sonnet | 1596s | 126 | 1413 | 67 | $3.0779 | csharp |
| Docker Image Tag Generator | default | opus | 920s | 156 | 400 | 162 | $3.8236 | python |
| Docker Image Tag Generator | powershell | opus | 745s | 109 | 421 | 101 | $3.0455 | powershell |
| Docker Image Tag Generator | powershell-strict | opus | 731s | 130 | 481 | 127 | $3.3981 | powershell |
| Docker Image Tag Generator | csharp-script | opus | 994s | 154 | 143163 | 139 | $4.5999 | csharp |
| Docker Image Tag Generator | default | sonnet | 229s | 20 | 297 | 17 | $0.5030 | python |
| Docker Image Tag Generator | powershell | sonnet | 808s | 169 | 292 | 143 | $3.4633 | powershell |
| Docker Image Tag Generator | powershell-strict | sonnet | 522s | 59 | 643 | 38 | $1.3398 | powershell |
| Docker Image Tag Generator | csharp-script | sonnet | 797s | 103 | 760 | 88 | $2.2850 | csharp |
| Test Results Aggregator | default | opus | 1014s | 172 | 818 | 203 | $4.9677 | python |
| Test Results Aggregator | powershell | opus | 610s | 89 | 904 | 70 | $3.0967 | powershell |
| Test Results Aggregator | powershell-strict | opus | 1113s | 164 | 990 | 148 | $6.1834 | powershell |
| Test Results Aggregator | csharp-script | opus | 704s | 120 | 1834 | 93 | $3.4022 | csharp |
| Test Results Aggregator | default | sonnet | 612s | 76 | 1375 | 59 | $2.0075 | python |
| Test Results Aggregator | powershell | sonnet | 575s | 63 | 907 | 40 | $1.5669 | powershell |
| Test Results Aggregator | powershell-strict | sonnet | 874s | 37 | 794 | 27 | $1.3284 | powershell |
| Test Results Aggregator | csharp-script | sonnet | 780s | 67 | 1464 | 29 | $2.3248 | csharp |
| Environment Matrix Generator | default | opus | 929s | 119 | 713 | 172 | $3.9295 | python |
| Environment Matrix Generator | powershell | opus | 897s | 148 | 931 | 117 | $4.9329 | powershell |
| Environment Matrix Generator | powershell-strict | opus | 1007s | 137 | 868 | 126 | $4.4838 | powershell |
| Environment Matrix Generator | csharp-script | opus | 1260s | 175 | 1945 | 142 | $6.4697 | csharp |
| Environment Matrix Generator | default | sonnet | 492s | 52 | 925 | 33 | $1.3242 | python |
| Environment Matrix Generator | powershell | sonnet | 402s | 30 | 516 | 33 | $0.8864 | powershell |
| Environment Matrix Generator | powershell-strict | sonnet | 1800s | 0 | 586 | 0 | $0.0000 | powershell |
| Environment Matrix Generator | csharp-script | sonnet | 773s | 85 | 1126 | 59 | $2.2585 | csharp |

## Comparison by Language Mode

| Mode | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|------|------|-------------|-----------|------------|-----------|------------|
| csharp-script | 32 | 2816s | 5641 | 97.0 | 114 | $123.1841 |
| default | 32 | 1546s | 728 | 96.7 | 104 | $85.9171 |
| powershell | 32 | 2400s | 686 | 70.0 | 85 | $81.3700 |
| powershell-strict | 32 | 2423s | 802 | 82.3 | 95 | $100.8605 |

## Comparison by Model

| Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Total Cost |
|-------|------|-------------|-----------|------------|-----------|------------|
| opus | 64 | 2922s | 3091 | 129.6 | 137 | $277.0265 |
| sonnet | 64 | 1671s | 837 | 43.5 | 63 | $114.3052 |

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
| Batch File Renamer | sonnet | powershell-strict | python | 2802s | 754s | -73% | 44 | 30 | -14 | 555 | 626 |
| Batch File Renamer | sonnet | csharp-script | python | 2802s | 1156s | -59% | 44 | 121 | +77 | 555 | 1088 |
| Database Seed Script | sonnet | powershell | python | 978s | 724s | -26% | 28 | 36 | +8 | 742 | 813 |
| Database Seed Script | sonnet | powershell-strict | python | 978s | 763s | -22% | 28 | 17 | -11 | 742 | 1178 |
| Database Seed Script | sonnet | csharp-script | python | 978s | 1687s | +72% | 28 | 0 | -28 | 742 | 2013 |
| Error Retry Pipeline | sonnet | powershell | python | 530s | 492s | -7% | 42 | 22 | -20 | 636 | 628 |
| Error Retry Pipeline | sonnet | powershell-strict | python | 530s | 427s | -20% | 42 | 17 | -25 | 636 | 479 |
| Error Retry Pipeline | sonnet | csharp-script | python | 530s | 607s | +15% | 42 | 42 | +0 | 636 | 797 |
| Multi-file Search and Rep | sonnet | powershell | python | 270s | 527s | +95% | 21 | 49 | +28 | 786 | 471 |
| Multi-file Search and Rep | sonnet | powershell-strict | python | 270s | 919s | +240% | 21 | 62 | +41 | 786 | 957 |
| Multi-file Search and Rep | sonnet | csharp-script | python | 270s | 875s | +224% | 21 | 66 | +45 | 786 | 892 |
| Semantic Version Bumper | sonnet | powershell | python | 775s | 820s | +6% | 58 | 96 | +38 | 714 | 624 |
| Semantic Version Bumper | sonnet | powershell-strict | python | 775s | 760s | -2% | 58 | 59 | +1 | 714 | 773 |
| Semantic Version Bumper | sonnet | csharp-script | python | 775s | 1022s | +32% | 58 | 42 | -16 | 714 | 1625 |
| PR Label Assigner | sonnet | powershell | python | 401s | 467s | +16% | 23 | 33 | +10 | 530 | 454 |
| PR Label Assigner | sonnet | powershell-strict | python | 401s | 531s | +32% | 23 | 16 | -7 | 530 | 542 |
| PR Label Assigner | sonnet | csharp-script | python | 401s | 1259s | +214% | 23 | 95 | +72 | 530 | 957 |
| Dependency License Checke | sonnet | powershell | python | 435s | 181s | -58% | 39 | 18 | -21 | 729 | 555 |
| Dependency License Checke | sonnet | powershell-strict | python | 435s | 943s | +117% | 39 | 57 | +18 | 729 | 1016 |
| Dependency License Checke | sonnet | csharp-script | python | 435s | 1596s | +267% | 39 | 67 | +28 | 729 | 1413 |
| Docker Image Tag Generato | sonnet | powershell | python | 229s | 808s | +252% | 17 | 143 | +126 | 297 | 292 |
| Docker Image Tag Generato | sonnet | powershell-strict | python | 229s | 522s | +128% | 17 | 38 | +21 | 297 | 643 |
| Docker Image Tag Generato | sonnet | csharp-script | python | 229s | 797s | +248% | 17 | 88 | +71 | 297 | 760 |
| Test Results Aggregator | sonnet | powershell | python | 612s | 575s | -6% | 59 | 40 | -19 | 1375 | 907 |
| Test Results Aggregator | sonnet | powershell-strict | python | 612s | 874s | +43% | 59 | 27 | -32 | 1375 | 794 |
| Test Results Aggregator | sonnet | csharp-script | python | 612s | 780s | +27% | 59 | 29 | -30 | 1375 | 1464 |
| Environment Matrix Genera | sonnet | powershell | python | 492s | 402s | -18% | 33 | 33 | +0 | 925 | 516 |
| Environment Matrix Genera | sonnet | powershell-strict | python | 492s | 1800s | +266% | 33 | 0 | -33 | 925 | 586 |
| Environment Matrix Genera | sonnet | csharp-script | python | 492s | 773s | +57% | 33 | 59 | +26 | 925 | 1126 |

## Observations

- **Fastest run:** Dependency License Checker / powershell / sonnet — 181s
- **Slowest run:** REST API Client / powershell-strict / opus — 22713s
- **Most errors:** CSV Report Generator / default / opus — 225 errors
- **Fewest errors:** CSV Report Generator / csharp-script / opus — 0 errors

- **Avg cost per run (opus):** $4.3285
- **Avg cost per run (sonnet):** $1.7860

- **Estimated time remaining:** 10.2 hours (based on avg 2296s per run)
- **Estimated total cost:** $440.25

---
*Generated by runner.py, instructions version v1*