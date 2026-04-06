#!/bin/bash
# run-tests.sh - Run the Pester test suite
cd "$(dirname "$0")"
pwsh -NoProfile run-tests.ps1
