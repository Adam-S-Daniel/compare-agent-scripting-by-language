#!/usr/bin/env bats
# Semantic Version Bumper - bats test suite (TDD red/green approach)
# Workflow structure tests run immediately; act-based tests run the full pipeline.
# All act runs share a single setup_file invocation (one act push total).

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml"
SCRIPT_FILE="$SCRIPT_DIR/version-bumper.sh"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"

# ---------------------------------------------------------------------------
# WORKFLOW STRUCTURE TESTS — fast, no Docker required
# ---------------------------------------------------------------------------

@test "version-bumper.sh exists" {
    [ -f "$SCRIPT_FILE" ]
}

@test "version-bumper.sh is executable" {
    [ -x "$SCRIPT_FILE" ]
}

@test "version-bumper.sh has correct shebang" {
    head -1 "$SCRIPT_FILE" | grep -q '#!/usr/bin/env bash'
}

@test "version-bumper.sh passes bash -n syntax check" {
    bash -n "$SCRIPT_FILE"
}

@test "version-bumper.sh passes shellcheck" {
    shellcheck "$SCRIPT_FILE"
}

@test "workflow file exists at expected path" {
    [ -f "$WORKFLOW_FILE" ]
}

@test "workflow has push trigger" {
    grep -q "push:" "$WORKFLOW_FILE"
}

@test "workflow has workflow_dispatch trigger" {
    grep -q "workflow_dispatch:" "$WORKFLOW_FILE"
}

@test "workflow references actions/checkout" {
    grep -q "actions/checkout" "$WORKFLOW_FILE"
}

@test "workflow references version-bumper.sh" {
    grep -q "version-bumper.sh" "$WORKFLOW_FILE"
}

@test "fixture files exist" {
    [ -f "$SCRIPT_DIR/fixtures/patch-commits.txt" ]
    [ -f "$SCRIPT_DIR/fixtures/minor-commits.txt" ]
    [ -f "$SCRIPT_DIR/fixtures/major-commits.txt" ]
    [ -f "$SCRIPT_DIR/fixtures/mixed-commits.txt" ]
}

@test "actionlint passes on workflow file" {
    run actionlint "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# ACT-BASED INTEGRATION TESTS
# setup_file creates a temp git repo, runs act ONCE, saves to act-result.txt.
# Individual @test functions parse the saved output — no repeated act runs.
# ---------------------------------------------------------------------------

setup_file() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    # Export so teardown_file can clean up
    export _BATS_ACT_TMPDIR="$tmpdir"

    # Copy project files (exclude .git so we can re-init cleanly)
    cp -r "$SCRIPT_DIR/." "$tmpdir/"
    rm -rf "$tmpdir/.git"

    # Initialize a real git repo — act requires committed content
    cd "$tmpdir"
    git init -b main
    git config user.email "ci@example.com"
    git config user.name "CI Bot"
    git add -A
    git commit -m "chore: initial project commit for act test"

    # Run act push once; tee to act-result.txt and capture exit code
    local act_output
    act_output=$(act push --rm -C "$tmpdir" 2>&1)
    local act_exit=$?

    {
        echo "======== ACT RUN: semantic-version-bumper ========"
        echo "$act_output"
        echo "======== ACT EXIT CODE: $act_exit ========"
    } > "$ACT_RESULT"

    # Persist exit code for the @test that checks it
    export _BATS_ACT_EXIT="$act_exit"
}

teardown_file() {
    rm -rf "$_BATS_ACT_TMPDIR"
}

@test "act-result.txt artifact exists" {
    [ -f "$ACT_RESULT" ]
}

@test "act exits with code 0" {
    [ "$_BATS_ACT_EXIT" -eq 0 ]
}

@test "act output contains Job succeeded" {
    grep -q "Job succeeded" "$ACT_RESULT"
}

@test "act output shows patch bump NEW_VERSION=1.0.1" {
    grep -q "NEW_VERSION=1.0.1" "$ACT_RESULT"
}

@test "act output shows minor bump NEW_VERSION=1.2.0" {
    grep -q "NEW_VERSION=1.2.0" "$ACT_RESULT"
}

@test "act output shows major bump NEW_VERSION=3.0.0" {
    grep -q "NEW_VERSION=3.0.0" "$ACT_RESULT"
}

@test "act output shows package.json bump NEW_VERSION=1.5.1" {
    grep -q "NEW_VERSION=1.5.1" "$ACT_RESULT"
}

@test "act output shows PASS: patch bump" {
    grep -q "PASS: patch bump" "$ACT_RESULT"
}

@test "act output shows PASS: minor bump" {
    grep -q "PASS: minor bump" "$ACT_RESULT"
}

@test "act output shows PASS: major bump" {
    grep -q "PASS: major bump" "$ACT_RESULT"
}

@test "act output shows PASS: package.json bump" {
    grep -q "PASS: package.json bump" "$ACT_RESULT"
}

@test "act output contains changelog output" {
    grep -q "CHANGELOG" "$ACT_RESULT"
}
