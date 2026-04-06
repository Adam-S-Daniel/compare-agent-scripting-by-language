#!/usr/bin/env bash
# Test runner script for test-results-aggregator
# Usage: bash run_tests.sh
set -e

cd "$(dirname "$0")"

echo "=== Installing pytest ==="
pip install pytest --quiet

echo ""
echo "=== Running tests ==="
python3 -m pytest test_aggregator.py -v

echo ""
echo "=== Done ==="
