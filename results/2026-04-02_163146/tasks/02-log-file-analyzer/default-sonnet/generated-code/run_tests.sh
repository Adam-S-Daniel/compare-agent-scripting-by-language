#!/bin/bash
# Run the log analyzer tests.
# Installs pytest if not available, then runs both pytest and the
# standalone unittest runner.

set -e
cd "$(dirname "$0")"

echo "=== Installing pytest if needed ==="
if ! python3 -m pytest --version >/dev/null 2>&1; then
    pip3 install --user pytest
fi

echo ""
echo "=== Running pytest (with verbose output) ==="
python3 -m pytest test_log_analyzer.py -v

echo ""
echo "=== Running standalone unittest runner (also runs sample fixture) ==="
python3 run_tests.py
