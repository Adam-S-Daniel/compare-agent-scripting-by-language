# TestResultsAggregator.psm1
# Module for parsing test results (JUnit XML, JSON), aggregating across matrix builds,
# detecting flaky tests, and generating markdown summaries.
#
# Approach:
# - Each parser normalizes results to a common hashtable format with keys:
#   Source, TotalTests, Passed, Failed, Skipped, Duration, Tests
# - Tests is an array of hashtables: Name, Suite, Status, Duration, Error
# - Merge-TestResults sums up totals and collects all runs
# - Find-FlakyTests groups test executions by name and checks for mixed pass/fail
# - ConvertTo-MarkdownSummary formats everything into GitHub-compatible markdown

function ConvertFrom-JUnitXml {
    <#
    .SYNOPSIS
        Parses a JUnit XML file and returns normalized test results.
    .DESCRIPTION
        Reads a JUnit XML file (testsuites/testsuite/testcase format),
        extracts test case details, and returns a normalized hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the file exists
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File does not exist: $Path"
    }

    # Attempt to parse the XML
    try {
        [xml]$xml = Get-Content -LiteralPath $Path -Raw
    }
    catch {
        throw "Failed to parse XML file '$Path': $($_.Exception.Message)"
    }

    # Navigate the JUnit XML structure: <testsuites> -> <testsuite> -> <testcase>
    $testSuites = $xml.testsuites
    if (-not $testSuites) {
        throw "Failed to parse JUnit XML: missing <testsuites> root element in '$Path'"
    }

    $tests = [System.Collections.ArrayList]::new()
    $totalPassed = 0
    $totalFailed = 0
    $totalSkipped = 0

    foreach ($suite in $testSuites.testsuite) {
        foreach ($tc in $suite.testcase) {
            # Determine test status from child elements
            $status = 'passed'
            $errorMsg = $null

            if ($tc.failure) {
                $status = 'failed'
                $errorMsg = $tc.failure.message
            }
            elseif ($tc.error) {
                $status = 'failed'
                $errorMsg = $tc.error.message
            }
            elseif ($tc.skipped) {
                $status = 'skipped'
                $errorMsg = $tc.skipped.message
            }

            # Parse duration, defaulting to 0 if missing
            $duration = 0.0
            if ($tc.time) {
                $duration = [double]$tc.time
            }

            $null = $tests.Add(@{
                Name     = $tc.name
                Suite    = if ($tc.classname) { $tc.classname } else { $suite.name }
                Status   = $status
                Duration = $duration
                Error    = $errorMsg
            })

            switch ($status) {
                'passed'  { $totalPassed++ }
                'failed'  { $totalFailed++ }
                'skipped' { $totalSkipped++ }
            }
        }
    }

    # Parse top-level duration
    $totalDuration = 0.0
    if ($testSuites.time) {
        $totalDuration = [double]$testSuites.time
    }

    return @{
        Source     = $Path
        TotalTests = $tests.Count
        Passed     = $totalPassed
        Failed     = $totalFailed
        Skipped    = $totalSkipped
        Duration   = $totalDuration
        Tests      = $tests.ToArray()
    }
}

function ConvertFrom-TestResultJson {
    <#
    .SYNOPSIS
        Parses a JSON test result file and returns normalized test results.
    .DESCRIPTION
        Reads a JSON file with structure: { testSuite, environment, duration, tests: [...] }
        and normalizes it to the common result format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the file exists
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File does not exist: $Path"
    }

    # Attempt to parse the JSON
    try {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse JSON file '$Path': $($_.Exception.Message)"
    }

    $tests = [System.Collections.ArrayList]::new()
    $totalPassed = 0
    $totalFailed = 0
    $totalSkipped = 0

    foreach ($t in $json.tests) {
        $errorMsg = $null
        if ($t.error) {
            $errorMsg = $t.error
        }

        $null = $tests.Add(@{
            Name     = $t.name
            Suite    = $t.suite
            Status   = $t.status
            Duration = [double]$t.duration
            Error    = $errorMsg
        })

        switch ($t.status) {
            'passed'  { $totalPassed++ }
            'failed'  { $totalFailed++ }
            'skipped' { $totalSkipped++ }
        }
    }

    return @{
        Source     = $Path
        TotalTests = $tests.Count
        Passed     = $totalPassed
        Failed     = $totalFailed
        Skipped    = $totalSkipped
        Duration   = [double]$json.duration
        Tests      = $tests.ToArray()
    }
}

function Merge-TestResults {
    <#
    .SYNOPSIS
        Aggregates test results from multiple runs and computes totals.
    .DESCRIPTION
        Takes an array of normalized result hashtables (from parsers) and
        produces a single aggregated result with summed totals and per-run breakdown.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results
    )

    $totalTests = 0
    $totalPassed = 0
    $totalFailed = 0
    $totalSkipped = 0
    $totalDuration = 0.0
    $uniqueTestNames = [System.Collections.Generic.HashSet[string]]::new()
    $runs = [System.Collections.ArrayList]::new()

    foreach ($r in $Results) {
        $totalTests    += $r.TotalTests
        $totalPassed   += $r.Passed
        $totalFailed   += $r.Failed
        $totalSkipped  += $r.Skipped
        $totalDuration += $r.Duration

        # Collect unique test names
        foreach ($t in $r.Tests) {
            $null = $uniqueTestNames.Add($t.Name)
        }

        # Store per-run summary
        $null = $runs.Add(@{
            Source     = $r.Source
            TotalTests = $r.TotalTests
            Passed     = $r.Passed
            Failed     = $r.Failed
            Skipped    = $r.Skipped
            Duration   = $r.Duration
        })
    }

    return @{
        TotalTests    = $totalTests
        Passed        = $totalPassed
        Failed        = $totalFailed
        Skipped       = $totalSkipped
        TotalDuration = $totalDuration
        RunCount      = $Results.Count
        UniqueTests   = @($uniqueTestNames)
        Runs          = $runs.ToArray()
    }
}

