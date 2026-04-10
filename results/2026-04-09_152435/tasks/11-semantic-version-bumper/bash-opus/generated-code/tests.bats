#!/usr/bin/env bats
# tests.bats — TDD tests for semver-bump.sh
#
# Tests cover:
#   1. Version parsing from VERSION file and package.json
#   2. Bump type determination from conventional commits
#   3. Version arithmetic (major/minor/patch bumps)
#   4. Changelog generation
#   5. Error handling (missing files, invalid versions)
#   6. End-to-end integration with git repos

SCRIPT="$BATS_TEST_DIRNAME/semver-bump.sh"
FIXTURES="$BATS_TEST_DIRNAME/test/fixtures"

setup() {
  # Create a temp directory for each test
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ---------- VERSION PARSING ----------

@test "parse version from VERSION file" {
  echo "1.2.3" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.4"* ]]
}

@test "parse version from package.json" {
  cat > "$TEST_TMPDIR/package.json" <<'EOF'
{
  "name": "my-app",
  "version": "3.1.0",
  "description": "test"
}
EOF
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/package.json" --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3.1.1"* ]]
}

@test "error on missing version file" {
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/nonexistent" --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"does not exist"* ]]
}

@test "error on invalid version in VERSION file" {
  echo "not-a-version" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid"* ]] || [[ "$output" == *"Invalid"* ]]
}

# ---------- BUMP TYPE DETERMINATION ----------

@test "feat commits trigger minor bump" {
  echo "1.0.0" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-feat.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.1.0"* ]]
}

@test "fix-only commits trigger patch bump" {
  echo "2.3.1" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2.3.2"* ]]
}

@test "breaking change with bang triggers major bump" {
  echo "0.5.3" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-breaking.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.0.0"* ]]
}

@test "BREAKING CHANGE footer triggers major bump" {
  echo "1.4.2" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-breaking-footer.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2.0.0"* ]]
}

@test "mixed commits use highest priority bump (feat > fix)" {
  echo "1.0.0" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-mixed.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.1.0"* ]]
}

@test "no bumpable commits exits with message" {
  echo "1.0.0" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-none.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no bump"* ]] || [[ "$output" == *"No bump"* ]]
}

# ---------- VERSION ARITHMETIC ----------

@test "patch bump increments patch" {
  echo "1.0.0" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-fix.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.0.1"* ]]
}

@test "minor bump resets patch to 0" {
  echo "1.2.5" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-feat.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.3.0"* ]]
}

@test "major bump resets minor and patch to 0" {
  echo "2.7.3" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-breaking.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3.0.0"* ]]
}

# ---------- VERSION FILE UPDATE ----------

@test "VERSION file is updated with new version" {
  echo "1.0.0" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-feat.txt"
  [ "$status" -eq 0 ]
  result="$(cat "$TEST_TMPDIR/VERSION")"
  [ "$result" = "1.1.0" ]
}

@test "package.json is updated with new version" {
  cat > "$TEST_TMPDIR/package.json" <<'EOF'
{
  "name": "my-app",
  "version": "2.0.0",
  "description": "test"
}
EOF
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/package.json" --commit-log "$FIXTURES/commits-feat.txt"
  [ "$status" -eq 0 ]
  # Verify version was updated in file
  grep -q '"version": "2.1.0"' "$TEST_TMPDIR/package.json"
}

# ---------- CHANGELOG GENERATION ----------

@test "changelog entry is generated" {
  echo "1.0.0" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-feat.txt" --changelog "$TEST_TMPDIR/CHANGELOG.md"
  [ "$status" -eq 0 ]
  [ -f "$TEST_TMPDIR/CHANGELOG.md" ]
  grep -q "1.1.0" "$TEST_TMPDIR/CHANGELOG.md"
}

@test "changelog contains commit descriptions" {
  echo "1.0.0" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-feat.txt" --changelog "$TEST_TMPDIR/CHANGELOG.md"
  [ "$status" -eq 0 ]
  grep -q "add user authentication module" "$TEST_TMPDIR/CHANGELOG.md"
  grep -q "implement search functionality" "$TEST_TMPDIR/CHANGELOG.md"
}

@test "changelog groups entries by type" {
  echo "1.0.0" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$FIXTURES/commits-mixed.txt" --changelog "$TEST_TMPDIR/CHANGELOG.md"
  [ "$status" -eq 0 ]
  grep -q "Features" "$TEST_TMPDIR/CHANGELOG.md"
  grep -q "Bug Fixes" "$TEST_TMPDIR/CHANGELOG.md"
}

# ---------- GIT INTEGRATION ----------

@test "reads commits from git log when no commit-log file given" {
  # Set up a real git repo with conventional commits
  cd "$TEST_TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "1.0.0" > VERSION
  git add VERSION
  git commit -q -m "chore: initial commit"
  git tag v1.0.0
  echo "code" > app.sh
  git add app.sh
  git commit -q -m "feat: add application entry point"
  echo "more code" >> app.sh
  git add app.sh
  git commit -q -m "fix: handle edge case in startup"

  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.1.0"* ]]
}

@test "error on missing commit log file" {
  echo "1.0.0" > "$TEST_TMPDIR/VERSION"
  run bash "$SCRIPT" --version-file "$TEST_TMPDIR/VERSION" --commit-log "$TEST_TMPDIR/nonexistent-commits.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"does not exist"* ]]
}
