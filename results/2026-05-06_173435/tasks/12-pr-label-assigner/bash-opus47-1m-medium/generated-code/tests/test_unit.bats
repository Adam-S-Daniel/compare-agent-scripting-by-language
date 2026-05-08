#!/usr/bin/env bats
# Unit-level tests for the label assigner script logic.
# These tests run the script directly against fixture inputs.
# (The full pipeline tests via `act` live in test_act.bats.)

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../pr-label-assigner.sh"
    FIXTURES="$BATS_TEST_DIRNAME/fixtures"
}

@test "script file exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "passes shellcheck" {
    run shellcheck "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "passes bash -n syntax check" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "errors when config file missing" {
    run "$SCRIPT" --config /nonexistent/config.txt --files /dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"config"* ]]
}

@test "errors when files list missing" {
    run "$SCRIPT" --config "$FIXTURES/rules.txt" --files /nonexistent/files.txt
    [ "$status" -ne 0 ]
    [[ "$output" == *"files"* ]]
}

@test "single docs match yields documentation label" {
    run "$SCRIPT" --config "$FIXTURES/rules.txt" --files "$FIXTURES/case_docs.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

@test "api files yield api and backend labels" {
    run "$SCRIPT" --config "$FIXTURES/rules.txt" --files "$FIXTURES/case_api.txt"
    [ "$status" -eq 0 ]
    # priority 20 rule emits "api,backend"
    expected=$'api\nbackend'
    [ "$output" = "$expected" ]
}

@test "test files matched by *.test.* pattern" {
    run "$SCRIPT" --config "$FIXTURES/rules.txt" --files "$FIXTURES/case_tests.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "tests" ]
}

@test "mixed files produce union of labels in priority order" {
    run "$SCRIPT" --config "$FIXTURES/rules.txt" --files "$FIXTURES/case_mixed.txt"
    [ "$status" -eq 0 ]
    # priorities: docs=10, api=20, tests=30 → docs first, then api,backend, then tests
    expected=$'documentation\napi\nbackend\ntests'
    [ "$output" = "$expected" ]
}

@test "labels deduplicated when multiple files match same rule" {
    run "$SCRIPT" --config "$FIXTURES/rules.txt" --files "$FIXTURES/case_dup.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

@test "no matching files produces empty output" {
    run "$SCRIPT" --config "$FIXTURES/rules.txt" --files "$FIXTURES/case_none.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "comments and blank lines in config ignored" {
    run "$SCRIPT" --config "$FIXTURES/rules_with_comments.txt" --files "$FIXTURES/case_docs.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

@test "invalid config line reports error" {
    run "$SCRIPT" --config "$FIXTURES/rules_bad.txt" --files "$FIXTURES/case_docs.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid"* || "$output" == *"Invalid"* ]]
}

@test "--help prints usage" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}
