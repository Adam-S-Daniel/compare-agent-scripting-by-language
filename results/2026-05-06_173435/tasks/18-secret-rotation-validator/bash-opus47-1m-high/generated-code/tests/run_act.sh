#!/usr/bin/env bash
# Test harness: stage the project into a fresh temp git repo, run
# `act push --rm` once, and capture combined output (plus the act exit
# code) into act-result.txt at the project root.
#
# We deliberately invoke `act` exactly ONCE (per the task's 3-run cap)
# and run all fixture scenarios as separate steps inside the single
# workflow run. The bats suite then parses sentinel lines from the
# captured output to assert per-fixture behaviour.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACT_RESULT="${PROJECT_ROOT}/act-result.txt"

stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT

# Copy the project into a fresh staging directory so the run is
# self-contained and reproducible.
cp -r \
    "${PROJECT_ROOT}/bin" \
    "${PROJECT_ROOT}/tests" \
    "${PROJECT_ROOT}/.github" \
    "${PROJECT_ROOT}/.actrc" \
    "${stage_dir}/"

cd "${stage_dir}" || exit 1

git init -q
git config user.email "ci@example.com"
git config user.name "ci"
git add -A
git commit -q -m "stage for act" || true

# Run act. We capture stdout+stderr together and tee to a buffer so we
# can also record the exit code as a sentinel line.
act_output=$(act push --rm 2>&1)
act_exit=$?

{
    echo "===== act push --rm ====="
    echo "${act_output}"
    echo "ACT_EXIT_CODE=${act_exit}"
} > "${ACT_RESULT}"

# Forward stdout for caller diagnostics.
cat "${ACT_RESULT}"
exit 0
