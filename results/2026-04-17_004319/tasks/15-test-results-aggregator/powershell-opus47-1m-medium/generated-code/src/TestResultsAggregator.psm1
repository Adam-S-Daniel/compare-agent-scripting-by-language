# TestResultsAggregator.psm1
# Parses JUnit XML and JSON test result files, aggregates them (simulating
# matrix builds), detects flaky tests, and produces a GitHub-Actions-ready
# markdown summary.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-JUnitXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )
    process {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "JUnit XML file not found: $Path"
        }
        try {
            [xml]$xml = Get-Content -LiteralPath $Path -Raw
        } catch {
            throw "Failed to parse JUnit XML '$Path': $($_.Exception.Message)"
        }

        $results = [System.Collections.Generic.List[object]]::new()
        # Support both <testsuites><testsuite/></testsuites> and top-level <testsuite>.
        $suites = @()
        if ($xml.testsuites) {
            $suites = @($xml.testsuites.testsuite)
        } elseif ($xml.testsuite) {
            $suites = @($xml.testsuite)
        }
        foreach ($suite in $suites) {
            if (-not $suite) { continue }
            $suiteName = [string]$suite.name
            foreach ($tc in @($suite.testcase)) {
                if (-not $tc) { continue }
                # Use PSObject.Properties for membership checks — avoids strict-mode
                # failures when the XML child element is absent.
                $tcProps = $tc.PSObject.Properties.Name
                $status = 'passed'
                if ('failure' -in $tcProps -or 'error' -in $tcProps) { $status = 'failed' }
                elseif ('skipped' -in $tcProps) { $status = 'skipped' }

                $duration = 0.0
                if ('time' -in $tcProps) { [double]::TryParse([string]$tc.time, [ref]$duration) | Out-Null }

                $results.Add([pscustomobject]@{
                    Suite    = $suiteName
                    Name     = [string]$tc.name
                    FullName = "$suiteName.$($tc.name)"
                    Status   = $status
                    Duration = $duration
                })
            }
        }
        [pscustomobject]@{
            Source  = $Path
            Format  = 'junit'
            Results = $results.ToArray()
        }
    }
}

function Import-TestResultJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )
    process {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "JSON test result file not found: $Path"
        }
        try {
            $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        } catch {
            throw "Failed to parse JSON '$Path': $($_.Exception.Message)"
        }

        $results = [System.Collections.Generic.List[object]]::new()
        $tests = @()
        if ($data.PSObject.Properties.Name -contains 'tests') { $tests = @($data.tests) }
        elseif ($data -is [System.Collections.IEnumerable]) { $tests = @($data) }

        foreach ($t in $tests) {
            $suiteName = if ($t.PSObject.Properties.Name -contains 'suite') { [string]$t.suite } else { 'default' }
            $name      = [string]$t.name
            $status    = ([string]$t.status).ToLowerInvariant()
            if ($status -notin 'passed','failed','skipped') {
                throw "Unknown test status '$status' in $Path for test '$name'"
            }
            $duration = 0.0
            if ($t.PSObject.Properties.Name -contains 'duration') {
                [double]::TryParse([string]$t.duration, [ref]$duration) | Out-Null
            }
            $results.Add([pscustomobject]@{
                Suite    = $suiteName
                Name     = $name
                FullName = "$suiteName.$name"
                Status   = $status
                Duration = $duration
            })
        }
        [pscustomobject]@{
            Source  = $Path
            Format  = 'json'
            Results = $results.ToArray()
        }
    }
}

function Import-TestResultFile {
    # Dispatch by extension.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { Import-JUnitXml -Path $Path }
        '.json' { Import-TestResultJson -Path $Path }
        default { throw "Unsupported test result format: $ext (file: $Path)" }
    }
}

function Merge-TestResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Runs
    )
    $allResults = [System.Collections.Generic.List[object]]::new()
    foreach ($run in $Runs) {
        foreach ($r in $run.Results) { $allResults.Add($r) }
    }

    $passed  = @($allResults | Where-Object Status -eq 'passed').Count
    $failed  = @($allResults | Where-Object Status -eq 'failed').Count
    $skipped = @($allResults | Where-Object Status -eq 'skipped').Count
    $duration = ($allResults | Measure-Object -Property Duration -Sum).Sum
    if (-not $duration) { $duration = 0.0 }

    # Flaky: same FullName has both passed and failed statuses across runs.
    $flaky = [System.Collections.Generic.List[object]]::new()
    $byName = $allResults | Group-Object -Property FullName
    foreach ($grp in $byName) {
        $statuses = $grp.Group | Select-Object -ExpandProperty Status -Unique
        if (($statuses -contains 'passed') -and ($statuses -contains 'failed')) {
            $flaky.Add([pscustomobject]@{
                Name       = $grp.Name
                PassCount  = @($grp.Group | Where-Object Status -eq 'passed').Count
                FailCount  = @($grp.Group | Where-Object Status -eq 'failed').Count
                TotalRuns  = $grp.Count
            })
        }
    }

    [pscustomobject]@{
        FileCount = $Runs.Count
        Total     = $allResults.Count
        Passed    = $passed
        Failed    = $failed
        Skipped   = $skipped
        Duration  = [math]::Round([double]$duration, 3)
        Flaky     = $flaky.ToArray()
        Runs      = $Runs
    }
}

