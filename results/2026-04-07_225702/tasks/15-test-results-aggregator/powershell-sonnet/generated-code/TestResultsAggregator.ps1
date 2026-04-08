# TestResultsAggregator.ps1
# Aggregates test results from JUnit XML and JSON files across matrix build runs.
# Computes totals, identifies flaky tests, and generates a GitHub Actions markdown summary.

# ---------------------------------------------------------------------------
# Parse-JUnitXml
# Reads a JUnit XML file and returns a structured result object.
# The JUnit schema allows <failure> and <skipped> child elements on <testcase>.
# ---------------------------------------------------------------------------
function Parse-JUnitXml {
    param([string]$Path)

    # Guard: file must exist before we try to parse it
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: '$Path'"
    }

    [xml]$doc = Get-Content -LiteralPath $Path -Raw

    # Support both <testsuites> (plural, wrapping one or more <testsuite>) and
    # bare <testsuite> roots.
    $root = $doc.DocumentElement

    # Collect all <testcase> nodes regardless of nesting depth
    $testcaseNodes = $root.GetElementsByTagName("testcase")

    $testCases = foreach ($tc in $testcaseNodes) {
        $status  = "Passed"
        $message = ""

        if ($null -ne $tc.failure) {
            $status  = "Failed"
            $message = $tc.failure.message
        } elseif ($null -ne $tc.error) {
            $status  = "Failed"
            $message = $tc.error.message
        } elseif ($null -ne $tc.skipped) {
            $status = "Skipped"
        }

        [PSCustomObject]@{
            Name     = $tc.name
            Suite    = $tc.classname
            Status   = $status
            Duration = [double]($tc.time ?? 0)
            Message  = $message
        }
    }

    # Derive counts from parsed test cases (authoritative over attribute values)
    $passed  = ($testCases | Where-Object Status -eq "Passed").Count
    $failed  = ($testCases | Where-Object Status -eq "Failed").Count
    $skipped = ($testCases | Where-Object Status -eq "Skipped").Count
    $total   = $testCases.Count

    # Duration: prefer the root attribute; fall back to summing individual cases
    $duration = if ($root.time) { [double]$root.time } else {
        ($testCases | Measure-Object Duration -Sum).Sum
    }

    [PSCustomObject]@{
        Source    = $Path
        Total     = $total
        Passed    = $passed
        Failed    = $failed
        Skipped   = $skipped
        Duration  = $duration
        TestCases = $testCases
    }
}

# ---------------------------------------------------------------------------
# Parse-JsonResults
# Reads a JSON file that contains a "tests" array and a "summary" object.
# ---------------------------------------------------------------------------
function Parse-JsonResults {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: '$Path'"
    }

    $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json

    $testCases = foreach ($t in $data.tests) {
        # Normalise status to Title Case (Passed/Failed/Skipped)
        $status = switch ($t.status.ToLower()) {
            "passed"  { "Passed" }
            "failed"  { "Failed" }
            "skipped" { "Skipped" }
            default   { "Unknown" }
        }

        [PSCustomObject]@{
            Name     = $t.name
            Suite    = $t.suite
            Status   = $status
            Duration = [double]($t.duration ?? 0)
            Message  = if ($t.message) { $t.message } else { "" }
        }
    }

    # Prefer the embedded summary block; derive from cases if absent
    $summary = $data.summary
    $total    = if ($summary) { [int]$summary.total    } else { $testCases.Count }
    $passed   = if ($summary) { [int]$summary.passed   } else { ($testCases | Where-Object Status -eq "Passed").Count }
    $failed   = if ($summary) { [int]$summary.failed   } else { ($testCases | Where-Object Status -eq "Failed").Count }
    $skipped  = if ($summary) { [int]$summary.skipped  } else { ($testCases | Where-Object Status -eq "Skipped").Count }
    $duration = if ($summary) { [double]$summary.duration } else { ($testCases | Measure-Object Duration -Sum).Sum }

    [PSCustomObject]@{
        Source    = $Path
        Total     = $total
        Passed    = $passed
        Failed    = $failed
        Skipped   = $skipped
        Duration  = $duration
        TestCases = $testCases
    }
}

# ---------------------------------------------------------------------------
# Aggregate-Results
# Sums totals across an array of run-result objects.
# ---------------------------------------------------------------------------
function Aggregate-Results {
    param([object[]]$RunResults)

    $totalTests    = ($RunResults | Measure-Object Total    -Sum).Sum
    $totalPassed   = ($RunResults | Measure-Object Passed   -Sum).Sum
    $totalFailed   = ($RunResults | Measure-Object Failed   -Sum).Sum
    $totalSkipped  = ($RunResults | Measure-Object Skipped  -Sum).Sum
    $totalDuration = ($RunResults | Measure-Object Duration -Sum).Sum

    [PSCustomObject]@{
        RunCount      = $RunResults.Count
        TotalTests    = $totalTests
        TotalPassed   = $totalPassed
        TotalFailed   = $totalFailed
        TotalSkipped  = $totalSkipped
        TotalDuration = [math]::Round($totalDuration, 4)
    }
}

