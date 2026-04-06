# TestResultsAggregator Module
# Parses JUnit XML and JSON test result files, aggregates across matrix builds,
# detects flaky tests, and generates GitHub Actions-style markdown summaries.
#
# TDD approach: tests in TestResultsAggregator.Tests.ps1 were written FIRST,
# then each function below was implemented to make the corresponding tests pass.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# GREEN PHASE 1: Import-JUnitResults
# Parses a JUnit XML file into a standardised result object.
# =============================================================================
function Import-JUnitResults {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the file exists
    if (-not (Test-Path -Path $Path)) {
        throw "File does not exist: $Path"
    }

    # Attempt to load and parse the XML
    try {
        [xml]$xml = Get-Content -Path $Path -Raw
    }
    catch {
        throw "Failed to parse JUnit XML file '$Path': $($_.Exception.Message)"
    }

    # Extract the root <testsuites> element
    $testSuitesNode = $xml.testsuites
    [string]$runName = [string]$testSuitesNode.name
    [double]$totalDuration = [double]$testSuitesNode.time

    # Build a flat list of test case objects from all <testsuite>/<testcase> elements
    [System.Collections.ArrayList]$testCases = [System.Collections.ArrayList]::new()

    foreach ($suite in $testSuitesNode.testsuite) {
        foreach ($tc in $suite.testcase) {
            [string]$status = 'passed'
            [string]$failureMessage = ''

            # Use SelectSingleNode for safe child element access in strict mode
            $failureNode = $tc.SelectSingleNode('failure')
            $skippedNode = $tc.SelectSingleNode('skipped')

            if ($null -ne $failureNode) {
                $status = 'failed'
                $failureMessage = [string]$failureNode.GetAttribute('message')
            }
            elseif ($null -ne $skippedNode) {
                $status = 'skipped'
            }

            [hashtable]$testCase = @{
                Name           = [string]$tc.name
                ClassName      = [string]$tc.classname
                Status         = [string]$status
                Duration       = [double]$tc.time
                FailureMessage = [string]$failureMessage
            }
            [void]$testCases.Add($testCase)
        }
    }

    [hashtable]$result = @{
        RunName       = $runName
        TotalDuration = $totalDuration
        TestCases     = [array]$testCases.ToArray()
    }

    return $result
}

# =============================================================================
# GREEN PHASE 2: Import-JsonTestResults
# Parses a JSON test result file into the same standardised result object.
# =============================================================================
function Import-JsonTestResults {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the file exists
    if (-not (Test-Path -Path $Path)) {
        throw "File does not exist: $Path"
    }

    # Attempt to load and parse the JSON
    try {
        [string]$raw = Get-Content -Path $Path -Raw
        $json = $raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse JSON file '$Path': $($_.Exception.Message)"
    }

    [string]$runName = [string]$json.runName
    [double]$totalDuration = [double]0

    # Build a flat list of test case objects from all suites
    [System.Collections.ArrayList]$testCases = [System.Collections.ArrayList]::new()

    foreach ($suite in $json.suites) {
        foreach ($test in $suite.tests) {
            [string]$failureMessage = ''
            if ($test.status -eq 'failed' -and $null -ne $test.error) {
                $failureMessage = [string]$test.error.message
            }

            [double]$duration = [double]$test.duration
            $totalDuration = $totalDuration + $duration

            [hashtable]$testCase = @{
                Name           = [string]$test.name
                ClassName      = [string]$test.classname
                Status         = [string]$test.status
                Duration       = $duration
                FailureMessage = $failureMessage
            }
            [void]$testCases.Add($testCase)
        }
    }

    [hashtable]$result = @{
        RunName       = $runName
        TotalDuration = $totalDuration
        TestCases     = [array]$testCases.ToArray()
    }

    return $result
}

