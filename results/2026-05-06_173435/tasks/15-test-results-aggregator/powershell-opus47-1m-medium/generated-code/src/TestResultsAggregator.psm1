# TestResultsAggregator
# Parses JUnit XML and JSON test result files, aggregates across multiple runs
# (matrix builds), detects flaky tests, and renders a markdown summary that
# can be dropped into $GITHUB_STEP_SUMMARY.
#
# Each test case is represented as a PSCustomObject with shape:
#   Name             string  - test name (classname.name for JUnit)
#   Status           string  - 'Passed' | 'Failed' | 'Skipped'
#   DurationSeconds  double  - duration in seconds
#   RunName          string  - which input file/run produced this case
#   Message          string  - failure/skip message (may be empty)
#
# StrictMode is intentionally NOT enabled module-wide: parsed JUnit XML
# elements expose children as dynamic properties that are absent for cases
# without failures/skips, and strict mode would throw on every miss.

function Read-JUnitTestResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [string] $RunName
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JUnit file not found: $Path"
    }
    if (-not $RunName) { $RunName = [System.IO.Path]::GetFileNameWithoutExtension($Path) }

    try {
        $xml = New-Object System.Xml.XmlDocument
        $xml.Load((Resolve-Path -LiteralPath $Path).Path)
    } catch {
        throw "Failed to parse XML file '$Path': $($_.Exception.Message)"
    }

    $caseNodes = $xml.SelectNodes('//testcase')
    $cases = [System.Collections.Generic.List[object]]::new()
    foreach ($tc in $caseNodes) {
        $failure = $tc.SelectSingleNode('failure')
        $errorN  = $tc.SelectSingleNode('error')
        $skipped = $tc.SelectSingleNode('skipped')

        $status  = 'Passed'
        $message = $null
        if ($failure) { $status = 'Failed';  $message = $failure.GetAttribute('message') }
        elseif ($errorN) { $status = 'Failed'; $message = $errorN.GetAttribute('message') }
        elseif ($skipped) { $status = 'Skipped'; $message = $skipped.GetAttribute('message') }

        # Use the bare test name as the identity for cross-run flaky detection;
        # classname is preserved separately for context.
        $className = $tc.GetAttribute('classname')
        $name      = $tc.GetAttribute('name')

        $duration = 0.0
        $timeAttr = $tc.GetAttribute('time')
        if ($timeAttr) { [double]::TryParse($timeAttr, [ref]$duration) | Out-Null }

        $cases.Add([pscustomobject]@{
            Name            = $name
            ClassName       = $className
            Status          = $status
            DurationSeconds = $duration
            RunName         = $RunName
            Message         = $message
        })
    }

    # Emit each case to the pipeline; callers wrap with @() if they need a guaranteed array.
    $cases.ToArray() | Write-Output
}

function Read-JsonTestResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [string] $RunName
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }
    if (-not $RunName) { $RunName = [System.IO.Path]::GetFileNameWithoutExtension($Path) }

    try {
        $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse JSON file '$Path': $($_.Exception.Message)"
    }

    # Accept either { tests: [...] } or a top-level array.
    $rawTests = @()
    if ($data -is [System.Array]) {
        $rawTests = $data
    } elseif ($data.PSObject.Properties.Name -contains 'tests') {
        $rawTests = @($data.tests)
    } else {
        $rawTests = @($data)
    }

    $cases = [System.Collections.Generic.List[object]]::new()
    foreach ($t in $rawTests) {
        $props = $t.PSObject.Properties.Name
        $statusRaw = if ($props -contains 'status') { "$($t.status)" } else { 'passed' }
        $status = switch -Regex ($statusRaw.ToLowerInvariant()) {
            '^pass'  { 'Passed';  break }
            '^fail'  { 'Failed';  break }
            '^skip'  { 'Skipped'; break }
            '^error' { 'Failed';  break }
            default  { 'Passed' }
        }

        $duration = 0.0
        if ($props -contains 'duration_ms' -and $t.duration_ms) {
            $duration = [double]$t.duration_ms / 1000.0
        } elseif ($props -contains 'duration_seconds' -and $t.duration_seconds) {
            $duration = [double]$t.duration_seconds
        } elseif ($props -contains 'duration' -and $t.duration) {
            $duration = [double]$t.duration
        }

        $message = if ($props -contains 'message') { "$($t.message)" } else { $null }

        $cases.Add([pscustomobject]@{
            Name            = "$($t.name)"
            Status          = $status
            DurationSeconds = $duration
            RunName         = $RunName
            Message         = $message
        })
    }

    # Emit each case to the pipeline; callers wrap with @() if they need a guaranteed array.
    $cases.ToArray() | Write-Output
}

