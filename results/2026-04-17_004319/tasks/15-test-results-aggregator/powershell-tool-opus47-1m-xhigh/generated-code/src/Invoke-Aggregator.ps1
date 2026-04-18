<#
.SYNOPSIS
    CLI entrypoint for TestResultsAggregator. Reads test-result files,
    aggregates totals, detects flaky tests, and prints Markdown.

.DESCRIPTION
    Designed for use from a GitHub Actions `run:` step or locally.
    When $env:GITHUB_STEP_SUMMARY is defined, the Markdown is appended
    there so the summary shows up on the job page.

.PARAMETER InputPath
    Directory containing test-result files, or a single file path.

.PARAMETER EmitAssertions
    If set, also prints machine-readable single-line assertion tokens
    (ASSERT_TOTAL=..., ASSERT_FLAKY=..., etc.) that the act test
    harness parses to validate workflow output.

.PARAMETER FailOnTestFailure
    If set, exits with code 1 when any aggregated test failed.
    Off by default: the aggregator is a reporting tool and the input
    data may legitimately contain failures from the upstream test run.
#>
param(
    [Parameter(Mandatory)][string]$InputPath,
    [switch]$EmitAssertions,
    [switch]$FailOnTestFailure
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot 'TestResultsAggregator.psm1'
Import-Module $modulePath -Force

if (-not (Test-Path -LiteralPath $InputPath)) {
    Write-Error "Input path not found: $InputPath"
    exit 2
}

$resultSets = Import-TestResults -Path $InputPath
if (@($resultSets).Count -eq 0) {
    Write-Error "No .xml or .json test-result files found under: $InputPath"
    exit 3
}

$aggregated = Get-AggregatedResults -ResultSets $resultSets
$flaky      = @(Get-FlakyTest -ResultSets $resultSets)
$markdown   = New-SummaryMarkdown -Aggregated $aggregated -FlakyTests $flaky

# Bracketed delimiters make it easy for the act harness to slice the markdown
# out of the surrounding workflow log noise.
Write-Output '----- AGGREGATOR BEGIN -----'
Write-Output $markdown
Write-Output '----- AGGREGATOR END -----'

if ($EmitAssertions) {
    Write-Output "ASSERT_FILES=$($aggregated.Files)"
    Write-Output "ASSERT_TOTAL=$($aggregated.TotalTests)"
    Write-Output "ASSERT_PASSED=$($aggregated.Passed)"
    Write-Output "ASSERT_FAILED=$($aggregated.Failed)"
    Write-Output "ASSERT_SKIPPED=$($aggregated.Skipped)"
    Write-Output "ASSERT_DURATION=$($aggregated.Duration)"
    Write-Output "ASSERT_FLAKY_COUNT=$($flaky.Count)"
    foreach ($f in $flaky) { Write-Output "ASSERT_FLAKY=$($f.Name)" }
}

if ($env:GITHUB_STEP_SUMMARY) {
    $markdown | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}

if ($FailOnTestFailure -and $aggregated.Failed -gt 0) {
    Write-Error "$($aggregated.Failed) test(s) failed across $($aggregated.Files) file(s)"
    exit 1
}
exit 0
