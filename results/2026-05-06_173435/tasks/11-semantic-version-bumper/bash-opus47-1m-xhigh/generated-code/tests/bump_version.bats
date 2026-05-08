#!/usr/bin/env bats
# Tests for the semantic version bumper script.
# Each test sets up an isolated temporary directory with a fresh "project" containing
# a version file or package.json plus a commit log fixture. The bumper script
# is run against that project and we assert on the resulting version, file
# contents, and changelog output.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../bump_version.sh"
    TMPDIR="$(mktemp -d)"
    cd "$TMPDIR"
}

teardown() {
    rm -rf "$TMPDIR"
}

# --- helpers -------------------------------------------------------------

# Write a list of "type: subject" lines as the commit log.
write_commits() {
    printf '%s\n' "$@" > commits.txt
}

# --- detection of bump type from commit messages ------------------------

@test "detect_bump returns 'patch' for fix-only commits" {
    write_commits "fix: correct off-by-one in pagination"
    run "$SCRIPT" detect-bump commits.txt
    [ "$status" -eq 0 ]
    [ "$output" = "patch" ]
}

@test "detect_bump returns 'minor' when a feat commit is present" {
    write_commits \
        "fix: correct typo in README" \
        "feat: add export to CSV"
    run "$SCRIPT" detect-bump commits.txt
    [ "$status" -eq 0 ]
    [ "$output" = "minor" ]
}

@test "detect_bump returns 'major' when a breaking change is present (BREAKING CHANGE token)" {
    write_commits \
        "feat: rewrite API surface" \
        "BREAKING CHANGE: removes deprecated /v1 endpoints"
    run "$SCRIPT" detect-bump commits.txt
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "detect_bump returns 'major' when a commit subject has a bang (feat!)" {
    write_commits "feat!: drop python 3.7 support"
    run "$SCRIPT" detect-bump commits.txt
    [ "$status" -eq 0 ]
    [ "$output" = "major" ]
}

@test "detect_bump returns 'none' when no conventional commits are present" {
    write_commits \
        "chore: tidy whitespace" \
        "docs: clarify install steps"
    run "$SCRIPT" detect-bump commits.txt
    [ "$status" -eq 0 ]
    [ "$output" = "none" ]
}

@test "detect_bump fails with a clear error if the commits file does not exist" {
    run "$SCRIPT" detect-bump no-such-file.txt
    [ "$status" -ne 0 ]
    [[ "$output" == *"commits file not found"* ]]
}

# --- next-version arithmetic --------------------------------------------

@test "next_version: patch bump" {
    run "$SCRIPT" next-version 1.2.3 patch
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.4" ]
}

@test "next_version: minor bump resets patch" {
    run "$SCRIPT" next-version 1.2.3 minor
    [ "$status" -eq 0 ]
    [ "$output" = "1.3.0" ]
}

@test "next_version: major bump resets minor and patch" {
    run "$SCRIPT" next-version 1.2.3 major
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "next_version: 'none' returns the current version unchanged" {
    run "$SCRIPT" next-version 1.2.3 none
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

@test "next_version rejects an invalid semver string" {
    run "$SCRIPT" next-version "not-a-version" patch
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid semver"* ]]
}

@test "next_version rejects an unknown bump type" {
    run "$SCRIPT" next-version 1.0.0 sideways
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown bump type"* ]]
}

# --- reading and writing the version file -------------------------------

@test "read_version reads a plain VERSION file" {
    echo "0.5.1" > VERSION
    run "$SCRIPT" read-version VERSION
    [ "$status" -eq 0 ]
    [ "$output" = "0.5.1" ]
}

@test "read_version reads from package.json" {
    cat > package.json <<'JSON'
{
  "name": "demo",
  "version": "2.0.4",
  "description": "x"
}
JSON
    run "$SCRIPT" read-version package.json
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.4" ]
}

@test "write_version updates a plain VERSION file" {
    echo "0.5.1" > VERSION
    run "$SCRIPT" write-version VERSION 0.6.0
    [ "$status" -eq 0 ]
    [ "$(cat VERSION)" = "0.6.0" ]
}

@test "write_version updates the version field in package.json without disturbing other fields" {
    cat > package.json <<'JSON'
{
  "name": "demo",
  "version": "2.0.4",
  "description": "x"
}
JSON
    run "$SCRIPT" write-version package.json 2.1.0
    [ "$status" -eq 0 ]
    grep -q '"version": "2.1.0"' package.json
    grep -q '"name": "demo"' package.json
    grep -q '"description": "x"' package.json
}

# --- changelog generation ----------------------------------------------

@test "changelog: groups commits by section with a heading line" {
    write_commits \
        "feat: add export to CSV" \
        "fix: correct off-by-one in pagination" \
        "chore: tidy whitespace"
    run "$SCRIPT" changelog 1.3.0 commits.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"## 1.3.0"* ]]
    [[ "$output" == *"### Features"* ]]
    [[ "$output" == *"add export to CSV"* ]]
    [[ "$output" == *"### Fixes"* ]]
    [[ "$output" == *"correct off-by-one"* ]]
    # chore should not show up under Features or Fixes
    [[ "$output" != *"tidy whitespace"* ]] || \
        [[ "$output" == *"### Other"* ]]
}

@test "changelog: surfaces breaking changes under a dedicated heading" {
    write_commits \
        "feat!: drop python 3.7 support" \
        "BREAKING CHANGE: minimum python version is now 3.8"
    run "$SCRIPT" changelog 2.0.0 commits.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"### Breaking Changes"* ]]
    [[ "$output" == *"drop python 3.7 support"* ]]
}

