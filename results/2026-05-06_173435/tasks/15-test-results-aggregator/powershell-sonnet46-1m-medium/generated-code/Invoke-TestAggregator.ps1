<#
.SYNOPSIS
    Aggregates test results from JUnit XML and JSON files across a matrix build.
    Identifies flaky tests and generates a markdown summary for GitHub Actions.

.DESCRIPTION
    Supports JUnit XML (standard CI format) and a simple JSON format.
    Flaky tests are those that passed in at least one run and failed in at least one other.

.PARAMETER InputPaths
    One or more file paths or directories to scan for test result files.
    Directories are searched for *.xml and *.json files.

.PARAMETER OutputFile
    Optional path to write the markdown summary. If omitted, writes to stdout.

.EXAMPLE
    ./Invoke-TestAggregator.ps1 -InputPaths fixtures
    ./Invoke-TestAggregator.ps1 -InputPaths run1.xml,run2.xml,run3.json
#>
param(
    [string[]]$InputPaths = @("fixtures"),
    [string]$OutputFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

function New-TestResult {
    param(
        [string]$Name,
        [string]$Suite,
        [ValidateSet("passed","failed","skipped")]
        [string]$Status,
        [double]$Duration,
        [string]$Source,
        [string]$ErrorMessage = ""
    )
    [PSCustomObject]@{
        Name         = $Name
        Suite        = $Suite
        Status       = $Status
        Duration     = $Duration
        Source       = $Source
        ErrorMessage = $ErrorMessage
    }
}

# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

function Invoke-ParseJUnitXml {
    <# Parse a JUnit XML file (supports both <testsuite> and <testsuites> roots). #>
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return @()
    }

    $results = [System.Collections.Generic.List[PSObject]]::new()

    try {
        [xml]$xml = Get-Content $FilePath -Raw -Encoding UTF8
    }
    catch {
        Write-Error "Failed to parse XML file '$FilePath': $_"
        return @()
    }

    # Handle both <testsuites><testsuite> and bare <testsuite> root elements
    $suites = if ($xml.testsuites) { $xml.testsuites.testsuite } else { $xml.testsuite }

    foreach ($suite in $suites) {
        $suiteName = $suite.name
        foreach ($tc in $suite.testcase) {
            $status = "passed"
            $errorMsg = ""

            # Use SelectSingleNode to safely check for child elements under StrictMode
            $failureNode = $tc.SelectSingleNode("failure")
            $errorNode   = $tc.SelectSingleNode("error")
            $skippedNode = $tc.SelectSingleNode("skipped")

            if ($null -ne $failureNode) {
                $status = "failed"
                $attr = $failureNode.GetAttribute("message")
                $errorMsg = if ($attr) { $attr } else { "test failed" }
            }
            elseif ($null -ne $errorNode) {
                $status = "failed"
                $attr = $errorNode.GetAttribute("message")
                $errorMsg = if ($attr) { $attr } else { "test error" }
            }
            elseif ($null -ne $skippedNode) {
                $status = "skipped"
            }

            $duration = 0.0
            if ($tc.time) {
                [double]::TryParse($tc.time, [System.Globalization.NumberStyles]::Float,
                    [System.Globalization.CultureInfo]::InvariantCulture, [ref]$duration) | Out-Null
            }

            $results.Add((New-TestResult -Name $tc.name -Suite $suiteName -Status $status `
                -Duration $duration -Source $FilePath -ErrorMessage $errorMsg))
        }
    }

    return $results.ToArray()
}

function Invoke-ParseJsonResults {
    <# Parse a JSON test result file with a "results" array. #>
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return @()
    }

    try {
        $json = Get-Content $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to parse JSON file '$FilePath': $_"
        return @()
    }

    if (-not $json.results) {
        Write-Warning "JSON file '$FilePath' has no 'results' array — skipping."
        return @()
    }

    $results = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($item in $json.results) {
        $status = ($item.status ?? "failed").ToString().ToLower()
        if ($status -notin @("passed","failed","skipped")) {
            Write-Warning "Unknown status '$status' for test '$($item.name)' — treating as failed."
            $status = "failed"
        }

        $duration = 0.0
        if ($null -ne $item.duration) { $duration = [double]$item.duration }

        $suite = if ($item.suite) { $item.suite } else { "Unknown" }

        $results.Add((New-TestResult -Name $item.name -Suite $suite -Status $status `
            -Duration $duration -Source $FilePath))
    }

    return $results.ToArray()
}

function Invoke-ParseTestFile {
    <# Dispatch to the right parser based on file extension. #>
    param([string]$FilePath)

    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    switch ($ext) {
        ".xml"  { return Invoke-ParseJUnitXml    -FilePath $FilePath }
        ".json" { return Invoke-ParseJsonResults -FilePath $FilePath }
        default {
            Write-Warning "Unsupported file format '$ext' for '$FilePath' — skipping."
            return @()
        }
    }
}

# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

function Find-FlakyTests {
    <# Return names of tests that passed in some runs and failed in others. #>
    param([object[]]$AllResults)

    # Group by test name and collect the distinct statuses seen
    $byName = @{}
    foreach ($r in $AllResults) {
        if (-not $byName.ContainsKey($r.Name)) { $byName[$r.Name] = [System.Collections.Generic.HashSet[string]]::new() }
        [void]$byName[$r.Name].Add($r.Status)
    }

    $flaky = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $byName.Keys) {
        $statuses = $byName[$name]
        if ($statuses.Contains("passed") -and $statuses.Contains("failed")) {
            $flaky.Add($name)
        }
    }

    return ($flaky | Sort-Object)
}

