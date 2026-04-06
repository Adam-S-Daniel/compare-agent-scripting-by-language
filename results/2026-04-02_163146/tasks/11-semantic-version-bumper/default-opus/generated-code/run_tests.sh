#!/bin/bash
# Run the test suite. Uses unittest (stdlib) — no pip install needed.
set -euo pipefail
cd "$(dirname "$0")"
python3 -m pytest test_version_bumper.py -v 2>/dev/null || python3 -m unittest test_version_bumper -v
