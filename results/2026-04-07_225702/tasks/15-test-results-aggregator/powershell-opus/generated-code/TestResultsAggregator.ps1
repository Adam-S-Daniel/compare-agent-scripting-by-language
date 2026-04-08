# TestResultsAggregator.ps1
# Aggregates test results from JUnit XML and JSON formats,
# identifies flaky tests, and generates a Markdown summary.

function Import-JUnitResults {
    <#
    .SYNOPSIS
        Parses a JUnit XML file into a normalized test-result object.
    .DESCRIPTION
        Reads a JUnit XML file (testsuites/testsuite/testcase), normalizes
        each test case into a PSCustomObject with Name, ClassName, Status,
        Duration, and ErrorMessage fields.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the file exists
    if (-not (Test-Path $Path)) {
        throw "File '$Path' does not exist."
    }

    # Try to parse the XML
    try {
        [xml]$xml = Get-Content -Path $Path -Raw
    }
    catch {
        throw "Failed to parse XML from '$Path': $_"
    }

    $testCases = @()
    $root = $xml.testsuites

    # Walk each testsuite and testcase
    foreach ($suite in $root.testsuite) {
        foreach ($tc in $suite.testcase) {
            $status = 'Passed'
            $errorMessage = $null

            if ($tc.failure) {
                $status = 'Failed'
                $errorMessage = $tc.failure.message
            }
            elseif ($tc.skipped) {
                $status = 'Skipped'
            }

            $testCases += [PSCustomObject]@{
                Name         = $tc.name
                ClassName    = $tc.classname
                Status       = $status
                Duration     = [double]$tc.time
                ErrorMessage = $errorMessage
            }
        }
    }

    # Return normalized result object
    [PSCustomObject]@{
        TestCases     = $testCases
        TotalDuration = [double]$root.time
    }
}

function Import-JsonResults {
    <#
    .SYNOPSIS
        Parses a JSON test-results file into a normalized test-result object.
    .DESCRIPTION
        Reads a JSON file with a testSuites array, normalizes each test into
        the same PSCustomObject shape as Import-JUnitResults.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File '$Path' does not exist."
    }

    try {
        $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse JSON from '$Path': $_"
    }

    # Normalize status strings to title case (passed -> Passed, etc.)
    $statusMap = @{
        'passed'  = 'Passed'
        'failed'  = 'Failed'
        'skipped' = 'Skipped'
    }

    $testCases = @()
    foreach ($suite in $json.testSuites) {
        foreach ($t in $suite.tests) {
            $normalizedStatus = $statusMap[$t.status]
            if (-not $normalizedStatus) {
                $normalizedStatus = (Get-Culture).TextInfo.ToTitleCase($t.status)
            }

            $testCases += [PSCustomObject]@{
                Name         = $t.name
                ClassName    = $t.classname
                Status       = $normalizedStatus
                Duration     = [double]$t.duration
                ErrorMessage = $t.error
            }
        }
    }

    $totalDuration = ($testCases | Measure-Object -Property Duration -Sum).Sum

    [PSCustomObject]@{
        TestCases     = $testCases
        TotalDuration = [double]$totalDuration
    }
}

function Merge-TestResults {
    <#
    .SYNOPSIS
        Aggregates multiple parsed test-result objects into a single summary.
    .DESCRIPTION
        Accepts an array of result objects (from Import-JUnitResults / Import-JsonResults),
        combines all test cases, and computes totals for passed/failed/skipped/duration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results
    )

    $allCases = @()
    $totalDuration = 0.0

    foreach ($r in $Results) {
        $allCases += $r.TestCases
        $totalDuration += $r.TotalDuration
    }

    $passed  = @($allCases | Where-Object { $_.Status -eq 'Passed' }).Count
    $failed  = @($allCases | Where-Object { $_.Status -eq 'Failed' }).Count
    $skipped = @($allCases | Where-Object { $_.Status -eq 'Skipped' }).Count

    [PSCustomObject]@{
        TotalTests    = $allCases.Count
        Passed        = $passed
        Failed        = $failed
        Skipped       = $skipped
        TotalDuration = [math]::Round($totalDuration, 3)
        AllTestCases  = $allCases
    }
}

function Get-FlakyTests {
    <#
    .SYNOPSIS
        Identifies flaky tests — those that both passed and failed across runs.
    .DESCRIPTION
        Groups test cases by their fully-qualified name (ClassName.Name), then
        checks if a test has at least one Passed AND at least one Failed outcome.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$MergedResults
    )

    if (-not $MergedResults.AllTestCases -or $MergedResults.AllTestCases.Count -eq 0) {
        return @()
    }

    # Group by test identity (ClassName + Name)
    $groups = $MergedResults.AllTestCases | Group-Object -Property { "$($_.ClassName).$($_.Name)" }

    $flakyTests = @()
    foreach ($g in $groups) {
        $statuses = $g.Group | Select-Object -ExpandProperty Status
        $passCount = @($statuses | Where-Object { $_ -eq 'Passed' }).Count
        $failCount = @($statuses | Where-Object { $_ -eq 'Failed' }).Count

        # Flaky = has both passes and failures
        if ($passCount -gt 0 -and $failCount -gt 0) {
            $flakyTests += [PSCustomObject]@{
                Name       = $g.Group[0].Name
                ClassName  = $g.Group[0].ClassName
                PassCount  = $passCount
                FailCount  = $failCount
                TotalRuns  = $g.Count
            }
        }
    }

    $flakyTests
}

