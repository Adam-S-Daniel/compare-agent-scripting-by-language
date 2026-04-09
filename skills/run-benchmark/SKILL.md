---
name: run-benchmark
description: Run the v3 benchmark suite. Use when the user wants to execute benchmark runs against Claude Code agents with specific tasks, modes, and models.
compatibility: Requires claude CLI, actionlint, act, docker, pwsh, bun, bats, shellcheck
---

# Run Benchmark

Ask the user which tasks (11-18, default: all), modes (default/powershell/bash/typescript-bun, default: all), and models (opus/sonnet, default: both) unless they already specified.

## Steps

1. **Verify prerequisites:**
   ```bash
   claude --version && actionlint --version && act --version && docker ps && pwsh --version && bun --version && bats --version
   ```

2. **Build and run the command:**
   ```bash
   python3 runner.py --tasks 11,12,13,14,15,16,17,18 --modes default,powershell,bash,typescript-bun --models opus,sonnet
   ```
   - To resume: add `--resume <timestamp-dir>`
   - To change timeout: add `--timeout <minutes>` (0 = unlimited)

3. **Monitor progress** — periodically check:
   ```bash
   grep "Finished:" /tmp/benchmark-*.log | tail -5
   grep -E "FATAL|TIMEOUT" /tmp/benchmark-*.log
   ```

4. **After completion**, regenerate reports:
   ```bash
   python3 generate_results.py --all
   ```

5. **Anomaly scan** — check all metrics.json for:
   - `exit_code != 0`
   - Missing `act-result.txt`
   - `actionlint_pass` failures
   - Low turn counts (possible double-result bug: check cli-output.json for multiple `type: result` events)

## Known issues

- MCP config must be `{"mcpServers":{}}` not `{}` (the latter causes silent failure)
- PowerShell/sonnet runs average ~20min and are the most trap-prone
- If a run times out (exit code -9), re-run with `--timeout 0`
- Background task notifications can create a second result event — the parser keeps the first, but verify if metrics look wrong (0-3 turns on a run that produced code)
