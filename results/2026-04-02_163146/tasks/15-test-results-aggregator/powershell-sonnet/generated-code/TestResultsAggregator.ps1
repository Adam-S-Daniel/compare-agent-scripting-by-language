# TestResultsAggregator.ps1
# Test Results Aggregator: parses JUnit XML and JSON test result files,
# aggregates results across matrix runs, detects flaky tests, and
# generates a GitHub Actions-compatible markdown summary.
#
# TDD APPROACH:
# This file was written AFTER TestResultsAggregator.Tests.ps1 to satisfy
# the failing tests (RED -> GREEN). Each function corresponds to a Describe block.
#
# Functions:
#   Parse-JUnitXml           - Cycle 1: parse JUnit XML -> test result objects
#   Parse-JsonResults        - Cycle 2: parse JSON results -> test result objects
#   Aggregate-TestResults    - Cycle 3: combine results, compute totals
#   Find-FlakyTests          - Cycle 4: identify tests that both pass and fail
#   New-MarkdownSummary      - Cycle 5: build GitHub Actions markdown summary
#   Invoke-TestResultsAggregator - Cycle 6: end-to-end orchestration

# =============================================================================
# CYCLE 1: Parse-JUnitXml
# =============================================================================
function Parse-JUnitXml {
    <#
    .SYNOPSIS
        Parses a JUnit XML file and returns an array of test result objects.
    .PARAMETER Path
        Path to the JUnit XML file.
    .PARAMETER RunId
        Identifier for this run (e.g. "matrix-ubuntu-node18"). Defaults to the filename.
    #>
    param(
        [string]$Path,
        [string]$RunId = ""
    )

    # Validate file exists before attempting to parse
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JUnit XML file not found: $Path"
    }

    # Use the RunId if provided, otherwise derive from filename
    if (-not $RunId) {
        $RunId = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Handle both <testsuites> (wrapper) and bare <testsuite> roots
    $suites = if ($xml.testsuites) {
        $xml.testsuites.testsuite
    } elseif ($xml.testsuite) {
        @($xml.testsuite)
    } else {
        throw "Unrecognized JUnit XML structure in: $Path"
    }

    foreach ($suite in $suites) {
        $suiteName = $suite.name

        foreach ($tc in $suite.testcase) {
            # Determine status by examining child elements
            $status = if ($tc.failure -or $tc.error) {
                "failed"
            } elseif ($tc.skipped) {
                "skipped"
            } else {
                "passed"
            }

            # Duration is a string attribute; convert to double safely
            $duration = 0.0
            if ($tc.time) {
                [double]::TryParse($tc.time, [System.Globalization.NumberStyles]::Any,
                    [System.Globalization.CultureInfo]::InvariantCulture, [ref]$duration) | Out-Null
            }

            # Build a unique test name: Suite::TestName
            $testName = "$suiteName::$($tc.name)"

            $results.Add([PSCustomObject]@{
                Name     = $testName
                Suite    = $suiteName
                Status   = $status
                Duration = $duration
                RunId    = $RunId
            })
        }
    }

    return $results.ToArray()
}

