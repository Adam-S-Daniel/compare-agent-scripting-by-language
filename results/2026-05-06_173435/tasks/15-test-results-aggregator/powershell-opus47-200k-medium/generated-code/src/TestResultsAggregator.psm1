# TestResultsAggregator
# ----------------------
# Parses test result files in two formats (JUnit XML, JSON), aggregates them
# across runs (matrix-build style), classifies tests that flip between
# passed/failed as "flaky", and emits a GitHub-Actions-friendly markdown
# summary. Built test-first: every public function here is exercised by
# tests/TestResultsAggregator.Tests.ps1.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-JUnitTestResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JUnit file not found: $Path"
    }
    $resolved = (Resolve-Path -LiteralPath $Path).Path

    try {
        [xml]$doc = Get-Content -LiteralPath $resolved -Raw
    } catch {
        throw "Failed to parse JUnit XML '$resolved': $($_.Exception.Message)"
    }

    # JUnit allows either a top-level <testsuite> or a <testsuites> wrapper.
    $hasWrapper = $doc.DocumentElement -and $doc.DocumentElement.LocalName -eq 'testsuites'
    $suites = if ($hasWrapper) { @($doc.DocumentElement.testsuite) } else { @($doc.DocumentElement) }
    $tests    = New-Object System.Collections.Generic.List[object]
    $duration = 0.0
    $name     = $null

    foreach ($suite in $suites) {
        if (-not $suite) { continue }
        if (-not $name)  { $name = [string]$suite.GetAttribute('name') }
        $timeAttr = $suite.GetAttribute('time')
        if ($timeAttr) { $duration += [double]$timeAttr }

        foreach ($tc in @($suite.SelectNodes('testcase'))) {
            $status  = 'passed'
            $message = $null
            $failNode    = $tc.SelectSingleNode('failure')
            $errorNode   = $tc.SelectSingleNode('error')
            $skippedNode = $tc.SelectSingleNode('skipped')
            if ($failNode) {
                $status = 'failed'
                $message = $failNode.GetAttribute('message')
            } elseif ($errorNode) {
                $status = 'failed'
                $message = $errorNode.GetAttribute('message')
            } elseif ($skippedNode) {
                $status = 'skipped'
            }
            $tcTime = $tc.GetAttribute('time')
            $tests.Add([pscustomobject]@{
                ClassName = $tc.GetAttribute('classname')
                Name      = $tc.GetAttribute('name')
                Status    = $status
                Duration  = if ($tcTime) { [double]$tcTime } else { 0.0 }
                Message   = $message
            })
        }
    }

    [pscustomobject]@{
        Suite    = $name
        Source   = $resolved
        Duration = $duration
        Tests    = $tests.ToArray()
    }
}

function Read-JsonTestResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }
    $resolved = (Resolve-Path -LiteralPath $Path).Path

    try {
        $obj = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse JSON '$resolved': $($_.Exception.Message)"
    }

    $tests = foreach ($t in @($obj.tests)) {
        [pscustomobject]@{
            ClassName = [string]$t.classname
            Name      = [string]$t.name
            Status    = ([string]$t.status).ToLowerInvariant()
            Duration  = if ($t.PSObject.Properties['duration']) { [double]$t.duration } else { 0.0 }
            Message   = if ($t.PSObject.Properties['message'])  { [string]$t.message }  else { $null }
        }
    }

    [pscustomobject]@{
        Suite    = [string]$obj.suite
        Source   = $resolved
        Duration = if ($obj.PSObject.Properties['duration']) { [double]$obj.duration } else { 0.0 }
        Tests    = @($tests)
    }
}

function Get-TestResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { Read-JUnitTestResults -Path $Path }
        '.json' { Read-JsonTestResults  -Path $Path }
        default { throw "Unsupported file extension '$ext' for '$Path'. Use .xml (JUnit) or .json." }
    }
}

