#!/usr/bin/env bats

# Test suite for semantic version bumper
# Uses red/green TDD methodology with bats-core

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/test/fixtures"

# Source the library functions for unit testing
setup() {
    source "$SCRIPT_DIR/version_lib.sh"
}

# ============================================================
# Version Parsing Tests
# ============================================================

@test "parse_version extracts major.minor.patch from plain version string" {
    result="$(parse_version "3.7.12")"
    [ "$result" = "3 7 12" ]
}

@test "parse_version extracts version from string with v prefix" {
    result="$(parse_version "v1.0.0")"
    [ "$result" = "1 0 0" ]
}

@test "parse_version fails on invalid version string" {
    run parse_version "not-a-version"
    [ "$status" -ne 0 ]
}

@test "parse_version fails on empty string" {
    run parse_version ""
    [ "$status" -ne 0 ]
}

@test "read_version_file reads version from plain text file" {
    result="$(read_version_file "$FIXTURES_DIR/version_plain.txt")"
    [ "$result" = "1.2.3" ]
}

@test "read_version_file reads version from package.json" {
    result="$(read_version_file "$FIXTURES_DIR/package.json")"
    [ "$result" = "2.5.1" ]
}

@test "read_version_file fails on nonexistent file" {
    run read_version_file "/nonexistent/file.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# ============================================================
# Bump Type Detection Tests
# ============================================================

@test "detect_bump_type returns patch for fix-only commits" {
    result="$(detect_bump_type "$FIXTURES_DIR/commits_patch.txt")"
    [ "$result" = "patch" ]
}

@test "detect_bump_type returns minor for feat commits" {
    result="$(detect_bump_type "$FIXTURES_DIR/commits_minor.txt")"
    [ "$result" = "minor" ]
}

@test "detect_bump_type returns major for breaking change (! suffix)" {
    result="$(detect_bump_type "$FIXTURES_DIR/commits_major.txt")"
    [ "$result" = "major" ]
}

@test "detect_bump_type returns major for BREAKING CHANGE footer" {
    result="$(detect_bump_type "$FIXTURES_DIR/commits_breaking_footer.txt")"
    [ "$result" = "major" ]
}

@test "detect_bump_type returns none for non-bumping commits" {
    result="$(detect_bump_type "$FIXTURES_DIR/commits_no_bump.txt")"
    [ "$result" = "none" ]
}

@test "detect_bump_type returns none for empty commit log" {
    result="$(detect_bump_type "$FIXTURES_DIR/commits_empty.txt")"
    [ "$result" = "none" ]
}

# ============================================================
# Version Bumping Tests
# ============================================================

@test "bump_version increments patch correctly" {
    result="$(bump_version "1.2.3" "patch")"
    [ "$result" = "1.2.4" ]
}

@test "bump_version increments minor and resets patch" {
    result="$(bump_version "1.2.3" "minor")"
    [ "$result" = "1.3.0" ]
}

@test "bump_version increments major and resets minor+patch" {
    result="$(bump_version "1.2.3" "major")"
    [ "$result" = "2.0.0" ]
}

@test "bump_version returns same version for none" {
    result="$(bump_version "1.2.3" "none")"
    [ "$result" = "1.2.3" ]
}

@test "bump_version handles 0.x versions" {
    result="$(bump_version "0.1.0" "minor")"
    [ "$result" = "0.2.0" ]
}

@test "bump_version handles v prefix" {
    result="$(bump_version "v1.2.3" "patch")"
    [ "$result" = "1.2.4" ]
}

# ============================================================
# Changelog Generation Tests
# ============================================================

@test "generate_changelog groups fix commits under Fixed" {
    result="$(generate_changelog "$FIXTURES_DIR/commits_patch.txt" "1.2.4")"
    [[ "$result" == *"## 1.2.4"* ]]
    [[ "$result" == *"### Fixed"* ]]
    [[ "$result" == *"resolve null pointer in user service"* ]]
}

@test "generate_changelog groups feat commits under Added" {
    result="$(generate_changelog "$FIXTURES_DIR/commits_minor.txt" "1.3.0")"
    [[ "$result" == *"### Added"* ]]
    [[ "$result" == *"add user authentication endpoint"* ]]
}

@test "generate_changelog includes Breaking Changes section for major" {
    result="$(generate_changelog "$FIXTURES_DIR/commits_major.txt" "2.0.0")"
    [[ "$result" == *"### Breaking Changes"* ]]
    [[ "$result" == *"redesign authentication system"* ]]
}

@test "generate_changelog returns empty for no-bump commits" {
    result="$(generate_changelog "$FIXTURES_DIR/commits_no_bump.txt" "1.2.3")"
    # Should still produce a header but with Other section
    [[ "$result" == *"## 1.2.3"* ]]
}

# ============================================================
# Version File Update Tests
# ============================================================

@test "update_version_file updates plain text version file" {
    tmp="$(mktemp)"
    echo "1.2.3" > "$tmp"
    update_version_file "$tmp" "1.3.0"
    result="$(cat "$tmp")"
    [ "$result" = "1.3.0" ]
    rm -f "$tmp"
}

@test "update_version_file updates package.json version" {
    tmp="$(mktemp --suffix=.json)"
    cat "$FIXTURES_DIR/package.json" > "$tmp"
    update_version_file "$tmp" "2.6.0"
    # Verify the version changed
    result="$(grep '"version"' "$tmp" | head -1)"
    [[ "$result" == *'"2.6.0"'* ]]
    # Verify other fields are preserved
    result_name="$(grep '"name"' "$tmp")"
    [[ "$result_name" == *'"test-project"'* ]]
    rm -f "$tmp"
}

@test "update_version_file fails on nonexistent file" {
    run update_version_file "/nonexistent/file.txt" "1.0.0"
    [ "$status" -ne 0 ]
}

# ============================================================
# Error Handling Tests
# ============================================================

@test "parse_version rejects version with missing components" {
    run parse_version "1.2"
    [ "$status" -ne 0 ]
}

@test "bump_version rejects invalid bump type" {
    run bump_version "1.2.3" "invalid"
    [ "$status" -ne 0 ]
}

@test "detect_bump_type fails on nonexistent commit file" {
    run detect_bump_type "/nonexistent/commits.txt"
    [ "$status" -ne 0 ]
}

# ============================================================
# Integration Test: Full pipeline
# ============================================================

@test "full pipeline: patch bump on plain version file" {
    tmp_version="$(mktemp)"
    echo "1.2.3" > "$tmp_version"
    tmp_changelog="$(mktemp)"

    run "$SCRIPT_DIR/version_bumper.sh" \
        --version-file "$tmp_version" \
        --commits "$FIXTURES_DIR/commits_patch.txt" \
        --changelog "$tmp_changelog"

    [ "$status" -eq 0 ]
    [[ "$output" == *"1.2.4"* ]]

    # Version file should be updated
    new_ver="$(cat "$tmp_version")"
    [ "$new_ver" = "1.2.4" ]

    # Changelog should exist and have content
    [ -s "$tmp_changelog" ]

    rm -f "$tmp_version" "$tmp_changelog"
}

@test "full pipeline: minor bump on package.json" {
    tmp_pkg="$(mktemp --suffix=.json)"
    cat "$FIXTURES_DIR/package.json" > "$tmp_pkg"
    tmp_changelog="$(mktemp)"

    run "$SCRIPT_DIR/version_bumper.sh" \
        --version-file "$tmp_pkg" \
        --commits "$FIXTURES_DIR/commits_minor.txt" \
        --changelog "$tmp_changelog"

    [ "$status" -eq 0 ]
    [[ "$output" == *"2.6.0"* ]]

    rm -f "$tmp_pkg" "$tmp_changelog"
}

@test "full pipeline: major bump" {
    tmp_version="$(mktemp)"
    echo "1.2.3" > "$tmp_version"
    tmp_changelog="$(mktemp)"

    run "$SCRIPT_DIR/version_bumper.sh" \
        --version-file "$tmp_version" \
        --commits "$FIXTURES_DIR/commits_major.txt" \
        --changelog "$tmp_changelog"

    [ "$status" -eq 0 ]
    [[ "$output" == *"2.0.0"* ]]

    new_ver="$(cat "$tmp_version")"
    [ "$new_ver" = "2.0.0" ]

    rm -f "$tmp_version" "$tmp_changelog"
}

@test "full pipeline: no bump needed" {
    tmp_version="$(mktemp)"
    echo "1.2.3" > "$tmp_version"
    tmp_changelog="$(mktemp)"

    run "$SCRIPT_DIR/version_bumper.sh" \
        --version-file "$tmp_version" \
        --commits "$FIXTURES_DIR/commits_no_bump.txt" \
        --changelog "$tmp_changelog"

    [ "$status" -eq 0 ]
    [[ "$output" == *"1.2.3"* ]]

    # Version should remain unchanged
    new_ver="$(cat "$tmp_version")"
    [ "$new_ver" = "1.2.3" ]

    rm -f "$tmp_version" "$tmp_changelog"
}

@test "full pipeline: missing --version-file argument errors" {
    run "$SCRIPT_DIR/version_bumper.sh" \
        --commits "$FIXTURES_DIR/commits_patch.txt"

    [ "$status" -ne 0 ]
    [[ "$output" == *"version-file"* ]] || [[ "$output" == *"Usage"* ]]
}
