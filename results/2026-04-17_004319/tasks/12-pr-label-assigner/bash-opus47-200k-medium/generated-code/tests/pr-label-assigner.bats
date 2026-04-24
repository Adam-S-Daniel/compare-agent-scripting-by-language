#!/usr/bin/env bats
# Tests for pr-label-assigner.sh

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../pr-label-assigner.sh"
  TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR"
}

# --- Basic usage / errors ---

@test "prints usage when no args given" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "errors when rules file missing" {
  echo "x" > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/missing.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"rules file not found"* ]]
}

@test "errors when files list missing" {
  echo "x|y" > "$TMPDIR/rules.conf"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/missing.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"files list not found"* ]]
}

# --- Matching ---

@test "matches a simple exact path" {
  printf 'README.md|documentation\n' > "$TMPDIR/rules.conf"
  printf 'README.md\n' > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "documentation" ]
}

@test "matches a recursive ** glob across subdirectories" {
  printf 'docs/**|documentation\n' > "$TMPDIR/rules.conf"
  printf 'docs/guide/intro.md\ndocs/readme.md\nsrc/main.go\n' > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "documentation" ]
}

@test "matches single-segment * glob but not across slashes" {
  printf 'src/*|top-src\n' > "$TMPDIR/rules.conf"
  printf 'src/main.go\nsrc/pkg/util.go\n' > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "top-src" ]
}

@test "matches .test. middle-of-path glob pattern" {
  printf '**/*.test.*|tests\n' > "$TMPDIR/rules.conf"
  printf 'src/api/user.test.go\nsrc/api/user.go\n' > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "tests" ]
}

@test "applies multiple labels when several rules match one file" {
  cat > "$TMPDIR/rules.conf" <<EOF
src/api/**|api
**/*.test.*|tests
EOF
  printf 'src/api/user.test.go\n' > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  # Both labels expected, alphabetical default ordering
  [[ "$output" == *"api"* ]]
  [[ "$output" == *"tests"* ]]
}

@test "deduplicates labels across matching files" {
  printf 'docs/**|documentation\n' > "$TMPDIR/rules.conf"
  printf 'docs/a.md\ndocs/b.md\ndocs/c/d.md\n' > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 1 ]
  [ "$output" = "documentation" ]
}

@test "ignores blank lines and # comments in rules" {
  cat > "$TMPDIR/rules.conf" <<EOF
# this is a comment

docs/**|documentation
# another comment
EOF
  printf 'docs/x.md\n' > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "documentation" ]
}

@test "priority ordering: lower priority number appears first" {
  cat > "$TMPDIR/rules.conf" <<EOF
**/*.test.*|tests|50
src/api/**|api|10
docs/**|documentation|90
EOF
  printf 'src/api/u.go\nsrc/api/u.test.go\ndocs/readme.md\n' > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  # Expect api(10), tests(50), documentation(90)
  expected="$(printf 'api\ntests\ndocumentation')"
  [ "$output" = "$expected" ]
}

@test "no matching rules produces empty output" {
  printf 'nothing/*|nope\n' > "$TMPDIR/rules.conf"
  printf 'src/main.go\n' > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "handles file paths with special regex chars safely" {
  printf 'a.b/**|special\n' > "$TMPDIR/rules.conf"
  # a.b should match literally; axb should NOT match
  printf 'a.b/c.txt\naxb/c.txt\n' > "$TMPDIR/files.txt"
  run bash "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "special" ]
}
