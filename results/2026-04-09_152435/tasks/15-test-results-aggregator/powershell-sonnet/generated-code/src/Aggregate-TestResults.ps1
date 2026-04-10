# Aggregate-TestResults.ps1
#
# Test results aggregator supporting JUnit XML and JSON formats.
# Parses multiple result files (simulating a matrix build), computes totals,
# identifies flaky tests, and generates a GitHub Actions markdown summary.
#
# TDD BUILD-UP HISTORY:
#   RED   -> Parse-JUnitXml tests written, function did not exist
#   GREEN -> Parse-JUnitXml implemented to pass tests
#   RED   -> Parse-JsonResults tests written, function did not exist
#   GREEN -> Parse-JsonResults implemented
#   RED   -> Aggregate-TestResults tests written, function did not exist
#   GREEN -> Aggregate-TestResults implemented
#   RED   -> Find-FlakyTests tests written, function did not exist
#   GREEN -> Find-FlakyTests implemented
#   RED   -> New-MarkdownSummary tests written, function did not exist
#   GREEN -> New-MarkdownSummary implemented
#   REFACTOR -> Extracted helper New-TestCaseObject, unified key generation

# Helper: builds the canonical key used to group test cases across runs.
function script:Get-TestCaseKey {
    param([string]$ClassName, [string]$Name)
    if ($ClassName) { return "${ClassName}::${Name}" }
    return $Name
}

# Helper: constructs a standardised test case hashtable.
function script:New-TestCaseObject {
    param(
        [string]$Name,
        [string]$ClassName,
        [string]$Status,   # "passed" | "failed" | "skipped"
        [double]$Duration,
        [string]$Message,
        [string]$SourceFile
    )
    return @{
        Name       = $Name
        ClassName  = $ClassName
        Key        = (script:Get-TestCaseKey $ClassName $Name)
        Status     = $Status
        Duration   = $Duration
        Message    = $Message
        SourceFile = $SourceFile
    }
}

# ============================================================
# Parse-JUnitXml
# Returns a hashtable with aggregated totals and test case list.
# ============================================================
function Parse-JUnitXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: '$Path'"
    }

    # Load and validate XML
    $raw = Get-Content -Path $Path -Raw
    try {
        [xml]$xml = $raw
    } catch {
        throw "Invalid XML in file '$Path': $($_.Exception.Message)"
    }

    # JUnit XML may have <testsuites> wrapping <testsuite>, or just <testsuite>.
    $suites = @($xml.testsuites.testsuite) + @($xml.testsuite) |
              Where-Object { $_ -ne $null }

    $testCases = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($suite in $suites) {
        foreach ($tc in $suite.testcase) {
            $status = "passed"
            $message = $null

            if ($tc.failure) {
                $status = "failed"
                $message = $tc.failure.message
            } elseif ($tc.error) {
                $status = "failed"
                $message = $tc.error.message
            } elseif ($tc.skipped -ne $null) {
                $status = "skipped"
            }

            $duration = 0.0
            if ($tc.time) { [double]::TryParse($tc.time, [ref]$duration) | Out-Null }

            $testCases.Add((script:New-TestCaseObject `
                -Name       $tc.name `
                -ClassName  $tc.classname `
                -Status     $status `
                -Duration   $duration `
                -Message    $message `
                -SourceFile $Path))
        }
    }

    $passed  = ($testCases | Where-Object { $_.Status -eq "passed"  }).Count
    $failed  = ($testCases | Where-Object { $_.Status -eq "failed"  }).Count
    $skipped = ($testCases | Where-Object { $_.Status -eq "skipped" }).Count

    # Duration: prefer the attribute on <testsuites> / <testsuite> for accuracy.
    $durationAttr = $xml.testsuites.time
    if (-not $durationAttr) { $durationAttr = ($suites | Select-Object -First 1).time }
    $totalDuration = 0.0
    if ($durationAttr) { [double]::TryParse($durationAttr, [ref]$totalDuration) | Out-Null }
    if ($totalDuration -eq 0.0) {
        $totalDuration = ($testCases | Measure-Object -Property Duration -Sum).Sum
    }

    return @{
        SourceFile  = $Path
        Format      = "junit"
        TotalTests  = $testCases.Count
        Passed      = $passed
        Failed      = $failed
        Skipped     = $skipped
        Duration    = $totalDuration
        TestCases   = $testCases.ToArray()
    }
}

