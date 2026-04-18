#!/usr/bin/env bash
# run-act-tests.sh - Harness that exercises the PR Label Assigner workflow
# through `act` end-to-end for multiple fixture-driven test cases.
#
# Each test case:
#   1. Builds a temp git repo containing the project files plus the case's
#      fixtures (rules.conf, files.txt).
#   2. Runs `act push --rm` inside that repo.
#   3. Appends the output, clearly delimited, to act-result.txt in the
#      original working directory.
#   4. Asserts act exited 0, the expected label list appears between the
#      workflow's markers, and every job shows "Job succeeded".

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$PROJECT_DIR/act-result.txt"

# Reset the results artifact.
: > "$RESULT_FILE"

fail_count=0
pass_count=0

# Workflow-structure pre-checks: shellcheck + actionlint + bats structural tests.
{
    printf '==================== PRECHECK: shellcheck ====================\n'
} >>"$RESULT_FILE"
if shellcheck "$PROJECT_DIR/label-assigner.sh" "$PROJECT_DIR/run-act-tests.sh" \
        >>"$RESULT_FILE" 2>&1; then
    echo "PASS [shellcheck]"
    pass_count=$((pass_count+1))
    echo "shellcheck: OK" >>"$RESULT_FILE"
else
    echo "FAIL [shellcheck]" >&2
    fail_count=$((fail_count+1))
fi

{
    printf '\n==================== PRECHECK: actionlint ====================\n'
} >>"$RESULT_FILE"
if actionlint "$PROJECT_DIR/.github/workflows/pr-label-assigner.yml" \
        >>"$RESULT_FILE" 2>&1; then
    echo "PASS [actionlint]"
    pass_count=$((pass_count+1))
    echo "actionlint: OK" >>"$RESULT_FILE"
else
    echo "FAIL [actionlint]" >&2
    fail_count=$((fail_count+1))
fi

{
    printf '\n==================== PRECHECK: workflow_structure.bats ====================\n'
} >>"$RESULT_FILE"
if bats "$PROJECT_DIR/tests/workflow_structure.bats" >>"$RESULT_FILE" 2>&1; then
    echo "PASS [workflow_structure.bats]"
    pass_count=$((pass_count+1))
else
    echo "FAIL [workflow_structure.bats]" >&2
    fail_count=$((fail_count+1))
fi

# Files that must be copied into each temp repo.
COPY_ENTRIES=(
    "label-assigner.sh"
    "tests"
    ".github"
    ".actrc"
    "vendor"
)

# Build a temp repo for one test case.
# Args: temp_dir rules_content files_content
setup_case_repo() {
    local tmp="$1" rules="$2" files="$3"
    local entry
    for entry in "${COPY_ENTRIES[@]}"; do
        if [[ -e "$PROJECT_DIR/$entry" ]]; then
            cp -r "$PROJECT_DIR/$entry" "$tmp/"
        fi
    done
    mkdir -p "$tmp/fixtures"
    printf '%s' "$rules"  > "$tmp/fixtures/rules.conf"
    printf '%s' "$files"  > "$tmp/fixtures/files.txt"

    (
        cd "$tmp"
        git init -q -b main
        git config user.email "test@example.com"
        git config user.name "test"
        git add -A
        git commit -q -m "test case fixtures"
    )
}

# Run one test case through act and assert.
# Args: name expected_labels_newline_joined rules_content files_content
run_case() {
    local name="$1"
    local expected="$2"
    local rules="$3"
    local files="$4"

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    setup_case_repo "$tmp" "$rules" "$files"

    local log="$tmp/act.log"
    local status=0
    (
        cd "$tmp"
        # --pull=false: the mapped image is local-only (no registry copy).
        act push --rm --pull=false >"$log" 2>&1
    ) || status=$?

    {
        printf '\n==================== CASE: %s ====================\n' "$name"
        printf 'act exit status: %d\n' "$status"
        printf '%s\n' '------- act output -------'
        cat "$log"
        printf '%s\n' '------- end act output -------'
    } >>"$RESULT_FILE"

    local case_ok=1

    if [[ "$status" -ne 0 ]]; then
        echo "FAIL [$name]: act exited $status" >&2
        case_ok=0
    fi

    # Extract labels emitted between workflow markers.
    local labels
    labels="$(awk '
        /===LABELS_START===/ { capture=1; next }
        /===LABELS_END===/   { capture=0; next }
        capture { sub(/^[^|]*\|[[:space:]]*/, ""); print }
    ' "$log")"

    if [[ "$labels" != "$expected" ]]; then
        echo "FAIL [$name]: label output mismatch" >&2
        echo "  expected:" >&2
        printf '%s\n' "$expected" | sed 's/^/    /' >&2
        echo "  got:" >&2
        printf '%s\n' "$labels" | sed 's/^/    /' >&2
        case_ok=0
    fi

    # Every job should have a "Job succeeded" line.
    local expected_jobs=3  # lint, test, assign-labels
    local succeeded
    succeeded="$(grep -c 'Job succeeded' "$log" || true)"
    if (( succeeded < expected_jobs )); then
        echo "FAIL [$name]: expected >=${expected_jobs} 'Job succeeded' lines, got ${succeeded}" >&2
        case_ok=0
    fi

    if (( case_ok )); then
        echo "PASS [$name]"
        pass_count=$((pass_count+1))
    else
        fail_count=$((fail_count+1))
    fi
}

# ---------- Test cases ----------

# Case 1: the default committed fixtures exercise three rules.
# Rules: docs (10), api (30), tests (20), docker (15), ci (5)
# Files: docs/readme.md, src/api/v1/users.go, src/api/v1/users.test.go
# Expected labels by priority desc then name: api, tests, documentation.
run_case "default-fixtures" \
$'api\ntests\ndocumentation' \
'# Default PR label rules: pattern:label[:priority]
docs/**:documentation:10
src/api/**:api:30
**/*.test.*:tests:20
Dockerfile:docker:15
.github/**:ci:5
' \
'docs/readme.md
src/api/v1/users.go
src/api/v1/users.test.go
'

# Case 2: infra-only PR (Dockerfile + CI). Expect docker (15), ci (5).
run_case "infra-only" \
$'docker\nci' \
'docs/**:documentation:10
src/api/**:api:30
**/*.test.*:tests:20
Dockerfile:docker:15
.github/**:ci:5
' \
'Dockerfile
.github/workflows/deploy.yml
'

# Case 3: docs-only PR. Expect just documentation.
run_case "docs-only" \
'documentation' \
'docs/**:documentation:10
src/api/**:api:30
**/*.test.*:tests:20
' \
'docs/readme.md
docs/guide/getting-started.md
'

echo
echo "Summary: $pass_count passed, $fail_count failed"
if (( fail_count > 0 )); then
    exit 1
fi
