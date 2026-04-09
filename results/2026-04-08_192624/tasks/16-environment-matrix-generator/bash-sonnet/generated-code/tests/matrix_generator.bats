#!/usr/bin/env bats
# Tests for environment matrix generator
# TDD approach: tests written first, then implementation

# Setup: make script available
SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/matrix_generator.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

setup() {
    # Ensure fixtures directory exists
    mkdir -p "$FIXTURES_DIR"
}

# ============================================================
# TEST 1 (RED): Script exists and is executable
# ============================================================
@test "script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ============================================================
# TEST 2 (RED): Basic matrix generation from simple config
# ============================================================
@test "generates basic matrix from simple config" {
    cat > "$FIXTURES_DIR/simple.json" <<'EOF'
{
  "os": ["ubuntu-latest"],
  "language_versions": ["3.9"],
  "feature_flags": ["default"]
}
EOF
    run "$SCRIPT" "$FIXTURES_DIR/simple.json"
    [ "$status" -eq 0 ]
    # Output should be valid JSON
    echo "$output" | jq . > /dev/null
}

# ============================================================
# TEST 3 (RED): Matrix includes all combinations
# ============================================================
@test "generates correct number of combinations" {
    cat > "$FIXTURES_DIR/multi.json" <<'EOF'
{
  "os": ["ubuntu-latest", "windows-latest"],
  "language_versions": ["3.9", "3.10"],
  "feature_flags": ["default"]
}
EOF
    run "$SCRIPT" "$FIXTURES_DIR/multi.json"
    [ "$status" -eq 0 ]
    # 2 os * 2 versions * 1 flag = 4 combinations
    count=$(echo "$output" | jq '.include | length')
    [ "$count" -eq 4 ]
}

# ============================================================
# TEST 4 (RED): Matrix has correct structure for GitHub Actions
# ============================================================
@test "matrix has correct GitHub Actions structure" {
    cat > "$FIXTURES_DIR/structure.json" <<'EOF'
{
  "os": ["ubuntu-latest"],
  "language_versions": ["3.9"],
  "feature_flags": ["default"]
}
EOF
    run "$SCRIPT" "$FIXTURES_DIR/structure.json"
    [ "$status" -eq 0 ]
    # Must have include array
    has_include=$(echo "$output" | jq 'has("include")')
    [ "$has_include" = "true" ]
    # Each entry must have os, language_version, feature_flag
    os=$(echo "$output" | jq -r '.include[0].os')
    [ "$os" = "ubuntu-latest" ]
    version=$(echo "$output" | jq -r '.include[0].language_version')
    [ "$version" = "3.9" ]
    flag=$(echo "$output" | jq -r '.include[0].feature_flag')
    [ "$flag" = "default" ]
}

# ============================================================
# TEST 5 (RED): Exclude rules work correctly
# ============================================================
@test "exclude rules remove matching combinations" {
    cat > "$FIXTURES_DIR/exclude.json" <<'EOF'
{
  "os": ["ubuntu-latest", "windows-latest"],
  "language_versions": ["3.9", "3.10"],
  "feature_flags": ["default"],
  "exclude": [
    {"os": "windows-latest", "language_version": "3.9"}
  ]
}
EOF
    run "$SCRIPT" "$FIXTURES_DIR/exclude.json"
    [ "$status" -eq 0 ]
    # 2*2*1=4 minus 1 excluded = 3
    count=$(echo "$output" | jq '.include | length')
    [ "$count" -eq 3 ]
    # Verify the excluded combination is not present
    excluded=$(echo "$output" | jq '[.include[] | select(.os == "windows-latest" and .language_version == "3.9")] | length')
    [ "$excluded" -eq 0 ]
}

# ============================================================
# TEST 6 (RED): fail-fast configuration
# ============================================================
@test "fail-fast setting is included in output" {
    cat > "$FIXTURES_DIR/failfast.json" <<'EOF'
{
  "os": ["ubuntu-latest"],
  "language_versions": ["3.9"],
  "feature_flags": ["default"],
  "fail_fast": true
}
EOF
    run "$SCRIPT" "$FIXTURES_DIR/failfast.json"
    [ "$status" -eq 0 ]
    fail_fast=$(echo "$output" | jq '."fail-fast"')
    [ "$fail_fast" = "true" ]
}

# ============================================================
# TEST 7 (RED): max-parallel configuration
# ============================================================
@test "max-parallel setting is included in output" {
    cat > "$FIXTURES_DIR/maxparallel.json" <<'EOF'
{
  "os": ["ubuntu-latest"],
  "language_versions": ["3.9"],
  "feature_flags": ["default"],
  "max_parallel": 4
}
EOF
    run "$SCRIPT" "$FIXTURES_DIR/maxparallel.json"
    [ "$status" -eq 0 ]
    max_parallel=$(echo "$output" | jq '."max-parallel"')
    [ "$max_parallel" -eq 4 ]
}

