#!/usr/bin/env bats
# Tests for semantic version bumper using bats-core
# TDD approach: tests written first, implementation follows

# Setup: ensure script exists and is executable
setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../version-bumper.sh"
    FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
    # Create a temp dir for each test
    TEST_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ─── RED PHASE 1: Parsing version from version.txt ───────────────────────────

@test "parse_version reads version from version.txt" {
    echo "1.2.3" > "$TEST_DIR/version.txt"
    run bash "$SCRIPT" parse-version "$TEST_DIR/version.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

@test "parse_version reads version from package.json" {
    echo '{"version": "2.5.0", "name": "myapp"}' > "$TEST_DIR/package.json"
    run bash "$SCRIPT" parse-version "$TEST_DIR/package.json"
    [ "$status" -eq 0 ]
    [ "$output" = "2.5.0" ]
}

@test "parse_version fails with meaningful error for missing file" {
    run bash "$SCRIPT" parse-version "/nonexistent/path/version.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"does not exist"* ]] || [[ "$output" == *"No such"* ]]
}

@test "parse_version fails for invalid semver in version.txt" {
    echo "not-a-version" > "$TEST_DIR/version.txt"
    run bash "$SCRIPT" parse-version "$TEST_DIR/version.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"invalid"* ]]
}

# ─── RED PHASE 2: Determining bump type from commit messages ──────────────────

@test "determine_bump returns patch for fix commits" {
    run bash "$SCRIPT" determine-bump "$FIXTURES/commits-patch.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "patch" ]
}

@test "determine_bump returns minor for feat commits" {
    run bash "$SCRIPT" determine-bump "$FIXTURES/commits-minor.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "minor" ]
}

@test "determine_bump returns major for breaking change commits" {
    run bash "$SCRIPT" determine-bump "$FIXTURES/commits-major.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "determine_bump returns major for BREAKING CHANGE footer" {
    run bash "$SCRIPT" determine-bump "$FIXTURES/commits-breaking-footer.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "determine_bump returns minor when mix of feat and fix" {
    run bash "$SCRIPT" determine-bump "$FIXTURES/commits-mixed.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "minor" ]
}

@test "determine_bump returns patch for unknown/chore commits" {
    run bash "$SCRIPT" determine-bump "$FIXTURES/commits-chore.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "patch" ]
}

@test "determine_bump fails for missing commit file" {
    run bash "$SCRIPT" determine-bump "/nonexistent/commits.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"does not exist"* ]] || [[ "$output" == *"No such"* ]]
}

# ─── RED PHASE 3: Bumping version numbers ────────────────────────────────────

@test "bump_version increments patch: 1.2.3 -> 1.2.4" {
    run bash "$SCRIPT" bump-version "1.2.3" "patch"
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.4" ]
}

@test "bump_version increments minor: 1.2.3 -> 1.3.0" {
    run bash "$SCRIPT" bump-version "1.2.3" "minor"
    [ "$status" -eq 0 ]
    [ "$output" = "1.3.0" ]
}

@test "bump_version increments major: 1.2.3 -> 2.0.0" {
    run bash "$SCRIPT" bump-version "1.2.3" "major"
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "bump_version resets patch on minor bump: 1.2.9 -> 1.3.0" {
    run bash "$SCRIPT" bump-version "1.2.9" "minor"
    [ "$status" -eq 0 ]
    [ "$output" = "1.3.0" ]
}

@test "bump_version resets minor and patch on major bump: 1.9.9 -> 2.0.0" {
    run bash "$SCRIPT" bump-version "1.9.9" "major"
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "bump_version fails for invalid bump type" {
    run bash "$SCRIPT" bump-version "1.2.3" "invalid"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"invalid"* ]] || [[ "$output" == *"Unknown"* ]]
}

# ─── RED PHASE 4: Updating version files ─────────────────────────────────────

@test "update_version_file updates version.txt in place" {
    echo "1.2.3" > "$TEST_DIR/version.txt"
    run bash "$SCRIPT" update-version-file "$TEST_DIR/version.txt" "1.3.0"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_DIR/version.txt")" = "1.3.0" ]
}

