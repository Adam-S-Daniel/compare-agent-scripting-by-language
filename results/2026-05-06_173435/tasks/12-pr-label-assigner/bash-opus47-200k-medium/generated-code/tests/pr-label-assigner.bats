#!/usr/bin/env bats

# Tests for pr-label-assigner.sh
# Approach: red/green TDD - each test exercises one behavior.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../pr-label-assigner.sh"
  TMP="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP"
}

# -------- usage / errors --------

@test "exits non-zero with usage when no args" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "errors when config file missing" {
  run "$SCRIPT" --config "$TMP/nope.cfg" --files "$TMP/files.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"config"* ]]
}

@test "errors when files list missing" {
  echo "10:docs/**:documentation" > "$TMP/cfg"
  run "$SCRIPT" --config "$TMP/cfg" --files "$TMP/missing"
  [ "$status" -ne 0 ]
  [[ "$output" == *"files"* ]]
}

# -------- core matching --------

@test "single rule matching a directory glob produces label" {
  cat > "$TMP/cfg" <<EOF
10:docs/**:documentation
EOF
  cat > "$TMP/files" <<EOF
docs/readme.md
EOF
  run "$SCRIPT" --config "$TMP/cfg" --files "$TMP/files"
  [ "$status" -eq 0 ]
  [ "$output" = "documentation" ]
}

@test "no match yields empty output" {
  echo "10:docs/**:documentation" > "$TMP/cfg"
  echo "src/main.go" > "$TMP/files"
  run "$SCRIPT" --config "$TMP/cfg" --files "$TMP/files"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "multiple files trigger multiple labels" {
  cat > "$TMP/cfg" <<EOF
10:docs/**:documentation
20:src/api/**:api
EOF
  cat > "$TMP/files" <<EOF
docs/x.md
src/api/users.go
EOF
  run "$SCRIPT" --config "$TMP/cfg" --files "$TMP/files"
  [ "$status" -eq 0 ]
  # Output sorted by priority desc; api(20) before documentation(10)
  [ "${lines[0]}" = "api" ]
  [ "${lines[1]}" = "documentation" ]
}

@test "duplicate labels are deduplicated" {
  cat > "$TMP/cfg" <<EOF
10:docs/**:documentation
EOF
  cat > "$TMP/files" <<EOF
docs/a.md
docs/b.md
docs/sub/c.md
EOF
  run "$SCRIPT" --config "$TMP/cfg" --files "$TMP/files"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l)" -eq 1 ]
  [ "$output" = "documentation" ]
}

@test "single file may receive multiple labels from different rules" {
  cat > "$TMP/cfg" <<EOF
30:src/api/**:api
20:**/*.go:go
10:src/**:source
EOF
  echo "src/api/users.go" > "$TMP/files"
  run "$SCRIPT" --config "$TMP/cfg" --files "$TMP/files"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "api" ]
  [ "${lines[1]}" = "go" ]
  [ "${lines[2]}" = "source" ]
}

@test "filename glob with *.test.* matches test files anywhere" {
  cat > "$TMP/cfg" <<EOF
10:**/*.test.*:tests
EOF
  cat > "$TMP/files" <<EOF
src/foo.test.js
lib/bar.test.ts
src/main.js
EOF
  run "$SCRIPT" --config "$TMP/cfg" --files "$TMP/files"
  [ "$status" -eq 0 ]
  [ "$output" = "tests" ]
}

@test "comments and blank lines in config are ignored" {
  cat > "$TMP/cfg" <<EOF
# this is a comment

10:docs/**:documentation
# another comment
EOF
  echo "docs/x.md" > "$TMP/files"
  run "$SCRIPT" --config "$TMP/cfg" --files "$TMP/files"
  [ "$status" -eq 0 ]
  [ "$output" = "documentation" ]
}

@test "priority ordering: higher priority labels come first" {
  cat > "$TMP/cfg" <<EOF
1:**/*.md:lowest
50:docs/**:documentation
5:**/*:any
EOF
  echo "docs/readme.md" > "$TMP/files"
  run "$SCRIPT" --config "$TMP/cfg" --files "$TMP/files"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "documentation" ]
  [ "${lines[1]}" = "any" ]
  [ "${lines[2]}" = "lowest" ]
}

@test "invalid config line produces error" {
  cat > "$TMP/cfg" <<EOF
not_a_valid_rule
EOF
  echo "x" > "$TMP/files"
  run "$SCRIPT" --config "$TMP/cfg" --files "$TMP/files"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid"* ]] || [[ "$output" == *"Invalid"* ]]
}
