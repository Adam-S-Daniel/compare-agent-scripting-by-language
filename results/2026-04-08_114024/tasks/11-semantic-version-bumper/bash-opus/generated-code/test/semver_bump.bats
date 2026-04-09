#!/usr/bin/env bats
# Tests for semantic version bumper script
# Uses red/green TDD: each test was written before the corresponding implementation.

SCRIPT="$BATS_TEST_DIRNAME/../semver_bump.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

setup() {
    # Create a temp directory for each test to avoid side effects
    TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ── Parsing version from VERSION file ──

@test "parse_version reads version from a plain VERSION file" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-patch.log" --dry-run
    [[ "$output" == *"Current version: 1.2.3"* ]]
}

@test "parse_version reads version from package.json" {
    cp "$FIXTURES/package.json" "$TEST_TMPDIR/package.json"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/package.json" --commits "$FIXTURES/commits-patch.log" --dry-run
    [[ "$output" == *"Current version: 2.5.0"* ]]
}

@test "parse_version fails on missing file" {
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/nonexistent" --commits "$FIXTURES/commits-patch.log"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "parse_version fails on invalid version format" {
    echo "not-a-version" > "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-patch.log"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid"* ]]
}

# ── Commit classification ──

@test "patch commits produce a patch bump" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-patch.log" --dry-run
    [[ "$output" == *"New version: 1.2.4"* ]]
}

@test "feat commit produces a minor bump" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-minor.log" --dry-run
    [[ "$output" == *"New version: 1.3.0"* ]]
}

@test "breaking change with bang produces a major bump" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-major.log" --dry-run
    [[ "$output" == *"New version: 2.0.0"* ]]
}

@test "BREAKING CHANGE footer produces a major bump" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-breaking-footer.log" --dry-run
    [[ "$output" == *"New version: 2.0.0"* ]]
}

@test "empty commit log produces no bump" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-empty.log"
    [ "$status" -ne 0 ]
    [[ "$output" == *"No version-relevant commits"* ]]
}

# ── File update ──

@test "VERSION file is updated in place (non-dry-run)" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-minor.log"
    [ "$status" -eq 0 ]
    result="$(cat "$TEST_TMPDIR/VERSION")"
    [ "$result" = "1.3.0" ]
}

@test "package.json version field is updated in place" {
    cp "$FIXTURES/package.json" "$TEST_TMPDIR/package.json"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/package.json" --commits "$FIXTURES/commits-patch.log"
    [ "$status" -eq 0 ]
    # Extract the version field from the updated package.json
    version="$(grep '"version"' "$TEST_TMPDIR/package.json" | sed 's/.*"\([0-9]*\.[0-9]*\.[0-9]*\)".*/\1/')"
    [ "$version" = "2.5.1" ]
}

@test "dry-run does NOT modify the version file" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-minor.log" --dry-run
    [ "$status" -eq 0 ]
    result="$(cat "$TEST_TMPDIR/VERSION")"
    [ "$result" = "1.2.3" ]
}

# ── Changelog generation ──

@test "changelog is generated with commit entries" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-minor.log" --changelog "$TEST_TMPDIR/CHANGELOG.md"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMPDIR/CHANGELOG.md" ]
    # Check the changelog contains the version heading and commit messages
    grep -q "## 1.3.0" "$TEST_TMPDIR/CHANGELOG.md"
    grep -q "add user profile endpoint" "$TEST_TMPDIR/CHANGELOG.md"
    grep -q "correct validation logic" "$TEST_TMPDIR/CHANGELOG.md"
}

@test "changelog groups entries by type" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-minor.log" --changelog "$TEST_TMPDIR/CHANGELOG.md"
    [ "$status" -eq 0 ]
    grep -q "### Features" "$TEST_TMPDIR/CHANGELOG.md"
    grep -q "### Bug Fixes" "$TEST_TMPDIR/CHANGELOG.md"
}

@test "changelog is not created on dry-run" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-minor.log" --changelog "$TEST_TMPDIR/CHANGELOG.md" --dry-run
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMPDIR/CHANGELOG.md" ]
}

# ── Output ──

@test "script outputs only the new version on stdout with --quiet" {
    cp "$FIXTURES/VERSION" "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commits "$FIXTURES/commits-patch.log" --quiet
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.4" ]
}

# ── Argument validation ──

@test "missing --version-file argument shows usage" {
    run bash "$SCRIPT" --commits "$FIXTURES/commits-patch.log"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--version-file"* ]]
}

@test "missing --commits argument shows usage" {
    run bash "$SCRIPT" --version-file "$FIXTURES/VERSION"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--commits"* ]]
}
