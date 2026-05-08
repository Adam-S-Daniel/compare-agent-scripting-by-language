#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CLI entry point that wraps Invoke-TestResultsAggregator for use from a
    GitHub Actions step (or any shell).

.DESCRIPTION
    Reads test result files (JUnit XML or JSON) from -InputPath, aggregates
    them, prints a small summary to stdout, and writes the full Markdown
    summary to -OutputPath. If $env:GITHUB_STEP_SUMMARY is set, the markdown
    is also appended there so it shows up in the GitHub Actions job summary.

    Exit codes:
        0  — all good (no failed tests, parsing succeeded)
        1  — one or more failed tests, OR no fixtures found
        2  — script-level error (bad input path, malformed file, etc.)

.PARAMETER InputPath
    Path to a directory containing .xml/.json files, or a single file.

.PARAMETER OutputPath
    Where to write the rendered markdown. Defaults to test-summary.md.

.PARAMETER FailOnTestFailure
    When $true (default), exit non-zero if any test failed. Set to $false
    in CI legs that just want to publish the summary.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputPath,

    [string]$OutputPath = 'test-summary.md',

    [bool]$FailOnTestFailure = $true
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Resolve the module relative to *this script* — keeps the CLI portable.
$modulePath = Join-Path $PSScriptRoot 'src' 'TestResultsAggregator.psm1'
Import-Module $modulePath -Force

try {
    $result = Invoke-TestResultsAggregator -InputPath $InputPath -OutputPath $OutputPath -PassThru
} catch {
    Write-Error "Aggregation failed: $($_.Exception.Message)"
    exit 2
}

Write-Host ''
Write-Host '=== Test Results Aggregator ==='
Write-Host ("Files aggregated : {0} run(s)" -f $result.Totals.RunCount)
Write-Host ("Total tests      : {0}" -f $result.Totals.Total)
Write-Host ("Passed           : {0}" -f $result.Totals.Passed)
Write-Host ("Failed           : {0}" -f $result.Totals.Failed)
Write-Host ("Skipped          : {0}" -f $result.Totals.Skipped)
Write-Host ("Duration         : {0:N2}s" -f $result.Totals.Duration)
Write-Host ("Flaky tests      : {0}" -f $result.Flaky.Count)
Write-Host ("Markdown summary : {0}" -f $result.OutputPath)
Write-Host ''

# Append to the GitHub Actions step summary when running in a workflow.
if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $result.Markdown
    Write-Host "Wrote summary to GITHUB_STEP_SUMMARY: $($env:GITHUB_STEP_SUMMARY)"
}

if ($FailOnTestFailure -and $result.HasFailures) {
    Write-Host "::error::$($result.Totals.Failed) test(s) failed"
    exit 1
}

exit 0
