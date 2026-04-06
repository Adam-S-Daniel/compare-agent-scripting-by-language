#!/bin/bash
# Test runner script for semantic version bumper
# Run: bash run_tests.sh

set -e

# Install pytest if not available
if ! python3 -c "import pytest" 2>/dev/null; then
    pip3 install pytest
fi

# Run tests with verbose output
python3 -m pytest test_semver_bumper.py -v
