#!/usr/bin/env bats

# Tests for pr-label-assigner.sh
# Approach: feed mock changed-file lists and a label config to the script,
# then assert the output matches the expected label set.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../pr-label-assigner.sh"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ---------------------------------------------------------------------------
# Smoke / CLI
# ---------------------------------------------------------------------------

@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "prints help with --help" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--config"* ]]
  [[ "$output" == *"--files"* ]]
}

@test "errors when --config is missing" {
  echo "src/foo.js" > "$TMPDIR_TEST/files.txt"
  run "$SCRIPT" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--config"* ]]
}

@test "errors when config file does not exist" {
  echo "src/foo.js" > "$TMPDIR_TEST/files.txt"
  run "$SCRIPT" --config "$TMPDIR_TEST/missing.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"missing.conf"* ]]
}

# ---------------------------------------------------------------------------
# Basic matching
# ---------------------------------------------------------------------------

@test "matches a single file to a single label" {
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
docs/**:documentation
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
docs/readme.md
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "documentation" ]
}

@test "deduplicates labels across multiple files" {
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
docs/**:documentation
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
docs/a.md
docs/b.md
docs/sub/c.md
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "documentation" ]
}

@test "matches multiple distinct labels for different files" {
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
docs/**:documentation
src/api/**:api
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
docs/readme.md
src/api/users.go
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -eq 0 ]
  # Output is sorted, newline-separated
  expected=$'api\ndocumentation'
  [ "$output" = "$expected" ]
}

# ---------------------------------------------------------------------------
# Glob pattern semantics
# ---------------------------------------------------------------------------

@test "single-star does not cross slashes" {
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
src/*.js:shallow-js
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
src/index.js
src/sub/deep.js
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -eq 0 ]
  # Only the top-level src/index.js should match
  [ "$output" = "shallow-js" ]
}

@test "double-star crosses slashes" {
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
src/**/*.js:any-js
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
src/index.js
src/sub/deep.js
src/a/b/c.js
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "any-js" ]
}

@test "test-file glob matches *.test.* anywhere" {
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
**/*.test.*:tests
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
src/foo.test.js
lib/bar.test.ts
src/no_match.js
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "tests" ]
}

# ---------------------------------------------------------------------------
# Multiple labels per rule
# ---------------------------------------------------------------------------

@test "comma-separated labels in a single rule are all assigned" {
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
src/api/**:api,backend
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
src/api/users.go
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -eq 0 ]
  expected=$'api\nbackend'
  [ "$output" = "$expected" ]
}

@test "a file that matches multiple rules gets the union of labels" {
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
src/**/*.go:go
src/api/**:api
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
src/api/users.go
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -eq 0 ]
  expected=$'api\ngo'
  [ "$output" = "$expected" ]
}

# ---------------------------------------------------------------------------
# Priority ordering (when same label specified multiple times w/ different priorities)
# ---------------------------------------------------------------------------

@test "priority field overrides earlier rule for same label" {
  # Two rules emit the same label "x" — both apply, dedup keeps it; priority
  # determines emission order vs other labels.
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
src/**:b-label:50
docs/**:a-label:10
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
src/x.js
docs/y.md
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt" --order priority
  [ "$status" -eq 0 ]
  # Lower priority number = higher priority, emitted first
  expected=$'a-label\nb-label'
  [ "$output" = "$expected" ]
}

# ---------------------------------------------------------------------------
# Configuration robustness
# ---------------------------------------------------------------------------

@test "ignores blank lines and comments in config" {
  cat > "$TMPDIR_TEST/labels.conf" <<'EOF'
# this is a comment
docs/**:documentation

# another comment
src/api/**:api
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
docs/r.md
src/api/x.go
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -eq 0 ]
  expected=$'api\ndocumentation'
  [ "$output" = "$expected" ]
}

@test "no matching rule produces no output and succeeds" {
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
docs/**:documentation
EOF
  cat > "$TMPDIR_TEST/files.txt" <<EOF
src/main.c
EOF
  run "$SCRIPT" --config "$TMPDIR_TEST/labels.conf" --files "$TMPDIR_TEST/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "reads file list from stdin when --files is -" {
  cat > "$TMPDIR_TEST/labels.conf" <<EOF
docs/**:documentation
EOF
  run bash -c "echo 'docs/x.md' | '$SCRIPT' --config '$TMPDIR_TEST/labels.conf' --files -"
  [ "$status" -eq 0 ]
  [ "$output" = "documentation" ]
}
