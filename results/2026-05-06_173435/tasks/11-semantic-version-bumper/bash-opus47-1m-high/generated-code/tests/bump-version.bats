#!/usr/bin/env bats
#
# Tests for bump-version.sh
#
# TDD progression:
#   1. version reading (VERSION + package.json)
#   2. commit-type detection (feat/fix/breaking)
#   3. version bumping arithmetic
#   4. file writing
#   5. changelog generation
#   6. CLI integration

setup() {
    SCRIPT_DIR="$BATS_TEST_DIRNAME/.."
    BUMP="$SCRIPT_DIR/bump-version.sh"
    TEST_TMP="$(mktemp -d)"
    cd "$TEST_TMP" || exit 1
}

teardown() {
    cd /tmp || true
    rm -rf "$TEST_TMP"
}

# -------- read_version --------------------------------------------------

@test "read_version: reads from a plain VERSION file" {
    echo "1.2.3" > VERSION
    run "$BUMP" read VERSION
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

@test "read_version: reads from package.json" {
    cat > package.json <<'JSON'
{
  "name": "example",
  "version": "0.4.7"
}
JSON
    run "$BUMP" read package.json
    [ "$status" -eq 0 ]
    [ "$output" = "0.4.7" ]
}

@test "read_version: errors for missing file" {
    run "$BUMP" read does-not-exist
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "read_version: errors when version cannot be parsed" {
    echo "not-a-version" > VERSION
    run "$BUMP" read VERSION
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not parse"* ]]
}

# -------- detect_bump (commit type detection) ---------------------------

@test "detect_bump: feat commits trigger minor" {
    cat > commits.txt <<'EOF'
feat: add login flow
chore: tidy deps
EOF
    run "$BUMP" detect commits.txt
    [ "$status" -eq 0 ]
    [ "$output" = "minor" ]
}

@test "detect_bump: fix-only commits trigger patch" {
    cat > commits.txt <<'EOF'
fix: handle null user
docs: update readme
EOF
    run "$BUMP" detect commits.txt
    [ "$status" -eq 0 ]
    [ "$output" = "patch" ]
}

@test "detect_bump: BREAKING CHANGE in body triggers major" {
    cat > commits.txt <<'EOF'
feat: rework auth

BREAKING CHANGE: drops legacy session cookies
EOF
    run "$BUMP" detect commits.txt
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "detect_bump: '!' marker on type triggers major" {
    cat > commits.txt <<'EOF'
feat!: drop node 16 support
fix: small thing
EOF
    run "$BUMP" detect commits.txt
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "detect_bump: no relevant commits returns 'none'" {
    cat > commits.txt <<'EOF'
chore: bump deps
docs: tweak heading
style: format
EOF
    run "$BUMP" detect commits.txt
    [ "$status" -eq 0 ]
    [ "$output" = "none" ]
}

# -------- next_version (arithmetic) -------------------------------------

@test "next_version: patch bump increments patch" {
    run "$BUMP" next 1.2.3 patch
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.4" ]
}

@test "next_version: minor bump increments minor and resets patch" {
    run "$BUMP" next 1.2.3 minor
    [ "$status" -eq 0 ]
    [ "$output" = "1.3.0" ]
}

@test "next_version: major bump increments major and resets minor/patch" {
    run "$BUMP" next 1.2.3 major
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "next_version: 'none' bump returns same version" {
    run "$BUMP" next 1.2.3 none
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

# -------- write_version -------------------------------------------------

@test "write_version: updates VERSION file in place" {
    echo "1.0.0" > VERSION
    run "$BUMP" write VERSION 2.0.0
    [ "$status" -eq 0 ]
    [ "$(cat VERSION)" = "2.0.0" ]
}

@test "write_version: updates the version field in package.json" {
    cat > package.json <<'JSON'
{
  "name": "demo",
  "version": "1.0.0",
  "scripts": { "test": "echo hi" }
}
JSON
    run "$BUMP" write package.json 1.1.0
    [ "$status" -eq 0 ]
    grep -q '"version": "1.1.0"' package.json
    # other fields preserved
    grep -q '"name": "demo"' package.json
    grep -q '"test": "echo hi"' package.json
}

# -------- changelog -----------------------------------------------------

@test "changelog: groups entries by type with version header" {
    cat > commits.txt <<'EOF'
feat: add login
fix: correct retry logic
chore: bump deps
EOF
    run "$BUMP" changelog commits.txt 1.2.0
    [ "$status" -eq 0 ]
    [[ "$output" == *"## 1.2.0"* ]]
    [[ "$output" == *"### Features"* ]]
    [[ "$output" == *"add login"* ]]
    [[ "$output" == *"### Fixes"* ]]
    [[ "$output" == *"correct retry logic"* ]]
}

# -------- bump (the all-in-one CLI) -------------------------------------

@test "bump: end-to-end on VERSION file with feat commit" {
    echo "1.1.0" > VERSION
    cat > commits.txt <<'EOF'
feat: add awesome feature
EOF
    run "$BUMP" bump VERSION commits.txt CHANGELOG.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.2.0"* ]]
    [ "$(cat VERSION)" = "1.2.0" ]
    grep -q "## 1.2.0" CHANGELOG.md
    grep -q "add awesome feature" CHANGELOG.md
}

@test "bump: end-to-end on package.json with fix commit" {
    cat > package.json <<'JSON'
{
  "name": "demo",
  "version": "0.5.0"
}
JSON
    cat > commits.txt <<'EOF'
fix: stop crashing on empty input
EOF
    run "$BUMP" bump package.json commits.txt CHANGELOG.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"0.5.1"* ]]
    grep -q '"version": "0.5.1"' package.json
}

@test "bump: end-to-end with breaking change" {
    echo "1.4.2" > VERSION
    cat > commits.txt <<'EOF'
feat!: redesign API surface
fix: small thing
EOF
    run "$BUMP" bump VERSION commits.txt CHANGELOG.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"2.0.0"* ]]
    [ "$(cat VERSION)" = "2.0.0" ]
}

@test "bump: no version-relevant commits exits non-zero with message" {
    echo "1.0.0" > VERSION
    cat > commits.txt <<'EOF'
chore: tidy
docs: typo
EOF
    run "$BUMP" bump VERSION commits.txt CHANGELOG.md
    [ "$status" -ne 0 ]
    [[ "$output" == *"no version-affecting commits"* ]]
    [ "$(cat VERSION)" = "1.0.0" ]
}

@test "bump: fails clearly when commits file missing" {
    echo "1.0.0" > VERSION
    run "$BUMP" bump VERSION /nope/commits.txt CHANGELOG.md
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "bump: appends to existing CHANGELOG.md keeping prior entries" {
    echo "1.0.0" > VERSION
    cat > CHANGELOG.md <<'EOF'
# Changelog

## 1.0.0
- initial
EOF
    cat > commits.txt <<'EOF'
feat: shiny
EOF
    run "$BUMP" bump VERSION commits.txt CHANGELOG.md
    [ "$status" -eq 0 ]
    grep -q "## 1.1.0" CHANGELOG.md
    grep -q "## 1.0.0" CHANGELOG.md
    grep -q "initial" CHANGELOG.md
}

# -------- usage / help --------------------------------------------------

@test "usage: prints help when called with no args" {
    run "$BUMP"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}
