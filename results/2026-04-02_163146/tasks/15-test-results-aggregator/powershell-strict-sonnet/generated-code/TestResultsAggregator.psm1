# TestResultsAggregator.psm1
# Parses JUnit XML and JSON test result files, aggregates across matrix runs,
# identifies flaky tests, and generates a GitHub Actions markdown summary.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

#region --- Internal helpers ---

# Normalise a status string from various sources to one of: Passed, Failed, Skipped
function ConvertTo-NormalisedStatus {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$RawStatus
    )

    switch ($RawStatus.ToLowerInvariant()) {
        'passed'  { return 'Passed' }
        'pass'    { return 'Passed' }
        'failed'  { return 'Failed' }
        'fail'    { return 'Failed' }
        'skipped' { return 'Skipped' }
        'skip'    { return 'Skipped' }
        default   { return 'Passed' }   # JUnit: absence of failure element = passed
    }
}

#endregion

#region --- Parse-JUnitXml ---

<#
.SYNOPSIS
    Parses a JUnit XML file and returns a structured result object.

.DESCRIPTION
    Reads a JUnit XML test report and extracts test counts and individual test case
    details. Each <testcase> element is examined for <failure>, <error>, or <skipped>
    child elements to determine status.

.PARAMETER Path
    Absolute or relative path to the JUnit XML file.

.OUTPUTS
    PSCustomObject with TotalTests, Passed, Failed, Skipped, Duration, TestCases, RunLabel.
#>
function Parse-JUnitXml {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: '$Path'"
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw

    $suite = $xml.testsuite

    # Accumulate per-case results (attribute values come back as strings)
    [int]$totalTests  = [int]$suite.tests
    [double]$duration = [double]$suite.time
    [int]$failCount   = 0
    [int]$skipCount   = 0

    $testCases = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($tc in $suite.testcase) {
        [string]$name     = [string]$tc.name
        [double]$tcTime   = [double]$tc.time
        [string]$status   = 'Passed'
        [string]$message  = ''

        # Check child elements for failure / error / skipped
        $failureNode = $tc.failure
        $errorNode   = $tc.error
        $skippedNode = $tc.skipped

        if ($null -ne $failureNode) {
            $status  = 'Failed'
            $message = [string]$failureNode.message
            $failCount++
        }
        elseif ($null -ne $errorNode) {
            $status  = 'Failed'
            $message = [string]$errorNode.message
            $failCount++
        }
        elseif ($null -ne $skippedNode) {
            $status  = 'Skipped'
            $message = [string]$skippedNode.message
            $skipCount++
        }

        $testCases.Add([PSCustomObject]@{
            Name     = $name
            Status   = $status
            Duration = $tcTime
            Message  = $message
        })
    }

    [int]$passCount = $totalTests - $failCount - $skipCount

    return [PSCustomObject]@{
        TotalTests = $totalTests
        Passed     = $passCount
        Failed     = $failCount
        Skipped    = $skipCount
        Duration   = $duration
        TestCases  = $testCases.ToArray()
        RunLabel   = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }
}

#endregion

#region --- Parse-JsonResults ---

<#
.SYNOPSIS
    Parses a JSON test results file and returns a structured result object.

.DESCRIPTION
    Reads a JSON file whose structure contains a "summary" section (total, passed,
    failed, skipped, duration) and a "tests" array of individual test cases.

.PARAMETER Path
    Absolute or relative path to the JSON results file.

.OUTPUTS
    PSCustomObject with TotalTests, Passed, Failed, Skipped, Duration, TestCases, RunLabel.
#>
function Parse-JsonResults {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: '$Path'"
    }

    $raw  = Get-Content -LiteralPath $Path -Raw
    $data = $raw | ConvertFrom-Json

    [int]$totalTests  = [int]$data.summary.total
    [int]$passed      = [int]$data.summary.passed
    [int]$failed      = [int]$data.summary.failed
    [int]$skipped     = [int]$data.summary.skipped
    [double]$duration = [double]$data.summary.duration

    $testCases = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($t in $data.tests) {
        [string]$status  = ConvertTo-NormalisedStatus -RawStatus ([string]$t.status)
        [string]$message = if ($null -ne $t.message) { [string]$t.message } else { '' }

        $testCases.Add([PSCustomObject]@{
            Name     = [string]$t.name
            Status   = $status
            Duration = [double]$t.duration
            Message  = $message
        })
    }

    return [PSCustomObject]@{
        TotalTests = $totalTests
        Passed     = $passed
        Failed     = $failed
        Skipped    = $skipped
        Duration   = $duration
        TestCases  = $testCases.ToArray()
        RunLabel   = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }
}

