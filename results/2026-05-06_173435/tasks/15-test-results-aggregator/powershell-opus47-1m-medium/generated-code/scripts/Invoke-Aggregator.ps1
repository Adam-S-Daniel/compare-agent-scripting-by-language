#!/usr/bin/env pwsh
# CLI wrapper for the TestResultsAggregator module. Designed to run inside a
# GitHub Actions step. Reads test result files from -InputDirectory, writes
# the markdown summary to -OutputPath (default: $GITHUB_STEP_SUMMARY when set,
# else ./test-summary.md), prints the summary to the log, and exits non-zero
# if any test failed (overridable via -AllowFailures).

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputDirectory,
    [string] $OutputPath,
    [switch] $AllowFailures
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..' 'src' 'TestResultsAggregator.psm1'
Import-Module $modulePath -Force

if (-not $OutputPath) {
    if ($env:GITHUB_STEP_SUMMARY) {
        $OutputPath = $env:GITHUB_STEP_SUMMARY
    } else {
        $OutputPath = Join-Path (Get-Location) 'test-summary.md'
    }
}

Write-Host "Aggregating test results from: $InputDirectory"
$summary = Invoke-TestResultsAggregator -InputDirectory $InputDirectory -OutputPath $OutputPath

# Echo the markdown to the workflow log so the act harness can assert on it.
Write-Host '----- BEGIN SUMMARY -----'
Get-Content -LiteralPath $OutputPath -Raw
Write-Host '----- END SUMMARY -----'

# Machine-readable totals for harness assertions.
Write-Host ("AGG_TOTAL={0}"    -f $summary.Total)
Write-Host ("AGG_PASSED={0}"   -f $summary.Passed)
Write-Host ("AGG_FAILED={0}"   -f $summary.Failed)
Write-Host ("AGG_SKIPPED={0}"  -f $summary.Skipped)
Write-Host ("AGG_DURATION={0}" -f $summary.DurationSeconds)

if ($summary.Failed -gt 0 -and -not $AllowFailures) {
    Write-Host "::error::$($summary.Failed) test(s) failed."
    exit 1
}
exit 0
