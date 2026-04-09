#!/usr/bin/env bats
# tests.bats — Docker image tag generator tests
#
# All tests run through GitHub Actions via act. We also validate workflow
# structure and actionlint compliance.
#
# The act run happens once in setup_file; individual test cases parse
# the captured output in act-result.txt.

WORK_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"

# ============================================================================
# Workflow structure tests (no act needed)
# ============================================================================

@test "workflow YAML file exists" {
  [ -f "$WORK_DIR/.github/workflows/docker-image-tag-generator.yml" ]
}

@test "workflow references docker-tag-generator.sh" {
  grep -q "docker-tag-generator.sh" "$WORK_DIR/.github/workflows/docker-image-tag-generator.yml"
}

@test "docker-tag-generator.sh exists and is executable" {
  [ -x "$WORK_DIR/docker-tag-generator.sh" ]
}

@test "workflow has push trigger" {
  grep -q "push:" "$WORK_DIR/.github/workflows/docker-image-tag-generator.yml"
}

@test "workflow has pull_request trigger" {
  grep -q "pull_request:" "$WORK_DIR/.github/workflows/docker-image-tag-generator.yml"
}

@test "workflow has workflow_dispatch trigger" {
  grep -q "workflow_dispatch:" "$WORK_DIR/.github/workflows/docker-image-tag-generator.yml"
}

@test "workflow has generate-tags job" {
  grep -q "generate-tags:" "$WORK_DIR/.github/workflows/docker-image-tag-generator.yml"
}

@test "workflow uses actions/checkout@v4" {
  grep -q "actions/checkout@v4" "$WORK_DIR/.github/workflows/docker-image-tag-generator.yml"
}

@test "actionlint passes with exit code 0" {
  run actionlint "$WORK_DIR/.github/workflows/docker-image-tag-generator.yml"
  [ "$status" -eq 0 ]
}

@test "shellcheck passes on docker-tag-generator.sh" {
  run shellcheck "$WORK_DIR/docker-tag-generator.sh"
  [ "$status" -eq 0 ]
}

@test "bash -n syntax check passes" {
  run bash -n "$WORK_DIR/docker-tag-generator.sh"
  [ "$status" -eq 0 ]
}

# ============================================================================
# Act-based integration tests
# ============================================================================

# Run act once and store output for all subsequent tests
setup_file() {
  # Only run act if act-result.txt doesn't already exist
  if [ ! -f "$WORK_DIR/act-result.txt" ]; then
    # Create a temporary git repo with our project files
    local tmpdir
    tmpdir="$(mktemp -d)"

    # Copy project files
    cp "$WORK_DIR/docker-tag-generator.sh" "$tmpdir/"
    chmod +x "$tmpdir/docker-tag-generator.sh"
    mkdir -p "$tmpdir/.github/workflows"
    cp "$WORK_DIR/.github/workflows/docker-image-tag-generator.yml" "$tmpdir/.github/workflows/"

    # Copy .actrc if present
    if [ -f "$WORK_DIR/.actrc" ]; then
      cp "$WORK_DIR/.actrc" "$tmpdir/"
    fi

    # Init a git repo (act needs this for push events)
    cd "$tmpdir"
    git init -b main
    git config user.email "test@test.com"
    git config user.name "Test"
    git add -A
    git commit -m "initial"

    # Run act and capture output
    act push --rm --pull=false 2>&1 | tee "$WORK_DIR/act-result.txt" || true

    # Cleanup
    rm -rf "$tmpdir"
  fi
}

@test "act-result.txt was created" {
  [ -f "$WORK_DIR/act-result.txt" ]
}

@test "act: generate-tags job succeeded" {
  grep -q "Job succeeded" "$WORK_DIR/act-result.txt"
}

@test "act: Test 1 — main branch produces 'latest' tag" {
  grep -q "DOCKER_TAG=latest" "$WORK_DIR/act-result.txt"
  grep -q "TEST 1 PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: Test 2 — master branch produces 'latest' tag" {
  grep -q "TEST 2 PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: Test 3 — PR build produces 'pr-42' tag" {
  grep -q "DOCKER_TAG=pr-42" "$WORK_DIR/act-result.txt"
  grep -q "DOCKER_TAG=feature-login-deadbee" "$WORK_DIR/act-result.txt"
  grep -q "TEST 3 PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: Test 4 — semver tag produces 'v1.2.3'" {
  grep -q "DOCKER_TAG=v1.2.3" "$WORK_DIR/act-result.txt"
  grep -q "TEST 4 PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: Test 5 — feature branch produces 'feature-awesome-thing-cafebab'" {
  grep -q "DOCKER_TAG=feature-awesome-thing-cafebab" "$WORK_DIR/act-result.txt"
  grep -q "TEST 5 PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: Test 6 — sanitization lowercases and strips special chars" {
  grep -q "DOCKER_TAG=feature-my-branch-name-aabbccd" "$WORK_DIR/act-result.txt"
  grep -q "TEST 6 PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: Test 7 — refs/heads/ prefix is stripped" {
  grep -q "TEST 7 PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: Test 8 — error on missing inputs" {
  grep -q "TEST 8 PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: Test 9 — tag only without branch produces 'v2.0.0-rc.1'" {
  grep -q "DOCKER_TAG=v2.0.0-rc.1" "$WORK_DIR/act-result.txt"
  grep -q "TEST 9 PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: Test 10 — combined tag + PR + feature branch" {
  grep -q "DOCKER_TAG=v1.0.0" "$WORK_DIR/act-result.txt"
  grep -q "DOCKER_TAG=pr-99" "$WORK_DIR/act-result.txt"
  grep -q "DOCKER_TAG=release-1.0-abcdef1" "$WORK_DIR/act-result.txt"
  grep -q "TEST 10 PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: all 10 test cases passed" {
  grep -q "ALL TESTS PASSED" "$WORK_DIR/act-result.txt"
}

@test "act: no test failures in output" {
  # Ensure no FAILED lines appear
  ! grep -q "FAILED" "$WORK_DIR/act-result.txt"
}
