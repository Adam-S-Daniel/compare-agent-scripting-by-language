#!/usr/bin/env bats
# Tests for bump-version.sh - Semantic Version Bumper
# TDD: each test drives a single piece of functionality.

setup() {
    # Locate the script under test relative to this bats file.
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    SCRIPT="$SCRIPT_DIR/bump-version.sh"
    FIXTURES="$SCRIPT_DIR/test/fixtures"

    # Each test gets an isolated temp workspace so file writes don't leak.
    TMP="$(mktemp -d)"
    export SCRIPT FIXTURES TMP
}

teardown() {
    rm -rf "$TMP"
}

# --- bump_type determination ----------------------------------------------

@test "bump_type: 'fix' commit yields patch" {
    run "$SCRIPT" bump_type "fix: correct parsing bug"
    [ "$status" -eq 0 ]
    [ "$output" = "patch" ]
}

@test "bump_type: 'feat' commit yields minor" {
    run "$SCRIPT" bump_type "feat: add new flag"
    [ "$status" -eq 0 ]
    [ "$output" = "minor" ]
}

@test "bump_type: '!' after type yields major" {
    run "$SCRIPT" bump_type "feat!: drop support for node 14"
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "bump_type: 'BREAKING CHANGE:' footer yields major" {
    run "$SCRIPT" bump_type $'feat: new api\n\nBREAKING CHANGE: removes old endpoint'
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "bump_type: unknown type yields none" {
    run "$SCRIPT" bump_type "chore: tidy whitespace"
    [ "$status" -eq 0 ]
    [ "$output" = "none" ]
}

@test "bump_type: highest-precedence wins across multiple commits (stdin)" {
    # Multiple commits piped via stdin, one per line; breaking beats feat beats fix.
    output="$(printf 'fix: a\nfeat: b\nfix: c\n' | "$SCRIPT" bump_type)"
    [ "$output" = "minor" ]

    output="$(printf 'feat: a\nfeat!: wipe\nfix: c\n' | "$SCRIPT" bump_type)"
    [ "$output" = "major" ]
}

# --- bump_version arithmetic ---------------------------------------------

@test "bump_version: patch increments last number" {
    run "$SCRIPT" bump_version 1.2.3 patch
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.4" ]
}

@test "bump_version: minor increments middle and zeroes patch" {
    run "$SCRIPT" bump_version 1.2.3 minor
    [ "$status" -eq 0 ]
    [ "$output" = "1.3.0" ]
}

@test "bump_version: major increments first and zeroes the rest" {
    run "$SCRIPT" bump_version 1.2.3 major
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "bump_version: none returns version unchanged" {
    run "$SCRIPT" bump_version 1.2.3 none
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

@test "bump_version: rejects non-semver input" {
    run "$SCRIPT" bump_version "not-a-version" patch
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid semver"* ]]
}

# --- read_version --------------------------------------------------------

@test "read_version: reads plain VERSION file" {
    echo "0.4.1" > "$TMP/VERSION"
    run "$SCRIPT" read_version "$TMP/VERSION"
    [ "$status" -eq 0 ]
    [ "$output" = "0.4.1" ]
}

@test "read_version: reads version from package.json" {
    cat > "$TMP/package.json" <<'EOF'
{
  "name": "demo",
  "version": "2.3.4",
  "description": "demo"
}
EOF
    run "$SCRIPT" read_version "$TMP/package.json"
    [ "$status" -eq 0 ]
    [ "$output" = "2.3.4" ]
}

@test "read_version: errors on missing file" {
    run "$SCRIPT" read_version "$TMP/nope"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# --- write_version -------------------------------------------------------

@test "write_version: updates plain VERSION file" {
    echo "0.4.1" > "$TMP/VERSION"
    run "$SCRIPT" write_version "$TMP/VERSION" "0.5.0"
    [ "$status" -eq 0 ]
    [ "$(cat "$TMP/VERSION")" = "0.5.0" ]
}

@test "write_version: preserves package.json structure" {
    cat > "$TMP/package.json" <<'EOF'
{
  "name": "demo",
  "version": "2.3.4",
  "description": "demo"
}
EOF
    run "$SCRIPT" write_version "$TMP/package.json" "3.0.0"
    [ "$status" -eq 0 ]
    # New version is in place and other fields are preserved.
    grep -q '"version": "3.0.0"' "$TMP/package.json"
    grep -q '"name": "demo"' "$TMP/package.json"
    grep -q '"description": "demo"' "$TMP/package.json"
}

# --- changelog -----------------------------------------------------------

@test "changelog: groups commits by type under version heading" {
    output="$(printf 'feat: add foo\nfix: bug in bar\nchore: deps\n' | "$SCRIPT" changelog "1.3.0")"
    [[ "$output" == *"## 1.3.0"* ]]
    [[ "$output" == *"### Features"* ]]
    [[ "$output" == *"add foo"* ]]
    [[ "$output" == *"### Bug Fixes"* ]]
    [[ "$output" == *"bug in bar"* ]]
}

@test "changelog: includes breaking-change section when relevant" {
    output="$(printf 'feat!: big rewrite\n' | "$SCRIPT" changelog "2.0.0")"
    [[ "$output" == *"### BREAKING CHANGES"* ]]
    [[ "$output" == *"big rewrite"* ]]
}

# --- end-to-end run command ----------------------------------------------

@test "run: bumps a VERSION file using a commit log fixture (feat -> minor)" {
    echo "1.1.0" > "$TMP/VERSION"
    cp "$FIXTURES/commits-feat.log" "$TMP/commits.log"

    run "$SCRIPT" run --version-file "$TMP/VERSION" --commits "$TMP/commits.log" --changelog "$TMP/CHANGELOG.md"
    [ "$status" -eq 0 ]

    # Script prints the new version to stdout for pipeline consumption.
    [ "$output" = "1.2.0" ]
    [ "$(cat "$TMP/VERSION")" = "1.2.0" ]
    grep -q "## 1.2.0" "$TMP/CHANGELOG.md"
    grep -q "add login command" "$TMP/CHANGELOG.md"
}

@test "run: package.json + fix-only commits yields patch bump" {
    cat > "$TMP/package.json" <<'EOF'
{
  "name": "demo",
  "version": "0.9.3"
}
EOF
    cp "$FIXTURES/commits-fix.log" "$TMP/commits.log"

    run "$SCRIPT" run --version-file "$TMP/package.json" --commits "$TMP/commits.log" --changelog "$TMP/CHANGELOG.md"
    [ "$status" -eq 0 ]
    [ "$output" = "0.9.4" ]
    grep -q '"version": "0.9.4"' "$TMP/package.json"
    grep -q "## 0.9.4" "$TMP/CHANGELOG.md"
}

@test "run: breaking commit triggers major bump" {
    echo "2.5.1" > "$TMP/VERSION"
    cp "$FIXTURES/commits-breaking.log" "$TMP/commits.log"

    run "$SCRIPT" run --version-file "$TMP/VERSION" --commits "$TMP/commits.log" --changelog "$TMP/CHANGELOG.md"
    [ "$status" -eq 0 ]
    [ "$output" = "3.0.0" ]
    grep -q "## 3.0.0" "$TMP/CHANGELOG.md"
    grep -q "BREAKING CHANGES" "$TMP/CHANGELOG.md"
}

@test "run: no conventional commits -> no bump, exits 0 with message" {
    echo "1.0.0" > "$TMP/VERSION"
    cp "$FIXTURES/commits-chore.log" "$TMP/commits.log"

    run "$SCRIPT" run --version-file "$TMP/VERSION" --commits "$TMP/commits.log" --changelog "$TMP/CHANGELOG.md"
    [ "$status" -eq 0 ]
    # Version unchanged; stdout still prints current version for downstream steps.
    [ "$output" = "1.0.0" ]
    [ "$(cat "$TMP/VERSION")" = "1.0.0" ]
}

@test "run: reports clear error when version file is missing" {
    run "$SCRIPT" run --version-file "$TMP/missing" --commits "$FIXTURES/commits-feat.log" --changelog "$TMP/CHANGELOG.md"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}
