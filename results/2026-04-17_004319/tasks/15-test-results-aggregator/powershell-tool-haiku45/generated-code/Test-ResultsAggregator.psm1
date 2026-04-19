# Test Results Aggregator Module
# Parses multiple test result formats, aggregates results, identifies flaky tests, and generates reports

function Parse-JUnitXml {
    <#
    .SYNOPSIS
    Parses a JUnit XML test results file and extracts test metrics.

    .PARAMETER Path
    Path to the JUnit XML file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    try {
        [xml]$xml = Get-Content -Path $Path -Raw
        $testsuite = $xml.testsuites.testsuite | Select-Object -First 1

        if (-not $testsuite) {
            throw "No testsuite element found in XML"
        }

        $passed = 0
        $failed = 0
        $skipped = 0
        $testCases = @()

        foreach ($testcase in $testsuite.testcase) {
            $tc = @{
                name = $testcase.name
                state = "passed"
                duration = [double]$testcase.time
            }

            if ($testcase.failure) {
                $tc.state = "failed"
                $failed++
            } elseif ($testcase.skipped) {
                $tc.state = "skipped"
                $skipped++
            } else {
                $passed++
            }

            $testCases += $tc
        }

        return @{
            passed = $passed
            failed = $failed
            skipped = $skipped
            totalDuration = [double]$testsuite.time
            testCases = $testCases
            source = $Path
            format = "junit-xml"
        }
    }
    catch {
        throw "Error parsing JUnit XML file: $_"
    }
}

function Parse-JsonTestResults {
    <#
    .SYNOPSIS
    Parses a JSON test results file and extracts test metrics.

    .PARAMETER Path
    Path to the JSON file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    try {
        $json = Get-Content -Path $Path -Raw | ConvertFrom-Json

        $passed = if ($json.passes) { $json.passes } elseif ($json.passed) { $json.passed } else { 0 }
        $failed = if ($json.failures) { $json.failures } elseif ($json.failed) { $json.failed } else { 0 }
        $skipped = if ($json.skipped) { $json.skipped } else { 0 }
        $durationMs = if ($json.duration) { $json.duration } else { 0 }
        $totalDuration = $durationMs / 1000

        $testCases = @()
        if ($json.testCases) {
            foreach ($tc in $json.testCases) {
                $tcDuration = if ($tc.duration) { $tc.duration } else { 0 }
                $testCases += @{
                    name = $tc.name
                    state = $tc.state
                    duration = $tcDuration / 1000
                }
            }
        }

        return @{
            passed = $passed
            failed = $failed
            skipped = $skipped
            totalDuration = $totalDuration
            testCases = $testCases
            source = $Path
            format = "json"
        }
    }
    catch {
        throw "Error parsing JSON file: $_"
    }
}

function Aggregate-TestResults {
    <#
    .SYNOPSIS
    Aggregates test results from multiple parsed result objects.

    .PARAMETER Results
    Array of result objects from Parse-JUnitXml or Parse-JsonTestResults.
    #>
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    $totalPassed = 0
    $totalFailed = 0
    $totalSkipped = 0
    $totalDuration = 0.0
    $allTestCases = @()

    foreach ($result in $Results) {
        $totalPassed += $result.passed
        $totalFailed += $result.failed
        $totalSkipped += $result.skipped
        $totalDuration += $result.totalDuration
        $allTestCases += $result.testCases
    }

    return @{
        totalPassed = $totalPassed
        totalFailed = $totalFailed
        totalSkipped = $totalSkipped
        totalDuration = $totalDuration
        testCount = $Results.Count
        allTestCases = $allTestCases
    }
}

function Identify-FlakyTests {
    <#
    .SYNOPSIS
    Identifies tests that have inconsistent results across multiple runs.
    A flaky test is one that passed in some runs and failed in others.

    .PARAMETER Runs
    Array of result objects representing different test runs.
    #>
    param(
        [Parameter(Mandatory)]
        [object[]]$Runs
    )

    $testStates = @{}

    # Collect states across all runs
    foreach ($run in $Runs) {
        foreach ($testCase in $run.testCases) {
            if (-not $testStates[$testCase.name]) {
                $testStates[$testCase.name] = @()
            }
            $testStates[$testCase.name] += $testCase.state
        }
    }

    # Find tests with inconsistent states
    $flaky = @()
    foreach ($testName in $testStates.Keys) {
        $states = $testStates[$testName]
        $uniqueStates = @($states | Select-Object -Unique)

        # Flaky if it has multiple different states (e.g., both "passed" and "failed")
        if ($uniqueStates.Count -gt 1) {
            $flaky += $testName
        }
    }

    return $flaky | Sort-Object
}

