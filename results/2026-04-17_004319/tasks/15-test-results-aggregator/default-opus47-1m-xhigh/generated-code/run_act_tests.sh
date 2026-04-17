#!/usr/bin/env bash
# Test harness: runs every fixture case through `act push --rm`, appending
# output to act-result.txt, and fails if any case's exit code or aggregated
# numbers don't match the expected values defined in tests/test_workflow.py.
#
# This script is the required artifact producer: act-result.txt must exist
# after it runs.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# Start fresh so we don't mix old output in.
: > act-result.txt

# Install pyyaml for the workflow structure tests, pytest for running them.
python3 -m pip install --quiet --user pytest pyyaml >/dev/null 2>&1 || true

# Structure tests (fast: YAML parse + actionlint).
echo "== Running workflow structure tests =="
python3 -m pytest tests/test_workflow.py -v -k "not test_act_" --no-header

# Act-backed tests (slow: ~30-90s per case, plus Docker overhead).
echo "== Running act-backed tests =="
RUN_ACT=1 python3 -m pytest tests/test_workflow.py::test_act_run_matches_expected \
    tests/test_workflow.py::test_act_result_file_produced \
    -v -s --no-header

echo "== All tests passed =="
echo "act-result.txt size: $(wc -c < act-result.txt) bytes"
