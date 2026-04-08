#!/usr/bin/env bats

# Test suite for semantic version bumper
# Uses red/green TDD: each test group was written before its implementation.

SCRIPT="$BATS_TEST_DIRNAME/../semver_bumper.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

setup() {
    # Create a temporary directory for each test
    export TMPDIR
    TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMPDIR"
}

# Helper: source just the functions from the script without running main
load_functions() {
    # Source the script in "library mode" by setting SEMVER_LIB=1
    export SEMVER_LIB=1
    # shellcheck source=../semver_bumper.sh
    source "$SCRIPT"
}

# =============================================================================
# ROUND 1: Version parsing
# =============================================================================

@test "parse_version: reads version from a VERSION file" {
    load_functions
    echo "1.2.3" > "$TMPDIR/VERSION"
    run parse_version "$TMPDIR/VERSION"
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

@test "parse_version: reads version from a package.json file" {
    load_functions
    cat > "$TMPDIR/package.json" <<'JSON'
{
  "name": "my-app",
  "version": "2.5.0",
  "description": "test"
}
JSON
    run parse_version "$TMPDIR/package.json"
    [ "$status" -eq 0 ]
    [ "$output" = "2.5.0" ]
}

@test "parse_version: fails on missing file" {
    load_functions
    run parse_version "$TMPDIR/nonexistent"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "parse_version: fails on invalid semver in VERSION file" {
    load_functions
    echo "not-a-version" > "$TMPDIR/VERSION"
    run parse_version "$TMPDIR/VERSION"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid"* ]] || [[ "$output" == *"Invalid"* ]]
}

@test "parse_version: handles version with v prefix" {
    load_functions
    echo "v3.1.4" > "$TMPDIR/VERSION"
    run parse_version "$TMPDIR/VERSION"
    [ "$status" -eq 0 ]
    [ "$output" = "3.1.4" ]
}

# =============================================================================
# ROUND 2: Commit classification
# =============================================================================

@test "classify_commits: patch-only commits produce 'patch'" {
    load_functions
    run classify_commits "$FIXTURES/commits_patch.log"
    [ "$status" -eq 0 ]
    [ "$output" = "patch" ]
}

@test "classify_commits: feat commits produce 'minor'" {
    load_functions
    run classify_commits "$FIXTURES/commits_minor.log"
    [ "$status" -eq 0 ]
    [ "$output" = "minor" ]
}

@test "classify_commits: breaking change commits produce 'major'" {
    load_functions
    run classify_commits "$FIXTURES/commits_major.log"
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "classify_commits: BREAKING CHANGE footer produces 'major'" {
    load_functions
    run classify_commits "$FIXTURES/commits_breaking_footer.log"
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "classify_commits: no feat/fix commits produce 'patch' as default" {
    load_functions
    run classify_commits "$FIXTURES/commits_empty.log"
    [ "$status" -eq 0 ]
    [ "$output" = "patch" ]
}

@test "classify_commits: fails on missing commit log" {
    load_functions
    run classify_commits "$TMPDIR/nonexistent.log"
    [ "$status" -ne 0 ]
}

# =============================================================================
# ROUND 3: Version bumping
# =============================================================================

@test "bump_version: patch bump 1.2.3 -> 1.2.4" {
    load_functions
    run bump_version "1.2.3" "patch"
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.4" ]
}

@test "bump_version: minor bump 1.2.3 -> 1.3.0" {
    load_functions
    run bump_version "1.2.3" "minor"
    [ "$status" -eq 0 ]
    [ "$output" = "1.3.0" ]
}

@test "bump_version: major bump 1.2.3 -> 2.0.0" {
    load_functions
    run bump_version "1.2.3" "major"
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "bump_version: patch bump from 0.0.0 -> 0.0.1" {
    load_functions
    run bump_version "0.0.0" "patch"
    [ "$status" -eq 0 ]
    [ "$output" = "0.0.1" ]
}

@test "bump_version: major bump from 0.9.9 -> 1.0.0" {
    load_functions
    run bump_version "0.9.9" "major"
    [ "$status" -eq 0 ]
    [ "$output" = "1.0.0" ]
}

@test "bump_version: fails on invalid bump type" {
    load_functions
    run bump_version "1.0.0" "invalid"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid bump type"* ]]
}

# =============================================================================
# ROUND 4: Changelog generation
# =============================================================================

@test "generate_changelog: includes version header" {
    load_functions
    run generate_changelog "2.0.0" "$FIXTURES/commits_major.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## 2.0.0"* ]]
}

@test "generate_changelog: groups breaking changes" {
    load_functions
    run generate_changelog "2.0.0" "$FIXTURES/commits_major.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Breaking Changes"* ]]
}

@test "generate_changelog: groups features" {
    load_functions
    run generate_changelog "1.3.0" "$FIXTURES/commits_minor.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Features"* ]]
}

@test "generate_changelog: groups fixes" {
    load_functions
    run generate_changelog "1.2.4" "$FIXTURES/commits_patch.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bug Fixes"* ]]
}

@test "generate_changelog: includes commit messages" {
    load_functions
    run generate_changelog "1.2.4" "$FIXTURES/commits_patch.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"correct off-by-one error in pagination"* ]]
}

# =============================================================================
# ROUND 5: Version file update
# =============================================================================

