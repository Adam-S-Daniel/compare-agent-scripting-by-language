#!/usr/bin/env bats
# test_secret_rotation.bats
#
# Test harness that validates the secret-rotation-validator through GitHub
# Actions via `act`. Each test sets up a temp git repo, runs act push --rm,
# captures output, and asserts on exact expected values.

PROJ_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
ACT_RESULT="$PROJ_DIR/act-result.txt"

# ── Helpers ───────────────────────────────────────────────────────────────────

# Set up a temporary git repo with project files and run a specific act job.
# The temp repo approach ensures isolation per test.
run_act_job() {
    local job_name="$1"
    local tmpdir
    tmpdir=$(mktemp -d)

    # Copy project files into temp repo
    cp "$PROJ_DIR/secret-rotation-validator.sh" "$tmpdir/"
    cp -r "$PROJ_DIR/fixtures" "$tmpdir/"
    mkdir -p "$tmpdir/.github/workflows"
    cp "$PROJ_DIR/.github/workflows/secret-rotation-validator.yml" "$tmpdir/.github/workflows/"

    # Initialize git repo (act requires one)
    git -C "$tmpdir" init -b main >/dev/null 2>&1
    git -C "$tmpdir" add -A >/dev/null 2>&1
    git -C "$tmpdir" -c user.name="test" -c user.email="test@test.com" commit -m "init" >/dev/null 2>&1

    # Run act for the specified job from within the tmpdir
    local act_output act_exit
    echo "======== ACT RUN: $job_name ========" >> "$ACT_RESULT"

    act_output=$(cd "$tmpdir" && act push --rm \
        -j "$job_name" \
        -W ".github/workflows/secret-rotation-validator.yml" \
        --defaultbranch main \
        --detect-event \
        2>&1) && act_exit=0 || act_exit=$?

    echo "$act_output" >> "$ACT_RESULT"
    echo "======== END: $job_name (exit=$act_exit) ========" >> "$ACT_RESULT"
    echo "" >> "$ACT_RESULT"

    # Clean up
    rm -rf "$tmpdir"

    # Return output and exit code via globals
    ACT_OUTPUT="$act_output"
    ACT_EXIT=$act_exit
}

# ── Setup / Teardown ─────────────────────────────────────────────────────────

setup() {
    # Create the result file on first test only
    if [[ ! -f "$ACT_RESULT" ]]; then
        echo "# Secret Rotation Validator - Act Test Results" > "$ACT_RESULT"
        echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ACT_RESULT"
        echo "" >> "$ACT_RESULT"
    fi
}

# ── Workflow Structure Tests ─────────────────────────────────────────────────

@test "workflow YAML exists at correct path" {
    [ -f "$PROJ_DIR/.github/workflows/secret-rotation-validator.yml" ]
}

@test "workflow has expected triggers (push, pull_request, schedule, workflow_dispatch)" {
    local wf="$PROJ_DIR/.github/workflows/secret-rotation-validator.yml"
    grep -q "push:" "$wf"
    grep -q "pull_request:" "$wf"
    grep -q "schedule:" "$wf"
    grep -q "workflow_dispatch:" "$wf"
}

@test "workflow has all expected jobs" {
    local wf="$PROJ_DIR/.github/workflows/secret-rotation-validator.yml"
    grep -q "validate-script:" "$wf"
    grep -q "test-mixed-status:" "$wf"
    grep -q "test-all-ok:" "$wf"
    grep -q "test-all-expired:" "$wf"
    grep -q "test-warning-status:" "$wf"
    grep -q "test-error-handling:" "$wf"
    grep -q "test-custom-warning-window:" "$wf"
}

@test "workflow references script file that exists" {
    local wf="$PROJ_DIR/.github/workflows/secret-rotation-validator.yml"
    grep -q "secret-rotation-validator.sh" "$wf"
    [ -f "$PROJ_DIR/secret-rotation-validator.sh" ]
}

@test "workflow references fixture files that exist" {
    [ -f "$PROJ_DIR/fixtures/mixed-status.json" ]
    [ -f "$PROJ_DIR/fixtures/all-ok.json" ]
    [ -f "$PROJ_DIR/fixtures/all-expired.json" ]
    [ -f "$PROJ_DIR/fixtures/warning-only.json" ]
    [ -f "$PROJ_DIR/fixtures/empty.json" ]
}

