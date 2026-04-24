#!/usr/bin/env bats
# Tests for semantic version bumper - TDD approach
# Each test was written BEFORE the implementation code

setup() {
    # Create a temp directory for each test
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
    # Path to the main script
    SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/version_bumper.sh"
    export SCRIPT
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── Helper: write a version.json fixture ───────────────────────────────────
write_version_file() {
    local version="$1"
    echo "{\"version\": \"$version\"}" > "$TEST_DIR/version.json"
}

# ── Helper: write a package.json fixture ───────────────────────────────────
write_package_json() {
    local version="$1"
    cat > "$TEST_DIR/package.json" <<EOF
{
  "name": "my-package",
  "version": "$version",
  "description": "test package"
}
EOF
}

# ── Helper: write a commit log fixture ─────────────────────────────────────
write_commit_log() {
    cat > "$TEST_DIR/commits.txt" <<EOF
$1
EOF
}

# ═══════════════════════════════════════════════════════════
# RED 1: script must exist and be executable
# ═══════════════════════════════════════════════════════════
@test "script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ═══════════════════════════════════════════════════════════
# RED 2: parse version from version.json
# ═══════════════════════════════════════════════════════════
@test "reads version from version.json" {
    write_version_file "1.2.3"
    > "$TEST_DIR/commits.txt"   # empty commits file — only testing version parse
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"current version: 1.2.3"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 3: parse version from package.json
# ═══════════════════════════════════════════════════════════
@test "reads version from package.json" {
    write_package_json "2.0.1"
    write_commit_log "fix: correct typo"
    run "$SCRIPT" --file "$TEST_DIR/package.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"current version: 2.0.1"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 4: fix commit → patch bump
# ═══════════════════════════════════════════════════════════
@test "fix commit bumps patch version" {
    write_version_file "1.2.3"
    write_commit_log "fix: correct null pointer"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"new version: 1.2.4"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 5: feat commit → minor bump
# ═══════════════════════════════════════════════════════════
@test "feat commit bumps minor version" {
    write_version_file "1.2.3"
    write_commit_log "feat: add user auth"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"new version: 1.3.0"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 6: breaking change → major bump
# ═══════════════════════════════════════════════════════════
@test "breaking change bumps major version" {
    write_version_file "1.2.3"
    write_commit_log "feat!: remove deprecated API"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"new version: 2.0.0"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 7: BREAKING CHANGE footer → major bump
# ═══════════════════════════════════════════════════════════
@test "BREAKING CHANGE footer bumps major version" {
    write_version_file "1.2.3"
    write_commit_log "feat: new api

BREAKING CHANGE: removed old endpoint"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"new version: 2.0.0"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 8: multiple commits → highest bump wins
# ═══════════════════════════════════════════════════════════
@test "multiple commits: highest bump wins (feat beats fix)" {
    write_version_file "1.2.3"
    write_commit_log "fix: typo
feat: new dashboard
fix: another typo"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"new version: 1.3.0"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 9: no relevant commits → no bump
# ═══════════════════════════════════════════════════════════
@test "non-conventional commits produce no bump" {
    write_version_file "1.2.3"
    write_commit_log "chore: update deps
docs: fix readme"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"new version: 1.2.3"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 10: actually update version.json (non-dry-run)
# ═══════════════════════════════════════════════════════════
@test "updates version.json with new version" {
    write_version_file "1.0.0"
    write_commit_log "feat: shiny new feature"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt"
    [ "$status" -eq 0 ]
    # Read back the file and check
    updated=$(grep -o '"version": "[^"]*"' "$TEST_DIR/version.json" | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
    [ "$updated" = "1.1.0" ]
}

# ═══════════════════════════════════════════════════════════
# RED 11: updates package.json with new version
# ═══════════════════════════════════════════════════════════
@test "updates package.json with new version" {
    write_package_json "2.3.4"
    write_commit_log "fix: edge case"
    run "$SCRIPT" --file "$TEST_DIR/package.json" --commits "$TEST_DIR/commits.txt"
    [ "$status" -eq 0 ]
    updated=$(grep -o '"version": "[^"]*"' "$TEST_DIR/package.json" | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
    [ "$updated" = "2.3.5" ]
}

# ═══════════════════════════════════════════════════════════
# RED 12: generates changelog entry
# ═══════════════════════════════════════════════════════════
@test "generates CHANGELOG.md entry" {
    write_version_file "1.0.0"
    write_commit_log "feat: add login page
fix: fix logout bug"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" \
        --changelog "$TEST_DIR/CHANGELOG.md"
    [ "$status" -eq 0 ]
    [ -f "$TEST_DIR/CHANGELOG.md" ]
    [[ "$(cat "$TEST_DIR/CHANGELOG.md")" == *"## [1.1.0]"* ]]
    [[ "$(cat "$TEST_DIR/CHANGELOG.md")" == *"feat: add login page"* ]]
    [[ "$(cat "$TEST_DIR/CHANGELOG.md")" == *"fix: fix logout bug"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 13: changelog prepends to existing CHANGELOG.md
# ═══════════════════════════════════════════════════════════
@test "changelog prepends to existing CHANGELOG.md" {
    write_version_file "1.0.0"
    write_commit_log "fix: patch thing"
    echo "## [1.0.0] - 2024-01-01

- initial release" > "$TEST_DIR/CHANGELOG.md"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" \
        --changelog "$TEST_DIR/CHANGELOG.md"
    [ "$status" -eq 0 ]
    # New entry must appear before old entry
    first_heading=$(grep "^## \[" "$TEST_DIR/CHANGELOG.md" | head -1)
    [[ "$first_heading" == *"1.0.1"* ]]
    [[ "$(cat "$TEST_DIR/CHANGELOG.md")" == *"initial release"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 14: outputs new version on stdout as last line
# ═══════════════════════════════════════════════════════════
@test "last stdout line is the new version number" {
    write_version_file "3.1.4"
    write_commit_log "feat: new thing"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    last_line="${lines[-1]}"
    [ "$last_line" = "3.2.0" ]
}

# ═══════════════════════════════════════════════════════════
# RED 15: missing version file exits with error
# ═══════════════════════════════════════════════════════════
@test "missing version file exits with error" {
    run "$SCRIPT" --file "$TEST_DIR/nonexistent.json" --commits "$TEST_DIR/commits.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"does not exist"* ]] || [[ "$output" == *"Error"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 16: missing commits file exits with error
# ═══════════════════════════════════════════════════════════
@test "missing commits file exits with error" {
    write_version_file "1.0.0"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/nocommits.txt"
    [ "$status" -ne 0 ]
}

# ═══════════════════════════════════════════════════════════
# RED 17: invalid semver in file exits with error
# ═══════════════════════════════════════════════════════════
@test "invalid semver in version file exits with error" {
    echo '{"version": "not-a-semver"}' > "$TEST_DIR/version.json"
    write_commit_log "fix: something"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"invalid"* ]] || [[ "$output" == *"Error"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 18: minor bump resets patch to 0
# ═══════════════════════════════════════════════════════════
@test "minor bump resets patch component to 0" {
    write_version_file "1.2.9"
    write_commit_log "feat: big new feature"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"new version: 1.3.0"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 19: major bump resets minor and patch to 0
# ═══════════════════════════════════════════════════════════
@test "major bump resets minor and patch to 0" {
    write_version_file "1.9.9"
    write_commit_log "feat!: breaking redesign"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"new version: 2.0.0"* ]]
}

# ═══════════════════════════════════════════════════════════
# RED 20: empty commits file → no bump
# ═══════════════════════════════════════════════════════════
@test "empty commits file results in no version bump" {
    write_version_file "1.0.0"
    > "$TEST_DIR/commits.txt"
    run "$SCRIPT" --file "$TEST_DIR/version.json" --commits "$TEST_DIR/commits.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"new version: 1.0.0"* ]]
}
