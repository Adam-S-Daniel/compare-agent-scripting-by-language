#!/usr/bin/env bats

# Tests for the PR label assigner script.
# Runs the script against fixture rule files and mocked file lists,
# asserting on the labels printed to stdout.

setup() {
    # Resolve the repo root from the test file location so tests
    # work whether bats is run from the repo root or elsewhere.
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    SCRIPT="$REPO_ROOT/label-assigner.sh"
    FIXTURES="$REPO_ROOT/tests/fixtures"
}

@test "single rule: docs path matches documentation label" {
    run "$SCRIPT" --rules "$FIXTURES/rules-basic.txt" --files "$FIXTURES/files-docs-only.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

@test "multiple labels: file matches more than one rule" {
    run "$SCRIPT" --rules "$FIXTURES/rules-multi.txt" --files "$FIXTURES/files-api-test.txt"
    [ "$status" -eq 0 ]
    # Output is sorted lines of unique labels.
    expected=$'api\ntests'
    [ "$output" = "$expected" ]
}

@test "many files produce union of labels (deduped, sorted)" {
    run "$SCRIPT" --rules "$FIXTURES/rules-basic.txt" --files "$FIXTURES/files-mixed.txt"
    [ "$status" -eq 0 ]
    expected=$'api\ndocumentation\ntests'
    [ "$output" = "$expected" ]
}

@test "priority: when two rules match the same file, higher priority wins exclusively" {
    # Rules file marks security as exclusive priority over api for src/api/auth.go.
    run "$SCRIPT" --rules "$FIXTURES/rules-priority.txt" --files "$FIXTURES/files-priority.txt"
    [ "$status" -eq 0 ]
    # security is exclusive: it suppresses other matches for the same file.
    # frontend label still appears for the unrelated web/index.html file.
    expected=$'frontend\nsecurity'
    [ "$output" = "$expected" ]
}

@test "double-star glob matches nested paths" {
    run "$SCRIPT" --rules "$FIXTURES/rules-basic.txt" --files "$FIXTURES/files-deep.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

@test "extension glob *.test.* matches anywhere" {
    run "$SCRIPT" --rules "$FIXTURES/rules-basic.txt" --files "$FIXTURES/files-tests.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "tests" ]
}

@test "no rule matches: produces no output and exits 0" {
    run "$SCRIPT" --rules "$FIXTURES/rules-basic.txt" --files "$FIXTURES/files-no-match.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "missing --rules flag: error and non-zero exit" {
    run "$SCRIPT" --files "$FIXTURES/files-docs-only.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--rules"* ]]
}

@test "missing --files flag: error and non-zero exit" {
    run "$SCRIPT" --rules "$FIXTURES/rules-basic.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--files"* ]]
}

@test "rules file does not exist: error" {
    run "$SCRIPT" --rules "/nonexistent/rules.txt" --files "$FIXTURES/files-docs-only.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"rules"* ]] || [[ "$output" == *"not found"* ]]
}

@test "files file does not exist: error" {
    run "$SCRIPT" --rules "$FIXTURES/rules-basic.txt" --files "/nonexistent/files.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"files"* ]]
}

@test "comments and blank lines in rules are ignored" {
    run "$SCRIPT" --rules "$FIXTURES/rules-with-comments.txt" --files "$FIXTURES/files-docs-only.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

@test "--help prints usage and exits 0" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "malformed rule line missing arrow: error" {
    run "$SCRIPT" --rules "$FIXTURES/rules-malformed.txt" --files "$FIXTURES/files-docs-only.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"malformed"* ]] || [[ "$output" == *"invalid"* ]]
}
