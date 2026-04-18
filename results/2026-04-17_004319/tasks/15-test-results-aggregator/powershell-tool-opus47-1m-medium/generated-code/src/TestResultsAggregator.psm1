# TestResultsAggregator.psm1
# Parses JUnit XML and JSON (Jest-style) test reports, aggregates them across
# multiple runs, detects flaky tests, and renders a GitHub-Actions markdown
# summary. Everything is written as idempotent pure functions so the module
# can be unit-tested with Pester.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-TestResult {
    # Helper: normalized shape used across parsers. Centralizing the schema
    # keeps aggregation/reporting oblivious to the source format.
    param(
        [string]$Name,
        [string]$ClassName,
        [ValidateSet('passed', 'failed', 'skipped')][string]$Status,
        [double]$Duration,
        [string]$Message,
        [string]$SourceFile
    )
    [pscustomobject]@{
        Name       = $Name
        ClassName  = $ClassName
        Status     = $Status
        Duration   = [double]$Duration
        Message    = $Message
        SourceFile = $SourceFile
    }
}

function Import-JUnitResults {
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

    # Support both <testsuites><testsuite> and bare <testsuite> roots.
    $suites = @()
    if ($doc.testsuites) { $suites = @($doc.testsuites.testsuite) }
    elseif ($doc.testsuite) { $suites = @($doc.testsuite) }
    else { throw "Invalid JUnit XML (no <testsuite> element): $resolved" }

    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($suite in $suites) {
        if (-not $suite) { continue }
        foreach ($case in @($suite.testcase)) {
            if (-not $case) { continue }
            $status = 'passed'
            $msg = ''
            $props = $case.PSObject.Properties.Name
            if ($props -contains 'failure')      { $status = 'failed';  $msg = [string]$case.failure.message }
            elseif ($props -contains 'error')    { $status = 'failed';  $msg = [string]$case.error.message }
            elseif ($props -contains 'skipped')  { $status = 'skipped'; $msg = [string]$case.skipped.message }

            $durRaw = if ($props -contains 'time') { $case.time } else { '0' }
            $dur = 0.0
            [void][double]::TryParse($durRaw, [ref]$dur)

            $out.Add((New-TestResult `
                -Name $case.name `
                -ClassName $case.classname `
                -Status $status `
                -Duration $dur `
                -Message $msg `
                -SourceFile $resolved))
        }
    }
    , $out.ToArray()
}

function Import-JsonResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }
    $resolved = (Resolve-Path -LiteralPath $Path).Path

    try {
        $doc = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json -Depth 20
    } catch {
        throw "Failed to parse JSON '$resolved': $($_.Exception.Message)"
    }

    $out = [System.Collections.Generic.List[object]]::new()

    # Jest-like shape: testResults[].assertionResults[]
    if ($doc.PSObject.Properties.Name -contains 'testResults') {
        foreach ($suite in @($doc.testResults)) {
            foreach ($t in @($suite.assertionResults)) {
                $raw = [string]$t.status
                $status = switch ($raw) {
                    'passed'  { 'passed' }
                    'failed'  { 'failed' }
                    'pending' { 'skipped' }
                    'skipped' { 'skipped' }
                    default   { 'passed' }
                }
                # Jest reports duration in milliseconds; normalize to seconds.
                $durMs = 0.0
                if ($t.PSObject.Properties.Name -contains 'duration' -and $null -ne $t.duration) {
                    [void][double]::TryParse([string]$t.duration, [ref]$durMs)
                }
                $msg = ''
                if ($t.PSObject.Properties.Name -contains 'failureMessages' -and $t.failureMessages) {
                    $msg = ($t.failureMessages -join "`n")
                }
                $out.Add((New-TestResult `
                    -Name $t.title `
                    -ClassName ([string]$suite.name) `
                    -Status $status `
                    -Duration ($durMs / 1000.0) `
                    -Message $msg `
                    -SourceFile $resolved))
            }
        }
    } else {
        throw "Unsupported JSON test report shape (expected 'testResults'): $resolved"
    }

    , $out.ToArray()
}

function Import-TestResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { return (Import-JUnitResults -Path $Path) }
        '.json' { return (Import-JsonResults  -Path $Path) }
        default { throw "Unsupported file extension '$ext' for $Path (expected .xml or .json)" }
    }
}

function Get-AggregatedResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Paths)

    $all = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $Paths) {
        foreach ($r in @(Import-TestResults -Path $p)) {
            $all.Add($r)
        }
    }

    $passed  = @($all | Where-Object { $_.Status -eq 'passed'  }).Count
    $failed  = @($all | Where-Object { $_.Status -eq 'failed'  }).Count
    $skipped = @($all | Where-Object { $_.Status -eq 'skipped' }).Count
    $duration = ($all | Measure-Object -Property Duration -Sum).Sum
    if (-not $duration) { $duration = 0.0 }

    # Flaky = same (ClassName+Name) observed as both passed AND failed across
    # the aggregated runs. Skipped alone doesn't count as flaky.
    $flaky = [System.Collections.Generic.List[object]]::new()
    $groups = $all | Group-Object -Property { "$($_.ClassName)::$($_.Name)" }
    foreach ($g in $groups) {
        $pc = @($g.Group | Where-Object { $_.Status -eq 'passed' }).Count
        $fc = @($g.Group | Where-Object { $_.Status -eq 'failed' }).Count
        if ($pc -gt 0 -and $fc -gt 0) {
            $first = $g.Group[0]
            $flaky.Add([pscustomobject]@{
                Name      = $first.Name
                ClassName = $first.ClassName
                PassCount = $pc
                FailCount = $fc
                Runs      = $g.Group.Count
            })
        }
    }

    [pscustomobject]@{
        Totals = [pscustomobject]@{
            Total    = $all.Count
            Passed   = $passed
            Failed   = $failed
            Skipped  = $skipped
            Duration = [double]$duration
        }
        FlakyTests = $flaky.ToArray()
        FileCount  = $Paths.Count
        Results    = $all.ToArray()
    }
}

function Format-MarkdownSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Aggregate)

    $t = $Aggregate.Totals
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Test Results')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Aggregated across **$($Aggregate.FileCount)** result file(s).")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Metric | Count |')
    [void]$sb.AppendLine('| --- | ---: |')
    [void]$sb.AppendLine("| Total | $($t.Total) |")
    [void]$sb.AppendLine("| Passed | $($t.Passed) |")
    [void]$sb.AppendLine("| Failed | $($t.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($t.Skipped) |")
    [void]$sb.AppendLine(("| Duration (s) | {0:N3} |" -f [double]$t.Duration))
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Flaky Tests')
    [void]$sb.AppendLine()
    if (-not $Aggregate.FlakyTests -or $Aggregate.FlakyTests.Count -eq 0) {
        [void]$sb.AppendLine('No flaky tests detected.')
    } else {
        [void]$sb.AppendLine('| Test | Class | Pass | Fail | Runs |')
        [void]$sb.AppendLine('| --- | --- | ---: | ---: | ---: |')
        foreach ($f in $Aggregate.FlakyTests) {
            [void]$sb.AppendLine("| $($f.Name) | $($f.ClassName) | $($f.PassCount) | $($f.FailCount) | $($f.Runs) |")
        }
    }
    $sb.ToString()
}

Export-ModuleMember -Function `
    Import-JUnitResults, Import-JsonResults, Import-TestResults, `
    Get-AggregatedResults, Format-MarkdownSummary
