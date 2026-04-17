<#
.SYNOPSIS
  Aggregates JUnit XML + JSON test result files into a markdown summary suitable
  for a GitHub Actions job summary. Writes the summary to $env:GITHUB_STEP_SUMMARY
  when present, otherwise to the -OutputPath (defaults to ./test-summary.md).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputDir,
    [string]$OutputPath = 'test-summary.md',
    [int]$FailIfFailures = 0
)

$ErrorActionPreference = 'Stop'
$ModulePath = Join-Path $PSScriptRoot 'TestResultsAggregator.psm1'
Import-Module $ModulePath -Force

if (-not (Test-Path -LiteralPath $InputDir)) {
    throw "Input directory not found: $InputDir"
}

$files = Get-ChildItem -LiteralPath $InputDir -Recurse -File |
    Where-Object { $_.Extension -in '.xml', '.json' } |
    Sort-Object FullName

if (-not $files) {
    throw "No .xml or .json result files found under $InputDir"
}

Write-Host "Found $($files.Count) result file(s)."
$agg = Get-AggregatedResults -Paths $files.FullName
$md  = Format-MarkdownSummary -Aggregate $agg

# Always write to OutputPath for local / artifact use.
Set-Content -LiteralPath $OutputPath -Value $md -Encoding utf8
Write-Host "Wrote markdown summary to $OutputPath"

# GitHub Actions job summary file, if available.
if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $md -Encoding utf8
    Write-Host "Appended summary to GITHUB_STEP_SUMMARY."
}

# Print key totals on stdout so CI logs (and act output assertions) can match.
$t = $agg.Totals
Write-Host "TOTAL=$($t.Total) PASSED=$($t.Passed) FAILED=$($t.Failed) SKIPPED=$($t.Skipped) FLAKY=$($agg.FlakyTests.Count)"

if ($FailIfFailures -and $t.Failed -gt 0) {
    Write-Error "Failing: $($t.Failed) test failure(s) detected."
    exit 1
}
exit 0
