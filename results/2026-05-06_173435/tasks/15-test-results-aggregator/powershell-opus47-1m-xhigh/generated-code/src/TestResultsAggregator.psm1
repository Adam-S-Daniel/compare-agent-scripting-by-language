#requires -Version 7.0
Set-StrictMode -Version Latest

# TestResultsAggregator
#
# Parses test result files in JUnit XML or JSON format, aggregates them across
# multiple matrix-build runs, identifies flaky tests, and renders a markdown
# summary intended for $GITHUB_STEP_SUMMARY.
#
# Internal test record shape (a hashtable):
#   Name           - test case name
#   Suite          - suite / classname
#   Status         - 'passed' | 'failed' | 'skipped'
#   Duration       - seconds, [double]
#   RunId          - which input file/run produced the record
#   FailureMessage - failure message, or $null

function Read-JUnitXmlResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $RunId
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JUnit XML file not found: $Path"
    }

    $doc = [xml]::new()
    try {
        $doc.Load((Resolve-Path -LiteralPath $Path).Path)
    }
    catch {
        throw "File '$Path' is not valid JUnit XML: $($_.Exception.Message)"
    }

    # Accept both <testsuites> and bare <testsuite> roots.
    $root = $doc.DocumentElement
    if (-not $root) {
        throw "File '$Path' is not valid JUnit XML: missing root element"
    }

    $suiteNodes = if ($root.LocalName -eq 'testsuites') {
        @($root.SelectNodes('testsuite'))
    }
    elseif ($root.LocalName -eq 'testsuite') {
        @($root)
    }
    else {
        throw "File '$Path' is not valid JUnit XML: unexpected root element <$($root.LocalName)>"
    }

    $tests = New-Object System.Collections.Generic.List[hashtable]

    foreach ($suite in $suiteNodes) {
        $suiteName = if ($suite.HasAttribute('name')) { $suite.GetAttribute('name') } else { '' }
        foreach ($case in $suite.SelectNodes('testcase')) {
            $name = $case.GetAttribute('name')
            $className = if ($case.HasAttribute('classname')) { $case.GetAttribute('classname') } else { $suiteName }
            $time = 0.0
            if ($case.HasAttribute('time')) {
                [double]::TryParse(
                    $case.GetAttribute('time'),
                    [System.Globalization.NumberStyles]::Float,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [ref]$time
                ) | Out-Null
            }

            $status = 'passed'
            $failureMsg = $null
            $failureNode = $case.SelectSingleNode('failure')
            $errorNode   = $case.SelectSingleNode('error')
            $skippedNode = $case.SelectSingleNode('skipped')
            if ($failureNode) {
                $status = 'failed'
                $failureMsg = if ($failureNode.HasAttribute('message')) { $failureNode.GetAttribute('message') } else { $failureNode.InnerText }
            }
            elseif ($errorNode) {
                $status = 'failed'
                $failureMsg = if ($errorNode.HasAttribute('message')) { $errorNode.GetAttribute('message') } else { $errorNode.InnerText }
            }
            elseif ($skippedNode) {
                $status = 'skipped'
            }

            $tests.Add(@{
                Name           = $name
                Suite          = $className
                Status         = $status
                Duration       = [double]$time
                RunId          = $RunId
                FailureMessage = $failureMsg
            })
        }
    }

    return @{ Tests = $tests.ToArray() }
}

function Read-JsonResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $RunId
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JSON file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "File '$Path' is not valid JSON: $($_.Exception.Message)"
    }

    $rootProps = @($data.PSObject.Properties.Name)
    if ($rootProps -notcontains 'tests') {
        throw "JSON file '$Path' is missing required 'tests' array"
    }
    if ($null -eq $data.tests) {
        throw "JSON file '$Path' has a null 'tests' array"
    }

    $tests = New-Object System.Collections.Generic.List[hashtable]
    foreach ($t in @($data.tests)) {
        $names = @($t.PSObject.Properties.Name)
        $duration = 0.0
        if (($names -contains 'duration') -and ($null -ne $t.duration)) {
            $duration = [double]$t.duration
        }
        $failureMsg = $null
        if ($names -contains 'failureMessage') {
            $failureMsg = $t.failureMessage
        }
        $suite = ''
        if ($names -contains 'suite') { $suite = [string]$t.suite }
        elseif ($names -contains 'classname') { $suite = [string]$t.classname }

        $tests.Add(@{
            Name           = [string]$t.name
            Suite          = $suite
            Status         = [string]$t.status
            Duration       = $duration
            RunId          = $RunId
            FailureMessage = $failureMsg
        })
    }
    return @{ Tests = $tests.ToArray() }
}

function Read-TestResultsFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $RunId
    )
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { return Read-JUnitXmlResults -Path $Path -RunId $RunId }
        '.json' { return Read-JsonResults     -Path $Path -RunId $RunId }
        default { throw "Unsupported test result file extension '$ext' for path '$Path'" }
    }
}

function Get-AggregateTotals {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()] $Tests)

    $passed = 0; $failed = 0; $skipped = 0; $duration = 0.0
    foreach ($t in @($Tests)) {
        switch ($t.Status) {
            'passed'  { $passed++ }
            'failed'  { $failed++ }
            'skipped' { $skipped++ }
        }
        $duration += [double]$t.Duration
    }
    return @{
        Total    = $passed + $failed + $skipped
        Passed   = $passed
        Failed   = $failed
        Skipped  = $skipped
        # Round to 2dp to keep totals stable in markdown / assertions.
        Duration = [math]::Round($duration, 2)
    }
}

