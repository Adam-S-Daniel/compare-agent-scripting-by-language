# Invoke-TestResultsAggregator.ps1
# Parses JUnit XML and JSON test result files, aggregates across matrix runs,
# identifies flaky tests, and generates a GitHub Actions job summary in Markdown.
#
# Usage:
#   ./Invoke-TestResultsAggregator.ps1 -InputPath ./fixtures -OutputFile ./summary.md
#
# When dot-sourced (. ./Invoke-TestResultsAggregator.ps1), only functions are loaded.

[CmdletBinding()]
param(
    [string]$InputPath = ".",
    [string]$OutputFile = ""
)

# ============================================================
# Helper: extract run name from a file path (filename sans extension)
# ============================================================
function Get-RunName {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.Path]::GetFileNameWithoutExtension($Path)
}

# ============================================================
# Parse a JUnit XML file and return a run-result hashtable
# ============================================================
function Get-JUnitResults {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    [xml]$xml = Get-Content $Path -Raw -Encoding UTF8
    $runName  = Get-RunName -Path $Path
    $cases    = [System.Collections.Generic.List[hashtable]]::new()
    $passed   = 0
    $failed   = 0
    $skipped  = 0
    $duration = 0.0

    # Handle both <testsuites><testsuite> and bare <testsuite> root formats
    $suites = if ($xml.testsuites) { $xml.testsuites.testsuite } else { $xml.testsuite }

    foreach ($suite in $suites) {
        foreach ($tc in $suite.testcase) {
            $status  = "passed"
            $message = ""

            if ($tc.failure) {
                $status  = "failed"
                $message = $tc.failure.message
            } elseif ($tc.error) {
                $status  = "failed"
                $message = $tc.error.message
            } elseif ($null -ne $tc.skipped) {
                $status = "skipped"
            }

            $tcDuration = [double]($tc.time -as [double])
            $duration  += $tcDuration

            switch ($status) {
                "passed"  { $passed++ }
                "failed"  { $failed++ }
                "skipped" { $skipped++ }
            }

            $cases.Add(@{
                Name     = $tc.name
                Status   = $status
                Duration = $tcDuration
                Message  = $message
            })
        }
    }

    return @{
        RunName   = $runName
        Format    = "junit"
        Tests     = $passed + $failed + $skipped
        Passed    = $passed
        Failed    = $failed
        Skipped   = $skipped
        Duration  = [math]::Round($duration, 2)
        TestCases = $cases.ToArray()
    }
}

# ============================================================
# Parse a JSON result file and return a run-result hashtable
# JSON schema: { suite, platform, timestamp, tests: [{name, status, duration, message?}] }
# ============================================================
function Get-JsonResults {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $data    = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $runName = Get-RunName -Path $Path
    $cases   = [System.Collections.Generic.List[hashtable]]::new()
    $passed  = 0
    $failed  = 0
    $skipped = 0
    $duration = 0.0

    foreach ($test in $data.tests) {
        $status     = $test.status.ToLower()
        $message    = if ($test.PSObject.Properties['message']) { $test.message } else { "" }
        $tcDuration = [double]($test.duration -as [double])
        $duration  += $tcDuration

        switch ($status) {
            "passed"  { $passed++ }
            "failed"  { $failed++ }
            "skipped" { $skipped++ }
        }

        $cases.Add(@{
            Name     = $test.name
            Status   = $status
            Duration = $tcDuration
            Message  = $message
        })
    }

    return @{
        RunName   = $runName
        Format    = "json"
        Tests     = $passed + $failed + $skipped
        Passed    = $passed
        Failed    = $failed
        Skipped   = $skipped
        Duration  = [math]::Round($duration, 2)
        TestCases = $cases.ToArray()
    }
}

# ============================================================
# Dispatch to the appropriate parser based on file extension
# ============================================================
function Get-TestResults {
    param([Parameter(Mandatory)][string]$Path)

    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    switch ($ext) {
        ".xml"  { return Get-JUnitResults -Path $Path }
        ".json" { return Get-JsonResults  -Path $Path }
        default { throw "Unsupported file format '$ext': $Path" }
    }
}

