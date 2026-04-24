# TestResultsAggregator.psm1
#
# Parse JUnit XML and JSON test-result files, aggregate them across multiple
# runs (a "matrix" build), detect flaky tests (the same test case passes in
# some runs and fails in others), and render a GitHub-Actions-friendly
# markdown summary.
#
# Public functions (explicitly exported at the bottom):
#   Import-JUnitXml      -- parse one JUnit XML file into a run object
#   Import-JsonResults   -- parse one JSON file into a run object
#   Import-TestResults   -- dispatch to the right parser based on extension
#   Merge-TestRuns       -- compute totals across many runs, and flaky set
#   Find-FlakyTests      -- standalone flaky-test detection
#   Format-GitHubSummary -- render an aggregate as GitHub-flavored markdown
#
# Data shapes:
#   Test   = [pscustomobject]@{ Name; ClassName; Status('passed'|'failed'|'skipped'); Duration; Message }
#   Run    = [pscustomobject]@{ Source; Format; Tests=Test[] }
#   Agg    = [pscustomobject]@{ TotalTests; TotalPassed; TotalFailed; TotalSkipped;
#                               TotalDuration; Runs; FlakyTests }

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function New-TestCase {
    # Small helper: builds a uniform Test object regardless of input format.
    param(
        [string]$Name,
        [string]$ClassName,
        [string]$Status,
        [double]$Duration = 0.0,
        [string]$Message = $null
    )
    [pscustomobject]@{
        Name      = $Name
        ClassName = $ClassName
        Status    = $Status
        Duration  = $Duration
        Message   = $Message
    }
}

function Import-JUnitXml {
    <#
    .SYNOPSIS
    Parse a JUnit-style XML file into a run object.

    .DESCRIPTION
    Supports both root elements:
      * <testsuites> wrapping one or more <testsuite>
      * a single <testsuite> at the root
    A testcase is considered:
      * failed  if it contains <failure> or <error>
      * skipped if it contains <skipped>
      * passed  otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JUnit XML file not found: $Path"
    }

    [xml]$doc = Get-Content -LiteralPath $Path -Raw
    $root = $doc.DocumentElement
    if (-not $root) { throw "JUnit XML has no root element: $Path" }

    $suites = switch ($root.LocalName) {
        'testsuites' { @($root.testsuite) }
        'testsuite'  { @($root) }
        default      { throw "Unexpected root element '<$($root.LocalName)>' in $Path" }
    }

    $tests = foreach ($suite in $suites) {
        if (-not $suite) { continue }
        foreach ($tc in @($suite.testcase)) {
            if (-not $tc) { continue }

            $status = if ($tc.SelectSingleNode('failure') -or $tc.SelectSingleNode('error')) {
                'failed'
            } elseif ($tc.SelectSingleNode('skipped')) {
                'skipped'
            } else {
                'passed'
            }

            $dur = 0.0
            if ($tc.HasAttribute('time')) {
                [double]::TryParse($tc.time, [ref]$dur) | Out-Null
            }

            $msg = $null
            $failNode = $tc.SelectSingleNode('failure')
            $errNode  = $tc.SelectSingleNode('error')
            $skipNode = $tc.SelectSingleNode('skipped')
            if ($failNode -and $failNode.HasAttribute('message')) { $msg = $failNode.message }
            elseif ($errNode -and $errNode.HasAttribute('message')) { $msg = $errNode.message }
            elseif ($skipNode -and $skipNode.HasAttribute('message')) { $msg = $skipNode.message }

            New-TestCase -Name $tc.name -ClassName $tc.classname -Status $status -Duration $dur -Message $msg
        }
    }

    [pscustomobject]@{
        Source = (Resolve-Path -LiteralPath $Path).Path
        Format = 'junit'
        Tests  = @($tests)
    }
}

function Import-JsonResults {
    <#
    .SYNOPSIS
    Parse a JSON test-result file into a run object.

    .DESCRIPTION
    Expected schema (minimal, matches the fixtures):
      {
        "suite": "<suite-name>",
        "tests": [
          { "name": "...", "classname": "...", "status": "passed|failed|skipped",
            "duration": 0.0, "message": "..." }
        ]
      }
    classname defaults to the suite name when omitted.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON results file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $json = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON in $Path : $($_.Exception.Message)"
    }

    if (-not $json.PSObject.Properties['tests']) {
        throw "JSON results file $Path is missing required 'tests' array."
    }

    $suiteName = if ($json.PSObject.Properties['suite']) { [string]$json.suite } else { '' }

    $tests = foreach ($t in @($json.tests)) {
        $status = ''
        if ($t.PSObject.Properties['status'] -and $t.status) {
            $status = ([string]$t.status).ToLowerInvariant()
        }
        if ($status -notin @('passed','failed','skipped')) {
            throw "Test '$($t.name)' in $Path has invalid status '$status'. Expected passed|failed|skipped."
        }

        $cls = if ($t.PSObject.Properties['classname'] -and $t.classname) { [string]$t.classname } else { $suiteName }
        $dur = 0.0
        if ($t.PSObject.Properties['duration'] -and $null -ne $t.duration) {
            [double]::TryParse([string]$t.duration, [ref]$dur) | Out-Null
        }
        $msg = if ($t.PSObject.Properties['message']) { [string]$t.message } else { $null }

        New-TestCase -Name $t.name -ClassName $cls -Status $status -Duration $dur -Message $msg
    }

    [pscustomobject]@{
        Source = (Resolve-Path -LiteralPath $Path).Path
        Format = 'json'
        Tests  = @($tests)
    }
}

function Import-TestResults {
    <#
    .SYNOPSIS
    Auto-detect the format from the file extension and dispatch.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { return Import-JUnitXml    -Path $Path }
        '.json' { return Import-JsonResults -Path $Path }
        default { throw "Unsupported test result format '$ext' for file: $Path (expected .xml or .json)" }
    }
}