function Find-FlakyTests {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()] $Tests)

    # Group by Suite + Name. A test is flaky if it has both a passed run
    # and a failed run somewhere in the input. Skips don't count either way.
    $groups = @{}
    foreach ($t in @($Tests)) {
        $key = '{0}::{1}' -f $t.Suite, $t.Name
        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = @{
                Suite = $t.Suite
                Name = $t.Name
                PassCount = 0
                FailCount = 0
                Runs = New-Object System.Collections.Generic.List[string]
            }
        }
        switch ($t.Status) {
            'passed' { $groups[$key].PassCount++; $groups[$key].Runs.Add($t.RunId) }
            'failed' { $groups[$key].FailCount++; $groups[$key].Runs.Add($t.RunId) }
        }
    }

    [hashtable[]] $flaky = @()
    foreach ($g in $groups.Values) {
        if ($g.PassCount -gt 0 -and $g.FailCount -gt 0) {
            $flaky += @{
                Name      = $g.Name
                Suite     = $g.Suite
                PassCount = $g.PassCount
                FailCount = $g.FailCount
                Runs      = $g.Runs.ToArray()
            }
        }
    }

    # Sort for deterministic markdown output.
    if ($flaky.Count -gt 1) {
        $flaky = [hashtable[]]($flaky | Sort-Object Suite, Name)
    }
    # The leading comma forces PowerShell to return the array as a single
    # value rather than enumerating it (which would unwrap a 0/1 element
    # array into $null / a bare hashtable at the call site).
    return ,$flaky
}

function Format-MarkdownSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()] $Tests)

    $totals = Get-AggregateTotals -Tests $Tests
    $flaky  = Find-FlakyTests     -Tests $Tests
    $failures = @($Tests | Where-Object { $_.Status -eq 'failed' })

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('## Test Results')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Passed | Failed | Skipped | Total | Duration |')
    [void]$sb.AppendLine('| ------ | ------ | ------- | ----- | -------- |')
    [void]$sb.AppendLine(('| {0} | {1} | {2} | {3} | {4:F2}s |' -f $totals.Passed, $totals.Failed, $totals.Skipped, $totals.Total, $totals.Duration))
    [void]$sb.AppendLine('')

    if ($totals.Failed -eq 0 -and $flaky.Count -eq 0) {
        [void]$sb.AppendLine('All tests passed.')
        return $sb.ToString()
    }

    if ($failures.Count -gt 0) {
        [void]$sb.AppendLine('### Failures')
        [void]$sb.AppendLine('')
        foreach ($f in ($failures | Sort-Object Suite, Name, RunId)) {
            $msg = if ($f.FailureMessage) { $f.FailureMessage } else { '(no message)' }
            [void]$sb.AppendLine(('- **{0} / {1}** (run `{2}`): {3}' -f $f.Suite, $f.Name, $f.RunId, $msg))
        }
        [void]$sb.AppendLine('')
    }

    if ($flaky.Count -gt 0) {
        [void]$sb.AppendLine('### Flaky tests')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('| Suite | Test | Passed | Failed |')
        [void]$sb.AppendLine('| ----- | ---- | ------ | ------ |')
        foreach ($f in $flaky) {
            [void]$sb.AppendLine(('| {0} | {1} | {2} | {3} |' -f $f.Suite, $f.Name, $f.PassCount, $f.FailCount))
        }
        [void]$sb.AppendLine('')
    }

    return $sb.ToString()
}

function Invoke-AggregateTestResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $InputDirectory,
        [string] $OutputMarkdown
    )

    if (-not (Test-Path -LiteralPath $InputDirectory -PathType Container)) {
        throw "Input directory not found: $InputDirectory"
    }

    # We accept .xml and .json. We treat each file as a separate matrix run,
    # using the file's basename as the RunId.
    $files = @(Get-ChildItem -LiteralPath $InputDirectory -File |
        Where-Object { $_.Extension -in '.xml', '.json' } |
        Sort-Object Name)
    if ($files.Count -eq 0) {
        throw "No test result files (*.xml, *.json) found in '$InputDirectory'"
    }

    $allTests = New-Object System.Collections.Generic.List[hashtable]
    foreach ($file in $files) {
        $runId = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $parsed = Read-TestResultsFile -Path $file.FullName -RunId $runId
        foreach ($t in $parsed.Tests) { $allTests.Add($t) }
    }

    $tests = $allTests.ToArray()
    $totals = Get-AggregateTotals -Tests $tests
    $flaky  = Find-FlakyTests     -Tests $tests
    $md     = Format-MarkdownSummary -Tests $tests

    if ($OutputMarkdown) {
        $dir = Split-Path -Parent $OutputMarkdown
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $OutputMarkdown -Value $md -Encoding utf8
    }

    return @{
        Totals      = $totals
        Flaky       = $flaky
        Tests       = $tests
        Markdown    = $md
        FailureExit = if ($totals.Failed -gt 0) { 1 } else { 0 }
        Files       = $files | ForEach-Object { $_.FullName }
    }
}

Export-ModuleMember -Function `
    Read-JUnitXmlResults, `
    Read-JsonResults, `
    Read-TestResultsFile, `
    Get-AggregateTotals, `
    Find-FlakyTests, `
    Format-MarkdownSummary, `
    Invoke-AggregateTestResults
