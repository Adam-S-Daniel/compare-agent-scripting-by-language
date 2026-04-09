#!/usr/bin/env bats
# Tests for semantic version bumper using bats-core
# TDD approach: each test was written before the implementation

# Load the script under test
SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # Create a temp dir for each test
    TEST_TMPDIR="$(mktemp -d)"
    export TEST_TMPDIR
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ---------------------------------------------------------------------------
# Test 1 (RED): parse_version extracts semver from a plain version file
# ---------------------------------------------------------------------------
@test "parse_version reads version from VERSION file" {
    echo "1.2.3" > "$TEST_TMPDIR/VERSION"
    run bash "$SCRIPT_DIR/bump-version.sh" --parse-only "$TEST_TMPDIR/VERSION"
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

# ---------------------------------------------------------------------------
# Test 2 (RED): parse_version reads version from package.json
# ---------------------------------------------------------------------------
@test "parse_version reads version from package.json" {
    cat > "$TEST_TMPDIR/package.json" <<'EOF'
{
  "name": "my-app",
  "version": "2.4.1",
  "description": "test"
}
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" --parse-only "$TEST_TMPDIR/package.json"
    [ "$status" -eq 0 ]
    [ "$output" = "2.4.1" ]
}

# ---------------------------------------------------------------------------
# Test 3 (RED): detect_bump_type returns 'patch' for fix: commits
# ---------------------------------------------------------------------------
@test "detect_bump_type returns patch for fix commits" {
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
fix: correct null pointer dereference
fix: handle empty input
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" --detect-bump "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "patch" ]
}

# ---------------------------------------------------------------------------
# Test 4 (RED): detect_bump_type returns 'minor' for feat: commits
# ---------------------------------------------------------------------------
@test "detect_bump_type returns minor for feat commits" {
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
feat: add user authentication
fix: correct typo in README
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" --detect-bump "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "minor" ]
}

# ---------------------------------------------------------------------------
# Test 5 (RED): detect_bump_type returns 'major' for breaking change commits
# ---------------------------------------------------------------------------
@test "detect_bump_type returns major for breaking change commits" {
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
feat!: redesign public API
fix: small tweak
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" --detect-bump "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

# ---------------------------------------------------------------------------
# Test 6 (RED): detect_bump_type returns 'major' for BREAKING CHANGE footer
# ---------------------------------------------------------------------------
@test "detect_bump_type returns major for BREAKING CHANGE in footer" {
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
feat: new config format

BREAKING CHANGE: config file format changed from YAML to TOML
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" --detect-bump "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

# ---------------------------------------------------------------------------
# Test 7 (RED): bump_version increments patch correctly
# ---------------------------------------------------------------------------
@test "bump_version increments patch from 1.2.3 to 1.2.4" {
    run bash "$SCRIPT_DIR/bump-version.sh" --bump patch 1.2.3
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.4" ]
}

# ---------------------------------------------------------------------------
# Test 8 (RED): bump_version increments minor and resets patch
# ---------------------------------------------------------------------------
@test "bump_version increments minor from 1.2.3 to 1.3.0" {
    run bash "$SCRIPT_DIR/bump-version.sh" --bump minor 1.2.3
    [ "$status" -eq 0 ]
    [ "$output" = "1.3.0" ]
}

# ---------------------------------------------------------------------------
# Test 9 (RED): bump_version increments major and resets minor+patch
# ---------------------------------------------------------------------------
@test "bump_version increments major from 1.2.3 to 2.0.0" {
    run bash "$SCRIPT_DIR/bump-version.sh" --bump major 1.2.3
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

# ---------------------------------------------------------------------------
# Test 10 (RED): full pipeline updates VERSION file and outputs new version
# ---------------------------------------------------------------------------
@test "full pipeline bumps patch version in VERSION file" {
    echo "1.0.0" > "$TEST_TMPDIR/VERSION"
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
fix: resolve login redirect bug
fix: sanitize user input
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" \
        --version-file "$TEST_TMPDIR/VERSION" \
        --commits "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "1.0.1" ]
    # Verify the file was actually updated
    [ "$(cat "$TEST_TMPDIR/VERSION")" = "1.0.1" ]
}

# ---------------------------------------------------------------------------
# Test 11 (RED): full pipeline bumps minor for feat commits
# ---------------------------------------------------------------------------
@test "full pipeline bumps minor version for feat commits" {
    echo "1.1.0" > "$TEST_TMPDIR/VERSION"
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
feat: add dark mode toggle
fix: button alignment
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" \
        --version-file "$TEST_TMPDIR/VERSION" \
        --commits "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.0" ]
    [ "$(cat "$TEST_TMPDIR/VERSION")" = "1.2.0" ]
}

# ---------------------------------------------------------------------------
# Test 12 (RED): full pipeline bumps major for breaking changes
# ---------------------------------------------------------------------------
@test "full pipeline bumps major version for breaking changes" {
    echo "2.3.1" > "$TEST_TMPDIR/VERSION"
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
feat!: remove deprecated endpoints
feat: add new v2 API
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" \
        --version-file "$TEST_TMPDIR/VERSION" \
        --commits "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "3.0.0" ]
    [ "$(cat "$TEST_TMPDIR/VERSION")" = "3.0.0" ]
}

# ---------------------------------------------------------------------------
# Test 13 (RED): full pipeline updates package.json version
# ---------------------------------------------------------------------------
@test "full pipeline bumps version in package.json" {
    cat > "$TEST_TMPDIR/package.json" <<'EOF'
{
  "name": "my-app",
  "version": "0.9.5",
  "description": "test"
}
EOF
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
feat: introduce plugin system
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" \
        --version-file "$TEST_TMPDIR/package.json" \
        --commits "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "0.10.0" ]
    # Verify package.json was updated
    run bash -c "grep '\"version\"' \"$TEST_TMPDIR/package.json\""
    [[ "$output" == *'"0.10.0"'* ]]
}

