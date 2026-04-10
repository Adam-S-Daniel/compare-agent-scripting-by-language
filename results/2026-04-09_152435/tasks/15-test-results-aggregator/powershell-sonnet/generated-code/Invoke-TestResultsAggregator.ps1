# Invoke-TestResultsAggregator.ps1
#
# Aggregates test results from multiple formats (JUnit XML, JSON) across a
# matrix build, computes totals, detects flaky tests, and emits a Markdown
# summary suitable for GitHub Actions $GITHUB_STEP_SUMMARY.
#
# Usage (direct):
#   ./Invoke-TestResultsAggregator.ps1 -InputPaths ./fixtures/*.xml,./fixtures/*.json
#
# Usage (dot-source in Pester):
#   . ./Invoke-TestResultsAggregator.ps1   # loads functions only

[CmdletBinding()]
param(
    # One or more file paths (globs supported) to JUnit XML or JSON result files.
    [string[]]$InputPaths,
    # Optional path to write the Markdown output; if omitted, writes to stdout.
    [string]$OutputPath
)

# ─── Function: Parse-JUnitXml ─────────────────────────────────────────────────
# RED → GREEN cycle 1
# Parses a JUnit XML file and returns an array of test-result objects.
function Parse-JUnitXml {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-Error "JUnit XML file not found: $Path"
        return @()
    }

    try {
        [xml]$xml = Get-Content -Path $Path -Raw -Encoding UTF8
    }
    catch {
        Write-Error "Failed to parse XML file '$Path': $_"
        return @()
    }

    $fileName = Split-Path $Path -Leaf
    $results  = [System.Collections.Generic.List[object]]::new()

    # Support both <testsuites><testsuite> and bare <testsuite> at root
    $suites = if ($xml.testsuites) { $xml.testsuites.testsuite } else { $xml.testsuite }
    if ($null -eq $suites) { return @() }

    # Normalise to array so foreach always iterates
    foreach ($suite in @($suites)) {
        $suiteName = $suite.name

        foreach ($tc in @($suite.testcase)) {
            if ($null -eq $tc) { continue }

            # Determine status from child elements
            $status  = "passed"
            $message = ""

            if ($tc.failure) {
                $status  = "failed"
                $message = if ($tc.failure.message) { $tc.failure.message }
                           else { $tc.failure.'#text' }
            }
            elseif ($tc.error) {
                $status  = "failed"
                $message = if ($tc.error.message) { $tc.error.message }
                           else { $tc.error.'#text' }
            }
            elseif ($tc.skipped -or $tc.'system-out' -match "skipped") {
                # Some reporters use <skipped/> element
                if ($tc.skipped -ne $null) { $status = "skipped" }
            }

            $results.Add([PSCustomObject]@{
                Name      = $tc.name
                ClassName = $tc.classname
                Suite     = $suiteName
                Status    = $status
                Duration  = [double]($tc.time ?? 0)
                Message   = [string]$message
                File      = $fileName
            })
        }
    }

    return $results.ToArray()
}

# ─── Function: Parse-JsonResults ─────────────────────────────────────────────
# RED → GREEN cycle 2
# Parses a JSON test-results file with the schema:
#   { "suite": "...", "duration": 0.7, "tests": [ { "name", "status", "duration" } ] }
function Parse-JsonResults {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-Error "JSON results file not found: $Path"
        return @()
    }

    try {
        $json = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to parse JSON file '$Path': $_"
        return @()
    }

    $fileName  = Split-Path $Path -Leaf
    $suiteName = $json.suite ?? "Unknown"
    $results   = [System.Collections.Generic.List[object]]::new()

    foreach ($test in $json.tests) {
        $results.Add([PSCustomObject]@{
            Name      = $test.name
            ClassName = $suiteName
            Suite     = $suiteName
            Status    = $test.status   # "passed" | "failed" | "skipped"
            Duration  = [double]($test.duration ?? 0)
            Message   = [string]($test.message ?? "")
            File      = $fileName
        })
    }

    return $results.ToArray()
}

# ─── Function: Aggregate-TestResults ─────────────────────────────────────────
# RED → GREEN cycle 3
# Takes a flat array of test-result objects (from all files/runs) and computes
# totals.  Returns a single PSCustomObject with the aggregate numbers.
function Aggregate-TestResults {
    param(
        [Parameter(Mandatory)][object[]]$AllResults
    )

    $passed  = @($AllResults | Where-Object { $_.Status -eq "passed" })
    $failed  = @($AllResults | Where-Object { $_.Status -eq "failed" })
    $skipped = @($AllResults | Where-Object { $_.Status -eq "skipped" })

    $totalDuration = ($AllResults | Measure-Object -Property Duration -Sum).Sum
    $roundedDuration = [Math]::Round([double]$totalDuration, 2)

    return [PSCustomObject]@{
        Total       = $AllResults.Count
        Passed      = $passed.Count
        Failed      = $failed.Count
        Skipped     = $skipped.Count
        Duration    = $roundedDuration
        FailedTests = $failed
    }
}

