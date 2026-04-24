#!/usr/bin/env bats
# Tests for pr-label-assigner.sh using bats-core
# TDD: tests are written first, implementation follows

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/pr-label-assigner.sh"

# Fixture: default rules config used across tests
setup() {
    RULES_FILE="$(mktemp)"
    cat > "$RULES_FILE" <<'EOF'
docs/**:documentation:10
src/api/**:api:20
src/**:source:5
*.test.*:tests:15
*.spec.*:tests:15
**/*.test.*:tests:15
**/*.spec.*:tests:15
*.md:documentation:10
**/*.md:documentation:10
Makefile:build:10
**/*.sh:shell:10
.github/**:ci:20
EOF
}

teardown() {
    rm -f "$RULES_FILE"
}

# --- TEST 1: script exists and is executable ---
@test "script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# --- TEST 2: no files produces no labels ---
@test "no files produces no output" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- TEST 3: single file matching docs rule ---
@test "docs file gets documentation label" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "docs/README.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "documentation"
}

# --- TEST 4: single file matching api rule ---
@test "api file gets api label" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "src/api/users.js"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "api"
}

# --- TEST 5: test file gets tests label ---
@test "test file gets tests label" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "src/utils.test.js"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "tests"
}

# --- TEST 6: file matching multiple rules gets multiple labels ---
@test "api test file gets both api and tests labels" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "src/api/users.test.js"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "api"
    echo "$output" | grep -qx "tests"
}

# --- TEST 7: labels are deduplicated ---
@test "multiple files matching same rule produce single label" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "docs/README.md
docs/guide.md"
    [ "$status" -eq 0 ]
    # Count occurrences of 'documentation' - should be exactly 1
    count=$(echo "$output" | grep -c "^documentation$" || true)
    [ "$count" -eq 1 ]
}

# --- TEST 8: unmatched file produces no label ---
@test "unmatched file produces no label" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "some/random/file.xyz"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- TEST 9: multiple files with different labels ---
@test "multiple files produce multiple labels" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "docs/README.md
src/api/users.js"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "documentation"
    echo "$output" | grep -qx "api"
}

# --- TEST 10: priority ordering - higher priority labels appear first ---
@test "higher priority labels appear before lower priority labels" {
    # src/api/** has priority 20, src/** has priority 5
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "src/api/users.js"
    [ "$status" -eq 0 ]
    # api (priority 20) should appear before source (priority 5)
    api_line=$(echo "$output" | grep -n "^api$" | cut -d: -f1)
    source_line=$(echo "$output" | grep -n "^source$" | cut -d: -f1)
    [ -n "$api_line" ]
    [ -n "$source_line" ]
    [ "$api_line" -lt "$source_line" ]
}

# --- TEST 11: rules from file argument ---
@test "accepts rules via --rules flag" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "docs/guide.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "documentation"
}

# --- TEST 12: files from --files argument instead of stdin ---
@test "accepts file list via --files flag" {
    FILES_LIST="$(mktemp)"
    echo "src/api/handler.js" > "$FILES_LIST"
    run bash "$SCRIPT" --rules "$RULES_FILE" --files "$FILES_LIST"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "api"
    rm -f "$FILES_LIST"
}

# --- TEST 13: missing rules file produces error ---
@test "missing rules file produces error message" {
    run bash "$SCRIPT" --rules /nonexistent/rules.conf <<< "docs/README.md"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "error\|not found\|cannot"
}

# --- TEST 14: CI/github files get ci label ---
@test "github actions file gets ci label" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< ".github/workflows/test.yml"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "ci"
}

# --- TEST 15: custom rules override defaults ---
@test "custom rules file is used when specified" {
    CUSTOM_RULES="$(mktemp)"
    echo "src/**:custom-source:10" > "$CUSTOM_RULES"
    run bash "$SCRIPT" --rules "$CUSTOM_RULES" <<< "src/main.js"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "custom-source"
    rm -f "$CUSTOM_RULES"
}

# --- TEST 16: spec files get tests label ---
@test "spec file gets tests label" {
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "src/components/Button.spec.js"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "tests"
}

# --- TEST 17: mock file list integration test ---
@test "mock PR file list produces expected labels" {
    # Simulate a PR touching docs, api, and tests
    run bash "$SCRIPT" --rules "$RULES_FILE" <<< "docs/api-reference.md
src/api/endpoints.js
src/api/endpoints.test.js
src/utils/helpers.js"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "documentation"
    echo "$output" | grep -qx "api"
    echo "$output" | grep -qx "tests"
    echo "$output" | grep -qx "source"
}

# --- TEST 18: comments and blank lines in rules file are ignored ---
@test "rules file with comments and blank lines works" {
    COMMENTED_RULES="$(mktemp)"
    cat > "$COMMENTED_RULES" <<'EOF'
# This is a comment
docs/**:documentation:10

# Another comment
src/api/**:api:20
EOF
    run bash "$SCRIPT" --rules "$COMMENTED_RULES" <<< "docs/README.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "documentation"
    rm -f "$COMMENTED_RULES"
}