function Read-TestResultDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Input directory not found: $Path"
    }

    $all = [System.Collections.Generic.List[object]]::new()
    $files = Get-ChildItem -LiteralPath $Path -File | Sort-Object Name
    foreach ($f in $files) {
        $runName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        switch -Regex ($f.Extension.ToLowerInvariant()) {
            '\.xml$'  { foreach ($c in (Read-JUnitTestResult -Path $f.FullName -RunName $runName)) { $all.Add($c) } }
            '\.json$' { foreach ($c in (Read-JsonTestResult  -Path $f.FullName -RunName $runName)) { $all.Add($c) } }
            default   { Write-Verbose "Skipping unrecognized file: $($f.Name)" }
        }
    }
    $all.ToArray() | Write-Output
}

function Get-TestResultSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Cases
    )
    $passed   = @($Cases | Where-Object { $_.Status -eq 'Passed' }).Count
    $failed   = @($Cases | Where-Object { $_.Status -eq 'Failed' }).Count
    $skipped  = @($Cases | Where-Object { $_.Status -eq 'Skipped' }).Count
    $duration = ($Cases | Measure-Object -Property DurationSeconds -Sum).Sum
    if (-not $duration) { $duration = 0.0 }

    [pscustomobject]@{
        Total           = $Cases.Count
        Passed          = $passed
        Failed          = $failed
        Skipped         = $skipped
        DurationSeconds = [math]::Round([double]$duration, 3)
    }
}

function Find-FlakyTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Cases
    )

    $flaky = [System.Collections.Generic.List[object]]::new()
    foreach ($group in ($Cases | Group-Object Name)) {
        $statuses = @($group.Group | Select-Object -ExpandProperty Status -Unique)
        # Flaky = test appeared as Passed in at least one run AND Failed in at least one run.
        if (($statuses -contains 'Passed') -and ($statuses -contains 'Failed')) {
            $passCount = @($group.Group | Where-Object { $_.Status -eq 'Passed' }).Count
            $failCount = @($group.Group | Where-Object { $_.Status -eq 'Failed' }).Count
            $flaky.Add([pscustomobject]@{
                Name   = $group.Name
                Runs   = $group.Count
                Passed = $passCount
                Failed = $failCount
            })
        }
    }
    $flaky.ToArray() | Write-Output
}

function Format-TestSummaryMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Cases
    )

    $summary = Get-TestResultSummary -Cases $Cases
    $flaky   = Find-FlakyTest -Cases $Cases
    $failed  = @($Cases | Where-Object { $_.Status -eq 'Failed' })

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Test Results')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Totals')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("- Total: $($summary.Total)")
    [void]$sb.AppendLine("- Passed: $($summary.Passed)")
    [void]$sb.AppendLine("- Failed: $($summary.Failed)")
    [void]$sb.AppendLine("- Skipped: $($summary.Skipped)")
    [void]$sb.AppendLine("- Duration: $($summary.DurationSeconds)s")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Flaky Tests')
    [void]$sb.AppendLine('')
    if ($flaky.Count -gt 0) {
        [void]$sb.AppendLine('| Test | Runs | Passed | Failed |')
        [void]$sb.AppendLine('| --- | --- | --- | --- |')
        foreach ($f in $flaky) {
            [void]$sb.AppendLine("| $($f.Name) | $($f.Runs) | $($f.Passed) | $($f.Failed) |")
        }
    } else {
        [void]$sb.AppendLine('No flaky tests detected.')
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Failures')
    [void]$sb.AppendLine('')
    if ($failed.Count -gt 0) {
        [void]$sb.AppendLine('| Test | Run | Message |')
        [void]$sb.AppendLine('| --- | --- | --- |')
        foreach ($c in $failed) {
            $msgRaw = if ($c.PSObject.Properties.Name -contains 'Message') { "$($c.Message)" } else { '' }
            $msg = ($msgRaw -replace '\r?\n', ' ').Trim()
            if (-not $msg) { $msg = '(no message)' }
            [void]$sb.AppendLine("| $($c.Name) | $($c.RunName) | $msg |")
        }
    } else {
        [void]$sb.AppendLine('No failures.')
    }
    return $sb.ToString()
}

function Invoke-TestResultsAggregator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $InputDirectory,
        [Parameter(Mandatory)] [string] $OutputPath
    )

    $cases = Read-TestResultDirectory -Path $InputDirectory
    if ($cases.Count -eq 0) {
        throw "No recognized test result files (.xml or .json) found in '$InputDirectory'."
    }
    $md = Format-TestSummaryMarkdown -Cases $cases
    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $md -Encoding UTF8
    return Get-TestResultSummary -Cases $cases
}

Export-ModuleMember -Function `
    Read-JUnitTestResult, Read-JsonTestResult, Read-TestResultDirectory, `
    Get-TestResultSummary, Find-FlakyTest, Format-TestSummaryMarkdown, `
    Invoke-TestResultsAggregator
