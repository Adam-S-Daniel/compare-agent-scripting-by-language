# Test Results Aggregator
# Parses JUnit XML and JSON test results, aggregates across matrix runs,
# identifies flaky tests, and generates a GitHub Actions markdown summary.

[CmdletBinding()]
param(
    [string]$ResultsDir = '',
    [string]$OutputFile = ''
)

function Import-JUnitXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    try {
        [xml]$xml = Get-Content -Path $Path -Raw
    } catch {
        throw "Invalid XML in file: $Path - $_"
    }

    $suite = $xml.testsuites.testsuite
    if (-not $suite) {
        throw "Invalid JUnit XML: no testsuite element found in $Path"
    }

    $testCases = @()
    foreach ($tc in $suite.testcase) {
        $status = 'passed'
        $errorMessage = $null

        $failureNode = $tc.SelectSingleNode('failure')
        $skippedNode = $tc.SelectSingleNode('skipped')

        if ($failureNode) {
            $status = 'failed'
            $errorMessage = $failureNode.GetAttribute('message')
        } elseif ($skippedNode) {
            $status = 'skipped'
            $errorMessage = $skippedNode.GetAttribute('message')
        }

        $testCases += @{
            Name         = $tc.name
            ClassName    = $tc.classname
            Duration     = [double]$tc.time
            Status       = $status
            ErrorMessage = $errorMessage
        }
    }

    @{
        SuiteName  = $suite.name
        TotalTests = [int]$suite.tests
        Failed     = [int]$suite.failures
        Skipped    = [int]$suite.skipped
        Passed     = [int]$suite.tests - [int]$suite.failures - [int]$suite.skipped
        Duration   = [double]$suite.time
        TestCases  = $testCases
        SourceFile = (Split-Path $Path -Leaf)
    }
}

function Import-JsonTestResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    try {
        $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
    } catch {
        throw "Invalid JSON in file: $Path - $_"
    }

    $suite = $json.testSuites[0]
    if (-not $suite) {
        throw "Invalid JSON test results: no testSuites found in $Path"
    }

    $testCases = @()
    foreach ($tc in $suite.testCases) {
        $testCases += @{
            Name         = $tc.name
            ClassName    = $tc.classname
            Duration     = [double]$tc.duration
            Status       = $tc.status
            ErrorMessage = if ($tc.errorMessage) { $tc.errorMessage } else { $null }
        }
    }

    $passed = @($testCases | Where-Object { $_.Status -eq 'passed' }).Count
    $failed = @($testCases | Where-Object { $_.Status -eq 'failed' }).Count
    $skipped = @($testCases | Where-Object { $_.Status -eq 'skipped' }).Count

    @{
        SuiteName  = $suite.name
        TotalTests = [int]$suite.tests
        Failed     = $failed
        Skipped    = $skipped
        Passed     = $passed
        Duration   = [double]$suite.duration
        TestCases  = $testCases
        SourceFile = (Split-Path $Path -Leaf)
    }
}

function Merge-TestResults {
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

    foreach ($r in $Results) {
        $totalTests += $r.TotalTests
        $totalPassed += $r.Passed
        $totalFailed += $r.Failed
        $totalSkipped += $r.Skipped
        $totalDuration += $r.Duration
    }

    $executed = $totalPassed + $totalFailed
    $passRate = if ($executed -gt 0) {
        [Math]::Round(($totalPassed / $executed) * 100, 1)
    } else { 0.0 }

    @{
        TotalTests = $totalTests
        Passed     = $totalPassed
        Failed     = $totalFailed
        Skipped    = $totalSkipped
        Duration   = [Math]::Round($totalDuration, 2)
        PassRate   = $passRate
        Runs       = $Results
    }
}

function Find-FlakyTests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results
    )

    $testOutcomes = @{}
    foreach ($run in $Results) {
        foreach ($tc in $run.TestCases) {
            if ($tc.Status -eq 'skipped') { continue }
            if (-not $testOutcomes.ContainsKey($tc.Name)) {
                $testOutcomes[$tc.Name] = @{ PassCount = 0; FailCount = 0 }
            }
            if ($tc.Status -eq 'passed') {
                $testOutcomes[$tc.Name].PassCount++
            } else {
                $testOutcomes[$tc.Name].FailCount++
            }
        }
    }

    $flaky = @()
    foreach ($name in ($testOutcomes.Keys | Sort-Object)) {
        $outcome = $testOutcomes[$name]
        if ($outcome.PassCount -gt 0 -and $outcome.FailCount -gt 0) {
            $flaky += @{
                Name      = $name
                PassCount = $outcome.PassCount
                FailCount = $outcome.FailCount
            }
        }
    }

    return , $flaky
}

