#!/bin/bash
# Fresh full-matrix benchmark run started 2026-05-06.
#
# Replicates the matrix attempted in results/2026-04-24_202012/ but in a single
# directory to avoid having to combine two partial runs.
#
# Matrix: 7 tasks x 5 modes x 8 model-effort combos = 280 runs.
# Each runner.py invocation runs ONE model-effort combo (35 runs sequentially,
# never parallel). The first invocation creates the run directory; the rest
# resume into it.
#
# Tasks: 11, 12, 13, 15, 16, 17, 18  (task 14 archived)
# Modes: default, powershell, bash, powershell-tool, typescript-bun
# Model-effort combos:
#   1. haiku45 (no effort)
#   2. opus              -> claude-opus-4-6 (no effort)
#   3. sonnet            -> claude-sonnet-4-6 (no effort)
#   4. opus47-1m  high   -> claude-opus-4-7[1m]
#   5. opus47-1m  medium -> claude-opus-4-7[1m]
#   6. opus47-1m  xhigh  -> claude-opus-4-7[1m]
#   7. opus47-200k medium-> claude-opus-4-7
#   8. sonnet46-1m medium-> claude-sonnet-4-6[1m]
#
# Estimated wall time: ~40 hours based on 04-24 timing (~9 min per run).

set -uo pipefail
cd "$(dirname "$0")"

LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/fresh-run-2026-05-06.log"

TASKS="11,12,13,15,16,17,18"
MODES="default,powershell,bash,powershell-tool,typescript-bun"

run_invocation() {
    local desc="$1"
    shift
    {
        echo ""
        echo "==================== $desc ===================="
        echo "Started at:  $(date -Iseconds)"
        echo "Command:     python3 runner.py $*"
    } | tee -a "$LOG_FILE"

    python3 runner.py "$@" 2>&1 | tee -a "$LOG_FILE"
    local rc=${PIPESTATUS[0]}

    {
        echo "Finished at: $(date -Iseconds)"
        echo "Exit code:   $rc"
    } | tee -a "$LOG_FILE"
    return 0  # never abort the matrix on a single failed invocation
}

# Invocation 1 — creates the new results directory.
run_invocation "1/8 haiku45 (no effort)" \
    --tasks "$TASKS" --models haiku45 --modes "$MODES"

# Identify the run directory created by invocation 1 so the rest can resume.
RUN_DIR=$(ls -td results/2026-05-* 2>/dev/null | head -1 | xargs -n1 basename)
if [ -z "$RUN_DIR" ]; then
    echo "ERROR: No 2026-05-* run directory found after invocation 1; aborting." | tee -a "$LOG_FILE"
    exit 1
fi
echo "Run directory: $RUN_DIR" | tee -a "$LOG_FILE"

run_invocation "2/8 opus (no effort)" \
    --resume "$RUN_DIR" --tasks "$TASKS" --models opus --modes "$MODES"

run_invocation "3/8 sonnet (no effort)" \
    --resume "$RUN_DIR" --tasks "$TASKS" --models sonnet --modes "$MODES"

run_invocation "4/8 opus47-1m, effort=high" \
    --resume "$RUN_DIR" --tasks "$TASKS" --models opus47-1m --effort high --modes "$MODES"

run_invocation "5/8 opus47-1m, effort=medium" \
    --resume "$RUN_DIR" --tasks "$TASKS" --models opus47-1m --effort medium --modes "$MODES"

run_invocation "6/8 opus47-1m, effort=xhigh" \
    --resume "$RUN_DIR" --tasks "$TASKS" --models opus47-1m --effort xhigh --modes "$MODES"

run_invocation "7/8 opus47-200k, effort=medium" \
    --resume "$RUN_DIR" --tasks "$TASKS" --models opus47-200k --effort medium --modes "$MODES"

run_invocation "8/8 sonnet46-1m, effort=medium" \
    --resume "$RUN_DIR" --tasks "$TASKS" --models sonnet46-1m --effort medium --modes "$MODES"

{
    echo ""
    echo "==================== ALL DONE ===================="
    echo "Finished at: $(date -Iseconds)"
    echo "Run dir:     results/$RUN_DIR"
} | tee -a "$LOG_FILE"
