#!/bin/bash
# watchdog.sh — Restarts runner.py with --resume if it crashes.
# Usage: ./watchdog.sh <run_timestamp> [runner args...]
# Example: ./watchdog.sh 2026-04-02_181500 --tasks all --models opus,sonnet --modes default,powershell,powershell-strict,csharp-script

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
RUN_TIMESTAMP="${1:?Usage: watchdog.sh <run_timestamp> [runner args...]}"
shift
RUNNER_ARGS=("$@")
LOG="/tmp/benchmark-run.log"
MAX_RESTARTS=200  # generous limit for 144 runs

restart_count=0

while [ "$restart_count" -lt "$MAX_RESTARTS" ]; do
    restart_count=$((restart_count + 1))

    # Count completed runs
    completed=$(find "$REPO/results/$RUN_TIMESTAMP/tasks" -name "metrics.json" 2>/dev/null | wc -l)
    echo "[$(date +%H:%M:%S)] Watchdog: attempt $restart_count, $completed runs completed so far" >> "$LOG"

    # Check if all runs are done (look for summary.json as the signal)
    if [ -f "$REPO/results/$RUN_TIMESTAMP/summary.json" ]; then
        echo "[$(date +%H:%M:%S)] Watchdog: summary.json found, all runs complete!" >> "$LOG"
        break
    fi

    # Run the benchmark with --resume
    echo "[$(date +%H:%M:%S)] Watchdog: starting runner.py --resume $RUN_TIMESTAMP ${RUNNER_ARGS[*]}" >> "$LOG"
    cd "$REPO"
    python3 runner.py --resume "$RUN_TIMESTAMP" "${RUNNER_ARGS[@]}" >> "$LOG" 2>&1 || true

    # Brief pause before restart
    sleep 5

    # Re-check completion
    completed=$(find "$REPO/results/$RUN_TIMESTAMP/tasks" -name "metrics.json" 2>/dev/null | wc -l)
    echo "[$(date +%H:%M:%S)] Watchdog: runner exited, $completed runs completed" >> "$LOG"
done

echo "[$(date +%H:%M:%S)] Watchdog: finished after $restart_count attempts" >> "$LOG"
