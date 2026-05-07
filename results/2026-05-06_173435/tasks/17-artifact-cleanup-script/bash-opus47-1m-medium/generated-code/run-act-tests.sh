#!/usr/bin/env bash
# Test harness: runs the workflow under `act` for multiple test cases,
# appends each run's output to act-result.txt, and asserts on EXACT
# expected values in the act output. Each case runs in an isolated
# temp git repo with that case's fixture data swapped in.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$PROJECT_ROOT/act-result.txt"
: > "$RESULT_FILE"

overall_status=0

# Run a case. Args:
#   $1 case name
#   $2 path to TSV fixture file to use as basic.tsv (overrides default)
#   $3 NOW iso timestamp
#   $4 max-age-days
#   $5+ shell tests, evaluated against captured act output ($act_output)
run_case() {
    local case_name="$1" fixture_file="$2" now="$3" age_days="$4"
    shift 4
    local tmp
    tmp="$(mktemp -d)"

    cp "$PROJECT_ROOT/cleanup.sh" "$tmp/"
    cp -r "$PROJECT_ROOT/tests" "$tmp/"
    mkdir -p "$tmp/.github/workflows"
    cp "$PROJECT_ROOT/.github/workflows/artifact-cleanup-script.yml" "$tmp/.github/workflows/"
    cp "$PROJECT_ROOT/.actrc" "$tmp/" 2>/dev/null || true

    # Place case fixture alongside the existing fixtures (without clobbering)
    cp "$fixture_file" "$tmp/tests/fixtures/case.tsv"

    sed -i "s|NOW: .*|NOW: \"$now\"|" "$tmp/.github/workflows/artifact-cleanup-script.yml"
    sed -i "s|MAX_AGE_DAYS: .*|MAX_AGE_DAYS: \"$age_days\"|" "$tmp/.github/workflows/artifact-cleanup-script.yml"
    sed -i "s|INPUT_FILE: .*|INPUT_FILE: tests/fixtures/case.tsv|" "$tmp/.github/workflows/artifact-cleanup-script.yml"

    (
        cd "$tmp"
        git init -q
        git config user.email t@t
        git config user.name t
        git add -A
        git commit -q -m "case $case_name"
    )

    {
        echo
        echo "===================================================================="
        echo "CASE: $case_name"
        echo "fixture: $fixture_file  now: $now  max-age-days: $age_days"
        echo "===================================================================="
    } >> "$RESULT_FILE"

    local act_output exit_code
    set +e
    act_output="$(cd "$tmp" && act push --rm --pull=false 2>&1)"
    exit_code=$?
    set -e
    echo "$act_output" >> "$RESULT_FILE"

    if [ "$exit_code" -ne 0 ]; then
        echo "FAIL: $case_name — act exit $exit_code" | tee -a "$RESULT_FILE"
        overall_status=1
        rm -rf "$tmp"
        return
    fi

    # Every job must report success. Workflow has 2 jobs: lint, test.
    local job_succeeded_count
    job_succeeded_count="$(grep -c "Job succeeded" <<<"$act_output" || true)"
    if [ "$job_succeeded_count" -lt 2 ]; then
        echo "FAIL: $case_name — expected >= 2 'Job succeeded', got $job_succeeded_count" | tee -a "$RESULT_FILE"
        overall_status=1
    fi

    # Run all assertions passed in $@. Each is a substring that must appear in act_output.
    local assertion
    for assertion in "$@"; do
        if ! grep -qF -- "$assertion" <<<"$act_output"; then
            echo "FAIL: $case_name — missing expected output: $assertion" | tee -a "$RESULT_FILE"
            overall_status=1
        fi
    done

    rm -rf "$tmp"
    echo "PASS: $case_name (asserted $# expectations)"
}

# Case A: default basic.tsv (a1=1d, a2=10d, a3=40d), max-age=30
# Expect: a3 deleted -> reclaimed 3000, retained 2 (in age-policy block)
# keep-latest=1 over multi.tsv -> deleted 3 (in keep-latest block)
run_case "default-30-day-cutoff" \
    "$PROJECT_ROOT/tests/fixtures/basic.tsv" \
    "2026-05-07T00:00:00Z" \
    "30" \
    "DELETE a3" \
    "Reclaimed: 3000 bytes" \
    "Retained: 2" \
    "Deleted: 3" \
    "DRY-RUN PLAN"

# Case B: same fixture, max-age=100 (nothing old enough) -> retain all 3
run_case "lenient-100-day-cutoff" \
    "$PROJECT_ROOT/tests/fixtures/basic.tsv" \
    "2026-05-07T00:00:00Z" \
    "100" \
    "Retained: 3" \
    "Reclaimed: 0 bytes" \
    "DRY-RUN PLAN"

# Case C: alternative fixture — single old artifact, max-age=1
TMPFIX="$(mktemp)"
cat > "$TMPFIX" <<'EOF'
zzz	9999	2026-01-01T00:00:00Z	999
fresh	100	2026-05-06T00:00:00Z	999
EOF
run_case "alt-fixture-aggressive-cutoff" \
    "$TMPFIX" \
    "2026-05-07T00:00:00Z" \
    "1" \
    "DELETE zzz" \
    "Reclaimed: 9999 bytes" \
    "Retained: 1" \
    "Deleted: 1"
rm -f "$TMPFIX"

if [ "$overall_status" -eq 0 ]; then
    echo "ALL ACT CASES PASSED" | tee -a "$RESULT_FILE"
else
    echo "SOME ACT CASES FAILED" | tee -a "$RESULT_FILE"
fi
exit "$overall_status"
