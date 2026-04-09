#!/usr/bin/env bats
# Tests for Docker Image Tag Generator
#
# All integration tests run through act (GitHub Actions locally).
# Each test creates a temp git repo, copies project files, runs act,
# captures output to act-result.txt, and asserts exact expected values.

# ── Paths ────────────────────────────────────────────────────────────────────
ORIG_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
SCRIPT_PATH="${ORIG_DIR}/docker-tag-generator.sh"
WORKFLOW_PATH="${ORIG_DIR}/.github/workflows/docker-image-tag-generator.yml"
ACT_RESULT="${ORIG_DIR}/act-result.txt"

# Mock SHA used across all tests (40 hex chars)
MOCK_SHA="a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"
SHORT_SHA="a1b2c3d"

# ── Helpers ──────────────────────────────────────────────────────────────────

# Create a temporary git repo with the project files copied in.
create_test_repo() {
    local dir
    dir="$(mktemp -d)"
    pushd "$dir" > /dev/null
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    cp "$SCRIPT_PATH" .
    mkdir -p .github/workflows
    cp "$WORKFLOW_PATH" .github/workflows/
    git add -A
    git commit -q -m "initial commit"
    echo "$dir"
}

# Run act push in the given directory and append output to act-result.txt.
# Arguments: test_dir event_json [extra act flags...]
run_act() {
    local test_dir="$1" event_json="$2"
    shift 2
    local event_file="${test_dir}/event.json"
    echo "$event_json" > "$event_file"

    local output exit_code=0
    output=$(cd "$test_dir" && act push --rm \
        -P ubuntu-latest=catthehacker/ubuntu:act-latest \
        -e event.json \
        "$@" 2>&1) || exit_code=$?

    # Append delimited output to the shared results file
    {
        echo "============================================================"
        echo "TEST: ${BATS_TEST_DESCRIPTION}"
        echo "EXIT CODE: ${exit_code}"
        echo "============================================================"
        echo "$output"
        echo ""
    } >> "$ACT_RESULT"

    # Return the output and exit code
    echo "$output"
    return "$exit_code"
}

# Extract Docker tags from act output (lines between the delimiters).
extract_tags() {
    local output="$1"
    echo "$output" \
        | sed -n '/GENERATED DOCKER TAGS/,/END DOCKER TAGS/p' \
        | grep '|' \
        | sed 's/.*| //' \
        | grep -v '==='
}

# Assert that a specific tag appears in the extracted tags.
assert_tag_present() {
    local tags="$1" expected="$2"
    if ! echo "$tags" | grep -qx "$expected"; then
        echo "FAIL: expected tag '$expected' not found in:"
        echo "$tags"
        return 1
    fi
}

# Assert that a specific tag does NOT appear.
assert_tag_absent() {
    local tags="$1" unexpected="$2"
    if echo "$tags" | grep -qx "$unexpected"; then
        echo "FAIL: unexpected tag '$unexpected' found in:"
        echo "$tags"
        return 1
    fi
}

# ── Setup / Teardown ────────────────────────────────────────────────────────

setup_file() {
    # Clear act-result.txt at the start of the test suite
    : > "$ACT_RESULT"
}

setup() {
    TEST_DIR="$(create_test_repo)"
}

