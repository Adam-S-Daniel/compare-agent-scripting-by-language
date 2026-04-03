#!/usr/bin/env bash
# run-tests.sh — convenience script to install Pester (if needed) and run all tests
set -euo pipefail
cd "$(dirname "$0")"
pwsh -NoProfile -NonInteractive -File ./setup-and-test.ps1
