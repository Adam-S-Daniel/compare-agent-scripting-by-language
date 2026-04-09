#!/usr/bin/env bats
# Tests for pr_label_assigner.sh using bats-core
# TDD approach: tests written before implementation

# Path to the script under test
SCRIPT="$BATS_TEST_DIRNAME/../pr_label_assigner.sh"

# Helper: create a temp config file with given rules
# Format: one rule per line: pattern:label:priority
create_config() {
    local config_file="$1"
    shift
    printf '%s\n' "$@" > "$config_file"
}

# Helper: create a temp file list
create_filelist() {
    local file="$1"
    shift
    printf '%s\n' "$@" > "$file"
}

setup() {
    # Create temp dir for each test
    TEST_DIR="$(mktemp -d)"
    CONFIG="$TEST_DIR/rules.conf"
    FILELIST="$TEST_DIR/files.txt"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================
# Test 1: Script exists and is executable
# ============================================================
@test "script exists and is executable" {
    [ -x "$SCRIPT" ]
}

# ============================================================
# Test 2: Basic docs/** -> documentation mapping
# ============================================================
@test "docs file matches documentation label" {
    create_config "$CONFIG" "docs/**:documentation:10"
    create_filelist "$FILELIST" "docs/README.md"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    echo "Output: $output"
    [[ "$output" == *"documentation"* ]]
}

# ============================================================
# Test 3: src/api/** -> api mapping
# ============================================================
@test "src/api file matches api label" {
    create_config "$CONFIG" "src/api/**:api:10"
    create_filelist "$FILELIST" "src/api/handler.go"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    [[ "$output" == *"api"* ]]
}

# ============================================================
# Test 4: *.test.* pattern matches tests label
# ============================================================
@test "test file matches tests label" {
    create_config "$CONFIG" "*.test.*:tests:10"
    create_filelist "$FILELIST" "handler.test.js"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    [[ "$output" == *"tests"* ]]
}

# ============================================================
# Test 5: Multiple files can produce multiple labels
# ============================================================
@test "multiple files produce multiple labels" {
    create_config "$CONFIG" \
        "docs/**:documentation:10" \
        "src/api/**:api:20"
    create_filelist "$FILELIST" \
        "docs/guide.md" \
        "src/api/routes.go"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
    [[ "$output" == *"api"* ]]
}

# ============================================================
# Test 6: Labels are deduplicated (same label not repeated)
# ============================================================
@test "duplicate labels are deduplicated" {
    create_config "$CONFIG" "docs/**:documentation:10"
    create_filelist "$FILELIST" \
        "docs/README.md" \
        "docs/guide.md"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    # Count occurrences of 'documentation' - should be exactly 1
    local count
    count=$(echo "$output" | grep -c "documentation")
    [ "$count" -eq 1 ]
}

# ============================================================
# Test 7: No match produces no labels (empty output or "none")
# ============================================================
@test "unmatched files produce no labels" {
    create_config "$CONFIG" "docs/**:documentation:10"
    create_filelist "$FILELIST" "src/main.go"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    [[ "$output" != *"documentation"* ]]
}

# ============================================================
# Test 8: Priority ordering - higher priority label first
# ============================================================
@test "higher priority rules appear first in output" {
    create_config "$CONFIG" \
        "src/**:backend:5" \
        "src/api/**:api:20"
    create_filelist "$FILELIST" "src/api/handler.go"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    # Both labels should appear
    [[ "$output" == *"api"* ]]
    [[ "$output" == *"backend"* ]]

    # Higher priority (20) label 'api' should appear before lower priority (5) 'backend'
    local api_pos backend_pos
    api_pos=$(echo "$output" | grep -n "api" | head -1 | cut -d: -f1)
    backend_pos=$(echo "$output" | grep -n "backend" | head -1 | cut -d: -f1)
    [ "$api_pos" -le "$backend_pos" ]
}

# ============================================================
# Test 9: Missing config file produces error
# ============================================================
@test "missing config file produces error" {
    create_filelist "$FILELIST" "docs/README.md"

    run "$SCRIPT" --config "/nonexistent/rules.conf" --files "$FILELIST"

    [ "$status" -ne 0 ]
    [[ "$output" == *"error"* ]] || [[ "$output" == *"Error"* ]] || [[ "$output" == *"ERROR"* ]]
}

# ============================================================
# Test 10: Missing files list produces error
# ============================================================
@test "missing files list produces error" {
    create_config "$CONFIG" "docs/**:documentation:10"

    run "$SCRIPT" --config "$CONFIG" --files "/nonexistent/files.txt"

    [ "$status" -ne 0 ]
}

# ============================================================
# Test 11: Wildcard at root level (*.md -> documentation)
# ============================================================
@test "root level wildcard matches files" {
    create_config "$CONFIG" "*.md:documentation:10"
    create_filelist "$FILELIST" "README.md"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
}

# ============================================================
# Test 12: Multiple rules can match a single file
# ============================================================
@test "multiple rules matching same file produce multiple labels" {
    create_config "$CONFIG" \
        "src/**:backend:10" \
        "**/*.test.js:tests:20"
    create_filelist "$FILELIST" "src/handler.test.js"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    [[ "$output" == *"backend"* ]]
    [[ "$output" == *"tests"* ]]
}

# ============================================================
# Test 13: Comments in config file are ignored
# ============================================================
@test "config file comments are ignored" {
    cat > "$CONFIG" <<'EOF'
# This is a comment
docs/**:documentation:10
# Another comment
src/api/**:api:20
EOF
    create_filelist "$FILELIST" "docs/guide.md"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    [[ "$output" == *"documentation"* ]]
    [[ "$output" != *"#"* ]]
}

# ============================================================
# Test 14: Empty files list produces empty labels
# ============================================================
@test "empty files list produces no labels" {
    create_config "$CONFIG" "docs/**:documentation:10"
    # Create empty file list
    > "$FILELIST"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    [[ "$output" != *"documentation"* ]]
}

# ============================================================
# Test 15: Output format is one label per line
# ============================================================
@test "output format is one label per line" {
    create_config "$CONFIG" \
        "docs/**:documentation:10" \
        "src/**:backend:20"
    create_filelist "$FILELIST" \
        "docs/guide.md" \
        "src/main.go"

    run "$SCRIPT" --config "$CONFIG" --files "$FILELIST"

    [ "$status" -eq 0 ]
    # Each label should be on its own line
    local doc_line backend_line
    doc_line=$(echo "$output" | grep "^documentation$")
    backend_line=$(echo "$output" | grep "^backend$")
    [ -n "$doc_line" ]
    [ -n "$backend_line" ]
}
