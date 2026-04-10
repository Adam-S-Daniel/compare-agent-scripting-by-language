#!/usr/bin/env bats
# Tests for Docker Image Tag Generator
# Uses bats-core testing framework
# TDD approach: each test was written before the corresponding implementation

# Path to the script under test
SCRIPT="${BATS_TEST_DIRNAME}/../generate-tags.sh"

# ─────────────────────────────────────────────────────────────────────────────
# RED phase: first failing test — main branch should produce 'latest'
# ─────────────────────────────────────────────────────────────────────────────

@test "main branch generates 'latest' tag" {
    run "$SCRIPT" --branch main --sha abc1234567890
    [ "$status" -eq 0 ]
    [ "$output" = "latest" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# master branch (alias for main)
# ─────────────────────────────────────────────────────────────────────────────

@test "master branch generates 'latest' tag" {
    run "$SCRIPT" --branch master --sha abc1234567890
    [ "$status" -eq 0 ]
    [ "$output" = "latest" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# PR branches generate pr-{number}
# ─────────────────────────────────────────────────────────────────────────────

@test "PR number generates 'pr-{number}' tag" {
    run "$SCRIPT" --branch feature/my-feature --sha abc1234567890 --pr 42
    [ "$status" -eq 0 ]
    [ "$output" = "pr-42" ]
}

@test "PR 1 generates 'pr-1' tag" {
    run "$SCRIPT" --branch fix/bugfix --sha def5678901234 --pr 1
    [ "$status" -eq 0 ]
    [ "$output" = "pr-1" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Semver tags produce v{semver}; when on main also produce 'latest'
# ─────────────────────────────────────────────────────────────────────────────

@test "semver tag on main generates 'v1.2.3' and 'latest'" {
    run "$SCRIPT" --branch main --sha abc1234567890 --tag v1.2.3
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^v1\.2\.3$"
    echo "$output" | grep -q "^latest$"
}

@test "semver tag on feature branch generates only 'v1.0.0'" {
    run "$SCRIPT" --branch feature/release --sha abc1234567890 --tag v1.0.0
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^v1\.0\.0$"
    # should NOT contain a branch-sha tag when a version tag is present
    ! echo "$output" | grep -q "\-abc1234$"
}

# ─────────────────────────────────────────────────────────────────────────────
# Feature branches get {sanitized-branch}-{short-sha}
# Short SHA = first 7 characters of the full SHA
# ─────────────────────────────────────────────────────────────────────────────

@test "feature branch generates branch-shortsha tag" {
    run "$SCRIPT" --branch feature/my-feature --sha abc1234567890
    [ "$status" -eq 0 ]
    [ "$output" = "feature-my-feature-abc1234" ]
}

@test "develop branch generates branch-shortsha tag" {
    run "$SCRIPT" --branch develop --sha def5678901234
    [ "$status" -eq 0 ]
    [ "$output" = "develop-def5678" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Tag sanitization: lowercase, no special chars except hyphens
# ─────────────────────────────────────────────────────────────────────────────

@test "branch name is lowercased" {
    run "$SCRIPT" --branch Feature/MyFeature --sha abc1234567890
    [ "$status" -eq 0 ]
    [ "$output" = "feature-myfeature-abc1234" ]
}

@test "underscores in branch name are replaced with hyphens" {
    run "$SCRIPT" --branch feature_my_feature --sha abc1234567890
    [ "$status" -eq 0 ]
    [ "$output" = "feature-my-feature-abc1234" ]
}

@test "multiple special chars are collapsed to single hyphen" {
    run "$SCRIPT" --branch "feat//double-slash" --sha abc1234567890
    [ "$status" -eq 0 ]
    [ "$output" = "feat-double-slash-abc1234" ]
}

@test "leading and trailing hyphens are trimmed from sanitized branch" {
    run "$SCRIPT" --branch "/leading-slash" --sha abc1234567890
    [ "$status" -eq 0 ]
    [ "$output" = "leading-slash-abc1234" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Error handling
# ─────────────────────────────────────────────────────────────────────────────

@test "missing --branch argument exits with error" {
    run "$SCRIPT" --sha abc1234567890
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "branch"
}

@test "missing --sha argument exits with error" {
    run "$SCRIPT" --branch main
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "sha"
}

@test "unknown argument exits with error" {
    run "$SCRIPT" --branch main --sha abc1234 --unknown-flag value
    [ "$status" -ne 0 ]
}
