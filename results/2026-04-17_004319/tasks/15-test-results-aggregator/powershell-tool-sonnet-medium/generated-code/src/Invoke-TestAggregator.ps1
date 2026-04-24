# TDD green phase: minimum implementation to pass all Pester tests.
# Supports JUnit XML and JSON result formats; identifies flaky tests;
# outputs a GitHub Actions-compatible markdown summary.

Set-StrictMode -Version Latest

function ConvertFrom-JUnitXml {
    <#
    .SYNOPSIS  Parse a JUnit XML file and return a run result object.
    #>
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $xml      = [xml](Get-Content -Path $Path -Raw -ErrorAction Stop)
    $runName  = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $tests    = [System.Collections.Generic.List[PSCustomObject]]::new()
    $duration = 0.0

    foreach ($suite in @($xml.testsuites.testsuite)) {
        $duration += [double]$suite.time

        foreach ($tc in @($suite.testcase)) {
            $status  = 'passed'
            $message = $null

            # Use SelectSingleNode to avoid PropertyNotFoundException in strict mode
            # when the child element is absent.
            $failureNode = $tc.SelectSingleNode('failure')
            $skippedNode = $tc.SelectSingleNode('skipped')

            if ($failureNode) {
                $status  = 'failed'
                $message = $failureNode.GetAttribute('message')
            } elseif ($skippedNode) {
                $status = 'skipped'
            }

            $tests.Add([PSCustomObject]@{
                Name     = $tc.name
                Suite    = $tc.classname
                Status   = $status
                Duration = [double]$tc.time
                Message  = $message
                Run      = $runName
                File     = $Path
            })
        }
    }

    [PSCustomObject]@{
        Run      = $runName
        Duration = $duration
        Tests    = $tests.ToArray()
    }
}

function ConvertFrom-JsonResults {
    <#
    .SYNOPSIS  Parse a JSON test-results file and return a run result object.
    #>
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $data    = Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json
    $runName = if ($data.run) { $data.run } else {
        [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }
    $tests   = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($t in $data.tests) {
        $tests.Add([PSCustomObject]@{
            Name     = $t.name
            Suite    = $t.suite
            Status   = $t.status
            Duration = [double]$t.duration
            Message  = if ($t.PSObject.Properties['message']) { $t.message } else { $null }
            Run      = $runName
            File     = $Path
        })
    }

    [PSCustomObject]@{
        Run      = $runName
        Duration = [double]$data.duration
        Tests    = $tests.ToArray()
    }
}

function Merge-TestResults {
    <#
    .SYNOPSIS  Aggregate an array of run-result objects into cumulative totals.
    #>
    param(
        [Parameter(Mandatory)][array]$RunResults
    )

    $all      = [System.Collections.Generic.List[PSCustomObject]]::new()
    $passed   = 0
    $failed   = 0
    $skipped  = 0
    $duration = 0.0

    foreach ($run in $RunResults) {
        $duration += $run.Duration
        foreach ($t in $run.Tests) {
            $all.Add($t)
            switch ($t.Status) {
                'passed'  { $passed++  }
                'failed'  { $failed++  }
                'skipped' { $skipped++ }
            }
        }
    }

    [PSCustomObject]@{
        TotalPassed   = $passed
        TotalFailed   = $failed
        TotalSkipped  = $skipped
        TotalDuration = [Math]::Round($duration, 1)
        Tests         = $all.ToArray()
    }
}

function Find-FlakyTests {
    <#
    .SYNOPSIS  Return names of tests that both passed and failed across runs.
               Skipped results are neutral and never trigger flaky classification.
    #>
    param(
        [Parameter(Mandatory)][array]$AllTests
    )

    $grouped = $AllTests | Group-Object -Property Name
    $flaky   = [System.Collections.Generic.List[string]]::new()

    foreach ($grp in $grouped) {
        $statuses   = $grp.Group.Status | Where-Object { $_ -ne 'skipped' }
        $hasPassed  = $statuses -contains 'passed'
        $hasFailed  = $statuses -contains 'failed'

        if ($hasPassed -and $hasFailed) {
            $flaky.Add($grp.Name)
        }
    }

    # Return sorted so output is deterministic
    $flaky | Sort-Object
}

function New-MarkdownSummary {
    <#
    .SYNOPSIS  Build a GitHub Actions job-summary markdown string.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Aggregated,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$FlakyTests
    )

    $total    = $Aggregated.TotalPassed + $Aggregated.TotalFailed + $Aggregated.TotalSkipped
    $passRate = if ($total -gt 0) {
        [Math]::Round(($Aggregated.TotalPassed / $total) * 100, 1)
    } else { 0 }

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("## Test Results Summary")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Metric | Value |")
    $null = $sb.AppendLine("|--------|-------|")
    $null = $sb.AppendLine("| Total Tests | $total |")
    $null = $sb.AppendLine("| Passed | $($Aggregated.TotalPassed) |")
    $null = $sb.AppendLine("| Failed | $($Aggregated.TotalFailed) |")
    $null = $sb.AppendLine("| Skipped | $($Aggregated.TotalSkipped) |")
    $null = $sb.AppendLine("| Pass Rate | $passRate% |")
    $null = $sb.AppendLine("| Total Duration | $($Aggregated.TotalDuration)s |")
    $null = $sb.AppendLine("")

    if ($FlakyTests.Count -gt 0) {
        $null = $sb.AppendLine("### Flaky Tests ($($FlakyTests.Count))")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("The following tests had inconsistent results across runs:")
        $null = $sb.AppendLine("")
        foreach ($t in $FlakyTests) {
            $null = $sb.AppendLine("- $t")
        }
        $null = $sb.AppendLine("")
    } else {
        $null = $sb.AppendLine("### No Flaky Tests Detected")
        $null = $sb.AppendLine("")
    }

    $sb.ToString()
}

