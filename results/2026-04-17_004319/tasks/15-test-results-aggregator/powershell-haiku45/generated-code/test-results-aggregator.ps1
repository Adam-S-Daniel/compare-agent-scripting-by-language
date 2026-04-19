<#
Test Results Aggregator
Parses and aggregates test results from JUnit XML and JSON formats,
identifies flaky tests, and generates GitHub Actions job summary.
#>

function Get-JunitXmlTestResults {
    [CmdletBinding()]
    param(
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return @{Tests = @(); TotalTime = 0; Summary = @{Passed = 0; Failed = 0; Skipped = 0}}
    }

    [xml]$xml = Get-Content $FilePath
    $results = @{Tests = @(); TotalTime = 0; Summary = @{Passed = 0; Failed = 0; Skipped = 0}}

    foreach ($testsuite in $xml.testsuites.testsuite) {
        $results.TotalTime += [double]$testsuite.time
        foreach ($testcase in $testsuite.testcase) {
            $test = @{
                Name = $testcase.name
                Class = $testcase.classname
                Duration = [double]$testcase.time
                Status = "passed"
            }

            # Check for failure/skipped elements in ChildNodes
            $hasFailure = $testcase.ChildNodes | Where-Object { $_.Name -eq "failure" }
            $hasSkipped = $testcase.ChildNodes | Where-Object { $_.Name -eq "skipped" }

            if ($hasFailure) {
                $test.Status = "failed"
                $test.Message = $hasFailure.message
                $results.Summary.Failed++
            }
            elseif ($hasSkipped) {
                $test.Status = "skipped"
                $results.Summary.Skipped++
            }
            else {
                $results.Summary.Passed++
            }

            $results.Tests += $test
        }
    }

    return $results
}

function Get-JsonTestResults {
    [CmdletBinding()]
    param(
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return @{Tests = @(); TotalTime = 0; Summary = @{Passed = 0; Failed = 0; Skipped = 0}}
    }

    $json = Get-Content $FilePath | ConvertFrom-Json
    $results = @{Tests = @(); TotalTime = $json.duration; Summary = @{Passed = 0; Failed = 0; Skipped = 0}}

    foreach ($test in $json.tests) {
        $testObj = @{
            Name = $test.name
            Duration = $test.duration
            Status = $test.status
        }

        if ($test.status -eq "passed") {
            $results.Summary.Passed++
        }
        elseif ($test.status -eq "failed") {
            $results.Summary.Failed++
            $testObj.Message = $test.message
        }
        elseif ($test.status -eq "skipped") {
            $results.Summary.Skipped++
        }

        $results.Tests += $testObj
    }

    return $results
}

function Aggregate-TestResults {
    [CmdletBinding()]
    param(
        [object[]]$TestResults = @()
    )

    $aggregated = @{
        Passed = 0
        Failed = 0
        Skipped = 0
        Duration = 0
        AllTests = @()
    }

    foreach ($result in $TestResults) {
        if ($result.Summary) {
            $aggregated.Passed += $result.Summary.Passed
            $aggregated.Failed += $result.Summary.Failed
            $aggregated.Skipped += $result.Summary.Skipped
        }
        $aggregated.Duration += $result.TotalTime
        $aggregated.AllTests += @($result.Tests)
    }

    return $aggregated
}

function ConvertTo-MarkdownSummary {
    [CmdletBinding()]
    param(
        [object]$AggregatedResults
    )

    $markdown = @"
# Test Results Summary

## Totals

| Metric | Count |
|--------|-------|
| **Passed** | $($AggregatedResults.Passed) |
| **Failed** | $($AggregatedResults.Failed) |
| **Skipped** | $($AggregatedResults.Skipped) |
| **Total Duration** | $([math]::Round($AggregatedResults.Duration, 2))s |

"@

    return $markdown
}

function Find-FlakyTests {
    [CmdletBinding()]
    param(
        [object[]]$MultipleRuns
    )

    $testStatuses = @{}

    foreach ($run in $MultipleRuns) {
        foreach ($test in $run.Tests) {
            if (-not $testStatuses[$test.Name]) {
                $testStatuses[$test.Name] = @()
            }
            $testStatuses[$test.Name] += $test.Status
        }
    }

    $flaky = @()
    foreach ($testName in $testStatuses.Keys) {
        $statuses = $testStatuses[$testName]
        if (($statuses -contains "passed") -and ($statuses -contains "failed")) {
            $flaky += , @{Name = $testName; Statuses = $statuses}
        }
    }

    return , $flaky
}

function Invoke-TestResultsAggregator {
    [CmdletBinding()]
    param(
        [string[]]$TestResultFiles = @(),
        [string]$OutputFormat = "markdown"
    )

    # Placeholder implementation
    Write-Host "Test Results Aggregator initialized"
}