# ============================================================
# Discover and parse all XML/JSON files under InputPath
# ============================================================
function Get-AllTestResults {
    param([Parameter(Mandatory)][string]$InputPath)

    if (-not (Test-Path $InputPath)) {
        throw "Input path not found: $InputPath"
    }

    $files = Get-ChildItem -Path $InputPath -Include "*.xml", "*.json" -File -Recurse |
             Sort-Object Name

    if ($files.Count -eq 0) {
        throw "No test result files (*.xml, *.json) found in: $InputPath"
    }

    return @($files | ForEach-Object { Get-TestResults -Path $_.FullName })
}

# ============================================================
# Compute aggregate totals across all runs
# ============================================================
function Get-AggregatedResults {
    param([Parameter(Mandatory)][array]$Runs)

    $total    = 0
    $passed   = 0
    $failed   = 0
    $skipped  = 0
    $duration = 0.0

    foreach ($run in $Runs) {
        $total    += $run.Tests
        $passed   += $run.Passed
        $failed   += $run.Failed
        $skipped  += $run.Skipped
        $duration += $run.Duration
    }

    return @{
        TotalTests = $total
        Passed     = $passed
        Failed     = $failed
        Skipped    = $skipped
        Duration   = [math]::Round($duration, 2)
    }
}

# ============================================================
# Identify flaky tests: tests that pass in some runs AND fail in others
# Returns sorted array of @{Name; PassedIn; FailedIn}
# ============================================================
function Get-FlakyTests {
    param([Parameter(Mandatory)][array]$Runs)

    $byName = @{}

    foreach ($run in $Runs) {
        foreach ($tc in $run.TestCases) {
            if (-not $byName.ContainsKey($tc.Name)) {
                $byName[$tc.Name] = @{
                    PassedIn = [System.Collections.Generic.List[string]]::new()
                    FailedIn = [System.Collections.Generic.List[string]]::new()
                }
            }
            if ($tc.Status -eq "passed") {
                $byName[$tc.Name].PassedIn.Add($run.RunName)
            } elseif ($tc.Status -eq "failed") {
                $byName[$tc.Name].FailedIn.Add($run.RunName)
            }
        }
    }

    $flaky = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($name in ($byName.Keys | Sort-Object)) {
        $entry = $byName[$name]
        if ($entry.PassedIn.Count -gt 0 -and $entry.FailedIn.Count -gt 0) {
            $flaky.Add(@{
                Name     = $name
                PassedIn = $entry.PassedIn.ToArray()
                FailedIn = $entry.FailedIn.ToArray()
            })
        }
    }

    return $flaky.ToArray()
}

