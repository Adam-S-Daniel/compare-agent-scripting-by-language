#!/usr/bin/env bash
#
# run-act-tests.sh — end-to-end harness that runs the
# test-results-aggregator workflow under act for several fixture
# variants, captures every run into act-result.txt, and asserts the
# workflow produced the exact expected output for each input.
#
# Usage: ./run-act-tests.sh [--max-cases N]
# Produces: act-result.txt (required artifact — one delimited section
#           per test case, capturing act's full stdout/stderr).
#
# Strategy:
#   * For each case we build a temp directory containing the project
#     (aggregate.sh, tests/, .github/workflows/...) plus a specific
#     fixture set, init it as a git repo, and run `act push --rm`.
#   * The workflow emits lines like "AGGREGATE_RESULT: total=X ...".
#     We grep those out of act's output and assert exact expected
#     values for the current case.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$REPO_ROOT/act-result.txt"

: > "$RESULT_FILE"

MAX_CASES=3
while [ $# -gt 0 ]; do
    case "$1" in
        --max-cases) MAX_CASES="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

# Copy the project (script + workflow + tests) into $1 (a temp dir).
# The caller then drops their fixtures/ into place before `act push`.
seed_project() {
    local dest="$1"
    mkdir -p "$dest/.github/workflows" "$dest/tests" "$dest/fixtures" "$dest/input"
    cp "$REPO_ROOT/aggregate.sh" "$dest/aggregate.sh"
    cp "$REPO_ROOT/tests/aggregate.bats" "$dest/tests/aggregate.bats"
    cp "$REPO_ROOT/.github/workflows/test-results-aggregator.yml" \
       "$dest/.github/workflows/test-results-aggregator.yml"
    # bats tests always need the full fixture set.
    cp "$REPO_ROOT"/fixtures/run1.xml  "$dest/fixtures/"
    cp "$REPO_ROOT"/fixtures/run2.xml  "$dest/fixtures/"
    cp "$REPO_ROOT"/fixtures/run1.json "$dest/fixtures/"
    cp "$REPO_ROOT"/fixtures/run2.json "$dest/fixtures/"
    # Point act at our pre-built image so Docker doesn't pull ubuntu-latest
    # from a non-existent remote during testing.
    if [ -f "$REPO_ROOT/.actrc" ]; then
        cp "$REPO_ROOT/.actrc" "$dest/.actrc"
    fi
    chmod +x "$dest/aggregate.sh"
}

# Run act in $1. Captures stdout+stderr and prints to stdout.
run_act() {
    local dir="$1"
    (
        cd "$dir"
        git init -q
        git config user.email "ci@example.com"
        git config user.name  "ci"
        git add -A
        git commit -q -m "seed"
        # --rm to remove container after run, -W for workflow path
        act push --rm --pull=false \
            -W .github/workflows/test-results-aggregator.yml \
            2>&1
    )
}

# Append a delimited section to act-result.txt so every case is
# identifiable afterwards.
append_section() {
    local name="$1" body_file="$2"
    {
        printf '\n================================================================\n'
        printf 'TEST CASE: %s\n' "$name"
        printf '================================================================\n'
        cat "$body_file"
    } >> "$RESULT_FILE"
}

# Assertion helper — exit on failure.
assert_contains() {
    local haystack="$1" needle="$2" label="$3"
    if ! grep -qF -- "$needle" "$haystack"; then
        printf 'ASSERTION FAILED (%s): expected %q in act output\n' "$label" "$needle" >&2
        return 1
    fi
    printf '  OK: %s contains %q\n' "$label" "$needle"
}

