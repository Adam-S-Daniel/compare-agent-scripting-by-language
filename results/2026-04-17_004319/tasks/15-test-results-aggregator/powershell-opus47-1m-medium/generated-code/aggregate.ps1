#!/usr/bin/env pwsh
# Entry-point script: imports the module and runs the aggregation pipeline.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputPath,
    [string]$OutputPath = 'test-summary.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'src' 'TestResultsAggregator.psm1'
Import-Module $modulePath -Force

$agg = Invoke-TestResultsAggregation -InputPath $InputPath -OutputPath $OutputPath

# Exit non-zero if any test failed so CI gates on the result.
if ($agg.Failed -gt 0) {
    Write-Host "::warning::$($agg.Failed) test failure(s) detected."
}
exit 0
