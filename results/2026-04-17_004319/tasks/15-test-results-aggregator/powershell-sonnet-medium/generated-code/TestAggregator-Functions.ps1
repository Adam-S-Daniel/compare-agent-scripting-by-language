# TestAggregator-Functions.ps1
# Pure functions for parsing, aggregating, and summarising test results.
# Dot-sourced by both Invoke-TestAggregator.ps1 and Pester tests.

function Parse-JUnitXml {
    <#
    .SYNOPSIS
    Parses a JUnit XML test result file and returns a flat list of test results.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "JUnit XML file not found: '$FilePath'"
    }

    [xml]$xml = Get-Content $FilePath -ErrorAction Stop

    # Support both <testsuites> (wrapper) and bare <testsuite> root elements
    $suites = if ($xml.testsuites) { $xml.testsuites.testsuite } else { $xml.testsuite }

    $results = @()
    foreach ($suite in $suites) {
        foreach ($tc in $suite.testcase) {
            # $tc.skipped returns "" (not $null) for <skipped/> empty elements;
            # a plain boolean check fails on "", so use explicit null comparison.
            $status = if ($tc.failure)              { 'failed'  }
                      elseif ($null -ne $tc.skipped) { 'skipped' }
                      else                           { 'passed'  }

            $results += [PSCustomObject]@{
                Name     = $tc.name
                Suite    = $suite.name
                Status   = $status
                Duration = [double]$tc.time
                Source   = $FilePath
                Message  = if ($tc.failure) { $tc.failure.message } else { $null }
            }
        }
    }
    return $results
}

function Parse-JsonResults {
    <#
    .SYNOPSIS
    Parses a JSON test result file and returns a flat list of test results.
    Expected schema: { "suite": "...", "tests": [ { "name","status","duration"[,"message"] } ] }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "JSON result file not found: '$FilePath'"
    }

    $data = Get-Content $FilePath -Raw -ErrorAction Stop | ConvertFrom-Json

    $results = @()
    foreach ($test in $data.tests) {
        $results += [PSCustomObject]@{
            Name     = $test.name
            Suite    = $data.suite
            Status   = $test.status
            Duration = [double]$test.duration
            Source   = $FilePath
            Message  = $test.message
        }
    }
    return $results
}

function Get-AllResults {
    <#
    .SYNOPSIS
    Walks a directory, parses every *.xml and *.json test result file found,
    and returns all results as a single flat collection.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ResultsPath
    )

    if (-not (Test-Path $ResultsPath)) {
        throw "Results path does not exist: '$ResultsPath'"
    }

    $all = @()

    Get-ChildItem -Path $ResultsPath -Filter '*.xml' -Recurse | ForEach-Object {
        try   { $all += Parse-JUnitXml -FilePath $_.FullName }
        catch { Write-Warning "Skipping XML file '$($_.FullName)': $_" }
    }

    Get-ChildItem -Path $ResultsPath -Filter '*.json' -Recurse | ForEach-Object {
        try   { $all += Parse-JsonResults -FilePath $_.FullName }
        catch { Write-Warning "Skipping JSON file '$($_.FullName)': $_" }
    }

    return $all
}

function Find-FlakyTests {
    <#
    .SYNOPSIS
    Identifies tests that had inconsistent outcomes (passed in some runs, failed
    in others) across the aggregated result set.  Skipped tests are ignored.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results
    )

    $flaky = @()
    $nonSkipped = $Results | Where-Object { $_.Status -ne 'skipped' }

    $grouped = $nonSkipped | Group-Object -Property Name
    foreach ($g in $grouped) {
        $statuses = $g.Group | Select-Object -ExpandProperty Status -Unique
        if ($statuses.Count -gt 1) {
            $flaky += [PSCustomObject]@{
                Name        = $g.Name
                PassedCount = ($g.Group | Where-Object { $_.Status -eq 'passed' }).Count
                FailedCount = ($g.Group | Where-Object { $_.Status -eq 'failed' }).Count
            }
        }
    }
    return $flaky
}

function New-MarkdownSummary {
    <#
    .SYNOPSIS
    Generates a GitHub-Actions-compatible markdown job summary from aggregated
    test results and the list of flaky tests.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Results,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$FlakyTests
    )

    $passed   = ($Results | Where-Object { $_.Status -eq 'passed'  }).Count
    $failed   = ($Results | Where-Object { $_.Status -eq 'failed'  }).Count
    $skipped  = ($Results | Where-Object { $_.Status -eq 'skipped' }).Count
    $total    = $Results.Count
    $duration = ($Results | Measure-Object -Property Duration -Sum).Sum

    $md  = "# Test Results Summary`n`n"
    $md += "## Overall Results`n`n"
    $md += "| Metric | Value |`n"
    $md += "|--------|-------|`n"
    $md += "| Total Tests | $total |`n"
    $md += "| Passed | $passed |`n"
    $md += "| Failed | $failed |`n"
    $md += "| Skipped | $skipped |`n"
    $md += "| Total Duration | $("{0:F2}" -f $duration)s |`n"
    $md += "`n"

    $md += "## Flaky Tests`n`n"
    if ($FlakyTests.Count -gt 0) {
        $md += "The following tests had inconsistent results across runs:`n`n"
        $md += "| Test Name | Passed | Failed |`n"
        $md += "|-----------|--------|--------|`n"
        foreach ($f in $FlakyTests | Sort-Object Name) {
            $md += "| $($f.Name) | $($f.PassedCount) | $($f.FailedCount) |`n"
        }
    } else {
        $md += "No flaky tests detected.`n"
    }

    return $md
}
