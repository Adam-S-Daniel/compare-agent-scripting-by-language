# Invoke-TestResultsAggregator.ps1
#
# Parses JUnit XML and JSON test result files, aggregates results across
# multiple files (matrix build simulation), identifies flaky tests, and
# generates a GitHub Actions-compatible markdown summary.
#
# TDD APPROACH: Each function was implemented AFTER a failing Pester test.
# See TestResultsAggregator.Tests.ps1 for the test-first sequence.

#region ── TDD Iteration 1: Parse JUnit XML ──────────────────────────────────

function Parse-JUnitXml {
    <#
    .SYNOPSIS
        Parses a JUnit-format XML file and returns structured test result data.
    .PARAMETER Path
        Path to the JUnit XML file (.xml).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    try {
        [xml]$xml = Get-Content -Path $Path -Raw -Encoding UTF8
    } catch {
        throw "Failed to parse XML file '$Path': $_"
    }

    # Support both <testsuites><testsuite> and bare <testsuite> root elements
    $suites = if ($xml.testsuites -and $xml.testsuites.testsuite) {
        @($xml.testsuites.testsuite)
    } elseif ($xml.testsuite) {
        @($xml.testsuite)
    } else {
        throw "Invalid JUnit XML: expected <testsuites> or <testsuite> root element in '$Path'"
    }

    $tests        = [System.Collections.Generic.List[hashtable]]::new()
    $totalPassed  = 0
    $totalFailed  = 0
    $totalSkipped = 0
    $totalDuration = 0.0

    foreach ($suite in $suites) {
        $suiteName = $suite.name
        foreach ($tc in @($suite.testcase)) {
            if ($null -eq $tc) { continue }

            # Determine status: failure/error -> failed; skipped -> skipped; else passed
            # NOTE: <skipped/> is an EMPTY element, so $tc.skipped returns "" (falsy).
            # We must test for $null (absent) rather than truthiness.
            $status = if ($null -ne $tc.failure -or $null -ne $tc.error) { 'failed' }
                      elseif ($null -ne $tc.skipped)                      { 'skipped' }
                      else                                                 { 'passed' }

            $duration = [double]($tc.time -replace ',', '.' -replace '[^0-9\.]', '0')

            $tests.Add(@{
                Name     = $tc.name
                Suite    = $suiteName
                Status   = $status
                Duration = $duration
            })

            switch ($status) {
                'passed'  { $totalPassed++ }
                'failed'  { $totalFailed++ }
                'skipped' { $totalSkipped++ }
            }
            $totalDuration += $duration
        }
    }

    return @{
        Tests    = $tests.ToArray()
        Passed   = $totalPassed
        Failed   = $totalFailed
        Skipped  = $totalSkipped
        Total    = $tests.Count
        Duration = [Math]::Round($totalDuration, 3)
        Source   = $Path
    }
}

#endregion

#region ── TDD Iteration 2: Parse JSON results ───────────────────────────────

function Parse-JsonResults {
    <#
    .SYNOPSIS
        Parses a JSON test results file and returns structured test result data.
    .DESCRIPTION
        Expected JSON schema:
          { "suites": [ { "name": "...", "tests": [ { "name": "...", "status": "passed|failed|skipped", "duration": 0.5 } ] } ] }
    .PARAMETER Path
        Path to the JSON file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    try {
        $json = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "Failed to parse JSON file '$Path': $_"
    }

    # Support { suites: [...] } or a bare suite object at the root
    $suites = if ($null -ne $json.suites) { @($json.suites) } else { @($json) }

    $tests        = [System.Collections.Generic.List[hashtable]]::new()
    $totalPassed  = 0
    $totalFailed  = 0
    $totalSkipped = 0
    $totalDuration = 0.0

    foreach ($suite in $suites) {
        $suiteName = if ($suite.name) { $suite.name } else { 'Unknown' }
        foreach ($tc in @($suite.tests)) {
            if ($null -eq $tc) { continue }

            $status   = if ($tc.status) { $tc.status.ToLower() } else { 'unknown' }
            $duration = [double]($tc.duration ?? 0)

            $tests.Add(@{
                Name     = $tc.name
                Suite    = $suiteName
                Status   = $status
                Duration = $duration
            })

            switch ($status) {
                'passed'  { $totalPassed++ }
                'failed'  { $totalFailed++ }
                'skipped' { $totalSkipped++ }
            }
            $totalDuration += $duration
        }
    }

    return @{
        Tests    = $tests.ToArray()
        Passed   = $totalPassed
        Failed   = $totalFailed
        Skipped  = $totalSkipped
        Total    = $tests.Count
        Duration = [Math]::Round($totalDuration, 3)
        Source   = $Path
    }
}

