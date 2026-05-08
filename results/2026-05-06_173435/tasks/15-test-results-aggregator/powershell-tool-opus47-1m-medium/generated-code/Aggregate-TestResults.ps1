#!/usr/bin/env pwsh
# CLI entry point. Reads test result files from -InputDir, writes a
# markdown summary to -OutFile, and prints the aggregate JSON to stdout
# so CI assertions can grep for exact totals.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputDir,
    [Parameter(Mandatory)] [string] $OutFile,
    [string] $StepSummaryPath = $env:GITHUB_STEP_SUMMARY,
    [switch] $FailOnFailures
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Aggregator.psm1') -Force

$result = Invoke-Aggregator -InputDir $InputDir -OutFile $OutFile

# Append to GitHub Actions job summary if running in CI.
if ($StepSummaryPath -and (Test-Path -LiteralPath $StepSummaryPath -ErrorAction SilentlyContinue)) {
    Add-Content -LiteralPath $StepSummaryPath -Value (Get-Content -LiteralPath $OutFile -Raw)
}

$t = $result.Aggregate.Totals
$flakyCount = $result.Aggregate.Flaky.Count
Write-Host "AGG_PASSED=$($t.Passed)"
Write-Host "AGG_FAILED=$($t.Failed)"
Write-Host "AGG_SKIPPED=$($t.Skipped)"
Write-Host "AGG_FLAKY=$flakyCount"
Write-Host "AGG_RUNS=$($t.Runs)"
Write-Host "AGG_DURATION=$('{0:N2}' -f $t.Duration)"

if ($FailOnFailures -and $t.Failed -gt 0 -and $flakyCount -eq 0) {
    # Hard failures (no flake masking) -> non-zero exit so the CI step fails.
    Write-Error "There were $($t.Failed) hard test failure(s)."
    exit 1
}