function Find-FlakyTests {
    <#
    .SYNOPSIS
    Identify tests whose status differs across the provided runs.

    .DESCRIPTION
    A test is flaky when, across all runs, its observed statuses include BOTH
    'passed' and 'failed'. 'skipped' alone does not count. Tests are matched
    by the composite key "<ClassName>::<Name>".
    Returns an array; the array is empty (but still an array) if nothing is flaky.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Runs
    )

    $all = foreach ($r in $Runs) { foreach ($t in $r.Tests) { $t } }
    if (-not $all) { return ,@() }

    $groups = $all | Group-Object -Property { "{0}::{1}" -f $_.ClassName, $_.Name }

    $flaky = foreach ($g in $groups) {
        $statuses = @($g.Group.Status | Sort-Object -Unique)
        if (($statuses -contains 'passed') -and ($statuses -contains 'failed')) {
            $first = $g.Group[0]
            [pscustomobject]@{
                Name      = $first.Name
                ClassName = $first.ClassName
                Statuses  = $statuses
                RunCount  = $g.Count
            }
        }
    }

    ,@($flaky)
}

function Merge-TestRuns {
    <#
    .SYNOPSIS
    Aggregate totals over many runs and attach flaky-test info.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Runs
    )

    $all = foreach ($r in $Runs) { foreach ($t in $r.Tests) { $t } }
    $passed  = @($all | Where-Object Status -EQ 'passed').Count
    $failed  = @($all | Where-Object Status -EQ 'failed').Count
    $skipped = @($all | Where-Object Status -EQ 'skipped').Count
    $durSum  = ($all | Measure-Object -Property Duration -Sum).Sum
    if (-not $durSum) { $durSum = 0.0 }

    $flaky = Find-FlakyTests -Runs $Runs

    [pscustomobject]@{
        TotalTests    = $passed + $failed + $skipped
        TotalPassed   = $passed
        TotalFailed   = $failed
        TotalSkipped  = $skipped
        TotalDuration = [double]$durSum
        Runs          = @($Runs)
        FlakyTests    = @($flaky)
    }
}

function Format-GitHubSummary {
    <#
    .SYNOPSIS
    Render a Merge-TestRuns aggregate as GitHub-flavored markdown.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Aggregate
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Test Results Summary')
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## Totals')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Metric | Value |')
    [void]$sb.AppendLine('| --- | --- |')
    [void]$sb.AppendLine("| Total tests | $($Aggregate.TotalTests) |")
    [void]$sb.AppendLine("| Passed | $($Aggregate.TotalPassed) |")
    [void]$sb.AppendLine("| Failed | $($Aggregate.TotalFailed) |")
    [void]$sb.AppendLine("| Skipped | $($Aggregate.TotalSkipped) |")
    [void]$sb.AppendLine("| Duration (s) | $([math]::Round($Aggregate.TotalDuration, 2)) |")
    [void]$sb.AppendLine("| Runs | $($Aggregate.Runs.Count) |")
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## Flaky tests')
    [void]$sb.AppendLine()
    if ($Aggregate.FlakyTests.Count -eq 0) {
        [void]$sb.AppendLine('No flaky tests detected.')
    } else {
        [void]$sb.AppendLine('| Class | Test | Observed statuses | Runs |')
        [void]$sb.AppendLine('| --- | --- | --- | --- |')
        foreach ($f in $Aggregate.FlakyTests) {
            $statuses = ($f.Statuses -join ', ')
            [void]$sb.AppendLine("| $($f.ClassName) | $($f.Name) | $statuses | $($f.RunCount) |")
        }
    }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## Per-run breakdown')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Source | Format | Tests | Passed | Failed | Skipped | Duration (s) |')
    [void]$sb.AppendLine('| --- | --- | --- | --- | --- | --- | --- |')
    foreach ($r in $Aggregate.Runs) {
        $p = @($r.Tests | Where-Object Status -EQ 'passed').Count
        $f = @($r.Tests | Where-Object Status -EQ 'failed').Count
        $s = @($r.Tests | Where-Object Status -EQ 'skipped').Count
        $d = ($r.Tests | Measure-Object -Property Duration -Sum).Sum
        if (-not $d) { $d = 0.0 }
        $name = [System.IO.Path]::GetFileName($r.Source)
        [void]$sb.AppendLine("| $name | $($r.Format) | $($r.Tests.Count) | $p | $f | $s | $([math]::Round([double]$d,2)) |")
    }

    # Failed-test detail block: surfaces the actual failure messages so
    # a developer reading the GitHub job summary can start debugging without
    # opening the raw result files.
    $failures = foreach ($r in $Aggregate.Runs) {
        $src = [System.IO.Path]::GetFileName($r.Source)
        foreach ($t in $r.Tests) {
            if ($t.Status -eq 'failed') {
                [pscustomobject]@{ Source=$src; ClassName=$t.ClassName; Name=$t.Name; Message=$t.Message }
            }
        }
    }
    if ($failures) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('## Failed test details')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Source | Class | Test | Message |')
        [void]$sb.AppendLine('| --- | --- | --- | --- |')
        foreach ($f in $failures) {
            $msg = if ($f.Message) { ($f.Message -replace '\|','\|' -replace '[\r\n]+',' ') } else { '' }
            [void]$sb.AppendLine("| $($f.Source) | $($f.ClassName) | $($f.Name) | $msg |")
        }
    }

    $sb.ToString()
}

Export-ModuleMember -Function `
    Import-JUnitXml,
    Import-JsonResults,
    Import-TestResults,
    Merge-TestRuns,
    Find-FlakyTests,
    Format-GitHubSummary
