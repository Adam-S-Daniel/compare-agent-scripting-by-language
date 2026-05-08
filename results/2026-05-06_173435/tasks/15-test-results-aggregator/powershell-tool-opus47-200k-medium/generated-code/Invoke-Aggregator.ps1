#!/usr/bin/env pwsh
# CLI wrapper for the TestResultsAggregator module.
# Aggregates test results in -InputDir and prints a markdown summary.
# When $env:GITHUB_STEP_SUMMARY is set, the markdown is also written there.
# Emits a single machine-parsable line beginning with "AGGREGATE_RESULT::"
# so CI can assert on exact totals.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputDir,
    [string]$OutputFile
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'TestResultsAggregator.psm1'
Import-Module $modulePath -Force

$result = Invoke-Aggregator -InputDir $InputDir -OutputFile $OutputFile
$agg = $result.Aggregated

Write-Output $result.Markdown

if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $result.Markdown
}

# Emit a single line of structured metrics for CI assertions.
$flakyNames = ($agg.FlakyTests | ForEach-Object { $_.Test }) -join ','
if (-not $flakyNames) { $flakyNames = 'none' }
"AGGREGATE_RESULT:: TOTAL=$($agg.TotalTests) PASSED=$($agg.TotalPassed) FAILED=$($agg.TotalFailed) SKIPPED=$($agg.TotalSkipped) RUNS=$($agg.RunCount) FLAKY=$flakyNames"

# Exit nonzero if any tests failed AND there are no flaky tests masking them.
# For this aggregator we always exit 0 so CI can post the summary regardless.
exit 0
