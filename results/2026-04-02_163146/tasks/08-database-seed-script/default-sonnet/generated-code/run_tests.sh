#!/usr/bin/env bash
# Run all tests and the seed script CLI.
set -euo pipefail

echo "=== Running tests ==="
python3 -m unittest test_database_seed -v

echo ""
echo "=== Running seed script CLI ==="
python3 database_seed.py seed.db

echo ""
echo "All done."
