#!/usr/bin/env pwsh
# CLI entry point. Reads test result files (.xml/.json) from -InputPath
# (file or directory), aggregates them, and writes a markdown summary to
# -OutputPath. Used by the GitHub Actions workflow and by the act harness.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputPath,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..' 'src' 'TestResultsAggregator.psm1'
Import-Module $modulePath -Force

$agg = Invoke-TestResultsAggregator -InputPath $InputPath -OutputPath $OutputPath
$t   = $agg.Totals

# Single-line, parseable summary so the workflow & act harness can grep for it.
"AGGREGATE: runs=$($agg.RunCount) total=$($t.Total) passed=$($t.Passed) failed=$($t.Failed) skipped=$($t.Skipped) flaky=$(@($agg.Flaky).Count) duration=$($t.Duration)"

# Mirror to GitHub Actions job summary if the env var is set.
if ($env:GITHUB_STEP_SUMMARY) {
    Get-Content -LiteralPath $OutputPath -Raw | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY
}

# Exit non-zero if there were any non-flaky failures and the caller asked for it.
if ($env:FAIL_ON_FAILURE -eq 'true' -and $t.Failed -gt 0) {
    exit 1
}