function New-MarkdownSummary {
    <#
    .SYNOPSIS
        Generates a GitHub Actions-style Markdown summary of test results.
    .DESCRIPTION
        Produces a Markdown string with a totals table, a flaky tests section
        (if any), and a failed tests section (if any).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$MergedResults,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$FlakyTests
    )

    $sb = [System.Text.StringBuilder]::new()

    # Overall status indicator
    $statusIcon = if ($MergedResults.Failed -gt 0) { '&#x274C;' } else { '&#x2705;' }
    $statusText = if ($MergedResults.Failed -gt 0) { 'Some tests failed' } else { 'All tests passed' }

    [void]$sb.AppendLine("# Test Results Summary")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("**Status:** $statusIcon $statusText")
    [void]$sb.AppendLine()

    # Totals table
    [void]$sb.AppendLine("| Metric | Value |")
    [void]$sb.AppendLine("|--------|-------|")
    [void]$sb.AppendLine("| Total Tests | $($MergedResults.TotalTests) |")
    [void]$sb.AppendLine("| Passed | $($MergedResults.Passed) |")
    [void]$sb.AppendLine("| Failed | $($MergedResults.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($MergedResults.Skipped) |")
    [void]$sb.AppendLine("| Duration | $($MergedResults.TotalDuration)s |")
    [void]$sb.AppendLine()

    # Flaky tests section — only if there are flaky tests
    if ($FlakyTests -and $FlakyTests.Count -gt 0) {
        [void]$sb.AppendLine("## Flaky Tests")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("These tests produced inconsistent results across runs:")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| Test | Class | Passed | Failed | Total Runs |")
        [void]$sb.AppendLine("|------|-------|--------|--------|------------|")
        foreach ($ft in $FlakyTests) {
            [void]$sb.AppendLine("| $($ft.Name) | $($ft.ClassName) | $($ft.PassCount) | $($ft.FailCount) | $($ft.TotalRuns) |")
        }
        [void]$sb.AppendLine()
    }

    # Failed tests section — only if there are failures
    $failedCases = @($MergedResults.AllTestCases | Where-Object { $_.Status -eq 'Failed' })
    if ($failedCases.Count -gt 0) {
        [void]$sb.AppendLine("## Failed Tests")
        [void]$sb.AppendLine()
        foreach ($fc in $failedCases) {
            [void]$sb.AppendLine("### ``$($fc.ClassName).$($fc.Name)``")
            if ($fc.ErrorMessage) {
                [void]$sb.AppendLine()
                [void]$sb.AppendLine('```')
                [void]$sb.AppendLine($fc.ErrorMessage)
                [void]$sb.AppendLine('```')
            }
            [void]$sb.AppendLine()
        }
    }

    $sb.ToString()
}

function Invoke-TestResultsAggregator {
    <#
    .SYNOPSIS
        End-to-end orchestrator: scans a directory for test result files,
        parses them, aggregates, detects flaky tests, and produces a Markdown summary.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Directory '$Path' does not exist."
    }

    # Discover test result files
    $xmlFiles  = @(Get-ChildItem -Path $Path -Filter '*.xml' -File -ErrorAction SilentlyContinue)
    $jsonFiles = @(Get-ChildItem -Path $Path -Filter '*.json' -File -ErrorAction SilentlyContinue)

    if ($xmlFiles.Count -eq 0 -and $jsonFiles.Count -eq 0) {
        throw "No test result files found in '$Path'."
    }

    $results = @()

    foreach ($f in $xmlFiles) {
        try {
            $results += Import-JUnitResults -Path $f.FullName
        }
        catch {
            Write-Warning "Skipping '$($f.Name)': $_"
        }
    }

    foreach ($f in $jsonFiles) {
        try {
            $results += Import-JsonResults -Path $f.FullName
        }
        catch {
            Write-Warning "Skipping '$($f.Name)': $_"
        }
    }

    $merged = Merge-TestResults -Results $results
    $flaky  = Get-FlakyTests -MergedResults $merged
    $md     = New-MarkdownSummary -MergedResults $merged -FlakyTests $flaky

    [PSCustomObject]@{
        Merged     = $merged
        FlakyTests = $flaky
        Markdown   = $md
    }
}
