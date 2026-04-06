#!/usr/bin/env bash
# Install dependencies and run all tests
# Usage: bash run_tests.sh

set -e

echo "=== Installing dependencies ==="
pip3 install -r requirements.txt --quiet

echo "=== Running tests ==="
python3 -m pytest test_process_monitor.py -v

echo "=== Done ==="
