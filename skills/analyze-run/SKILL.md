---
name: analyze-run
description: Deep-dive analysis of a benchmark run. Use when the user wants to understand what happened in a run, find anomalies, or investigate specific agent behaviors.
---

# Analyze Run

The user specifies a run directory (e.g., `results/2026-04-09_152435`) or "latest".

## Steps

1. **Load metrics** from all `tasks/*/metrics.json` in the run directory.

2. **Status report**: completion count, total cost, total duration, any failures.

3. **Anomaly scan**:
   - `exit_code != 0`
   - Missing `act-result.txt` or failed `actionlint_pass`
   - Low turn counts (possible double-result bug)
   - Suspiciously short durations (< 30s for a GHA task)
   - Check cli-output.json for multiple `type: result` events

4. **Trap detection**: Import and run `_detect_traps` from `generate_results.py` on each run's events + console log.

5. **Hook savings**: Compute gross saved, overhead (per language/model combo), and net. Use `all_tool_uses` for real test time when available. Note that typescript-bun/opus has very high hook overhead (tsc takes 12-21s per Write on large files).

6. **Identify outliers**: Find the most interesting/unusual runs and explain why by reading their `console-log.txt`.

7. **Compare across versions**: If prior runs exist, compare avg duration, cost, and trap rates.

## Analysis style

The user values deep "why" analysis over surface metrics. When something looks unusual:
- Read the console-log.txt and trace the agent's narrative
- Identify the specific decision or trap that caused the outcome
- Compare against the same task in other modes/models
- Use concrete transcript evidence, not just numbers
