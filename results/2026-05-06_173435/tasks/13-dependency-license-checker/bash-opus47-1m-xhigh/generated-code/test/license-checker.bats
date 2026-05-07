#!/usr/bin/env bats
# Test suite for the dependency license checker.
#
# All test cases that exercise the license-checking behaviour run through the
# GitHub Actions workflow via `act`, satisfying the "all testing goes through
# the pipeline" requirement. Static checks (shellcheck, actionlint, YAML
# structure, file existence) run locally because they are cheap and do not
# exercise the script logic.

setup_file() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export REPO_ROOT
    ACT_RESULT_FILE="$REPO_ROOT/act-result.txt"
    export ACT_RESULT_FILE
    : > "$ACT_RESULT_FILE"  # truncate the act-result.txt artifact at start
}

# ---- Static / structural tests --------------------------------------------

@test "license-checker.sh exists and is executable" {
    [ -x "$REPO_ROOT/license-checker.sh" ]
}

@test "license-checker.sh starts with the required shebang" {
    run head -n 1 "$REPO_ROOT/license-checker.sh"
    [ "$status" -eq 0 ]
    [ "$output" = "#!/usr/bin/env bash" ]
}

@test "license-checker.sh passes bash -n syntax validation" {
    run bash -n "$REPO_ROOT/license-checker.sh"
    [ "$status" -eq 0 ]
}

@test "license-checker.sh passes shellcheck" {
    run shellcheck "$REPO_ROOT/license-checker.sh"
    [ "$status" -eq 0 ]
}

@test "workflow file exists" {
    [ -f "$REPO_ROOT/.github/workflows/dependency-license-checker.yml" ]
}

@test "workflow passes actionlint" {
    run actionlint "$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

@test "workflow declares a push trigger" {
    run grep -E "^[[:space:]]*push:" "$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

@test "workflow references the script" {
    run grep -F "license-checker.sh" "$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

@test "workflow uses actions/checkout@v4" {
    run grep -F "actions/checkout@v4" "$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

@test "workflow declares contents:read permission" {
    run grep -E "contents:[[:space:]]*read" "$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

# ---- act-based integration tests ------------------------------------------
#
# Each case sets up a temp git repo containing the project + the case's
# fixture data, runs `act push --rm`, captures all output to act-result.txt,
# and asserts on exact expected values from the workflow output.

# Run the workflow against a given fixture case directory.
# Globals set on success:
#   ACT_OUTPUT  - full stdout/stderr from act
#   ACT_STATUS  - exit code from act
run_workflow_for_case() {
    local case_dir="$1"
    local case_name="$2"

    local tmp
    tmp="$(mktemp -d)"
    # Copy project files (script + workflow) into the temp repo.
    cp -r "$REPO_ROOT/license-checker.sh" "$tmp/"
    cp -r "$REPO_ROOT/.github" "$tmp/"
    cp -r "$REPO_ROOT/.actrc" "$tmp/" 2>/dev/null || true
    # Copy fixture files: manifest, config, mock at known paths the workflow expects.
    mkdir -p "$tmp/fixtures"
    cp "$case_dir"/manifest.* "$tmp/fixtures/" 2>/dev/null || true
    cp "$case_dir"/config.txt "$tmp/fixtures/"
    cp "$case_dir"/mock-licenses.txt "$tmp/fixtures/"

    (
        cd "$tmp"
        git init -q
        git config user.email "t@t.t"
        git config user.name "t"
        git add -A
        git commit -q -m "test"
    )

    {
        echo ""
        echo "############################################################"
        echo "## CASE: $case_name"
        echo "############################################################"
    } >> "$ACT_RESULT_FILE"

    # Use bats's `run` builtin so a non-zero act exit code does not abort
    # the test before we can record output and assert on it.
    run bash -c "cd '$tmp' && act push --rm 2>&1"
    ACT_OUTPUT="$output"
    ACT_STATUS="$status"
    echo "$ACT_OUTPUT" >> "$ACT_RESULT_FILE"
    {
        echo "## ACT EXIT: $ACT_STATUS"
        echo "############################################################"
    } >> "$ACT_RESULT_FILE"

    rm -rf "$tmp"
    export ACT_OUTPUT ACT_STATUS
}

@test "act case1: all dependencies are approved -> PASS" {
    run_workflow_for_case "$REPO_ROOT/test/fixtures/case1" "case1-all-approved"
    [ "$ACT_STATUS" -eq 0 ]
    # The workflow always succeeds; the script's exit code is captured separately.
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    [[ "$ACT_OUTPUT" == *"checker_exit=0"* ]]
    [[ "$ACT_OUTPUT" == *"foo@1.0.0 | MIT | APPROVED"* ]]
    [[ "$ACT_OUTPUT" == *"bar@2.5.0 | Apache-2.0 | APPROVED"* ]]
    [[ "$ACT_OUTPUT" == *"SUMMARY: total=2 approved=2 denied=0 unknown=0"* ]]
    [[ "$ACT_OUTPUT" == *"STATUS: PASS"* ]]
}

@test "act case2: a denied license is present -> FAIL" {
    run_workflow_for_case "$REPO_ROOT/test/fixtures/case2" "case2-denied"
    [ "$ACT_STATUS" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    [[ "$ACT_OUTPUT" == *"checker_exit=1"* ]]
    [[ "$ACT_OUTPUT" == *"foo@1.0.0 | MIT | APPROVED"* ]]
    [[ "$ACT_OUTPUT" == *"baz@3.1.4 | GPL-3.0 | DENIED"* ]]
    [[ "$ACT_OUTPUT" == *"SUMMARY: total=2 approved=1 denied=1 unknown=0"* ]]
    [[ "$ACT_OUTPUT" == *"STATUS: FAIL"* ]]
}

@test "act case3: package.json with an unknown license -> UNKNOWN" {
    run_workflow_for_case "$REPO_ROOT/test/fixtures/case3" "case3-unknown-pkgjson"
    [ "$ACT_STATUS" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    [[ "$ACT_OUTPUT" == *"checker_exit=2"* ]]
    [[ "$ACT_OUTPUT" == *"left-pad@1.3.0 | MIT | APPROVED"* ]]
    [[ "$ACT_OUTPUT" == *"obscure-lib@0.0.1 | UNKNOWN | UNKNOWN"* ]]
    [[ "$ACT_OUTPUT" == *"SUMMARY: total=2 approved=1 denied=0 unknown=1"* ]]
    [[ "$ACT_OUTPUT" == *"STATUS: WARN"* ]]
}
