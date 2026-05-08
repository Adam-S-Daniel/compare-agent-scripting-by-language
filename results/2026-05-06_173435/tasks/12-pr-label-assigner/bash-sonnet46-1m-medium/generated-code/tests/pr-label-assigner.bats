#!/usr/bin/env bats
# Tests for the PR Label Assigner script.
# Structure: unit tests for the script, workflow structure/actionlint tests,
# and one act integration test that runs the workflow and verifies all outputs.

SCRIPT="$BATS_TEST_DIRNAME/../pr-label-assigner.sh"
WORKFLOW="$BATS_TEST_DIRNAME/../.github/workflows/pr-label-assigner.yml"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"
PROJECT_ROOT="$BATS_TEST_DIRNAME/.."

# ──────────────────────────────────────────────────────────────────────────────
# RED: first failing test (script doesn't exist yet)
# ──────────────────────────────────────────────────────────────────────────────
@test "script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Script syntax and static analysis
# ──────────────────────────────────────────────────────────────────────────────
@test "script passes bash -n syntax check" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "script passes shellcheck" {
    run shellcheck "$SCRIPT"
    [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Error handling
# ──────────────────────────────────────────────────────────────────────────────
@test "missing config file prints error and exits 1" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error" ]]
}

@test "nonexistent config file prints error and exits 1" {
    run "$SCRIPT" /nonexistent/rules.conf /dev/null
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error" ]]
}

@test "nonexistent files input prints error and exits 1" {
    run "$SCRIPT" "$FIXTURES/basic-rules.conf" /nonexistent/files.txt
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error" ]]
}

# ──────────────────────────────────────────────────────────────────────────────
# Basic label matching (GREEN phase after implementing the script)
# ──────────────────────────────────────────────────────────────────────────────
@test "docs file gets documentation label" {
    run "$SCRIPT" "$FIXTURES/basic-rules.conf" "$FIXTURES/files-docs.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

@test "api file gets api label" {
    run "$SCRIPT" "$FIXTURES/basic-rules.conf" "$FIXTURES/files-api.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "api" ]
}

@test "test file gets tests label" {
    tmpfile=$(mktemp)
    echo "app.test.js" > "$tmpfile"
    run "$SCRIPT" "$FIXTURES/basic-rules.conf" "$tmpfile"
    rm -f "$tmpfile"
    [ "$status" -eq 0 ]
    [ "$output" = "tests" ]
}

@test "spec file gets tests label" {
    tmpfile=$(mktemp)
    echo "utils.spec.ts" > "$tmpfile"
    run "$SCRIPT" "$FIXTURES/basic-rules.conf" "$tmpfile"
    rm -f "$tmpfile"
    [ "$status" -eq 0 ]
    [ "$output" = "tests" ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Multiple labels per file
# ──────────────────────────────────────────────────────────────────────────────
@test "file matching multiple rules gets multiple labels" {
    run "$SCRIPT" "$FIXTURES/basic-rules.conf" "$FIXTURES/files-multi-label.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"api"* ]]
    [[ "$output" == *"tests"* ]]
}

@test "multiple files produce union of labels" {
    run "$SCRIPT" "$FIXTURES/basic-rules.conf" "$FIXTURES/files-multi.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"api"* ]]
    [[ "$output" == *"documentation"* ]]
}

# ──────────────────────────────────────────────────────────────────────────────
# No match
# ──────────────────────────────────────────────────────────────────────────────
@test "file with no matching rule outputs no-labels message" {
    run "$SCRIPT" "$FIXTURES/basic-rules.conf" "$FIXTURES/files-no-match.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "No labels matched" ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Deduplication
# ──────────────────────────────────────────────────────────────────────────────
@test "duplicate labels from multiple rules are deduplicated" {
    run "$SCRIPT" "$FIXTURES/basic-rules.conf" "$FIXTURES/files-dedup.txt"
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | grep -c "^tests$")
    [ "$count" -eq 1 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Priority ordering (higher-priority = earlier line in config)
# ──────────────────────────────────────────────────────────────────────────────
@test "priority config: specific rule and broad rule both apply" {
    run "$SCRIPT" "$FIXTURES/priority-rules.conf" "$FIXTURES/files-priority.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"api"* ]]
    [[ "$output" == *"source"* ]]
}

@test "output labels are sorted alphabetically" {
    run "$SCRIPT" "$FIXTURES/priority-rules.conf" "$FIXTURES/files-priority.txt"
    [ "$status" -eq 0 ]
    local first second
    first=$(echo "$output" | head -1)
    second=$(echo "$output" | tail -1)
    [[ "$first" < "$second" || "$first" == "$second" ]]
}

# ──────────────────────────────────────────────────────────────────────────────
# Comments in config
# ──────────────────────────────────────────────────────────────────────────────
@test "comment lines in config are ignored" {
    tmpconf=$(mktemp)
    tmpfiles=$(mktemp)
    cat > "$tmpconf" << 'EOF'
# This is a comment
docs/**:documentation
# Another comment
EOF
    echo "docs/guide.md" > "$tmpfiles"
    run "$SCRIPT" "$tmpconf" "$tmpfiles"
    rm -f "$tmpconf" "$tmpfiles"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Nested paths with ** glob
# ──────────────────────────────────────────────────────────────────────────────
@test "deeply nested path matches docs/** pattern" {
    tmpconf=$(mktemp)
    tmpfiles=$(mktemp)
    echo "docs/**:documentation" > "$tmpconf"
    echo "docs/en/getting-started/intro.md" > "$tmpfiles"
    run "$SCRIPT" "$tmpconf" "$tmpfiles"
    rm -f "$tmpconf" "$tmpfiles"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Stdin input (files-input = "-")
# ──────────────────────────────────────────────────────────────────────────────
@test "reads changed files from stdin when argument is dash" {
    run bash -c "echo 'docs/README.md' | \"$SCRIPT\" \"$FIXTURES/basic-rules.conf\" -"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Workflow structure tests (no act needed — fast)
# ──────────────────────────────────────────────────────────────────────────────
@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "workflow has push trigger" {
    run grep -q "push:" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow has pull_request trigger" {
    run grep -q "pull_request:" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow has workflow_dispatch trigger" {
    run grep -q "workflow_dispatch:" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow has at least one job" {
    run grep -q "^jobs:" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow references pr-label-assigner.sh and file exists" {
    run grep -q "pr-label-assigner.sh" "$WORKFLOW"
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/pr-label-assigner.sh" ]
}

@test "workflow uses actions/checkout" {
    run grep -q "actions/checkout" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "actionlint passes on workflow file" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Act integration test — ONE act run covering ALL functional test cases
# ──────────────────────────────────────────────────────────────────────────────
@test "act integration: workflow runs successfully and all test cases pass" {
    local tmpdir act_exit
    tmpdir=$(mktemp -d)

    # Copy the entire project into the temp dir
    cp -r "$PROJECT_ROOT/." "$tmpdir/"

    # Initialise a git repo so act can detect push event
    (
        cd "$tmpdir"
        git init -q
        git config user.email "ci@test.local"
        git config user.name "CI Test"
        git add -A
        git commit -q -m "ci: test run"
    )

    # Run act; --pull=false avoids attempting to re-pull the local image
    local act_out="$tmpdir/act-output.txt"
    (cd "$tmpdir" && act push --rm --pull=false 2>&1) | tee "$act_out" >> "$PROJECT_ROOT/act-result.txt"
    act_exit=${PIPESTATUS[0]}

    # Delimiter in act-result.txt for readability
    echo "=== END ACT RUN ===" >> "$PROJECT_ROOT/act-result.txt"

    # Assert act succeeded
    [ "$act_exit" -eq 0 ]

    # Assert every job shows success
    grep -q "Job succeeded" "$act_out"

    # Assert individual integration test cases passed
    grep -q "INTEGRATION_TEST: basic-docs | STATUS: PASS" "$act_out"
    grep -q "INTEGRATION_TEST: basic-api | STATUS: PASS" "$act_out"
    grep -q "INTEGRATION_TEST: test-label | STATUS: PASS" "$act_out"
    grep -q "INTEGRATION_TEST: spec-label | STATUS: PASS" "$act_out"
    grep -q "INTEGRATION_TEST: no-match | STATUS: PASS" "$act_out"
    grep -q "INTEGRATION_TEST: multi-file | STATUS: PASS" "$act_out"
    grep -q "INTEGRATION_TEST: multi-label-file | STATUS: PASS" "$act_out"
    grep -q "INTEGRATION_TEST: priority-overlap | STATUS: PASS" "$act_out"
    grep -q "INTEGRATION_TEST: dedup-labels | STATUS: PASS" "$act_out"
    grep -q "INTEGRATION_TEST: nested-path | STATUS: PASS" "$act_out"

    rm -rf "$tmpdir"
}
