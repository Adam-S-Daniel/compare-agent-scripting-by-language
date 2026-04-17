#!/usr/bin/env bash
# End-to-end test harness for the environment matrix generator workflow.
#
# For each test case we:
#   1. Build an isolated temp workspace with this project's files plus the
#      case's fixture staged as ./config.json.
#   2. Initialise a throwaway git repo (act needs one for `act push`).
#   3. Run `act push --rm`, tee stdout+stderr into the case's log.
#   4. Append the log to ./act-result.txt with a clear delimiter.
#   5. Assert on the act exit code, on "Job succeeded", and on exact
#      known-good substrings from the captured output.
#
# We only invoke `act push` three times (once per case) per the benchmark's
# instructions. On failure we surface the error and keep going so the
# harness reports all failures in one pass.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

RESULT_FILE="$HERE/act-result.txt"
: > "$RESULT_FILE"  # truncate any stale run

overall_status=0
declare -a failed_cases

stage_workspace() {
    # Copy project files + the chosen fixture into a temp dir and init a
    # git repo there. Emits the path on stdout.
    local fixture="$1"
    local tmp
    tmp="$(mktemp -d)"
    cp -r "$HERE/.github" "$tmp/"
    cp -r "$HERE/tests" "$tmp/"
    cp "$HERE/matrix_generator.py" "$tmp/"
    cp "$HERE/.actrc" "$tmp/"
    cp "$fixture" "$tmp/config.json"
    (
        cd "$tmp"
        git init --quiet
        git config user.email "test@example.com"
        git config user.name "Tester"
        git add -A
        git commit --quiet -m "case"
    )
    echo "$tmp"
}

run_case() {
    local name="$1"
    local fixture="$2"
    local expect_failure="$3"
    shift 3
    # Remaining args: exact substrings that must appear in stdout.
    local must_contain=("$@")

    echo
    echo "================================================================="
    echo "Running case: $name (expect_failure=$expect_failure)"
    echo "================================================================="

    local tmp
    tmp="$(stage_workspace "$fixture")"

    local log="$tmp/act.log"
    (
        cd "$tmp"
        # --env sets container-side env vars; the workflow step consumes
        # EXPECT_FAILURE via the shell so we can drive pass/fail per case.
        act push --rm --env "EXPECT_FAILURE=$expect_failure" 2>&1
    ) | tee "$log"
    local rc="${PIPESTATUS[0]}"

    {
        printf '\n\n===== CASE %s (expect_failure=%s) =====\n' "$name" "$expect_failure"
        printf 'ACT_EXIT_CODE=%s\n' "$rc"
        cat "$log"
        printf '\n===== END CASE %s =====\n' "$name"
    } >> "$RESULT_FILE"

    local case_ok=1
    if [ "$rc" -ne 0 ]; then
        echo "ASSERTION FAILED [$name]: act exit code was $rc (expected 0)"
        case_ok=0
    fi
    if ! grep -q "Job succeeded" "$log"; then
        echo "ASSERTION FAILED [$name]: 'Job succeeded' missing from output"
        case_ok=0
    fi
    for needle in "${must_contain[@]}"; do
        if ! grep -qF -- "$needle" "$log"; then
            echo "ASSERTION FAILED [$name]: expected substring missing: $needle"
            case_ok=0
        fi
    done

    if [ "$case_ok" -eq 1 ]; then
        echo "CASE OK: $name"
    else
        overall_status=1
        failed_cases+=("$name")
    fi

    rm -rf "$tmp"
}

# --- Structural checks before we pay for any act runs -----------------------

echo "=== Structural checks ==="
if ! actionlint .github/workflows/environment-matrix-generator.yml; then
    echo "actionlint failed"
    overall_status=1
fi

python3 - <<'PY'
import sys, yaml
with open(".github/workflows/environment-matrix-generator.yml") as fh:
    wf = yaml.safe_load(fh)
assert wf["name"] == "Environment Matrix Generator", wf["name"]
# PyYAML parses the `on:` key as the boolean True on Python — accept either.
triggers = wf.get("on") or wf.get(True)
assert triggers is not None, "workflow has no trigger block"
for t in ("push", "pull_request", "workflow_dispatch"):
    assert t in triggers, f"missing trigger {t}"
job = wf["jobs"]["validate-and-generate"]
step_names = [s.get("name", "") for s in job["steps"]]
for expected in ("Check out repository", "Run unit tests", "Generate matrix from fixture"):
    assert expected in step_names, f"missing step: {expected}"
# Spot-check: workflow actually references the script we built.
assert any("matrix_generator.py" in (s.get("run") or "") for s in job["steps"]), "script not referenced"
print("STRUCTURAL_CHECKS_OK")
PY
if [ $? -ne 0 ]; then
    overall_status=1
fi

# Paths referenced from the workflow must exist on disk.
for p in matrix_generator.py tests/test_matrix_generator.py; do
    if [ ! -f "$p" ]; then
        echo "missing required file: $p"
        overall_status=1
    fi
done

# --- The three act-based test cases ----------------------------------------

# Case 1: 2 OS x 2 Python = 4 combinations, fail-fast=false, max-parallel=2.
run_case "basic" "$HERE/fixtures/case1_basic.json" "false" \
    "MATRIX_OK" \
    "total_combinations=4" \
    "fail-fast=False" \
    "max-parallel=2" \
    "matrix_keys=os,python"

# Case 2: includes + excludes. Cartesian 3*2*2 = 12, minus 4 excluded
# (windows-latest/18 x 2 features, macos-latest/minimal x 2 nodes),
# plus 1 fully-new include (os=alpine) = 9. The other include extends
# an existing row and doesn't add to the count.
run_case "include_exclude" "$HERE/fixtures/case2_include_exclude.json" "false" \
    "MATRIX_OK" \
    "total_combinations=9" \
    "fail-fast=True" \
    "max-parallel=4" \
    "matrix_keys=exclude,features,include,node,os"

# Case 3: 3 OS * 4 Python * 3 features = 36 combinations, max_size=10 →
# generator rejects with exit code 2. The workflow step asserts the
# non-zero rc under EXPECT_FAILURE=true and still passes.
run_case "exceeds_max_size" "$HERE/fixtures/case3_exceeds_max.json" "true" \
    "EXPECTED_FAILURE_OK" \
    "matrix has 36 combinations" \
    "SCRIPT_EXIT_CODE=2"

echo
echo "================================================================="
if [ "$overall_status" -eq 0 ]; then
    echo "ALL CASES PASSED"
else
    echo "FAILED CASES: ${failed_cases[*]}"
fi
echo "Result log: $RESULT_FILE"
exit "$overall_status"