function Invoke-TestAggregator {
    <#
    .SYNOPSIS  Parse, aggregate, and summarise test results from multiple files.
    .PARAMETER InputPaths  One or more .xml (JUnit) or .json result files.
    .PARAMETER OutputPath  Optional path to write the markdown summary file.
    #>
    param(
        [Parameter(Mandatory)][string[]]$InputPaths,
        [string]$OutputPath
    )

    $runResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($path in $InputPaths) {
        if (-not (Test-Path $path)) {
            Write-Error "File not found: $path"
            continue
        }

        $ext = [System.IO.Path]::GetExtension($path).ToLower()
        try {
            switch ($ext) {
                '.xml'  { $runResults.Add((ConvertFrom-JUnitXml    -Path $path)) }
                '.json' { $runResults.Add((ConvertFrom-JsonResults  -Path $path)) }
                default { Write-Warning "Unsupported format '$ext' — skipping: $path" }
            }
        } catch {
            Write-Error "Failed to parse '$path': $_"
        }
    }

    if ($runResults.Count -eq 0) {
        Write-Error "No valid test result files could be parsed."
        return
    }

    $aggregated  = Merge-TestResults  -RunResults $runResults.ToArray()
    $flakyTests  = Find-FlakyTests    -AllTests   $aggregated.Tests
    $markdown    = New-MarkdownSummary -Aggregated $aggregated -FlakyTests $flakyTests

    # Emit structured markers so the CI harness can assert exact values.
    Write-Host "AGGREGATED_PASSED=$($aggregated.TotalPassed)"
    Write-Host "AGGREGATED_FAILED=$($aggregated.TotalFailed)"
    Write-Host "AGGREGATED_SKIPPED=$($aggregated.TotalSkipped)"
    Write-Host "AGGREGATED_DURATION=$($aggregated.TotalDuration)"
    Write-Host "FLAKY_COUNT=$($flakyTests.Count)"
    if ($flakyTests.Count -gt 0) {
        Write-Host "FLAKY_TESTS=$($flakyTests -join ',')"
    }
    Write-Host ""
    Write-Host $markdown

    if ($OutputPath) {
        $markdown | Out-File -FilePath $OutputPath -Encoding UTF8 -NoNewline:$false
        Write-Host "Markdown written to: $OutputPath"
    }

    # Append to GitHub Actions step summary when the env var is available.
    if ($env:GITHUB_STEP_SUMMARY) {
        $markdown | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding UTF8 -Append
    }

    [PSCustomObject]@{
        Aggregated = $aggregated
        FlakyTests = $flakyTests
        Markdown   = $markdown
    }
}
