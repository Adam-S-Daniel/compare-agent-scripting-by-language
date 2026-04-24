#!/usr/bin/env bats
# Tests for the semantic version bumper.
# Each test creates an isolated temp dir with fixtures so cases don't leak state.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../bump-version.sh"
  TMPDIR_TEST="$(mktemp -d)"
  cd "$TMPDIR_TEST" || exit 1
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ---- read_version --------------------------------------------------------

@test "read_version reads from a plain VERSION file" {
  echo "1.2.3" > VERSION
  run "$SCRIPT" --read VERSION
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "read_version reads from package.json" {
  cat > package.json <<'JSON'
{
  "name": "demo",
  "version": "0.5.7",
  "private": true
}
JSON
  run "$SCRIPT" --read package.json
  [ "$status" -eq 0 ]
  [ "$output" = "0.5.7" ]
}

@test "read_version errors on missing file" {
  run "$SCRIPT" --read no-such.txt
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "read_version errors on invalid version" {
  echo "not-a-version" > VERSION
  run "$SCRIPT" --read VERSION
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid"* ]]
}

# ---- determine_bump from commits ----------------------------------------

@test "determine_bump returns major for breaking change" {
  cat > commits.txt <<'EOF'
feat!: drop support for node 14
fix: small typo
EOF
  run "$SCRIPT" --bump-type commits.txt
  [ "$status" -eq 0 ]
  [ "$output" = "major" ]
}

@test "determine_bump detects BREAKING CHANGE footer" {
  cat > commits.txt <<'EOF'
feat: new api

BREAKING CHANGE: rewrites the request shape
EOF
  run "$SCRIPT" --bump-type commits.txt
  [ "$status" -eq 0 ]
  [ "$output" = "major" ]
}

@test "determine_bump returns minor for feat" {
  cat > commits.txt <<'EOF'
feat: add caching layer
fix: handle null inputs
EOF
  run "$SCRIPT" --bump-type commits.txt
  [ "$status" -eq 0 ]
  [ "$output" = "minor" ]
}

@test "determine_bump returns patch for fix only" {
  cat > commits.txt <<'EOF'
fix: correct off-by-one in pager
chore: bump dependency
EOF
  run "$SCRIPT" --bump-type commits.txt
  [ "$status" -eq 0 ]
  [ "$output" = "patch" ]
}

@test "determine_bump returns none when no relevant commits" {
  cat > commits.txt <<'EOF'
chore: update README
docs: clarify install steps
EOF
  run "$SCRIPT" --bump-type commits.txt
  [ "$status" -eq 0 ]
  [ "$output" = "none" ]
}

# ---- next_version arithmetic ---------------------------------------------

@test "next_version major bumps the major and resets minor/patch" {
  run "$SCRIPT" --next 1.4.7 major
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]
}

@test "next_version minor bumps the minor and resets patch" {
  run "$SCRIPT" --next 1.4.7 minor
  [ "$status" -eq 0 ]
  [ "$output" = "1.5.0" ]
}

@test "next_version patch bumps just the patch" {
  run "$SCRIPT" --next 1.4.7 patch
  [ "$status" -eq 0 ]
  [ "$output" = "1.4.8" ]
}

@test "next_version errors on unknown bump type" {
  run "$SCRIPT" --next 1.4.7 weird
  [ "$status" -ne 0 ]
}

# ---- write_version --------------------------------------------------------

@test "write_version updates a plain VERSION file" {
  echo "1.2.3" > VERSION
  run "$SCRIPT" --write VERSION 1.3.0
  [ "$status" -eq 0 ]
  [ "$(cat VERSION)" = "1.3.0" ]
}

@test "write_version updates only the version field in package.json" {
  cat > package.json <<'JSON'
{
  "name": "demo",
  "version": "0.5.7",
  "scripts": {
    "test": "echo ok"
  }
}
JSON
  run "$SCRIPT" --write package.json 0.6.0
  [ "$status" -eq 0 ]
  grep -q '"version": "0.6.0"' package.json
  grep -q '"name": "demo"' package.json
  grep -q '"scripts"' package.json
}

# ---- changelog generation -------------------------------------------------

@test "changelog includes Features and Fixes sections" {
  cat > commits.txt <<'EOF'
feat: add caching layer
fix: handle null inputs
chore: tweak ci
EOF
  run "$SCRIPT" --changelog 1.5.0 commits.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"## 1.5.0"* ]]
  [[ "$output" == *"### Features"* ]]
  [[ "$output" == *"add caching layer"* ]]
  [[ "$output" == *"### Fixes"* ]]
  [[ "$output" == *"handle null inputs"* ]]
  # chore should not appear under Features or Fixes
  [[ "$output" != *"tweak ci"* ]]
}

@test "changelog has Breaking Changes section for feat!" {
  cat > commits.txt <<'EOF'
feat!: drop legacy API
EOF
  run "$SCRIPT" --changelog 2.0.0 commits.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"### Breaking Changes"* ]]
  [[ "$output" == *"drop legacy API"* ]]
}

# ---- end-to-end run -------------------------------------------------------

@test "run end-to-end: bumps VERSION, writes CHANGELOG, prints new version" {
  echo "1.1.0" > VERSION
  cat > commits.txt <<'EOF'
feat: amazing new feature
fix: minor bug
EOF
  run "$SCRIPT" --run VERSION commits.txt
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.0" ]
  [ "$(cat VERSION)" = "1.2.0" ]
  grep -q "## 1.2.0" CHANGELOG.md
  grep -q "amazing new feature" CHANGELOG.md
  grep -q "minor bug" CHANGELOG.md
}

@test "run end-to-end with package.json and breaking change yields major bump" {
  cat > package.json <<'JSON'
{
  "name": "demo",
  "version": "0.9.4"
}
JSON
  cat > commits.txt <<'EOF'
feat!: brand new shape
fix: stuff
EOF
  run "$SCRIPT" --run package.json commits.txt
  [ "$status" -eq 0 ]
  [ "$output" = "1.0.0" ]
  grep -q '"version": "1.0.0"' package.json
}

@test "run end-to-end with no relevant commits keeps version unchanged" {
  echo "1.0.0" > VERSION
  cat > commits.txt <<'EOF'
docs: typos
chore: lint
EOF
  run "$SCRIPT" --run VERSION commits.txt
  [ "$status" -eq 0 ]
  [ "$output" = "1.0.0" ]
  [ "$(cat VERSION)" = "1.0.0" ]
}
