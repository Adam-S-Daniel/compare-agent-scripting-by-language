#!/usr/bin/env bats
# PR Label Assigner - Test Suite
#
# TDD approach: tests define the expected behavior.
# Tests are ordered from simplest to most complex, mirroring implementation order.
#
# Test groups:
#   1. Script existence / executability
#   2. Basic label matching (one file, one rule)
#   3. Glob pattern matching (nested paths, wildcards)
#   4. Multiple labels per file (file matches multiple rules)
#   5. Multiple files → combined label set
#   6. Priority ordering and deduplication (same label from multiple rules → once)
#   7. No-match handling (empty output)
#   8. Error handling (missing config, no args)
#   9. Stdin mode
#  10. Full production config smoke tests
#  11. Workflow structure tests (YAML triggers, paths, actionlint)

# ---------------------------------------------------------------------------
# Setup: define paths relative to the test file so tests work wherever bats
# is invoked from (repo root, tests/, CI container, etc.)
# ---------------------------------------------------------------------------
setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SCRIPT="$REPO_ROOT/pr-label-assigner.sh"
    TEST_CONFIG="$REPO_ROOT/fixtures/test-rules.conf"
    FULL_CONFIG="$REPO_ROOT/label-rules.conf"
    WORKFLOW="$REPO_ROOT/.github/workflows/pr-label-assigner.yml"
}

# ===========================================================================
# TDD Step 1: Script existence and executability
# (These tests fail first — drives creation of the script)
# ===========================================================================

@test "script file exists" {
    [ -f "$SCRIPT" ]
}

@test "script is executable" {
    [ -x "$SCRIPT" ]
}

# ===========================================================================
# TDD Step 2: Basic label matching — docs file → documentation
# ===========================================================================

@test "docs/ file gets 'documentation' label" {
    run "$SCRIPT" "$TEST_CONFIG" "docs/README.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
}

@test "nested docs/ file gets 'documentation' label" {
    run "$SCRIPT" "$TEST_CONFIG" "docs/api/reference.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
}

# ===========================================================================
# TDD Step 3: API file label matching — src/api/** → api
# ===========================================================================

@test "src/api/ file gets 'api' label" {
    run "$SCRIPT" "$TEST_CONFIG" "src/api/users.ts"
    [ "$status" -eq 0 ]
    [[ "$output" == *"api"* ]]
}

@test "deeply nested src/api/ file gets 'api' label" {
    run "$SCRIPT" "$TEST_CONFIG" "src/api/v1/handlers/users.ts"
    [ "$status" -eq 0 ]
    [[ "$output" == *"api"* ]]
}

# ===========================================================================
# TDD Step 4: Test file pattern — *.test.* → tests
# ===========================================================================

@test "*.test.ts file gets 'tests' label" {
    run "$SCRIPT" "$TEST_CONFIG" "src/utils.test.ts"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tests"* ]]
}

@test "*.test.tsx file gets 'tests' label" {
    run "$SCRIPT" "$TEST_CONFIG" "components/Button.test.tsx"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tests"* ]]
}

@test "*.test.js file gets 'tests' label" {
    run "$SCRIPT" "$TEST_CONFIG" "lib/parser.test.js"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tests"* ]]
}

# ===========================================================================
# TDD Step 5: Multiple labels per file (file matches several rules)
# ===========================================================================

@test "api test file gets both 'api' and 'tests' labels" {
    run "$SCRIPT" "$TEST_CONFIG" "src/api/users.test.ts"
    [ "$status" -eq 0 ]
    [[ "$output" == *"api"* ]]
    [[ "$output" == *"tests"* ]]
}

# ===========================================================================
# TDD Step 6: Multiple files → combined unique label set
# ===========================================================================

@test "docs + api files produce combined label set" {
    run "$SCRIPT" "$TEST_CONFIG" "docs/README.md" "src/api/users.ts"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
    [[ "$output" == *"api"* ]]
}

@test "three files each with different labels produce three labels" {
    run "$SCRIPT" "$TEST_CONFIG" "docs/README.md" "src/api/users.ts" "src/utils.test.ts"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
    [[ "$output" == *"api"* ]]
    [[ "$output" == *"tests"* ]]
}

# ===========================================================================
# TDD Step 7: Priority ordering and deduplication
# When two rules both map to the same label, the label appears exactly once.
# Output order = order of first matching rule (highest priority first).
# ===========================================================================

