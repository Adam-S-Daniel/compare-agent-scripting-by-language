#!/usr/bin/env bash
# run_tests.sh — test harness: runs act and verifies outputs, writes act-result.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
WORKFLOW=".github/workflows/environment-matrix-generator.yml"

cd "$SCRIPT_DIR"

# ---- Workflow structure checks (no act needed) ----
echo "=== WORKFLOW STRUCTURE CHECKS ===" | tee -a "$RESULT_FILE"

# Check actionlint passes
echo "--- actionlint ---" | tee -a "$RESULT_FILE"
if actionlint "$WORKFLOW" >> "$RESULT_FILE" 2>&1; then
    echo "actionlint: PASSED" | tee -a "$RESULT_FILE"
else
    echo "actionlint: FAILED" | tee -a "$RESULT_FILE"
    exit 1
fi

# Verify workflow references script and fixtures that exist
echo "--- Verify referenced files exist ---" | tee -a "$RESULT_FILE"
python3 - "$WORKFLOW" "$SCRIPT_DIR" <<'PYCHECK' | tee -a "$RESULT_FILE"
import sys, re
from pathlib import Path

workflow_path = Path(sys.argv[1])
base = Path(sys.argv[2])
content = workflow_path.read_text()

# Check required trigger events
for event in ["push", "pull_request", "workflow_dispatch"]:
    assert event in content, f"Missing trigger: {event}"
    print(f"Trigger '{event}': present")

# Check script is referenced
assert "matrix_generator.py" in content, "matrix_generator.py not referenced"
print("matrix_generator.py: referenced")
assert (base / "matrix_generator.py").exists(), "matrix_generator.py does not exist"
print("matrix_generator.py: exists on disk")

# Check fixtures are referenced and exist
for fixture in ["basic_matrix.json", "matrix_with_excludes.json", "matrix_with_includes.json", "matrix_exceeds_max_size.json"]:
    assert fixture in content, f"Fixture not referenced: {fixture}"
    assert (base / "fixtures" / fixture).exists(), f"Fixture missing on disk: {fixture}"
    print(f"fixtures/{fixture}: referenced and exists")

print("STRUCTURE_CHECKS: PASSED")
PYCHECK

# ---- act run ----
echo "" | tee -a "$RESULT_FILE"
echo "=== ACT RUN ===" | tee -a "$RESULT_FILE"
echo "--- act push --rm ---" | tee -a "$RESULT_FILE"

# Run act, capturing combined stdout+stderr, tee to result file
act_exit=0
act push --rm --pull=false -W "$WORKFLOW" 2>&1 | tee -a "$RESULT_FILE" || act_exit=$?

echo "" | tee -a "$RESULT_FILE"
echo "act exit code: $act_exit" | tee -a "$RESULT_FILE"

if [ "$act_exit" -ne 0 ]; then
    echo "ACT RUN: FAILED (exit $act_exit)" | tee -a "$RESULT_FILE"
    exit 1
fi

# ---- Parse act output and assert expected values ----
echo "=== ASSERTIONS ===" | tee -a "$RESULT_FILE"

python3 - "$RESULT_FILE" <<'PYASSERT' | tee -a "$RESULT_FILE"
import sys, re
from pathlib import Path

content = Path(sys.argv[1]).read_text()

def assert_in(needle, label):
    if needle not in content:
        print(f"ASSERTION FAILED: '{needle}' not found — {label}")
        sys.exit(1)
    print(f"ASSERTION PASSED: '{needle}' found — {label}")

# Unit tests passed
assert_in("passed", "pytest passed")

# TC1
assert_in("TC1 PASSED: basic_matrix verified", "TC1 success marker")

# TC2
assert_in("TC2 PASSED: matrix_with_excludes verified", "TC2 success marker")

# TC3
assert_in("TC3 PASSED: matrix_with_includes verified", "TC3 success marker")

# TC4
assert_in("TC4 PASSED: matrix_exceeds_max_size correctly errors", "TC4 success marker")

# All jobs succeeded
assert_in("Job succeeded", "at least one job succeeded")

print("ALL ASSERTIONS PASSED")
PYASSERT

echo "" | tee -a "$RESULT_FILE"
echo "=== ALL TESTS PASSED ===" | tee -a "$RESULT_FILE"
