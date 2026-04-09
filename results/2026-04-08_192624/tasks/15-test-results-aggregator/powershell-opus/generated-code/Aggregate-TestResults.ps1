<#
.SYNOPSIS
    Aggregates test results from JUnit XML and JSON files across matrix builds.
.DESCRIPTION
    Parses test result files in JUnit XML and JSON formats, computes totals
    (passed, failed, skipped, duration), identifies flaky tests (tests that
    passed in some runs and failed in others), and generates a markdown summary
    suitable for a GitHub Actions job summary.
.PARAMETER ResultsDir
    Directory containing test result files (*.xml for JUnit, *.json for JSON).
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ResultsDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Validate the results directory exists
if (-not (Test-Path $ResultsDir)) {
    Write-Error "Results directory not found: $ResultsDir"
    exit 1
}

# Collect all individual test results from every file
$allResults = [System.Collections.ArrayList]::new()

# --- Parse JUnit XML files ---
$xmlFiles = @(Get-ChildItem -Path $ResultsDir -Filter "*.xml" -ErrorAction SilentlyContinue)
foreach ($file in $xmlFiles) {
    try {
        [xml]$xml = Get-Content $file.FullName -Raw

        # Handle both <testsuites><testsuite>... and bare <testsuite>...
        if ($xml.testsuites) {
            $testsuites = @($xml.testsuites.testsuite)
        }
        elseif ($xml.testsuite) {
            $testsuites = @($xml.testsuite)
        }
        else {
            Write-Warning "No testsuite element found in $($file.Name), skipping."
            continue
        }

        foreach ($suite in $testsuites) {
            $testcases = @($suite.testcase)
            foreach ($tc in $testcases) {
                # Determine status from child elements using SelectSingleNode
                # to avoid strict-mode errors on missing properties
                $status = "passed"
                if ($null -ne $tc.SelectSingleNode('failure')) {
                    $status = "failed"
                }
                elseif ($null -ne $tc.SelectSingleNode('skipped')) {
                    $status = "skipped"
                }

                # Parse duration safely
                $duration = 0.0
                $timeAttr = $tc.GetAttribute('time')
                if ($timeAttr) {
                    $duration = [double]$timeAttr
                }

                # Build a fully-qualified test name
                $suiteName = $suite.GetAttribute('name')
                $caseName  = $tc.GetAttribute('name')
                $testName  = "$suiteName.$caseName"

                [void]$allResults.Add([PSCustomObject]@{
                    Name     = $testName
                    Status   = $status
                    Duration = $duration
                    File     = $file.Name
                })
            }
        }
    }
    catch {
        Write-Error "Failed to parse JUnit XML file '$($file.Name)': $_"
    }
}

# --- Parse JSON test result files ---
$jsonFiles = @(Get-ChildItem -Path $ResultsDir -Filter "*.json" -ErrorAction SilentlyContinue)
foreach ($file in $jsonFiles) {
    try {
        $json = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $suiteName = $json.testSuite

        foreach ($result in $json.results) {
            $testName = "$suiteName.$($result.name)"

            [void]$allResults.Add([PSCustomObject]@{
                Name     = $testName
                Status   = $result.status
                Duration = [double]$result.duration
                File     = $file.Name
            })
        }
    }
    catch {
        Write-Error "Failed to parse JSON file '$($file.Name)': $_"
    }
}

# --- Compute aggregate totals ---
$totalTests = $allResults.Count
$passed  = @($allResults | Where-Object { $_.Status -eq "passed" }).Count
$failed  = @($allResults | Where-Object { $_.Status -eq "failed" }).Count
$skipped = @($allResults | Where-Object { $_.Status -eq "skipped" }).Count

$durationSum = ($allResults | Measure-Object -Property Duration -Sum).Sum
if ($null -eq $durationSum) { $durationSum = 0 }
$totalDuration = "{0:F2}" -f $durationSum

# --- Identify flaky tests ---
# A test is "flaky" if it appears with both passed and failed status across runs.
$grouped = $allResults | Group-Object -Property Name
$flakyTests = [System.Collections.ArrayList]::new()
foreach ($group in $grouped) {
    $statuses = @($group.Group | Select-Object -ExpandProperty Status -Unique)
    if (($statuses -contains "passed") -and ($statuses -contains "failed")) {
        $passCount = @($group.Group | Where-Object { $_.Status -eq "passed" }).Count
        $failCount = @($group.Group | Where-Object { $_.Status -eq "failed" }).Count
        [void]$flakyTests.Add([PSCustomObject]@{
            Name      = $group.Name
            PassCount = $passCount
            FailCount = $failCount
        })
    }
}
$flakyTests = @($flakyTests | Sort-Object -Property Name)

# --- Compute per-file breakdown ---
$fileGroups = $allResults | Group-Object -Property File | Sort-Object -Property Name
$fileStats = foreach ($fg in $fileGroups) {
    $fp = @($fg.Group | Where-Object { $_.Status -eq "passed" }).Count
    $ff = @($fg.Group | Where-Object { $_.Status -eq "failed" }).Count
    $fs = @($fg.Group | Where-Object { $_.Status -eq "skipped" }).Count
    $fd = ($fg.Group | Measure-Object -Property Duration -Sum).Sum
    [PSCustomObject]@{
        File     = $fg.Name
        Total    = $fg.Count
        Passed   = $fp
        Failed   = $ff
        Skipped  = $fs
        Duration = "{0:F2}" -f $fd
    }
}

# --- Build the markdown summary ---
$sb = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine("# Test Results Summary")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Metric | Value |")
[void]$sb.AppendLine("|--------|-------|")
[void]$sb.AppendLine("| Total | $totalTests |")
[void]$sb.AppendLine("| Passed | $passed |")
[void]$sb.AppendLine("| Failed | $failed |")
[void]$sb.AppendLine("| Skipped | $skipped |")
[void]$sb.AppendLine("| Duration | ${totalDuration}s |")

# Flaky tests section
if ($flakyTests.Count -gt 0) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Flaky Tests")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("The following tests produced inconsistent results across runs:")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Test Name | Pass Count | Fail Count |")
    [void]$sb.AppendLine("|-----------|------------|------------|")
    foreach ($ft in $flakyTests) {
        [void]$sb.AppendLine("| $($ft.Name) | $($ft.PassCount) | $($ft.FailCount) |")
    }
}
else {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Flaky Tests")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("No flaky tests detected.")
}

# Per-file breakdown
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Results by File")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| File | Total | Passed | Failed | Skipped | Duration |")
[void]$sb.AppendLine("|------|-------|--------|--------|---------|----------|")
foreach ($fs in $fileStats) {
    [void]$sb.AppendLine("| $($fs.File) | $($fs.Total) | $($fs.Passed) | $($fs.Failed) | $($fs.Skipped) | $($fs.Duration)s |")
}

$markdown = $sb.ToString()

# Output the markdown to stdout
Write-Output $markdown

# Also write to GITHUB_STEP_SUMMARY if available
if ($env:GITHUB_STEP_SUMMARY -and (Test-Path (Split-Path $env:GITHUB_STEP_SUMMARY -Parent) -ErrorAction SilentlyContinue)) {
    $markdown | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}