function Invoke-AggregateResults {
    <# Compute summary statistics across all test results. #>
    param([object[]]$AllResults)

    $passed  = ($AllResults | Where-Object Status -eq "passed").Count
    $failed  = ($AllResults | Where-Object Status -eq "failed").Count
    $skipped = ($AllResults | Where-Object Status -eq "skipped").Count
    $duration = if ($AllResults.Count -gt 0) {
        ($AllResults | Measure-Object Duration -Sum).Sum
    } else { 0.0 }
    $flaky = Find-FlakyTests -AllResults $AllResults

    [PSCustomObject]@{
        TotalPassed   = $passed
        TotalFailed   = $failed
        TotalSkipped  = $skipped
        TotalDuration = [Math]::Round($duration, 2)
        FlakyTests    = @($flaky)
        AllResults    = $AllResults
    }
}

# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------

function ConvertTo-MarkdownSummary {
    <# Generate a GitHub-flavored markdown summary of aggregated results. #>
    param([PSCustomObject]$Aggregate)

    $total    = $Aggregate.TotalPassed + $Aggregate.TotalFailed + $Aggregate.TotalSkipped
    $passRate = if ($total -gt 0) { [Math]::Round(100.0 * $Aggregate.TotalPassed / $total, 1) } else { 0 }
    $statusEmoji = if ($Aggregate.TotalFailed -eq 0) { "PASS" } else { "FAIL" }

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("# Test Results Summary")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**Status:** $statusEmoji")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Overall Results")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Metric | Value |")
    [void]$sb.AppendLine("|--------|-------|")
    [void]$sb.AppendLine("| Total Tests | $total |")
    [void]$sb.AppendLine("| Passed | $($Aggregate.TotalPassed) |")
    [void]$sb.AppendLine("| Failed | $($Aggregate.TotalFailed) |")
    [void]$sb.AppendLine("| Skipped | $($Aggregate.TotalSkipped) |")
    [void]$sb.AppendLine("| Pass Rate | $passRate% |")
    [void]$sb.AppendLine("| Duration | $($Aggregate.TotalDuration)s |")
    [void]$sb.AppendLine("")

    if ($Aggregate.FlakyTests.Count -gt 0) {
        [void]$sb.AppendLine("## Flaky Tests")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("The following tests passed in some runs and failed in others:")
        [void]$sb.AppendLine("")
        foreach ($name in $Aggregate.FlakyTests) {
            [void]$sb.AppendLine("- $name")
        }
        [void]$sb.AppendLine("")
    }

    if ($Aggregate.TotalFailed -gt 0) {
        [void]$sb.AppendLine("## Failed Tests")
        [void]$sb.AppendLine("")
        $failures = $Aggregate.AllResults | Where-Object Status -eq "failed"
        foreach ($f in $failures) {
            $line = "- **$($f.Name)** (suite: $($f.Suite))"
            if ($f.ErrorMessage) { $line += ": $($f.ErrorMessage)" }
            [void]$sb.AppendLine($line)
        }
        [void]$sb.AppendLine("")
    }

    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# Main execution
# ---------------------------------------------------------------------------

# Collect all files to process
$allFiles = [System.Collections.Generic.List[string]]::new()

foreach ($path in $InputPaths) {
    if (Test-Path $path -PathType Container) {
        Get-ChildItem $path -File | Where-Object { $_.Extension -in @(".xml",".json") } |
            Sort-Object Name | ForEach-Object { $allFiles.Add($_.FullName) }
    }
    elseif (Test-Path $path -PathType Leaf) {
        $allFiles.Add((Resolve-Path $path).Path)
    }
    else {
        Write-Warning "Path not found or not accessible: $path"
    }
}

if ($allFiles.Count -eq 0) {
    Write-Error "No test result files (*.xml, *.json) found in: $($InputPaths -join ', ')"
    exit 1
}

Write-Output "Processing $($allFiles.Count) file(s)..."

$allResults = [System.Collections.Generic.List[PSObject]]::new()
foreach ($file in $allFiles) {
    Write-Output "  Parsing: $file"
    $parsed = Invoke-ParseTestFile -FilePath $file
    foreach ($r in $parsed) { $allResults.Add($r) }
}

$aggregate = Invoke-AggregateResults -AllResults $allResults.ToArray()

# Output key metrics as parseable lines (used by the act test harness for assertions)
Write-Output "AGGREGATE_PASSED=$($aggregate.TotalPassed)"
Write-Output "AGGREGATE_FAILED=$($aggregate.TotalFailed)"
Write-Output "AGGREGATE_SKIPPED=$($aggregate.TotalSkipped)"
Write-Output "AGGREGATE_DURATION=$($aggregate.TotalDuration)"
Write-Output "AGGREGATE_TOTAL=$($aggregate.TotalPassed + $aggregate.TotalFailed + $aggregate.TotalSkipped)"

if ($aggregate.FlakyTests.Count -gt 0) {
    Write-Output "FLAKY_TESTS=$($aggregate.FlakyTests -join ',')"
}
else {
    Write-Output "FLAKY_TESTS=none"
}

# Generate markdown summary
$markdown = ConvertTo-MarkdownSummary -Aggregate $aggregate

# Write to GitHub Step Summary when running in Actions
if ($env:GITHUB_STEP_SUMMARY) {
    $markdown | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    Write-Output "Markdown summary written to GitHub Step Summary."
}

if ($OutputFile) {
    $markdown | Out-File -FilePath $OutputFile -Encoding utf8
    Write-Output "Summary written to: $OutputFile"
}
else {
    Write-Output ""
    Write-Output "--- MARKDOWN SUMMARY ---"
    Write-Output $markdown
    Write-Output "--- END SUMMARY ---"
}