#endregion

#region ── TDD Iteration 3: Format dispatcher ────────────────────────────────

function Parse-TestResultFile {
    <#
    .SYNOPSIS
        Parses a test result file, delegating to the appropriate parser by extension.
    .PARAMETER Path
        Path to a .xml (JUnit) or .json (custom) test result file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    switch ($ext) {
        '.xml'  { return Parse-JUnitXml      -Path $Path }
        '.json' { return Parse-JsonResults   -Path $Path }
        default { throw "Unsupported file format '$ext'. Supported: .xml, .json" }
    }
}

#endregion

#region ── TDD Iteration 4: Aggregate results ────────────────────────────────

function Aggregate-TestResults {
    <#
    .SYNOPSIS
        Aggregates an array of parsed result objects into a single summary.
    .PARAMETER Results
        Array of result hashtables as returned by Parse-JUnitXml / Parse-JsonResults.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results
    )

    $totalPassed   = 0
    $totalFailed   = 0
    $totalSkipped  = 0
    $totalDuration = 0.0
    $allTests      = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($result in $Results) {
        $totalPassed   += $result.Passed
        $totalFailed   += $result.Failed
        $totalSkipped  += $result.Skipped
        $totalDuration += $result.Duration
        foreach ($t in $result.Tests) { $allTests.Add($t) }
    }

    return @{
        Passed   = $totalPassed
        Failed   = $totalFailed
        Skipped  = $totalSkipped
        Total    = $totalPassed + $totalFailed + $totalSkipped
        Duration = [Math]::Round($totalDuration, 3)
        Tests    = $allTests.ToArray()
    }
}

#endregion

#region ── TDD Iteration 5: Flaky test detection ─────────────────────────────

function Find-FlakyTests {
    <#
    .SYNOPSIS
        Identifies tests that both passed and failed across multiple result files.
    .DESCRIPTION
        A test is considered flaky when it appears in multiple runs and has at
        least one pass AND at least one failure.
    .PARAMETER Results
        Array of result hashtables (same format as Aggregate-TestResults input).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results
    )

    # Accumulate pass/fail counts per test name across all result files
    $byName = @{}
    foreach ($result in $Results) {
        foreach ($test in $result.Tests) {
            $name = $test.Name
            if (-not $byName.ContainsKey($name)) {
                $byName[$name] = @{ Passed = 0; Failed = 0; Total = 0 }
            }
            $byName[$name].Total++
            if ($test.Status -eq 'passed') { $byName[$name].Passed++ }
            elseif ($test.Status -eq 'failed') { $byName[$name].Failed++ }
        }
    }

    # A test is flaky if it has both passes and failures.
    # Use a List to guarantee a non-null return even when nothing qualifies.
    $flakyList = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($name in $byName.Keys) {
        $d = $byName[$name]
        if ($d.Passed -gt 0 -and $d.Failed -gt 0) {
            $passRate = [int][Math]::Round(($d.Passed / $d.Total) * 100)
            $flakyList.Add([pscustomobject]@{
                Name     = $name
                Passed   = $d.Passed
                Failed   = $d.Failed
                Total    = $d.Total
                PassRate = $passRate
            })
        }
    }

    # Sort by pass rate ascending (least reliable first); always return an array
    return @($flakyList | Sort-Object PassRate)
}

#endregion

#region ── TDD Iteration 6: Markdown summary generation ──────────────────────

