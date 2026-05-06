<#
.SYNOPSIS
    Aggregates test results from multiple XML and JSON files across matrix builds.
.DESCRIPTION
    Parses JUnit XML and JSON test result files, aggregates results, identifies flaky tests,
    and generates a markdown summary suitable for GitHub Actions job summary.
#>

function Invoke-TestAggregation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$InputPaths,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    # Validate input files exist
    foreach ($path in $InputPaths) {
        if (-not (Test-Path $path)) {
            throw "File not found: $path"
        }
    }

    $aggregatedResults = @{
        TotalTests   = 0
        TotalPassed  = 0
        TotalFailed  = 0
        TotalSkipped = 0
        TotalDuration = 0
        AllTestCases = @()  # Track all test cases across runs
        FlakyTests   = @()  # Tests that pass in some runs but fail in others
    }

    # Parse each input file
    foreach ($inputPath in $InputPaths) {
        $fileExt = [System.IO.Path]::GetExtension($inputPath).ToLower()

        if ($fileExt -eq '.xml') {
            $fileResults = Parse-JunitXml $inputPath
        } elseif ($fileExt -eq '.json') {
            $fileResults = Parse-JsonTestResults $inputPath
        } else {
            Write-Warning "Skipping unsupported file format: $inputPath"
            continue
        }

        # Aggregate counts
        $aggregatedResults.TotalTests += $fileResults.Tests
        $aggregatedResults.TotalPassed += $fileResults.Passed
        $aggregatedResults.TotalFailed += $fileResults.Failed
        $aggregatedResults.TotalSkipped += $fileResults.Skipped
        $aggregatedResults.TotalDuration += $fileResults.Duration

        # Track all test cases for flaky test detection
        if ($fileResults.TestCases) {
            $aggregatedResults.AllTestCases += @($fileResults.TestCases)
        }
    }

    # Identify flaky tests (tests that appear with different results across runs)
    $aggregatedResults.FlakyTests = Identify-FlakyTests $aggregatedResults.AllTestCases

    # Export to file if requested
    if ($OutputPath) {
        $markdown = ConvertTo-TestResultsMarkdown -AggregationResult $aggregatedResults
        $markdown | Out-File -FilePath $OutputPath -Encoding UTF8
    }

    return $aggregatedResults
}

function Parse-JunitXml {
    [CmdletBinding()]
    param([string]$FilePath)

    $xml = [xml](Get-Content $FilePath)

    $results = @{
        Tests = 0
        Passed = 0
        Failed = 0
        Skipped = 0
        Duration = 0
        TestCases = @()
    }

    # Process all testsuites
    foreach ($suite in $xml.testsuites.testsuite) {
        $results.Tests += [int]$suite.tests
        $results.Failed += [int]$suite.failures
        $results.Skipped += [int]$suite.skipped
        $results.Duration += [double]$suite.time

        # Calculate passed = total - failed - skipped
        $suitePassed = [int]$suite.tests - [int]$suite.failures - [int]$suite.skipped
        $results.Passed += $suitePassed

        # Track individual test cases
        foreach ($testcase in $suite.testcase) {
            $testStatus = 'passed'
            if ($testcase.failure) {
                $testStatus = 'failed'
            } elseif ($testcase.skipped) {
                $testStatus = 'skipped'
            }

            $results.TestCases += @{
                Name = $testcase.name
                Status = $testStatus
                Duration = [double]$testcase.time
            }
        }
    }

    return $results
}

function Parse-JsonTestResults {
    [CmdletBinding()]
    param([string]$FilePath)

    $json = Get-Content $FilePath -Raw | ConvertFrom-Json

    $results = @{
        Tests = 0
        Passed = 0
        Failed = 0
        Skipped = 0
        Duration = 0
        TestCases = @()
    }

    # Process all testsuites
    foreach ($suite in $json.testsuites) {
        $results.Tests += $suite.tests
        $results.Passed += $suite.passed
        $results.Failed += $suite.failed
        $results.Skipped += $suite.skipped
        $results.Duration += $suite.duration

        # Track individual test cases
        foreach ($testcase in $suite.testcases) {
            $results.TestCases += @{
                Name = $testcase.name
                Status = $testcase.status
                Duration = $testcase.duration
            }
        }
    }

    return $results
}

function Identify-FlakyTests {
    [CmdletBinding()]
    param([array]$AllTestCases)

    $testStatusMap = @{}

    # Group test cases by name and track their statuses
    foreach ($testCase in $AllTestCases) {
        $testName = $testCase.Name

        if (-not $testStatusMap.ContainsKey($testName)) {
            $testStatusMap[$testName] = @()
        }

        $testStatusMap[$testName] += $testCase.Status
    }

    # Find tests with mixed results (flaky)
    $flakyTests = @()
    foreach ($testName in $testStatusMap.Keys) {
        $statuses = $testStatusMap[$testName]

        # A test is flaky if it has more than one status value
        # and includes 'passed' and 'failed' (not just skipped)
        $uniqueStatuses = $statuses | Select-Object -Unique

        if (($uniqueStatuses.Count -gt 1) -and
            ($uniqueStatuses -contains 'passed') -and
            ($uniqueStatuses -contains 'failed')) {
            $flakyTests += $testName
        }
    }

    return $flakyTests | Select-Object -Unique
}

function ConvertTo-TestResultsMarkdown {
    [CmdletBinding()]
    param([hashtable]$AggregationResult)

    # Calculate pass rate
    $passRate = if ($AggregationResult.TotalTests -gt 0) {
        [math]::Round(($AggregationResult.TotalPassed / $AggregationResult.TotalTests) * 100, 2)
    } else {
        0
    }

    # Build markdown
    $markdown = @"
# Test Results Summary

## Statistics
- **Total Tests**: $($AggregationResult.TotalTests)
- **Passed**: $($AggregationResult.TotalPassed) ✅
- **Failed**: $($AggregationResult.TotalFailed) ❌
- **Skipped**: $($AggregationResult.TotalSkipped) ⏭️
- **Pass Rate**: $passRate%
- **Total Duration**: $([math]::Round($AggregationResult.TotalDuration, 2))s

"@

    # Add flaky tests section if any exist
    if ($AggregationResult.FlakyTests -and $AggregationResult.FlakyTests.Count -gt 0) {
        $markdown += "## Flaky Tests ⚠️`n`n"
        foreach ($flakyTest in $AggregationResult.FlakyTests) {
            $markdown += "- $flakyTest`n"
        }
        $markdown += "`n"
    }

    return $markdown
}

# Export function for GitHub Actions
function Export-TestResultsToGitHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$InputPaths
    )

    # Aggregate results
    $results = Invoke-TestAggregation -InputPaths $InputPaths

    # Generate markdown
    $markdown = ConvertTo-TestResultsMarkdown -AggregationResult $results

    # Export to GitHub Actions job summary if env variable is available
    if ($env:GITHUB_STEP_SUMMARY) {
        $markdown | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding UTF8 -Append
    }

    return $results
}