@test "update_version_file: updates VERSION file" {
    load_functions
    echo "1.0.0" > "$TMPDIR/VERSION"
    run update_version_file "$TMPDIR/VERSION" "1.1.0"
    [ "$status" -eq 0 ]
    [ "$(cat "$TMPDIR/VERSION")" = "1.1.0" ]
}

@test "update_version_file: updates package.json version field" {
    load_functions
    cat > "$TMPDIR/package.json" <<'JSON'
{
  "name": "my-app",
  "version": "1.0.0",
  "description": "test"
}
JSON
    run update_version_file "$TMPDIR/package.json" "1.1.0"
    [ "$status" -eq 0 ]
    # Verify the version was updated
    local new_ver
    new_ver=$(grep '"version"' "$TMPDIR/package.json" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    [ "$new_ver" = "1.1.0" ]
}

# =============================================================================
# ROUND 6: End-to-end integration
# =============================================================================

@test "integration: full bump from VERSION file with minor commits" {
    echo "1.0.0" > "$TMPDIR/VERSION"
    run "$SCRIPT" --version-file "$TMPDIR/VERSION" --commits "$FIXTURES/commits_minor.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.1.0"* ]]
    [ "$(cat "$TMPDIR/VERSION")" = "1.1.0" ]
}

@test "integration: full bump from package.json with patch commits" {
    cat > "$TMPDIR/package.json" <<'JSON'
{
  "name": "test",
  "version": "3.2.1"
}
JSON
    run "$SCRIPT" --version-file "$TMPDIR/package.json" --commits "$FIXTURES/commits_patch.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.2.2"* ]]
}

@test "integration: full bump with major (breaking) commits" {
    echo "1.5.3" > "$TMPDIR/VERSION"
    run "$SCRIPT" --version-file "$TMPDIR/VERSION" --commits "$FIXTURES/commits_major.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2.0.0"* ]]
    [ "$(cat "$TMPDIR/VERSION")" = "2.0.0" ]
}

@test "integration: changelog file is created" {
    echo "1.0.0" > "$TMPDIR/VERSION"
    run "$SCRIPT" --version-file "$TMPDIR/VERSION" --commits "$FIXTURES/commits_minor.log" --changelog "$TMPDIR/CHANGELOG.md"
    [ "$status" -eq 0 ]
    [ -f "$TMPDIR/CHANGELOG.md" ]
    [[ "$(cat "$TMPDIR/CHANGELOG.md")" == *"## 1.1.0"* ]]
}

@test "integration: --dry-run does not modify files" {
    echo "1.0.0" > "$TMPDIR/VERSION"
    run "$SCRIPT" --version-file "$TMPDIR/VERSION" --commits "$FIXTURES/commits_minor.log" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.1.0"* ]]
    # File should remain unchanged
    [ "$(cat "$TMPDIR/VERSION")" = "1.0.0" ]
}

@test "integration: fails without required arguments" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"--version-file"* ]]
}

@test "integration: reads commits from git log when --commits not provided" {
    # Set up a temporary git repo
    cd "$TMPDIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "0.1.0" > VERSION
    git add VERSION
    git commit -q -m "initial commit"
    git commit -q --allow-empty -m "feat: add new feature"
    git commit -q --allow-empty -m "fix: fix a bug"

    run "$SCRIPT" --version-file "$TMPDIR/VERSION"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0.2.0"* ]]
}

# =============================================================================
# ROUND 7: GitHub Actions workflow validation
# =============================================================================

@test "workflow: YAML file exists" {
    [ -f "$BATS_TEST_DIRNAME/../.github/workflows/semantic-version-bumper.yml" ]
}

@test "workflow: has required trigger events" {
    local workflow="$BATS_TEST_DIRNAME/../.github/workflows/semantic-version-bumper.yml"
    grep -q "push:" "$workflow"
    grep -q "workflow_dispatch:" "$workflow"
}

@test "workflow: references semver_bumper.sh script" {
    local workflow="$BATS_TEST_DIRNAME/../.github/workflows/semantic-version-bumper.yml"
    grep -q "semver_bumper.sh" "$workflow"
}

@test "workflow: script files referenced in workflow exist" {
    local workflow="$BATS_TEST_DIRNAME/../.github/workflows/semantic-version-bumper.yml"
    # Extract script references and check they exist relative to repo root
    local repo_root="$BATS_TEST_DIRNAME/.."
    # The workflow should reference semver_bumper.sh
    [ -f "$repo_root/semver_bumper.sh" ]
}

@test "workflow: uses actions/checkout@v4" {
    local workflow="$BATS_TEST_DIRNAME/../.github/workflows/semantic-version-bumper.yml"
    grep -q "actions/checkout@v4" "$workflow"
}

@test "workflow: has jobs defined" {
    local workflow="$BATS_TEST_DIRNAME/../.github/workflows/semantic-version-bumper.yml"
    grep -q "^jobs:" "$workflow"
}

@test "workflow: passes actionlint validation" {
    run actionlint "$BATS_TEST_DIRNAME/../.github/workflows/semantic-version-bumper.yml"
    echo "actionlint output: $output"
    [ "$status" -eq 0 ]
}

@test "workflow: has environment variables or outputs for version" {
    local workflow="$BATS_TEST_DIRNAME/../.github/workflows/semantic-version-bumper.yml"
    grep -q "new_version" "$workflow"
}
