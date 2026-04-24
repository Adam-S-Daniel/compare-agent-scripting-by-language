#!/usr/bin/env bash
# test-harness.sh
#
# Runs matrix-generator.sh against every fixture in tests/fixtures/ and prints
# each result framed by `===CASE:<name>===` / `===END:<name>===` delimiters so
# the bats suite can parse a single `act` invocation's combined output and
# assert per-case expectations.
#
# Exit behavior: the harness always exits 0 (so the workflow step succeeds);
# per-case exit codes are embedded in the framed output as `EXIT:<code>`.
# This lets us test error paths (max_size overflow, invalid JSON, ...) through
# the same pipeline without tripping `set -e` at the step boundary.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="${SCRIPT_DIR}/tests/fixtures"

if [[ ! -d "$FIXTURE_DIR" ]]; then
    echo "error: no fixture directory at $FIXTURE_DIR" >&2
    exit 1
fi

shopt -s nullglob
cases=("$FIXTURE_DIR"/*.json)
if (( ${#cases[@]} == 0 )); then
    echo "error: no fixtures found in $FIXTURE_DIR" >&2
    exit 1
fi

echo "harness: running ${#cases[@]} fixture(s)"

for fixture in "${cases[@]}"; do
    name="$(basename "$fixture" .json)"
    echo "===CASE:${name}==="
    # Run the script and capture stdout+stderr together with exit code so the
    # harness output is a single stream regardless of success/failure.
    set +e
    out="$("${SCRIPT_DIR}/matrix-generator.sh" "$fixture" 2>&1)"
    rc=$?
    set -e
    printf '%s\n' "$out"
    echo "EXIT:${rc}"
    echo "===END:${name}==="
done

echo "harness: done"
