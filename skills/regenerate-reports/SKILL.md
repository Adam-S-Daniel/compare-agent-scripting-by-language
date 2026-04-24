---
name: regenerate-reports
description: Regenerate results.md for all benchmark runs and update the README index. Use after changing generate_results.py, combine_results.py, judge_consistency_report.py, or conclusions_report.py.
---

# Regenerate Reports

## Steps

1. **Back up current results** (optional but recommended after code changes):
   ```bash
   cp results/2026-04-08_192624/results.md /tmp/results-backup.md
   ```

2. **Regenerate per-run reports + README**:
   ```bash
   python3 generate_results.py --all
   ```

3. **Regenerate combined cross-run reports** (if any exist in `results/`
   as `results_<dirA>__<dirB>.md`):
   ```bash
   python3 combine_results.py results/<dirA> results/<dirB>
   ```
   Combined reports call the max-effort Claude CLI for the Conclusions
   and Judge Consistency Summary sections. Those calls can exceed the
   default 600s timeout; bump via module attr from a wrapper if needed
   (see `conclusions_report.SUMMARY_TIMEOUT_S`). Results are cached in
   `results/<combined-report>.conclusions-cache.json` keyed on the
   hash of system+user prompts, so re-runs with the same inputs are
   free.

4. **Verify** the output matches expectations:
   ```bash
   # If you backed up, diff against it (ignoring timestamp):
   diff <(grep -v "Last updated" /tmp/results-backup.md) \
        <(grep -v "Last updated" results/2026-04-08_192624/results.md)
   ```

5. **Spot-check** a few dollar amounts and durations against raw
   metrics.json files. Also verify:
   - No duplicate rows in the combined report's Tiers / Comparison
     tables (same Language + Model label appearing twice).
   - CLI Version Legend header reads `| Variant label | CLI version |
     Tasks | Languages |` with exactly one CLI version per row.
   - Judge Consistency Summary renders as a top-level `## Judge
     Consistency Summary` above Tiers, not buried under Notes.

## Options

- `python3 generate_results.py results/<timestamp>` — regenerate one run
- `python3 generate_results.py --all` — regenerate all runs + update README
- `python3 generate_results.py --update-readme` — only update README runs table
- `python3 combine_results.py <dirA> <dirB> [<dirC> …]` — build cross-run combined report
