# TestResultsAggregator.ps1
#
# Parses test result files in JUnit XML and JSON formats, aggregates results
# across multiple files (simulating a matrix build), computes totals, identifies
# flaky tests, and generates a markdown summary for GitHub Actions job summaries.
#
# Usage: ./TestResultsAggregator.ps1 -FixturesPath ./fixtures

param(
    [Parameter(Mandatory = $true)]
    [string]$FixturesPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Parse a JUnit XML test result file and return an array of test case objects.
# JUnit XML format: <testsuites><testsuite><testcase> with optional <failure>/<skipped> children.
function Parse-JUnitXml {
    param([string]$FilePath)

    $results = @()
    try {
        [xml]$xml = Get-Content -Path $FilePath -Raw

        # Handle both <testsuites><testsuite> and bare <testsuite> root
        $suites = if ($xml.testsuites) { $xml.testsuites.testsuite } else { $xml.testsuite }
        if (-not $suites) {
            Write-Warning "No test suites found in $FilePath"
            return $results
        }

        # Normalize to array
        if ($suites -isnot [System.Array]) { $suites = @($suites) }

        foreach ($suite in $suites) {
            $suiteName = $suite.name
            $testcases = $suite.testcase
            if (-not $testcases) { continue }
            if ($testcases -isnot [System.Array]) { $testcases = @($testcases) }

            foreach ($tc in $testcases) {
                # Determine status from child elements using SelectSingleNode
                # (avoids strict-mode errors from accessing non-existent properties)
                $status = 'passed'
                if ($null -ne $tc.SelectSingleNode('failure')) { $status = 'failed' }
                if ($null -ne $tc.SelectSingleNode('skipped')) { $status = 'skipped' }

                $duration = 0.0
                $timeAttr = $tc.GetAttribute('time')
                if ($timeAttr) { $duration = [double]$timeAttr }

                $results += [PSCustomObject]@{
                    Name     = $tc.name
                    Suite    = $suiteName
                    Status   = $status
                    Duration = $duration
                    Source   = Split-Path $FilePath -Leaf
                }
            }
        }
    }
    catch {
        Write-Error "Failed to parse JUnit XML file '$FilePath': $_"
    }
    return $results
}

# Parse a JSON test result file and return an array of test case objects.
# Expected format: { "testsuites": [{ "name": "...", "testcases": [...] }] }
function Parse-JsonResults {
    param([string]$FilePath)

    $results = @()
    try {
        $json = Get-Content -Path $FilePath -Raw | ConvertFrom-Json

        foreach ($suite in $json.testsuites) {
            $suiteName = $suite.name
            foreach ($tc in $suite.testcases) {
                $results += [PSCustomObject]@{
                    Name     = $tc.name
                    Suite    = $suiteName
                    Status   = $tc.status
                    Duration = [double]$tc.duration
                    Source   = Split-Path $FilePath -Leaf
                }
            }
        }
    }
    catch {
        Write-Error "Failed to parse JSON file '$FilePath': $_"
    }
    return $results
}

# Discover and parse all test result files in the given directory.
# Auto-detects format by file extension (.xml = JUnit, .json = JSON).
function Get-AllTestResults {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Error "Fixtures path not found: $Path"
        return @()
    }

    $allResults = @()
    $files = @(Get-ChildItem -Path $Path -File | Where-Object { $_.Extension -in '.xml', '.json' })

    if ($files.Count -eq 0) {
        Write-Warning "No .xml or .json test result files found in $Path"
        return $allResults
    }

    foreach ($file in $files) {
        Write-Host "Parsing: $($file.Name)"
        switch ($file.Extension) {
            '.xml'  { $allResults += Parse-JUnitXml -FilePath $file.FullName }
            '.json' { $allResults += Parse-JsonResults -FilePath $file.FullName }
        }
    }

    return $allResults
}

