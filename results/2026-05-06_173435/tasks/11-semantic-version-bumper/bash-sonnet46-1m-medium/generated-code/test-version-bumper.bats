#!/usr/bin/env bats
# Unit tests for bump-version.sh using bats-core.
# TDD approach: tests written before the implementation script exists.

SCRIPT="$BATS_TEST_DIRNAME/bump-version.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

setup() {
    # Each test gets its own temp dir so files don't bleed between tests
    TEST_TMP="$BATS_TEST_TMPDIR/test-$$"
    mkdir -p "$TEST_TMP"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---------------------------------------------------------------------------
# patch bump: only fix commits → increment patch digit only
# ---------------------------------------------------------------------------
@test "patch bump: fix commit bumps 1.0.0 to 1.0.1" {
    cp "$FIXTURES/version-1.0.0.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-fix.txt"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_TMP/version.txt")" = "1.0.1" ]
    [[ "$output" == *"NEW_VERSION: 1.0.1"* ]]
}

@test "patch bump: fix commit bumps 1.2.3 to 1.2.4" {
    cp "$FIXTURES/version-1.2.3.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-fix.txt"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_TMP/version.txt")" = "1.2.4" ]
    [[ "$output" == *"NEW_VERSION: 1.2.4"* ]]
}

# ---------------------------------------------------------------------------
# minor bump: feat commit (higher precedence than fix)
# ---------------------------------------------------------------------------
@test "minor bump: feat commit bumps 1.0.0 to 1.1.0" {
    cp "$FIXTURES/version-1.0.0.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-feat.txt"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_TMP/version.txt")" = "1.1.0" ]
    [[ "$output" == *"NEW_VERSION: 1.1.0"* ]]
}

@test "minor bump: feat wins over fix in mixed commits" {
    cp "$FIXTURES/version-1.0.0.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-mixed.txt"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_TMP/version.txt")" = "1.1.0" ]
    [[ "$output" == *"NEW_VERSION: 1.1.0"* ]]
}

# ---------------------------------------------------------------------------
# major bump: breaking change wins over everything
# ---------------------------------------------------------------------------
@test "major bump: breaking change (feat!) bumps 1.0.0 to 2.0.0" {
    cp "$FIXTURES/version-1.0.0.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-breaking.txt"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_TMP/version.txt")" = "2.0.0" ]
    [[ "$output" == *"NEW_VERSION: 2.0.0"* ]]
}

@test "major bump: breaking change bumps 1.2.3 to 2.0.0" {
    cp "$FIXTURES/version-1.2.3.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-breaking.txt"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_TMP/version.txt")" = "2.0.0" ]
    [[ "$output" == *"NEW_VERSION: 2.0.0"* ]]
}

# ---------------------------------------------------------------------------
# no-op: chore/docs commits don't bump the version
# ---------------------------------------------------------------------------
@test "no bump: non-semantic commits leave version unchanged" {
    cp "$FIXTURES/version-1.0.0.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-none.txt"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_TMP/version.txt")" = "1.0.0" ]
    [[ "$output" == *"NEW_VERSION: 1.0.0"* ]]
}

# ---------------------------------------------------------------------------
# package.json format
# ---------------------------------------------------------------------------
@test "package.json: feat commit bumps version field to 1.1.0" {
    cp "$FIXTURES/package-1.0.0.json" "$TEST_TMP/package.json"
    run bash "$SCRIPT" "$TEST_TMP/package.json" "$FIXTURES/commits-feat.txt"
    [ "$status" -eq 0 ]
    new_ver=$(grep '"version"' "$TEST_TMP/package.json" | sed 's/.*"version": *"\([^"]*\)".*/\1/')
    [ "$new_ver" = "1.1.0" ]
    [[ "$output" == *"NEW_VERSION: 1.1.0"* ]]
}

@test "package.json: fix commit bumps version field to 1.0.1" {
    cp "$FIXTURES/package-1.0.0.json" "$TEST_TMP/package.json"
    run bash "$SCRIPT" "$TEST_TMP/package.json" "$FIXTURES/commits-fix.txt"
    [ "$status" -eq 0 ]
    new_ver=$(grep '"version"' "$TEST_TMP/package.json" | sed 's/.*"version": *"\([^"]*\)".*/\1/')
    [ "$new_ver" = "1.0.1" ]
    [[ "$output" == *"NEW_VERSION: 1.0.1"* ]]
}

# ---------------------------------------------------------------------------
# changelog output format
# ---------------------------------------------------------------------------
@test "changelog: fix commits appear under Bug Fixes section" {
    cp "$FIXTURES/version-1.0.0.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-fix.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bug Fixes"* ]]
}

@test "changelog: feat commits appear under Features section" {
    cp "$FIXTURES/version-1.0.0.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-feat.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Features"* ]]
}

@test "changelog: breaking changes appear under Breaking Changes section" {
    cp "$FIXTURES/version-1.0.0.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-breaking.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Breaking Changes"* ]]
}

@test "changelog: header includes new version number" {
    cp "$FIXTURES/version-1.0.0.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "$FIXTURES/commits-feat.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[1.1.0]"* ]]
}

# ---------------------------------------------------------------------------
# error handling
# ---------------------------------------------------------------------------
@test "error: missing version file exits non-zero with message" {
    run bash "$SCRIPT" "/no/such/file.txt" "$FIXTURES/commits-fix.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "error: missing commits file exits non-zero with message" {
    cp "$FIXTURES/version-1.0.0.txt" "$TEST_TMP/version.txt"
    run bash "$SCRIPT" "$TEST_TMP/version.txt" "/no/such/commits.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "error: no arguments exits non-zero with usage message" {
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}
