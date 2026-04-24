#!/usr/bin/env bats
# Tests for semantic version bumper — TDD approach.
# Written BEFORE bump-version.sh to define the expected behavior (red/green TDD).

# Paths relative to the test file location
SCRIPT="${BATS_TEST_DIRNAME}/../bump-version.sh"
FIXTURES="${BATS_TEST_DIRNAME}/../fixtures"
WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/semantic-version-bumper.yml"

setup() {
    TEST_TMPDIR=$(mktemp -d)
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# TDD Phase 1 (RED → GREEN): fix commit bumps patch version
# Written first; fails until bump-version.sh exists and parses fix commits.
# =============================================================================
@test "fix commit bumps patch version (1.0.0 -> 1.0.1)" {
    echo "1.0.0" > "${TEST_TMPDIR}/version.txt"
    cp "${FIXTURES}/commits-fix.txt" "${TEST_TMPDIR}/commits.txt"

    run bash "$SCRIPT" "${TEST_TMPDIR}/version.txt" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    [ "$output" = "1.0.1" ]
}

# =============================================================================
# TDD Phase 2 (RED → GREEN): feat commit bumps minor version
# =============================================================================
@test "feat commit bumps minor version (1.0.0 -> 1.1.0)" {
    echo "1.0.0" > "${TEST_TMPDIR}/version.txt"
    cp "${FIXTURES}/commits-feat.txt" "${TEST_TMPDIR}/commits.txt"

    run bash "$SCRIPT" "${TEST_TMPDIR}/version.txt" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    [ "$output" = "1.1.0" ]
}

# =============================================================================
# TDD Phase 3 (RED → GREEN): breaking change bumps major version
# Uses feat! syntax (! after type triggers breaking change).
# =============================================================================
@test "breaking change (feat!) bumps major version (1.0.0 -> 2.0.0)" {
    echo "1.0.0" > "${TEST_TMPDIR}/version.txt"
    cp "${FIXTURES}/commits-breaking.txt" "${TEST_TMPDIR}/commits.txt"

    run bash "$SCRIPT" "${TEST_TMPDIR}/version.txt" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

# =============================================================================
# TDD Phase 4 (RED → GREEN): BREAKING CHANGE in commit body also triggers major
# =============================================================================
@test "BREAKING CHANGE keyword triggers major bump" {
    echo "2.0.0" > "${TEST_TMPDIR}/version.txt"
    printf 'fix: patch something\nBREAKING CHANGE: removed old endpoint\n' > "${TEST_TMPDIR}/commits.txt"

    run bash "$SCRIPT" "${TEST_TMPDIR}/version.txt" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    [ "$output" = "3.0.0" ]
}

# =============================================================================
# TDD Phase 5 (RED → GREEN): highest bump wins with mixed commits
# feat + fix + chore => minor (feat wins over fix and chore)
# =============================================================================
@test "mixed commits use highest bump type (feat+fix -> minor, 1.0.0 -> 1.1.0)" {
    echo "1.0.0" > "${TEST_TMPDIR}/version.txt"
    cp "${FIXTURES}/commits-mixed.txt" "${TEST_TMPDIR}/commits.txt"

    run bash "$SCRIPT" "${TEST_TMPDIR}/version.txt" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    [ "$output" = "1.1.0" ]
}

# =============================================================================
# TDD Phase 6 (RED → GREEN): package.json version parsing
# =============================================================================
@test "parses version from package.json (2.3.4 + fix -> 2.3.5)" {
    cp "${FIXTURES}/package-2.3.4.json" "${TEST_TMPDIR}/package.json"
    cp "${FIXTURES}/commits-fix.txt" "${TEST_TMPDIR}/commits.txt"

    run bash "$SCRIPT" "${TEST_TMPDIR}/package.json" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    [ "$output" = "2.3.5" ]
}

# =============================================================================
# TDD Phase 7 (RED → GREEN): version file is updated in place
# =============================================================================
@test "version.txt is updated to new version after bump" {
    echo "3.2.1" > "${TEST_TMPDIR}/version.txt"
    cp "${FIXTURES}/commits-feat.txt" "${TEST_TMPDIR}/commits.txt"

    run bash "$SCRIPT" "${TEST_TMPDIR}/version.txt" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    updated=$(tr -d '[:space:]' < "${TEST_TMPDIR}/version.txt")
    [ "$updated" = "3.3.0" ]
}

# =============================================================================
# TDD Phase 8 (RED → GREEN): changelog is generated with sections
# =============================================================================
@test "changelog entry created with version header and Features section" {
    echo "1.0.0" > "${TEST_TMPDIR}/version.txt"
    cp "${FIXTURES}/commits-feat.txt" "${TEST_TMPDIR}/commits.txt"

    run bash "$SCRIPT" "${TEST_TMPDIR}/version.txt" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    [ -f "${TEST_TMPDIR}/CHANGELOG.md" ]
    grep -q "\[1.1.0\]" "${TEST_TMPDIR}/CHANGELOG.md"
    grep -q "Features" "${TEST_TMPDIR}/CHANGELOG.md"
}

@test "changelog entry created with Bug Fixes section for fix commits" {
    echo "1.0.0" > "${TEST_TMPDIR}/version.txt"
    cp "${FIXTURES}/commits-fix.txt" "${TEST_TMPDIR}/commits.txt"

    run bash "$SCRIPT" "${TEST_TMPDIR}/version.txt" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    grep -q "Bug Fixes" "${TEST_TMPDIR}/CHANGELOG.md"
}

@test "changelog prepends to existing CHANGELOG.md" {
    echo "1.0.0" > "${TEST_TMPDIR}/version.txt"
    cp "${FIXTURES}/commits-fix.txt" "${TEST_TMPDIR}/commits.txt"
    echo "## [1.0.0] - 2025-01-01" > "${TEST_TMPDIR}/CHANGELOG.md"

    run bash "$SCRIPT" "${TEST_TMPDIR}/version.txt" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    # New entry at top, old entry still present
    grep -q "\[1.0.1\]" "${TEST_TMPDIR}/CHANGELOG.md"
    grep -q "\[1.0.0\]" "${TEST_TMPDIR}/CHANGELOG.md"
}

# =============================================================================
# TDD Phase 9 (RED → GREEN): package.json is updated in place
# =============================================================================
@test "package.json version field is updated after bump" {
    cp "${FIXTURES}/package-2.3.4.json" "${TEST_TMPDIR}/package.json"
    cp "${FIXTURES}/commits-feat.txt" "${TEST_TMPDIR}/commits.txt"

    run bash "$SCRIPT" "${TEST_TMPDIR}/package.json" "${TEST_TMPDIR}/commits.txt" "${TEST_TMPDIR}/CHANGELOG.md"

    [ "$status" -eq 0 ]
    grep -q '"version": "2.4.0"' "${TEST_TMPDIR}/package.json"
}

# =============================================================================
# TDD Phase 10 (RED → GREEN): error handling
# =============================================================================
@test "exits non-zero when version file does not exist" {
    run bash "$SCRIPT" "/nonexistent/version.txt" "/dev/null"
    [ "$status" -ne 0 ]
}

@test "exits non-zero when commits file does not exist" {
    echo "1.0.0" > "${TEST_TMPDIR}/version.txt"
    run bash "$SCRIPT" "${TEST_TMPDIR}/version.txt" "/nonexistent/commits.txt"
    [ "$status" -ne 0 ]
}

@test "exits non-zero with too few arguments" {
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
}

# =============================================================================
# Workflow Structure Tests
# Verify the GHA workflow YAML has the expected structure and references.
# =============================================================================
@test "workflow file exists at expected path" {
    [ -f "$WORKFLOW" ]
}

@test "workflow has push trigger" {
    grep -q 'push' "$WORKFLOW"
}

@test "workflow has jobs section" {
    grep -q 'jobs:' "$WORKFLOW"
}

@test "workflow references bump-version.sh" {
    grep -q 'bump-version.sh' "$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'actions/checkout@v4' "$WORKFLOW"
}

@test "bump-version.sh script file exists" {
    [ -f "${BATS_TEST_DIRNAME}/../bump-version.sh" ]
}

@test "actionlint passes on workflow file" {
    if ! command -v actionlint &>/dev/null; then
        skip "actionlint not available in this environment"
    fi
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}
