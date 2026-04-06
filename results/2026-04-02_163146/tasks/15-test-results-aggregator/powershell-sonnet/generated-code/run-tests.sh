#!/usr/bin/env bash
# Run Pester tests for the Test Results Aggregator
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec pwsh -NonInteractive -NoProfile -Command "
    Set-Location '$SCRIPT_DIR'
    Invoke-Pester -Path './TestResultsAggregator.Tests.ps1' -Output Detailed
"
