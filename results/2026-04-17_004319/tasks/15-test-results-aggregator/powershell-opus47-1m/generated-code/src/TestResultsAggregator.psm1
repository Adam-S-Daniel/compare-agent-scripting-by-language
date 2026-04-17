# TestResultsAggregator.psm1
#
# Parses JUnit XML and JSON test result files into a common normalized shape,
# aggregates across multiple runs (e.g. matrix builds), identifies flaky tests,
# and renders a GitHub Actions-friendly markdown summary.
#
# Normalized shape returned by parsers:
#   [pscustomobject]@{
#       Format = 'junit' | 'json'
#       Source = <path>
#       Totals = [pscustomobject]@{ Total; Passed; Failed; Skipped; DurationSeconds }
#       Tests  = @([pscustomobject]@{ Suite; Name; Outcome; DurationSeconds; Message })
#   }

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# ---------- helpers ------------------------------------------------------

# Build a scripted exception with a stable ErrorId so tests can assert on it.
function New-AggregatorError {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$ErrorId,
        [System.Management.Automation.ErrorCategory]$Category = 'InvalidData',
        [object]$TargetObject
    )
    $exn = [System.Exception]::new($Message)
    [System.Management.Automation.ErrorRecord]::new($exn, $ErrorId, $Category, $TargetObject)
}

function New-Totals {
    param([int]$Total, [int]$Passed, [int]$Failed, [int]$Skipped, [double]$DurationSeconds)
    [pscustomobject]@{
        Total           = $Total
        Passed          = $Passed
        Failed          = $Failed
        Skipped         = $Skipped
        DurationSeconds = $DurationSeconds
    }
}

function New-TestCase {
    param([string]$Suite, [string]$Name, [string]$Outcome, [double]$DurationSeconds, [string]$Message)
    [pscustomobject]@{
        Suite           = $Suite
        Name            = $Name
        Outcome         = $Outcome
        DurationSeconds = $DurationSeconds
        Message         = $Message
    }
}

# ---------- JUnit XML parser ---------------------------------------------

