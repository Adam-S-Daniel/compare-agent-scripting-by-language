# TestResultsAggregator
# ---------------------
# A small PowerShell module that ingests test result files in JUnit XML or
# JSON form, aggregates them across multiple "runs" (the matrix legs of a CI
# job), identifies flaky tests, and renders a Markdown summary suitable for
# a GitHub Actions job summary ($GITHUB_STEP_SUMMARY).
#
# Approach
#   * Each individual test case is normalised to a flat PSCustomObject with
#     fields { Name, ClassName, Status, Duration, Run, Message }. Status is
#     one of Passed | Failed | Skipped. This lets all downstream functions
#     treat the input uniformly regardless of source format.
#   * Identity for flakiness purposes is (ClassName, Name). A test is
#     "flaky" if it has at least one Passed and at least one Failed
#     observation across runs. Skipped runs are ignored for the verdict.
#   * Errors are surfaced via `throw` with messages that name what failed
#     and why — never silent failures.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# ---- internal helpers ------------------------------------------------------

function ConvertTo-NormalizedStatus {
    # JUnit, Pester, pytest-json, etc. all use slightly different vocabulary
    # ("pass"/"passed"/"PASS"/"success"). Normalize to one of three values.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Raw)

    switch -Regex ($Raw.ToLowerInvariant()) {
        '^(pass(ed)?|success|ok)$'   { return 'Passed'  }
        '^(fail(ed)?|error|broken)$' { return 'Failed'  }
        '^(skip(ped)?|ignored|na)$'  { return 'Skipped' }
        default { throw "Unknown test status '$Raw'." }
    }
}

# ---- JUnit parser ----------------------------------------------------------

function ConvertFrom-JUnitXml {
<#
.SYNOPSIS
    Parses a JUnit-format XML file and emits one normalized object per <testcase>.

.PARAMETER Path
    Absolute or relative path to the JUnit .xml file.

.OUTPUTS
    PSCustomObject with Name, ClassName, Status, Duration, Run, Message.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JUnit file not found: $Path"
    }

    [xml]$xml = $null
    try {
        $xml = [xml](Get-Content -LiteralPath $Path -Raw)
    } catch {
        throw "Failed to parse XML file '$Path': $($_.Exception.Message)"
    }

    # JUnit files come in two shapes: a root <testsuites> wrapping multiple
    # <testsuite>s, or a single <testsuite> as the root. SelectNodes handles
    # both with a //testcase XPath.
    $cases = $xml.SelectNodes('//testcase')
    $runName = [System.IO.Path]::GetFileName($Path)

    foreach ($tc in $cases) {
        $status  = 'Passed'
        $message = $null

        if ($tc.SelectSingleNode('failure') -or $tc.SelectSingleNode('error')) {
            $status = 'Failed'
            $node   = $tc.SelectSingleNode('failure')
            if (-not $node) { $node = $tc.SelectSingleNode('error') }
            $message = if ($node.message) { $node.message } else { $node.InnerText.Trim() }
        }
        elseif ($tc.SelectSingleNode('skipped')) {
            $status = 'Skipped'
            $skippedNode = $tc.SelectSingleNode('skipped')
            if ($skippedNode.message) { $message = $skippedNode.message }
        }

        $duration = 0.0
        if ($tc.HasAttribute('time') -and $tc.time) {
            [double]::TryParse(
                $tc.time,
                [System.Globalization.NumberStyles]::Float,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref]$duration) | Out-Null
        }

        [pscustomobject]@{
            Name      = [string]$tc.name
            ClassName = [string]$tc.classname
            Status    = $status
            Duration  = $duration
            Run       = $runName
            Message   = $message
        }
    }
}

# ---- JSON parser -----------------------------------------------------------

function ConvertFrom-TestJson {
<#
.SYNOPSIS
    Parses a JSON test-result file with the documented schema:
        { "run": "<id>", "tests": [ {name, suite, status, duration, message?}, ... ] }

.PARAMETER Path
    Absolute or relative path to the .json file.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JSON file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    $obj = $null
    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON file '$Path': $($_.Exception.Message)"
    }

    if (-not $obj.PSObject.Properties.Match('tests')) {
        throw "JSON file '$Path' does not contain a 'tests' array."
    }

    $runName = [System.IO.Path]::GetFileName($Path)

    foreach ($t in $obj.tests) {
        # Suite/message/duration are all optional in the schema. Use the
        # indexer-style lookup against PSObject.Properties — Match() returns a
        # collection that's awkward to test under Set-StrictMode 3.0, while
        # the indexer cleanly returns $null for missing names.
        $props = $t.PSObject.Properties
        $className = if ($props['suite'])    { [string]$t.suite }    else { '' }
        $message   = if ($props['message'])  { [string]$t.message }  else { $null }
        $duration  = if ($props['duration']) { [double]$t.duration } else { 0.0 }

        [pscustomobject]@{
            Name      = [string]$t.name
            ClassName = $className
            Status    = (ConvertTo-NormalizedStatus -Raw ([string]$t.status))
            Duration  = $duration
            Run       = $runName
            Message   = $message
        }
    }
}