#endregion

#region --- Merge-TestResults ---

<#
.SYNOPSIS
    Merges an array of individual run result objects into a single aggregate.

.DESCRIPTION
    Sums TotalTests, Passed, Failed, Skipped, and Duration across all supplied
    result objects. The merged object does not carry TestCases; callers that need
    per-case data should work with the original Results array.

.PARAMETER Results
    Array of result PSCustomObjects as returned by Parse-JUnitXml or Parse-JsonResults.

.OUTPUTS
    PSCustomObject with aggregate TotalTests, Passed, Failed, Skipped, Duration.
#>
function Merge-TestResults {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Results
    )

    [int]$totalTests  = 0
    [int]$passed      = 0
    [int]$failed      = 0
    [int]$skipped     = 0
    [double]$duration = 0.0

    foreach ($r in $Results) {
        $totalTests += [int]$r.TotalTests
        $passed     += [int]$r.Passed
        $failed     += [int]$r.Failed
        $skipped    += [int]$r.Skipped
        $duration   += [double]$r.Duration
    }

    return [PSCustomObject]@{
        TotalTests = $totalTests
        Passed     = $passed
        Failed     = $failed
        Skipped    = $skipped
        Duration   = [Math]::Round($duration, 3)
    }
}

#endregion

#region --- Find-FlakyTests ---

<#
.SYNOPSIS
    Identifies tests that both pass and fail across different runs.

.DESCRIPTION
    A flaky test is one where the Status is 'Passed' in at least one run result and
    'Failed' in at least one other run result. The function groups test cases by name
    across all supplied result objects and flags those with mixed outcomes.

.PARAMETER Results
    Array of per-run result objects, each containing a RunLabel and TestCases array.

.OUTPUTS
    Array of PSCustomObjects: Name, PassCount, FailCount, Runs (labels where it ran).
#>
function Find-FlakyTests {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Results
    )

    # Build a dictionary: test name -> {pass runs, fail runs}
    $index = [System.Collections.Generic.Dictionary[string, PSCustomObject]]::new()

    foreach ($run in $Results) {
        [string]$label = [string]$run.RunLabel

        foreach ($tc in $run.TestCases) {
            [string]$name = [string]$tc.Name

            if (-not $index.ContainsKey($name)) {
                $index[$name] = [PSCustomObject]@{
                    Name      = $name
                    PassRuns  = [System.Collections.Generic.List[string]]::new()
                    FailRuns  = [System.Collections.Generic.List[string]]::new()
                }
            }

            if ($tc.Status -eq 'Passed') {
                $index[$name].PassRuns.Add($label)
            }
            elseif ($tc.Status -eq 'Failed') {
                $index[$name].FailRuns.Add($label)
            }
        }
    }

    # Collect tests that have both passes and failures
    $flaky = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($entry in $index.Values) {
        if ($entry.PassRuns.Count -gt 0 -and $entry.FailRuns.Count -gt 0) {
            $flaky.Add([PSCustomObject]@{
                Name      = $entry.Name
                PassCount = [int]$entry.PassRuns.Count
                FailCount = [int]$entry.FailRuns.Count
                PassRuns  = $entry.PassRuns.ToArray()
                FailRuns  = $entry.FailRuns.ToArray()
            })
        }
    }

    return , $flaky.ToArray()
}

#endregion

#region --- New-MarkdownSummary ---

<#
.SYNOPSIS
    Generates a GitHub Actions-compatible markdown job summary.

.DESCRIPTION
    Produces a markdown string that includes:
      - An overall PASSED / FAILED badge
      - A summary table (total, passed, failed, skipped, duration)
      - A per-run breakdown table
      - A flaky-tests section (if any)

.PARAMETER MergedResults
    The aggregate result object from Merge-TestResults.

.PARAMETER FlakyTests
    Array of flaky-test objects from Find-FlakyTests.

.PARAMETER RunResults
    The original per-run result objects (used for the per-run table).

.OUTPUTS
    [string] Markdown content.