function Import-JUnitXmlResult {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $PSCmdlet.ThrowTerminatingError(
            (New-AggregatorError -Message "JUnit file not found: $Path" `
                                 -ErrorId 'FileNotFound' `
                                 -Category ObjectNotFound `
                                 -TargetObject $Path))
    }

    [xml]$doc = Get-Content -LiteralPath $Path -Raw

    # Accept either <testsuites> as the outer or a single <testsuite>.
    # NOTE: Use .LocalName rather than .Name — PowerShell's XML type adapter
    # exposes child attributes as properties, so ".Name" on an element that
    # also has a "name" attribute returns the ATTRIBUTE VALUE, not the element
    # tag. .LocalName returns the actual tag.
    $rootTag = $doc.DocumentElement.LocalName
    $suites = @()
    if ($rootTag -eq 'testsuites') {
        if ($doc.DocumentElement.PSObject.Properties['testsuite']) {
            $suites = @($doc.DocumentElement.testsuite)
        }
    } elseif ($rootTag -eq 'testsuite') {
        $suites = @($doc.DocumentElement)
    } else {
        $PSCmdlet.ThrowTerminatingError(
            (New-AggregatorError -Message "Not a JUnit document (root = $rootTag): $Path" `
                                 -ErrorId 'InvalidJUnit' `
                                 -TargetObject $Path))
    }

    $tests = New-Object System.Collections.Generic.List[object]
    $total = 0; $passed = 0; $failed = 0; $skipped = 0
    $suiteTimeSum = 0.0     # sum of per-<testsuite time="..."> attributes
    $caseTimeSum  = 0.0     # fallback: sum of per-<testcase time="...">
    $haveAnySuiteTime = $false

    foreach ($suite in $suites) {
        if ($null -eq $suite) { continue }
        $suiteName = [string]$suite.name
        if ($suite.PSObject.Properties['time'] -and $suite.time) {
            $st = 0.0
            if ([double]::TryParse([string]$suite.time, [ref]$st)) {
                $suiteTimeSum += $st
                $haveAnySuiteTime = $true
            }
        }

        # XmlElement property access returns $null when missing — guard each.
        $cases = @()
        if ($suite.PSObject.Properties['testcase']) { $cases = @($suite.testcase) }

        foreach ($tc in $cases) {
            if ($null -eq $tc) { continue }
            $total++
            $name = [string]$tc.name

            $d = 0.0
            if ($tc.PSObject.Properties['time'] -and $tc.time) {
                [void][double]::TryParse([string]$tc.time, [ref]$d)
            }
            $caseTimeSum += $d

            # Check for the PRESENCE of the child element (not truthiness):
            # PowerShell's XML adapter returns an empty string for self-closing
            # empty elements like <skipped/>, which would evaluate as false.
            $outcome = 'passed'
            $msg = $null
            if ($tc.PSObject.Properties['failure']) {
                $outcome = 'failed'
                $msg = if ($tc.failure.message) { [string]$tc.failure.message } else { [string]$tc.failure.'#text' }
            } elseif ($tc.PSObject.Properties['error']) {
                $outcome = 'failed'
                $msg = if ($tc.error.message) { [string]$tc.error.message } else { [string]$tc.error.'#text' }
            } elseif ($tc.PSObject.Properties['skipped']) {
                $outcome = 'skipped'
            }

            switch ($outcome) {
                'passed'  { $passed++ }
                'failed'  { $failed++ }
                'skipped' { $skipped++ }
            }

            $tests.Add((New-TestCase -Suite $suiteName -Name $name -Outcome $outcome -DurationSeconds $d -Message $msg))
        }
    }

    # Prefer the declared <testsuite time=...> sum; fall back to per-testcase total.
    $duration = if ($haveAnySuiteTime) { $suiteTimeSum } else { $caseTimeSum }

    [pscustomobject]@{
        Format = 'junit'
        Source = $Path
        Totals = New-Totals -Total $total -Passed $passed -Failed $failed -Skipped $skipped -DurationSeconds $duration
        Tests  = $tests.ToArray()
    }
}

# ---------- JSON parser ---------------------------------------------------

function Import-JsonTestResult {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $PSCmdlet.ThrowTerminatingError(
            (New-AggregatorError -Message "JSON file not found: $Path" `
                                 -ErrorId 'FileNotFound' `
                                 -Category ObjectNotFound `
                                 -TargetObject $Path))
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $PSCmdlet.ThrowTerminatingError(
            (New-AggregatorError -Message "JSON parse error in ${Path}: $($_.Exception.Message)" `
                                 -ErrorId 'InvalidJson' `
                                 -TargetObject $Path))
    }

    # Allowed outcomes — anything else is a fixture authoring error.
    $validOutcomes = @('passed', 'failed', 'skipped')

    $tests = New-Object System.Collections.Generic.List[object]
    $passed = 0; $failed = 0; $skipped = 0
    $totalDuration = 0.0

    $cases = @()
    if ($obj.PSObject.Properties['tests']) { $cases = @($obj.tests) }

    foreach ($tc in $cases) {
        $outcome = [string]$tc.outcome
        if ($outcome -notin $validOutcomes) {
            $PSCmdlet.ThrowTerminatingError(
                (New-AggregatorError -Message "Invalid outcome '$outcome' in ${Path} (must be passed/failed/skipped)" `
                                     -ErrorId 'InvalidOutcome' `
                                     -TargetObject $Path))
        }
        switch ($outcome) {
            'passed'  { $passed++ }
            'failed'  { $failed++ }
            'skipped' { $skipped++ }
        }
        $dur = 0.0
        if ($tc.PSObject.Properties['durationSeconds'] -and $null -ne $tc.durationSeconds) {
            $dur = [double]$tc.durationSeconds
        }
        $msg = $null
        if ($tc.PSObject.Properties['message']) { $msg = [string]$tc.message }
        $suite = if ($tc.PSObject.Properties['suite']) { [string]$tc.suite } else { '' }
        $tests.Add((New-TestCase -Suite $suite -Name ([string]$tc.name) -Outcome $outcome -DurationSeconds $dur -Message $msg))
        $totalDuration += $dur
    }

    # Prefer top-level durationSeconds when present, otherwise sum per-test.
    if ($obj.PSObject.Properties['durationSeconds'] -and $null -ne $obj.durationSeconds) {
        $totalDuration = [double]$obj.durationSeconds
    }

    $total = $passed + $failed + $skipped

    [pscustomobject]@{
        Format = 'json'
        Source = $Path
        Totals = New-Totals -Total $total -Passed $passed -Failed $failed -Skipped $skipped -DurationSeconds $totalDuration
        Tests  = $tests.ToArray()
    }
}

