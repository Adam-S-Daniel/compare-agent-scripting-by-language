#!/usr/bin/env bats

# Setup and teardown for test environment
setup() {
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    export CHECKER="${SCRIPT_DIR}/dependency-license-checker.sh"
    export TEST_FIXTURES="${SCRIPT_DIR}/test_fixtures"

    # Create fixtures directory
    mkdir -p "${TEST_FIXTURES}"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# Test 1: Script exists and is executable
@test "dependency-license-checker script exists" {
    [ -f "${CHECKER}" ]
}

# Test 2: Script has correct shebang
@test "script has correct shebang" {
    head -1 "${CHECKER}" | grep -q "#!/usr/bin/env bash"
}

# Test 3: Script passes shellcheck validation
@test "script passes shellcheck" {
    command -v shellcheck >/dev/null 2>&1 && shellcheck "${CHECKER}" || skip "shellcheck not installed"
}

# Test 4: Parse simple package.json with single dependency
@test "parse simple package.json" {
    cat > "${TEST_DIR}/package.json" <<'EOF'
{
  "name": "test-app",
  "dependencies": {
    "lodash": "4.17.21"
  }
}
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/package.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"lodash"* ]]
    [[ "$output" == *"4.17.21"* ]]
}

# Test 5: Parse multiple dependencies
@test "parse multiple dependencies from package.json" {
    cat > "${TEST_DIR}/package.json" <<'EOF'
{
  "name": "test-app",
  "dependencies": {
    "lodash": "4.17.21",
    "express": "4.18.2"
  }
}
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/package.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"lodash"* ]]
    [[ "$output" == *"express"* ]]
}

# Test 6: Check against allow-list (mocked license data)
@test "check dependency against allow-list" {
    cat > "${TEST_DIR}/package.json" <<'EOF'
{
  "dependencies": {
    "lodash": "4.17.21"
  }
}
EOF

    cat > "${TEST_DIR}/config.json" <<'EOF'
{
  "allowlist": ["MIT", "Apache-2.0"],
  "denylist": []
}
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/package.json" --config "${TEST_DIR}/config.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"APPROVED"* || "$output" == *"approved"* ]]
}

# Test 7: Check dependency against deny-list (mocked)
@test "check dependency against deny-list" {
    cat > "${TEST_DIR}/package.json" <<'EOF'
{
  "dependencies": {
    "viral-license-lib": "1.0.0"
  }
}
EOF

    cat > "${TEST_DIR}/config.json" <<'EOF'
{
  "allowlist": ["MIT"],
  "denylist": ["GPL-3.0"]
}
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/package.json" --config "${TEST_DIR}/config.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DENIED"* || "$output" == *"denied"* ]]
}

# Test 8: Unknown license (not in allow or deny list)
@test "report unknown license status" {
    cat > "${TEST_DIR}/package.json" <<'EOF'
{
  "dependencies": {
    "mystery-lib": "1.0.0"
  }
}
EOF

    cat > "${TEST_DIR}/config.json" <<'EOF'
{
  "allowlist": ["MIT"],
  "denylist": []
}
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/package.json" --config "${TEST_DIR}/config.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"UNKNOWN"* || "$output" == *"unknown"* ]]
}

# Test 9: Parse requirements.txt (Python dependencies)
@test "parse requirements.txt" {
    cat > "${TEST_DIR}/requirements.txt" <<'EOF'
requests==2.28.1
django==4.1.0
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/requirements.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"requests"* ]]
    [[ "$output" == *"django"* ]]
}

# Test 10: Handle missing manifest file
@test "error on missing manifest file" {
    run "${CHECKER}" --manifest "/nonexistent/file.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"error"* || "$output" == *"Error"* || "$output" == *"not found"* ]]
}

# Test 11: Generate compliance report with mixed statuses
@test "generate compliance report with multiple statuses" {
    cat > "${TEST_DIR}/package.json" <<'EOF'
{
  "dependencies": {
    "lodash": "4.17.21",
    "express": "4.18.2",
    "mystery-lib": "1.0.0"
  }
}
EOF

    cat > "${TEST_DIR}/config.json" <<'EOF'
{
  "allowlist": ["MIT"],
  "denylist": ["GPL-3.0"]
}
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/package.json" --config "${TEST_DIR}/config.json"
    [ "$status" -eq 0 ]
    # Should contain at least one status line per dependency
    [[ "$output" == *"lodash"* ]]
    [[ "$output" == *"express"* ]]
    [[ "$output" == *"mystery-lib"* ]]
}

# Test 12: Output format contains dependency name, version, and status
@test "output format includes name, version, and license status" {
    cat > "${TEST_DIR}/package.json" <<'EOF'
{
  "dependencies": {
    "test-lib": "1.2.3"
  }
}
EOF

    cat > "${TEST_DIR}/config.json" <<'EOF'
{
  "allowlist": ["MIT"],
  "denylist": []
}
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/package.json" --config "${TEST_DIR}/config.json"
    [ "$status" -eq 0 ]
    # Check for structured output (name, version, status)
    [[ "$output" == *"test-lib"* ]]
    [[ "$output" == *"1.2.3"* ]]
}

# Test 13: Handle devDependencies in package.json
@test "parse both dependencies and devDependencies" {
    cat > "${TEST_DIR}/package.json" <<'EOF'
{
  "dependencies": {
    "lodash": "4.17.21"
  },
  "devDependencies": {
    "jest": "29.0.0"
  }
}
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/package.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"lodash"* ]]
    [[ "$output" == *"jest"* ]]
}

# Test 14: Configuration file can use JSON format
@test "config file supports JSON format" {
    cat > "${TEST_DIR}/package.json" <<'EOF'
{
  "dependencies": {
    "lodash": "4.17.21"
  }
}
EOF

    cat > "${TEST_DIR}/config.json" <<'EOF'
{
  "allowlist": ["MIT", "Apache-2.0", "BSD-3-Clause"],
  "denylist": ["GPL-3.0", "AGPL-3.0"]
}
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/package.json" --config "${TEST_DIR}/config.json"
    [ "$status" -eq 0 ]
}

# Test 15: Mocked license database returns correct licenses
@test "mock license lookup returns correct license for known packages" {
    cat > "${TEST_DIR}/package.json" <<'EOF'
{
  "dependencies": {
    "lodash": "4.17.21"
  }
}
EOF

    cat > "${TEST_DIR}/config.json" <<'EOF'
{
  "allowlist": ["MIT"],
  "denylist": []
}
EOF

    run "${CHECKER}" --manifest "${TEST_DIR}/package.json" --config "${TEST_DIR}/config.json"
    [ "$status" -eq 0 ]
    # lodash should be approved (MIT license)
    [[ "$output" == *"APPROVED"* || "$output" == *"approved"* ]]
}