# ============================================================
# Parse-JsonResults
# JSON format: { name, timestamp, testcases: [ {name, classname, status, duration, message} ] }
# ============================================================
function Parse-JsonResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: '$Path'"
    }

    $raw = Get-Content -Path $Path -Raw
    try {
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Invalid JSON in file '$Path': $($_.Exception.Message)"
    }

    if ($null -eq $data.testcases) {
        throw "Invalid JSON: missing 'testcases' array in '$Path'"
    }

    $testCases = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($tc in $data.testcases) {
        $status = if ($tc.status) { $tc.status.ToLower() } else { "passed" }
        $testCases.Add((script:New-TestCaseObject `
            -Name       $tc.name `
            -ClassName  $tc.classname `
            -Status     $status `
            -Duration   ([double]($tc.duration ?? 0)) `
            -Message    $tc.message `
            -SourceFile $Path))
    }

    $passed  = ($testCases | Where-Object { $_.Status -eq "passed"  }).Count
    $failed  = ($testCases | Where-Object { $_.Status -eq "failed"  }).Count
    $skipped = ($testCases | Where-Object { $_.Status -eq "skipped" }).Count
    $totalDuration = ($testCases | Measure-Object -Property Duration -Sum).Sum

    return @{
        SourceFile  = $Path
        Format      = "json"
        TotalTests  = $testCases.Count
        Passed      = $passed
        Failed      = $failed
        Skipped     = $skipped
        Duration    = $totalDuration
        TestCases   = $testCases.ToArray()
    }
}

# ============================================================
# Aggregate-TestResults
# Accepts an array of file paths (XML or JSON), dispatches to the
# correct parser, and returns unified aggregated results.
# ============================================================
function Aggregate-TestResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths
    )

    if ($Paths.Count -eq 0) {
        throw "Aggregate-TestResults requires at least one file path."
    }

    $files       = [System.Collections.Generic.List[hashtable]]::new()
    $allCases    = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($path in $Paths) {
        $ext = [System.IO.Path]::GetExtension($path).ToLower()
        switch ($ext) {
            ".xml" {
                $parsed = Parse-JUnitXml -Path $path
                $files.Add($parsed)
                foreach ($tc in $parsed.TestCases) { $allCases.Add($tc) }
            }
            ".json" {
                $parsed = Parse-JsonResults -Path $path
                $files.Add($parsed)
                foreach ($tc in $parsed.TestCases) { $allCases.Add($tc) }
            }
            default {
                Write-Warning "Unsupported file extension '$ext' for file '$path'. Skipping."
            }
        }
    }

    # Group test cases by their canonical key for flaky detection
    $byName = @{}
    foreach ($tc in $allCases) {
        if (-not $byName.ContainsKey($tc.Key)) {
            $byName[$tc.Key] = [System.Collections.Generic.List[hashtable]]::new()
        }
        $byName[$tc.Key].Add($tc)
    }

    $totalTests    = ($files | Measure-Object -Property TotalTests -Sum).Sum
    $totalPassed   = ($files | Measure-Object -Property Passed     -Sum).Sum
    $totalFailed   = ($files | Measure-Object -Property Failed     -Sum).Sum
    $totalSkipped  = ($files | Measure-Object -Property Skipped    -Sum).Sum
    $totalDuration = ($files | Measure-Object -Property Duration   -Sum).Sum

    return @{
        Files           = $files.ToArray()
        TotalTests      = [int]$totalTests
        TotalPassed     = [int]$totalPassed
        TotalFailed     = [int]$totalFailed
        TotalSkipped    = [int]$totalSkipped
        TotalDuration   = [double]$totalDuration
        TestCasesByName = $byName
    }
}

