#!/usr/bin/env bash
# Shared helpers for act-driven bats tests.
#
# Each test case constructs a clean temp git repo containing the project
# files plus the case's manifest fixture, runs `act push --rm`, captures
# combined stdout/stderr, and appends a clearly-delimited block to the
# project-root act-result.txt artifact.

# PROJECT_ROOT — absolute path to the project under test.
PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
export PROJECT_ROOT

# All cases append into this single artifact at the project root.
ACT_RESULT_FILE="${PROJECT_ROOT}/act-result.txt"
export ACT_RESULT_FILE

# Build a temp git repo populated with the project files. Echoes the path.
# The caller should cd into it before running act, and `rm -rf` it after.
make_test_repo() {
    local tmp
    tmp=$(mktemp -d -t licensecheck-act-XXXXXX)

    # Copy everything the workflow + script need. Use cp -a to keep the
    # executable bit on bin/license-check.sh.
    cp -a "${PROJECT_ROOT}/bin"               "${tmp}/"
    cp -a "${PROJECT_ROOT}/fixtures"          "${tmp}/"
    cp -a "${PROJECT_ROOT}/.github"           "${tmp}/"
    cp -a "${PROJECT_ROOT}/.actrc"            "${tmp}/"

    # Initialize a real git repo so actions/checkout@v4 has commits to fetch.
    (
        cd "${tmp}" || exit 1
        git init -q -b main
        git config user.email "tests@example.com"
        git config user.name  "license-check-tests"
        git add -A
        git commit -q -m "test fixture"
    )

    printf '%s' "${tmp}"
}

# Append a delimited block for one case to act-result.txt. Args:
#   $1 — case label
#   $2 — act exit status
#   $3 — combined stdout/stderr text
record_case() {
    local label="$1" rc="$2" output="$3"
    {
        # `--` ends printf option parsing so format strings starting with
        # `-` (like our `-----` separator) aren't mistaken for flags.
        printf -- '\n========== CASE: %s ==========\n' "$label"
        printf -- 'act exit status: %s\n' "$rc"
        printf -- '----- begin act output -----\n'
        printf -- '%s\n' "$output"
        printf -- '----- end act output -----\n'
    } >> "${ACT_RESULT_FILE}"
}

# Run act in the given test repo. Echoes combined output to stdout. Sets
# ACT_RC for the caller to read (bats `run` swallows the exit code so we
# stash it in a global instead). The caller must export ACT_RC themselves
# if they need it across functions; here it's a regular shell variable.
run_act_push() {
    local repo="$1"
    (
        cd "${repo}" || exit 1
        # `--rm` removes the container after each run so disk doesn't grow.
        # 2>&1 merges stderr so the captured output contains the full log.
        act push --rm 2>&1
    )
}
