---
name: run-benchmark
description: Run the v4 benchmark suite. Use when the user wants to execute benchmark runs against Claude Code agents with specific tasks, modes, and models.
compatibility: Requires claude CLI, actionlint, act, docker, pwsh, bun, bats, shellcheck
---

# Run Benchmark

Ask the user which tasks (11,12,13,15,16,17,18 — task 14 archived; default: all 7), language modes (default/powershell/powershell-tool/bash/typescript-bun; default: all 5), and models (opus, sonnet, opus47-1m, opus47-200k, sonnet46-1m, haiku45 — see `models.py`; default: opus,sonnet) unless they already specified. For multi-effort matrices (e.g. opus47-1m at high+medium+xhigh), use a wrapper script that runs `runner.py` once per (model, effort) combo with `--resume` after the first call — see `run-fresh-matrix-2026-05-06.sh` for the canonical pattern.

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
   Single (model, effort) combo:
   ```bash
   python3 runner.py --tasks 11,12,13,15,16,17,18 --modes default,powershell,powershell-tool,bash,typescript-bun --models opus,sonnet
   ```
   - To resume: add `--resume <timestamp-dir>` (subsequent invocations writing to the same dir).
   - To set a non-default reasoning effort: add `--effort {low,medium,high,xhigh,max}` (variant dir name then carries the effort suffix).
   - To change timeout: add `--timeout <minutes>` (0 = unlimited).
   For multi-(model,effort) matrices, drive sequential invocations from a wrapper script (one per combo, first creates dir, rest `--resume`); never run `runner.py` invocations in parallel.

4. **Monitor progress** — periodically check:
   ```bash
   find results/<run-dir>/tasks -name "metrics.json" | wc -l  # completed count
   tail -3 /tmp/benchmark-*.log  # current activity
   ```

5. **After completion**, regenerate reports and per-CC-version docs:
   ```bash
   python3 generate_results.py --all
   python3 version_docs.py results/<run-dir>
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