@test "actionlint passes on workflow" {
    run actionlint "$PROJ_DIR/.github/workflows/secret-rotation-validator.yml"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "shellcheck passes on script" {
    run shellcheck "$PROJ_DIR/secret-rotation-validator.sh"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "bash syntax check passes" {
    run bash -n "$PROJ_DIR/secret-rotation-validator.sh"
    echo "$output"
    [ "$status" -eq 0 ]
}

# ── Act Integration Tests ────────────────────────────────────────────────────

@test "act: validate-script job succeeds (shellcheck + syntax)" {
    run_act_job "validate-script"
    echo "$ACT_OUTPUT"
    [ "$ACT_EXIT" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
}

@test "act: test-mixed-status — 4 secrets, 3 expired, 1 ok" {
    run_act_job "test-mixed-status"
    echo "$ACT_OUTPUT"
    [ "$ACT_EXIT" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    # Verify exact assertion values from the workflow step
    [[ "$ACT_OUTPUT" == *"total=4 expired=3 ok=1"* ]]
    [[ "$ACT_OUTPUT" == *"ALL ASSERTIONS PASSED"* ]]
    # Verify markdown report generation
    [[ "$ACT_OUTPUT" == *"Secret Rotation Report"* ]]
    [[ "$ACT_OUTPUT" == *"DB_PASSWORD"* ]]
    [[ "$ACT_OUTPUT" == *"EXPIRED Secrets"* ]]
    [[ "$ACT_OUTPUT" == *"OK Secrets"* ]]
}

@test "act: test-all-ok — 2 secrets, 0 expired, 0 warning, 2 ok" {
    run_act_job "test-all-ok"
    echo "$ACT_OUTPUT"
    [ "$ACT_EXIT" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    [[ "$ACT_OUTPUT" == *"ALL ASSERTIONS PASSED"* ]]
    [[ "$ACT_OUTPUT" == *'"ok": 2'* ]]
    [[ "$ACT_OUTPUT" == *'"expired": 0'* ]]
    [[ "$ACT_OUTPUT" == *'"warning": 0'* ]]
}

@test "act: test-all-expired — 2 secrets, 2 expired, 0 ok" {
    run_act_job "test-all-expired"
    echo "$ACT_OUTPUT"
    [ "$ACT_EXIT" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    [[ "$ACT_OUTPUT" == *"ALL ASSERTIONS PASSED"* ]]
    [[ "$ACT_OUTPUT" == *'"expired": 2'* ]]
    [[ "$ACT_OUTPUT" == *'"ok": 0'* ]]
    # OLD_DB_PASS: 2025-01-01 -> 2026-04-09 = 463 days since rotation
    [[ "$ACT_OUTPUT" == *'"days_since": 463'* ]]
}

@test "act: test-warning-status — 1 secret expiring in 5 days" {
    run_act_job "test-warning-status"
    echo "$ACT_OUTPUT"
    [ "$ACT_EXIT" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    [[ "$ACT_OUTPUT" == *"ALL ASSERTIONS PASSED"* ]]
    [[ "$ACT_OUTPUT" == *'"warning": 1'* ]]
    [[ "$ACT_OUTPUT" == *"EXPIRING_SOON"* ]]
    [[ "$ACT_OUTPUT" == *'"days_until": 5'* ]]
}

@test "act: test-error-handling — all 4 error cases caught" {
    run_act_job "test-error-handling"
    echo "$ACT_OUTPUT"
    [ "$ACT_EXIT" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    [[ "$ACT_OUTPUT" == *"correctly failed with missing config"* ]]
    [[ "$ACT_OUTPUT" == *"correctly failed with nonexistent file"* ]]
    [[ "$ACT_OUTPUT" == *"correctly failed with invalid format"* ]]
    [[ "$ACT_OUTPUT" == *"correctly failed with empty secrets"* ]]
    [[ "$ACT_OUTPUT" == *"ALL ERROR HANDLING TESTS PASSED"* ]]
}

@test "act: test-custom-warning-window — 30-day window changes classification" {
    run_act_job "test-custom-warning-window"
    echo "$ACT_OUTPUT"
    [ "$ACT_EXIT" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    [[ "$ACT_OUTPUT" == *"ALL ASSERTIONS PASSED"* ]]
    # With 30-day window, API_KEY (26 days until expiry) becomes warning instead of ok
    [[ "$ACT_OUTPUT" == *'"warning": 1'* ]]
    [[ "$ACT_OUTPUT" == *'"warning_window_days": 30'* ]]
}

@test "act-result.txt exists and contains all test run sections" {
    [ -f "$ACT_RESULT" ]
    grep -q "ACT RUN: validate-script" "$ACT_RESULT"
    grep -q "ACT RUN: test-mixed-status" "$ACT_RESULT"
    grep -q "ACT RUN: test-all-ok" "$ACT_RESULT"
    grep -q "ACT RUN: test-all-expired" "$ACT_RESULT"
    grep -q "ACT RUN: test-warning-status" "$ACT_RESULT"
    grep -q "ACT RUN: test-error-handling" "$ACT_RESULT"
    grep -q "ACT RUN: test-custom-warning-window" "$ACT_RESULT"
}
