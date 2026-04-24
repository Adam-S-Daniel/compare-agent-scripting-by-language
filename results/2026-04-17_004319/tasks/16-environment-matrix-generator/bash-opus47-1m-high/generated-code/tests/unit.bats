#!/usr/bin/env bats
# Unit tests for matrix-generator.sh.
#
# Note: the *primary* test suite (ci.bats) drives the workflow through `act`,
# per benchmark rules. This unit file just keeps a TDD record of the individual
# behaviors the script must satisfy. Each test invokes the script directly
# against a fixture and asserts on its stdout / exit code.

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SCRIPT="$PROJECT_ROOT/matrix-generator.sh"
    FIXTURES="$PROJECT_ROOT/tests/fixtures"
}

@test "basic OS x language_versions cartesian product" {
    run bash "$SCRIPT" "$FIXTURES/basic.json"
    [ "$status" -eq 0 ]
    count=$(echo "$output" | jq '.matrix.include | length')
    [ "$count" -eq 4 ]
    # Every combination is present
    echo "$output" | jq -e '.matrix.include[] | select(.os=="ubuntu-latest" and .language_version=="3.10")'
    echo "$output" | jq -e '.matrix.include[] | select(.os=="ubuntu-latest" and .language_version=="3.11")'
    echo "$output" | jq -e '.matrix.include[] | select(.os=="windows-latest" and .language_version=="3.10")'
    echo "$output" | jq -e '.matrix.include[] | select(.os=="windows-latest" and .language_version=="3.11")'
}

@test "excludes remove matching combinations" {
    run bash "$SCRIPT" "$FIXTURES/with-exclude.json"
    [ "$status" -eq 0 ]
    count=$(echo "$output" | jq '.matrix.include | length')
    [ "$count" -eq 3 ]
    # windows + extra feature was excluded
    excluded=$(echo "$output" | jq '[.matrix.include[] | select(.os=="windows-latest" and .feature=="extra")] | length')
    [ "$excluded" -eq 0 ]
}

@test "includes append extra combinations" {
    run bash "$SCRIPT" "$FIXTURES/with-include.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.matrix.include[] | select(.os=="macos-latest" and .language_version=="3.11")'
}

@test "max-parallel and fail-fast appear in output" {
    run bash "$SCRIPT" "$FIXTURES/parallel-fail-fast.json"
    [ "$status" -eq 0 ]
    mp=$(echo "$output" | jq -r '."max-parallel"')
    ff=$(echo "$output" | jq -r '."fail-fast"')
    [ "$mp" = "4" ]
    [ "$ff" = "true" ]
}

@test "exceeding max_size fails with exit code 3" {
    run bash "$SCRIPT" "$FIXTURES/too-big.json"
    [ "$status" -eq 3 ]
    [[ "$output" == *"exceeds max_size"* ]]
}

@test "invalid JSON fails with exit code 2" {
    run bash "$SCRIPT" "$FIXTURES/invalid.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"invalid JSON"* ]]
}

@test "missing config file fails with exit code 2" {
    run bash "$SCRIPT" "$FIXTURES/does-not-exist.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"not found"* ]]
}

@test "no arguments prints usage and exits 1" {
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}

@test "empty axes with no includes fails with meaningful error" {
    run bash "$SCRIPT" "$FIXTURES/empty.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"at least one axis"* ]]
}

@test "features axis is included when present" {
    run bash "$SCRIPT" "$FIXTURES/with-features.json"
    [ "$status" -eq 0 ]
    count=$(echo "$output" | jq '.matrix.include | length')
    [ "$count" -eq 8 ]  # 2 os * 2 lv * 2 features
}
