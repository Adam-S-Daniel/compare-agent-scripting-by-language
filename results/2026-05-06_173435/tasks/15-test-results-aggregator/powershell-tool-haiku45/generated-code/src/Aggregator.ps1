<#
.SYNOPSIS
Parses JUnit XML test result files and returns test case objects.

.DESCRIPTION
Reads a JUnit XML file and extracts test information including name, status,
class, and duration. Returns an array of PSCustomObject test results.
#>
function ParseJunitXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    [xml]$xml = Get-Content $FilePath
    $tests = @()

    foreach ($testsuite in $xml.testsuites.testsuite) {
        foreach ($testcase in $testsuite.testcase) {
            $status = "passed"

            if ($testcase.failure) {
                $status = "failed"
            } elseif ($testcase.skipped) {
                $status = "skipped"
            }

            $tests += [PSCustomObject]@{
                Name     = $testcase.name
                Class    = $testcase.classname
                Status   = $status
                Duration = [double]$testcase.time
                Suite    = $testsuite.name
                Message  = if ($testcase.failure) { $testcase.failure.message } elseif ($testcase.skipped) { $testcase.skipped.message } else { $null }
            }
        }
    }

    return $tests
}

<#
.SYNOPSIS
Parses JSON test result files and returns test case objects.

.DESCRIPTION
Reads a JSON file containing test results and extracts test information.
Supports standard JSON test report formats with tests_list arrays.
#>
function ParseJsonResults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    $json = Get-Content $FilePath -Raw | ConvertFrom-Json
    $tests = @()

    foreach ($suite in $json.suites) {
        foreach ($test in $suite.tests_list) {
            $status = $test.state
            if ($status -eq "pending") {
                $status = "skipped"
            }

            $message = $null
            if ($test.err) {
                $message = $test.err.message
            }

            $tests += [PSCustomObject]@{
                Name     = $test.title
                Class    = $suite.title
                Status   = $status
                Duration = [double]$test.duration
                Suite    = $suite.title
                Message  = $message
            }
        }
    }

    return $tests
}

<#
.SYNOPSIS
Aggregates test results from multiple parsed test sources.

.DESCRIPTION
Combines arrays of test results into a single collection. Used to merge
results from different file types or test runs.
#>
function AggregateResults {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ResultArrays
    )

    $aggregated = @()
    foreach ($results in $ResultArrays) {
        $aggregated += $results
    }
    return $aggregated
}

<#
.SYNOPSIS
Calculates summary statistics from test results.

.DESCRIPTION
Takes a collection of test results and computes totals for passed, failed,
skipped tests, and total duration.
#>
function CalculateTotals {
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Results = @()
    )

    $passed = ($Results | Where-Object { $_.Status -eq "passed" }).Count
    $failed = ($Results | Where-Object { $_.Status -eq "failed" }).Count
    $skipped = ($Results | Where-Object { $_.Status -eq "skipped" }).Count
    $total = $Results.Count

    $duration = 0
    if ($Results.Count -gt 0) {
        $duration = ($Results | Measure-Object -Property Duration -Sum).Sum
    }

    return [PSCustomObject]@{
        Total    = $total
        Passed   = $passed
        Failed   = $failed
        Skipped  = $skipped
        Duration = $duration
    }
}

<#
.SYNOPSIS
Identifies flaky tests across multiple test runs.

