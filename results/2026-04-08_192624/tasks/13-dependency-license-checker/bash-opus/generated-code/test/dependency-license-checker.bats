#!/usr/bin/env bats
# Tests for dependency-license-checker.sh
# Covers: argument validation, package.json parsing, requirements.txt parsing,
# license classification (approved/denied/unknown), report output, exit codes.

SCRIPT="./dependency-license-checker.sh"
FIXTURES="./test/fixtures"

# ── Error handling tests ─────────────────────────────────────────────────────

@test "errors when --manifest is missing" {
  run "$SCRIPT" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Missing --manifest"* ]]
}

@test "errors when --config is missing" {
  run "$SCRIPT" --manifest "$FIXTURES/package.json" --license-db "$FIXTURES/mock-licenses.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Missing --config"* ]]
}

@test "errors when --license-db is missing" {
  run "$SCRIPT" --manifest "$FIXTURES/package.json" --config "$FIXTURES/license-config.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Missing --license-db"* ]]
}

@test "errors when manifest file does not exist" {
  run "$SCRIPT" --manifest "/nonexistent.json" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Manifest not found"* ]]
}

@test "errors on unsupported manifest type" {
  local tmp
  tmp="$(mktemp --suffix=.toml)"
  echo '[deps]' > "$tmp"
  run "$SCRIPT" --manifest "$tmp" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  rm -f "$tmp"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unsupported manifest type"* ]]
}

# ── package.json tests ───────────────────────────────────────────────────────

@test "package.json: parses all dependencies including devDependencies" {
  run "$SCRIPT" --manifest "$FIXTURES/package.json" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [[ "$output" == *"express"* ]]
  [[ "$output" == *"lodash"* ]]
  [[ "$output" == *"left-pad"* ]]
  [[ "$output" == *"jest"* ]]
  [[ "$output" == *"Total: 4"* ]]
}

@test "package.json: correctly classifies MIT as approved" {
  run "$SCRIPT" --manifest "$FIXTURES/package.json" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [[ "$output" == *"express"*"MIT"*"approved"* ]]
  [[ "$output" == *"lodash"*"MIT"*"approved"* ]]
}

@test "package.json: classifies unlisted license as unknown" {
  run "$SCRIPT" --manifest "$FIXTURES/package.json" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [[ "$output" == *"left-pad"*"WTFPL"*"unknown"* ]]
}

@test "package.json: exit code 0 when no denied deps" {
  run "$SCRIPT" --manifest "$FIXTURES/package.json" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [ "$status" -eq 0 ]
}

@test "package.json: summary counts are correct" {
  run "$SCRIPT" --manifest "$FIXTURES/package.json" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [[ "$output" == *"Approved: 3"* ]]
  [[ "$output" == *"Denied: 0"* ]]
  [[ "$output" == *"Unknown: 1"* ]]
}

# ── requirements.txt tests ───────────────────────────────────────────────────

@test "requirements.txt: parses all dependencies" {
  run "$SCRIPT" --manifest "$FIXTURES/requirements.txt" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [[ "$output" == *"requests"* ]]
  [[ "$output" == *"flask"* ]]
  [[ "$output" == *"numpy"* ]]
  [[ "$output" == *"cryptography"* ]]
  [[ "$output" == *"Total: 4"* ]]
}

@test "requirements.txt: classifies GPL-3.0 as denied" {
  run "$SCRIPT" --manifest "$FIXTURES/requirements.txt" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [[ "$output" == *"cryptography"*"GPL-3.0"*"denied"* ]]
}

@test "requirements.txt: exit code 1 when denied deps exist" {
  run "$SCRIPT" --manifest "$FIXTURES/requirements.txt" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [ "$status" -eq 1 ]
}

@test "requirements.txt: summary counts are correct" {
  run "$SCRIPT" --manifest "$FIXTURES/requirements.txt" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  [[ "$output" == *"Approved: 3"* ]]
  [[ "$output" == *"Denied: 1"* ]]
  [[ "$output" == *"Unknown: 0"* ]]
}

# ── JSON output format ───────────────────────────────────────────────────────

@test "json format: produces valid structure" {
  run "$SCRIPT" --manifest "$FIXTURES/package.json" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"summary"'* ]]
  [[ "$output" == *'"dependencies"'* ]]
  [[ "$output" == *'"total": 4'* ]]
  [[ "$output" == *'"approved": 3'* ]]
}

@test "json format: contains dependency entries" {
  run "$SCRIPT" --manifest "$FIXTURES/package.json" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json" --format json
  [[ "$output" == *'"name": "express"'* ]]
  [[ "$output" == *'"license": "MIT"'* ]]
  [[ "$output" == *'"status": "approved"'* ]]
}

# ── All-approved scenario ────────────────────────────────────────────────────

@test "all-approved: exit code 0 and correct counts" {
  # Create a manifest with only approved-license deps
  local tmpdir
  tmpdir="$(mktemp -d)"
  cat > "$tmpdir/package.json" <<'MANIFEST'
{
  "dependencies": {
    "express": "4.18.2",
    "lodash": "4.17.21"
  }
}
MANIFEST
  run "$SCRIPT" --manifest "$tmpdir/package.json" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Approved: 2"* ]]
  [[ "$output" == *"Denied: 0"* ]]
  [[ "$output" == *"Unknown: 0"* ]]
}

# ── Unknown dependency (not in license DB) ───────────────────────────────────

@test "unknown dep: dependency not in license DB gets UNKNOWN license" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  cat > "$tmpdir/requirements.txt" <<'MANIFEST'
mystery-pkg==1.0.0
MANIFEST
  run "$SCRIPT" --manifest "$tmpdir/requirements.txt" --config "$FIXTURES/license-config.json" --license-db "$FIXTURES/mock-licenses.json"
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mystery-pkg"*"UNKNOWN"*"unknown"* ]]
}
