#!/usr/bin/env pwsh
#requires -Version 7.0

<#
.SYNOPSIS
    CLI entry point for the test-results aggregator.

.DESCRIPTION
    Reads JUnit XML and JSON test result files from -InputDirectory,
    aggregates totals (passed/failed/skipped/duration), identifies flaky
    tests (tests with both passed and failed outcomes across runs), and
    writes a markdown summary to -OutputPath.

    When $env:GITHUB_STEP_SUMMARY is set (running inside a GitHub Actions
    job), the markdown is also appended there so it appears as a job
    summary in the Actions UI. The same content is echoed to stdout so
    the act/CI logs contain assertable lines for tests.

.PARAMETER InputDirectory
    Directory containing test result files (*.xml for JUnit, *.json).

.PARAMETER OutputPath
    Path to write the markdown summary file. Default: ./summary.md
#>
param(
    [Parameter(Mandatory)] [string] $InputDirectory,
    [string] $OutputPath = './summary.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the module relative to this script so the workflow only needs to
# call `pwsh ./Invoke-Aggregator.ps1` regardless of cwd.
$modulePath = Join-Path $PSScriptRoot 'Aggregator.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Error "Aggregator.psm1 not found beside Invoke-Aggregator.ps1 (looked at: $modulePath)"
    exit 2
}
Import-Module $modulePath -Force

try {
    $bundle = Invoke-Aggregate -InputDirectory $InputDirectory
} catch {
    Write-Error "Aggregation failed: $($_.Exception.Message)"
    exit 1
}

# Persist the markdown summary.
$bundle.Markdown | Set-Content -Path $OutputPath -Encoding utf8

# Append to GitHub Actions job summary when available.
if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $bundle.Markdown
}

# Echo to stdout so logs (and act output) carry the assertable values.
Write-Host $bundle.Markdown

# Surface parsed file count for diagnostics.
Write-Host ""
Write-Host "Aggregated $($bundle.Results.Count) test results from $($bundle.Files.Count) file(s) in '$InputDirectory'."

# Exit non-zero on the presence of failures so CI can choose to fail; we
# treat aggregation success itself as separate from test pass/fail. The
# task spec asks the workflow to run successfully — so we exit 0 unless
# the user opts into strict mode via env var.
if ($env:AGGREGATOR_FAIL_ON_TEST_FAILURE -eq '1' -and $bundle.Aggregate.Failed -gt 0) {
    exit 1
}
exit 0
