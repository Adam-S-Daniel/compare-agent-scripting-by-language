#!/usr/bin/env bats
#
# TDD test suite for the semantic version bumper.
# Each test case runs the GitHub Actions workflow via `act push --rm`
# against a fresh temp git repo containing the fixture data, then asserts
# the exact expected new version / changelog lines appear in act output.
#
# All act output is appended to act-result.txt with clear delimiters.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ACT_RESULT="$REPO_ROOT/act-result.txt"

setup_file() {
    # Truncate the aggregate act-result.txt at the start of the suite.
    : > "$ACT_RESULT"
}

# Build a temp repo populated with our project + the test fixture.
# $1 = fixture dir name (contains VERSION and commits.txt)
make_repo() {
    local fixture="$1"
    local tmp
    tmp="$(mktemp -d)"
    cp "$REPO_ROOT/bump-version.sh" "$tmp/"
    mkdir -p "$tmp/.github/workflows"
    cp "$REPO_ROOT/.github/workflows/semantic-version-bumper.yml" "$tmp/.github/workflows/"
    cp "$REPO_ROOT/.actrc" "$tmp/"
    cp "$REPO_ROOT/fixtures/$fixture/VERSION" "$tmp/VERSION"
    cp "$REPO_ROOT/fixtures/$fixture/commits.txt" "$tmp/commits.txt"
    (
        cd "$tmp"
        git init -q -b main
        git config user.email t@t
        git config user.name t
        git add .
        git commit -q -m "init"
    )
    echo "$tmp"
}

run_act_case() {
    local label="$1" tmp="$2"
    echo "===== CASE: $label =====" >> "$ACT_RESULT"
    (cd "$tmp" && act push --rm --pull=false \
        --container-architecture linux/amd64) >>"$ACT_RESULT" 2>&1
    local rc=$?
    echo "===== END $label (rc=$rc) =====" >> "$ACT_RESULT"
    return $rc
}

@test "feat commits bump minor version 1.0.0 -> 1.1.0" {
    local tmp; tmp="$(make_repo feat-case)"
    run run_act_case "feat-case" "$tmp"
    [ "$status" -eq 0 ]
    grep -q "NEW_VERSION=1.1.0" "$ACT_RESULT"
    grep -q "Job succeeded" "$ACT_RESULT"
    grep -q "### Features" "$ACT_RESULT"
}

@test "fix commits bump patch version 1.1.0 -> 1.1.1" {
    local tmp; tmp="$(make_repo fix-case)"
    run run_act_case "fix-case" "$tmp"
    [ "$status" -eq 0 ]
    grep -q "NEW_VERSION=1.1.1" "$ACT_RESULT"
    grep -q "Job succeeded" "$ACT_RESULT"
    grep -q "### Bug Fixes" "$ACT_RESULT"
}

@test "breaking change commits bump major version 1.2.3 -> 2.0.0" {
    local tmp; tmp="$(make_repo breaking-case)"
    run run_act_case "breaking-case" "$tmp"
    [ "$status" -eq 0 ]
    grep -q "NEW_VERSION=2.0.0" "$ACT_RESULT"
    grep -q "Job succeeded" "$ACT_RESULT"
    grep -q "### BREAKING CHANGES" "$ACT_RESULT"
}

@test "workflow YAML passes actionlint" {
    run actionlint "$REPO_ROOT/.github/workflows/semantic-version-bumper.yml"
    [ "$status" -eq 0 ]
}

@test "workflow structure: triggers on push and references bump-version.sh" {
    local wf="$REPO_ROOT/.github/workflows/semantic-version-bumper.yml"
    grep -qE "^on:" "$wf"
    grep -qE "^\s*push:" "$wf"
    grep -q "bump-version.sh" "$wf"
    [ -f "$REPO_ROOT/bump-version.sh" ]
}

@test "script passes shellcheck and bash -n" {
    run shellcheck "$REPO_ROOT/bump-version.sh"
    [ "$status" -eq 0 ]
    run bash -n "$REPO_ROOT/bump-version.sh"
    [ "$status" -eq 0 ]
}
