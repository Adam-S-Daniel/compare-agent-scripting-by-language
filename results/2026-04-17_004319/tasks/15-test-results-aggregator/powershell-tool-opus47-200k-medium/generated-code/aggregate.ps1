#!/usr/bin/env pwsh
# Entry script: aggregate test result files into a markdown summary.
#
# Usage:
#   ./aggregate.ps1 -InputPaths file1.xml,file2.json -OutputPath summary.md
#
# When invoked inside a GitHub Actions job, pass $env:GITHUB_STEP_SUMMARY as
# -OutputPath to surface the summary on the workflow run page.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$InputPaths,
    [Parameter(Mandatory)][string]$OutputPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestResultsAggregator.psm1') -Force

# Expand globs for convenience when invoked from a shell.
$expanded = [System.Collections.Generic.List[string]]::new()
foreach ($p in $InputPaths) {
    $resolved = Get-ChildItem -Path $p -ErrorAction SilentlyContinue
    if ($resolved) { $resolved | ForEach-Object { $expanded.Add($_.FullName) } }
    elseif (Test-Path -LiteralPath $p) { $expanded.Add((Resolve-Path $p).Path) }
    else { throw "Input path not found: $p" }
}

if ($expanded.Count -eq 0) {
    throw 'No input files provided.'
}

Write-Host "Aggregating $($expanded.Count) test result file(s)..."
$agg = Get-AggregatedResults -Paths $expanded
$md = Format-MarkdownSummary -Aggregation $agg

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
Set-Content -LiteralPath $OutputPath -Value $md -Encoding utf8

# Emit key metrics to stdout so CI logs show them without reading the file.
$t = $agg.Totals
Write-Host "RESULT passed=$($t.Passed) failed=$($t.Failed) skipped=$($t.Skipped) total=$($t.Total) duration=$([Math]::Round($t.Duration, 2)) flaky=$($agg.Flaky.Count)"
foreach ($f in $agg.Flaky) {
    Write-Host "FLAKY $($f.Name) passes=$($f.Passes) failures=$($f.Failures)"
}

# Non-zero exit when failures exist (but flaky tests alone are not fatal).
if ($t.Failed -gt 0 -and $t.Failed -gt $agg.Flaky.Count) {
    exit 1
}
exit 0
