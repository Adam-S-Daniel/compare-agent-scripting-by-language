# Test Results Aggregator module.
# Parses JUnit XML and JSON test result files, aggregates across runs,
# detects flaky tests (same test name passes in some runs and fails in others),
# and renders a markdown summary for GitHub Actions job summaries.

Set-StrictMode -Version Latest

function Import-JUnitResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JUnit file not found: $Path"
    }

    try {
        [xml]$doc = Get-Content -LiteralPath $Path -Raw
    } catch {
        throw "Failed to parse JUnit XML '$Path': $($_.Exception.Message)"
    }

    $results = New-Object System.Collections.Generic.List[object]

    # Accept either <testsuites> root or single <testsuite> root.
    # Note: PowerShell's XML adapter aliases .Name to a `name` attribute if one exists,
    # so we use LocalName to reliably read the tag name.
    $rootTag = $doc.DocumentElement.LocalName
    $suites = @()
    if ($rootTag -eq 'testsuites') {
        $suites = @($doc.DocumentElement.testsuite)
    } elseif ($rootTag -eq 'testsuite') {
        $suites = @($doc.DocumentElement)
    } else {
        throw "Unexpected JUnit root element '$rootTag' in $Path"
    }

    foreach ($suite in $suites) {
        if ($null -eq $suite) { continue }
        $suiteName = [string]$suite.name
        $cases = @()
        if ($suite.PSObject.Properties['testcase'] -and $suite.testcase) {
            $cases = @($suite.testcase)
        }
        foreach ($tc in $cases) {
            $hasProp = { param($o,$n) $o.PSObject.Properties[$n] -and $null -ne $o.$n }
            $name = [string]$tc.name
            $class = if (& $hasProp $tc 'classname') { [string]$tc.classname } else { $suiteName }
            $fullName = if ($class) { "$class.$name" } else { $name }

            $duration = 0.0
            if (& $hasProp $tc 'time') {
                [double]::TryParse([string]$tc.time, [ref]$duration) | Out-Null
            }

            $status = 'passed'
            if ((& $hasProp $tc 'failure') -or (& $hasProp $tc 'error')) {
                $status = 'failed'
            } elseif (& $hasProp $tc 'skipped') {
                $status = 'skipped'
            }

            $results.Add([pscustomobject]@{
                Name     = $fullName
                Status   = $status
                Duration = [double]$duration
                Source   = $Path
            })
        }
    }

    return ,$results.ToArray()
}

function Import-JsonResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON '$Path': $($_.Exception.Message)"
    }

    if (-not $data.PSObject.Properties['tests']) {
        throw "JSON test file '$Path' is missing required 'tests' array"
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($t in @($data.tests)) {
        $name = [string]$t.name
        if (-not $name) { throw "Test in '$Path' is missing a name" }
        $status = [string]$t.status
        if ($status -notin @('passed','failed','skipped')) {
            throw "Test '$name' in '$Path' has invalid status '$status'"
        }
        $duration = 0.0
        if ($t.PSObject.Properties['duration'] -and $null -ne $t.duration) {
            [double]::TryParse([string]$t.duration, [ref]$duration) | Out-Null
        }
        $results.Add([pscustomobject]@{
            Name     = $name
            Status   = $status
            Duration = [double]$duration
            Source   = $Path
        })
    }
    return ,$results.ToArray()
}

function Import-TestResults {
    # Auto-dispatch by extension.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { return Import-JUnitResults -Path $Path }
        '.json' { return Import-JsonResults -Path $Path }
        default { throw "Unsupported test result file extension: $ext ($Path)" }
    }
}

