#!/usr/bin/env bats
# Secret Rotation Validator - Test Harness
#
# Tests are organized in two groups:
#   1. Structural tests  - validate YAML, actionlint, file references (no act)
#   2. Functional tests   - run the workflow through act and verify exact output
#
# All functional tests execute via the GitHub Actions workflow through act.

# Project root (one level up from test/)
PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
WORKFLOW_FILE="$PROJECT_DIR/.github/workflows/secret-rotation-validator.yml"
ACT_RESULT_FILE="$PROJECT_DIR/act-result.txt"
# Shared file for act output across tests (persists for the file's lifetime)
ACT_OUTPUT_FILE="$PROJECT_DIR/.act-output-cache"
ACT_EXIT_FILE="$PROJECT_DIR/.act-exit-cache"

# ============================================================
# Helper: read cached act output (populated by setup_file)
# ============================================================
get_act_output() {
    cat "$ACT_OUTPUT_FILE"
}

get_act_exit() {
    cat "$ACT_EXIT_FILE"
}

# ============================================================
# setup_file: run act once, cache results for all tests
# ============================================================
setup_file() {
    # Clear previous results
    > "$ACT_RESULT_FILE"

    local tmpdir
    tmpdir=$(mktemp -d)

    # Copy project files into the temp repo
    cp "$PROJECT_DIR/secret-rotation-validator.sh" "$tmpdir/"
    cp -r "$PROJECT_DIR/test" "$tmpdir/"
    mkdir -p "$tmpdir/.github/workflows"
    cp "$WORKFLOW_FILE" "$tmpdir/.github/workflows/"
    if [[ -f "$PROJECT_DIR/.actrc" ]]; then
        cp "$PROJECT_DIR/.actrc" "$tmpdir/"
    fi

    # Initialize a git repo (act requires it for push events)
    cd "$tmpdir"
    git init -b main
    git add -A
    git -c user.email="test@test.com" -c user.name="Test" commit -m "init"

    # Run act and capture output
    local act_exit=0
    act push --rm --pull=false > "$ACT_OUTPUT_FILE" 2>&1 || act_exit=$?
    echo "$act_exit" > "$ACT_EXIT_FILE"

    # Write to act-result.txt (required artifact)
    {
        echo "========================================"
        echo "ACT RUN $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "========================================"
        cat "$ACT_OUTPUT_FILE"
        echo ""
    } >> "$ACT_RESULT_FILE"

    # Clean up temp dir
    rm -rf "$tmpdir"
    cd "$PROJECT_DIR"
}

teardown_file() {
    rm -f "$ACT_OUTPUT_FILE" "$ACT_EXIT_FILE"
}

# ============================================================
# STRUCTURAL TESTS (no act needed)
# ============================================================

@test "workflow YAML file exists" {
    [[ -f "$WORKFLOW_FILE" ]]
}

@test "actionlint passes on workflow" {
    run actionlint "$WORKFLOW_FILE"
    echo "$output"
    [[ "$status" -eq 0 ]]
}

@test "script file exists and is executable" {
    [[ -f "$PROJECT_DIR/secret-rotation-validator.sh" ]]
    [[ -x "$PROJECT_DIR/secret-rotation-validator.sh" ]]
}

@test "script passes shellcheck" {
    run shellcheck "$PROJECT_DIR/secret-rotation-validator.sh"
    echo "$output"
    [[ "$status" -eq 0 ]]
}

@test "script passes bash -n syntax check" {
    run bash -n "$PROJECT_DIR/secret-rotation-validator.sh"
    echo "$output"
    [[ "$status" -eq 0 ]]
}

@test "workflow has push trigger" {
    grep -q 'push:' "$WORKFLOW_FILE"
}

@test "workflow has pull_request trigger" {
    grep -q 'pull_request:' "$WORKFLOW_FILE"
}

@test "workflow has schedule trigger" {
    grep -q 'schedule:' "$WORKFLOW_FILE"
}

@test "workflow has workflow_dispatch trigger" {
    grep -q 'workflow_dispatch:' "$WORKFLOW_FILE"
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'actions/checkout@v4' "$WORKFLOW_FILE"
}

@test "workflow references secret-rotation-validator.sh" {
    grep -q 'secret-rotation-validator.sh' "$WORKFLOW_FILE"
}

@test "workflow references test fixture files that exist" {
    # Extract fixture paths referenced in the workflow
    local fixtures
    fixtures=$(grep -oP 'test/fixtures/[a-z-]+\.json' "$WORKFLOW_FILE" | sort -u)
    for fixture in $fixtures; do
        echo "Checking: $fixture"
        [[ -f "$PROJECT_DIR/$fixture" ]]
    done
}

@test "workflow has permissions set" {
    grep -q 'permissions:' "$WORKFLOW_FILE"
}

