#!/usr/bin/env bats
# Test suite for the PR label assigner script
# Uses TDD methodology: write failing tests first, then implement

setup() {
  export SCRIPT="$BATS_TEST_DIRNAME/../label-assigner.sh"
  export TEST_FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  mkdir -p "$TEST_FIXTURES"
}

# Test 1: Script should exist
@test "script exists" {
  [ -f "$SCRIPT" ]
}

# Test 2: Script should have correct shebang
@test "script has correct shebang" {
  head -1 "$SCRIPT" | grep -q "#!/usr/bin/env bash"
}

# Test 3: Script should pass shellcheck
@test "script passes shellcheck" {
  shellcheck "$SCRIPT"
}

# Test 4: Script should pass bash -n syntax check
@test "script passes bash -n syntax check" {
  bash -n "$SCRIPT"
}

# Test 5: Basic invocation with no files should output empty label set
@test "no files returns empty output" {
  output=$("$SCRIPT")
  [ -z "$output" ]
}

# Test 6: Single file matching single pattern should return single label
@test "single file with single matching pattern" {
  output=$("$SCRIPT" --config <(cat <<'EOF'
docs/readme.md:documentation
EOF
) <<< "docs/readme.md")
  [ "$output" = "documentation" ]
}

# Test 7: Glob pattern should match multiple files
@test "glob pattern matches multiple files" {
  output=$("$SCRIPT" --config <(cat <<'EOF'
src/api/**:api
EOF
) <<'EOF'
src/api/users.js
src/api/posts.js
EOF
)
  [ "$output" = "api" ]
}

# Test 8: File matching multiple patterns should return multiple labels
@test "file matching multiple patterns returns multiple labels sorted" {
  output=$("$SCRIPT" --config <(cat <<'EOF'
src/**:core
*.js:javascript
EOF
) <<< "src/index.js")
  [ "$output" = "core
javascript" ]
}

# Test 9: Non-matching file should not produce output
@test "non-matching file produces no output" {
  output=$("$SCRIPT" --config <(cat <<'EOF'
docs/**:documentation
EOF
) <<< "src/app.js")
  [ -z "$output" ]
}

# Test 10: Priority ordering - first matching rule wins on conflict
@test "priority ordering: first matching rule wins" {
  output=$("$SCRIPT" --config <(cat <<'EOF'
*.js:javascript
src/**:core
EOF
) <<< "src/app.js")
  [ "$output" = "core
javascript" ]
}

# Test 11: Duplicate labels should be deduplicated
@test "duplicate labels are removed" {
  output=$("$SCRIPT" --config <(cat <<'EOF'
src/**:core
*.js:core
EOF
) <<< "src/app.js")
  [ "$output" = "core" ]
}

# Test 12: Test files should get 'tests' label
@test "test files get tests label" {
  output=$("$SCRIPT" --config <(cat <<'EOF'
*.test.*:tests
*.spec.*:tests
EOF
) <<< "app.test.js")
  [ "$output" = "tests" ]
}

# Test 13: Multiple files with different patterns
@test "multiple files with different patterns" {
  output=$("$SCRIPT" --config <(cat <<'EOF'
docs/**:documentation
src/api/**:api
*.test.*:tests
EOF
) <<'EOF'
docs/readme.md
src/api/users.js
app.test.js
EOF
)
  expected="api
documentation
tests"
  [ "$output" = "$expected" ]
}

# Test 14: Invalid config should error gracefully
@test "invalid config file produces error" {
  run "$SCRIPT" --config /nonexistent/config
  [ $status -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"not found"* ]]
}

# Test 15: Empty file list with valid config
@test "empty file list returns nothing" {
  output=$("$SCRIPT" --config <(cat <<'EOF'
docs/**:documentation
EOF
) <<'EOF'
EOF
)
  [ -z "$output" ]
}