function Merge-TestResults {
    # Aggregate a flat list of result records into totals + flaky list.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][object[]]$Results
    )

    $all = @($Results)
    $passed = 0; $failed = 0; $skipped = 0; [double]$duration = 0
    foreach ($r in $all) {
        switch ($r.Status) {
            'passed'  { $passed++  }
            'failed'  { $failed++  }
            'skipped' { $skipped++ }
        }
        $duration += [double]$r.Duration
    }

    # Group by test name to find flaky (both passed and failed observed).
    $flaky = New-Object System.Collections.Generic.List[string]
    $groups = $all | Group-Object -Property Name
    foreach ($g in $groups) {
        $statuses = $g.Group | ForEach-Object { $_.Status } | Sort-Object -Unique
        if (($statuses -contains 'passed') -and ($statuses -contains 'failed')) {
            $flaky.Add($g.Name)
        }
    }

    return [pscustomobject]@{
        Total    = $all.Count
        Passed   = $passed
        Failed   = $failed
        Skipped  = $skipped
        Duration = [double]$duration
        Flaky    = @($flaky | Sort-Object)
        Results  = $all
    }
}

function Format-MarkdownSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Aggregate
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Test Results Summary')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Metric | Count |')
    [void]$sb.AppendLine('|---|---|')
    [void]$sb.AppendLine("| Total | $($Aggregate.Total) |")
    [void]$sb.AppendLine("| Passed | $($Aggregate.Passed) |")
    [void]$sb.AppendLine("| Failed | $($Aggregate.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($Aggregate.Skipped) |")
    [void]$sb.AppendLine(("| Duration | {0:N2}s |" -f $Aggregate.Duration))
    [void]$sb.AppendLine()

    if ($Aggregate.Failed -gt 0) {
        [void]$sb.AppendLine('## Failed Tests')
        [void]$sb.AppendLine()
        $failedNames = $Aggregate.Results | Where-Object Status -EQ 'failed' |
            ForEach-Object { $_.Name } | Sort-Object -Unique
        foreach ($n in $failedNames) {
            [void]$sb.AppendLine("- $n")
        }
        [void]$sb.AppendLine()
    }

    [void]$sb.AppendLine('## Flaky Tests')
    [void]$sb.AppendLine()
    if ($Aggregate.Flaky.Count -eq 0) {
        [void]$sb.AppendLine('_None detected._')
    } else {
        foreach ($n in $Aggregate.Flaky) {
            [void]$sb.AppendLine("- $n")
        }
    }
    [void]$sb.AppendLine()

    $status = if ($Aggregate.Failed -gt 0) { 'FAILURE' } else { 'SUCCESS' }
    [void]$sb.AppendLine("**Overall status: $status**")
    return $sb.ToString()
}

function Invoke-Aggregator {
    # Main entry point: walk a directory for .xml / .json fixtures,
    # aggregate, and write markdown to the given output path.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath
    )

    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Input path does not exist: $InputPath"
    }

    $files = @()
    if ((Get-Item -LiteralPath $InputPath).PSIsContainer) {
        $files = @(Get-ChildItem -LiteralPath $InputPath -Recurse -File |
            Where-Object { $_.Extension -in '.xml','.json' } |
            Sort-Object FullName)
    } else {
        $files = @(Get-Item -LiteralPath $InputPath)
    }

    if (@($files).Count -eq 0) {
        throw "No test result files (*.xml, *.json) found under '$InputPath'"
    }

    $all = New-Object System.Collections.Generic.List[object]
    foreach ($f in $files) {
        Write-Verbose "Parsing $($f.FullName)"
        foreach ($r in (Import-TestResults -Path $f.FullName)) {
            $all.Add($r)
        }
    }

    $agg = Merge-TestResults -Results $all.ToArray()
    $md = Format-MarkdownSummary -Aggregate $agg

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $md -Encoding utf8

    # Also emit key totals to stdout so CI can grep them.
    Write-Host "TOTAL=$($agg.Total)"
    Write-Host "PASSED=$($agg.Passed)"
    Write-Host "FAILED=$($agg.Failed)"
    Write-Host "SKIPPED=$($agg.Skipped)"
    Write-Host ("DURATION={0:N2}" -f $agg.Duration)
    Write-Host "FLAKY_COUNT=$($agg.Flaky.Count)"
    if ($agg.Flaky.Count -gt 0) {
        Write-Host "FLAKY=$($agg.Flaky -join ',')"
    }

    return $agg
}

Export-ModuleMember -Function Import-JUnitResults, Import-JsonResults, Import-TestResults, Merge-TestResults, Format-MarkdownSummary, Invoke-Aggregator
