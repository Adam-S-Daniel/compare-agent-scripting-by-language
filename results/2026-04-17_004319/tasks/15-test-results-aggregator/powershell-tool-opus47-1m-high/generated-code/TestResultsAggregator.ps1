<#
.SYNOPSIS
    Aggregate JUnit XML and JSON test result files and produce a markdown
    summary suitable for a GitHub Actions job summary.

.DESCRIPTION
    This script is meant to be dot-sourced from Pester tests or run as a CLI.
    It exposes a few small functions so each piece of logic can be tested in
    isolation:

        Read-JUnitXmlResult   - parse a JUnit XML file into normalised records
        Read-JsonResult       - parse a simple JSON results file
        Read-TestResultFile   - dispatch by extension
        Get-AggregatedResult  - total passed/failed/skipped/duration across files
        Get-FlakyTest         - detect tests that both passed and failed across runs
        Format-MarkdownSummary - render the aggregate as markdown
        Invoke-TestResultsAggregator - CLI entry point

    The normalised record produced by the readers has this shape:
        [pscustomobject]@{
            Name            = 'test_addition'
            ClassName       = 'suite.math'
            Outcome         = 'Passed' | 'Failed' | 'Skipped'
            DurationSeconds = 0.12
            Message         = $null
            SourceFile      = '/path/to/junit-run1.xml'
            RunName         = 'junit-run1'
        }
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-JUnitXmlResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Test result file not found: $Path"
    }

    try {
        [xml]$doc = Get-Content -LiteralPath $Path -Raw
    } catch {
        throw "Failed to parse JUnit XML '$Path': $($_.Exception.Message)"
    }

    $runName = [IO.Path]::GetFileNameWithoutExtension($Path)

    # Support both <testsuites><testsuite> and a bare <testsuite> root.
    $suites = @()
    if ($doc.testsuites -and $doc.testsuites.testsuite) {
        $suites = @($doc.testsuites.testsuite)
    } elseif ($doc.testsuite) {
        $suites = @($doc.testsuite)
    }

    $results = foreach ($suite in $suites) {
        if (-not $suite.testcase) { continue }
        foreach ($case in @($suite.testcase)) {
            $outcome = 'Passed'
            $message = $null
            if ($case.PSObject.Properties['failure']) {
                $outcome = 'Failed'
                $message = [string]$case.failure.message
            } elseif ($case.PSObject.Properties['error']) {
                $outcome = 'Failed'
                $message = [string]$case.error.message
            } elseif ($case.PSObject.Properties['skipped']) {
                $outcome = 'Skipped'
                $message = [string]$case.skipped.message
            }
            $duration = 0.0
            if ($case.PSObject.Properties['time'] -and $case.time) {
                [double]::TryParse([string]$case.time, [ref]$duration) | Out-Null
            }
            [pscustomobject]@{
                Name            = [string]$case.name
                ClassName       = [string]$case.classname
                Outcome         = $outcome
                DurationSeconds = [double]$duration
                Message         = $message
                SourceFile      = (Resolve-Path -LiteralPath $Path).Path
                RunName         = $runName
            }
        }
    }

    return ,@($results)
}

function Read-JsonResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Test result file not found: $Path"
    }

    try {
        $doc = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse JSON '$Path': $($_.Exception.Message)"
    }

    $runName = [IO.Path]::GetFileNameWithoutExtension($Path)

    # Accept either { tests: [...] } or a bare array.
    $cases = @()
    if ($doc -is [System.Collections.IEnumerable] -and -not ($doc -is [string])) {
        $cases = @($doc)
    } elseif ($doc.PSObject.Properties['tests']) {
        $cases = @($doc.tests)
    }

    $results = foreach ($case in $cases) {
        $raw = [string]$case.outcome
        $outcome = switch -Regex ($raw.ToLowerInvariant()) {
            '^pass(ed)?$' { 'Passed'; break }
            '^fail(ed)?$' { 'Failed'; break }
            '^skip(ped)?$' { 'Skipped'; break }
            default { 'Passed' }
        }
        $duration = 0.0
        if ($case.PSObject.Properties['duration'] -and $null -ne $case.duration) {
            [double]::TryParse([string]$case.duration, [ref]$duration) | Out-Null
        }
        $className = ''
        if ($case.PSObject.Properties['classname']) { $className = [string]$case.classname }
        $msg = $null
        if ($case.PSObject.Properties['message']) { $msg = [string]$case.message }
        [pscustomobject]@{
            Name            = [string]$case.name
            ClassName       = $className
            Outcome         = $outcome
            DurationSeconds = [double]$duration
            Message         = $msg
            SourceFile      = (Resolve-Path -LiteralPath $Path).Path
            RunName         = $runName
        }
    }

    return ,@($results)
}

function Read-TestResultFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { return (Read-JUnitXmlResult -Path $Path) }
        '.json' { return (Read-JsonResult -Path $Path) }
        default { throw "Unsupported test result file extension: '$ext' ($Path)" }
    }
}

