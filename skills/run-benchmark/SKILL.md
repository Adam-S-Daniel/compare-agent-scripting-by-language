---
name: run-benchmark
description: Run the v4 benchmark suite. Use when the user wants to execute benchmark runs against Claude Code agents with specific tasks, modes, and models.
compatibility: Requires claude CLI, actionlint, act, docker, pwsh, bun, bats, shellcheck
---

# Run Benchmark

Ask the user which tasks (11-18, default: all), modes (default/powershell/bash/typescript-bun, default: all), and models (opus/sonnet, default: both) unless they already specified.

## Steps

1. **Verify prerequisites:**
   ```bash
   claude --version && actionlint --version && act --version && docker ps && pwsh --version && bun --version && bats --version
   ```

2. **Build custom act image** (if not already built):
   ```bash
   docker build -t act-ubuntu-pwsh:latest -f Dockerfile.act .
   ```
   Runner.py auto-detects this image and injects `.actrc` into workspaces.

3. **Build and run the command:**
   ```bash
   python3 runner.py --tasks 11,12,13,14,15,16,17,18 --modes default,powershell,bash,typescript-bun --models opus,sonnet
   ```
   - To resume: add `--resume <timestamp-dir>`
   - To change timeout: add `--timeout <minutes>` (0 = unlimited)

4. **Monitor progress** — periodically check:
   ```bash
   find results/<run-dir>/tasks -name "metrics.json" | wc -l  # completed count
   tail -3 /tmp/benchmark-*.log  # current activity
   ```

5. **After completion**, regenerate reports:
   ```bash
   python3 generate_results.py --all
   ```

6. **Anomaly scan** — check all metrics.json for:
   - `exit_code != 0`
   - Missing `act-result.txt`
   - `actionlint_pass` failures
   - Low turn counts (possible double-result bug: check cli-output.json for multiple `type: result` events)

## Known issues

- MCP config must be `{"mcpServers":{}}` not `{}` (the latter causes silent failure)
- If a run times out (exit code -9), re-run with `--timeout 0`
- If you change generate_results.py or runner.py mid-run, stop and resume to pick up the new code
- Always push after committing — the user expects all work on the remote at all times

## v4 vs v3 performance

v4 runs average 8.6min (v3 was 11.4min, 24% faster). Zero failures vs v3's 1 timeout and 3 double-result bugs. The improvement comes from trap-awareness guidance, `shell: pwsh`, and the custom act image.
