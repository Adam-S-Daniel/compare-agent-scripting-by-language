#!/usr/bin/env bash
# Test harness: runs each test case through act and validates output
# Usage: bash run-tests.sh
# Produces act-result.txt with all act output, asserts on exact expected values

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
FAILURES=0
PASSES=0

# Clear result file
: > "$RESULT_FILE"

log() { echo "[run-tests] $*"; }
fail() { echo "[FAIL] $*" | tee -a "$RESULT_FILE"; FAILURES=$((FAILURES + 1)); }
pass() { echo "[PASS] $*" | tee -a "$RESULT_FILE"; PASSES=$((PASSES + 1)); }

# run_test_case <name> <fixture_file> <initial_version> <expected_version>
run_test_case() {
  local name="$1"
  local fixture="$2"
  local init_version="$3"
  local expected_version="$4"

  log "=== Test case: $name ==="
  echo "" >> "$RESULT_FILE"
  echo "========================================" >> "$RESULT_FILE"
  echo "TEST CASE: $name" >> "$RESULT_FILE"
  echo "fixture=$fixture  init_version=$init_version  expected=$expected_version" >> "$RESULT_FILE"
  echo "========================================" >> "$RESULT_FILE"

  # Create an isolated temp git repo for this test case
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" RETURN

  # Copy project files into temp repo
  cp -r "$SCRIPT_DIR/src" "$tmpdir/"
  cp -r "$SCRIPT_DIR/fixtures" "$tmpdir/"
  cp -r "$SCRIPT_DIR/.github" "$tmpdir/"
  cp "$SCRIPT_DIR/.actrc" "$tmpdir/"

  # Write a package.json with the specified initial version
  cat > "$tmpdir/package.json" <<EOF
{
  "name": "semantic-version-bumper",
  "version": "$init_version",
  "description": "Semantic version bumper using conventional commits",
  "scripts": {
    "test": "bun test",
    "bump": "bun run src/main.ts"
  },
  "devDependencies": {}
}
EOF

  # Overwrite commits.json with the specified fixture (workflow reads fixtures/<fixture>.json)
  # The workflow uses fixtures/ directory; our fixture is already there by name

  # Initialize git repo (act requires it)
  cd "$tmpdir"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  git add -A
  git commit -q -m "test: initial commit for $name"
  cd "$SCRIPT_DIR"

  # Run act with the chosen fixture via workflow_dispatch input
  local act_output
  local act_exit=0
  act_output=$(cd "$tmpdir" && act push --rm --pull=false \
    --input "commits_fixture=${fixture}" \
    --input "dry_run=true" \
    2>&1) || act_exit=$?

  echo "$act_output" >> "$RESULT_FILE"

  # Assert exit code 0
  if [ "$act_exit" -ne 0 ]; then
    fail "$name: act exited with code $act_exit (expected 0)"
  else
    log "$name: act exited 0"
  fi

  # Assert "Job succeeded" appears in output
  if echo "$act_output" | grep -q "Job succeeded"; then
    log "$name: found 'Job succeeded'"
  else
    fail "$name: 'Job succeeded' not found in act output"
  fi

  # Assert expected version appears in output
  if echo "$act_output" | grep -q "New version: $expected_version"; then
    pass "$name: output contains 'New version: $expected_version'"
  else
    fail "$name: expected 'New version: $expected_version' not found in act output"
    echo "--- relevant lines ---" >> "$RESULT_FILE"
    echo "$act_output" | grep -i "version" >> "$RESULT_FILE" || true
  fi
}

# -----------------------------------------------------------------------
# Workflow structure tests (YAML validation, file existence, actionlint)
# -----------------------------------------------------------------------

log "=== Workflow structure tests ==="
echo "========================================" >> "$RESULT_FILE"
echo "WORKFLOW STRUCTURE TESTS" >> "$RESULT_FILE"
echo "========================================" >> "$RESULT_FILE"

# 1. actionlint
if actionlint .github/workflows/semantic-version-bumper.yml >> "$RESULT_FILE" 2>&1; then
  pass "actionlint: workflow passes lint"
else
  fail "actionlint: workflow failed lint"
fi

# 2. Required files exist
for f in src/version-bumper.ts src/main.ts src/version-bumper.test.ts \
          fixtures/fix-commits.json fixtures/feat-commits.json fixtures/breaking-commits.json \
          .github/workflows/semantic-version-bumper.yml; do
  if [ -f "$SCRIPT_DIR/$f" ]; then
    pass "file exists: $f"
  else
    fail "file missing: $f"
  fi
done

# 3. Workflow has expected triggers (grep YAML)
if grep -q "push:" "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml"; then
  pass "workflow has push trigger"
else
  fail "workflow missing push trigger"
fi
if grep -q "workflow_dispatch:" "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml"; then
  pass "workflow has workflow_dispatch trigger"
else
  fail "workflow missing workflow_dispatch trigger"
fi

# 4. Workflow references correct script path
if grep -q "src/main.ts" "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml"; then
  pass "workflow references src/main.ts"
else
  fail "workflow does not reference src/main.ts"
fi

# -----------------------------------------------------------------------
# Test cases through act
# -----------------------------------------------------------------------
# Test case 1: fix commits only → patch bump (1.0.0 → 1.0.1)
run_test_case "fix-commits-patch-bump" "fix-commits" "1.0.0" "1.0.1"

# Test case 2: feat commits → minor bump (1.0.0 → 1.1.0)
run_test_case "feat-commits-minor-bump" "feat-commits" "1.0.0" "1.1.0"

# Test case 3: breaking commits → major bump (1.0.0 → 2.0.0)
run_test_case "breaking-commits-major-bump" "breaking-commits" "1.0.0" "2.0.0"

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo "" | tee -a "$RESULT_FILE"
echo "========================================" >> "$RESULT_FILE"
echo "SUMMARY" >> "$RESULT_FILE"
echo "========================================" >> "$RESULT_FILE"
log "Results: $PASSES passed, $FAILURES failed"
echo "Results: $PASSES passed, $FAILURES failed" >> "$RESULT_FILE"

if [ "$FAILURES" -gt 0 ]; then
  log "SOME TESTS FAILED — see $RESULT_FILE"
  exit 1
else
  log "ALL TESTS PASSED"
  echo "ALL TESTS PASSED" >> "$RESULT_FILE"
  exit 0
fi
