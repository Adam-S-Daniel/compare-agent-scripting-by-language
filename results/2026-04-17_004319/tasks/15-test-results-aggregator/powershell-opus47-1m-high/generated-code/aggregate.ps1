<#
.SYNOPSIS
Aggregate JUnit XML and JSON test results and emit a markdown summary.

.DESCRIPTION
Scans -InputDir for *.xml and *.json result files, parses each, aggregates
totals, detects flaky tests, and emits:
  * a line-oriented summary on stdout that is easy to grep from CI
  * a full markdown summary, written to -OutFile and (if present)
    appended to $env:GITHUB_STEP_SUMMARY so it shows up on the
    GitHub Actions job summary page.

Exits non-zero only on file-system / parse errors. The presence of
failed tests does NOT fail this script; aggregation is a reporting
step, not the test runner itself.

.EXAMPLE
    pwsh ./aggregate.ps1 -InputDir ./tests/fixtures/default -OutFile summary.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputDir,
    [string]$OutFile
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'src/TestResultsAggregator.psm1'
Import-Module $modulePath -Force

if (-not (Test-Path -LiteralPath $InputDir)) {
    throw "Input directory not found: $InputDir"
}

# Wrap in @(...) so .Count works even when one file is returned (strict mode).
$files = @(Get-ChildItem -Path $InputDir -Include *.xml, *.json -File -Recurse)
if ($files.Count -eq 0) {
    throw "No test result files (.xml or .json) found in: $InputDir"
}

Write-Host "Discovered $($files.Count) result file(s) in $InputDir"
$runs = foreach ($f in $files) {
    Write-Host "  - parsing $($f.Name)"
    Import-TestResults -Path $f.FullName
}

$agg = Merge-TestRuns -Runs $runs
$md  = Format-GitHubSummary -Aggregate $agg

# Line-oriented, grep-friendly totals — used by the act test harness
# to assert exact expected values against the workflow's output.
Write-Host ("TOTALS: TotalTests={0} Passed={1} Failed={2} Skipped={3} Flaky={4} Runs={5}" -f `
    $agg.TotalTests, $agg.TotalPassed, $agg.TotalFailed, $agg.TotalSkipped, `
    $agg.FlakyTests.Count, $agg.Runs.Count)

foreach ($f in $agg.FlakyTests) {
    Write-Host ("FLAKY: {0}::{1} statuses=[{2}] runs={3}" -f `
        $f.ClassName, $f.Name, ($f.Statuses -join '|'), $f.RunCount)
}

if ($OutFile) {
    $md | Set-Content -LiteralPath $OutFile -Encoding utf8
    Write-Host "Wrote markdown summary to $OutFile"
}

if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $md -Encoding utf8
    Write-Host "Appended markdown to GITHUB_STEP_SUMMARY"
}
