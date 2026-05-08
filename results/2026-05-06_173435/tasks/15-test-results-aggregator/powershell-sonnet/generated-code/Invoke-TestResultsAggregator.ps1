# Test Results Aggregator
# Parses JUnit XML and JSON test result files, aggregates across matrix runs,
# detects flaky tests, and produces a GitHub Actions markdown summary.

function Parse-JUnitXml {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    [xml]$xml = Get-Content -Raw $Path

    $tests = [System.Collections.Generic.List[PSCustomObject]]::new()
    $passed = 0
    $failed = 0
    $skipped = 0
    $duration = 0.0

    # Sum duration from testsuites root if present, else sum from suites
    $root = $xml.testsuites
    if ($null -eq $root) { $root = $xml.testsuite }

    if ($root.time) {
        $duration = [double]$root.time
    }

    foreach ($suite in $xml.SelectNodes("//testsuite")) {
        $suiteName = $suite.name

        foreach ($tc in $suite.SelectNodes("testcase")) {
            $name   = $tc.name
            $status = "passed"

            if ($tc.SelectSingleNode("failure") -or $tc.SelectSingleNode("error")) {
                $status = "failed"
                $failed++
            } elseif ($tc.SelectSingleNode("skipped")) {
                $status = "skipped"
                $skipped++
            } else {
                $passed++
            }

            $tests.Add([PSCustomObject]@{
                Name     = $name
                Status   = $status
                Suite    = $suiteName
                Duration = if ($tc.time) { [double]$tc.time } else { 0.0 }
            })
        }
    }

    [PSCustomObject]@{
        Passed   = $passed
        Failed   = $failed
        Skipped  = $skipped
        Duration = $duration
        Tests    = $tests.ToArray()
    }
}

function Parse-JsonResults {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $data = Get-Content -Raw $Path | ConvertFrom-Json

    $tests = foreach ($t in $data.tests) {
        [PSCustomObject]@{
            Name     = $t.name
            Status   = $t.status
            Suite    = if ($t.suite) { $t.suite } else { "Default" }
            Duration = if ($t.duration) { [double]$t.duration } else { 0.0 }
        }
    }

    [PSCustomObject]@{
        Passed   = [int]$data.summary.passed
        Failed   = [int]$data.summary.failed
        Skipped  = [int]$data.summary.skipped
        Duration = [double]$data.summary.duration
        Tests    = @($tests)
    }
}

function Merge-TestResults {
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$Results
    )

    $totalPassed   = ($Results | Measure-Object -Property Passed   -Sum).Sum
    $totalFailed   = ($Results | Measure-Object -Property Failed   -Sum).Sum
    $totalSkipped  = ($Results | Measure-Object -Property Skipped  -Sum).Sum
    $totalDuration = ($Results | Measure-Object -Property Duration -Sum).Sum

    # Collect per-test status across runs to identify flaky tests.
    # A test is flaky if it passed in at least one run and failed in at least one other.
    $testMap = @{}
    foreach ($result in $Results) {
        foreach ($t in $result.Tests) {
            $key = $t.Name
            if (-not $testMap.ContainsKey($key)) {
                $testMap[$key] = @{ PassCount = 0; FailCount = 0; SkipCount = 0 }
            }
            switch ($t.Status) {
                "passed"  { $testMap[$key].PassCount++ }
                "failed"  { $testMap[$key].FailCount++ }
                "skipped" { $testMap[$key].SkipCount++ }
            }
        }
    }

    $flakyTests = foreach ($name in $testMap.Keys) {
        $entry = $testMap[$name]
        if ($entry.PassCount -gt 0 -and $entry.FailCount -gt 0) {
            [PSCustomObject]@{
                Name      = $name
                PassCount = $entry.PassCount
                FailCount = $entry.FailCount
            }
        }
    }

    [PSCustomObject]@{
        TotalPassed   = $totalPassed
        TotalFailed   = $totalFailed
        TotalSkipped  = $totalSkipped
        TotalDuration = $totalDuration
        RunCount      = $Results.Count
        FlakyTests    = @($flakyTests)
    }
}

function New-MarkdownSummary {
    param(
        [Parameter(Mandatory)][PSCustomObject]$Merged
    )

    $total = $Merged.TotalPassed + $Merged.TotalFailed + $Merged.TotalSkipped
    $sb = [System.Text.StringBuilder]::new()

    $null = $sb.AppendLine("## Test Results Summary")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Metric | Value |")
    $null = $sb.AppendLine("|--------|-------|")
    $null = $sb.AppendLine("| Total Tests | $total |")
    $null = $sb.AppendLine("| Passed | $($Merged.TotalPassed) |")
    $null = $sb.AppendLine("| Failed | $($Merged.TotalFailed) |")
    $null = $sb.AppendLine("| Skipped | $($Merged.TotalSkipped) |")
    $null = $sb.AppendLine("| Duration (s) | $($Merged.TotalDuration) |")
    $null = $sb.AppendLine("| Matrix Runs | $($Merged.RunCount) |")

    if ($Merged.FlakyTests.Count -gt 0) {
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("### Flaky Tests Detected")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("| Test Name | Passed Runs | Failed Runs |")
        $null = $sb.AppendLine("|-----------|-------------|-------------|")
        foreach ($ft in $Merged.FlakyTests) {
            $null = $sb.AppendLine("| $($ft.Name) | $($ft.PassCount) | $($ft.FailCount) |")
        }
    }

    $sb.ToString()
}

function Invoke-Aggregation {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$OutputMarkdown
    )

    if (-not (Test-Path $Path)) {
        throw "Directory not found: $Path"
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($file in Get-ChildItem -Path $Path -File) {
        switch ($file.Extension.ToLower()) {
            ".xml" {
                $results.Add((Parse-JUnitXml -Path $file.FullName))
            }
            ".json" {
                $results.Add((Parse-JsonResults -Path $file.FullName))
            }
        }
    }

    if ($results.Count -eq 0) {
        throw "No test result files (.xml or .json) found in: $Path"
    }

    $merged = Merge-TestResults -Results $results.ToArray()

    if ($OutputMarkdown) {
        return New-MarkdownSummary -Merged $merged
    }

    $merged
}
