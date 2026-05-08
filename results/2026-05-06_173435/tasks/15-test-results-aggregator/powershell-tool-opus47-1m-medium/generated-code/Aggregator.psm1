# Test-results aggregator.
#
# Reads JUnit XML and JSON test result files, aggregates them across multiple
# "matrix" runs, identifies flaky tests (passed in some runs, failed in
# others), and emits a markdown summary suitable for $GITHUB_STEP_SUMMARY.
#
# Each parser produces a uniform record:
#   [pscustomobject]@{
#       File  = '<source path>'
#       Tests = @( @{ ClassName; Name; Status; Duration; Message } ... )
#   }
# Status is one of: passed, failed, skipped.

Set-StrictMode -Version Latest

# Safe property accessor — avoids "PropertyNotFoundException" under
# Set-StrictMode -Version Latest when reading optional fields off
# PSCustomObjects (JSON-derived) or [pscustomobject] hashtable literals.
function Get-Prop {
    param([Parameter(Mandatory)] $Object, [Parameter(Mandatory)] [string] $Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $props = $Object.PSObject.Properties
    if ($null -ne $props[$Name]) { return $props[$Name].Value }
    return $Default
}

function Read-JUnitXml {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JUnit file not found: $Path"
    }

    try {
        [xml]$doc = Get-Content -LiteralPath $Path -Raw
    } catch {
        throw "Failed to parse JUnit XML '$Path': $($_.Exception.Message)"
    }

    # Accept either <testsuites><testsuite>...</testsuite></testsuites> or a
    # single top-level <testsuite>. SelectNodes with '//testcase' covers both.
    $cases = $doc.SelectNodes('//testcase')
    if ($null -eq $cases) {
        throw "JUnit XML '$Path' contains no <testcase> elements"
    }

    $tests = foreach ($c in $cases) {
        $status = 'passed'
        $message = $null
        if ($c.SelectSingleNode('failure')) {
            $status = 'failed'
            $message = $c.SelectSingleNode('failure').GetAttribute('message')
        } elseif ($c.SelectSingleNode('error')) {
            $status = 'failed'
            $message = $c.SelectSingleNode('error').GetAttribute('message')
        } elseif ($c.SelectSingleNode('skipped')) {
            $status = 'skipped'
        }
        $duration = 0.0
        $rawTime = $c.GetAttribute('time')
        if ($rawTime) { [double]::TryParse($rawTime, [ref]$duration) | Out-Null }

        [pscustomobject]@{
            ClassName = $c.GetAttribute('classname')
            Name      = $c.GetAttribute('name')
            Status    = $status
            Duration  = [double]$duration
            Message   = $message
        }
    }

    [pscustomobject]@{
        File  = (Resolve-Path -LiteralPath $Path).Path
        Tests = @($tests)
    }
}

function Read-TestJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    try {
        $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse test JSON '$Path': $($_.Exception.Message)"
    }

    if ($null -eq $data.PSObject.Properties['tests']) {
        throw "Test JSON '$Path' is missing the 'tests' array"
    }

    $tests = foreach ($t in $data.tests) {
        $status = [string](Get-Prop $t 'status' 'passed')
        $status = $status.ToLowerInvariant()
        $duration = 0.0
        $rawDur = Get-Prop $t 'duration' 0
        [double]::TryParse([string]$rawDur, [ref]$duration) | Out-Null
        [pscustomobject]@{
            ClassName = [string](Get-Prop $t 'classname' '')
            Name      = [string](Get-Prop $t 'name' '')
            Status    = $status
            Duration  = [double]$duration
            Message   = Get-Prop $t 'message' $null
        }
    }

    [pscustomobject]@{
        File  = (Resolve-Path -LiteralPath $Path).Path
        Tests = @($tests)
    }
}

function Read-TestResultFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { Read-JUnitXml -Path $Path }
        '.json' { Read-TestJson -Path $Path }
        default { throw "Unsupported test result extension '$ext' for '$Path'" }
    }
}

function Merge-TestResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object[]] $Runs)

    $byKey = [ordered]@{}   # key -> list of {Status, Duration, Message, File}
    $files = New-Object System.Collections.Generic.List[object]
    $totalPassed = 0; $totalFailed = 0; $totalSkipped = 0; $totalDuration = 0.0

    foreach ($run in $Runs) {
        $fp = 0; $ff = 0; $fs = 0; $fd = 0.0
        foreach ($t in $run.Tests) {
            switch ($t.Status) {
                'passed'  { $totalPassed++;  $fp++ }
                'failed'  { $totalFailed++;  $ff++ }
                'skipped' { $totalSkipped++; $fs++ }
            }
            $totalDuration += $t.Duration
            $fd += $t.Duration

            $key = if ($t.ClassName) { "$($t.ClassName).$($t.Name)" } else { $t.Name }
            if (-not $byKey.Contains($key)) { $byKey[$key] = New-Object System.Collections.Generic.List[object] }
            $byKey[$key].Add([pscustomobject]@{
                Status   = $t.Status
                Duration = $t.Duration
                Message  = (Get-Prop $t 'Message' $null)
                File     = $run.File
            })
        }
        $files.Add([pscustomobject]@{
            File     = $run.File
            Passed   = $fp
            Failed   = $ff
            Skipped  = $fs
            Duration = $fd
        })
    }

    $flaky  = New-Object System.Collections.Generic.List[object]
    $failed = New-Object System.Collections.Generic.List[object]

    foreach ($key in $byKey.Keys) {
        $entries = $byKey[$key]
        $passCount = @($entries | Where-Object Status -eq 'passed').Count
        $failCount = @($entries | Where-Object Status -eq 'failed').Count
        $parts = $key -split '\.', 2
        $cls  = if ($parts.Count -eq 2) { $parts[0] } else { '' }
        $name = if ($parts.Count -eq 2) { $parts[1] } else { $parts[0] }

        if ($passCount -gt 0 -and $failCount -gt 0) {
            $flaky.Add([pscustomobject]@{
                Key       = $key
                ClassName = $cls
                Name      = $name
                PassCount = $passCount
                FailCount = $failCount
                Runs      = $entries.Count
            })
        } elseif ($failCount -gt 0 -and $passCount -eq 0) {
            $firstFail = @($entries | Where-Object Status -eq 'failed') | Select-Object -First 1
            $msg = if ($firstFail) { $firstFail.Message } else { $null }
            $failed.Add([pscustomobject]@{
                Key       = $key
                ClassName = $cls
                Name      = $name
                FailCount = $failCount
                Runs      = $entries.Count
                Message   = $msg
            })
        }
    }

    [pscustomobject]@{
        Totals = [pscustomobject]@{
            Passed   = $totalPassed
            Failed   = $totalFailed
            Skipped  = $totalSkipped
            Duration = [double]$totalDuration
            Runs     = $Runs.Count
        }
        Flaky  = $flaky.ToArray()
        Failed = $failed.ToArray()
        Files  = $files.ToArray()
    }
}

