#!/usr/bin/env bats

# Tests for bump-version.sh - semantic version bumping from conventional commits.
# TDD: tests written first, then implementation.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../bump-version.sh"
    TMPDIR="$(mktemp -d)"
    cd "$TMPDIR"
}

teardown() {
    rm -rf "$TMPDIR"
}

# --- determine_bump_type ---

@test "determine_bump_type: feat commit -> minor" {
    run bash "$SCRIPT" --determine-bump-type "feat: add login"
    [ "$status" -eq 0 ]
    [ "$output" = "minor" ]
}

@test "determine_bump_type: fix commit -> patch" {
    run bash "$SCRIPT" --determine-bump-type "fix: null pointer"
    [ "$status" -eq 0 ]
    [ "$output" = "patch" ]
}

@test "determine_bump_type: BREAKING CHANGE -> major" {
    run bash "$SCRIPT" --determine-bump-type "feat!: drop node 16
BREAKING CHANGE: removed API"
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "determine_bump_type: chore -> none" {
    run bash "$SCRIPT" --determine-bump-type "chore: update deps"
    [ "$status" -eq 0 ]
    [ "$output" = "none" ]
}

@test "determine_bump_type: multiple commits picks highest (major)" {
    local msgs="fix: a
feat: b
feat!: c"
    run bash "$SCRIPT" --determine-bump-type "$msgs"
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

# --- bump_version ---

@test "bump_version: patch bumps 1.2.3 -> 1.2.4" {
    run bash "$SCRIPT" --bump 1.2.3 patch
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.4" ]
}

@test "bump_version: minor bumps 1.2.3 -> 1.3.0" {
    run bash "$SCRIPT" --bump 1.2.3 minor
    [ "$status" -eq 0 ]
    [ "$output" = "1.3.0" ]
}

@test "bump_version: major bumps 1.2.3 -> 2.0.0" {
    run bash "$SCRIPT" --bump 1.2.3 major
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "bump_version: none leaves version unchanged" {
    run bash "$SCRIPT" --bump 1.2.3 none
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

@test "bump_version: invalid version -> error" {
    run bash "$SCRIPT" --bump not-a-version patch
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid version"* ]]
}

# --- read version file ---

@test "read_version: VERSION plain file" {
    echo "0.1.0" > VERSION
    run bash "$SCRIPT" --read-version VERSION
    [ "$status" -eq 0 ]
    [ "$output" = "0.1.0" ]
}

@test "read_version: package.json" {
    cat > package.json <<'EOF'
{
  "name": "demo",
  "version": "2.5.1",
  "description": "x"
}
EOF
    run bash "$SCRIPT" --read-version package.json
    [ "$status" -eq 0 ]
    [ "$output" = "2.5.1" ]
}

@test "read_version: missing file -> error" {
    run bash "$SCRIPT" --read-version nope.txt
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# --- write version file ---

@test "write_version: VERSION file" {
    echo "0.1.0" > VERSION
    run bash "$SCRIPT" --write-version VERSION 1.0.0
    [ "$status" -eq 0 ]
    [ "$(cat VERSION)" = "1.0.0" ]
}

@test "write_version: package.json preserves structure" {
    cat > package.json <<'EOF'
{
  "name": "demo",
  "version": "2.5.1",
  "description": "x"
}
EOF
    run bash "$SCRIPT" --write-version package.json 2.6.0
    [ "$status" -eq 0 ]
    run bash "$SCRIPT" --read-version package.json
    [ "$output" = "2.6.0" ]
    grep -q '"name": "demo"' package.json
}

# --- changelog ---

@test "changelog: groups by type" {
    local commits="feat: add login
fix: null check
chore: bump deps"
    run bash "$SCRIPT" --changelog 1.1.0 "$commits"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## 1.1.0"* ]]
    [[ "$output" == *"Features"* ]]
    [[ "$output" == *"add login"* ]]
    [[ "$output" == *"Bug Fixes"* ]]
    [[ "$output" == *"null check"* ]]
}

# --- full pipeline ---

@test "full pipeline: reads VERSION, bumps, writes, emits version + changelog" {
    echo "1.1.0" > VERSION
    mkdir -p fixtures
    cat > fixtures/commits.txt <<'EOF'
feat: add search
fix: typo in README
EOF
    run bash "$SCRIPT" --run VERSION fixtures/commits.txt CHANGELOG.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.2.0"* ]]
    [ "$(cat VERSION)" = "1.2.0" ]
    grep -q "## 1.2.0" CHANGELOG.md
    grep -q "add search" CHANGELOG.md
}

@test "full pipeline: no version-affecting commits -> no bump" {
    echo "1.1.0" > VERSION
    mkdir -p fixtures
    cat > fixtures/commits.txt <<'EOF'
chore: update deps
docs: fix README
EOF
    run bash "$SCRIPT" --run VERSION fixtures/commits.txt CHANGELOG.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.1.0"* ]]
    [ "$(cat VERSION)" = "1.1.0" ]
}
