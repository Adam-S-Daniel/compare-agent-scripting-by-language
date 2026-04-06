#!/usr/bin/env bash
# run-tests.sh — convenience wrapper to execute Pester tests
set -e
cd "$(dirname "$0")"
pwsh -NoProfile -Command "Invoke-Pester -Path './DatabaseSeed.Tests.ps1' -Output Detailed"