# ─── Function: Find-FlakyTests ───────────────────────────────────────────────
# RED → GREEN cycle 4
# A test is flaky if it appears in multiple runs and has at least one "passed"
# result AND at least one "failed" result.
function Find-FlakyTests {
    param(
        [Parameter(Mandatory)][object[]]$AllResults
    )

    $flaky = [System.Collections.Generic.List[object]]::new()

    $grouped = $AllResults | Group-Object -Property Name

    foreach ($group in $grouped) {
        $passes   = @($group.Group | Where-Object { $_.Status -eq "passed" }).Count
        $failures = @($group.Group | Where-Object { $_.Status -eq "failed" }).Count

        if ($passes -gt 0 -and $failures -gt 0) {
            $flaky.Add([PSCustomObject]@{
                Name   = $group.Name
                Passed = $passes
                Failed = $failures
            })
        }
    }

    return $flaky.ToArray()
}

# ─── Function: New-MarkdownSummary ───────────────────────────────────────────
# RED → GREEN cycle 5
# Generates a GitHub-Actions-compatible Markdown summary string.
function New-MarkdownSummary {
    param(
        [Parameter(Mandatory)][object]$Aggregated,
        [object[]]$FlakyTests = @()
    )

    $sb = [System.Text.StringBuilder]::new()

    # Header
    [void]$sb.AppendLine("# Test Results Summary")
    [void]$sb.AppendLine()

    # Totals table
    [void]$sb.AppendLine("## Totals")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("| Metric | Value |")
    [void]$sb.AppendLine("|--------|-------|")
    [void]$sb.AppendLine("| Total Tests | $($Aggregated.Total) |")
    [void]$sb.AppendLine("| Passed | $($Aggregated.Passed) |")
    [void]$sb.AppendLine("| Failed | $($Aggregated.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($Aggregated.Skipped) |")
    [void]$sb.AppendLine("| Duration (s) | $("{0:F2}" -f $Aggregated.Duration) |")

    # Flaky tests section
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Flaky Tests")
    [void]$sb.AppendLine()
    if ($FlakyTests -and $FlakyTests.Count -gt 0) {
        [void]$sb.AppendLine("The following tests had inconsistent results across runs:")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| Test Name | Passed | Failed |")
        [void]$sb.AppendLine("|-----------|--------|--------|")
        foreach ($ft in $FlakyTests) {
            [void]$sb.AppendLine("| $($ft.Name) | $($ft.Passed) | $($ft.Failed) |")
        }
    }
    else {
        [void]$sb.AppendLine("No flaky tests detected.")
    }

    # Failed tests section
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Failed Tests")
    [void]$sb.AppendLine()
    if ($Aggregated.FailedTests -and $Aggregated.FailedTests.Count -gt 0) {
        [void]$sb.AppendLine("| Test Name | Suite | Message |")
        [void]$sb.AppendLine("|-----------|-------|---------|")
        foreach ($ft in $Aggregated.FailedTests) {
            # Escape pipe characters in the message so the table stays valid
            $safeMsg = $ft.Message -replace '\|', '&#124;'
            [void]$sb.AppendLine("| $($ft.Name) | $($ft.Suite) | $safeMsg |")
        }
    }
    else {
        [void]$sb.AppendLine("All tests passed!")
    }

    return $sb.ToString()
}

# ─── Main entry point ─────────────────────────────────────────────────────────
# Guard: only execute when InputPaths is provided (not when dot-sourced by Pester)
if ($InputPaths -and $InputPaths.Count -gt 0) {

    $allResults = [System.Collections.Generic.List[object]]::new()

    foreach ($pattern in $InputPaths) {
        # Expand globs or accept literal paths
        $files = Get-Item -Path $pattern -ErrorAction SilentlyContinue
        if (-not $files) {
            Write-Warning "No files matched: $pattern"
            continue
        }
        foreach ($file in $files) {
            switch ($file.Extension.ToLower()) {
                ".xml"  { $allResults.AddRange(@(Parse-JUnitXml    -Path $file.FullName)) }
                ".json" { $allResults.AddRange(@(Parse-JsonResults  -Path $file.FullName)) }
                default { Write-Warning "Unsupported file extension: $($file.Extension)" }
            }
        }
    }

    if ($allResults.Count -eq 0) {
        Write-Error "No test results found. Check --InputPaths."
        exit 1
    }

    $aggregated = Aggregate-TestResults -AllResults $allResults.ToArray()
    $flaky      = Find-FlakyTests       -AllResults $allResults.ToArray()
    $summary    = New-MarkdownSummary   -Aggregated $aggregated -FlakyTests $flaky

    # Write to GITHUB_STEP_SUMMARY if running in GHA
    if ($env:GITHUB_STEP_SUMMARY) {
        $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding UTF8
    }

    if ($OutputPath) {
        $summary | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "Summary written to: $OutputPath"
    }
    else {
        Write-Output $summary
    }
}