# ---------------------------------------------------------------------------
# Test 14 (RED): changelog is generated and written
# ---------------------------------------------------------------------------
@test "changelog entry is generated for commits" {
    echo "1.5.0" > "$TEST_TMPDIR/VERSION"
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
feat: add export to CSV
fix: fix date parsing
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" \
        --version-file "$TEST_TMPDIR/VERSION" \
        --commits "$TEST_TMPDIR/commits.txt" \
        --changelog "$TEST_TMPDIR/CHANGELOG.md"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMPDIR/CHANGELOG.md" ]
    # Changelog should contain the new version
    run grep "1.6.0" "$TEST_TMPDIR/CHANGELOG.md"
    [ "$status" -eq 0 ]
    # Changelog should list the commits
    run grep "add export to CSV" "$TEST_TMPDIR/CHANGELOG.md"
    [ "$status" -eq 0 ]
    run grep "fix date parsing" "$TEST_TMPDIR/CHANGELOG.md"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 15 (RED): changelog prepends to existing CHANGELOG.md
# ---------------------------------------------------------------------------
@test "changelog prepends new entry to existing CHANGELOG.md" {
    echo "1.0.0" > "$TEST_TMPDIR/VERSION"
    cat > "$TEST_TMPDIR/CHANGELOG.md" <<'EOF'
## [1.0.0] - 2024-01-01

### Fixed
- initial release
EOF
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
fix: patch something
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" \
        --version-file "$TEST_TMPDIR/VERSION" \
        --commits "$TEST_TMPDIR/commits.txt" \
        --changelog "$TEST_TMPDIR/CHANGELOG.md"
    [ "$status" -eq 0 ]
    # New version heading should appear before old one
    new_line=$(grep -n "1.0.1" "$TEST_TMPDIR/CHANGELOG.md" | head -1 | cut -d: -f1)
    old_line=$(grep -n "1.0.0" "$TEST_TMPDIR/CHANGELOG.md" | head -1 | cut -d: -f1)
    [ "$new_line" -lt "$old_line" ]
}

# ---------------------------------------------------------------------------
# Test 16 (RED): error on missing version file
# ---------------------------------------------------------------------------
@test "error when version file does not exist" {
    cat > "$TEST_TMPDIR/commits.txt" <<'EOF'
fix: something
EOF
    run bash "$SCRIPT_DIR/bump-version.sh" \
        --version-file "$TEST_TMPDIR/nonexistent.txt" \
        --commits "$TEST_TMPDIR/commits.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"does not exist"* ]] || [[ "$output" == *"No such"* ]]
}

# ---------------------------------------------------------------------------
# Test 17 (RED): error on empty commits file
# ---------------------------------------------------------------------------
@test "error when commits file is empty" {
    echo "1.0.0" > "$TEST_TMPDIR/VERSION"
    touch "$TEST_TMPDIR/commits.txt"
    run bash "$SCRIPT_DIR/bump-version.sh" \
        --version-file "$TEST_TMPDIR/VERSION" \
        --commits "$TEST_TMPDIR/commits.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"empty"* ]] || [[ "$output" == *"no commits"* ]] || [[ "$output" == *"No commits"* ]]
}