function ConvertTo-MarkdownSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Aggregate)

    $status = if ($Aggregate.Failed -gt 0) { 'FAILED' } else { 'PASSED' }
    $icon   = if ($Aggregate.Failed -gt 0) { ':x:' } else { ':white_check_mark:' }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Test Results Summary $icon")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("**Overall Status:** $status")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Metric | Value |')
    [void]$sb.AppendLine('| --- | --- |')
    [void]$sb.AppendLine("| Files Processed | $($Aggregate.FileCount) |")
    [void]$sb.AppendLine("| Total Tests | $($Aggregate.Total) |")
    [void]$sb.AppendLine("| Passed | $($Aggregate.Passed) |")
    [void]$sb.AppendLine("| Failed | $($Aggregate.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($Aggregate.Skipped) |")
    [void]$sb.AppendLine("| Duration (s) | $($Aggregate.Duration) |")
    [void]$sb.AppendLine("| Flaky Tests | $($Aggregate.Flaky.Count) |")
    [void]$sb.AppendLine('')

    if ($Aggregate.Flaky.Count -gt 0) {
        [void]$sb.AppendLine('## :warning: Flaky Tests')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('| Test | Passes | Failures | Runs |')
        [void]$sb.AppendLine('| --- | --- | --- | --- |')
        foreach ($f in $Aggregate.Flaky) {
            [void]$sb.AppendLine("| $($f.Name) | $($f.PassCount) | $($f.FailCount) | $($f.TotalRuns) |")
        }
        [void]$sb.AppendLine('')
    }

    # Collect consistently failing tests (failed in every run that contains them).
    $failedTests = [System.Collections.Generic.List[string]]::new()
    $flakyNames = @($Aggregate.Flaky | Select-Object -ExpandProperty Name)
    $allResults = $Aggregate.Runs | ForEach-Object { $_.Results }
    $grouped = $allResults | Where-Object Status -eq 'failed' | Group-Object -Property FullName
    foreach ($g in $grouped) {
        if ($g.Name -notin $flakyNames) { [void]$failedTests.Add($g.Name) }
    }
    if ($failedTests.Count -gt 0) {
        [void]$sb.AppendLine('## :x: Failing Tests')
        [void]$sb.AppendLine('')
        foreach ($n in $failedTests) { [void]$sb.AppendLine("- $n") }
        [void]$sb.AppendLine('')
    }

    $sb.ToString()
}

function Invoke-TestResultsAggregation {
    # High-level entry point: discover files in a directory, aggregate, write
    # a markdown summary, and append it to $env:GITHUB_STEP_SUMMARY if set.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [string]$OutputPath
    )
    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Input path does not exist: $InputPath"
    }

    $files = if ((Get-Item -LiteralPath $InputPath).PSIsContainer) {
        Get-ChildItem -LiteralPath $InputPath -Recurse -File |
            Where-Object { $_.Extension -in '.xml','.json' } |
            Sort-Object FullName
    } else {
        @(Get-Item -LiteralPath $InputPath)
    }

    if (-not $files -or @($files).Count -eq 0) {
        throw "No test result files (.xml/.json) found under: $InputPath"
    }

    $runs = foreach ($f in $files) { Import-TestResultFile -Path $f.FullName }
    $aggregate = Merge-TestResults -Runs @($runs)
    $markdown  = ConvertTo-MarkdownSummary -Aggregate $aggregate

    if ($OutputPath) {
        Set-Content -LiteralPath $OutputPath -Value $markdown -Encoding utf8
    }
    if ($env:GITHUB_STEP_SUMMARY) {
        Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $markdown -Encoding utf8
    }

    # Always print a concise summary to stdout so CI logs are useful.
    Write-Host "Files processed: $($aggregate.FileCount)"
    Write-Host "Total: $($aggregate.Total) Passed: $($aggregate.Passed) Failed: $($aggregate.Failed) Skipped: $($aggregate.Skipped)"
    Write-Host "Flaky: $($aggregate.Flaky.Count)"
    Write-Host "Duration: $($aggregate.Duration)s"

    $aggregate
}

Export-ModuleMember -Function Import-JUnitXml, Import-TestResultJson, Import-TestResultFile,
    Merge-TestResults, ConvertTo-MarkdownSummary, Invoke-TestResultsAggregation
