#!/usr/bin/env bash
# Test harness: drives the workflow under `act`, captures output, and
# asserts on exact expected substrings. Writes a combined log to
# act-result.txt in the project root.
#
# We mutate `fixtures/package.json` per test case so the same workflow
# job exercises different inputs. Each test case is one `act push` run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_FILE="$ROOT/act-result.txt"
: > "$RESULT_FILE"

pass=0
fail=0

run_case() {
    local name="$1"; shift
    local fixture_file="$1"; shift
    local -a expected=("$@")

    echo "=========================================" | tee -a "$RESULT_FILE"
    echo "TEST CASE: $name" | tee -a "$RESULT_FILE"
    echo "=========================================" | tee -a "$RESULT_FILE"

    # Stage fixture as fixtures/package.json (workflow's default manifest).
    cp "$ROOT/$fixture_file" "$ROOT/fixtures/package.json"

    local tmp_repo
    tmp_repo="$(mktemp -d)"
    # Copy project into temp repo for an isolated git context.
    cp -r "$ROOT/." "$tmp_repo/"
    (
        cd "$tmp_repo"
        rm -rf .git
        git init -q
        git config user.email t@example.com
        git config user.name test
        git add -A
        git commit -q -m "test fixture"
    )

    local out
    set +e
    out="$(cd "$tmp_repo" && act push --rm --pull=false -W .github/workflows/dependency-license-checker.yml 2>&1)"
    local rc=$?
    set -e
    echo "$out" >> "$RESULT_FILE"
    echo "--- act exit: $rc ---" >> "$RESULT_FILE"

    rm -rf "$tmp_repo"

    local case_ok=1
    if [[ $rc -ne 0 ]]; then
        echo "FAIL: act exited $rc for case '$name'"
        case_ok=0
    fi
    if ! grep -q "Job succeeded" <<<"$out"; then
        echo "FAIL: 'Job succeeded' not found for '$name'"
        case_ok=0
    fi
    for needle in "${expected[@]}"; do
        if ! grep -qF -- "$needle" <<<"$out"; then
            echo "FAIL: expected substring not found for '$name': $needle"
            case_ok=0
        fi
    done

    if (( case_ok )); then
        echo "PASS: $name"
        pass=$((pass+1))
    else
        fail=$((fail+1))
    fi
}

# Stage fixture variants under test/fixtures-act/ so we can swap them in.
mkdir -p "$ROOT/test/fixtures-act"

cat > "$ROOT/test/fixtures-act/all-approved.json" <<'EOF'
{
  "name": "demo",
  "version": "1.0.0",
  "dependencies": {
    "leftpad": "1.0.0",
    "axios": "0.27.2"
  },
  "devDependencies": {
    "jest": "29.0.0"
  }
}
EOF

cat > "$ROOT/test/fixtures-act/has-denied.json" <<'EOF'
{
  "name": "demo",
  "version": "1.0.0",
  "dependencies": {
    "axios": "0.27.2",
    "gpl-package": "1.0.0"
  }
}
EOF

cat > "$ROOT/test/fixtures-act/has-unknown.json" <<'EOF'
{
  "name": "demo",
  "version": "1.0.0",
  "dependencies": {
    "leftpad": "1.0.0",
    "mystery": "0.1.0"
  }
}
EOF

# Case 1 — all dependencies have approved licenses.
run_case "all-approved" \
    "test/fixtures-act/all-approved.json" \
    "leftpad" "MIT" "APPROVED" \
    "Summary: approved=3 denied=0 unknown=0"

# Case 2 — one dependency uses a denied license; report should call it out
# and show a denied count of 1, but workflow still succeeds (non-strict).
run_case "has-denied" \
    "test/fixtures-act/has-denied.json" \
    "gpl-package" "GPL-3.0" "DENIED" \
    "Summary: approved=1 denied=1 unknown=0"

# Case 3 — a package whose license is mapped to an off-list value should
# end up classified as UNKNOWN.
run_case "has-unknown" \
    "test/fixtures-act/has-unknown.json" \
    "mystery" "UNKNOWN" \
    "Summary: approved=1 denied=0 unknown=1"

echo "===========" | tee -a "$RESULT_FILE"
echo "Pass: $pass  Fail: $fail" | tee -a "$RESULT_FILE"

if (( fail > 0 )); then
    exit 1
fi
