#!/usr/bin/env bats

# Tests for generate-matrix.sh — drives generation of a GitHub Actions
# strategy.matrix JSON from a higher-level config.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../generate-matrix.sh"
    FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
    TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "errors when no config file provided" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "errors when config file does not exist" {
    run "$SCRIPT" "$TMPDIR/missing.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "errors when config has no matrix key" {
    echo '{}' > "$TMPDIR/c.json"
    run "$SCRIPT" "$TMPDIR/c.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"matrix"* ]]
}

@test "basic 2x2 matrix produces strategy JSON with 4 combinations" {
    run "$SCRIPT" "$FIXTURES/basic.json"
    [ "$status" -eq 0 ]
    # Output must be valid JSON
    echo "$output" | jq -e . >/dev/null
    # Check matrix os/node arrays preserved
    [ "$(echo "$output" | jq -r '.matrix.os | length')" = "2" ]
    [ "$(echo "$output" | jq -r '.matrix.node | length')" = "2" ]
}

@test "include and exclude are passed through to matrix" {
    run "$SCRIPT" "$FIXTURES/with-include-exclude.json"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.matrix.include | length')" = "1" ]
    [ "$(echo "$output" | jq -r '.matrix.exclude | length')" = "1" ]
    [ "$(echo "$output" | jq -r '.matrix.include[0].os')" = "windows-latest" ]
}

@test "max_parallel and fail_fast are mapped to GH Actions keys" {
    run "$SCRIPT" "$FIXTURES/with-include-exclude.json"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '."max-parallel"')" = "4" ]
    [ "$(echo "$output" | jq -r '."fail-fast"')" = "false" ]
}

@test "fails when effective matrix size exceeds max_size" {
    run "$SCRIPT" "$FIXTURES/too-big.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"exceeds"* ]] || [[ "$output" == *"max_size"* ]]
}

@test "succeeds when effective matrix size equals max_size" {
    run "$SCRIPT" "$FIXTURES/at-limit.json"
    [ "$status" -eq 0 ]
}
