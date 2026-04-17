#!/usr/bin/env pwsh
# Aggregate-TestResults.ps1
#
# CLI entry point for the TestResultsAggregator module. Intended to be called
# from a GitHub Actions job to collapse a matrix of test result files into a
# single markdown summary (suitable for $GITHUB_STEP_SUMMARY).
#
# Example:
#   pwsh ./Aggregate-TestResults.ps1 -InputDir ./fixtures -SummaryPath summary.md
#   pwsh ./Aggregate-TestResults.ps1 -Path a.xml,b.json -SummaryPath summary.md

[CmdletBinding(DefaultParameterSetName = 'Dir')]
param(
    # Directory containing one or more *.xml and/or *.json test result files.
    [Parameter(ParameterSetName = 'Dir')]
    [string]$InputDir,

    # Explicit list of files (use instead of -InputDir).
    [Parameter(ParameterSetName = 'Paths')]
    [string[]]$Path,

    # Path to write the markdown summary. Defaults to ./summary.md.
    [string]$SummaryPath = 'summary.md',

    # When set, emits a one-line totals recap to stdout for easy CI grepping.
    [switch]$PrintRecap,

    # When set, a non-zero exit code indicates at least one test failed.
    [switch]$FailOnTestFailures
)

$ErrorActionPreference = 'Stop'

$moduleFile = Join-Path $PSScriptRoot 'src' 'TestResultsAggregator.psm1'
if (-not (Test-Path -LiteralPath $moduleFile)) {
    Write-Error "Module not found: $moduleFile"
    exit 2
}
Import-Module $moduleFile -Force

# Resolve input paths from either -Path or -InputDir.
$paths = @()
if ($PSCmdlet.ParameterSetName -eq 'Paths') {
    $paths = $Path
} else {
    if (-not $InputDir) { $InputDir = 'fixtures' }
    if (-not (Test-Path -LiteralPath $InputDir -PathType Container)) {
        Write-Error "Input directory not found: $InputDir"
        exit 2
    }
    $paths = @(
        Get-ChildItem -LiteralPath $InputDir -File -Recurse |
            Where-Object { $_.Extension -in '.xml', '.json' } |
            Sort-Object FullName |
            ForEach-Object { $_.FullName }
    )
}

if (-not $paths -or $paths.Count -eq 0) {
    Write-Error 'No test result files provided.'
    exit 2
}

Write-Host "Aggregating $($paths.Count) test result file(s)..."
foreach ($p in $paths) { Write-Host "  - $p" }

$result = Invoke-TestResultsAggregator -Paths $paths -SummaryPath $SummaryPath

$t = $result.Aggregate.Totals
$recap = "TOTALS total=$($t.Total) passed=$($t.Passed) failed=$($t.Failed) skipped=$($t.Skipped) duration=$([math]::Round([double]$t.DurationSeconds, 3))s flaky=$(@($result.Flaky).Count) status=$($result.OverallStatus)"
Write-Host $recap
if ($PrintRecap) {
    # Separate line with a stable prefix for grep-based assertions.
    Write-Output "RECAP::$recap"
}

# Append to $GITHUB_STEP_SUMMARY when running inside GitHub Actions / act.
if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $result.Markdown
    Write-Host "Wrote summary to `$GITHUB_STEP_SUMMARY"
}
Write-Host "Wrote summary to $SummaryPath"

if ($FailOnTestFailures -and $result.OverallStatus -eq 'failed') {
    exit 1
}
exit 0
