#!/usr/bin/env bash

# Test fixtures for semantic version bumper
# Provides functions to create mock commit logs and test data

# Create a mock git repository with commits for testing
create_test_repo() {
  local repo_dir="$1"
  local initial_version="${2:-1.0.0}"

  mkdir -p "$repo_dir"
  cd "$repo_dir"

  git init > /dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit with package.json
  cat > package.json << EOF
{
  "name": "test-app",
  "version": "$initial_version",
  "description": "Test application"
}
EOF

  git add package.json
  git commit -m "initial: setup project" > /dev/null 2>&1
}

# Add a feature commit to the test repo
add_feature_commit() {
  local repo_dir="$1"
  local message="${2:-feat: add new feature}"

  cd "$repo_dir"
  echo "console.log('new feature');" >> src.js
  git add src.js 2>/dev/null || git add . > /dev/null 2>&1
  git commit -m "$message" > /dev/null 2>&1
}

# Add a fix commit to the test repo
add_fix_commit() {
  local repo_dir="$1"
  local message="${2:-fix: resolve bug}"

  cd "$repo_dir"
  echo "// fixed" >> src.js
  git add src.js 2>/dev/null || git add . > /dev/null 2>&1
  git commit -m "$message" > /dev/null 2>&1
}

# Add a breaking change commit
add_breaking_commit() {
  local repo_dir="$1"
  local message="${2:-feat!: breaking change}"

  cd "$repo_dir"
  echo "// breaking change" >> src.js
  git add src.js 2>/dev/null || git add . > /dev/null 2>&1
  git commit -m "$message" > /dev/null 2>&1
}

# Create fixture: simple patch bump (1.0.0 -> 1.0.1)
fixture_patch_bump() {
  local tmpdir="$1"
  create_test_repo "$tmpdir" "1.0.0"
  add_fix_commit "$tmpdir" "fix: correct typo in docs"
  echo "patch"
}

# Create fixture: minor version bump (1.0.0 -> 1.1.0)
fixture_minor_bump() {
  local tmpdir="$1"
  create_test_repo "$tmpdir" "1.0.0"
  add_feature_commit "$tmpdir" "feat: add new API endpoint"
  echo "minor"
}

# Create fixture: major version bump (1.0.0 -> 2.0.0)
fixture_major_bump() {
  local tmpdir="$1"
  create_test_repo "$tmpdir" "1.0.0"
  add_breaking_commit "$tmpdir" "feat!: redesign database schema"
  echo "major"
}

# Create fixture: multiple commits (mix of features and fixes)
fixture_multiple_commits() {
  local tmpdir="$1"
  create_test_repo "$tmpdir" "2.1.3"
  add_fix_commit "$tmpdir" "fix: handle edge case in parser"
  add_feature_commit "$tmpdir" "feat: support new file formats"
  add_fix_commit "$tmpdir" "fix: improve error messages"
  echo "minor"
}

# Create fixture: complex scenario with breaking change
fixture_complex_changelog() {
  local tmpdir="$1"
  create_test_repo "$tmpdir" "1.5.2"
  add_fix_commit "$tmpdir" "fix: memory leak in event handler"
  add_feature_commit "$tmpdir" "feat(api): add pagination support"
  add_feature_commit "$tmpdir" "feat(cli): improve command output"
  add_breaking_commit "$tmpdir "feat!: remove deprecated methods"
  echo "major"
}

export -f create_test_repo
export -f add_feature_commit
export -f add_fix_commit
export -f add_breaking_commit
export -f fixture_patch_bump
export -f fixture_minor_bump
export -f fixture_major_bump
export -f fixture_multiple_commits
export -f fixture_complex_changelog
