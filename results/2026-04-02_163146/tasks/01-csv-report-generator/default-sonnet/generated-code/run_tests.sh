#!/usr/bin/env bash
# Run all tests and display results
set -e
python3 -m unittest test_csv_report -v