# ---------------------------------------------------------------------------
# Find-FlakyTests
# A test is "flaky" if it has at least one Passed result AND at least one
# Failed result across the supplied runs.
# ---------------------------------------------------------------------------
function Find-FlakyTests {
    param([object[]]$RunResults)

    # Collect all test cases from all runs, grouped by name
    $allCases = $RunResults | ForEach-Object { $_.TestCases }

    $grouped = $allCases | Group-Object -Property Name

    $flaky = foreach ($group in $grouped) {
        $statuses = $group.Group | Select-Object -ExpandProperty Status
        $hasPass  = $statuses -contains "Passed"
        $hasFail  = $statuses -contains "Failed"

        if ($hasPass -and $hasFail) {
            $passCount = ($statuses | Where-Object { $_ -eq "Passed" }).Count
            $failCount = ($statuses | Where-Object { $_ -eq "Failed" }).Count
            $suite     = $group.Group[0].Suite

            [PSCustomObject]@{
                Name       = $group.Name
                Suite      = $suite
                PassCount  = $passCount
                FailCount  = $failCount
            }
        }
    }

    # Return null/empty array when none found (BeNullOrEmpty compatible)
    if ($flaky) { return $flaky } else { return @() }
}

# ---------------------------------------------------------------------------
# New-MarkdownSummary
# Generates a GitHub Actions job-summary markdown string.
# ---------------------------------------------------------------------------
function New-MarkdownSummary {
    param(
        [PSCustomObject]$Aggregated,
        [object[]]$FlakyTests
    )

    $passRate = if ($Aggregated.TotalTests -gt 0) {
        [math]::Round(($Aggregated.TotalPassed / $Aggregated.TotalTests) * 100, 1)
    } else { 0 }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Test Results Summary")
    $lines.Add("")
    $lines.Add("## Overview")
    $lines.Add("")
    $lines.Add("| Metric | Value |")
    $lines.Add("|--------|-------|")
    $lines.Add("| Runs   | $($Aggregated.RunCount) |")
    $lines.Add("| Total Tests | $($Aggregated.TotalTests) |")
    $lines.Add("| Passed  | $($Aggregated.TotalPassed) |")
    $lines.Add("| Failed  | $($Aggregated.TotalFailed) |")
    $lines.Add("| Skipped | $($Aggregated.TotalSkipped) |")
    $lines.Add("| Pass Rate | $passRate% |")
    $lines.Add("| Total Duration | $($Aggregated.TotalDuration)s |")
    $lines.Add("")

    # Status badge line
    $status = if ($Aggregated.TotalFailed -gt 0) { ":x: **FAILED**" } else { ":white_check_mark: **PASSED**" }
    $lines.Add("**Status:** $status")
    $lines.Add("")

    # Flaky tests section
    $lines.Add("## Flaky Tests")
    $lines.Add("")

    if ($FlakyTests -and $FlakyTests.Count -gt 0) {
        $lines.Add("The following tests had inconsistent results across runs:")
        $lines.Add("")
        $lines.Add("| Test | Suite | Pass Count | Fail Count |")
        $lines.Add("|------|-------|-----------|-----------|")
        foreach ($f in $FlakyTests) {
            $lines.Add("| $($f.Name) | $($f.Suite) | $($f.PassCount) | $($f.FailCount) |")
        }
    } else {
        $lines.Add("No flaky tests detected.")
    }

    $lines -join "`n"
}

# ---------------------------------------------------------------------------
# Invoke-Aggregator
# Top-level entry point: parse files, aggregate, find flaky tests, return md.
# Dispatches to the correct parser based on file extension.
# ---------------------------------------------------------------------------
function Invoke-Aggregator {
    param([string[]]$Paths)

    if (-not $Paths -or $Paths.Count -eq 0) {
        throw "At least one file path must be provided."
    }

    $runResults = foreach ($path in $Paths) {
        $ext = [System.IO.Path]::GetExtension($path).ToLower()
        switch ($ext) {
            ".xml"  { Parse-JUnitXml    -Path $path }
            ".json" { Parse-JsonResults -Path $path }
            default { throw "Unsupported file format '$ext' for '$path'. Supported: .xml, .json" }
        }
    }

    $aggregated = Aggregate-Results -RunResults $runResults
    $flaky      = Find-FlakyTests   -RunResults $runResults

    New-MarkdownSummary -Aggregated $aggregated -FlakyTests $flaky
}
