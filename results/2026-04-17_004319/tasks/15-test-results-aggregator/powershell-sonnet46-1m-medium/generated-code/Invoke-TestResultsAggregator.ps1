# Invoke-TestResultsAggregator.ps1
# Aggregates JUnit XML and JSON test results from a matrix build directory,
# computes totals (passed/failed/skipped/duration), identifies flaky tests
# (passed in some runs, failed in others), and emits a Markdown summary.
#
# Usage:
#   ./Invoke-TestResultsAggregator.ps1 -InputPath ./fixtures

[CmdletBinding()]
param(
    # Directory containing .xml (JUnit) and/or .json test result files.
    [string]$InputPath = ""
)

# ── Parsers ───────────────────────────────────────────────────────────────────

function Read-JUnitXml {
    <#
    .SYNOPSIS Returns an array of hashtables, one per test case in the XML file.
    #>
    param([string]$FilePath)

    [xml]$xml = Get-Content -Path $FilePath -Raw
    $runId    = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $results  = [System.Collections.Generic.List[hashtable]]::new()

    # Support both <testsuite> root and <testsuites><testsuite> wrapper
    $suites = if ($xml.testsuites) { $xml.testsuites.testsuite }
              elseif ($xml.testsuite) { @($xml.testsuite) }
              else { @() }

    foreach ($suite in $suites) {
        foreach ($tc in $suite.testcase) {
            # $tc.skipped is "" (empty string, falsy) when <skipped/> exists — use $null check
            $status = if ($tc.failure -or $tc.error) { "failed" }
                      elseif ($null -ne $tc.skipped) { "skipped" }
                      else { "passed" }

            $results.Add(@{
                RunId     = $runId
                TestName  = $tc.name
                ClassName = $tc.classname
                Status    = $status
                Duration  = [double]$(if ($tc.time) { $tc.time } else { 0 })
            })
        }
    }

    return $results.ToArray()
}

function Read-JsonResults {
    <#
    .SYNOPSIS Returns an array of hashtables from a JSON results file.
    Expected shape: { "tests": [ { "name", "classname", "status", "duration" } ] }
    #>
    param([string]$FilePath)

    $data    = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
    $runId   = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $results = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($t in $data.tests) {
        $results.Add(@{
            RunId     = $runId
            TestName  = $t.name
            ClassName = $t.classname
            Status    = $t.status
            Duration  = [double]$(if ($null -ne $t.duration) { $t.duration } else { 0 })
        })
    }

    return $results.ToArray()
}

# ── Aggregation ───────────────────────────────────────────────────────────────

function Invoke-AggregateResults {
    param([object[]]$AllResults)

    $passed   = @($AllResults | Where-Object { $_.Status -eq "passed"  }).Count
    $failed   = @($AllResults | Where-Object { $_.Status -eq "failed"  }).Count
    $skipped  = @($AllResults | Where-Object { $_.Status -eq "skipped" }).Count
    $duration = ($AllResults | Measure-Object -Property Duration -Sum).Sum

    return @{
        TotalPassed   = $passed
        TotalFailed   = $failed
        TotalSkipped  = $skipped
        TotalDuration = [math]::Round($duration, 2)
    }
}

function Find-FlakyTests {
    <#
    .SYNOPSIS Returns sorted list of test names that have BOTH passed and failed
               across different runs — the hallmark of a flaky test.
    #>
    param([object[]]$AllResults)

    $flaky = [System.Collections.Generic.List[string]]::new()

    $AllResults | Group-Object -Property TestName | ForEach-Object {
        $statuses = $_.Group | Select-Object -ExpandProperty Status | Sort-Object -Unique
        if (($statuses -contains "passed") -and ($statuses -contains "failed")) {
            $flaky.Add($_.Name)
        }
    }

    return @($flaky | Sort-Object)
}

# ── Markdown generation ───────────────────────────────────────────────────────

function Format-MarkdownSummary {
    param(
        [hashtable]$Aggregate,
        [string[]]$FlakyTests,
        [int]$FileCount
    )

    $lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add("# Test Results Summary")
    $lines.Add("")
    $lines.Add("## Totals")
    $lines.Add("")
    $lines.Add("| Metric | Value |")
    $lines.Add("|--------|-------|")
    $lines.Add("| Files Processed | $FileCount |")
    $lines.Add("| :white_check_mark: Passed | $($Aggregate.TotalPassed) |")
    $lines.Add("| :x: Failed | $($Aggregate.TotalFailed) |")
    $lines.Add("| :zzz: Skipped | $($Aggregate.TotalSkipped) |")
    $lines.Add("| Duration (s) | $($Aggregate.TotalDuration) |")
    $lines.Add("")

    $lines.Add("## Flaky Tests")
    $lines.Add("")
    if ($FlakyTests -and $FlakyTests.Count -gt 0) {
        $lines.Add("The following tests **passed in some runs and failed in others**:")
        $lines.Add("")
        foreach ($name in $FlakyTests) {
            $lines.Add("- $name")
        }
    } else {
        $lines.Add("No flaky tests detected. :tada:")
    }
    $lines.Add("")

    return $lines -join "`n"
}

# ── Main execution (skipped when dot-sourced for unit testing) ────────────────

if ($MyInvocation.InvocationName -ne '.') {

    if (-not $InputPath) {
        Write-Error "Parameter -InputPath is required."
        exit 1
    }
    if (-not (Test-Path -Path $InputPath -PathType Container)) {
        Write-Error "InputPath '$InputPath' does not exist or is not a directory."
        exit 1
    }

    $files = @(Get-ChildItem -Path $InputPath -File |
               Where-Object { $_.Extension -in '.xml', '.json' } |
               Sort-Object Name)

    if ($files.Count -eq 0) {
        Write-Error "No .xml or .json test result files found in '$InputPath'."
        exit 1
    }

    $allResults = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($file in $files) {
        try {
            $parsed = if ($file.Extension -eq '.xml') {
                Read-JUnitXml -FilePath $file.FullName
            } else {
                Read-JsonResults -FilePath $file.FullName
            }
            foreach ($r in $parsed) { $allResults.Add($r) }
        } catch {
            Write-Warning "Skipping $($file.Name): $_"
        }
    }

    $aggregate  = Invoke-AggregateResults -AllResults $allResults.ToArray()
    $flakyTests = Find-FlakyTests         -AllResults $allResults.ToArray()
    $markdown   = Format-MarkdownSummary  -Aggregate $aggregate `
                                           -FlakyTests $flakyTests `
                                           -FileCount $files.Count

    # Human-readable Markdown to stdout (also captured by act logs)
    Write-Output $markdown

    # Machine-readable sentinel lines — asserted by Pester test harness
    Write-Output "AGGREGATE: Passed=$($aggregate.TotalPassed) Failed=$($aggregate.TotalFailed) Skipped=$($aggregate.TotalSkipped) Duration=$($aggregate.TotalDuration)"
    if ($flakyTests.Count -gt 0) {
        Write-Output "FLAKY: $($flakyTests -join ' ')"
    } else {
        Write-Output "FLAKY: none"
    }

    # Write to GitHub Actions step summary when running in a workflow
    if ($env:GITHUB_STEP_SUMMARY) {
        $markdown | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
    }
}