# ---- dispatcher ------------------------------------------------------------

function Get-TestResults {
<#
.SYNOPSIS
    Reads a test result file, dispatching to the appropriate parser based on
    file extension.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { ConvertFrom-JUnitXml -Path $Path }
        '.json' { ConvertFrom-TestJson -Path $Path }
        default { throw "Unsupported test result format '$ext' for file '$Path'. Supported: .xml, .json." }
    }
}

# ---- aggregation -----------------------------------------------------------

function Merge-TestResults {
<#
.SYNOPSIS
    Aggregates a flat list of test result objects into a totals summary.

.OUTPUTS
    PSCustomObject with Total, Passed, Failed, Skipped, Duration, RunCount.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    # Bucket by status with Where-Object — each pass is O(n), and it keeps
    # the function readable. For the volume we expect (CI job output) this
    # is more than fast enough.
    $passed  = @($Results | Where-Object Status -EQ 'Passed')
    $failed  = @($Results | Where-Object Status -EQ 'Failed')
    $skipped = @($Results | Where-Object Status -EQ 'Skipped')
    $totalDuration = ($Results | Measure-Object Duration -Sum).Sum
    if (-not $totalDuration) { $totalDuration = 0.0 }
    $runCount = ($Results | Select-Object -ExpandProperty Run -Unique | Measure-Object).Count

    [pscustomobject]@{
        Total    = $Results.Count
        Passed   = $passed.Count
        Failed   = $failed.Count
        Skipped  = $skipped.Count
        Duration = [double]$totalDuration
        RunCount = $runCount
    }
}

# ---- flakiness -------------------------------------------------------------

function Find-FlakyTest {
<#
.SYNOPSIS
    Returns one record per (ClassName, Name) test that passed in some runs and
    failed in others. Skipped observations are ignored when computing the verdict.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    $byTest = $Results | Group-Object -Property { "{0}::{1}" -f $_.ClassName, $_.Name }

    foreach ($group in $byTest) {
        $passedRuns = @(
            $group.Group | Where-Object Status -EQ 'Passed' |
                Select-Object -ExpandProperty Run
        )
        $failedRuns = @(
            $group.Group | Where-Object Status -EQ 'Failed' |
                Select-Object -ExpandProperty Run
        )
        if ($passedRuns.Count -gt 0 -and $failedRuns.Count -gt 0) {
            $first = $group.Group[0]
            [pscustomobject]@{
                ClassName  = $first.ClassName
                Name       = $first.Name
                PassedRuns = @($passedRuns | Sort-Object)
                FailedRuns = @($failedRuns | Sort-Object)
            }
        }
    }
}

# ---- markdown rendering ----------------------------------------------------