# ============================================================
# TEST 8 (RED): Maximum matrix size validation
# ============================================================
@test "fails when matrix exceeds maximum size" {
    # Build a config that generates too many combinations (>256)
    # 5 os * 6 versions * 10 flags = 300 > 256
    python3 -c "
import json
config = {
    'os': ['ubuntu-latest','windows-latest','macos-latest','ubuntu-22.04','debian-latest'],
    'language_versions': ['3.8','3.9','3.10','3.11','3.12','3.13'],
    'feature_flags': ['f1','f2','f3','f4','f5','f6','f7','f8','f9','f10']
}
print(json.dumps(config))
" > "$FIXTURES_DIR/toobig.json"
    run "$SCRIPT" "$FIXTURES_DIR/toobig.json"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "exceed\|too large\|maximum\|limit"
}

# ============================================================
# TEST 9 (RED): Custom max size override
# ============================================================
@test "custom max_size config overrides default limit" {
    cat > "$FIXTURES_DIR/custommax.json" <<'EOF'
{
  "os": ["ubuntu-latest", "windows-latest"],
  "language_versions": ["3.9", "3.10", "3.11"],
  "feature_flags": ["default"],
  "max_size": 6
}
EOF
    run "$SCRIPT" "$FIXTURES_DIR/custommax.json"
    [ "$status" -eq 0 ]
    count=$(echo "$output" | jq '.include | length')
    [ "$count" -eq 6 ]
}

# ============================================================
# TEST 10 (RED): Error on missing required fields
# ============================================================
@test "fails with meaningful error on missing os field" {
    cat > "$FIXTURES_DIR/missing_os.json" <<'EOF'
{
  "language_versions": ["3.9"],
  "feature_flags": ["default"]
}
EOF
    run "$SCRIPT" "$FIXTURES_DIR/missing_os.json"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "os\|required\|missing"
}

# ============================================================
# TEST 11 (RED): Error on invalid JSON input
# ============================================================
@test "fails with meaningful error on invalid JSON" {
    echo "not valid json {{{" > "$FIXTURES_DIR/invalid.json"
    run "$SCRIPT" "$FIXTURES_DIR/invalid.json"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "invalid\|json\|parse\|error"
}

# ============================================================
# TEST 12 (RED): Include rules add extra combinations
# ============================================================
@test "include rules add extra combinations" {
    cat > "$FIXTURES_DIR/include_extra.json" <<'EOF'
{
  "os": ["ubuntu-latest"],
  "language_versions": ["3.9"],
  "feature_flags": ["default"],
  "include_extra": [
    {"os": "macos-latest", "language_version": "3.11", "feature_flag": "experimental"}
  ]
}
EOF
    run "$SCRIPT" "$FIXTURES_DIR/include_extra.json"
    [ "$status" -eq 0 ]
    # 1 base + 1 extra = 2
    count=$(echo "$output" | jq '.include | length')
    [ "$count" -eq 2 ]
    # Check the extra entry is present
    has_macos=$(echo "$output" | jq '[.include[] | select(.os == "macos-latest")] | length')
    [ "$has_macos" -eq 1 ]
}

# ============================================================
# TEST 13 (RED): Full featured matrix with all options
# ============================================================
@test "generates full matrix with all options" {
    cat > "$FIXTURES_DIR/full.json" <<'EOF'
{
  "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
  "language_versions": ["3.9", "3.10", "3.11"],
  "feature_flags": ["default", "experimental"],
  "exclude": [
    {"os": "windows-latest", "feature_flag": "experimental"}
  ],
  "include_extra": [
    {"os": "ubuntu-20.04", "language_version": "3.8", "feature_flag": "legacy"}
  ],
  "fail_fast": false,
  "max_parallel": 8,
  "max_size": 256
}
EOF
    run "$SCRIPT" "$FIXTURES_DIR/full.json"
    [ "$status" -eq 0 ]
    # Valid JSON
    echo "$output" | jq . > /dev/null
    # fail-fast present
    echo "$output" | jq 'has("fail-fast")' | grep -q "true" || { echo "Missing fail-fast in: $output" >&2; false; }
    # max-parallel present
    echo "$output" | jq 'has("max-parallel")' | grep -q "true" || { echo "Missing max-parallel in: $output" >&2; false; }
    # include array present
    echo "$output" | jq 'has("include")' | grep -q "true"
}

# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================

@test "workflow file exists" {
    [ -f "$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml" ]
}

@test "workflow has required triggers" {
    WORKFLOW="$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml"
    grep -q "push:" "$WORKFLOW"
    grep -q "pull_request:" "$WORKFLOW"
    grep -q "workflow_dispatch:" "$WORKFLOW"
}

@test "workflow references script correctly" {
    WORKFLOW="$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml"
    grep -q "matrix_generator.sh" "$WORKFLOW"
    [ -f "$SCRIPT_DIR/matrix_generator.sh" ]
}

@test "actionlint passes on workflow file" {
    run actionlint "$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml"
    [ "$status" -eq 0 ]
}

@test "workflow uses actions/checkout@v4" {
    WORKFLOW="$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml"
    grep -q "actions/checkout@v4" "$WORKFLOW"
}