# --- Case 1: default fixtures (run1.xml + run2.xml + run1.json + run2.json).
# Expected totals (hand-computed):
#   run1.xml:  5 tests, 3 pass, 1 fail, 1 skip, 1.5s
#   run2.xml:  5 tests, 3 pass, 2 fail, 0 skip, 2.5s
#   run1.json: 4 tests, 3 pass, 1 fail, 0 skip, 0.8s
#   run2.json: 4 tests, 2 pass, 2 fail, 0 skip, 0.9s
#   TOTALS:    18 tests, 11 pass, 6 fail, 1 skip, 5.70s
#   FLAKY:     test_login (pass in run1.xml, fail in run2.xml)
#              test_multiply (pass in run1.json, fail in run2.json)
case_all_fixtures() {
    local tmp
    tmp="$(mktemp -d)"
    seed_project "$tmp"
    cp "$REPO_ROOT"/fixtures/run1.xml  "$tmp/input/"
    cp "$REPO_ROOT"/fixtures/run2.xml  "$tmp/input/"
    cp "$REPO_ROOT"/fixtures/run1.json "$tmp/input/"
    cp "$REPO_ROOT"/fixtures/run2.json "$tmp/input/"

    local out="$tmp/act.out"
    if run_act "$tmp" > "$out"; then
        echo "ACT_EXIT: 0" >> "$out"
    else
        echo "ACT_EXIT: $?" >> "$out"
    fi
    append_section "case_all_fixtures" "$out"

    # Assertions.
    grep -q '^ACT_EXIT: 0$' "$out" || { echo "act exited non-zero"; return 1; }
    # Every job must report success.
    local succeeded
    succeeded=$(grep -cE 'Job succeeded' "$out" || true)
    if [ "$succeeded" -lt 3 ]; then
        echo "Expected 3 'Job succeeded' lines, saw $succeeded" >&2
        return 1
    fi
    assert_contains "$out" 'AGGREGATE_RESULT: total=18 passed=11 failed=6 skipped=1 flaky=2 duration=5.70s pass_rate=64%' "aggregate result"
    assert_contains "$out" 'AGGREGATE_HAS_SUMMARY_HEADER: 1' "markdown header count"
    rm -rf "$tmp"
}

# --- Case 2: a single JSON file (run1.json).
# Expected: 4 tests, 3 pass, 1 fail, 0 skip, 0.80s, 0 flaky.
case_single_json() {
    local tmp
    tmp="$(mktemp -d)"
    seed_project "$tmp"
    cp "$REPO_ROOT"/fixtures/run1.json "$tmp/input/"

    local out="$tmp/act.out"
    if run_act "$tmp" > "$out"; then
        echo "ACT_EXIT: 0" >> "$out"
    else
        echo "ACT_EXIT: $?" >> "$out"
    fi
    append_section "case_single_json" "$out"

    grep -q '^ACT_EXIT: 0$' "$out" || { echo "act exited non-zero"; return 1; }
    local succeeded
    succeeded=$(grep -cE 'Job succeeded' "$out" || true)
    if [ "$succeeded" -lt 3 ]; then
        echo "Expected 3 'Job succeeded' lines, saw $succeeded" >&2
        return 1
    fi
    assert_contains "$out" 'AGGREGATE_RESULT: total=4 passed=3 failed=1 skipped=0 flaky=0 duration=0.80s pass_rate=75%' "aggregate result"
    rm -rf "$tmp"
}

# --- Case 3: synthesized all-passing XML fixture. Sanity check for a
# healthy matrix build (no failures, no flaky).
case_all_passing() {
    local tmp
    tmp="$(mktemp -d)"
    seed_project "$tmp"
    cat > "$tmp/input/green.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="smoke" tests="3" failures="0" skipped="0" time="0.6">
    <testcase name="test_a" classname="smoke" time="0.2"/>
    <testcase name="test_b" classname="smoke" time="0.2"/>
    <testcase name="test_c" classname="smoke" time="0.2"/>
</testsuite>
EOF

    local out="$tmp/act.out"
    if run_act "$tmp" > "$out"; then
        echo "ACT_EXIT: 0" >> "$out"
    else
        echo "ACT_EXIT: $?" >> "$out"
    fi
    append_section "case_all_passing" "$out"

    grep -q '^ACT_EXIT: 0$' "$out" || { echo "act exited non-zero"; return 1; }
    local succeeded
    succeeded=$(grep -cE 'Job succeeded' "$out" || true)
    if [ "$succeeded" -lt 3 ]; then
        echo "Expected 3 'Job succeeded' lines, saw $succeeded" >&2
        return 1
    fi
    assert_contains "$out" 'AGGREGATE_RESULT: total=3 passed=3 failed=0 skipped=0 flaky=0 duration=0.60s pass_rate=100%' "aggregate result"
    rm -rf "$tmp"
}

main() {
    local cases=(case_all_fixtures case_single_json case_all_passing)
    local n=0
    local failures=0
    for c in "${cases[@]}"; do
        n=$(( n + 1 ))
        if [ "$n" -gt "$MAX_CASES" ]; then break; fi
        printf '\n>>> Running %s\n' "$c"
        if ! "$c"; then
            printf 'CASE FAILED: %s\n' "$c" >&2
            failures=$(( failures + 1 ))
        fi
    done
    if [ "$failures" -gt 0 ]; then
        printf '\n%d case(s) failed\n' "$failures" >&2
        exit 1
    fi
    printf '\nAll %d act case(s) passed. Results in %s\n' "$n" "$RESULT_FILE"
}

main "$@"