# ============================================================
# Generate a GitHub Actions-compatible Markdown summary
# ============================================================
function New-MarkdownSummary {
    param(
        [Parameter(Mandatory)][hashtable]$Aggregate,
        [AllowEmptyCollection()][array]$FlakyTests = @(),
        [Parameter(Mandatory)][array]$Runs
    )

    $sb = [System.Text.StringBuilder]::new()

    $sb.AppendLine("# Test Results Summary") | Out-Null
    $sb.AppendLine()                         | Out-Null

    # Overall results table
    $sb.AppendLine("## Overall Results") | Out-Null
    $sb.AppendLine()                     | Out-Null
    $sb.AppendLine("| Metric | Value |") | Out-Null
    $sb.AppendLine("|--------|-------|") | Out-Null
    $sb.AppendLine("| Total Tests | $($Aggregate.TotalTests) |")                          | Out-Null
    $sb.AppendLine("| Passed | $($Aggregate.Passed) |")                                   | Out-Null
    $sb.AppendLine("| Failed | $($Aggregate.Failed) |")                                   | Out-Null
    $sb.AppendLine("| Skipped | $($Aggregate.Skipped) |")                                 | Out-Null
    $sb.AppendLine("| Duration | $($Aggregate.Duration.ToString('F2'))s |")               | Out-Null
    $sb.AppendLine()                                                                       | Out-Null

    # Per-run breakdown
    $sb.AppendLine("## Results by Run")                                                         | Out-Null
    $sb.AppendLine()                                                                            | Out-Null
    $sb.AppendLine("| Run | Format | Tests | Passed | Failed | Skipped | Duration |")          | Out-Null
    $sb.AppendLine("|-----|--------|-------|--------|--------|---------|----------|")            | Out-Null
    foreach ($run in $Runs) {
        $sb.AppendLine("| $($run.RunName) | $($run.Format) | $($run.Tests) | $($run.Passed) | $($run.Failed) | $($run.Skipped) | $($run.Duration.ToString('F2'))s |") | Out-Null
    }
    $sb.AppendLine() | Out-Null

    # Flaky tests section
    $sb.AppendLine("## Flaky Tests") | Out-Null
    $sb.AppendLine()                 | Out-Null
    if ($FlakyTests.Count -gt 0) {
        $sb.AppendLine("Tests that passed in some runs but failed in others:")      | Out-Null
        $sb.AppendLine()                                                            | Out-Null
        $sb.AppendLine("| Test Name | Passed In | Failed In |")                    | Out-Null
        $sb.AppendLine("|-----------|-----------|-----------|")                    | Out-Null
        foreach ($ft in $FlakyTests) {
            $passedIn = $ft.PassedIn -join ", "
            $failedIn = $ft.FailedIn -join ", "
            $sb.AppendLine("| $($ft.Name) | $passedIn | $failedIn |") | Out-Null
        }
    } else {
        $sb.AppendLine("No flaky tests detected.") | Out-Null
    }
    $sb.AppendLine() | Out-Null

    # Failed tests detail
    $allFailed = foreach ($run in $Runs) {
        foreach ($tc in $run.TestCases) {
            if ($tc.Status -eq "failed") {
                [PSCustomObject]@{ TestName = $tc.Name; RunName = $run.RunName; Message = $tc.Message }
            }
        }
    }

    if ($allFailed) {
        $sb.AppendLine("## Failed Tests")                          | Out-Null
        $sb.AppendLine()                                           | Out-Null
        $sb.AppendLine("| Test Name | Run | Message |")           | Out-Null
        $sb.AppendLine("|-----------|-----|---------|")           | Out-Null
        foreach ($f in $allFailed) {
            # Escape pipe chars so they don't break the table
            $msg = ($f.Message -replace '\|', '\|')
            $sb.AppendLine("| $($f.TestName) | $($f.RunName) | $msg |") | Out-Null
        }
        $sb.AppendLine() | Out-Null
    }

    return $sb.ToString()
}

# ============================================================
# Main entry point — only runs when script is invoked directly
# ============================================================
function Invoke-Main {
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [string]$OutputFile = ""
    )

    Write-Verbose "Discovering test result files in: $InputPath"

    $runs      = Get-AllTestResults -InputPath $InputPath
    $aggregate = Get-AggregatedResults -Runs $runs
    $flaky     = Get-FlakyTests -Runs $runs
    $markdown  = New-MarkdownSummary -Aggregate $aggregate -FlakyTests $flaky -Runs $runs

    # Emit structured KEY=VALUE lines for CI output parsing
    Write-Host "SUMMARY_TOTAL_TESTS=$($aggregate.TotalTests)"
    Write-Host "SUMMARY_PASSED=$($aggregate.Passed)"
    Write-Host "SUMMARY_FAILED=$($aggregate.Failed)"
    Write-Host "SUMMARY_SKIPPED=$($aggregate.Skipped)"
    Write-Host "SUMMARY_DURATION=$($aggregate.Duration.ToString('F2'))"
    Write-Host "SUMMARY_FLAKY_COUNT=$($flaky.Count)"
    $flakyNames = ($flaky | ForEach-Object { $_.Name }) -join ","
    Write-Host "SUMMARY_FLAKY_NAMES=$flakyNames"

    if ($OutputFile) {
        $markdown | Out-File -FilePath $OutputFile -Encoding UTF8 -NoNewline:$false
        Write-Verbose "Markdown summary written to: $OutputFile"
    } else {
        Write-Output $markdown
    }
}

# Guard: only execute main logic when the script is run directly, not dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main -InputPath $InputPath -OutputFile $OutputFile
}
