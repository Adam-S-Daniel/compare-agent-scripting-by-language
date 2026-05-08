# Test Results Aggregator
# Parses JUnit XML and JSON test result files, aggregates across multiple files
# (simulating a matrix build), identifies flaky tests, and outputs a markdown
# summary suitable for a GitHub Actions job summary.
#
# Usage:
#   ./Invoke-TestResultAggregator.ps1 -InputPath ./fixtures
#   ./Invoke-TestResultAggregator.ps1 -InputPath ./fixtures -JobSummary

param(
    [Parameter(Mandatory = $false)]
    [string]$InputPath = "."
)

# ---------------------------------------------------------------------------
# ConvertFrom-JUnitXml
# Parses a JUnit XML file and returns a result hashtable.
# ---------------------------------------------------------------------------
function ConvertFrom-JUnitXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    [xml]$doc = Get-Content $Path -Raw

    # Support both <testsuites><testsuite> and bare <testsuite>
    $suiteNode = if ($doc.testsuites) { $doc.testsuites.testsuite } else { $doc.testsuite }

    if (-not $suiteNode) {
        throw "No testsuite element found in: $Path"
    }

    $tests = @()
    foreach ($tc in $suiteNode.testcase) {
        $status = "Passed"
        if ($tc.failure) { $status = "Failed" }
        elseif ($tc.skipped) { $status = "Skipped" }

        $tests += [PSCustomObject]@{
            Name     = $tc.name
            Suite    = $suiteNode.name
            Status   = $status
            Duration = if ($tc.time) { [double]$tc.time } else { 0 }
            Message  = if ($tc.failure) { $tc.failure.message } else { $null }
        }
    }

    $tests_count  = [int]$suiteNode.tests
    $failures     = [int]$suiteNode.failures
    $skipped      = [int]$suiteNode.skipped
    $passed       = $tests_count - $failures - $skipped

    return [PSCustomObject]@{
        SourceFile = $Path
        Suite      = $suiteNode.name
        Passed     = $passed
        Failed     = $failures
        Skipped    = $skipped
        Duration   = [double]$suiteNode.time
        Tests      = $tests
    }
}

# ---------------------------------------------------------------------------
# ConvertFrom-JsonResults
# Parses a JSON test result file and returns a result hashtable.
# JSON format: { suite, duration, tests: [{name, status, duration, message?}] }
# ---------------------------------------------------------------------------
function ConvertFrom-JsonResults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $raw = Get-Content $Path -Raw
    try {
        $data = $raw | ConvertFrom-Json
    }
    catch {
        throw "invalid JSON in file '${Path}': $_"
    }

    $tests = @()
    foreach ($t in $data.tests) {
        $status = switch ($t.status.ToLower()) {
            "passed"  { "Passed" }
            "failed"  { "Failed" }
            "skipped" { "Skipped" }
            default   { "Unknown" }
        }
        $tests += [PSCustomObject]@{
            Name     = $t.name
            Suite    = $data.suite
            Status   = $status
            Duration = if ($t.duration) { [double]$t.duration } else { 0 }
            Message  = $t.message
        }
    }

    $passed  = ($tests | Where-Object Status -EQ "Passed").Count
    $failed  = ($tests | Where-Object Status -EQ "Failed").Count
    $skipped = ($tests | Where-Object Status -EQ "Skipped").Count

    return [PSCustomObject]@{
        SourceFile = $Path
        Suite      = $data.suite
        Passed     = $passed
        Failed     = $failed
        Skipped    = $skipped
        Duration   = [double]$data.duration
        Tests      = $tests
    }
}

# ---------------------------------------------------------------------------
# Invoke-AggregateResults
# Reads all .xml and .json files from InputPath and aggregates totals.
# ---------------------------------------------------------------------------
function Invoke-AggregateResults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath
    )

    $files = @()

    if (Test-Path $InputPath -PathType Container) {
        $xmlFiles  = Get-ChildItem $InputPath -Filter "*.xml"  | Sort-Object Name
        $jsonFiles = Get-ChildItem $InputPath -Filter "*.json" | Sort-Object Name

        foreach ($f in $xmlFiles)  { $files += ConvertFrom-JUnitXml    -Path $f.FullName }
        foreach ($f in $jsonFiles) { $files += ConvertFrom-JsonResults  -Path $f.FullName }
    }
    else {
        throw "InputPath '$InputPath' is not a valid directory."
    }

    $totalPassed   = ($files | Measure-Object -Property Passed   -Sum).Sum
    $totalFailed   = ($files | Measure-Object -Property Failed   -Sum).Sum
    $totalSkipped  = ($files | Measure-Object -Property Skipped  -Sum).Sum
    $totalDuration = ($files | Measure-Object -Property Duration -Sum).Sum
    $totalTests    = $totalPassed + $totalFailed + $totalSkipped

    # Round duration to avoid floating-point noise
    $totalDuration = [Math]::Round($totalDuration, 2)

    return [PSCustomObject]@{
        TotalPassed   = [int]$totalPassed
        TotalFailed   = [int]$totalFailed
        TotalSkipped  = [int]$totalSkipped
        TotalDuration = $totalDuration
        TotalTests    = [int]$totalTests
        Files         = $files
    }
}

