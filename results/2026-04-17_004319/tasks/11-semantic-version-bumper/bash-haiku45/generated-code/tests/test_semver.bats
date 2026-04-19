#!/usr/bin/env bats

# Test suite for semantic version bumper
# Uses TDD: write failing test, implement minimum to pass, repeat

setup() {
  # Create temp directory for each test
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"

  # Initialize a git repo for testing
  git init > /dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Source the script
  source "$BATS_TEST_DIRNAME/../semver-bumper.sh"
}

teardown() {
  # Clean up temp directory
  rm -rf "$TEST_DIR"
}

# Test 1: Parse version from package.json
@test "parse_version extracts version from package.json" {
  echo '{"version":"1.0.0"}' > package.json
  result=$(parse_version "package.json")
  [ "$result" = "1.0.0" ]
}

# Test 2: Parse version from VERSION file
@test "parse_version extracts version from VERSION file" {
  echo "2.3.4" > VERSION
  result=$(parse_version "VERSION")
  [ "$result" = "2.3.4" ]
}

# Test 3: Bump patch version (fix commit)
@test "bump_version increments patch for fix commits" {
  result=$(bump_version "1.0.0" "patch")
  [ "$result" = "1.0.1" ]
}

# Test 4: Bump minor version (feat commit)
@test "bump_version increments minor for feat commits" {
  result=$(bump_version "1.2.3" "minor")
  [ "$result" = "1.3.0" ]
}

# Test 5: Bump major version (breaking change)
@test "bump_version increments major for breaking changes" {
  result=$(bump_version "2.1.5" "major")
  [ "$result" = "3.0.0" ]
}

# Test 6: Determine version bump type from commits
@test "get_bump_type returns major for BREAKING CHANGE" {
  # Create initial commit
  echo "content" > file.txt
  git add file.txt
  git commit -m "initial" > /dev/null 2>&1

  # Create breaking change commit
  echo "updated" > file.txt
  git add file.txt
  git commit -m "feat!: breaking change" > /dev/null 2>&1

  # Get the bump type
  result=$(get_bump_type "HEAD~1" "HEAD")
  [ "$result" = "major" ]
}

# Test 7: Determine version bump type - feat
@test "get_bump_type returns minor for feat commit" {
  # Create initial commit
  echo "content" > file.txt
  git add file.txt
  git commit -m "initial" > /dev/null 2>&1

  # Create feat commit
  echo "updated" > file.txt
  git add file.txt
  git commit -m "feat: new feature" > /dev/null 2>&1

  result=$(get_bump_type "HEAD~1" "HEAD")
  [ "$result" = "minor" ]
}

# Test 8: Determine version bump type - fix
@test "get_bump_type returns patch for fix commit" {
  # Create initial commit
  echo "content" > file.txt
  git add file.txt
  git commit -m "initial" > /dev/null 2>&1

  # Create fix commit
  echo "updated" > file.txt
  git add file.txt
  git commit -m "fix: bug fix" > /dev/null 2>&1

  result=$(get_bump_type "HEAD~1" "HEAD")
  [ "$result" = "patch" ]
}

# Test 9: Update version in package.json
@test "update_version modifies package.json correctly" {
  echo '{"version":"1.0.0","name":"test"}' > package.json
  update_version "package.json" "1.1.0"

  version=$(grep -o '"version":"[^"]*"' package.json | cut -d'"' -f4)
  [ "$version" = "1.1.0" ]
}

# Test 10: Update version in VERSION file
@test "update_version modifies VERSION file correctly" {
  echo "1.0.0" > VERSION
  update_version "VERSION" "2.0.0"

  version=$(cat VERSION)
  [ "$version" = "2.0.0" ]
}

# Test 11: Generate changelog entry
@test "generate_changelog_entry creates proper entry" {
  # Create initial commit
  echo "content" > file.txt
  git add file.txt
  git commit -m "initial" > /dev/null 2>&1

  # Create feat commit
  echo "updated" > file.txt
  git add file.txt
  git commit -m "feat: new feature description" > /dev/null 2>&1

  result=$(generate_changelog_entry "HEAD~1" "HEAD" "1.1.0")

  # Should contain version and feature
  [[ "$result" =~ "1.1.0" ]]
  [[ "$result" =~ "new feature description" ]]
}

# Test 12: End-to-end test
@test "main flow: parse, bump, update, changelog" {
  echo '{"version":"1.0.0","name":"myapp"}' > package.json

  # Create initial commit
  git add package.json
  git commit -m "initial" > /dev/null 2>&1

  # Create feat commit
  echo '{"version":"1.0.0","name":"myapp","description":"updated"}' > package.json
  git add package.json
  git commit -m "feat: add new feature" > /dev/null 2>&1

  # Run main flow
  new_version=$(main_flow "package.json" "HEAD~1" "HEAD")

  # Check version was bumped correctly
  [ "$new_version" = "1.1.0" ]

  # Check package.json was updated
  version=$(grep -o '"version":"[^"]*"' package.json | cut -d'"' -f4)
  [ "$version" = "1.1.0" ]
}
