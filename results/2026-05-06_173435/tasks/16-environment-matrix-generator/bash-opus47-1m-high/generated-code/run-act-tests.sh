#!/usr/bin/env bash
# run-act-tests.sh — drive the GitHub Actions workflow through `act` for
# each test case. For every case we:
#   1. Materialize a temp git repo containing the project + the case's
#      fixture renamed to fixture.json.
#   2. Invoke `act push --rm` and capture the full output.
#   3. Append that output, with a clear header, to act-result.txt in the
#      project root.
#   4. Assert that act exited 0, that every job reported success, and that
#      the script's stdout / stderr / exit-code (printed inside delimited
#      ===STDOUT===, ===STDERR===, ===EXITCODE=== blocks by the workflow)
#      match the case's expected values exactly.
#
# Usage: ./run-act-tests.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="${PROJECT_DIR}/act-result.txt"

: > "$RESULT_FILE"   # truncate

# Each test case is represented as: a name, a fixture, an expected exit code
# from the script, and (when applicable) substrings expected on stdout /
# stderr. Fields are separated by ASCII unit-separator (\x1f) so any
# character is allowed inside a field — important because jq filters
# contain spaces, dots, pipes, and quotes.
#
# Field layout:
#   1. case name
#   2. fixture path (relative to project root)
#   3. expected script exit-code (string)
#   4. jq expression to run against the script's STDOUT block; "-" to skip
#   5. literal substring expected in the script's STDERR block

US=$'\x1f'
CASES=(
    "case1-basic${US}fixtures/case1-basic.json${US}0${US}(.matrix.os | length == 2) and (.matrix.node | length == 2) and (.\"fail-fast\" == true)${US}size=4"
    "case2-include-exclude${US}fixtures/case2-with-include-exclude.json${US}0${US}(.matrix.include | length == 1) and (.matrix.exclude | length == 2) and (.\"max-parallel\" == 6) and (.\"fail-fast\" == false)${US}size=9"
    "case3-exceeds-max-size${US}fixtures/case3-exceeds-max-size.json${US}1${US}-${US}exceeds max-size 5"
)

# Locate the act-image we know is preloaded (set in .actrc).
ACT_IMAGE_FLAG=""
if [[ -f "${PROJECT_DIR}/.actrc" ]]; then
    ACT_IMAGE_FLAG="$(grep -E '^-P' "${PROJECT_DIR}/.actrc" | head -n1 || true)"
fi

# run_case <name> <fixture> <exp_ec> <jq_check> <exp_err_substr>
run_case() {
    local name="$1"
    local fixture="$2"
    local exp_ec="$3"
    local jq_check="$4"
    local exp_err="$5"

    echo "=========================================================================="
    echo "CASE: $name"
    echo "  fixture: $fixture"
    echo "  expected script exit-code: $exp_ec"
    echo "=========================================================================="

    local workdir
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' RETURN

    # Mirror the project into a fresh temp dir, but skip artifacts that
    # don't belong inside the sandbox.
    rsync -a \
        --exclude='.git' \
        --exclude='act-result.txt' \
        --exclude='node_modules' \
        "${PROJECT_DIR}/" "${workdir}/"

    cp "${PROJECT_DIR}/${fixture}" "${workdir}/fixture.json"

    (
        cd "$workdir"
        git init -q
        git config user.email "act@local"
        git config user.name "act"
        git add -A
        git commit -q -m "fixture for ${name}"
    )

    # Run act, capturing both streams. Don't fail the harness if act itself
    # exits non-zero — we want to capture and inspect the output.
    local act_out act_ec=0
    set +e
    # shellcheck disable=SC2086  # ACT_IMAGE_FLAG holds "-P key=value", needs splitting
    act_out="$(cd "$workdir" && act push --rm --pull=false $ACT_IMAGE_FLAG 2>&1)"
    act_ec=$?
    set -e

    {
        echo
        echo "######## CASE: $name ########"
        echo "$act_out"
        echo "######## END CASE: $name (act_ec=$act_ec) ########"
        echo
    } >> "$RESULT_FILE"

    # --- assertions -------------------------------------------------------

    if [[ $act_ec -ne 0 ]]; then
        echo "FAIL ($name): act exited $act_ec (expected 0)"
        return 1
    fi

    if ! grep -q "Job succeeded" <<<"$act_out"; then
        echo "FAIL ($name): no 'Job succeeded' line in act output"
        return 1
    fi

    # act prefixes every script-output line with "[<job-name>] | ", e.g.
    #   [environment-matrix-generator/Generate and validate matrix]   | <line>
    # Strip that prefix before parsing.
    local stripped
    stripped="$(sed -E 's/^\[[^]]*\][[:space:]]*\|[[:space:]]?//' <<<"$act_out")"

    # Extract the script exit code from the workflow output.
    local script_ec
    script_ec="$(awk '/===EXITCODE===/{getline; print; exit}' <<<"$stripped" | tr -d '[:space:]')"
    if [[ "$script_ec" != "$exp_ec" ]]; then
        echo "FAIL ($name): script exit-code was '$script_ec' (expected '$exp_ec')"
        return 1
    fi

    # Extract the script stdout block.
    local script_stdout
    script_stdout="$(awk '/===STDOUT===/{flag=1; next} /===STDERR===/{flag=0} flag' <<<"$stripped")"

    if [[ "$jq_check" != "-" ]]; then
        if ! jq -e "$jq_check" <<<"$script_stdout" >/dev/null; then
            echo "FAIL ($name): jq check failed: $jq_check"
            echo "----- captured stdout -----"
            echo "$script_stdout"
            echo "---------------------------"
            return 1
        fi
    fi

    # Extract the script stderr block.
    local script_stderr
    script_stderr="$(awk '/===STDERR===/{flag=1; next} /===EXITCODE===/{flag=0} flag' <<<"$stripped")"

    if [[ -n "$exp_err" ]] && ! grep -qF "$exp_err" <<<"$script_stderr"; then
        echo "FAIL ($name): expected stderr substring '$exp_err' not found"
        echo "----- captured stderr -----"
        echo "$script_stderr"
        echo "---------------------------"
        return 1
    fi

    echo "PASS: $name"
    return 0
}

# Walk every case. Bash arrays of pipe-separated strings keep the harness
# self-contained (no associative arrays / external metadata files).
fail=0
for spec in "${CASES[@]}"; do
    IFS="$US" read -r name fixture exp_ec jq_check exp_err <<<"$spec"
    if ! run_case "$name" "$fixture" "$exp_ec" "$jq_check" "$exp_err"; then
        fail=1
    fi
done

if [[ $fail -ne 0 ]]; then
    echo
    echo "One or more act test cases failed. See $RESULT_FILE for details."
    exit 1
fi

echo
echo "All act test cases passed. Output captured in $RESULT_FILE."
