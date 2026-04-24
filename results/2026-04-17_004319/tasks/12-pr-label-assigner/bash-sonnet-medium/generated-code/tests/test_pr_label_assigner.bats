#!/usr/bin/env bats
# TDD tests for PR label assigner
# Run with: bats tests/test_pr_label_assigner.bats

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/pr_label_assigner.sh"

# ── Fixture helpers ──────────────────────────────────────────────────────────

setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
  CONFIG="$TMPDIR/rules.conf"
  FILES="$TMPDIR/files.txt"
}

teardown() {
  rm -rf "$TMPDIR"
}

write_config() {
  # Each arg is a "pattern:label" line
  printf '%s\n' "$@" > "$CONFIG"
}

write_files() {
  printf '%s\n' "$@" > "$FILES"
}

# ── RED phase 1: script exists and is executable ─────────────────────────────

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# ── RED phase 2: docs/** -> documentation ────────────────────────────────────

@test "docs/ path gets documentation label" {
  write_config "docs/**:documentation"
  write_files "docs/README.md" "docs/api/guide.md"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  [[ "$output" == *"documentation"* ]]
}

@test "non-docs path does not get documentation label" {
  write_config "docs/**:documentation"
  write_files "src/main.sh"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  [[ "$output" != *"documentation"* ]]
}

# ── RED phase 3: src/api/** -> api ───────────────────────────────────────────

@test "src/api/ path gets api label" {
  write_config "src/api/**:api"
  write_files "src/api/routes.sh" "src/api/auth.sh"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  [[ "$output" == *"api"* ]]
}

# ── RED phase 4: *.test.* -> tests ───────────────────────────────────────────

@test "test files get tests label" {
  write_config "*.test.*:tests"
  write_files "src/util.test.sh" "lib/parser.test.js"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tests"* ]]
}

# ── RED phase 5: multiple labels from different files ────────────────────────

@test "multiple files produce multiple labels" {
  write_config "docs/**:documentation" "src/api/**:api"
  write_files "docs/guide.md" "src/api/routes.sh"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  [[ "$output" == *"documentation"* ]]
  [[ "$output" == *"api"* ]]
}

# ── RED phase 6: deduplication ───────────────────────────────────────────────

@test "duplicate labels are not repeated" {
  write_config "docs/**:documentation"
  write_files "docs/a.md" "docs/b.md"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  # Count occurrences of "documentation" in output
  count=$(echo "$output" | grep -o "documentation" | wc -l)
  [ "$count" -eq 1 ]
}

# ── RED phase 7: multiple labels per file ────────────────────────────────────

@test "one file can match multiple rules" {
  write_config "src/**:source" "*.test.*:tests"
  write_files "src/util.test.sh"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  [[ "$output" == *"source"* ]]
  [[ "$output" == *"tests"* ]]
}

# ── RED phase 8: priority ordering ───────────────────────────────────────────

@test "priority: first matching rule wins for conflicting labels when --priority flag used" {
  # With priority mode, if two rules match same file, both labels still added
  # but output order reflects rule order (priority)
  write_config "src/api/**:api" "src/**:source"
  write_files "src/api/routes.sh"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES" --priority
  [ "$status" -eq 0 ]
  # api rule has higher priority (listed first), both labels present
  [[ "$output" == *"api"* ]]
  # In priority mode, the first label in output should be 'api'
  first_label=$(echo "$output" | tr ',' '\n' | head -1 | tr -d ' \n')
  [ "$first_label" = "api" ]
}

# ── RED phase 9: no matches = empty output ───────────────────────────────────

@test "no matching rules yields empty label set" {
  write_config "docs/**:documentation"
  write_files "src/main.sh"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  [ -z "$(echo "$output" | tr -d '[:space:]')" ]
}

# ── RED phase 10: error handling ─────────────────────────────────────────────

@test "missing config file exits with error" {
  run "$SCRIPT" --config /nonexistent/rules.conf --files "$FILES"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
}

@test "missing files list exits with error" {
  write_config "docs/**:documentation"
  run "$SCRIPT" --config "$CONFIG" --files /nonexistent/files.txt
  [ "$status" -ne 0 ]
}

# ── RED phase 11: mock/builtin file list ─────────────────────────────────────

@test "builtin mock file list works without --files flag" {
  write_config "docs/**:documentation" "src/api/**:api" "*.test.*:tests"
  run "$SCRIPT" --config "$CONFIG" --mock
  [ "$status" -eq 0 ]
  # Mock list contains docs, api, and test files
  [[ "$output" == *"documentation"* ]]
  [[ "$output" == *"api"* ]]
  [[ "$output" == *"tests"* ]]
}

# ── RED phase 12: glob patterns with ** and * ────────────────────────────────

@test "single wildcard matches in directory" {
  write_config "src/*.sh:shell"
  write_files "src/main.sh"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  [[ "$output" == *"shell"* ]]
}

@test "single wildcard does not match subdirectory" {
  write_config "src/*.sh:shell"
  write_files "src/lib/utils.sh"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  [[ "$output" != *"shell"* ]]
}

@test "double wildcard matches nested paths" {
  write_config "src/**/*.sh:shell"
  write_files "src/lib/utils.sh" "src/deep/nested/file.sh"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  [[ "$output" == *"shell"* ]]
}

# ── RED phase 13: output format ──────────────────────────────────────────────

@test "labels are output as comma-separated on one line" {
  write_config "docs/**:documentation" "src/**:source"
  write_files "docs/guide.md" "src/main.sh"
  run "$SCRIPT" --config "$CONFIG" --files "$FILES"
  [ "$status" -eq 0 ]
  # Output should be a single line with labels separated by commas
  line_count=$(echo "$output" | grep -c '.' || true)
  [ "$line_count" -eq 1 ]
  [[ "$output" == *","* ]]
}
