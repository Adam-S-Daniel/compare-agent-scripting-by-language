#!/usr/bin/env bats
# TDD tests for license-check.sh
# Validates parsing, license lookup, allow/deny classification, and report generation.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../license-check.sh"
  FIXTURES="${BATS_TEST_DIRNAME}/../fixtures"
  TMPDIR_T="$(mktemp -d)"
}

teardown() {
  rm -rf "${TMPDIR_T}"
}

@test "script exists and is executable" {
  [ -x "${SCRIPT}" ]
}

@test "prints usage when no args given" {
  run "${SCRIPT}"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "errors when manifest file missing" {
  run "${SCRIPT}" --manifest /nonexistent --licenses "${FIXTURES}/licenses.csv" \
    --allow "${FIXTURES}/allow.txt" --deny "${FIXTURES}/deny.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"manifest"* ]]
}

@test "parses simple manifest with approved license" {
  cat > "${TMPDIR_T}/req.txt" <<EOF
lodash==4.17.21
EOF
  run "${SCRIPT}" --manifest "${TMPDIR_T}/req.txt" --licenses "${FIXTURES}/licenses.csv" \
    --allow "${FIXTURES}/allow.txt" --deny "${FIXTURES}/deny.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lodash@4.17.21"* ]]
  [[ "$output" == *"MIT"* ]]
  [[ "$output" == *"APPROVED"* ]]
}

@test "detects denied license and exits nonzero" {
  cat > "${TMPDIR_T}/req.txt" <<EOF
badpkg==1.0.0
EOF
  run "${SCRIPT}" --manifest "${TMPDIR_T}/req.txt" --licenses "${FIXTURES}/licenses.csv" \
    --allow "${FIXTURES}/allow.txt" --deny "${FIXTURES}/deny.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"badpkg@1.0.0"* ]]
  [[ "$output" == *"GPL-3.0"* ]]
  [[ "$output" == *"DENIED"* ]]
}

@test "marks unknown when license not in db" {
  cat > "${TMPDIR_T}/req.txt" <<EOF
mystery==9.9.9
EOF
  run "${SCRIPT}" --manifest "${TMPDIR_T}/req.txt" --licenses "${FIXTURES}/licenses.csv" \
    --allow "${FIXTURES}/allow.txt" --deny "${FIXTURES}/deny.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"mystery@9.9.9"* ]]
  [[ "$output" == *"UNKNOWN"* ]]
}

@test "processes multi-package manifest and summary matches" {
  cat > "${TMPDIR_T}/req.txt" <<EOF
lodash==4.17.21
express==4.18.0
badpkg==1.0.0
mystery==9.9.9
EOF
  run "${SCRIPT}" --manifest "${TMPDIR_T}/req.txt" --licenses "${FIXTURES}/licenses.csv" \
    --allow "${FIXTURES}/allow.txt" --deny "${FIXTURES}/deny.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Total: 4"* ]]
  [[ "$output" == *"Approved: 2"* ]]
  [[ "$output" == *"Denied: 1"* ]]
  [[ "$output" == *"Unknown: 1"* ]]
}

@test "ignores blank lines and comments in manifest" {
  cat > "${TMPDIR_T}/req.txt" <<EOF
# comment line
lodash==4.17.21

# another comment
EOF
  run "${SCRIPT}" --manifest "${TMPDIR_T}/req.txt" --licenses "${FIXTURES}/licenses.csv" \
    --allow "${FIXTURES}/allow.txt" --deny "${FIXTURES}/deny.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total: 1"* ]]
}

@test "rejects malformed manifest entries with error" {
  cat > "${TMPDIR_T}/req.txt" <<EOF
lodash@@4.17.21
EOF
  run "${SCRIPT}" --manifest "${TMPDIR_T}/req.txt" --licenses "${FIXTURES}/licenses.csv" \
    --allow "${FIXTURES}/allow.txt" --deny "${FIXTURES}/deny.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"malformed"* || "$output" == *"invalid"* ]]
}
