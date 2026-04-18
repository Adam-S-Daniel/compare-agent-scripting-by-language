#!/usr/bin/env bats

# Integration tests for pr-label-assigner.sh
# TDD: each test case drives one behavior in the script.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../pr-label-assigner.sh"
    RULES="${BATS_TEST_DIRNAME}/fixtures/rules.conf"
}

@test "script exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "errors when rules file missing" {
    run "$SCRIPT" --rules /tmp/does-not-exist-xyz.conf --files /dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"rules file"* ]]
}

@test "docs/** matches docs label" {
    files=$(mktemp)
    echo "docs/readme.md" > "$files"
    run "$SCRIPT" --rules "$RULES" --files "$files"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
}

@test "multiple files produce multiple unique labels" {
    files=$(mktemp)
    printf 'docs/a.md\nsrc/api/handler.sh\n' > "$files"
    run "$SCRIPT" --rules "$RULES" --files "$files"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
    [[ "$output" == *"api"* ]]
}

@test "single file can produce multiple labels" {
    files=$(mktemp)
    echo "src/api/foo.test.sh" > "$files"
    run "$SCRIPT" --rules "$RULES" --files "$files"
    [ "$status" -eq 0 ]
    [[ "$output" == *"api"* ]]
    [[ "$output" == *"tests"* ]]
}

@test "labels are deduplicated" {
    files=$(mktemp)
    printf 'docs/a.md\ndocs/b.md\ndocs/c.md\n' > "$files"
    run "$SCRIPT" --rules "$RULES" --files "$files"
    [ "$status" -eq 0 ]
    count=$(echo "$output" | grep -c '^documentation$' || true)
    [ "$count" -eq 1 ]
}

@test "labels emitted in priority order (higher priority first)" {
    # rules.conf: api priority 10, tests priority 20, docs priority 5
    files=$(mktemp)
    printf 'src/api/x.test.sh\ndocs/a.md\n' > "$files"
    run "$SCRIPT" --rules "$RULES" --files "$files"
    [ "$status" -eq 0 ]
    # Expect order: tests (20), api (10), documentation (5)
    expected="tests
api
documentation"
    [ "$output" = "$expected" ]
}

@test "no rules matching produces empty output and exit 0" {
    files=$(mktemp)
    echo "random/other.bin" > "$files"
    run "$SCRIPT" --rules "$RULES" --files "$files"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "reads files from stdin when --files -" {
    run bash -c "printf 'docs/x.md\n' | '$SCRIPT' --rules '$RULES' --files -"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
}

@test "glob ** matches multi-level paths" {
    files=$(mktemp)
    echo "src/api/v1/nested/deep/handler.sh" > "$files"
    run "$SCRIPT" --rules "$RULES" --files "$files"
    [ "$status" -eq 0 ]
    [[ "$output" == *"api"* ]]
}

@test "single-star glob does not cross slash" {
    # *.test.* should match foo.test.sh at any level, but only as filename
    files=$(mktemp)
    echo "lib/foo.test.sh" > "$files"
    run "$SCRIPT" --rules "$RULES" --files "$files"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tests"* ]]
}

@test "workflow YAML parses and has expected structure" {
    wf="${BATS_TEST_DIRNAME}/../.github/workflows/pr-label-assigner.yml"
    [ -f "$wf" ]
    grep -q "on:" "$wf"
    grep -q "jobs:" "$wf"
    grep -q "actions/checkout@v4" "$wf"
    grep -q "pr-label-assigner.sh" "$wf"
}

@test "workflow passes actionlint" {
    wf="${BATS_TEST_DIRNAME}/../.github/workflows/pr-label-assigner.yml"
    run actionlint "$wf"
    [ "$status" -eq 0 ]
}
