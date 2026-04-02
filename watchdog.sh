#!/bin/bash
# watchdog.sh — Polls for runner.py completion and restarts it on crash.
# Runs the runner in a separate process group via setsid so that if
# the watchdog itself is killed, the runner keeps going, and vice versa.
#
# Usage: ./watchdog.sh <run_timestamp> [runner args...]
# Example: ./watchdog.sh 2026-04-02_181500 --tasks all --models opus,sonnet

REPO="$(cd "$(dirname "$0")" && pwd)"
RUN_TIMESTAMP="${1:?Usage: watchdog.sh <run_timestamp> [runner args...]}"
shift
RUNNER_ARGS=("$@")
LOG="/tmp/benchmark-run.log"
PIDFILE="/tmp/benchmark-runner.pid"
MAX_RESTARTS=200
POLL_INTERVAL=30

# Ignore common signals so watchdog survives even if children die
trap '' PIPE HUP

restart_count=0

launch_runner() {
    cd "$REPO"
    # Launch runner in its own session/process group
    setsid python3 runner.py --resume "$RUN_TIMESTAMP" "${RUNNER_ARGS[@]}" >> "$LOG" 2>&1 &
    local pid=$!
    echo "$pid" > "$PIDFILE"
    echo "[$(date +%H:%M:%S)] Watchdog: launched runner PID $pid (attempt $restart_count)" >> "$LOG"
}

is_runner_alive() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

count_completed() {
    find "$REPO/results/$RUN_TIMESTAMP/tasks" -name "metrics.json" 2>/dev/null | wc -l
}

is_fully_done() {
    [ -f "$REPO/results/$RUN_TIMESTAMP/summary.json" ]
}

# ── Main loop ──
while [ "$restart_count" -lt "$MAX_RESTARTS" ]; do
    completed=$(count_completed)

    # Check if fully done
    if is_fully_done; then
        echo "[$(date +%H:%M:%S)] Watchdog: summary.json found, all runs complete! ($completed metrics files)" >> "$LOG"
        break
    fi

    # Check if runner is alive
    if ! is_runner_alive; then
        restart_count=$((restart_count + 1))
        echo "[$(date +%H:%M:%S)] Watchdog: runner not running, $completed completed. Restarting (attempt $restart_count)..." >> "$LOG"

        # Clean up any partial result dirs (those with workspace-before.txt but no metrics.json)
        for dir in "$REPO/results/$RUN_TIMESTAMP/tasks"/*/*; do
            if [ -d "$dir" ] && [ -f "$dir/workspace-before.txt" ] && [ ! -f "$dir/metrics.json" ]; then
                echo "[$(date +%H:%M:%S)] Watchdog: cleaning partial result dir: $(basename "$(dirname "$dir")")/$(basename "$dir")" >> "$LOG"
                rm -rf "$dir"
            fi
        done

        launch_runner
    fi

    sleep "$POLL_INTERVAL"
done

echo "[$(date +%H:%M:%S)] Watchdog: exiting after $restart_count restart(s), $(count_completed) runs completed" >> "$LOG"
