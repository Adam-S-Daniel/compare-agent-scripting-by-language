#!/usr/bin/env bash
# run-act.sh — Harness that exercises the workflow under `act` with three
# different fixtures, collecting output into act-result.txt and asserting
# exact expected values for each case.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_FILE="${ROOT}/act-result.txt"
: > "$RESULT_FILE"  # truncate

pass=0
fail=0

# run_case <name> <fixture> <expected_deleted> <expected_retained> <expected_reclaimed>
run_case() {
    local case_name="$1"
    local fixture="$2"
    local exp_deleted="$3"
    local exp_retained="$4"
    local exp_reclaimed="$5"

    echo ""
    echo "=============================================="
    echo "ACT CASE: ${case_name}"
    echo "  fixture=${fixture}"
    echo "  expected: deleted=${exp_deleted} retained=${exp_retained} reclaimed=${exp_reclaimed}"
    echo "=============================================="

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    # Lay out project files in the temp workspace with the case's fixture
    # copied to the canonical path the workflow looks at.
    cp -r "${ROOT}/.github"       "$tmp/.github"
    cp -r "${ROOT}/tests"         "$tmp/tests"
    mkdir -p "${tmp}/fixtures"
    # Copy ALL fixtures (the unit-test fixture is required by the bats suite).
    cp "${ROOT}/fixtures/"*.json "${tmp}/fixtures/"
    # Overwrite the canonical per-case fixture with the one this case exercises.
    cp "${ROOT}/fixtures/${fixture}" "${tmp}/fixtures/sample-artifacts.json"
    cp "${ROOT}/artifact-cleanup.sh" "$tmp/"
    cp "${ROOT}/.actrc"              "$tmp/" 2>/dev/null || true
    chmod +x "$tmp/artifact-cleanup.sh"

    (
        cd "$tmp"
        git init -q
        git config user.email "t@t.t"
        git config user.name  "t"
        git add -A
        git commit -q -m "test fixture"
    )

    local case_log="$tmp/act.log"
    local act_status=0
    (
        cd "$tmp"
        act push --rm --pull=false
    ) >"$case_log" 2>&1 || act_status=$?

    {
        echo ""
        echo "=============================================="
        echo "CASE ${case_name} (exit=${act_status})"
        echo "fixture: ${fixture}"
        echo "=============================================="
        cat "$case_log"
    } >> "$RESULT_FILE"

    local case_pass=1

    if [ "$act_status" -ne 0 ]; then
        echo "  FAIL: act exited ${act_status}"
        case_pass=0
    fi

    if ! grep -q "Job succeeded" "$case_log"; then
        echo "  FAIL: 'Job succeeded' not found"
        case_pass=0
    fi

    # Expect two succeeded jobs (lint-and-test + run-cleanup).
    local succeeded
    succeeded=$(grep -c "Job succeeded" "$case_log" || true)
    if [ "${succeeded}" -lt 2 ]; then
        echo "  FAIL: expected >=2 'Job succeeded', got ${succeeded}"
        case_pass=0
    fi

    for pair in \
        "RESULT_DELETED=${exp_deleted}" \
        "RESULT_RETAINED=${exp_retained}" \
        "RESULT_RECLAIMED=${exp_reclaimed}" \
        "INVARIANT_OK=1"
    do
        if ! grep -q "${pair}" "$case_log"; then
            echo "  FAIL: expected marker ${pair} not found"
            case_pass=0
        else
            echo "  ok: ${pair}"
        fi
    done

    if [ "$case_pass" -eq 1 ]; then
        pass=$(( pass + 1 ))
        echo "  CASE ${case_name}: PASS"
    else
        fail=$(( fail + 1 ))
        echo "  CASE ${case_name}: FAIL"
    fi
}

# Each case's expected values are derived by hand from the fixture,
# given policies: --max-age-days 30 --keep-latest 1 --now 2026-04-19
# (hard-coded in the workflow's run-cleanup job).

# Case A: old-artifact (500MB, wfA) deleted; fresh-artifact (wfA) retained;
#         workflow-b-only (wfB) retained as sole member.
run_case "A-max-age-and-keep-latest"    "case-a-artifacts.json"   1 2 524288000

# Case B: both 2025 artifacts deleted by max-age; recent-1 retained.
run_case "B-all-old-deleted-by-age"     "case-b-artifacts.json"   2 1 3000000

# Case C: all within age, but wf-pr has 2 artifacts so keep-latest=1 evicts
#         the older (all-new-1, 10000 bytes).
run_case "C-keep-latest-only"           "case-c-artifacts.json"   1 1 10000

echo ""
echo "=============================================="
echo "HARNESS RESULT: pass=${pass} fail=${fail}"
echo "act-result.txt size: $(wc -c <"$RESULT_FILE") bytes"
echo "=============================================="

[ "$fail" -eq 0 ]