# ---------- Dispatcher ---------------------------------------------------

function Import-TestResultFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { return Import-JUnitXmlResult -Path $Path }
        '.json' { return Import-JsonTestResult -Path $Path }
        default {
            $PSCmdlet.ThrowTerminatingError(
                (New-AggregatorError -Message "Unknown test result extension '$ext' for file $Path" `
                                     -ErrorId 'UnknownFormat' `
                                     -TargetObject $Path))
        }
    }
}

# ---------- Aggregation --------------------------------------------------

function Merge-TestRun {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Runs)

    $total = 0; $passed = 0; $failed = 0; $skipped = 0; $duration = 0.0
    foreach ($r in $Runs) {
        $total   += [int]$r.Totals.Total
        $passed  += [int]$r.Totals.Passed
        $failed  += [int]$r.Totals.Failed
        $skipped += [int]$r.Totals.Skipped
        $duration += [double]$r.Totals.DurationSeconds
    }

    [pscustomobject]@{
        Totals = New-Totals -Total $total -Passed $passed -Failed $failed -Skipped $skipped -DurationSeconds $duration
        Runs   = @($Runs)
    }
}

# ---------- Flaky detection ----------------------------------------------

function Find-FlakyTest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Runs)

    # Group every test occurrence across all runs by "suite::name" identity,
    # then flag any id that both passed and failed at least once.
    $map = @{}
    foreach ($r in $Runs) {
        foreach ($t in $r.Tests) {
            $id = '{0}::{1}' -f $t.Suite, $t.Name
            if (-not $map.ContainsKey($id)) {
                $map[$id] = [pscustomobject]@{
                    Suite     = $t.Suite
                    Name      = $t.Name
                    PassCount = 0
                    FailCount = 0
                    Messages  = New-Object System.Collections.Generic.List[string]
                }
            }
            $entry = $map[$id]
            switch ($t.Outcome) {
                'passed' { $entry.PassCount++ }
                'failed' {
                    $entry.FailCount++
                    if ($t.Message) { [void]$entry.Messages.Add($t.Message) }
                }
            }
        }
    }

    @($map.Values | Where-Object { $_.PassCount -gt 0 -and $_.FailCount -gt 0 } |
        Sort-Object Suite, Name)
}

# ---------- Markdown rendering -------------------------------------------