#>
function New-MarkdownSummary {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$MergedResults,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$FlakyTests,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$RunResults
    )

    [string]$badge = if ([int]$MergedResults.Failed -eq 0) { '![PASSED](https://img.shields.io/badge/tests-PASSED-brightgreen)' }
                     else                                   { '![FAILED](https://img.shields.io/badge/tests-FAILED-red)' }

    $sb = [System.Text.StringBuilder]::new()

    $null = $sb.AppendLine('# Test Results Summary')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine($badge)
    $null = $sb.AppendLine()

    # Overall summary table
    $null = $sb.AppendLine('## Overall Results')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('| Metric | Value |')
    $null = $sb.AppendLine('|--------|-------|')
    $null = $sb.AppendLine("| Total  | $([int]$MergedResults.TotalTests) |")
    $null = $sb.AppendLine("| Passed | $([int]$MergedResults.Passed) |")
    $null = $sb.AppendLine("| Failed | $([int]$MergedResults.Failed) |")
    $null = $sb.AppendLine("| Skipped| $([int]$MergedResults.Skipped) |")
    $null = $sb.AppendLine("| Duration (s) | $([double]$MergedResults.Duration) |")
    $null = $sb.AppendLine()

    # Per-run breakdown
    if ($RunResults.Count -gt 0) {
        $null = $sb.AppendLine('## Per-Run Breakdown')
        $null = $sb.AppendLine()
        $null = $sb.AppendLine('| Run | Total | Passed | Failed | Skipped | Duration (s) |')
        $null = $sb.AppendLine('|-----|-------|--------|--------|---------|--------------|')

        foreach ($run in $RunResults) {
            $null = $sb.AppendLine("| $([string]$run.RunLabel) | $([int]$run.TotalTests) | $([int]$run.Passed) | $([int]$run.Failed) | $([int]$run.Skipped) | $([double]$run.Duration) |")
        }

        $null = $sb.AppendLine()
    }

    # Flaky tests section
    $null = $sb.AppendLine('## Flaky Tests')
    $null = $sb.AppendLine()

    if ($FlakyTests.Count -eq 0) {
        $null = $sb.AppendLine('_No flaky tests detected._')
    }
    else {
        $null = $sb.AppendLine('| Test Name | Pass Runs | Fail Runs |')
        $null = $sb.AppendLine('|-----------|-----------|-----------|')

        foreach ($ft in $FlakyTests) {
            $null = $sb.AppendLine("| $([string]$ft.Name) | $([int]$ft.PassCount) | $([int]$ft.FailCount) |")
        }
    }

    return $sb.ToString()
}

#endregion

#region --- Invoke-TestResultsAggregation (orchestration entry point) ---

<#
.SYNOPSIS
    Orchestrates end-to-end test result aggregation and markdown generation.

.DESCRIPTION
    Given a list of input file descriptors (Path, Format, RunLabel), this function:
      1. Parses each file using the appropriate parser (JUnit or Json).
      2. Merges all results into aggregate totals.
      3. Identifies flaky tests.
      4. Generates a markdown summary and writes it to OutputPath.

.PARAMETER InputFiles
    Array of PSCustomObjects each with: Path [string], Format [string] (JUnit|Json), RunLabel [string].

.PARAMETER OutputPath
    Path to write the generated markdown summary file.

.OUTPUTS
    None. Writes the markdown file as a side effect.
#>
function Invoke-TestResultsAggregation {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$InputFiles,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($fileDesc in $InputFiles) {
        [string]$filePath  = [string]$fileDesc.Path
        [string]$format    = [string]$fileDesc.Format
        [string]$runLabel  = [string]$fileDesc.RunLabel

        Write-Verbose "Parsing '$filePath' as $format (label: $runLabel)"

        $parsed = switch ($format) {
            'JUnit' { Parse-JUnitXml    -Path $filePath }
            'Json'  { Parse-JsonResults -Path $filePath }
            default { throw "Unknown format '$format'. Supported formats: JUnit, Json" }
        }

        # Attach the explicit run label (overrides the file-name default)
        $parsed.RunLabel = $runLabel

        $allResults.Add($parsed)
    }

    [PSCustomObject[]]$resultsArray = $allResults.ToArray()
    $merged = Merge-TestResults  -Results $resultsArray
    $flaky  = Find-FlakyTests    -Results $resultsArray
    $md     = New-MarkdownSummary -MergedResults $merged -FlakyTests $flaky -RunResults $resultsArray

    Set-Content -LiteralPath $OutputPath -Value $md -Encoding UTF8

    Write-Host "Summary written to: $OutputPath"
}

#endregion

# Export public functions only
Export-ModuleMember -Function @(
    'Parse-JUnitXml'
    'Parse-JsonResults'
    'Merge-TestResults'
    'Find-FlakyTests'
    'New-MarkdownSummary'
    'Invoke-TestResultsAggregation'
)