# =============================================================================
# GREEN PHASE 3: Merge-TestResults
# Aggregates results from multiple runs into totals and per-test detail maps.
# =============================================================================
function Merge-TestResults {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]]$Results
    )

    if ($Results.Count -eq 0) {
        throw 'Results must contain at least one test run.'
    }

    [int]$totalPassed = 0
    [int]$totalFailed = 0
    [int]$totalSkipped = 0
    [double]$totalDuration = [double]0
    [int]$runCount = $Results.Count

    # Per-test detail map: key = "ClassName.Name", value = outcomes across runs
    [hashtable]$testDetails = @{}

    foreach ($run in $Results) {
        $totalDuration = $totalDuration + [double]$run.TotalDuration

        foreach ($tc in $run.TestCases) {
            [string]$status = [string]$tc.Status

            switch ($status) {
                'passed'  { $totalPassed++  }
                'failed'  { $totalFailed++  }
                'skipped' { $totalSkipped++ }
            }

            # Build a unique key per test
            [string]$key = "$($tc.ClassName).$($tc.Name)"

            if (-not $testDetails.ContainsKey($key)) {
                $testDetails[$key] = @{
                    Name      = [string]$tc.Name
                    ClassName = [string]$tc.ClassName
                    Outcomes  = [System.Collections.ArrayList]::new()
                }
            }

            [hashtable]$outcome = @{
                RunName        = [string]$run.RunName
                Status         = $status
                Duration       = [double]$tc.Duration
                FailureMessage = [string]$tc.FailureMessage
            }
            [void]$testDetails[$key].Outcomes.Add($outcome)
        }
    }

    [hashtable]$merged = @{
        TotalPassed  = $totalPassed
        TotalFailed  = $totalFailed
        TotalSkipped = $totalSkipped
        TotalDuration = $totalDuration
        RunCount     = $runCount
        TestDetails  = $testDetails
    }

    return $merged
}

# =============================================================================
# GREEN PHASE 4: Get-FlakyTests
# Identifies tests that passed in some runs and failed in others.
# A test is flaky if it has at least one 'passed' AND at least one 'failed'.
# =============================================================================
function Get-FlakyTests {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$MergedResults
    )

    [System.Collections.ArrayList]$flakyTests = [System.Collections.ArrayList]::new()

    foreach ($key in $MergedResults.TestDetails.Keys) {
        $detail = $MergedResults.TestDetails[$key]
        [System.Collections.ArrayList]$outcomes = $detail.Outcomes

        [bool]$hasPassed = $false
        [bool]$hasFailed = $false

        foreach ($outcome in $outcomes) {
            if ([string]$outcome.Status -eq 'passed') {
                $hasPassed = $true
            }
            elseif ([string]$outcome.Status -eq 'failed') {
                $hasFailed = $true
            }
        }

        # Flaky = seen both passed AND failed across runs
        if ($hasPassed -and $hasFailed) {
            [int]$totalRuns = $outcomes.Count
            [int]$failedRuns = @($outcomes | Where-Object { [string]$_.Status -eq 'failed' }).Count
            [double]$failureRate = [double]$failedRuns / [double]$totalRuns

            [hashtable]$flakyInfo = @{
                Key         = [string]$key
                Name        = [string]$detail.Name
                ClassName   = [string]$detail.ClassName
                FailureRate = $failureRate
                FailedRuns  = $failedRuns
                TotalRuns   = $totalRuns
                Outcomes    = $outcomes
            }
            [void]$flakyTests.Add($flakyInfo)
        }
    }

    return [array]$flakyTests.ToArray()
}