function New-MarkdownSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Aggregate,
        [object[]]$Flaky = @()
    )

    $t = $Aggregate.Totals
    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine('# Test Results Summary')
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## Totals')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Metric   | Value |')
    [void]$sb.AppendLine('| -------- | ----- |')
    [void]$sb.AppendLine(('| Total    | {0} |' -f $t.Total))
    [void]$sb.AppendLine(('| Passed   | {0} |' -f $t.Passed))
    [void]$sb.AppendLine(('| Failed   | {0} |' -f $t.Failed))
    [void]$sb.AppendLine(('| Skipped  | {0} |' -f $t.Skipped))
    [void]$sb.AppendLine(('| Duration | {0:N3}s |' -f [double]$t.DurationSeconds))
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## Runs')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Source | Format | Total | Passed | Failed | Skipped | Duration |')
    [void]$sb.AppendLine('| ------ | ------ | ----- | ------ | ------ | ------- | -------- |')
    foreach ($r in $Aggregate.Runs) {
        $rt = $r.Totals
        $line = '| {0} | {1} | {2} | {3} | {4} | {5} | {6:N3}s |' -f `
            $r.Source, $r.Format, $rt.Total, $rt.Passed, $rt.Failed, $rt.Skipped, [double]$rt.DurationSeconds
        [void]$sb.AppendLine($line)
    }
    [void]$sb.AppendLine()

    # Filter $null defensively — @($null) yields a 1-element array with $null
    # inside, which would break property access under StrictMode.
    $flakyArr = @($Flaky | Where-Object { $null -ne $_ })
    if ($flakyArr.Count -gt 0) {
        [void]$sb.AppendLine(('## Flaky tests ({0})' -f $flakyArr.Count))
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Suite | Name | Passes | Failures |')
        [void]$sb.AppendLine('| ----- | ---- | ------ | -------- |')
        foreach ($f in $flakyArr) {
            [void]$sb.AppendLine(('| {0} | {1} | {2} | {3} |' -f $f.Suite, $f.Name, $f.PassCount, $f.FailCount))
        }
        [void]$sb.AppendLine()
    } else {
        [void]$sb.AppendLine('## Flaky tests')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('No flaky tests detected.')
        [void]$sb.AppendLine()
    }

    # List failed tests (if any) for quick triage.
    $failures = foreach ($r in $Aggregate.Runs) {
        foreach ($t in $r.Tests) {
            if ($t.Outcome -eq 'failed') {
                [pscustomobject]@{ Source = $r.Source; Suite = $t.Suite; Name = $t.Name; Message = $t.Message }
            }
        }
    }
    $failures = @($failures)
    if ($failures.Count -gt 0) {
        [void]$sb.AppendLine(('## Failed tests ({0})' -f $failures.Count))
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Source | Suite | Name | Message |')
        [void]$sb.AppendLine('| ------ | ----- | ---- | ------- |')
        foreach ($f in $failures) {
            $m = ($f.Message -replace "`r?`n", ' ').Trim()
            if ($m.Length -gt 120) { $m = $m.Substring(0, 117) + '...' }
            [void]$sb.AppendLine(('| {0} | {1} | {2} | {3} |' -f $f.Source, $f.Suite, $f.Name, $m))
        }
        [void]$sb.AppendLine()
    }

    $sb.ToString()
}

# ---------- Orchestrator -------------------------------------------------

function Invoke-TestResultsAggregator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Paths,
        [string]$SummaryPath
    )

    $runs = foreach ($p in $Paths) { Import-TestResultFile -Path $p }
    $runs = @($runs)

    $aggregate = Merge-TestRun -Runs $runs
    $flaky     = Find-FlakyTest -Runs $runs
    $markdown  = New-MarkdownSummary -Aggregate $aggregate -Flaky $flaky

    if ($SummaryPath) {
        $dir = Split-Path -Parent $SummaryPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $SummaryPath -Value $markdown -Encoding UTF8
    }

    $overall = if ($aggregate.Totals.Failed -gt 0) { 'failed' } else { 'passed' }

    [pscustomobject]@{
        Aggregate     = $aggregate
        Flaky         = $flaky
        Markdown      = $markdown
        OverallStatus = $overall
    }
}

Export-ModuleMember -Function `
    Import-JUnitXmlResult,
    Import-JsonTestResult,
    Import-TestResultFile,
    Merge-TestRun,
    Find-FlakyTest,
    New-MarkdownSummary,
    Invoke-TestResultsAggregator
