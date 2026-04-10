#!/usr/bin/env bats
# tests/version_bumper.bats
# Test suite for semantic version bumper using bats-core.
# TDD approach: tests are added incrementally, implementation follows.

# --- Setup ---
SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
BUMP_SCRIPT="$SCRIPT_DIR/bump-version.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

setup() {
    # Each test gets an isolated temp directory
    TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# TDD CYCLE 1: Parse version from version.txt
# =============================================================================

@test "parses version 1.2.3 from version.txt and returns it unchanged (no commits)" {
    echo "1.2.3" > "$TEST_TMPDIR/version.txt"
    # Empty commits file -> no bump -> same version
    touch "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

# =============================================================================
# TDD CYCLE 2: Parse version from package.json
# =============================================================================

@test "parses version from package.json and returns it unchanged (no commits)" {
    cat > "$TEST_TMPDIR/package.json" <<'EOF'
{
  "name": "my-app",
  "version": "2.0.1",
  "description": "test"
}
EOF
    touch "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/package.json" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.1" ]
}

# =============================================================================
# TDD CYCLE 3: Patch bump (fix commits)
# =============================================================================

@test "patch bump: 1.0.0 + fix commits -> 1.0.1" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_patch.txt" "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "1.0.1" ]
}

@test "patch bump updates version.txt in place" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_patch.txt" "$TEST_TMPDIR/commits.txt"
    bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    run cat "$TEST_TMPDIR/version.txt"
    [ "$output" = "1.0.1" ]
}

# =============================================================================
# TDD CYCLE 4: Minor bump (feat commits)
# =============================================================================

@test "minor bump: 1.1.0 + feat commits -> 1.2.0" {
    echo "1.1.0" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_minor.txt" "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.0" ]
}

@test "minor bump resets patch to 0: 1.1.5 + feat -> 1.2.0" {
    echo "1.1.5" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_minor.txt" "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.0" ]
}

# =============================================================================
# TDD CYCLE 5: Major bump (breaking change commits)
# =============================================================================

@test "major bump: 1.2.3 + breaking commits -> 2.0.0" {
    echo "1.2.3" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_major.txt" "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "major bump resets minor and patch to 0: 3.7.9 + breaking -> 4.0.0" {
    echo "3.7.9" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_major.txt" "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "4.0.0" ]
}

# =============================================================================
# TDD CYCLE 6: Mixed commits — highest bump wins
# =============================================================================

@test "mixed commits feat+fix: feat wins -> minor bump: 1.0.0 -> 1.1.0" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_mixed.txt" "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "1.1.0" ]
}

@test "breaking change with feat+fix: major wins -> 1.0.0 -> 2.0.0" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_breaking_mixed.txt" "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

# =============================================================================
# TDD CYCLE 7: Breaking change detection variants
# =============================================================================

@test "detects breaking change via feat! syntax" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    printf 'feat!: redesign entire API\n' > "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "detects breaking change via fix! syntax" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    printf 'fix!: change error response codes\n' > "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "detects breaking change via BREAKING CHANGE in message" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    printf 'feat: new login\nBREAKING CHANGE: auth tokens now expire\n' > "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

# =============================================================================
# TDD CYCLE 8: Changelog generation
# =============================================================================

@test "generates CHANGELOG.md with new version entry" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_minor.txt" "$TEST_TMPDIR/commits.txt"
    bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ -f "$TEST_TMPDIR/CHANGELOG.md" ]
}

@test "changelog contains new version header" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_minor.txt" "$TEST_TMPDIR/commits.txt"
    bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    run grep -c "## \[1.1.0\]" "$TEST_TMPDIR/CHANGELOG.md"
    [ "$output" -ge 1 ]
}

@test "changelog prepends new entry when CHANGELOG.md already exists" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_minor.txt" "$TEST_TMPDIR/commits.txt"
    echo "## [1.0.0] - 2024-01-01" > "$TEST_TMPDIR/CHANGELOG.md"
    bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    # New version should appear before old
    run bash -c "grep -n '## \[' \"$TEST_TMPDIR/CHANGELOG.md\" | head -1"
    [[ "$output" == *"1.1.0"* ]]
}

@test "changelog lists feat commits under Features section" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_minor.txt" "$TEST_TMPDIR/commits.txt"
    bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    run grep -c "### Features" "$TEST_TMPDIR/CHANGELOG.md"
    [ "$output" -ge 1 ]
}

@test "changelog lists fix commits under Bug Fixes section" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    cp "$FIXTURES_DIR/commits_patch.txt" "$TEST_TMPDIR/commits.txt"
    bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    run grep -c "### Bug Fixes" "$TEST_TMPDIR/CHANGELOG.md"
    [ "$output" -ge 1 ]
}

# =============================================================================
# TDD CYCLE 9: Error handling
# =============================================================================

@test "exits with error when version file does not exist" {
    touch "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/nonexistent.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
}

@test "exits with error when commits file does not exist" {
    echo "1.0.0" > "$TEST_TMPDIR/version.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/nonexistent.txt"
    [ "$status" -ne 0 ]
}

@test "exits with error when version file has invalid version format" {
    echo "not-a-version" > "$TEST_TMPDIR/version.txt"
    touch "$TEST_TMPDIR/commits.txt"
    run bash "$BUMP_SCRIPT" "$TEST_TMPDIR/version.txt" "$TEST_TMPDIR/commits.txt"
    [ "$status" -ne 0 ]
}

# =============================================================================
# TDD CYCLE 10: Workflow structure tests
# =============================================================================

WORKFLOW_FILE="$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml"

@test "workflow file exists" {
    [ -f "$WORKFLOW_FILE" ]
}

@test "workflow has push trigger" {
    run grep -c "push:" "$WORKFLOW_FILE"
    [ "$output" -ge 1 ]
}

@test "workflow has workflow_dispatch trigger" {
    run grep -c "workflow_dispatch" "$WORKFLOW_FILE"
    [ "$output" -ge 1 ]
}

@test "workflow has at least one job" {
    run grep -c "jobs:" "$WORKFLOW_FILE"
    [ "$output" -ge 1 ]
}

@test "workflow references bump-version.sh" {
    run grep -c "bump-version.sh" "$WORKFLOW_FILE"
    [ "$output" -ge 1 ]
}

@test "workflow uses actions/checkout@v4" {
    run grep -c "actions/checkout@v4" "$WORKFLOW_FILE"
    [ "$output" -ge 1 ]
}

@test "bump-version.sh script file exists" {
    [ -f "$SCRIPT_DIR/bump-version.sh" ]
}

@test "actionlint passes on workflow file" {
    run actionlint "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
}
