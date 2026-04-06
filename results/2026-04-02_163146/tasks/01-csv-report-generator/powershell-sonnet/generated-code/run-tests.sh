#!/bin/bash
# Run Pester tests
cd "$(dirname "$0")"
pwsh -Command "Invoke-Pester ./tests/CsvReportGenerator.Tests.ps1 -Output Detailed"