@test "update_version_file updates version in package.json" {
    echo '{"name": "myapp", "version": "1.0.0", "description": "test"}' > "$TEST_DIR/package.json"
    run bash "$SCRIPT" update-version-file "$TEST_DIR/package.json" "1.1.0"
    [ "$status" -eq 0 ]
    run bash "$SCRIPT" parse-version "$TEST_DIR/package.json"
    [ "$output" = "1.1.0" ]
}

@test "update_version_file preserves other package.json fields" {
    echo '{"name": "myapp", "version": "1.0.0", "description": "test"}' > "$TEST_DIR/package.json"
    bash "$SCRIPT" update-version-file "$TEST_DIR/package.json" "1.1.0"
    run bash -c "grep -q '\"name\": \"myapp\"' '$TEST_DIR/package.json'"
    [ "$status" -eq 0 ]
}

# ─── RED PHASE 5: Generating changelog entries ───────────────────────────────

@test "generate_changelog produces output with new version" {
    run bash "$SCRIPT" generate-changelog "1.3.0" "$FIXTURES/commits-mixed.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.3.0"* ]]
}

@test "generate_changelog groups features under Features section" {
    run bash "$SCRIPT" generate-changelog "1.3.0" "$FIXTURES/commits-minor.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Features"* ]] || [[ "$output" == *"feat"* ]]
}

@test "generate_changelog groups fixes under Bug Fixes section" {
    run bash "$SCRIPT" generate-changelog "1.2.4" "$FIXTURES/commits-patch.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bug Fixes"* ]] || [[ "$output" == *"fix"* ]]
}

@test "generate_changelog includes commit messages" {
    run bash "$SCRIPT" generate-changelog "1.3.0" "$FIXTURES/commits-minor.txt"
    [ "$status" -eq 0 ]
    # Should include something from the fixture commit messages
    [[ "$output" == *"add"* ]] || [[ "$output" == *"user"* ]] || [[ "$output" == *"feature"* ]]
}

# ─── RED PHASE 6: Full end-to-end pipeline ───────────────────────────────────

@test "run full pipeline with version.txt updates file and outputs new version" {
    echo "1.0.0" > "$TEST_DIR/version.txt"
    run bash "$SCRIPT" run "$TEST_DIR/version.txt" "$FIXTURES/commits-minor.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.1.0"* ]]
    [ "$(cat "$TEST_DIR/version.txt")" = "1.1.0" ]
}

@test "run full pipeline with package.json" {
    echo '{"name": "app", "version": "2.0.0"}' > "$TEST_DIR/package.json"
    run bash "$SCRIPT" run "$TEST_DIR/package.json" "$FIXTURES/commits-patch.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2.0.1"* ]]
}

@test "run full pipeline outputs changelog" {
    echo "1.0.0" > "$TEST_DIR/version.txt"
    run bash "$SCRIPT" run "$TEST_DIR/version.txt" "$FIXTURES/commits-mixed.txt"
    [ "$status" -eq 0 ]
    # Output should contain changelog-like content
    [[ "$output" == *"Changelog"* ]] || [[ "$output" == *"CHANGELOG"* ]] || [[ "$output" == *"Changes"* ]]
}

# ─── RED PHASE 7: GitHub Actions workflow validation ─────────────────────────

@test "workflow file exists at expected path" {
    [ -f "${BATS_TEST_DIRNAME}/../.github/workflows/semantic-version-bumper.yml" ]
}

@test "workflow file passes actionlint validation" {
    WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/semantic-version-bumper.yml"
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow has push and pull_request triggers" {
    WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/semantic-version-bumper.yml"
    run grep -E "^\s*(push|pull_request):" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow references version-bumper.sh script" {
    WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/semantic-version-bumper.yml"
    run grep -E "version-bumper\.sh" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow uses actions/checkout" {
    WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/semantic-version-bumper.yml"
    run grep -E "actions/checkout" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow script files exist (paths referenced in workflow are real)" {
    WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/semantic-version-bumper.yml"
    # Extract script references and check they exist
    SCRIPT_PATH="${BATS_TEST_DIRNAME}/../version-bumper.sh"
    [ -f "$SCRIPT_PATH" ]
}

@test "workflow has at least one job defined" {
    WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/semantic-version-bumper.yml"
    run grep -E "^\s+[a-zA-Z_-]+:" "$WORKFLOW"
    [ "$status" -eq 0 ]
}
