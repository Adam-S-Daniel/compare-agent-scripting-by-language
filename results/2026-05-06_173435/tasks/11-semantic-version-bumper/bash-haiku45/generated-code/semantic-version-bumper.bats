#!/usr/bin/env bats

# Semantic Version Bumper Tests
# Tests the core functionality of determining next version from conventional commits

setup() {
    # Get the directory where the test file is located
    export BUMPER_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILE")" && pwd)/semantic-version-bumper.sh"
    # Create a test workspace for this specific test
    export TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Helper: Create a git repo with commits
create_git_repo() {
    local initial_version="$1"

    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial package.json with version
    cat > package.json <<EOF
{
  "name": "test-project",
  "version": "$initial_version"
}
EOF

    git add package.json
    git commit -m "Initial commit" >/dev/null 2>&1
}

# Helper: Add a commit with a specific type
add_commit() {
    local type="$1"
    local message="$2"

    echo "change" >> test.txt
    git add test.txt
    git commit -m "$type: $message" >/dev/null 2>&1
}

# Test 1: Parse version from package.json
@test "parse_version extracts version from package.json" {
    cat > package.json <<'EOF'
{
  "name": "test-project",
  "version": "1.2.3"
}
EOF

    result=$("$BUMPER_SCRIPT" --parse-version package.json)
    [ "$result" = "1.2.3" ]
}

# Test 2: Parse version from VERSION file
@test "parse_version extracts version from VERSION file" {
    echo "2.0.1" > VERSION

    result=$("$BUMPER_SCRIPT" --parse-version VERSION)
    [ "$result" = "2.0.1" ]
}

# Test 3: Determine next version for patch bump
@test "determine_next_version bumps patch for fix commit" {
    create_git_repo "1.0.0"
    add_commit "fix" "minor bug fix"

    result=$("$BUMPER_SCRIPT" --determine-next-version "1.0.0")
    [ "$result" = "1.0.1" ]
}

# Test 4: Determine next version for minor bump
@test "determine_next_version bumps minor for feat commit" {
    create_git_repo "1.0.0"
    add_commit "feat" "new feature"

    result=$("$BUMPER_SCRIPT" --determine-next-version "1.0.0")
    [ "$result" = "1.1.0" ]
}

# Test 5: Determine next version for major bump
@test "determine_next_version bumps major for breaking change" {
    create_git_repo "1.0.0"
    add_commit "feat" "breaking change"$'\n\nBREAKING CHANGE: API changed'

    result=$("$BUMPER_SCRIPT" --determine-next-version "1.0.0")
    [ "$result" = "2.0.0" ]
}

# Test 6: Highest bump wins when multiple commit types present
@test "determine_next_version chooses highest bump (feat + fix)" {
    create_git_repo "1.0.0"
    add_commit "fix" "bug fix"
    add_commit "feat" "new feature"

    result=$("$BUMPER_SCRIPT" --determine-next-version "1.0.0")
    [ "$result" = "1.1.0" ]
}

# Test 7: Major wins over minor and patch
@test "determine_next_version chooses highest bump (breaking + feat + fix)" {
    create_git_repo "1.0.0"
    add_commit "fix" "bug fix"
    add_commit "feat" "breaking change"$'\n\nBREAKING CHANGE: API changed'
    add_commit "fix" "another fix"

    result=$("$BUMPER_SCRIPT" --determine-next-version "1.0.0")
    [ "$result" = "2.0.0" ]
}

# Test 8: No commits returns same version
@test "determine_next_version returns same version with no new commits" {
    create_git_repo "1.5.2"

    # Don't add any commits, just check without new changes
    # Use a tag to mark where we started
    git tag v1.5.2 >/dev/null 2>&1

    result=$("$BUMPER_SCRIPT" --determine-next-version "1.5.2")
    [ "$result" = "1.5.2" ]
}

# Test 9: Update version in package.json
@test "update_version modifies package.json correctly" {
    cat > package.json <<'EOF'
{
  "name": "test-project",
  "version": "1.0.0"
}
EOF

    "$BUMPER_SCRIPT" --update-version package.json 1.1.0

    result=$(grep '"version"' package.json | grep -o '[0-9.]*[0-9]')
    [ "$result" = "1.1.0" ]
}

