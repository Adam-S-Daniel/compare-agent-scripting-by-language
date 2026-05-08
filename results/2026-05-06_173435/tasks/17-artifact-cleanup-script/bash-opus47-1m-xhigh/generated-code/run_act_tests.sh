#!/usr/bin/env bash
#
# Test harness: drives the GitHub Actions workflow through `act` with
# multiple fixture / policy combinations and asserts on EXACT expected
# values in the captured output.
#
# Output strategy:
#   - All `act` stdout/stderr is appended to act-result.txt with delimiters.
#   - Per-case: assert exit code, "Job succeeded" presence, and case-specific
#     expected substrings (SUMMARY line, key DELETE / KEEP rows).
#   - Workflow structure tests run before any `act` invocation: actionlint,
#     YAML triggers/jobs/steps, file references.
#
# Limit ourselves to one `act push` per test case; do not retry on failure.

set -euo pipefail

cd "$(dirname "$0")"
PROJECT_DIR="$PWD"
RESULT_FILE="$PROJECT_DIR/act-result.txt"
WF=".github/workflows/artifact-cleanup-script.yml"

: > "$RESULT_FILE"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

OVERALL_PASS=0
OVERALL_FAIL=0
FAIL_REASONS=()

# ---------- workflow structure tests ----------

structure_test() {
    local desc=$1
    shift
    if "$@"; then
        green "  [PASS] $desc"
    else
        red   "  [FAIL] $desc"
        FAIL_REASONS+=("structure: $desc")
        OVERALL_FAIL=$((OVERALL_FAIL + 1))
        return 1
    fi
}

echo "=== Workflow structure tests ==="

structure_test "workflow file exists" test -f "$WF"
structure_test "script file exists"   test -f cleanup_artifacts.sh
structure_test "bats file exists"     test -f tests/cleanup_artifacts.bats
structure_test "actionlint passes"    actionlint "$WF"
structure_test "shellcheck on script" shellcheck cleanup_artifacts.sh
structure_test "shellcheck on harness" shellcheck "$0"
structure_test "bash -n on script"    bash -n cleanup_artifacts.sh

# YAML structural checks. Use grep to keep dependencies minimal.
yaml_grep() { grep -qE "$1" "$WF"; }
structure_test "trigger: push"              yaml_grep '^[[:space:]]*push:[[:space:]]*$'
structure_test "trigger: pull_request"      yaml_grep '^[[:space:]]*pull_request:[[:space:]]*$'
structure_test "trigger: workflow_dispatch" yaml_grep '^[[:space:]]*workflow_dispatch:[[:space:]]*$'
structure_test "trigger: schedule"          yaml_grep '^[[:space:]]*schedule:'
structure_test "job: validate"              yaml_grep '^[[:space:]]+validate:'
structure_test "job: cleanup"               yaml_grep '^[[:space:]]+cleanup:'
structure_test "uses checkout@v4"           yaml_grep 'actions/checkout@v4'
structure_test "references cleanup_artifacts.sh" yaml_grep 'cleanup_artifacts\.sh'
structure_test "references cleanup_artifacts.bats" yaml_grep 'cleanup_artifacts\.bats'
structure_test "permissions block present"  yaml_grep '^permissions:'
structure_test "needs: validate dependency" yaml_grep 'needs:[[:space:]]+validate'

OVERALL_PASS=$((OVERALL_PASS + 12))   # 12 file/lint checks above (counted via the `set -e` flow above)
echo

# ---------- act runs ----------