function New-MarkdownSummary {
    <#
    .SYNOPSIS
        Generates a GitHub Actions job-summary-compatible markdown report.
    .PARAMETER Aggregated
        Hashtable from Aggregate-TestResults.
    .PARAMETER FlakyTests
        Array from Find-FlakyTests.
    .PARAMETER Results
        Raw result array (for per-file breakdown table).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Aggregated,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$FlakyTests,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results
    )

    $sb = [System.Text.StringBuilder]::new()

    # ── Header ───────────────────────────────────────────────────────────────
    $null = $sb.AppendLine('# Test Results Summary')
    $null = $sb.AppendLine()

    # ── Overview table ───────────────────────────────────────────────────────
    $null = $sb.AppendLine('## Overview')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('| Metric | Count |')
    $null = $sb.AppendLine('|--------|-------|')
    $null = $sb.AppendLine("| Total Tests | $($Aggregated.Total) |")
    $null = $sb.AppendLine("| Passed | $($Aggregated.Passed) |")
    $null = $sb.AppendLine("| Failed | $($Aggregated.Failed) |")
    $null = $sb.AppendLine("| Skipped | $($Aggregated.Skipped) |")
    $null = $sb.AppendLine("| Duration | $($Aggregated.Duration)s |")
    $null = $sb.AppendLine()

    # ── Status badge ─────────────────────────────────────────────────────────
    $statusText = if ($Aggregated.Failed -eq 0) { 'PASSED' } else { 'FAILED' }
    $null = $sb.AppendLine("**Status: $statusText**")
    $null = $sb.AppendLine()

    # ── Flaky tests ──────────────────────────────────────────────────────────
    if ($FlakyTests.Count -gt 0) {
        $null = $sb.AppendLine('## Flaky Tests')
        $null = $sb.AppendLine()
        $null = $sb.AppendLine('| Test | Pass Rate | Passed Runs | Failed Runs |')
        $null = $sb.AppendLine('|------|-----------|-------------|-------------|')
        foreach ($f in $FlakyTests) {
            $null = $sb.AppendLine("| $($f.Name) | $($f.PassRate)% | $($f.Passed) | $($f.Failed) |")
        }
        $null = $sb.AppendLine()
    }

    # ── Per-file breakdown ───────────────────────────────────────────────────
    if ($Results.Count -gt 0) {
        $null = $sb.AppendLine('## Files Processed')
        $null = $sb.AppendLine()
        $null = $sb.AppendLine('| File | Passed | Failed | Skipped | Duration |')
        $null = $sb.AppendLine('|------|--------|--------|---------|----------|')
        foreach ($r in $Results) {
            $filename = [System.IO.Path]::GetFileName($r.Source)
            $null = $sb.AppendLine("| $filename | $($r.Passed) | $($r.Failed) | $($r.Skipped) | $($r.Duration)s |")
        }
        $null = $sb.AppendLine()
    }

    return $sb.ToString()
}

#endregion

#region ── TDD Iteration 7: Main orchestrator ────────────────────────────────

function Invoke-TestResultsAggregator {
    <#
    .SYNOPSIS
        Main entry point. Finds, parses, aggregates test result files and
        outputs a markdown summary to stdout (and GITHUB_STEP_SUMMARY when set).
    .PARAMETER Path
        Directory containing .xml and/or .json test result files (searched recursively).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Path not found: $Path"
    }

    # Discover all supported test result files
    $files = @(Get-ChildItem -Path $Path -Include '*.xml', '*.json' -Recurse -File)

    if ($files.Count -eq 0) {
        throw "No test result files (*.xml, *.json) found in: $Path"
    }

    Write-Host "Found $($files.Count) test result file(s) in '$Path'"

    # Parse each file; skip with a warning on parse errors
    $results = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($file in $files) {
        Write-Host "  Parsing: $($file.Name)"
        try {
            $results.Add((Parse-TestResultFile -Path $file.FullName))
        } catch {
            Write-Warning "Failed to parse '$($file.Name)': $_"
        }
    }

    if ($results.Count -eq 0) {
        throw "All files failed to parse — no results to aggregate"
    }

    $resultArray = $results.ToArray()

    # Aggregate totals
    $aggregated = Aggregate-TestResults -Results $resultArray

    # Identify flaky tests – coerce to array so FlakyTests parameter is never null
    $flakyTests = @(Find-FlakyTests -Results $resultArray)

    # Build markdown
    $markdown = New-MarkdownSummary -Aggregated $aggregated -FlakyTests $flakyTests -Results $resultArray

    # Output to console (captured by act / CI log)
    Write-Host $markdown

    # Write to GITHUB_STEP_SUMMARY when running in a real GHA runner or act
    if ($env:GITHUB_STEP_SUMMARY) {
        $markdown | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
        Write-Host '(Summary appended to GITHUB_STEP_SUMMARY)'
    }

    return @{
        Results    = $resultArray
        Aggregated = $aggregated
        FlakyTests = $flakyTests
        Markdown   = $markdown
    }
}

#endregion