function Generate-MarkdownSummary {
    <#
    .SYNOPSIS
    Generates a markdown summary of test results suitable for GitHub Actions job summary.

    .PARAMETER Summary
    Hashtable containing aggregated test metrics.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Summary
    )

    $md = @"
# Test Results Summary

## Overall Metrics
- **Total Tests**: $($Summary.totalTests)
- **Passed**: ✅ $($Summary.totalPassed)
- **Failed**: ❌ $($Summary.totalFailed)
- **Skipped**: ⏭️ $($Summary.totalSkipped)
- **Duration**: $([math]::Round($Summary.totalDuration, 2))s
- **Test Runs**: $($Summary.runCount)

"@

    if ($Summary.flakyTests -and $Summary.flakyTests.Count -gt 0) {
        $md += @"
## ⚠️ Flaky Tests
The following tests have inconsistent results across runs:
"@
        foreach ($test in $Summary.flakyTests) {
            $md += "`n- $test"
        }
        $md += "`n`n"
    }

    $passRate = if ($Summary.totalTests -gt 0) {
        [math]::Round(($Summary.totalPassed / $Summary.totalTests) * 100, 1)
    } else {
        0
    }

    $md += @"
## Pass Rate
**$passRate%** ($($Summary.totalPassed)/$($Summary.totalTests))
"@

    return $md
}

function Invoke-ResultsAggregation {
    <#
    .SYNOPSIS
    Main orchestration function that aggregates test results from multiple files
    and generates a markdown summary.

    .PARAMETER TestResultsPath
    Directory containing test result files to aggregate.

    .PARAMETER OutputPath
    Path where to write the markdown summary.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TestResultsPath,
        [string]$OutputPath
    )

    if (-not (Test-Path $TestResultsPath)) {
        throw "Test results directory not found: $TestResultsPath"
    }

    # Find and parse all result files
    $xmlFiles = Get-ChildItem -Path $TestResultsPath -Filter "*.xml" -ErrorAction SilentlyContinue
    $jsonFiles = Get-ChildItem -Path $TestResultsPath -Filter "*.json" -ErrorAction SilentlyContinue

    if ($xmlFiles.Count -eq 0 -and $jsonFiles.Count -eq 0) {
        throw "No test result files found in $TestResultsPath"
    }

    $allResults = @()

    foreach ($xmlFile in $xmlFiles) {
        try {
            $result = Parse-JUnitXml -Path $xmlFile.FullName
            $allResults += $result
        }
        catch {
            Write-Warning "Failed to parse XML file $($xmlFile.Name): $_"
        }
    }

    foreach ($jsonFile in $jsonFiles) {
        try {
            $result = Parse-JsonTestResults -Path $jsonFile.FullName
            $allResults += $result
        }
        catch {
            Write-Warning "Failed to parse JSON file $($jsonFile.Name): $_"
        }
    }

    if ($allResults.Count -eq 0) {
        throw "No test results could be parsed"
    }

    # Aggregate results
    $aggregated = Aggregate-TestResults -Results $allResults

    # Identify flaky tests
    $flakyTests = Identify-FlakyTests -Runs $allResults

    # Build summary
    $summary = @{
        totalTests = $aggregated.totalPassed + $aggregated.totalFailed + $aggregated.totalSkipped
        totalPassed = $aggregated.totalPassed
        totalFailed = $aggregated.totalFailed
        totalSkipped = $aggregated.totalSkipped
        totalDuration = $aggregated.totalDuration
        runCount = $allResults.Count
        flakyTests = $flakyTests
    }

    # Generate markdown
    $markdown = Generate-MarkdownSummary -Summary $summary

    # Output markdown
    if ($OutputPath) {
        Set-Content -Path $OutputPath -Value $markdown
        Write-Host "Summary written to $OutputPath"
    } else {
        Write-Host $markdown
    }

    return $summary
}

Export-ModuleMember -Function @(
    'Parse-JUnitXml'
    'Parse-JsonTestResults'
    'Aggregate-TestResults'
    'Identify-FlakyTests'
    'Generate-MarkdownSummary'
    'Invoke-ResultsAggregation'
)