.DESCRIPTION
Analyzes multiple test runs and identifies tests that have inconsistent results
(passed in some runs, failed in others). Returns array of flaky test objects
with pass/fail counts.
#>
function IdentifyFlakyTests {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ResultArrays
    )

    # Build a hashtable of test results across runs
    $testHistory = @{}

    # Handle both: array of arrays OR multiple parameters
    for ($i = 0; $i -lt $ResultArrays.Count; $i++) {
        $resultSet = $ResultArrays[$i]

        # If it's a single test object, wrap it in array
        if ($resultSet -and -not ($resultSet -is [array])) {
            $resultSet = @($resultSet)
        }

        foreach ($test in $resultSet) {
            if ($test) {
                $key = "$($test.Class)::$($test.Name)"

                if (-not $testHistory.ContainsKey($key)) {
                    $testHistory[$key] = @{
                        Name      = $test.Name
                        Class     = $test.Class
                        Statuses  = @()
                    }
                }

                $testHistory[$key].Statuses += $test.Status
            }
        }
    }

    # Find tests with mixed results
    $flaky = @()
    foreach ($key in $testHistory.Keys) {
        $statuses = $testHistory[$key].Statuses
        $passed = ($statuses | Where-Object { $_ -eq "passed" }).Count
        $failed = ($statuses | Where-Object { $_ -eq "failed" }).Count
        $skipped = ($statuses | Where-Object { $_ -eq "skipped" }).Count

        # A test is flaky if it has both pass and fail results across runs
        if ($passed -gt 0 -and $failed -gt 0) {
            $flaky += [PSCustomObject]@{
                Name      = $testHistory[$key].Name
                Class     = $testHistory[$key].Class
                PassCount = $passed
                FailCount = $failed
                Runs      = $statuses.Count
            }
        }
    }

    return $flaky
}

<#
.SYNOPSIS
Generates a markdown summary of test results.

.DESCRIPTION
Creates a formatted markdown report including totals, status emoji,
and flaky tests section if present.
#>
function GenerateMarkdownSummary {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Totals,

        [Parameter(Mandatory = $false)]
        [object[]]$FlakyTests = @(),

        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    $emoji = if ($Totals.Failed -eq 0) { "✅" } else { "❌" }
    $passRate = if ($Totals.Total -eq 0) { "N/A" } else { [math]::Round(($Totals.Passed / $Totals.Total) * 100, 2) }

    $markdown = @"
## $Title $emoji

**Summary:**
- Total: $($Totals.Total)
- Passed: $($Totals.Passed)
- Failed: $($Totals.Failed)
- Skipped: $($Totals.Skipped)
- Pass Rate: $passRate%
- Duration: $([math]::Round($Totals.Duration, 2))s

"@

    if ($FlakyTests -and $FlakyTests.Count -gt 0) {
        $markdown += "### 🔀 Flaky Tests`n`n"
        $markdown += "| Test | Class | Passed | Failed | Runs |`n"
        $markdown += "|------|-------|--------|--------|------|`n"

        foreach ($test in $FlakyTests) {
            $markdown += "| $($test.Name) | $($test.Class) | $($test.PassCount) | $($test.FailCount) | $($test.Runs) |`n"
        }
    }

    return $markdown
}

<#
.SYNOPSIS
Main entry point for test aggregation.

.DESCRIPTION
Processes test result files, aggregates them, calculates totals,
identifies flaky tests, and generates a markdown summary report.
#>
function Invoke-TestAggregation {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FilePaths,

        [Parameter(Mandatory = $false)]
        [string]$Title = "Test Results Summary",

        [Parameter(Mandatory = $false)]
        [string]$OutputFile = $null
    )

    $allResults = @()

    # Parse all files
    foreach ($file in $FilePaths) {
        Write-Verbose "Processing: $file"

        if ($file -match "\.xml$") {
            $allResults += ParseJunitXml $file
        } elseif ($file -match "\.json$") {
            $allResults += ParseJsonResults $file
        } else {
            Write-Warning "Unknown file format: $file"
        }
    }

    # Calculate aggregates
    $aggregated = AggregateResults $allResults
    $totals = CalculateTotals $aggregated
    $flaky = IdentifyFlakyTests $allResults

    # Generate report
    $summary = GenerateMarkdownSummary $totals $flaky $Title

    # Output results
    if ($OutputFile) {
        $summary | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Output "Report written to: $OutputFile"
    } else {
        Write-Output $summary
    }

    return @{
        Summary = $summary
        Totals  = $totals
        Flaky   = $flaky
    }
}
