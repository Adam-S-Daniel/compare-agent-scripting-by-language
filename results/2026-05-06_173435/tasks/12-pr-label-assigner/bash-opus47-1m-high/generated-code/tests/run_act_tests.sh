#!/usr/bin/env bash
#
# End-to-end harness: runs each test case through the workflow with
# `act push --rm`, captures output to act-result.txt, and asserts on
# exact expected labels for each case.
#
# To avoid burning multiple act runs while iterating, this script
# also performs structure / actionlint checks before any act invocation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

WORKFLOW=".github/workflows/pr-label-assigner.yml"
RESULT_FILE="$REPO_ROOT/act-result.txt"
: > "$RESULT_FILE"

pass=0
fail=0

note() { printf '[harness] %s\n' "$*"; }
record() { printf '%s\n' "$*" >> "$RESULT_FILE"; }

#
# Structural / static checks (no act invocation).
#
note "structure: workflow file exists"
[[ -f $WORKFLOW ]] || { echo "missing workflow: $WORKFLOW" >&2; exit 1; }

note "structure: workflow references label-assigner.sh"
grep -q 'label-assigner.sh' "$WORKFLOW"

note "structure: workflow has push trigger and job"
grep -qE '^[[:space:]]*push:' "$WORKFLOW"
grep -qE '^[[:space:]]*assign-labels:' "$WORKFLOW"
grep -q 'actions/checkout@v4' "$WORKFLOW"

note "structure: actionlint passes"
actionlint "$WORKFLOW"

#
# Per-test-case act runs. Each case writes its rules + files into
# ci/rules.txt and ci/files.txt, runs `act push --rm`, then asserts
# the workflow output.
#
mkdir -p ci

run_case() {
    local name=$1 rules_src=$2 files_src=$3 expected_labels=$4

    note "=== running case: $name ==="
    record ""
    record "############################################################"
    record "# Test case: $name"
    record "# Expected labels: $expected_labels"
    record "############################################################"

    cp "$rules_src" ci/rules.txt
    cp "$files_src" ci/files.txt

    # Stage so `act` (which uses git state) sees a clean tree of all files.
    git add -A >/dev/null 2>&1 || true

    local tmp_out
    tmp_out=$(mktemp)
    local rc=0
    act push --rm --workflows "$WORKFLOW" >"$tmp_out" 2>&1 || rc=$?

    cat "$tmp_out" >> "$RESULT_FILE"

    if [[ $rc -ne 0 ]]; then
        note "FAIL: act exit code $rc for case $name"
        fail=$((fail + 1))
        return
    fi

    # Assert "Job succeeded" appears.
    if ! grep -q "Job succeeded" "$tmp_out"; then
        note "FAIL: 'Job succeeded' not found for case $name"
        fail=$((fail + 1))
        return
    fi

    # The workflow emits "RESULT: labels=<csv>" on its own line.
    # act prefixes lines with `[workflow/job]   | `, so strip that.
    local actual
    actual=$(grep 'RESULT: labels=' "$tmp_out" \
        | sed -E 's/.*RESULT: labels=//' \
        | tr -d '\r' \
        | head -n1)

    if [[ $actual != "$expected_labels" ]]; then
        note "FAIL: case $name: expected '$expected_labels' got '$actual'"
        fail=$((fail + 1))
        return
    fi

    note "PASS: case $name -> $actual"
    pass=$((pass + 1))
    rm -f "$tmp_out"
}

# Three cases - one per act run, staying within the 3-run budget.
run_case "docs-only" \
    tests/fixtures/rules-basic.txt \
    tests/fixtures/files-docs-only.txt \
    "documentation"

run_case "mixed-multi-label" \
    tests/fixtures/rules-basic.txt \
    tests/fixtures/files-mixed.txt \
    "api,documentation,tests"

run_case "priority-exclusive" \
    tests/fixtures/rules-priority.txt \
    tests/fixtures/files-priority.txt \
    "frontend,security"

note "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
