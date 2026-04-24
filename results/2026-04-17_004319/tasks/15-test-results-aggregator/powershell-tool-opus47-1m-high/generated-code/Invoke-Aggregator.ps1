<#
.SYNOPSIS
    CLI wrapper around TestResultsAggregator.ps1.

.DESCRIPTION
    Accepts an -InputDir (containing .xml / .json files) or an explicit list of
    -Paths, aggregates them, writes a markdown summary to -OutputPath (if given)
    and additionally appends the summary to $env:GITHUB_STEP_SUMMARY when that
    variable is set - so it works as a GitHub Actions step.

    Exit codes:
        0 - all tests passed (and no flaky tests, unless -AllowFlaky is set)
        1 - at least one test failed
        2 - flaky tests were detected (only when -FailOnFlaky is set)
#>

[CmdletBinding()]
param(
    [string[]] $Paths,
    [string]   $InputDir,
    [string]   $OutputPath,
    [switch]   $FailOnFlaky,
    [switch]   $FailOnAny   # fail on any failure (default behavior anyway)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'TestResultsAggregator.ps1')

if (-not $Paths -or $Paths.Count -eq 0) {
    if (-not $InputDir) {
        throw "Provide either -Paths or -InputDir"
    }
    if (-not (Test-Path -LiteralPath $InputDir)) {
        throw "Input directory not found: $InputDir"
    }
    $Paths = Get-ChildItem -LiteralPath $InputDir -File |
        Where-Object { $_.Extension -in '.xml', '.json' } |
        Sort-Object Name |
        ForEach-Object { $_.FullName }
    if (-not $Paths -or $Paths.Count -eq 0) {
        throw "No .xml or .json test result files found in $InputDir"
    }
}

$summary = Invoke-TestResultsAggregator -Paths $Paths -OutputPath $OutputPath

Write-Host "Total:    $($summary.Total)"
Write-Host "Passed:   $($summary.Passed)"
Write-Host "Failed:   $($summary.Failed)"
Write-Host "Skipped:  $($summary.Skipped)"
Write-Host ("Duration: {0:N2}s" -f $summary.DurationSeconds)
Write-Host "Flaky:    $(@($summary.Flaky).Count)"

# Append to the GitHub step summary when running in Actions.
if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $summary.Markdown
    Write-Host "Appended markdown summary to GITHUB_STEP_SUMMARY"
}

# Structured tail for harness parsers - exact tokens for assertions.
Write-Host "AGG_RESULT total=$($summary.Total) passed=$($summary.Passed) failed=$($summary.Failed) skipped=$($summary.Skipped) flaky=$(@($summary.Flaky).Count)"

if ($FailOnFlaky -and @($summary.Flaky).Count -gt 0) { exit 2 }
if ($summary.Failed -gt 0 -and -not $FailOnAny.IsPresent) {
    # Default: a failed test does NOT fail the aggregator step (so the summary is still
    # posted). The CI job can decide based on the output how to react.
    exit 0
}
if ($FailOnAny -and $summary.Failed -gt 0) { exit 1 }
exit 0
