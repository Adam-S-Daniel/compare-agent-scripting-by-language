# TestResultsAggregator — parses JUnit XML and JSON test result files,
# aggregates results across runs, and renders a markdown summary suitable
# for the GitHub Actions $GITHUB_STEP_SUMMARY file.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function New-TestCase {
    param(
        [string]$Name,
        [string]$Suite,
        [ValidateSet('passed', 'failed', 'skipped')]
        [string]$Status,
        [double]$Duration,
        [string]$Source
    )
    [pscustomobject]@{
        Name     = $Name
        Suite    = $Suite
        Status   = $Status
        Duration = $Duration
        Source   = $Source
    }
}

function Read-JUnitXml {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JUnit XML file not found: $Path"
    }

    try {
        [xml]$doc = Get-Content -LiteralPath $Path -Raw
    } catch {
        throw "Failed to parse JUnit XML '$Path': $($_.Exception.Message)"
    }

    # Support both <testsuites><testsuite>...</testsuite></testsuites> and a
    # bare <testsuite> root. SelectNodes handles both shapes.
    $cases = [System.Collections.Generic.List[object]]::new()
    foreach ($suite in $doc.SelectNodes('//testsuite')) {
        $suiteName = $suite.GetAttribute('name')
        foreach ($tc in $suite.SelectNodes('testcase')) {
            $status = 'passed'
            if ($tc.SelectSingleNode('failure') -or $tc.SelectSingleNode('error')) {
                $status = 'failed'
            } elseif ($tc.SelectSingleNode('skipped')) {
                $status = 'skipped'
            }
            $durAttr = $tc.GetAttribute('time')
            $duration = 0.0
            if ($durAttr) { [double]::TryParse($durAttr, [ref]$duration) | Out-Null }
            $cases.Add((New-TestCase `
                -Name $tc.GetAttribute('name') `
                -Suite $suiteName `
                -Status $status `
                -Duration $duration `
                -Source (Split-Path -Leaf $Path)))
        }
    }

    [pscustomobject]@{
        Path  = $Path
        Cases = $cases.ToArray()
    }
}

function Read-TestResultJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    try {
        $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse JSON '$Path': $($_.Exception.Message)"
    }

    $suiteName = if ($data.PSObject.Properties['suite']) { $data.suite } else { '' }
    $rows = if ($data.PSObject.Properties['tests']) { $data.tests } else { $data }

    $cases = foreach ($t in $rows) {
        $status = "$($t.status)".ToLowerInvariant()
        if ($status -notin 'passed', 'failed', 'skipped') {
            throw "Unknown status '$status' for test '$($t.name)' in $Path"
        }
        $dur = 0.0
        if ($t.PSObject.Properties['duration']) { $dur = [double]$t.duration }
        New-TestCase -Name $t.name -Suite $suiteName -Status $status `
            -Duration $dur -Source (Split-Path -Leaf $Path)
    }

    [pscustomobject]@{
        Path  = $Path
        Cases = @($cases)
    }
}

function Import-TestResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { return Read-JUnitXml -Path $Path }
        '.json' { return Read-TestResultJson -Path $Path }
        default { throw "Unsupported test result format '$ext' for file '$Path'" }
    }
}

function Get-AggregatedResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Paths)

    $runs = foreach ($p in $Paths) { Import-TestResults -Path $p }
    $allCases = $runs.Cases

    $passed  = @($allCases | Where-Object Status -EQ 'passed').Count
    $failed  = @($allCases | Where-Object Status -EQ 'failed').Count
    $skipped = @($allCases | Where-Object Status -EQ 'skipped').Count
    $duration = ($allCases | Measure-Object -Property Duration -Sum).Sum
    if (-not $duration) { $duration = 0.0 }

    # Flaky: same test name observed with both a pass and a fail across runs.
    $flaky = @(
        $allCases |
            Group-Object Name |
            Where-Object {
                $statuses = $_.Group.Status | Sort-Object -Unique
                ($statuses -contains 'passed') -and ($statuses -contains 'failed')
            } |
            ForEach-Object {
                [pscustomobject]@{
                    Name      = $_.Name
                    Runs      = $_.Count
                    Passes    = @($_.Group | Where-Object Status -EQ 'passed').Count
                    Failures  = @($_.Group | Where-Object Status -EQ 'failed').Count
                }
            }
    )

    [pscustomobject]@{
        Runs   = $runs
        Cases  = $allCases
        Totals = [pscustomobject]@{
            Passed   = $passed
            Failed   = $failed
            Skipped  = $skipped
            Total    = $passed + $failed + $skipped
            Duration = [double]$duration
        }
        Flaky  = $flaky
    }
}

function Format-MarkdownSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Aggregation)

    $t = $Aggregation.Totals
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Test Results Summary')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Metric | Value |')
    [void]$sb.AppendLine('| --- | --- |')
    [void]$sb.AppendLine("| Passed | $($t.Passed) |")
    [void]$sb.AppendLine("| Failed | $($t.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($t.Skipped) |")
    [void]$sb.AppendLine("| Total | $($t.Total) |")
    [void]$sb.AppendLine(("| Duration | {0:N2}s |" -f $t.Duration))
    [void]$sb.AppendLine("| Runs | $($Aggregation.Runs.Count) |")
    [void]$sb.AppendLine()

    if ($t.Failed -gt 0) {
        [void]$sb.AppendLine('## Failures')
        [void]$sb.AppendLine()
        foreach ($c in ($Aggregation.Cases | Where-Object Status -EQ 'failed')) {
            [void]$sb.AppendLine("- **$($c.Name)** (suite: $($c.Suite), source: $($c.Source))")
        }
        [void]$sb.AppendLine()
    }

    [void]$sb.AppendLine('## Flaky Tests')
    [void]$sb.AppendLine()
    if ($Aggregation.Flaky.Count -eq 0) {
        [void]$sb.AppendLine('_No flaky tests detected._')
    } else {
        [void]$sb.AppendLine('| Test | Runs | Passes | Failures |')
        [void]$sb.AppendLine('| --- | --- | --- | --- |')
        foreach ($f in $Aggregation.Flaky) {
            [void]$sb.AppendLine("| $($f.Name) | $($f.Runs) | $($f.Passes) | $($f.Failures) |")
        }
    }

    $sb.ToString()
}

Export-ModuleMember -Function Read-JUnitXml, Read-TestResultJson, Import-TestResults,
    Get-AggregatedResults, Format-MarkdownSummary