@test "duplicate label from two rules appears exactly once" {
    # Create a temp config with two rules that both map to 'documentation'
    local tmpconfig="${BATS_TMPDIR}/dedup-test.conf"
    printf 'docs/**:documentation\n*.md:documentation\n' > "$tmpconfig"
    run "$SCRIPT" "$tmpconfig" "docs/README.md"
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | grep -c "^documentation$" || true)
    [ "$count" -eq 1 ]
}

@test "labels are output in rule-priority order" {
    # docs/** is rule 1, src/api/** is rule 2, *.test.* is rule 3
    # Expect: documentation, api, tests (in that order)
    run "$SCRIPT" "$TEST_CONFIG" "docs/guide.md" "src/api/utils.test.ts"
    [ "$status" -eq 0 ]
    # Check order: documentation must appear before api, api before tests
    local doc_line api_line tests_line
    doc_line=$(echo "$output" | grep -n "^documentation$" | cut -d: -f1 || true)
    api_line=$(echo "$output" | grep -n "^api$" | cut -d: -f1 || true)
    tests_line=$(echo "$output" | grep -n "^tests$" | cut -d: -f1 || true)
    [ -n "$doc_line" ]
    [ -n "$api_line" ]
    [ -n "$tests_line" ]
    [ "$doc_line" -lt "$api_line" ]
    [ "$api_line" -lt "$tests_line" ]
}

# ===========================================================================
# TDD Step 8: No-match handling — unrecognized files → empty output, exit 0
# ===========================================================================

@test "unmatched file produces empty output with exit 0" {
    run "$SCRIPT" "$TEST_CONFIG" "unknown/mystery.xyz"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "multiple unmatched files produce empty output with exit 0" {
    run "$SCRIPT" "$TEST_CONFIG" "random.bin" "tmp/scratch.tmp"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ===========================================================================
# TDD Step 9: Error handling — missing config, no args, invalid config
# ===========================================================================

@test "missing config file exits non-zero with error message" {
    run "$SCRIPT" "/nonexistent/no-such-config.conf" "docs/README.md"
    [ "$status" -ne 0 ]
}

@test "no arguments exits non-zero" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
}

# ===========================================================================
# TDD Step 10: Stdin mode — files can be piped in when no file args given
# ===========================================================================

@test "reads file list from stdin when no file args are provided" {
    run bash -c "printf 'docs/README.md\n' | '$SCRIPT' '$TEST_CONFIG'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
}

@test "stdin mode with multiple files produces combined labels" {
    run bash -c "printf 'docs/README.md\nsrc/api/users.ts\n' | '$SCRIPT' '$TEST_CONFIG'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
    [[ "$output" == *"api"* ]]
}

# ===========================================================================
# TDD Step 11: Full production config smoke tests
# ===========================================================================

@test "full config: docs file → documentation" {
    run "$SCRIPT" "$FULL_CONFIG" "docs/README.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
}

@test "full config: markdown file → documentation" {
    run "$SCRIPT" "$FULL_CONFIG" "CONTRIBUTING.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
}

@test "full config: src/ file → source" {
    run "$SCRIPT" "$FULL_CONFIG" "src/main.ts"
    [ "$status" -eq 0 ]
    [[ "$output" == *"source"* ]]
}

@test "full config: JSON file → config" {
    run "$SCRIPT" "$FULL_CONFIG" "package.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"config"* ]]
}

@test "full config: GitHub Actions workflow file → ci" {
    run "$SCRIPT" "$FULL_CONFIG" ".github/workflows/deploy.yml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ci"* ]]
}

# ===========================================================================
# TDD Step 12: Workflow structure tests
# (Verify the GHA workflow has expected structure, paths, and passes lint)
# ===========================================================================

@test "workflow file exists at .github/workflows/pr-label-assigner.yml" {
    [ -f "$WORKFLOW" ]
}

@test "workflow has 'push' trigger" {
    grep -q "push" "$WORKFLOW"
}

@test "workflow has 'workflow_dispatch' trigger" {
    grep -q "workflow_dispatch" "$WORKFLOW"
}

@test "workflow references pr-label-assigner.sh" {
    grep -q "pr-label-assigner.sh" "$WORKFLOW"
}

@test "script file referenced in workflow exists on disk" {
    [ -f "$REPO_ROOT/pr-label-assigner.sh" ]
}

@test "test config file referenced in workflow exists on disk" {
    [ -f "$REPO_ROOT/fixtures/test-rules.conf" ]
}

@test "shellcheck passes on pr-label-assigner.sh" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not available in this environment"
    fi
    run shellcheck "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "actionlint passes on workflow file" {
    if ! command -v actionlint >/dev/null 2>&1; then
        skip "actionlint not available in this environment"
    fi
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}
