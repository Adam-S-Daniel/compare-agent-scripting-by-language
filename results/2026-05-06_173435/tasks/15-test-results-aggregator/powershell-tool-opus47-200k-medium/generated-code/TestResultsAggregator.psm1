# TestResultsAggregator.psm1
# Parses test results (JUnit XML, JSON), aggregates across runs,
# detects flaky tests, and generates a markdown summary.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function ConvertFrom-JUnitXml {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JUnit XML file not found: $Path"
    }

    try {
        [xml]$xml = Get-Content -LiteralPath $Path -Raw
    } catch {
        throw "Failed to parse JUnit XML '$Path': $($_.Exception.Message)"
    }

    # Normalize: handle both <testsuites><testsuite>...</testsuite></testsuites>
    # and a single top-level <testsuite>.
    $suites = @()
    if ($xml.DocumentElement.Name -eq 'testsuites') {
        $suites = @($xml.testsuites.testsuite)
    } elseif ($xml.DocumentElement.Name -eq 'testsuite') {
        $suites = @($xml.testsuite)
    } else {
        throw "Unsupported JUnit XML root element: $($xml.DocumentElement.Name)"
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($suite in $suites) {
        if ($null -eq $suite) { continue }
        $suiteName = if ($suite.HasAttribute('name')) { $suite.name } else { '' }
        $cases = @()
        if ($suite.testcase) { $cases = @($suite.testcase) }
        foreach ($tc in $cases) {
            # Use SelectSingleNode to safely probe for child elements under StrictMode.
            $hasFailure = $null -ne $tc.SelectSingleNode('failure')
            $hasError   = $null -ne $tc.SelectSingleNode('error')
            $hasSkipped = $null -ne $tc.SelectSingleNode('skipped')
            $status = if ($hasFailure -or $hasError) { 'Failed' }
                      elseif ($hasSkipped) { 'Skipped' }
                      else { 'Passed' }

            $duration = 0.0
            if ($tc.HasAttribute('time')) {
                [double]::TryParse($tc.time, [ref]$duration) | Out-Null
            }

            $results.Add([pscustomobject]@{
                Name     = $tc.name
                Suite    = $suiteName
                Status   = $status
                Duration = $duration
            })
        }
    }
    return ,$results.ToArray()
}

function ConvertFrom-TestJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON test result file not found: $Path"
    }

    try {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse JSON '$Path': $($_.Exception.Message)"
    }

    $tests = @()
    if ($json.PSObject.Properties.Name -contains 'tests') {
        $tests = @($json.tests)
    } else {
        throw "JSON test result file missing 'tests' array: $Path"
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($t in $tests) {
        $status = if ($t.PSObject.Properties.Name -contains 'status') { [string]$t.status } else { 'unknown' }
        # Normalize status
        $normalized = switch -Regex ($status.ToLower()) {
            '^pass'        { 'Passed';  break }
            '^fail|^error' { 'Failed';  break }
            '^skip'        { 'Skipped'; break }
            default        { 'Failed' }
        }
        $duration = 0.0
        if ($t.PSObject.Properties.Name -contains 'duration') {
            [double]::TryParse([string]$t.duration, [ref]$duration) | Out-Null
        }
        $suite = if ($t.PSObject.Properties.Name -contains 'suite') { [string]$t.suite } else { '' }
        $results.Add([pscustomobject]@{
            Name     = [string]$t.name
            Suite    = $suite
            Status   = $normalized
            Duration = $duration
        })
    }
    return ,$results.ToArray()
}

function Get-TestResultsFromPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    switch ($ext) {
        '.xml'  { return ConvertFrom-JUnitXml -Path $Path }
        '.json' { return ConvertFrom-TestJson  -Path $Path }
        default { throw "Unsupported test result file type: $ext (path: $Path)" }
    }
}