function New-MarkdownSummary {
<#
.SYNOPSIS
    Renders an aggregated test summary as a Markdown string suitable for
    $GITHUB_STEP_SUMMARY.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    $totals = Merge-TestResults -Results $Results
    $flaky  = @(Find-FlakyTest -Results $Results)

    $passRate = if ($totals.Total -gt 0) {
        # Skipped tests count toward the denominator but not the numerator —
        # this matches what GitHub Actions / most CI dashboards report.
        ($totals.Passed / $totals.Total) * 100
    } else { 0 }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Test Results Summary')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Metric    | Value |')
    [void]$sb.AppendLine('| --------- | -----:|')
    [void]$sb.AppendLine("| Total     | $($totals.Total) |")
    [void]$sb.AppendLine("| Passed    | $($totals.Passed) |")
    [void]$sb.AppendLine("| Failed    | $($totals.Failed) |")
    [void]$sb.AppendLine("| Skipped   | $($totals.Skipped) |")
    [void]$sb.AppendLine(("| Pass rate | {0:N1}% |" -f $passRate))
    [void]$sb.AppendLine(("| Duration  | {0:N2}s |" -f $totals.Duration))
    [void]$sb.AppendLine("| Runs      | $($totals.RunCount) |")
    [void]$sb.AppendLine()

    # ---- failures ---------------------------------------------------------
    $failures = @($Results | Where-Object Status -EQ 'Failed')
    if ($failures.Count -gt 0) {
        [void]$sb.AppendLine('## Failures')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Test | Run | Message |')
        [void]$sb.AppendLine('| ---- | --- | ------- |')
        foreach ($f in $failures) {
            $msgProp = $f.PSObject.Properties['Message']
            $msg = if ($msgProp -and $msgProp.Value) {
                # Collapse newlines so a multi-line stack trace fits in one cell.
                ([string]$msgProp.Value -replace '\s+', ' ').Trim()
            } else { '' }
            $cls = if ($f.ClassName) { "$($f.ClassName)." } else { '' }
            [void]$sb.AppendLine("| ``$cls$($f.Name)`` | $($f.Run) | $msg |")
        }
        [void]$sb.AppendLine()
    }

    # ---- flaky -----------------------------------------------------------
    if ($flaky.Count -gt 0) {
        [void]$sb.AppendLine('## Flaky Tests')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('Tests that passed in some runs and failed in others:')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Test | Passed in | Failed in |')
        [void]$sb.AppendLine('| ---- | --------- | --------- |')
        foreach ($t in $flaky) {
            $cls = if ($t.ClassName) { "$($t.ClassName)." } else { '' }
            $pr = ($t.PassedRuns -join ', ')
            $fr = ($t.FailedRuns -join ', ')
            [void]$sb.AppendLine("| ``$cls$($t.Name)`` | $pr | $fr |")
        }
        [void]$sb.AppendLine()
    }

    # ---- per-run ---------------------------------------------------------
    [void]$sb.AppendLine('## Per-run breakdown')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Run | Total | Passed | Failed | Skipped | Duration |')
    [void]$sb.AppendLine('| --- | -----:| ------:| ------:| -------:| --------:|')
    $byRun = $Results | Group-Object Run | Sort-Object Name
    foreach ($r in $byRun) {
        $sub = Merge-TestResults -Results $r.Group
        [void]$sb.AppendLine(("| {0} | {1} | {2} | {3} | {4} | {5:N2}s |" -f `
            $r.Name, $sub.Total, $sub.Passed, $sub.Failed, $sub.Skipped, $sub.Duration))
    }

    return $sb.ToString()
}

# ---- top-level entry point ------------------------------------------------

function Invoke-TestResultsAggregator {
<#
.SYNOPSIS
    End-to-end entry point: discover test result files under -InputPath,
    aggregate them, write a markdown summary to -OutputPath, and (with
    -PassThru) return a structured result object.

.PARAMETER InputPath
    Either a directory (all .xml/.json under it are processed) or a single file.

.PARAMETER OutputPath
    Where to write the rendered markdown. Defaults to test-summary.md in CWD.

.PARAMETER PassThru
    Return a structured object describing the aggregation outcome.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [string]$OutputPath = 'test-summary.md',

        [switch]$PassThru
    )

    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Input path not found: $InputPath"
    }

    $files = if ((Get-Item -LiteralPath $InputPath).PSIsContainer) {
        Get-ChildItem -LiteralPath $InputPath -File -Recurse |
            Where-Object { $_.Extension -in '.xml', '.json' }
    } else {
        Get-Item -LiteralPath $InputPath
    }

    if (-not $files) {
        throw "No .xml or .json test result files found under '$InputPath'."
    }

    $all = foreach ($f in $files) {
        try {
            Get-TestResults -Path $f.FullName
        } catch {
            Write-Warning "Skipping '$($f.FullName)': $($_.Exception.Message)"
        }
    }
    $all = @($all)

    $markdown = New-MarkdownSummary -Results $all
    Set-Content -LiteralPath $OutputPath -Value $markdown -NoNewline

    if ($PassThru) {
        $totals = Merge-TestResults -Results $all
        return [pscustomobject]@{
            Markdown    = $markdown
            Totals      = $totals
            Flaky       = @(Find-FlakyTest -Results $all)
            HasFailures = ($totals.Failed -gt 0)
            OutputPath  = (Resolve-Path -LiteralPath $OutputPath).Path
        }
    }

    return $markdown
}

Export-ModuleMember -Function `
    ConvertFrom-JUnitXml, `
    ConvertFrom-TestJson, `
    Get-TestResults, `
    Merge-TestResults, `
    Find-FlakyTest, `
    New-MarkdownSummary, `
    Invoke-TestResultsAggregator
