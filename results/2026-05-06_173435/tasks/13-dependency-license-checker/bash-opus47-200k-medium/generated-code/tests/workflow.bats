#!/usr/bin/env bats

# Workflow-level tests. These never invoke check-licenses.sh directly;
# every assertion is made against output captured from `act push --rm`.
#
# We run act ONCE for the whole suite (it's slow), then re-use its captured
# stdout for every assertion. Per-test-case fixture variants are created in a
# scratch repo and we record a section in act-result.txt per case.

REPO_ROOT="$BATS_TEST_DIRNAME/.."
ACT_RESULT="$REPO_ROOT/act-result.txt"

# State shared across tests (computed once in the first test that needs it).
SHARED_STATE="${BATS_FILE_TMPDIR:-/tmp}/wf_state"

setup_file() {
    : > "$ACT_RESULT"
}

# ---- helpers ---------------------------------------------------------------

# Build a temporary git repo containing the project plus a swapped-in
# manifest, then run `act push --rm` against it. Output is captured to
# $ACT_RESULT and to stdout so individual tests can grep.
run_act_case() {
    local label=$1 manifest_src=$2

    local work
    work=$(mktemp -d)

    # Copy script + workflow + tests + fixtures into the scratch repo.
    cp -r "$REPO_ROOT/check-licenses.sh" "$work/"
    cp -r "$REPO_ROOT/.github" "$work/"
    cp -r "$REPO_ROOT/tests" "$work/"

    # Swap in the case-specific manifest as the workflow's default target.
    cp "$manifest_src" "$work/tests/fixtures/_manifest.json"

    # Patch the workflow so MANIFEST points at the scratch manifest.
    sed -i "s|tests/fixtures/package.json|tests/fixtures/_manifest.json|g" \
        "$work/.github/workflows/dependency-license-checker.yml"

    (
        cd "$work"
        git init -q
        git config user.email ci@example.com
        git config user.name ci
        git add .
        git commit -q -m "case: $label"
        # --rm cleans up containers; -W targets only our workflow.
        act push --rm -W .github/workflows/dependency-license-checker.yml \
            >"$work/out.txt" 2>&1
        echo $? > "$work/exit"
    )

    {
        echo "=================================================="
        echo "CASE: $label"
        echo "=================================================="
        cat "$work/out.txt"
        echo
        echo "[exit: $(cat "$work/exit")]"
        echo
    } >> "$ACT_RESULT"

    cp "$work/out.txt"  "$SHARED_STATE.${label}.out"
    cp "$work/exit"     "$SHARED_STATE.${label}.exit"
}

# Lazily run one act case so tests can share results without re-running act.
ensure_case() {
    local label=$1 manifest=$2
    [ -f "$SHARED_STATE.${label}.exit" ] && return 0
    run_act_case "$label" "$manifest"
}

# ---- workflow structure (no act required) ---------------------------------

@test "workflow file exists" {
    [ -f "$REPO_ROOT/.github/workflows/dependency-license-checker.yml" ]
}

@test "actionlint passes on workflow" {
    run actionlint "$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

@test "workflow declares expected triggers" {
    run grep -E '^(on:|  push:|  pull_request:|  schedule:|  workflow_dispatch:)' \
        "$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"push"* ]]
    [[ "$output" == *"pull_request"* ]]
    [[ "$output" == *"schedule"* ]]
    [[ "$output" == *"workflow_dispatch"* ]]
}

@test "workflow references the script that exists" {
    run grep -F 'check-licenses.sh' \
        "$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
    [ -x "$REPO_ROOT/check-licenses.sh" ]
}

@test "workflow uses checkout@v4" {
    run grep -F 'actions/checkout@v4' \
        "$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

@test "workflow declares contents:read permission" {
    run grep -E 'contents:[[:space:]]+read' \
        "$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

# ---- act execution: case "violations" (default fixtures) -------------------

@test "act case [violations]: succeeds and emits report with all 4 deps" {
    ensure_case "violations" "$REPO_ROOT/tests/fixtures/package.json"

    [ "$(cat "$SHARED_STATE.violations.exit")" = "0" ]
    out=$(cat "$SHARED_STATE.violations.out")
    [[ "$out" == *"left-pad@1.3.0"* ]]
    [[ "$out" == *"lodash@4.17.21"* ]]
    [[ "$out" == *"evil-pkg@0.0.1"* ]]
    [[ "$out" == *"mystery-pkg@9.9.9"* ]]
}

@test "act case [violations]: classifies APPROVED / DENIED / UNKNOWN exactly" {
    ensure_case "violations" "$REPO_ROOT/tests/fixtures/package.json"
    out=$(cat "$SHARED_STATE.violations.out")
    [[ "$out" == *"MIT"*"[APPROVED]"* ]]
    [[ "$out" == *"GPL-3.0"*"[DENIED]"* ]]
    [[ "$out" == *"[UNKNOWN]"* ]]
}

@test "act case [violations]: summary shows approved=2 denied=1 unknown=1" {
    ensure_case "violations" "$REPO_ROOT/tests/fixtures/package.json"
    out=$(cat "$SHARED_STATE.violations.out")
    [[ "$out" == *"approved=2 denied=1 unknown=1"* ]]
}

@test "act case [violations]: every job reports Job succeeded" {
    ensure_case "violations" "$REPO_ROOT/tests/fixtures/package.json"
    out=$(cat "$SHARED_STATE.violations.out")
    [[ "$out" == *"Job succeeded"* ]]
    # Both jobs (license-check + workflow-tests) should each succeed.
    succ=$(grep -c "Job succeeded" "$SHARED_STATE.violations.out")
    [ "$succ" -ge 2 ]
}

# ---- act execution: case "clean" (only-approved fixtures) ------------------

@test "act case [clean]: succeeds and reports approved=2 denied=0 unknown=0" {
    ensure_case "clean" "$REPO_ROOT/tests/fixtures/clean.json"
    [ "$(cat "$SHARED_STATE.clean.exit")" = "0" ]
    out=$(cat "$SHARED_STATE.clean.out")
    [[ "$out" == *"left-pad@1.3.0"*"MIT"*"[APPROVED]"* ]]
    [[ "$out" == *"lodash@4.17.21"*"Apache-2.0"*"[APPROVED]"* ]]
    [[ "$out" == *"approved=2 denied=0 unknown=0"* ]]
}

@test "act case [clean]: every job reports Job succeeded" {
    ensure_case "clean" "$REPO_ROOT/tests/fixtures/clean.json"
    out=$(cat "$SHARED_STATE.clean.out")
    succ=$(grep -c "Job succeeded" "$SHARED_STATE.clean.out")
    [ "$succ" -ge 2 ]
}

# ---- final required artifact check ----------------------------------------

@test "act-result.txt exists and contains both case sections" {
    [ -f "$ACT_RESULT" ]
    grep -q "CASE: violations" "$ACT_RESULT"
    grep -q "CASE: clean" "$ACT_RESULT"
}