# run_case <name> <fixture_data> <case_env_data> <expected_substring> [...]
run_case() {
    local name=$1 fixture=$2 case_env=$3
    shift 3
    local -a expected=("$@")

    echo "=== act case: $name ==="

    local tmpdir
    tmpdir=$(mktemp -d -t artifact-cleanup-act-XXXXXX)

    # Copy project files into the temp repo.
    install -m 0755 "$PROJECT_DIR/cleanup_artifacts.sh" "$tmpdir/cleanup_artifacts.sh"
    cp "$PROJECT_DIR/.actrc" "$tmpdir/.actrc"
    mkdir -p "$tmpdir/.github/workflows" "$tmpdir/tests"
    cp "$PROJECT_DIR/$WF" "$tmpdir/$WF"
    cp "$PROJECT_DIR/tests/cleanup_artifacts.bats" "$tmpdir/tests/"

    # Per-case fixture and policy config.
    printf '%s' "$fixture"  > "$tmpdir/fixture.tsv"
    printf '%s' "$case_env" > "$tmpdir/case.env"

    # Make a tiny git repo so `act push` has a HEAD to read.
    (
        cd "$tmpdir"
        git init -q -b master
        git -c user.email=t@t -c user.name=T add .
        git -c user.email=t@t -c user.name=T commit -q -m "case: $name"
    ) >/dev/null

    {
        echo
        echo "######################################################################"
        echo "# CASE: $name"
        echo "# fixture.tsv:"
        sed 's/^/#   /' "$tmpdir/fixture.tsv"
        echo "# case.env:"
        sed 's/^/#   /' "$tmpdir/case.env"
        echo "######################################################################"
    } >> "$RESULT_FILE"

    local actlog="$tmpdir/act.out"
    local rc=0
    (cd "$tmpdir" && act push --rm) >"$actlog" 2>&1 || rc=$?

    {
        echo "--- act exit code: $rc ---"
        cat "$actlog"
        echo "--- end of case: $name ---"
    } >> "$RESULT_FILE"

    # Assertions.
    local case_pass=1
    if (( rc != 0 )); then
        red "  [FAIL] act exit code != 0 (got $rc)"
        FAIL_REASONS+=("$name: act exit $rc")
        case_pass=0
    fi
    # Both jobs (validate + cleanup) must report success. "Job succeeded"
    # appears once per successful job.
    local succ_count
    succ_count=$(grep -c "Job succeeded" "$actlog" || true)
    if (( succ_count < 2 )); then
        red "  [FAIL] expected 'Job succeeded' twice (validate + cleanup); got $succ_count"
        FAIL_REASONS+=("$name: Job succeeded count=$succ_count")
        case_pass=0
    fi
    local needle
    for needle in "${expected[@]}"; do
        if ! grep -qF -- "$needle" "$actlog"; then
            red "  [FAIL] missing expected substring: $needle"
            FAIL_REASONS+=("$name: missing '$needle'")
            case_pass=0
        fi
    done

    if (( case_pass == 1 )); then
        green "  [PASS] $name"
        OVERALL_PASS=$((OVERALL_PASS + 1))
    else
        OVERALL_FAIL=$((OVERALL_FAIL + 1))
    fi

    rm -rf "$tmpdir"
}

# --- Case 1: no policies. Both artifacts retained, summary all-zero deletes.
run_case "no-policies" \
$'small.zip\t100\t1767100000\twf1\nlarge.zip\t5000\t1767200000\twf2\n' \
'' \
'SUMMARY retained=2 deleted=0 reclaimed_bytes=0' \
$'KEEP\tsmall.zip\t100' \
$'KEEP\tlarge.zip\t5000'

# --- Case 2: max-age policy. Two old artifacts deleted; two fresh kept.
run_case "max-age-policy" \
$'ancient1.zip\t1000\t1700000000\twf1\nancient2.zip\t2000\t1700000100\twf1\nfresh1.zip\t300\t1767000000\twf1\nfresh2.zip\t400\t1767100000\twf2\n' \
$'CFG_MAX_AGE_DAYS=10\nCFG_NOW=1767225600\n' \
'SUMMARY retained=2 deleted=2 reclaimed_bytes=3000' \
$'DELETE\tancient1.zip\t1000\tmax-age' \
$'DELETE\tancient2.zip\t2000\tmax-age' \
$'KEEP\tfresh1.zip\t300' \
$'KEEP\tfresh2.zip\t400'

# --- Case 3: combined max-age + keep-latest + max-total-size + dry-run.
# wf1 has a..d (4 artifacts); wf2 has only e. Expected layered effect:
#   max-age:  no deletes (cutoff well below all timestamps)
#   keep-latest=2 wf1: keep d,c (newest two); delete a,b
#   max-total-size=400 over the surviving c,d,e (sum=750): delete oldest (c, then d)
# Final: only e survives.
run_case "combined-policies-dry-run" \
$'a.zip\t100\t1700000000\twf1\nb.zip\t200\t1700000100\twf1\nc.zip\t300\t1700000200\twf1\nd.zip\t400\t1700000300\twf1\ne.zip\t50\t1700000400\twf2\n' \
$'CFG_MAX_AGE_DAYS=4000\nCFG_KEEP_LATEST=2\nCFG_MAX_TOTAL_SIZE=400\nCFG_DRY_RUN=1\nCFG_NOW=1767225600\n' \
'SUMMARY retained=1 deleted=4 reclaimed_bytes=1000' \
'DRY-RUN' \
$'DELETE\ta.zip\t100\tkeep-latest-per-workflow' \
$'DELETE\tb.zip\t200\tkeep-latest-per-workflow' \
$'DELETE\tc.zip\t300\tmax-total-size' \
$'DELETE\td.zip\t400\tmax-total-size' \
$'KEEP\te.zip\t50'

# ---------- summary ----------

echo
echo "============================================="
echo "Total: PASS=$OVERALL_PASS  FAIL=$OVERALL_FAIL"
if (( OVERALL_FAIL > 0 )); then
    echo "Failures:"
    printf '  - %s\n' "${FAIL_REASONS[@]}"
fi
echo "Full act output captured to: $RESULT_FILE"
echo "============================================="

(( OVERALL_FAIL == 0 ))