# =============================================================================
# GREEN PHASE 5: New-MarkdownSummary
# Generates a GitHub Actions-compatible markdown summary from aggregated results.
# =============================================================================
function New-MarkdownSummary {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$MergedResults,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$FlakyTests
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    # Title
    [void]$sb.AppendLine('# Test Results Summary')
    [void]$sb.AppendLine()

    # Overview section
    [int]$totalTests = $MergedResults.TotalPassed + $MergedResults.TotalFailed + $MergedResults.TotalSkipped
    [string]$durationFormatted = '{0:N2}' -f [double]$MergedResults.TotalDuration

    [void]$sb.AppendLine("**$totalTests** tests across **$($MergedResults.RunCount)** runs")
    [void]$sb.AppendLine()

    # Summary table
    [void]$sb.AppendLine('| Metric | Count |')
    [void]$sb.AppendLine('| ------ | ----- |')
    [void]$sb.AppendLine("| Passed | $($MergedResults.TotalPassed) |")
    [void]$sb.AppendLine("| Failed | $($MergedResults.TotalFailed) |")
    [void]$sb.AppendLine("| Skipped | $($MergedResults.TotalSkipped) |")
    [void]$sb.AppendLine("| Duration | ${durationFormatted}s |")
    [void]$sb.AppendLine()

    # Flaky tests section
    [void]$sb.AppendLine('## Flaky Tests')
    [void]$sb.AppendLine()

    if ($FlakyTests.Count -eq 0) {
        [void]$sb.AppendLine('No flaky tests detected.')
    }
    else {
        [void]$sb.AppendLine("Found **$($FlakyTests.Count)** flaky test(s):")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Test | Class | Failure Rate | Failed / Total |')
        [void]$sb.AppendLine('| ---- | ----- | ------------ | -------------- |')

        foreach ($flaky in $FlakyTests) {
            [int]$pct = [int]([double]$flaky.FailureRate * 100)
            [void]$sb.AppendLine("| $($flaky.Name) | $($flaky.ClassName) | ${pct}% | $($flaky.FailedRuns) / $($flaky.TotalRuns) |")
        }
    }

    [void]$sb.AppendLine()

    # Failed tests detail section
    [bool]$hasFailures = $MergedResults.TotalFailed -gt 0
    if ($hasFailures) {
        [void]$sb.AppendLine('## Failed Tests')
        [void]$sb.AppendLine()

        foreach ($key in $MergedResults.TestDetails.Keys) {
            $detail = $MergedResults.TestDetails[$key]
            foreach ($outcome in $detail.Outcomes) {
                if ([string]$outcome.Status -eq 'failed') {
                    [void]$sb.AppendLine("- **$($detail.ClassName).$($detail.Name)** (run: $($outcome.RunName))")
                    if (-not [string]::IsNullOrWhiteSpace([string]$outcome.FailureMessage)) {
                        [void]$sb.AppendLine("  > $($outcome.FailureMessage)")
                    }
                }
            }
        }
        [void]$sb.AppendLine()
    }

    return $sb.ToString()
}

# =============================================================================
# GREEN PHASE 6: Invoke-TestResultsAggregator
# End-to-end orchestrator: scans a directory for test files, parses them,
# merges results, detects flaky tests, and returns a markdown summary.
# =============================================================================
function Invoke-TestResultsAggregator {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Directory does not exist: $Path"
    }

    # Discover JUnit XML and JSON files
    [array]$xmlFiles = @(Get-ChildItem -Path $Path -Filter '*.xml' -File)
    [array]$jsonFiles = @(Get-ChildItem -Path $Path -Filter '*.json' -File)

    if (($xmlFiles.Count + $jsonFiles.Count) -eq 0) {
        throw "No test result files found in '$Path'. Expected .xml or .json files."
    }

    # Parse all files
    [System.Collections.ArrayList]$allResults = [System.Collections.ArrayList]::new()

    foreach ($xmlFile in $xmlFiles) {
        [hashtable]$parsed = Import-JUnitResults -Path $xmlFile.FullName
        [void]$allResults.Add($parsed)
    }

    foreach ($jsonFile in $jsonFiles) {
        [hashtable]$parsed = Import-JsonTestResults -Path $jsonFile.FullName
        [void]$allResults.Add($parsed)
    }

    # Merge, detect flaky, generate summary
    [hashtable]$merged = Merge-TestResults -Results ([hashtable[]]$allResults.ToArray())
    [array]$flakyTests = @(Get-FlakyTests -MergedResults $merged)
    [string]$summary = New-MarkdownSummary -MergedResults $merged -FlakyTests $flakyTests

    return $summary
}

# Export all public functions
Export-ModuleMember -Function @(
    'Import-JUnitResults'
    'Import-JsonTestResults'
    'Merge-TestResults'
    'Get-FlakyTests'
    'New-MarkdownSummary'
    'Invoke-TestResultsAggregator'
)