# ---------------------------------------------------------------------------
# Find-FlakyTests
# A flaky test is one with the same suite+name that both passed and failed
# across different files (simulating different matrix runs).
# ---------------------------------------------------------------------------
function Find-FlakyTests {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$AggregatedResults
    )

    # Collect all test runs indexed by "Suite::Name"
    $index = @{}
    foreach ($file in $AggregatedResults.Files) {
        foreach ($t in $file.Tests) {
            $key = "$($t.Suite)::$($t.Name)"
            if (-not $index.ContainsKey($key)) {
                $index[$key] = @{ Suite = $t.Suite; Name = $t.Name; Passed = 0; Failed = 0 }
            }
            if ($t.Status -eq "Passed")  { $index[$key].Passed++ }
            if ($t.Status -eq "Failed")  { $index[$key].Failed++ }
        }
    }

    # Flaky = appeared in both passed and failed states
    $flaky = $index.Values |
        Where-Object { $_.Passed -gt 0 -and $_.Failed -gt 0 } |
        Sort-Object Suite, Name |
        ForEach-Object {
            [PSCustomObject]@{
                Suite       = $_.Suite
                Name        = $_.Name
                PassedRuns  = $_.Passed
                FailedRuns  = $_.Failed
            }
        }

    return @($flaky)
}

# ---------------------------------------------------------------------------
# New-MarkdownSummary
# Generates a GitHub Actions job summary in Markdown.
# ---------------------------------------------------------------------------
function New-MarkdownSummary {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$AggregatedResults,

        [Parameter(Mandatory = $true)]
        [array]$FlakyTests
    )

    $agg = $AggregatedResults
    $dur = "{0:F2}s" -f $agg.TotalDuration
    $lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add("## Test Results Summary")
    $lines.Add("")
    $lines.Add("| Metric | Value |")
    $lines.Add("|--------|-------|")
    $lines.Add("| Total Passed | $($agg.TotalPassed) |")
    $lines.Add("| Total Failed | $($agg.TotalFailed) |")
    $lines.Add("| Total Skipped | $($agg.TotalSkipped) |")
    $lines.Add("| Total Tests | $($agg.TotalTests) |")
    $lines.Add("| Total Duration | $dur |")
    $lines.Add("")

    # Flaky tests section
    $lines.Add("## Flaky Tests ($($FlakyTests.Count))")
    $lines.Add("")
    if ($FlakyTests.Count -eq 0) {
        $lines.Add("No flaky tests detected.")
    }
    else {
        $lines.Add("| Test | Suite | Passed Runs | Failed Runs |")
        $lines.Add("|------|-------|-------------|-------------|")
        foreach ($f in ($FlakyTests | Sort-Object Suite, Name)) {
            $lines.Add("| $($f.Name) | $($f.Suite) | $($f.PassedRuns) | $($f.FailedRuns) |")
        }
    }
    $lines.Add("")

    # Per-file breakdown
    $lines.Add("## Results by File")
    $lines.Add("")
    $lines.Add("| File | Suite | Passed | Failed | Skipped | Duration |")
    $lines.Add("|------|-------|--------|--------|---------|----------|")
    foreach ($file in $agg.Files) {
        $name     = Split-Path $file.SourceFile -Leaf
        $fileDur  = "{0:F2}s" -f $file.Duration
        $lines.Add("| $name | $($file.Suite) | $($file.Passed) | $($file.Failed) | $($file.Skipped) | $fileDur |")
    }

    return $lines -join "`n"
}

# ---------------------------------------------------------------------------
# Main entry point (only runs when the script is invoked directly)
# ---------------------------------------------------------------------------
if ($MyInvocation.InvocationName -ne '.') {
    $agg    = Invoke-AggregateResults -InputPath $InputPath
    $flaky  = Find-FlakyTests -AggregatedResults $agg
    $md     = New-MarkdownSummary -AggregatedResults $agg -FlakyTests $flaky

    # Machine-readable markers for act assertions
    Write-Output "AGGREGATOR_RESULT_PASSED=$($agg.TotalPassed)"
    Write-Output "AGGREGATOR_RESULT_FAILED=$($agg.TotalFailed)"
    Write-Output "AGGREGATOR_RESULT_SKIPPED=$($agg.TotalSkipped)"
    Write-Output "AGGREGATOR_RESULT_TOTAL=$($agg.TotalTests)"
    Write-Output "AGGREGATOR_RESULT_DURATION=$($agg.TotalDuration)"
    Write-Output "AGGREGATOR_RESULT_FLAKY=$($flaky.Count)"
    Write-Output ""
    Write-Output $md

    # Write to GitHub Actions step summary if the env var is set
    if ($env:GITHUB_STEP_SUMMARY) {
        $md | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    }
}