function Get-AggregatedResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $Paths
    )

    $allResults = New-Object System.Collections.Generic.List[object]
    $runs = New-Object System.Collections.Generic.List[object]

    foreach ($p in $Paths) {
        $records = @(Read-TestResultFile -Path $p)
        $runs.Add([pscustomobject]@{
            Path    = $p
            RunName = [IO.Path]::GetFileNameWithoutExtension($p)
            Results = $records
        })
        foreach ($r in $records) { $allResults.Add($r) }
    }

    $passed  = @($allResults | Where-Object { $_.Outcome -eq 'Passed' }).Count
    $failed  = @($allResults | Where-Object { $_.Outcome -eq 'Failed' }).Count
    $skipped = @($allResults | Where-Object { $_.Outcome -eq 'Skipped' }).Count
    $duration = 0.0
    foreach ($r in $allResults) { $duration += [double]$r.DurationSeconds }

    return [pscustomobject]@{
        Total           = $allResults.Count
        Passed          = $passed
        Failed          = $failed
        Skipped         = $skipped
        DurationSeconds = $duration
        Runs            = $runs
        Results         = $allResults
    }
}

function Get-FlakyTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Aggregated
    )

    # Group by (ClassName::Name). A test is flaky if across runs it has both
    # a 'Passed' and a 'Failed' outcome. Skips alone are not flaky.
    $groups = $Aggregated.Results | Group-Object -Property { "$($_.ClassName)::$($_.Name)" }

    # Use an explicit List so an empty result round-trips cleanly through the
    # `return ,@(...)` unrolling guard without leaving a $null placeholder.
    $flaky = New-Object System.Collections.Generic.List[object]
    foreach ($g in $groups) {
        $outcomes = $g.Group | Select-Object -ExpandProperty Outcome -Unique
        if (($outcomes -contains 'Passed') -and ($outcomes -contains 'Failed')) {
            $first = $g.Group | Select-Object -First 1
            $flaky.Add([pscustomobject]@{
                Name      = $first.Name
                ClassName = $first.ClassName
                Runs      = @($g.Group | Select-Object -ExpandProperty RunName)
                Outcomes  = @($g.Group | Select-Object -ExpandProperty Outcome)
            })
        }
    }

    # Cast to a strongly-typed empty-safe array. Returning the List directly or
    # the comma-wrapped array both leak a single $null element through
    # pscustomobject hash-table construction - this form does not.
    [object[]]$out = $flaky.ToArray()
    ,$out
}

function Format-MarkdownSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Aggregated
    )

    $flaky = Get-FlakyTest -Aggregated $Aggregated
    $durFormatted = ('{0:N2}' -f $Aggregated.DurationSeconds)

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# Test Results Summary')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Totals')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Metric | Value |')
    [void]$sb.AppendLine('| --- | --- |')
    [void]$sb.AppendLine("| Total | $($Aggregated.Total) |")
    [void]$sb.AppendLine("| Passed | $($Aggregated.Passed) |")
    [void]$sb.AppendLine("| Failed | $($Aggregated.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($Aggregated.Skipped) |")
    [void]$sb.AppendLine("| Duration (s) | $durFormatted |")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Runs')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Run | Total | Passed | Failed | Skipped |')
    [void]$sb.AppendLine('| --- | ---: | ---: | ---: | ---: |')
    foreach ($r in $Aggregated.Runs) {
        $p = @($r.Results | Where-Object { $_.Outcome -eq 'Passed' }).Count
        $f = @($r.Results | Where-Object { $_.Outcome -eq 'Failed' }).Count
        $s = @($r.Results | Where-Object { $_.Outcome -eq 'Skipped' }).Count
        [void]$sb.AppendLine("| $($r.RunName) | $($r.Results.Count) | $p | $f | $s |")
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Failed tests')
    [void]$sb.AppendLine('')
    $failed = @($Aggregated.Results | Where-Object { $_.Outcome -eq 'Failed' })
    if ($failed.Count -eq 0) {
        [void]$sb.AppendLine('None')
    } else {
        foreach ($f in $failed) {
            $msg = if ($f.Message) { " - $($f.Message)" } else { '' }
            [void]$sb.AppendLine("- **$($f.ClassName)::$($f.Name)** (run: $($f.RunName))$msg")
        }
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Flaky tests')
    [void]$sb.AppendLine('')
    if (@($flaky).Count -eq 0) {
        [void]$sb.AppendLine('None')
    } else {
        foreach ($ft in $flaky) {
            [void]$sb.AppendLine("- **$($ft.ClassName)::$($ft.Name)** - outcomes: $($ft.Outcomes -join ', ')")
        }
    }

    return $sb.ToString()
}

function Invoke-TestResultsAggregator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $Paths,
        [string] $OutputPath
    )

    $agg = Get-AggregatedResult -Paths $Paths
    $md  = Format-MarkdownSummary -Aggregated $agg
    if ($OutputPath) {
        $dir = Split-Path -Parent $OutputPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $OutputPath -Value $md -NoNewline
    }

    # Strip the heavy fields to keep the summary compact; keep the markdown
    # itself on the returned object for callers that want both.
    return [pscustomobject]@{
        Total           = $agg.Total
        Passed          = $agg.Passed
        Failed          = $agg.Failed
        Skipped         = $agg.Skipped
        DurationSeconds = $agg.DurationSeconds
        Flaky           = [object[]](Get-FlakyTest -Aggregated $agg)
        Markdown        = $md
    }
}

# This file is a library: dot-source it (`. ./TestResultsAggregator.ps1`) to
# load the functions above. The CLI wrapper lives in Invoke-Aggregator.ps1.
