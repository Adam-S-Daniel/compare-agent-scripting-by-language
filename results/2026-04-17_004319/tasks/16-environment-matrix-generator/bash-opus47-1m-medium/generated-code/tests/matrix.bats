#!/usr/bin/env bats
# Tests for environment matrix generator.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../generate-matrix.sh"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "script file exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "script passes shellcheck" {
  run shellcheck "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "errors on missing config file" {
  run "$SCRIPT" /no/such/file.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"No such"* ]]
}

@test "errors on invalid JSON" {
  echo "not json" > "$TMPDIR_TEST/bad.json"
  run "$SCRIPT" "$TMPDIR_TEST/bad.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid"* ]] || [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"parse"* ]]
}

@test "minimal axes produce cartesian product" {
  cat > "$TMPDIR_TEST/c.json" <<'EOF'
{ "axes": { "os": ["linux","mac"], "node": ["18","20"] } }
EOF
  run "$SCRIPT" "$TMPDIR_TEST/c.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.count')
  [ "$count" -eq 4 ]
}

@test "exclude removes matching combinations" {
  cat > "$TMPDIR_TEST/c.json" <<'EOF'
{ "axes": { "os": ["linux","mac"], "node": ["18","20"] },
  "exclude": [ { "os": "mac", "node": "18" } ] }
EOF
  run "$SCRIPT" "$TMPDIR_TEST/c.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.count')
  [ "$count" -eq 3 ]
}

@test "include adds extra combinations" {
  cat > "$TMPDIR_TEST/c.json" <<'EOF'
{ "axes": { "os": ["linux"], "node": ["20"] },
  "include": [ { "os": "windows", "node": "21", "extra": "yes" } ] }
EOF
  run "$SCRIPT" "$TMPDIR_TEST/c.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.count')
  [ "$count" -eq 2 ]
  has_extra=$(echo "$output" | jq '[.combinations[] | select(.extra=="yes")] | length')
  [ "$has_extra" -eq 1 ]
}

@test "max-parallel and fail-fast appear in output" {
  cat > "$TMPDIR_TEST/c.json" <<'EOF'
{ "axes": { "os": ["linux"] }, "max-parallel": 3, "fail-fast": false }
EOF
  run "$SCRIPT" "$TMPDIR_TEST/c.json"
  [ "$status" -eq 0 ]
  mp=$(echo "$output" | jq '."max-parallel"')
  [ "$mp" -eq 3 ]
  ff=$(echo "$output" | jq '."fail-fast"')
  [ "$ff" = "false" ]
}

@test "fail-fast defaults to true" {
  cat > "$TMPDIR_TEST/c.json" <<'EOF'
{ "axes": { "os": ["linux"] } }
EOF
  run "$SCRIPT" "$TMPDIR_TEST/c.json"
  [ "$status" -eq 0 ]
  ff=$(echo "$output" | jq '."fail-fast"')
  [ "$ff" = "true" ]
}

@test "max-size validation fails when exceeded" {
  cat > "$TMPDIR_TEST/c.json" <<'EOF'
{ "axes": { "a": ["1","2","3"], "b": ["1","2","3"] }, "max-size": 5 }
EOF
  run "$SCRIPT" "$TMPDIR_TEST/c.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"exceeds"* ]] || [[ "$output" == *"max-size"* ]]
}

@test "feature flags are included as axis" {
  cat > "$TMPDIR_TEST/c.json" <<'EOF'
{ "axes": { "os": ["linux"], "feature": ["fastpath","slowpath"] } }
EOF
  run "$SCRIPT" "$TMPDIR_TEST/c.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.count')
  [ "$count" -eq 2 ]
  features=$(echo "$output" | jq -r '[.combinations[].feature] | sort | join(",")')
  [ "$features" = "fastpath,slowpath" ]
}

@test "empty axes produce zero combinations" {
  cat > "$TMPDIR_TEST/c.json" <<'EOF'
{ "axes": {} }
EOF
  run "$SCRIPT" "$TMPDIR_TEST/c.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.count')
  [ "$count" -eq 0 ]
}