function Get-AggregatedResults {
    [CmdletBinding()]
    param(
        # Array of arrays: one inner array of test result objects per "run".
        # Untyped to prevent PowerShell from flattening nested arrays during
        # parameter binding.
        [Parameter(Mandatory)]$Runs
    )
    # Coerce to a real array-of-arrays. If the caller passed a single run
    # (i.e. an array of test objects), wrap it.
    if ($Runs -isnot [System.Collections.IList] -and $Runs -isnot [System.Array]) {
        $Runs = @(,$Runs)
    }
    # If the first element looks like a test result (not an array of them),
    # treat the whole input as a single run.
    if ($Runs.Count -gt 0 -and $Runs[0] -isnot [System.Array] -and
        $Runs[0] -isnot [System.Collections.IList]) {
        $Runs = @(,$Runs)
    }

    $totalPassed  = 0
    $totalFailed  = 0
    $totalSkipped = 0
    $totalDuration = 0.0

    # Track per-test statuses across runs to find flaky tests
    $perTest = @{}

    foreach ($run in $Runs) {
        if ($null -eq $run) { continue }
        foreach ($r in $run) {
            switch ($r.Status) {
                'Passed'  { $totalPassed++ }
                'Failed'  { $totalFailed++ }
                'Skipped' { $totalSkipped++ }
            }
            $totalDuration += [double]$r.Duration
            $key = if ($r.Suite) { "$($r.Suite)::$($r.Name)" } else { $r.Name }
            if (-not $perTest.ContainsKey($key)) {
                $perTest[$key] = New-Object System.Collections.Generic.List[string]
            }
            $perTest[$key].Add($r.Status)
        }
    }

    $flaky = New-Object System.Collections.Generic.List[object]
    foreach ($key in $perTest.Keys) {
        $statuses = $perTest[$key]
        $hasPass = $statuses -contains 'Passed'
        $hasFail = $statuses -contains 'Failed'
        if ($hasPass -and $hasFail) {
            $flaky.Add([pscustomobject]@{
                Test         = $key
                Statuses     = $statuses.ToArray()
                PassCount    = @($statuses | Where-Object { $_ -eq 'Passed' }).Count
                FailCount    = @($statuses | Where-Object { $_ -eq 'Failed' }).Count
            })
        }
    }

    return [pscustomobject]@{
        TotalPassed   = $totalPassed
        TotalFailed   = $totalFailed
        TotalSkipped  = $totalSkipped
        TotalTests    = $totalPassed + $totalFailed + $totalSkipped
        TotalDuration = [math]::Round($totalDuration, 3)
        FlakyTests    = $flaky.ToArray() | Sort-Object Test
        RunCount      = $Runs.Count
    }
}

function New-MarkdownSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Aggregated)

    $a = $Aggregated
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Test Results Summary")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**Runs aggregated:** $($a.RunCount)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Metric | Count |")
    [void]$sb.AppendLine("| --- | --- |")
    [void]$sb.AppendLine("| Total | $($a.TotalTests) |")
    [void]$sb.AppendLine("| Passed | $($a.TotalPassed) |")
    [void]$sb.AppendLine("| Failed | $($a.TotalFailed) |")
    [void]$sb.AppendLine("| Skipped | $($a.TotalSkipped) |")
    [void]$sb.AppendLine("| Duration (s) | $($a.TotalDuration) |")
    [void]$sb.AppendLine("")

    if ($a.TotalFailed -gt 0) {
        [void]$sb.AppendLine("Status: FAILED")
    } else {
        [void]$sb.AppendLine("Status: PASSED")
    }
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("## Flaky Tests")
    [void]$sb.AppendLine("")
    if (($a.FlakyTests | Measure-Object).Count -eq 0) {
        [void]$sb.AppendLine("None detected.")
    } else {
        [void]$sb.AppendLine("| Test | Pass | Fail |")
        [void]$sb.AppendLine("| --- | --- | --- |")
        foreach ($f in $a.FlakyTests) {
            [void]$sb.AppendLine("| $($f.Test) | $($f.PassCount) | $($f.FailCount) |")
        }
    }
    return $sb.ToString()
}

function Invoke-Aggregator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputDir,
        [string]$OutputFile
    )
    if (-not (Test-Path -LiteralPath $InputDir)) {
        throw "Input directory not found: $InputDir"
    }
    $files = Get-ChildItem -LiteralPath $InputDir -File |
        Where-Object { $_.Extension -in '.xml','.json' } |
        Sort-Object Name
    if (-not $files) {
        throw "No .xml or .json test result files found in $InputDir"
    }
    $runs = @()
    foreach ($f in $files) {
        $runs += ,(Get-TestResultsFromPath -Path $f.FullName)
    }
    $agg = Get-AggregatedResults -Runs $runs
    $md = New-MarkdownSummary -Aggregated $agg
    if ($OutputFile) {
        $md | Set-Content -LiteralPath $OutputFile -Encoding utf8
    }
    return [pscustomobject]@{
        Aggregated = $agg
        Markdown   = $md
    }
}

Export-ModuleMember -Function ConvertFrom-JUnitXml, ConvertFrom-TestJson,
    Get-TestResultsFromPath, Get-AggregatedResults, New-MarkdownSummary,
    Invoke-Aggregator
