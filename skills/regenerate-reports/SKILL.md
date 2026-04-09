---
name: regenerate-reports
description: Regenerate results.md for all benchmark runs and update the README index. Use after changing generate_results.py or when reports need refreshing.
---

# Regenerate Reports

## Steps

1. **Back up current results** (optional but recommended after code changes):
   ```bash
   cp results/2026-04-08_192624/results.md /tmp/results-backup.md
   ```

2. **Regenerate all**:
   ```bash
   python3 generate_results.py --all
   ```

3. **Verify** the output matches expectations:
   ```bash
   # If you backed up, diff against it (ignoring timestamp):
   diff <(grep -v "Last updated" /tmp/results-backup.md) <(grep -v "Last updated" results/2026-04-08_192624/results.md)
   ```

4. **Spot-check** a few dollar amounts and durations against raw metrics.json files.

## Options

- `python3 generate_results.py results/<timestamp>` — regenerate one run
- `python3 generate_results.py --all` — regenerate all runs + update README
- `python3 generate_results.py --update-readme` — only update README runs table