function Merge-TestResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Results)

    $passed = 0; $failed = 0; $skipped = 0; $duration = 0.0
    $byTest   = @{}   # FullName -> @{ Passed; Failed; Skipped; Runs; LastMessage; LastSource }
    $failures = New-Object System.Collections.Generic.List[object]

    function _Field($obj, $name) {
        if ($null -eq $obj) { return $null }
        if ($obj -is [hashtable]) { return $obj[$name] }
        $p = $obj.PSObject.Properties[$name]
        if ($p) { return $p.Value }
        return $null
    }

    foreach ($run in $Results) {
        $duration += [double](_Field $run 'Duration')
        $runSource = _Field $run 'Source'
        foreach ($t in @(_Field $run 'Tests')) {
            $tStatus  = _Field $t 'Status'
            $tMessage = _Field $t 'Message'
            switch ($tStatus) {
                'passed'  { $passed++ }
                'failed'  { $failed++ }
                'skipped' { $skipped++ }
            }
            $key = "$(_Field $t 'ClassName').$(_Field $t 'Name')"
            if (-not $byTest.ContainsKey($key)) {
                $byTest[$key] = @{
                    FullName = $key; Passed = 0; Failed = 0; Skipped = 0; Runs = 0
                    LastMessage = $null; LastSource = $null
                }
            }
            $entry = $byTest[$key]
            $entry['Runs'] = [int]$entry['Runs'] + 1
            switch ($tStatus) {
                'passed'  { $entry['Passed'] = [int]$entry['Passed'] + 1 }
                'failed'  {
                    $entry['Failed'] = [int]$entry['Failed'] + 1
                    $entry['LastMessage'] = $tMessage
                    $entry['LastSource']  = $runSource
                    $failures.Add([pscustomobject]@{
                        FullName = $key
                        Message  = $tMessage
                        Source   = $runSource
                    })
                }
                'skipped' { $entry['Skipped'] = [int]$entry['Skipped'] + 1 }
            }
        }
    }

    # Flaky = at least one pass AND at least one fail across all runs.
    $flakyList = New-Object System.Collections.Generic.List[object]
    foreach ($k in @($byTest.Keys)) {
        $e = $byTest[$k]
        if ([int]$e['Passed'] -gt 0 -and [int]$e['Failed'] -gt 0) {
            $flakyList.Add([pscustomobject]@{
                FullName    = $e['FullName']
                Passed      = $e['Passed']
                Failed      = $e['Failed']
                Runs        = $e['Runs']
                LastMessage = $e['LastMessage']
            })
        }
    }

    [pscustomobject]@{
        RunCount = @($Results).Count
        Totals   = [pscustomobject]@{
            Passed   = $passed
            Failed   = $failed
            Skipped  = $skipped
            Total    = $passed + $failed + $skipped
            Duration = [math]::Round($duration, 3)
        }
        Flaky    = $flakyList.ToArray()
        Failures = $failures.ToArray()
    }
}

function New-MarkdownSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Aggregate)

    $t = $Aggregate.Totals
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Test Results Summary')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Aggregated across **$($Aggregate.RunCount)** run(s).")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Metric | Value |')
    [void]$sb.AppendLine('| --- | --- |')
    [void]$sb.AppendLine("| Passed | $($t.Passed) |")
    [void]$sb.AppendLine("| Failed | $($t.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($t.Skipped) |")
    [void]$sb.AppendLine("| Total | $($t.Total) |")
    [void]$sb.AppendLine("| Duration (s) | $($t.Duration) |")
    [void]$sb.AppendLine()

    if ($t.Failed -eq 0 -and @($Aggregate.Flaky).Count -eq 0) {
        [void]$sb.AppendLine('All tests passed. :tada:')
    }

    if (@($Aggregate.Flaky).Count -gt 0) {
        [void]$sb.AppendLine('## Flaky Tests')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Test | Passed | Failed | Runs |')
        [void]$sb.AppendLine('| --- | ---: | ---: | ---: |')
        foreach ($f in $Aggregate.Flaky) {
            [void]$sb.AppendLine("| $($f.FullName) | $($f.Passed) | $($f.Failed) | $($f.Runs) |")
        }
        [void]$sb.AppendLine()
    }

    if (@($Aggregate.Failures).Count -gt 0) {
        [void]$sb.AppendLine('## Failures')
        [void]$sb.AppendLine()
        foreach ($f in $Aggregate.Failures) {
            $msg = if ($f.Message) { $f.Message } else { '(no message)' }
            [void]$sb.AppendLine("- **$($f.FullName)** — $msg")
        }
        [void]$sb.AppendLine()
    }

    $sb.ToString()
}

function Invoke-TestResultsAggregator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath
    )

    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Input path not found: $InputPath"
    }

    $files = if ((Get-Item -LiteralPath $InputPath).PSIsContainer) {
        Get-ChildItem -LiteralPath $InputPath -File -Recurse |
            Where-Object { $_.Extension -in '.xml', '.json' } |
            Sort-Object FullName
    } else {
        @(Get-Item -LiteralPath $InputPath)
    }

    if (-not $files -or @($files).Count -eq 0) {
        throw "No .xml or .json test result files found in '$InputPath'."
    }

    $results = foreach ($f in $files) { Get-TestResults -Path $f.FullName }
    $agg     = Merge-TestResults -Results @($results)
    $md      = New-MarkdownSummary -Aggregate $agg

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $md -Encoding UTF8

    $agg
}

Export-ModuleMember -Function `
    Read-JUnitTestResults, Read-JsonTestResults, Get-TestResults,
    Merge-TestResults, New-MarkdownSummary, Invoke-TestResultsAggregator