# ============================================================
# Find-FlakyTests
# A test is FLAKY if it appears in more than one run AND has
# both "passed" and "failed" results across those runs.
# ============================================================
function Find-FlakyTests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$AggregatedResults
    )

    $flaky = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($key in $AggregatedResults.TestCasesByName.Keys) {
        $runs      = $AggregatedResults.TestCasesByName[$key]
        $passCount = ($runs | Where-Object { $_.Status -eq "passed"  }).Count
        $failCount = ($runs | Where-Object { $_.Status -eq "failed"  }).Count

        # Flaky = seen in multiple runs AND has at least one pass AND one fail
        if ($runs.Count -gt 1 -and $passCount -ge 1 -and $failCount -ge 1) {
            $flaky.Add(@{
                Name      = $key
                PassCount = $passCount
                FailCount = $failCount
                Runs      = $runs.ToArray()
            })
        }
    }

    return $flaky.ToArray()
}

# ============================================================
# New-MarkdownSummary
# Generates a GitHub Actions-compatible markdown job summary.
# ============================================================
function New-MarkdownSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$AggregatedResults,

        [Parameter(Mandatory)]
        [object[]]$FlakyTests
    )

    $agg     = $AggregatedResults
    $dSec    = [math]::Round($agg.TotalDuration, 2)
    $passRate = if ($agg.TotalTests -gt 0) {
        [math]::Round(($agg.TotalPassed / $agg.TotalTests) * 100, 1)
    } else { 0 }

    $statusIcon = if ($agg.TotalFailed -eq 0) { "PASS" } else { "FAIL" }

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Test Results Summary [$statusIcon]")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Aggregate Totals")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Metric | Value |")
    $null = $sb.AppendLine("|--------|-------|")
    $null = $sb.AppendLine("| Total Tests | $($agg.TotalTests) |")
    $null = $sb.AppendLine("| Passed | $($agg.TotalPassed) |")
    $null = $sb.AppendLine("| Failed | $($agg.TotalFailed) |")
    $null = $sb.AppendLine("| Skipped | $($agg.TotalSkipped) |")
    $null = $sb.AppendLine("| Duration (s) | ${dSec} |")
    $null = $sb.AppendLine("| Pass Rate | ${passRate}% |")
    $null = $sb.AppendLine("")

    # Per-file breakdown
    $null = $sb.AppendLine("## Per-File Breakdown")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| File | Format | Tests | Passed | Failed | Skipped | Duration (s) |")
    $null = $sb.AppendLine("|------|--------|-------|--------|--------|---------|-------------|")
    foreach ($f in $agg.Files) {
        $fileName = [System.IO.Path]::GetFileName($f.SourceFile)
        $null = $sb.AppendLine("| $fileName | $($f.Format) | $($f.TotalTests) | $($f.Passed) | $($f.Failed) | $($f.Skipped) | $([math]::Round($f.Duration,2)) |")
    }
    $null = $sb.AppendLine("")

    # Failed tests
    $failedCases = $agg.Files | ForEach-Object { $_.TestCases } | Where-Object { $_.Status -eq "failed" }
    if ($failedCases) {
        $null = $sb.AppendLine("## Failed Tests")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("| Test | Class | Message | File |")
        $null = $sb.AppendLine("|------|-------|---------|------|")
        foreach ($tc in $failedCases) {
            $msg      = if ($tc.Message) { $tc.Message -replace '\r?\n', ' ' | Select-Object -First 1 } else { "-" }
            $fileName = [System.IO.Path]::GetFileName($tc.SourceFile)
            $null = $sb.AppendLine("| $($tc.Name) | $($tc.ClassName) | $msg | $fileName |")
        }
        $null = $sb.AppendLine("")
    } else {
        $null = $sb.AppendLine("> All tests passed - no failures detected.")
        $null = $sb.AppendLine("")
    }

    # Flaky tests section
    if ($FlakyTests -and $FlakyTests.Count -gt 0) {
        $null = $sb.AppendLine("## Flaky Tests")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("> The following tests had inconsistent results across runs (passed in some, failed in others).")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("| Test | Pass Runs | Fail Runs |")
        $null = $sb.AppendLine("|------|-----------|-----------|")
        foreach ($ft in $FlakyTests) {
            $null = $sb.AppendLine("| $($ft.Name) | $($ft.PassCount) | $($ft.FailCount) |")
        }
        $null = $sb.AppendLine("")
    }

    return $sb.ToString()
}
