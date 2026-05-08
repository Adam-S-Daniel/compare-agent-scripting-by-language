#!/usr/bin/env pwsh
#requires -Version 7.0
<#
.SYNOPSIS
    CLI entry point for the test results aggregator.
.DESCRIPTION
    Walks a directory of JUnit XML and JSON test result files (one per matrix
    leg), aggregates them, identifies flaky tests, and writes a markdown
    summary suitable for $GITHUB_STEP_SUMMARY.

    Output written to:
      - the file passed via -SummaryPath
      - $GITHUB_STEP_SUMMARY (if set, e.g. when running in GitHub Actions)
      - stdout (always, so it shows up in act logs)

    Exit code: 0 if no failures, 1 if any test failed (so the workflow step
    can fail the build by default; pass -AllowFailures to disable).
.PARAMETER InputDirectory
    Directory containing *.xml (JUnit) or *.json result files.
.PARAMETER SummaryPath
    Optional path to write the markdown summary to.
.PARAMETER AllowFailures
    If set, exit 0 even if some tests failed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputDirectory,
    [string] $SummaryPath,
    [switch] $AllowFailures
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModulePath = Join-Path $PSScriptRoot 'TestResultsAggregator.psm1'
Import-Module $ModulePath -Force

try {
    $result = Invoke-AggregateTestResults `
        -InputDirectory $InputDirectory `
        -OutputMarkdown $SummaryPath
}
catch {
    Write-Error $_.Exception.Message
    exit 2
}

# Always echo the markdown to stdout so act logs show it.
Write-Output $result.Markdown

# Mirror to GitHub Actions step summary when available.
if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $result.Markdown
}

# Emit a few one-line, machine-greppable totals so harnesses can match exact
# values without parsing the markdown table.
$t = $result.Totals
Write-Output ("AGGREGATE_TOTAL={0}"    -f $t.Total)
Write-Output ("AGGREGATE_PASSED={0}"   -f $t.Passed)
Write-Output ("AGGREGATE_FAILED={0}"   -f $t.Failed)
Write-Output ("AGGREGATE_SKIPPED={0}"  -f $t.Skipped)
Write-Output ("AGGREGATE_DURATION={0:F2}" -f $t.Duration)
Write-Output ("AGGREGATE_FLAKY={0}"    -f $result.Flaky.Count)

if ($AllowFailures) {
    exit 0
}
exit $result.FailureExit
