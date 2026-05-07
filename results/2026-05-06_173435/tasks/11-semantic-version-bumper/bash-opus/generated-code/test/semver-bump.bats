#!/usr/bin/env bats

# Tests for semver-bump.sh — semantic version bumper based on conventional commits

SCRIPT="$BATS_TEST_DIRNAME/../semver-bump.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

setup() {
  WORK_DIR="$(mktemp -d)"
  cd "$WORK_DIR" || return 1
}

teardown() {
  rm -rf "$WORK_DIR"
}

# --- Version parsing from VERSION file ---

@test "parse version from VERSION file" {
  echo "1.2.3" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.4"* ]]
}

@test "parse version from package.json" {
  cat > package.json <<'JSON'
{
  "name": "test-pkg",
  "version": "2.0.0"
}
JSON
  run bash "$SCRIPT" --version-file package.json --commit-log "$FIXTURES/commits-feat.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2.1.0"* ]]
}

# --- Bump type detection ---

@test "fix commits produce patch bump" {
  echo "1.0.0" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.0.1"* ]]
}

@test "feat commits produce minor bump" {
  echo "1.0.0" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-feat.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.1.0"* ]]
}

@test "breaking change (bang) produces major bump" {
  echo "1.0.0" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-breaking.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2.0.0"* ]]
}

@test "BREAKING CHANGE footer produces major bump" {
  echo "0.9.0" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-breaking-footer.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.0.0"* ]]
}

@test "mixed commits use highest bump (feat > fix = minor)" {
  echo "1.1.0" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-mixed.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.0"* ]]
}

@test "no conventional commits defaults to patch" {
  echo "3.0.0" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-none.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3.0.1"* ]]
}

# --- Version file update ---

@test "VERSION file is updated in place" {
  echo "1.0.0" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-feat.txt"
  [ "$status" -eq 0 ]
  [ "$(cat VERSION)" = "1.1.0" ]
}

@test "package.json version field is updated" {
  cat > package.json <<'JSON'
{
  "name": "my-app",
  "version": "0.5.0",
  "description": "test"
}
JSON
  run bash "$SCRIPT" --version-file package.json --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -eq 0 ]
  run grep '"version"' package.json
  [[ "$output" == *'"0.5.1"'* ]]
}

# --- Changelog generation ---

@test "changelog file is created with entries" {
  echo "1.0.0" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-feat.txt" --changelog CHANGELOG.md
  [ "$status" -eq 0 ]
  [ -f CHANGELOG.md ]
  run cat CHANGELOG.md
  [[ "$output" == *"1.1.0"* ]]
  [[ "$output" == *"add user profile endpoint"* ]]
  [[ "$output" == *"implement dark mode toggle"* ]]
}

@test "changelog groups entries by type" {
  echo "1.0.0" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-mixed.txt" --changelog CHANGELOG.md
  [ "$status" -eq 0 ]
  run cat CHANGELOG.md
  [[ "$output" == *"Features"* ]]
  [[ "$output" == *"Bug Fixes"* ]]
}

# --- Error handling ---

@test "missing version file produces error" {
  run bash "$SCRIPT" --version-file nonexistent.txt --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "missing commit log produces error" {
  echo "1.0.0" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log nonexistent.txt
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "invalid version string produces error" {
  echo "not-a-version" > VERSION
  run bash "$SCRIPT" --version-file VERSION --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid"* ]]
}

@test "empty commit log defaults to patch bump" {
  echo "1.0.0" > VERSION
  touch empty-commits.txt
  run bash "$SCRIPT" --version-file VERSION --commit-log empty-commits.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.0.1"* ]]
}
