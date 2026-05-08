#!/usr/bin/env bats
# TDD tests for pr-label-assigner.sh
# Red/green cycle: tests were written first, then the script was implemented.

# ---------------------------------------------------------------------------
# Path setup — bats copies test files to a temp dir, so BASH_SOURCE[0] is
# wrong.  BATS_TEST_FILENAME always holds the original test file path and is
# set by bats before setup() runs, so we derive repo root from it there.
# ---------------------------------------------------------------------------
setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    SCRIPT="$REPO_ROOT/pr-label-assigner.sh"
    FIXTURES="$REPO_ROOT/tests/fixtures"
    WORKFLOW="$REPO_ROOT/.github/workflows/pr-label-assigner.yml"
}

# ---------------------------------------------------------------------------
# Sanity: script must exist (first TDD failing test — written before the script)
# ---------------------------------------------------------------------------
@test "script file exists" {
    [ -f "$SCRIPT" ]
}

@test "script is executable" {
    [ -x "$SCRIPT" ]
}

# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------
@test "exits with error and shows usage when no arguments given" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "exits with error when config file does not exist" {
    run "$SCRIPT" /nonexistent/path/config.conf
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "exits with error when file list argument does not exist" {
    run "$SCRIPT" "$FIXTURES/basic.conf" /nonexistent/files.txt
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

# ---------------------------------------------------------------------------
# Basic label assignment (one file → one label)
# ---------------------------------------------------------------------------
@test "assigns documentation label to a docs file" {
    run bash -c "echo 'docs/README.md' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

@test "assigns api label to a src/api file" {
    run bash -c "echo 'src/api/handler.js' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    [ "$output" = "api" ]
}

@test "assigns tests label to a .test. file via glob" {
    run bash -c "echo 'src/utils.test.js' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    [ "$output" = "tests" ]
}

@test "assigns frontend label to src/frontend files" {
    run bash -c "echo 'src/frontend/App.jsx' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    [ "$output" = "frontend" ]
}

# ---------------------------------------------------------------------------
# Multi-file: multiple files produce multiple distinct labels
# ---------------------------------------------------------------------------
@test "assigns multiple labels when multiple files match different rules" {
    run bash -c "printf 'docs/README.md\nsrc/api/handler.js\n' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
    [[ "$output" == *"api"* ]]
}

@test "assigns multiple labels when one file matches multiple rules" {
    # src/api/handler.test.js matches both src/api/** (api) and *.test.* (tests)
    run bash -c "echo 'src/api/handler.test.js' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"api"* ]]
    [[ "$output" == *"tests"* ]]
}

# ---------------------------------------------------------------------------
# Empty / no-match cases
# ---------------------------------------------------------------------------
@test "produces no output when no file matches any rule" {
    run bash -c "echo 'random/unmatched-file.rb' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "produces no output for empty input" {
    run bash -c "echo '' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Deduplication: same label from multiple files → appears only once
# ---------------------------------------------------------------------------
@test "deduplicates labels when multiple files match the same rule" {
    run bash -c "printf 'src/api/a.js\nsrc/api/b.js\n' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    count=$(echo "$output" | grep -c "^api$")
    [ "$count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Priority ordering: lower priority number → appears first in output
# ---------------------------------------------------------------------------
@test "outputs labels in ascending priority order" {
    # docs/spec.test.md matches documentation(1) and tests(3) from basic.conf
    # documentation has lower priority number → should appear first
    run bash -c "echo 'docs/spec.test.md' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    first=$(echo "$output" | head -1)
    [ "$first" = "documentation" ]
}

@test "priority config - api before tests when both match same file" {
    # priority.conf: api=1, tests=2; src/api/*.test.js matches both
    run bash -c "echo 'src/api/handler.test.js' | '$SCRIPT' '$FIXTURES/priority.conf'"
    [ "$status" -eq 0 ]
    first=$(echo "$output" | head -1)
    [ "$first" = "api" ]
}

# ---------------------------------------------------------------------------
# Glob patterns
# ---------------------------------------------------------------------------
@test "glob ** matches deeply nested paths" {
    run bash -c "echo 'docs/api/v2/reference/endpoints.md' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

@test "glob *.test.* matches test files with path prefix" {
    run bash -c "echo 'src/deeply/nested/component.test.tsx' | '$SCRIPT' '$FIXTURES/basic.conf'"
    [ "$status" -eq 0 ]
    [ "$output" = "tests" ]
}

# ---------------------------------------------------------------------------
# File-argument mode: pass file list as argument instead of stdin
# ---------------------------------------------------------------------------
@test "reads changed file list from file argument" {
    run "$SCRIPT" "$FIXTURES/basic.conf" "$FIXTURES/changed-files.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
    [[ "$output" == *"api"* ]]
}

# ---------------------------------------------------------------------------
# Config: comments and blank lines are ignored
# ---------------------------------------------------------------------------
@test "ignores comment lines and blank lines in config" {
    run bash -c "echo 'docs/guide.md' | '$SCRIPT' '$FIXTURES/comments.conf'"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

# ---------------------------------------------------------------------------
# Workflow structure tests (parse YAML, verify references, run actionlint)
# ---------------------------------------------------------------------------
@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "workflow has push and pull_request triggers" {
    python3 - <<PYEOF
import yaml, sys
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
# PyYAML (YAML 1.1) parses the GHA 'on:' key as boolean True.
# Handle both the boolean-key and string-key forms.
on = wf.get(True, None)
if on is None:
    on = wf.get('on', {})
if isinstance(on, str):
    on = {on: None}
if isinstance(on, list):
    on = {k: None for k in on}
assert 'push' in on, f"push trigger missing; got: {list(on.keys())}"
assert 'pull_request' in on, f"pull_request trigger missing; got: {list(on.keys())}"
print("Triggers OK:", list(on.keys()))
PYEOF
}

@test "workflow has at least one job" {
    python3 - <<PYEOF
import yaml
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
jobs = wf.get('jobs', {})
assert len(jobs) > 0, "workflow has no jobs"
print("Jobs found:", list(jobs.keys()))
PYEOF
}

@test "workflow references script file that exists" {
    grep -q "pr-label-assigner.sh" "$WORKFLOW"
    [ -f "$REPO_ROOT/pr-label-assigner.sh" ]
}

@test "workflow passes actionlint validation" {
    if ! command -v actionlint &>/dev/null; then
        skip "actionlint not available in this environment"
    fi
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}