# =============================================================================
# CYCLE 2: Parse-JsonResults
# =============================================================================
function Parse-JsonResults {
    <#
    .SYNOPSIS
        Parses a JSON test results file and returns an array of test result objects.
    .DESCRIPTION
        Expected JSON schema:
        {
          "runId": "...",
          "suites": [
            {
              "name": "SuiteName",
              "tests": [
                { "name": "TestName", "status": "passed|failed|skipped", "duration": 1.23, "message": "..." }
              ]
            }
          ]
        }
    .PARAMETER Path
        Path to the JSON results file.
    .PARAMETER RunId
        Identifier for this run. Overrides any runId in the JSON.
    #>
    param(
        [string]$Path,
        [string]$RunId = ""
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON results file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw

    # Attempt to parse; throw a descriptive error on invalid JSON
    $data = try {
        $raw | ConvertFrom-Json
    } catch {
        throw "Invalid JSON in file '$Path': $($_.Exception.Message)"
    }

    # Use provided RunId, then JSON runId, then filename
    if (-not $RunId) {
        $RunId = if ($data.runId) { $data.runId } else {
            [System.IO.Path]::GetFileNameWithoutExtension($Path)
        }
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($suite in $data.suites) {
        $suiteName = $suite.name

        foreach ($test in $suite.tests) {
            $status = $test.status.ToLower()
            # Normalize any non-standard status values
            if ($status -notin @("passed", "failed", "skipped")) {
                $status = "unknown"
            }

            $duration = 0.0
            if ($null -ne $test.duration) {
                $duration = [double]$test.duration
            }

            $results.Add([PSCustomObject]@{
                Name     = "$suiteName::$($test.name)"
                Suite    = $suiteName
                Status   = $status
                Duration = $duration
                RunId    = $RunId
            })
        }
    }

    return $results.ToArray()
}

# =============================================================================
# CYCLE 3: Aggregate-TestResults
# =============================================================================
function Aggregate-TestResults {
    <#
    .SYNOPSIS
        Aggregates an array of test result objects into summary totals.
    .PARAMETER Results
        Array of test result objects (from Parse-JUnitXml or Parse-JsonResults).
    .OUTPUTS
        PSCustomObject with TotalPassed, TotalFailed, TotalSkipped, TotalDuration, TestRuns.
    #>
    param(
        [object[]]$Results
    )

    # Handle empty input gracefully
    if (-not $Results -or $Results.Count -eq 0) {
        return [PSCustomObject]@{
            TotalPassed   = 0
            TotalFailed   = 0
            TotalSkipped  = 0
            TotalDuration = 0.0
            TestRuns      = @()
        }
    }

    $passed  = ($Results | Where-Object { $_.Status -eq "passed"  }).Count
    $failed  = ($Results | Where-Object { $_.Status -eq "failed"  }).Count
    $skipped = ($Results | Where-Object { $_.Status -eq "skipped" }).Count

    # Sum durations; use Measure-Object for cleanliness
    $totalDuration = ($Results | Measure-Object -Property Duration -Sum).Sum

    return [PSCustomObject]@{
        TotalPassed   = $passed
        TotalFailed   = $failed
        TotalSkipped  = $skipped
        TotalDuration = [Math]::Round($totalDuration, 6)
        TestRuns      = $Results
    }
}

# =============================================================================
# CYCLE 4: Find-FlakyTests
# =============================================================================
function Find-FlakyTests {
    <#
    .SYNOPSIS
        Identifies tests that both passed and failed across different runs.
    .DESCRIPTION
        A test is considered "flaky" if it has at least one "passed" result
        and at least one "failed" result across all runs. Skipped results are
        ignored for flakiness detection.
    .PARAMETER Results
        Array of test result objects.
    .OUTPUTS
        Array of PSCustomObjects with Name, PassedRuns, FailedRuns.
    #>
    param(
        [object[]]$Results
    )

    if (-not $Results -or $Results.Count -eq 0) {
        return @()
    }

    # Group results by test name
    $byName = $Results | Group-Object -Property Name

    $flaky = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($group in $byName) {
        $entries = $group.Group

        $passedRuns = @($entries | Where-Object { $_.Status -eq "passed" }  | Select-Object -ExpandProperty RunId)
        $failedRuns = @($entries | Where-Object { $_.Status -eq "failed" }  | Select-Object -ExpandProperty RunId)

        # Flaky = has BOTH at least one pass AND at least one failure
        if ($passedRuns.Count -gt 0 -and $failedRuns.Count -gt 0) {
            $flaky.Add([PSCustomObject]@{
                Name       = $group.Name
                PassedRuns = $passedRuns
                FailedRuns = $failedRuns
            })
        }
    }

    return $flaky.ToArray()
}

# =============================================================================
# CYCLE 5: New-MarkdownSummary
# =============================================================================
function New-MarkdownSummary {
    <#
    .SYNOPSIS
        Generates a GitHub Actions-compatible markdown summary of test results.
    .PARAMETER Aggregation
        PSCustomObject returned by Aggregate-TestResults.
    .PARAMETER FlakyTests
        Array of flaky test objects returned by Find-FlakyTests.
    .OUTPUTS
        String containing markdown content.
    #>
    param(
        [PSCustomObject]$Aggregation,
        [object[]]$FlakyTests
    )

    $sb = [System.Text.StringBuilder]::new()

    # --- Header ---
    [void]$sb.AppendLine("# Test Results Summary")
    [void]$sb.AppendLine()

    # --- Overall stats table ---
    $totalTests = $Aggregation.TotalPassed + $Aggregation.TotalFailed + $Aggregation.TotalSkipped
    # Use N3 so "12.345s" contains the substring "12.34" (matches test assertion)
    $durationFormatted = "{0:N3}s" -f $Aggregation.TotalDuration

    [void]$sb.AppendLine("## Overall Results")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("| Metric | Value |")
    [void]$sb.AppendLine("|--------|-------|")
    [void]$sb.AppendLine("| Total Tests | $totalTests |")
    [void]$sb.AppendLine("| Passed | $($Aggregation.TotalPassed) |")
    [void]$sb.AppendLine("| Failed | $($Aggregation.TotalFailed) |")
    [void]$sb.AppendLine("| Skipped | $($Aggregation.TotalSkipped) |")
    [void]$sb.AppendLine("| Duration | $durationFormatted |")
    [void]$sb.AppendLine()

    # --- Status badge line ---
    if ($Aggregation.TotalFailed -eq 0) {
        [void]$sb.AppendLine("> All tests passed!")
    } else {
        [void]$sb.AppendLine("> $($Aggregation.TotalFailed) test(s) failed.")
    }
    [void]$sb.AppendLine()

    # --- Flaky tests section ---
    [void]$sb.AppendLine("## Flaky Tests")
    [void]$sb.AppendLine()

    if (-not $FlakyTests -or $FlakyTests.Count -eq 0) {
        [void]$sb.AppendLine("No flaky tests detected across all runs.")
    } else {
        [void]$sb.AppendLine("The following tests produced inconsistent results across matrix runs:")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| Test Name | Passed In | Failed In |")
        [void]$sb.AppendLine("|-----------|-----------|-----------|")

        foreach ($f in $FlakyTests) {
            $passed = $f.PassedRuns -join ", "
            $failed = $f.FailedRuns -join ", "
            [void]$sb.AppendLine("| $($f.Name) | $passed | $failed |")
        }
    }
    [void]$sb.AppendLine()

    # --- Per-run breakdown ---
    [void]$sb.AppendLine("## Per-Run Breakdown")
    [void]$sb.AppendLine()

    if ($Aggregation.TestRuns -and $Aggregation.TestRuns.Count -gt 0) {
        $runs = $Aggregation.TestRuns | Group-Object -Property RunId

        [void]$sb.AppendLine("| Run | Passed | Failed | Skipped | Duration |")
        [void]$sb.AppendLine("|-----|--------|--------|---------|----------|")

        foreach ($run in $runs) {
            $rPassed  = ($run.Group | Where-Object { $_.Status -eq "passed"  }).Count
            $rFailed  = ($run.Group | Where-Object { $_.Status -eq "failed"  }).Count
            $rSkipped = ($run.Group | Where-Object { $_.Status -eq "skipped" }).Count
            $rDur     = ($run.Group | Measure-Object -Property Duration -Sum).Sum
            $rDurFmt  = "{0:N3}s" -f $rDur
            [void]$sb.AppendLine("| $($run.Name) | $rPassed | $rFailed | $rSkipped | $rDurFmt |")
        }
    } else {
        [void]$sb.AppendLine("No run data available.")
    }

    return $sb.ToString()
}

# =============================================================================
# CYCLE 6: Invoke-TestResultsAggregator (end-to-end orchestration)
# =============================================================================
function Invoke-TestResultsAggregator {
    <#
    .SYNOPSIS
        Orchestrates parsing, aggregation, flaky-test detection, and markdown generation.
    .DESCRIPTION
        Accepts a list of input file descriptors, parses each according to its format,
        aggregates all results, identifies flaky tests, and returns a markdown summary.
    .PARAMETER InputFiles
        Array of hashtables, each with:
          Path   - path to the result file
          RunId  - identifier for this run
          Format - "junit" or "json"
    .OUTPUTS
        String containing the markdown summary.
    #>
    param(
        [object[]]$InputFiles
    )

    $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($file in $InputFiles) {
        $parsed = switch ($file.Format.ToLower()) {
            "junit" {
                Parse-JUnitXml -Path $file.Path -RunId $file.RunId
            }
            "json" {
                Parse-JsonResults -Path $file.Path -RunId $file.RunId
            }
            default {
                throw "Unknown format '$($file.Format)' for file: $($file.Path). Supported: junit, json"
            }
        }

        foreach ($r in $parsed) {
            $allResults.Add($r)
        }
    }

    $aggregation = Aggregate-TestResults -Results $allResults.ToArray()
    $flakyTests  = Find-FlakyTests -Results $allResults.ToArray()
    $markdown    = New-MarkdownSummary -Aggregation $aggregation -FlakyTests $flakyTests

    return $markdown
}