# Test 10: Update version in VERSION file
@test "update_version modifies VERSION file correctly" {
    echo "1.0.0" > VERSION

    "$BUMPER_SCRIPT" --update-version VERSION 2.0.0

    result=$(cat VERSION)
    [ "$result" = "2.0.0" ]
}

# Test 11: Generate changelog entry
@test "generate_changelog creates changelog with commits" {
    create_git_repo "1.0.0"
    add_commit "feat" "awesome new feature"
    add_commit "fix" "critical bug fix"

    result=$("$BUMPER_SCRIPT" --generate-changelog "1.0.0" "1.1.0")

    [[ "$result" == *"1.1.0"* ]]
    [[ "$result" == *"feat"* ]] || [[ "$result" == *"Feature"* ]]
    [[ "$result" == *"fix"* ]] || [[ "$result" == *"Fix"* ]]
}

# Test 12: Full workflow - parse, determine, update, generate
@test "full workflow bumps version and generates changelog" {
    create_git_repo "1.2.3"
    add_commit "feat" "new capability"

    # Simulate the full workflow
    current_version=$("$BUMPER_SCRIPT" --parse-version package.json)
    next_version=$("$BUMPER_SCRIPT" --determine-next-version "$current_version")
    "$BUMPER_SCRIPT" --update-version package.json "$next_version"
    changelog=$("$BUMPER_SCRIPT" --generate-changelog "$current_version" "$next_version")

    [ "$current_version" = "1.2.3" ]
    [ "$next_version" = "1.3.0" ]
    grep -q '"version": "1.3.0"' package.json
    [[ "$changelog" == *"1.3.0"* ]]
}

# Test 13: Error handling - missing file
@test "parse_version fails gracefully with missing file" {
    run "$BUMPER_SCRIPT" --parse-version nonexistent.json
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"not found"* ]]
}

# Test 14: Error handling - invalid JSON
@test "parse_version fails gracefully with invalid JSON" {
    echo "{invalid json}" > package.json

    run "$BUMPER_SCRIPT" --parse-version package.json
    [ "$status" -ne 0 ]
}

# Test 15: Correctly identify commit types from git log
@test "commit analysis correctly identifies feat commits" {
    create_git_repo "0.0.1"
    add_commit "feat" "new feature"

    next_version=$("$BUMPER_SCRIPT" --determine-next-version "0.0.1")
    [ "$next_version" = "0.1.0" ]
}

# Test 16: Correctly identify commit types from git log
@test "commit analysis correctly identifies fix commits" {
    create_git_repo "0.0.1"
    add_commit "fix" "bug fix"

    next_version=$("$BUMPER_SCRIPT" --determine-next-version "0.0.1")
    [ "$next_version" = "0.0.2" ]
}

# Test 17: Chore commits don't trigger version bump
@test "chore commits don't affect version" {
    create_git_repo "1.0.0"
    add_commit "chore" "update dependencies"

    next_version=$("$BUMPER_SCRIPT" --determine-next-version "1.0.0")
    [ "$next_version" = "1.0.0" ]
}

# Test 18: Docs commits don't trigger version bump
@test "docs commits don't affect version" {
    create_git_repo "1.0.0"
    add_commit "docs" "update readme"

    next_version=$("$BUMPER_SCRIPT" --determine-next-version "1.0.0")
    [ "$next_version" = "1.0.0" ]
}

# Test 19: Version file in different locations
@test "works with VERSION file instead of package.json" {
    echo "3.2.1" > VERSION

    parsed=$("$BUMPER_SCRIPT" --parse-version VERSION)
    [ "$parsed" = "3.2.1" ]

    "$BUMPER_SCRIPT" --update-version VERSION 3.3.0

    updated=$(cat VERSION)
    [ "$updated" = "3.3.0" ]
}

# Test 20: Complex version scenarios
@test "handles zero versions correctly" {
    cat > package.json <<'EOF'
{
  "name": "test-project",
  "version": "0.0.0"
}
EOF

    result=$("$BUMPER_SCRIPT" --parse-version package.json)
    [ "$result" = "0.0.0" ]
}