function Find-FlakyTests {
    <#
    .SYNOPSIS
        Identifies flaky tests - those that passed in some runs but failed in others.
    .DESCRIPTION
        Groups all test executions by name across runs. A test is flaky if it has
        both 'passed' and 'failed' statuses across different runs. Skipped-only tests
        and consistently passing/failing tests are not considered flaky.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results
    )

    # Group all test executions by test name
    $testMap = @{}
    foreach ($run in $Results) {
        foreach ($t in $run.Tests) {
            if (-not $testMap.ContainsKey($t.Name)) {
                $testMap[$t.Name] = @{
                    Name      = $t.Name
                    Suite     = $t.Suite
                    PassCount = 0
                    FailCount = 0
                    SkipCount = 0
                    TotalRuns = 0
                }
            }
            $testMap[$t.Name].TotalRuns++
            switch ($t.Status) {
                'passed'  { $testMap[$t.Name].PassCount++ }
                'failed'  { $testMap[$t.Name].FailCount++ }
                'skipped' { $testMap[$t.Name].SkipCount++ }
            }
        }
    }

    # A test is flaky if it has BOTH passes and failures
    $flaky = [System.Collections.ArrayList]::new()
    foreach ($entry in $testMap.Values) {
        if ($entry.PassCount -gt 0 -and $entry.FailCount -gt 0) {
            $null = $flaky.Add($entry)
        }
    }

    # Use comma operator to prevent PowerShell from unrolling the array
    return , @($flaky)
}

function ConvertTo-MarkdownSummary {
    <#
    .SYNOPSIS
        Generates a markdown summary of aggregated test results.
    .DESCRIPTION
        Produces GitHub Actions-compatible markdown with:
        - Overall status header with pass/fail indicator
        - Totals (passed, failed, skipped, duration)
        - Per-run breakdown table
        - Flaky tests warning section (if any)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$AggregatedResults,

        [Parameter()]
        [array]$FlakyTests = @()
    )

    $a = $AggregatedResults
    $sb = [System.Text.StringBuilder]::new()

    # Header with overall status
    if ($a.Failed -eq 0) {
        $null = $sb.AppendLine("# Test Results - All Passed")
    }
    else {
        $null = $sb.AppendLine("# Test Results - $($a.Failed) Failure(s)")
    }
    $null = $sb.AppendLine()

    # Summary line
    $null = $sb.AppendLine("**$($a.RunCount) run(s)** across **$($a.UniqueTests.Count) unique test(s)** | Total duration: **$([math]::Round($a.TotalDuration, 3))s**")
    $null = $sb.AppendLine()

    # Totals
    $null = $sb.AppendLine("| Metric | Count |")
    $null = $sb.AppendLine("|--------|-------|")
    $null = $sb.AppendLine("| Passed | $($a.Passed) passed |")
    $null = $sb.AppendLine("| Failed | $($a.Failed) failed |")
    $null = $sb.AppendLine("| Skipped | $($a.Skipped) skipped |")
    $null = $sb.AppendLine("| **Total** | **$($a.TotalTests)** |")
    $null = $sb.AppendLine()

    # Per-run breakdown table
    $null = $sb.AppendLine("## Per-Run Breakdown")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("| Run | Passed | Failed | Skipped | Total | Duration |")
    $null = $sb.AppendLine("|-----|--------|--------|---------|-------|----------|")

    foreach ($run in $a.Runs) {
        $source = Split-Path $run.Source -Leaf
        $duration = [math]::Round($run.Duration, 3)
        $null = $sb.AppendLine("| $source | $($run.Passed) | $($run.Failed) | $($run.Skipped) | $($run.TotalTests) | ${duration}s |")
    }
    $null = $sb.AppendLine()

    # Flaky tests section - only shown when flaky tests exist
    if ($FlakyTests.Count -gt 0) {
        $null = $sb.AppendLine("## Flaky Tests")
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("The following tests showed inconsistent results across runs:")
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("| Test | Suite | Passed | Failed | Total Runs |")
        $null = $sb.AppendLine("|------|-------|--------|--------|------------|")

        foreach ($ft in $FlakyTests) {
            $null = $sb.AppendLine("| $($ft.Name) | $($ft.Suite) | $($ft.PassCount) | $($ft.FailCount) | $($ft.TotalRuns) |")
        }
        $null = $sb.AppendLine()
    }

    return $sb.ToString()
}

Export-ModuleMember -Function ConvertFrom-JUnitXml, ConvertFrom-TestResultJson, Merge-TestResults, Find-FlakyTests, ConvertTo-MarkdownSummary