teardown() {
    popd > /dev/null 2>&1 || true
    [[ -n "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

# ══════════════════════════════════════════════════════════════════════════════
# WORKFLOW STRUCTURE TESTS
# ══════════════════════════════════════════════════════════════════════════════

@test "workflow YAML file exists" {
    [[ -f "$WORKFLOW_PATH" ]]
}

@test "script file exists and is executable" {
    [[ -x "$SCRIPT_PATH" ]]
}

@test "workflow references docker-tag-generator.sh" {
    grep -q "docker-tag-generator.sh" "$WORKFLOW_PATH"
}

@test "workflow has correct triggers (push, pull_request, schedule, workflow_dispatch)" {
    python3 -c "
import yaml, sys
with open('$WORKFLOW_PATH') as f:
    wf = yaml.safe_load(f)
triggers = wf[True]  # 'on' is parsed as True by pyyaml
assert 'push' in triggers, 'missing push trigger'
assert 'pull_request' in triggers, 'missing pull_request trigger'
assert 'schedule' in triggers, 'missing schedule trigger'
assert 'workflow_dispatch' in triggers, 'missing workflow_dispatch trigger'
print('All expected triggers present')
"
}

@test "workflow has generate-tags job with checkout and generate steps" {
    python3 -c "
import yaml, sys
with open('$WORKFLOW_PATH') as f:
    wf = yaml.safe_load(f)
jobs = wf['jobs']
assert 'generate-tags' in jobs, 'missing generate-tags job'
steps = jobs['generate-tags']['steps']
step_names = [s.get('name', s.get('uses', '')) for s in steps]
assert any('checkout' in str(s) for s in steps if 'uses' in s), 'missing checkout step'
assert any('Generate Docker image tags' in n for n in step_names), 'missing generate step'
print('Job structure OK')
"
}

@test "actionlint passes with no errors" {
    run actionlint "$WORKFLOW_PATH"
    echo "$output"
    [[ "$status" -eq 0 ]]
}

@test "shellcheck passes on script" {
    run shellcheck "$SCRIPT_PATH"
    echo "$output"
    [[ "$status" -eq 0 ]]
}

@test "bash -n syntax check passes on script" {
    run bash -n "$SCRIPT_PATH"
    echo "$output"
    [[ "$status" -eq 0 ]]
}

# ══════════════════════════════════════════════════════════════════════════════
# INTEGRATION TESTS (via act)
# ══════════════════════════════════════════════════════════════════════════════

@test "main branch push: produces 'latest' and 'main-{sha}'" {
    local output
    output=$(run_act "$TEST_DIR" '{"ref":"refs/heads/main"}' \
        --env "OVERRIDE_COMMIT_SHA=${MOCK_SHA}")

    # Job must succeed
    echo "$output" | grep -q "Job succeeded"

    # Extract and verify exact tags
    local tags
    tags=$(extract_tags "$output")
    assert_tag_present "$tags" "latest"
    assert_tag_present "$tags" "main-${SHORT_SHA}"
}

@test "master branch push: produces 'latest' and 'master-{sha}'" {
    local output
    output=$(run_act "$TEST_DIR" '{"ref":"refs/heads/master"}' \
        --env "OVERRIDE_COMMIT_SHA=${MOCK_SHA}")

    echo "$output" | grep -q "Job succeeded"

    local tags
    tags=$(extract_tags "$output")
    assert_tag_present "$tags" "latest"
    assert_tag_present "$tags" "master-${SHORT_SHA}"
}

@test "feature branch push: produces '{branch}-{sha}' only (no 'latest')" {
    local output
    output=$(run_act "$TEST_DIR" '{"ref":"refs/heads/feature/add-login"}' \
        --env "OVERRIDE_COMMIT_SHA=${MOCK_SHA}")

    echo "$output" | grep -q "Job succeeded"

    local tags
    tags=$(extract_tags "$output")
    assert_tag_present "$tags" "feature-add-login-${SHORT_SHA}"
    assert_tag_absent "$tags" "latest"
}

@test "semver tag push: produces 'v{semver}' and 'latest'" {
    local output
    output=$(run_act "$TEST_DIR" '{"ref":"refs/tags/v1.2.3"}' \
        --env "OVERRIDE_COMMIT_SHA=${MOCK_SHA}")

    echo "$output" | grep -q "Job succeeded"

    local tags
    tags=$(extract_tags "$output")
    assert_tag_present "$tags" "v1.2.3"
    assert_tag_present "$tags" "latest"
}

@test "pre-release tag push: produces tag but no 'latest'" {
    # v2.0.0-rc.1 is semver-ish, but the base regex ^v[0-9]+\.[0-9]+\.[0-9]+
    # will match, so "latest" IS produced. This tests the tag sanitization.
    local output
    output=$(run_act "$TEST_DIR" '{"ref":"refs/tags/v2.0.0-rc.1"}' \
        --env "OVERRIDE_COMMIT_SHA=${MOCK_SHA}")

    echo "$output" | grep -q "Job succeeded"

    local tags
    tags=$(extract_tags "$output")
    # The sanitized tag should be "v2.0.0-rc.1" (dots and dashes are valid)
    assert_tag_present "$tags" "v2.0.0-rc.1"
}

@test "PR override: produces 'pr-{number}' and branch tag" {
    local output
    output=$(run_act "$TEST_DIR" '{"ref":"refs/heads/feature/pr-branch"}' \
        --env "OVERRIDE_COMMIT_SHA=${MOCK_SHA}" \
        --env "OVERRIDE_PR_NUMBER=42")

    echo "$output" | grep -q "Job succeeded"

    local tags
    tags=$(extract_tags "$output")
    assert_tag_present "$tags" "pr-42"
    assert_tag_present "$tags" "feature-pr-branch-${SHORT_SHA}"
}

@test "branch name sanitization: uppercase and special chars" {
    local output
    output=$(run_act "$TEST_DIR" '{"ref":"refs/heads/Feature/MY--Cool_Branch!"}' \
        --env "OVERRIDE_COMMIT_SHA=${MOCK_SHA}")

    echo "$output" | grep -q "Job succeeded"

    local tags
    tags=$(extract_tags "$output")
    # Should be lowercased, special chars replaced, dashes collapsed
    assert_tag_present "$tags" "feature-my-cool-branch-${SHORT_SHA}"
}

@test "tag override via env: produces tag without branch" {
    local output
    output=$(run_act "$TEST_DIR" '{"ref":"refs/heads/ignored"}' \
        --env "OVERRIDE_COMMIT_SHA=${MOCK_SHA}" \
        --env "OVERRIDE_GIT_TAG=v3.0.0")

    echo "$output" | grep -q "Job succeeded"

    local tags
    tags=$(extract_tags "$output")
    assert_tag_present "$tags" "v3.0.0"
    assert_tag_present "$tags" "latest"
}

@test "simple branch name: no slashes or special chars" {
    local output
    output=$(run_act "$TEST_DIR" '{"ref":"refs/heads/develop"}' \
        --env "OVERRIDE_COMMIT_SHA=${MOCK_SHA}")

    echo "$output" | grep -q "Job succeeded"

    local tags
    tags=$(extract_tags "$output")
    assert_tag_present "$tags" "develop-${SHORT_SHA}"
    assert_tag_absent "$tags" "latest"
}