function Format-MarkdownSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object] $Aggregate)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Test Results')
    [void]$sb.AppendLine('')

    $t = $Aggregate.Totals
    $total = $t.Passed + $t.Failed + $t.Skipped
    $verdict = if ($t.Failed -eq 0) { 'PASS' } else { 'FAIL' }
    [void]$sb.AppendLine("**Overall:** $verdict across $($t.Runs) run(s) - $total tests, $('{0:N2}' -f $t.Duration)s")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Metric | Count |')
    [void]$sb.AppendLine('| --- | ---: |')
    [void]$sb.AppendLine("| Passed | $($t.Passed) |")
    [void]$sb.AppendLine("| Failed | $($t.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($t.Skipped) |")
    [void]$sb.AppendLine("| Duration (s) | $('{0:N2}' -f $t.Duration) |")
    [void]$sb.AppendLine('')

    [void]$sb.AppendLine('## Per-file breakdown')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| File | Passed | Failed | Skipped | Duration (s) |')
    [void]$sb.AppendLine('| --- | ---: | ---: | ---: | ---: |')
    foreach ($f in $Aggregate.Files) {
        $fname = Split-Path -Leaf $f.File
        [void]$sb.AppendLine("| $fname | $($f.Passed) | $($f.Failed) | $($f.Skipped) | $('{0:N2}' -f $f.Duration) |")
    }
    [void]$sb.AppendLine('')

    [void]$sb.AppendLine('## Flaky tests')
    [void]$sb.AppendLine('')
    if ($Aggregate.Flaky.Count -eq 0) {
        [void]$sb.AppendLine('_None._')
    } else {
        [void]$sb.AppendLine('| Test | Pass | Fail | Runs |')
        [void]$sb.AppendLine('| --- | ---: | ---: | ---: |')
        foreach ($x in $Aggregate.Flaky) {
            [void]$sb.AppendLine("| ``$($x.Key)`` | $($x.PassCount) | $($x.FailCount) | $($x.Runs) |")
        }
    }
    [void]$sb.AppendLine('')

    [void]$sb.AppendLine('## Failed tests')
    [void]$sb.AppendLine('')
    if ($Aggregate.Failed.Count -eq 0) {
        [void]$sb.AppendLine('_None._')
    } else {
        [void]$sb.AppendLine('| Test | Failures | Runs | Message |')
        [void]$sb.AppendLine('| --- | ---: | ---: | --- |')
        foreach ($x in $Aggregate.Failed) {
            $m = if ($x.Message) { ($x.Message -replace '\|','\|' -replace '[\r\n]+',' ') } else { '' }
            [void]$sb.AppendLine("| ``$($x.Key)`` | $($x.FailCount) | $($x.Runs) | $m |")
        }
    }
    [void]$sb.AppendLine('')

    $sb.ToString()
}

function Invoke-Aggregator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $InputDir,
        [Parameter(Mandatory)] [string] $OutFile
    )

    if (-not (Test-Path -LiteralPath $InputDir -PathType Container)) {
        throw "Input directory not found: $InputDir"
    }

    $files = Get-ChildItem -LiteralPath $InputDir -File |
        Where-Object { $_.Extension -in '.xml', '.json' } |
        Sort-Object Name

    if (-not $files) { throw "No .xml or .json result files found in $InputDir" }

    $runs = foreach ($f in $files) {
        try {
            Read-TestResultFile -Path $f.FullName
        } catch {
            Write-Warning "Skipping $($f.Name): $($_.Exception.Message)"
        }
    }

    if (-not $runs) { throw "No parseable result files in $InputDir" }

    $agg = Merge-TestResults -Runs @($runs)
    $md  = Format-MarkdownSummary -Aggregate $agg

    Set-Content -LiteralPath $OutFile -Value $md -Encoding UTF8
    [pscustomobject]@{
        OutFile  = (Resolve-Path -LiteralPath $OutFile).Path
        Aggregate = $agg
    }
}

Export-ModuleMember -Function Read-JUnitXml, Read-TestJson, Read-TestResultFile,
    Merge-TestResults, Format-MarkdownSummary, Invoke-Aggregator