@test "all test fixture files are valid JSON" {
    for f in "$PROJECT_DIR"/test/fixtures/*.json; do
        echo "Checking: $f"
        jq empty "$f"
    done
}

# ============================================================
# FUNCTIONAL TESTS (via act)
# ============================================================

@test "act run exits successfully" {
    local exit_code
    exit_code=$(get_act_exit)
    echo "ACT_EXIT=$exit_code"
    [[ "$exit_code" -eq 0 ]]
}

@test "act: validate-secrets job succeeded" {
    get_act_output | grep -q "Job succeeded"
}

# --- Mixed secrets markdown (Test 1) ---
@test "act: mixed-secrets-markdown - exit code 1 for expired secrets" {
    get_act_output | grep -q "PASS: Exit code is 1 as expected"
}

@test "act: mixed-secrets-markdown - shows EXPIRED section" {
    get_act_output | grep -q "## EXPIRED Secrets"
}

@test "act: mixed-secrets-markdown - shows DB_PASSWORD expired 9 days ago" {
    get_act_output | grep -q "DB_PASSWORD"
    get_act_output | grep -q "expired 9 days ago"
}

@test "act: mixed-secrets-markdown - shows WARNING section" {
    get_act_output | grep -q "## WARNING Secrets"
}

@test "act: mixed-secrets-markdown - shows TLS_CERT expires in 5 days" {
    get_act_output | grep -q "TLS_CERT"
    get_act_output | grep -q "expires in 5 days"
}

@test "act: mixed-secrets-markdown - shows OK section" {
    get_act_output | grep -q "## OK Secrets"
}

@test "act: mixed-secrets-markdown - shows API_KEY expires in 85 days" {
    get_act_output | grep -q "API_KEY"
    get_act_output | grep -q "expires in 85 days"
}

@test "act: mixed-secrets-markdown - summary counts EXPIRED=1 WARNING=1 OK=1" {
    get_act_output | grep -q "| EXPIRED | 1 |"
    get_act_output | grep -q "| WARNING | 1 |"
    get_act_output | grep -q "| OK | 1 |"
}

# --- Mixed secrets JSON (Test 2) ---
@test "act: mixed-secrets-json - total=3 expired=1 warning=1 ok=1" {
    get_act_output | grep -q "PASS: total=3"
    get_act_output | grep -q "PASS: expired=1"
    get_act_output | grep -q "PASS: warning=1"
    get_act_output | grep -q "PASS: ok=1"
}

@test "act: mixed-secrets-json - DB_PASSWORD classified as expired" {
    get_act_output | grep -q "PASS: DB_PASSWORD is expired"
}

@test "act: mixed-secrets-json - TLS_CERT classified as warning" {
    get_act_output | grep -q "PASS: TLS_CERT is warning"
}

@test "act: mixed-secrets-json - API_KEY classified as ok" {
    get_act_output | grep -q "PASS: API_KEY is ok"
}

# --- All OK (Test 3) ---
@test "act: all-ok - exit code 0 (all secrets within policy)" {
    get_act_output | grep -q "PASS: Exit code is 0 as expected (all secrets OK)"
}

# --- All expired (Test 4) ---
@test "act: all-expired - expired=2 warning=0 ok=0" {
    get_act_output | grep -q "PASS: expired=2"
    get_act_output | grep -q "PASS: warning=0"
    get_act_output | grep -q "PASS: ok=0"
}

@test "act: all-expired - exit code 1" {
    # The workflow step verifies the exit code; we check its PASS assertion
    get_act_output | grep -q "PASS: Exit code is 1 as expected"
}

# --- Custom warning window (Test 5) ---
@test "act: custom-warning-window - SESSION_KEY becomes warning at 90-day window" {
    get_act_output | grep -q "PASS: warning=1 (SESSION_KEY within 90-day window)"
}

@test "act: custom-warning-window - SMTP_PASSWORD still ok at 90-day window" {
    get_act_output | grep -q "PASS: ok=1 (SMTP_PASSWORD still OK at 154 days)"
}

# --- Error: missing file (Test 6) ---
@test "act: error-missing-file - exit code 2" {
    get_act_output | grep -q "PASS: Exit code is 2 for missing file"
}

@test "act: error-missing-file - correct error message" {
    get_act_output | grep -q "PASS: Error message mentions missing config file"
}

# --- Error: invalid JSON (Test 7) ---
@test "act: error-invalid-json - exit code 2" {
    get_act_output | grep -q "PASS: Exit code is 2 for invalid JSON"
}

# --- Final check ---
@test "act: all workflow steps completed" {
    get_act_output | grep -q "All secret rotation validator tests passed successfully"
}

@test "act-result.txt exists and is non-empty" {
    [[ -s "$ACT_RESULT_FILE" ]]
}
