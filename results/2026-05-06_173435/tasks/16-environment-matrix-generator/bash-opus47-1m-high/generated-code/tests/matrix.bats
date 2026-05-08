#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Tests for the environment matrix generator.
# Each test feeds a JSON config to ./generate-matrix.sh and asserts on the
# resulting matrix JSON or the script's error behavior.
#
# We use `run --separate-stderr` so that $output holds only stdout (the
# emitted strategy JSON, parseable by jq) and $stderr holds the size= /
# error lines.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../generate-matrix.sh"
    TMPDIR_T="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMPDIR_T"
}

# --- 1. Basic axes -----------------------------------------------------------

@test "basic: simple axes produce matrix block with all axes" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{
  "axes": {
    "os": ["ubuntu-latest", "macos-latest"],
    "node": ["18", "20"]
  }
}
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.matrix.os | length == 2' >/dev/null
    echo "$output" | jq -e '.matrix.node | length == 2' >/dev/null
}

@test "basic: prints expanded combination count to stderr" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{
  "axes": {
    "os": ["ubuntu-latest", "macos-latest"],
    "node": ["18", "20"]
  }
}
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"size=4"* ]]
}

# --- 2. fail-fast and max-parallel pass-through -----------------------------

@test "options: fail-fast and max-parallel are passed through" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{
  "axes": { "os": ["ubuntu-latest"] },
  "fail-fast": false,
  "max-parallel": 4
}
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '."fail-fast" == false' >/dev/null
    echo "$output" | jq -e '."max-parallel" == 4' >/dev/null
}

@test "options: defaults are fail-fast=true and no max-parallel" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{ "axes": { "os": ["ubuntu-latest"] } }
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '."fail-fast" == true' >/dev/null
    echo "$output" | jq -e 'has("max-parallel") | not' >/dev/null
}

# --- 3. exclude rules --------------------------------------------------------

@test "exclude: a rule removes one combination from the count" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{
  "axes": {
    "os": ["ubuntu-latest", "macos-latest"],
    "node": ["18", "20"]
  },
  "exclude": [
    { "os": "macos-latest", "node": "18" }
  ]
}
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"size=3"* ]]
    echo "$output" | jq -e '.matrix.exclude | length == 1' >/dev/null
}

@test "exclude: a partial rule (single key) removes all matching combos" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{
  "axes": {
    "os": ["ubuntu-latest", "macos-latest"],
    "node": ["18", "20"]
  },
  "exclude": [ { "os": "macos-latest" } ]
}
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"size=2"* ]]
}

# --- 4. include rules --------------------------------------------------------

@test "include: appends extra combinations to size" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{
  "axes": { "os": ["ubuntu-latest"], "node": ["20"] },
  "include": [
    { "os": "windows-latest", "node": "20" }
  ]
}
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"size=2"* ]]
    echo "$output" | jq -e '.matrix.include | length == 1' >/dev/null
}

# --- 5. max-size validation --------------------------------------------------

@test "max-size: fails when matrix size exceeds limit" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{
  "axes": {
    "os": ["a", "b", "c"],
    "node": ["1", "2", "3"]
  },
  "max-size": 5
}
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"exceeds max-size"* ]]
}

@test "max-size: passes when matrix size is at limit" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{
  "axes": { "os": ["a", "b"], "node": ["1", "2"] },
  "max-size": 4
}
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -eq 0 ]
}

# --- 6. error handling -------------------------------------------------------

@test "error: missing config flag prints usage" {
    run --separate-stderr "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"Usage"* ]]
}

@test "error: missing file prints clear error" {
    run --separate-stderr "$SCRIPT" --config /nonexistent/file.json
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"not found"* ]]
}

@test "error: invalid JSON prints clear error" {
    echo "not json {" > "$TMPDIR_T/bad.json"
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/bad.json"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"invalid JSON"* ]]
}

@test "error: missing axes key prints clear error" {
    echo '{}' > "$TMPDIR_T/empty.json"
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/empty.json"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"axes"* ]]
}

# --- 7. feature flags axis ---------------------------------------------------

@test "axes: feature flag axis is included like any other" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{
  "axes": {
    "os": ["ubuntu-latest"],
    "node": ["20"],
    "feature": ["with-tls", "no-tls"]
  }
}
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.matrix.feature | length == 2' >/dev/null
    [[ "$stderr" == *"size=2"* ]]
}

# --- 8. full GH Actions strategy block ---------------------------------------

@test "shape: top-level keys are exactly fail-fast, matrix (and optionally max-parallel)" {
    cat > "$TMPDIR_T/config.json" <<'EOF'
{
  "axes": { "os": ["ubuntu-latest"] },
  "max-parallel": 2
}
EOF
    run --separate-stderr "$SCRIPT" --config "$TMPDIR_T/config.json"
    [ "$status" -eq 0 ]
    keys="$(echo "$output" | jq -r 'keys | sort | join(",")')"
    [ "$keys" = "fail-fast,matrix,max-parallel" ]
}