function New-MarkdownSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$MergedResults,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$FlakyTests
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("# Test Results Summary")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Totals")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("| Metric | Value |")
    [void]$sb.AppendLine("|--------|-------|")
    [void]$sb.AppendLine("| Total Tests | $($MergedResults.TotalTests) |")
    [void]$sb.AppendLine("| Passed | $($MergedResults.Passed) |")
    [void]$sb.AppendLine("| Failed | $($MergedResults.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($MergedResults.Skipped) |")
    $durationStr = "{0:F2}s" -f $MergedResults.Duration
    [void]$sb.AppendLine("| Duration | $durationStr |")
    $rateStr = "{0:F1}%" -f $MergedResults.PassRate
    [void]$sb.AppendLine("| Pass Rate | $rateStr |")

    if ($FlakyTests.Count -gt 0) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("## Flaky Tests")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("The following tests produced inconsistent results across runs:")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| Test Name | Pass Count | Fail Count |")
        [void]$sb.AppendLine("|-----------|-----------|------------|")
        foreach ($ft in $FlakyTests) {
            [void]$sb.AppendLine("| $($ft.Name) | $($ft.PassCount) | $($ft.FailCount) |")
        }
    }

    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Per-Run Results")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("| # | Suite | Passed | Failed | Skipped | Duration |")
    [void]$sb.AppendLine("|---|-------|--------|--------|---------|----------|")
    $runNum = 0
    foreach ($run in $MergedResults.Runs) {
        $runNum++
        $runDur = "{0:F2}s" -f $run.Duration
        [void]$sb.AppendLine("| $runNum | $($run.SuiteName) | $($run.Passed) | $($run.Failed) | $($run.Skipped) | $runDur |")
    }

    # Collect all failed tests
    $failedTests = @()
    foreach ($run in $MergedResults.Runs) {
        foreach ($tc in $run.TestCases) {
            if ($tc.Status -eq 'failed') {
                $failedTests += @{
                    Name      = $tc.Name
                    Suite     = $run.SuiteName
                    Source    = $run.SourceFile
                    Error     = $tc.ErrorMessage
                }
            }
        }
    }

    if ($failedTests.Count -gt 0) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("## Failed Tests")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| Test | Suite | Source | Error |")
        [void]$sb.AppendLine("|------|-------|--------|-------|")
        foreach ($ft in $failedTests) {
            [void]$sb.AppendLine("| $($ft.Name) | $($ft.Suite) | $($ft.Source) | $($ft.Error) |")
        }
    }

    return $sb.ToString()
}

# Main execution - only runs when ResultsDir is provided
if ($ResultsDir) {
    if (-not (Test-Path $ResultsDir)) {
        Write-Error "Results directory not found: $ResultsDir"
        exit 1
    }

    $results = @()
    foreach ($file in (Get-ChildItem -Path $ResultsDir -File | Sort-Object Name)) {
        switch ($file.Extension) {
            '.xml'  { $results += Import-JUnitXml -Path $file.FullName }
            '.json' { $results += Import-JsonTestResults -Path $file.FullName }
            default { Write-Warning "Skipping unsupported file: $($file.Name)" }
        }
    }

    if ($results.Count -eq 0) {
        Write-Error "No test result files found in $ResultsDir"
        exit 1
    }

    $merged = Merge-TestResults -Results $results
    $flaky = Find-FlakyTests -Results $results
    $markdown = New-MarkdownSummary -MergedResults $merged -FlakyTests $flaky

    Write-Output $markdown

    if ($OutputFile) {
        $markdown | Out-File -FilePath $OutputFile -Encoding utf8
        Write-Host "Summary written to $OutputFile"
    }

    # Write to GitHub Step Summary if available
    if ($env:GITHUB_STEP_SUMMARY) {
        $markdown | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
    }
}
