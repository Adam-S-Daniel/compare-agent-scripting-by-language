#!/usr/bin/env bats
# End-to-end pipeline tests. Each test sets up a temporary git repo
# containing the project files plus a single fixture's data, then runs
# `act push --rm` against it and asserts on the captured output.
#
# We append every act run's output to act-result.txt in the project root
# so that file is a complete audit trail of the pipeline executions.
#
# Mirrors the spec's "for each test case: set up temp repo, run act,
# capture output, assert exact expected values" pattern.
#
# We deliberately keep the case count modest (three) because each case
# spawns an isolated container; the package.json and no-op bump paths are
# covered by the unit-test suite that the workflow itself runs (so they
# do still execute through act, transitively).

# --- shared paths -------------------------------------------------------

PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
RESULT_FILE="${PROJECT_ROOT}/act-result.txt"
FIXTURES_DIR="${PROJECT_ROOT}/fixtures"

setup_file() {
    # Truncate the audit log once per file so re-runs don't accumulate.
    : > "$RESULT_FILE"
}

# Create an isolated workspace for one test case. Returns the path on stdout.
# Copies in:
#   - bump_version.sh        (the implementation)
#   - tests/bump_version.bats (the unit tests, run inside CI)
#   - .github/workflows/...  (the workflow file)
#   - .actrc                 (selects our pwsh-equipped runner image)
#   - the case's fixture files (VERSION/package.json + commits.txt)
make_workspace() {
    local case_name="$1"
    local fixture_dir="${FIXTURES_DIR}/${case_name}"

    local ws
    ws=$(mktemp -d)

    cp "${PROJECT_ROOT}/bump_version.sh" "$ws/"
    cp "${PROJECT_ROOT}/.actrc" "$ws/" 2>/dev/null || true
    mkdir -p "$ws/tests" "$ws/.github/workflows"
    cp "${PROJECT_ROOT}/tests/bump_version.bats" "$ws/tests/"
    cp "${PROJECT_ROOT}/.github/workflows/semantic-version-bumper.yml" \
        "$ws/.github/workflows/"

    # Copy fixture files into the workspace root so the workflow finds them.
    cp -r "${fixture_dir}/." "$ws/"

    # act needs a real git repo to drive the push event.
    (
        cd "$ws"
        git init -q -b main
        git -c user.email=t@t -c user.name=t add -A
        git -c user.email=t@t -c user.name=t commit -q -m "fixture: ${case_name}"
    )

    echo "$ws"
}

# Run act in the given workspace. Captures the log to ${ws}/act.log AND
# appends it to the shared act-result.txt so a single file documents all
# test-case runs (with delimiters identifying which case is which).
run_act_for() {
    local ws="$1"
    local case_name="$2"

    local log="${ws}/act.log"
    (
        cd "$ws"
        act push --rm > "$log" 2>&1
    )
    local rc=$?

    {
        printf '\n========== CASE: %s (exit=%d) ==========\n' "$case_name" "$rc"
        cat "$log"
        printf '========== END CASE: %s ==========\n' "$case_name"
    } >> "$RESULT_FILE"

    return "$rc"
}

# --- per-case tests -----------------------------------------------------

@test "act pipeline: fix-only commits produce a patch bump (1.2.3 -> 1.2.4)" {
    ws=$(make_workspace case-fix-patch)
    run_act_for "$ws" case-fix-patch
    rc=$?
    log="${ws}/act.log"
    [ "$rc" -eq 0 ]
    grep -q "NEW_VERSION=1.2.4" "$log"
    # Both jobs (lint + bump) need to report success.
    [ "$(grep -c 'Job succeeded' "$log")" -ge 2 ]
    rm -rf "$ws"
}

@test "act pipeline: feat commits produce a minor bump (1.2.3 -> 1.3.0)" {
    ws=$(make_workspace case-feat-minor)
    run_act_for "$ws" case-feat-minor
    rc=$?
    log="${ws}/act.log"
    [ "$rc" -eq 0 ]
    grep -q "NEW_VERSION=1.3.0" "$log"
    [ "$(grep -c 'Job succeeded' "$log")" -ge 2 ]
    rm -rf "$ws"
}

@test "act pipeline: breaking change produces a major bump (1.2.3 -> 2.0.0)" {
    ws=$(make_workspace case-breaking-major)
    run_act_for "$ws" case-breaking-major
    rc=$?
    log="${ws}/act.log"
    [ "$rc" -eq 0 ]
    grep -q "NEW_VERSION=2.0.0" "$log"
    [ "$(grep -c 'Job succeeded' "$log")" -ge 2 ]
    rm -rf "$ws"
}

# Sanity check on the audit log itself.
@test "act-result.txt was populated with all three cases" {
    [ -s "$RESULT_FILE" ]
    grep -q "CASE: case-fix-patch" "$RESULT_FILE"
    grep -q "CASE: case-feat-minor" "$RESULT_FILE"
    grep -q "CASE: case-breaking-major" "$RESULT_FILE"
}
