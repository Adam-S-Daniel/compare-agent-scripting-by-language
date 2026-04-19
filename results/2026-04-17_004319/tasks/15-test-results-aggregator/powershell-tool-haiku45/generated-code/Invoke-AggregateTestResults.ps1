#!/usr/bin/env pwsh
<#
.SYNOPSIS
Aggregates test results from multiple formats and generates a markdown summary.

.DESCRIPTION
This script parses JUnit XML and JSON test result files, aggregates the results
across multiple runs, computes totals, identifies flaky tests, and generates
a markdown summary suitable for GitHub Actions job summary.

.PARAMETER TestResultsPath
The directory containing test result files (*.xml and *.json).
Defaults to './test-results' if not specified.

.PARAMETER OutputPath
Optional path where to write the markdown summary file.
If not specified, output is printed to stdout.

.PARAMETER GithubSummary
If specified, also write the summary to $GITHUB_STEP_SUMMARY environment variable
for GitHub Actions integration.

.EXAMPLE
./Invoke-AggregateTestResults.ps1 -TestResultsPath "./test-results"

.EXAMPLE
./Invoke-AggregateTestResults.ps1 -TestResultsPath "./test-results" -OutputPath "./summary.md" -GithubSummary
#>

param(
    [string]$TestResultsPath = "./test-results",
    [string]$OutputPath,
    [switch]$GithubSummary
)

# Import the aggregator module
$modulePath = Join-Path $PSScriptRoot "Test-ResultsAggregator.psm1"
if (-not (Test-Path $modulePath)) {
    Write-Error "Module not found: $modulePath"
    exit 1
}

try {
    Import-Module $modulePath -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to import module: $_"
    exit 1
}

try {
    # Main aggregation logic
    Write-Host "Aggregating test results from: $TestResultsPath"

    if (-not (Test-Path $TestResultsPath)) {
        Write-Error "Test results directory not found: $TestResultsPath"
        exit 1
    }

    # Find all result files
    $xmlFiles = @(Get-ChildItem -Path $TestResultsPath -Filter "*.xml" -ErrorAction SilentlyContinue)
    $jsonFiles = @(Get-ChildItem -Path $TestResultsPath -Filter "*.json" -ErrorAction SilentlyContinue)

    if ($xmlFiles.Count -eq 0 -and $jsonFiles.Count -eq 0) {
        Write-Error "No test result files found in $TestResultsPath"
        exit 1
    }

    Write-Host "Found $($xmlFiles.Count) XML files and $($jsonFiles.Count) JSON files"

    # Parse all files
    $allResults = @()
    $parseErrors = @()

    foreach ($xmlFile in $xmlFiles) {
        try {
            Write-Host "  Parsing: $($xmlFile.Name)"
            $result = Parse-JUnitXml -Path $xmlFile.FullName
            $allResults += $result
        }
        catch {
            $parseErrors += "XML: $($xmlFile.Name) - $_"
            Write-Warning "Failed to parse XML file $($xmlFile.Name): $_"
        }
    }

    foreach ($jsonFile in $jsonFiles) {
        try {
            Write-Host "  Parsing: $($jsonFile.Name)"
            $result = Parse-JsonTestResults -Path $jsonFile.FullName
            $allResults += $result
        }
        catch {
            $parseErrors += "JSON: $($jsonFile.Name) - $_"
            Write-Warning "Failed to parse JSON file $($jsonFile.Name): $_"
        }
    }

    if ($allResults.Count -eq 0) {
        Write-Error "No test results could be parsed"
        exit 1
    }

    Write-Host "Successfully parsed $($allResults.Count) result files"

    # Aggregate results
    $aggregated = Aggregate-TestResults -Results $allResults
    Write-Host "Total tests: $($aggregated.totalPassed + $aggregated.totalFailed + $aggregated.totalSkipped)"
    Write-Host "  Passed: $($aggregated.totalPassed)"
    Write-Host "  Failed: $($aggregated.totalFailed)"
    Write-Host "  Skipped: $($aggregated.totalSkipped)"
    Write-Host "  Duration: $($aggregated.totalDuration)s"

    # Identify flaky tests
    $flakyTests = Identify-FlakyTests -Runs $allResults
    if ($flakyTests.Count -gt 0) {
        Write-Host "Flaky tests found: $($flakyTests.Count)"
        foreach ($test in $flakyTests) {
            Write-Host "  - $test"
        }
    } else {
        Write-Host "No flaky tests detected"
    }

    # Build summary
    $summary = @{
        totalTests = $aggregated.totalPassed + $aggregated.totalFailed + $aggregated.totalSkipped
        totalPassed = $aggregated.totalPassed
        totalFailed = $aggregated.totalFailed
        totalSkipped = $aggregated.totalSkipped
        totalDuration = $aggregated.totalDuration
        runCount = $allResults.Count
        flakyTests = $flakyTests
        parseErrors = $parseErrors
    }

    # Generate markdown
    $markdown = Generate-MarkdownSummary -Summary $summary

    # Add parse errors section if any
    if ($parseErrors.Count -gt 0) {
        $markdown += "`n## ⚠️ Parse Errors`nThe following files had errors during parsing:`n"
        foreach ($error in $parseErrors) {
            $markdown += "- $error`n"
        }
    }

    # Output markdown
    if ($OutputPath) {
        Set-Content -Path $OutputPath -Value $markdown -Encoding UTF8
        Write-Host "Summary written to: $OutputPath"
    } else {
        Write-Host ""
        Write-Host $markdown
    }

    # Write to GitHub Actions summary if requested
    if ($GithubSummary -and $env:GITHUB_STEP_SUMMARY) {
        Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $markdown -Encoding UTF8
        Write-Host "Summary also written to GitHub Actions job summary"
    }

    # Exit with appropriate code
    if ($aggregated.totalFailed -gt 0) {
        Write-Host ""
        Write-Host "Tests FAILED: $($aggregated.totalFailed) failure(s)" -ForegroundColor Red
        exit 1
    } else {
        Write-Host ""
        Write-Host "All tests PASSED" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