# --- end-to-end bump ---------------------------------------------------

@test "bump (end-to-end): updates VERSION file, writes CHANGELOG, prints new version" {
    echo "1.0.0" > VERSION
    write_commits \
        "feat: add login screen" \
        "fix: handle empty username"
    run "$SCRIPT" bump VERSION commits.txt CHANGELOG.md
    [ "$status" -eq 0 ]
    [ "$output" = "1.1.0" ]
    [ "$(cat VERSION)" = "1.1.0" ]
    grep -q "## 1.1.0" CHANGELOG.md
    grep -q "add login screen" CHANGELOG.md
    grep -q "handle empty username" CHANGELOG.md
}

@test "bump (end-to-end): with package.json updates version field" {
    cat > package.json <<'JSON'
{
  "name": "demo",
  "version": "1.0.0"
}
JSON
    write_commits "feat!: redesign config schema"
    run "$SCRIPT" bump package.json commits.txt CHANGELOG.md
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
    grep -q '"version": "2.0.0"' package.json
    grep -q "## 2.0.0" CHANGELOG.md
    grep -q "### Breaking Changes" CHANGELOG.md
}

@test "bump (end-to-end): no-bump commits leave version untouched and exit 0 with a notice" {
    echo "1.4.2" > VERSION
    write_commits "chore: rewrap docs" "docs: add example"
    run "$SCRIPT" bump VERSION commits.txt CHANGELOG.md
    [ "$status" -eq 0 ]
    [ "$output" = "1.4.2" ]
    [ "$(cat VERSION)" = "1.4.2" ]
    # No changelog should be written when nothing bumped
    [ ! -f CHANGELOG.md ]
}

@test "bump (end-to-end): appends to an existing CHANGELOG keeping prior entries" {
    echo "1.0.0" > VERSION
    cat > CHANGELOG.md <<'MD'
# Changelog

## 1.0.0
- initial release
MD
    write_commits "feat: shiny new thing"
    run "$SCRIPT" bump VERSION commits.txt CHANGELOG.md
    [ "$status" -eq 0 ]
    [ "$output" = "1.1.0" ]
    grep -q "## 1.1.0" CHANGELOG.md
    grep -q "shiny new thing" CHANGELOG.md
    # prior entry preserved
    grep -q "initial release" CHANGELOG.md
}

# --- usage / errors ----------------------------------------------------

@test "missing subcommand prints usage and fails" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}