# Identify flaky tests: tests that passed in some runs and failed in others.
# Groups test cases by name and checks if both 'passed' and 'failed' statuses exist.
function Find-FlakyTests {
    param([array]$AllResults)

    $flaky = @()

    # Group by test name, only consider tests that have both pass and fail results
    $grouped = $AllResults | Where-Object { $_.Status -ne 'skipped' } | Group-Object -Property Name

    foreach ($group in $grouped) {
        $statuses = @($group.Group | Select-Object -ExpandProperty Status | Sort-Object -Unique)
        if ($statuses -contains 'passed' -and $statuses -contains 'failed') {
            $total = @($group.Group).Count
            $passed = @($group.Group | Where-Object { $_.Status -eq 'passed' }).Count
            $pct = [math]::Round(($passed / $total) * 100, 1)

            $flaky += [PSCustomObject]@{
                Name     = $group.Name
                PassRate = "$pct% ($passed/$total)"
                Passed   = $passed
                Total    = $total
            }
        }
    }

    return $flaky
}

# Generate a markdown summary from aggregated test results.
function New-MarkdownSummary {
    param(
        [array]$AllResults,
        [array]$FlakyTests
    )

    $total = @($AllResults).Count
    $passed = @($AllResults | Where-Object { $_.Status -eq 'passed' }).Count
    $failed = @($AllResults | Where-Object { $_.Status -eq 'failed' }).Count
    $skipped = @($AllResults | Where-Object { $_.Status -eq 'skipped' }).Count
    $duration = [math]::Round(($AllResults | Measure-Object -Property Duration -Sum).Sum, 1)

    $md = @()
    $md += "# Test Results Summary"
    $md += ""
    $md += "| Metric | Value |"
    $md += "|--------|-------|"
    $md += "| Total | $total |"
    $md += "| Passed | $passed |"
    $md += "| Failed | $failed |"
    $md += "| Skipped | $skipped |"
    $md += "| Duration | ${duration}s |"
    $md += ""

    # Flaky tests section
    if ($FlakyTests -and @($FlakyTests).Count -gt 0) {
        $md += "## Flaky Tests"
        $md += ""
        $md += "| Test Name | Pass Rate |"
        $md += "|-----------|-----------|"
        foreach ($ft in $FlakyTests) {
            $md += "| $($ft.Name) | $($ft.PassRate) |"
        }
        $md += ""
    }
    else {
        $md += "No flaky tests detected."
        $md += ""
    }

    # Failed tests section (consistently failed tests, excluding flaky)
    $flakyNames = if ($null -ne $FlakyTests -and $FlakyTests) { @($FlakyTests | ForEach-Object { $_.Name }) } else { @() }
    $failedTests = @($AllResults | Where-Object { $_.Status -eq 'failed' } |
        Group-Object -Property Name |
        Where-Object { $_.Name -notin $flakyNames })

    if ($failedTests.Count -gt 0) {
        $md += "## Consistently Failed Tests"
        $md += ""
        $md += "| Test Name | Failures |"
        $md += "|-----------|----------|"
        foreach ($ft in $failedTests) {
            $md += "| $($ft.Name) | $($ft.Count) |"
        }
        $md += ""
    }

    return $md -join "`n"
}

# ============================================================================
# Main execution
# ============================================================================

Write-Host "=========================================="
Write-Host "  Test Results Aggregator"
Write-Host "=========================================="
Write-Host "Fixtures path: $FixturesPath"
Write-Host ""

# Step 1: Parse all test result files
$allResults = Get-AllTestResults -Path $FixturesPath

if ($allResults.Count -eq 0) {
    Write-Error "No test results found. Check your fixtures path."
    exit 1
}

Write-Host ""
Write-Host "Parsed $($allResults.Count) test case results."
Write-Host ""

# Step 2: Identify flaky tests
$flakyTests = Find-FlakyTests -AllResults $allResults

# Step 3: Generate and output markdown summary
$summary = New-MarkdownSummary -AllResults $allResults -FlakyTests $flakyTests

Write-Host $summary
