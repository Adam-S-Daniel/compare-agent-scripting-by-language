# TestResultsAggregator.psm1
#
# Parses test results from JUnit XML and JSON, aggregates across multiple
# files (simulating matrix build artifacts), detects flaky tests, and
# renders a Markdown summary suitable for $GITHUB_STEP_SUMMARY.
#
# Normalized result-set shape used throughout:
#   @{ Source; Format; Tests; Passed; Failed; Skipped; Total; Duration }
# where each Tests element is:
#   @{ Name; Status (passed|failed|skipped); Duration; Message; Suite }

$ErrorActionPreference = 'Stop'

function ConvertFrom-JUnitXml {
    <#
    .SYNOPSIS
        Parses a JUnit XML test-result file into a normalized result set.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JUnit XML file not found: $Path"
    }

    # [xml]-cast throws on malformed XML; wrap to give the caller a helpful message.
    try {
        [xml]$doc = Get-Content -LiteralPath $Path -Raw
    } catch {
        throw "Failed to parse '$Path' as XML: $($_.Exception.Message)"
    }

    # JUnit has two common roots: <testsuites> (wrapper) or bare <testsuite>.
    $root = $doc.DocumentElement
    $suites = switch ($root.LocalName) {
        'testsuites' { @($root.SelectNodes('./testsuite')) }
        'testsuite'  { @($root) }
        default      { throw "Not a JUnit XML document (root <$($root.LocalName)>): $Path" }
    }

    $tests = [System.Collections.Generic.List[object]]::new()
    foreach ($suite in $suites) {
        if ($null -eq $suite) { continue }
        $suiteName = [string]$suite.GetAttribute('name')
        foreach ($tc in @($suite.SelectNodes('./testcase'))) {
            $status  = 'passed'
            $message = $null
            # A testcase can carry zero or more nested markers. Order matters only
            # insofar as "any failure/error" wins over "skipped" wins over "passed".
            $failureNode = $tc.SelectSingleNode('./failure')
            $errorNode   = $tc.SelectSingleNode('./error')
            $skippedNode = $tc.SelectSingleNode('./skipped')
            if ($failureNode) {
                $status  = 'failed'
                $message = [string]$failureNode.GetAttribute('message')
                if (-not $message) { $message = $failureNode.InnerText }
            } elseif ($errorNode) {
                $status  = 'failed'
                $message = [string]$errorNode.GetAttribute('message')
                if (-not $message) { $message = $errorNode.InnerText }
            } elseif ($skippedNode) {
                $status = 'skipped'
            }

            $className = [string]$tc.GetAttribute('classname')
            $shortName = [string]$tc.GetAttribute('name')
            $fullName  = if ($className) { "$className.$shortName" } else { $shortName }

            $time = [string]$tc.GetAttribute('time')
            $duration = 0.0
            if ($time) {
                [void][double]::TryParse($time, [ref]$duration)
            }

            $tests.Add([pscustomobject]@{
                Name     = $fullName
                Status   = $status
                Duration = $duration
                Message  = $message
                Suite    = $suiteName
            }) | Out-Null
        }
    }

    New-ResultSet -Source $Path -Tests $tests.ToArray() -Format 'junit-xml'
}

function ConvertFrom-TestJson {
    <#
    .SYNOPSIS
        Parses a JSON test-result file into a normalized result set.
        Schema: { "duration"?: <seconds>, "tests": [ {name, status, duration?, message?, suite?} ] }
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JSON file not found: $Path"
    }

    try {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse '$Path' as JSON: $($_.Exception.Message)"
    }

    $propNames = @($json.PSObject.Properties.Name)
    if ($propNames -notcontains 'tests') {
        throw "JSON file missing required 'tests' array: $Path"
    }

    $validStatus = @('passed','failed','skipped')
    $tests = [System.Collections.Generic.List[object]]::new()
    foreach ($t in @($json.tests)) {
        if ($null -eq $t) { continue }
        $tProps = @($t.PSObject.Properties.Name)
        $status = [string]$t.status
        if ($validStatus -notcontains $status) {
            throw "Invalid test status '$status' in $Path (must be passed|failed|skipped)"
        }
        $duration = 0.0
        if ($tProps -contains 'duration' -and $null -ne $t.duration) {
            [void][double]::TryParse([string]$t.duration, [ref]$duration)
        }
        $tests.Add([pscustomobject]@{
            Name     = [string]$t.name
            Status   = $status
            Duration = $duration
            Message  = if ($tProps -contains 'message') { [string]$t.message } else { $null }
            Suite    = if ($tProps -contains 'suite')   { [string]$t.suite }   else { '' }
        }) | Out-Null
    }

    $explicit = $null
    if ($propNames -contains 'duration' -and $null -ne $json.duration) {
        $parsed = 0.0
        if ([double]::TryParse([string]$json.duration, [ref]$parsed)) { $explicit = $parsed }
    }

    New-ResultSet -Source $Path -Tests $tests.ToArray() -Format 'json' -ExplicitDuration $explicit
}

function New-ResultSet {
    # Internal factory. Keeps the normalized shape in one place.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Tests,
        [Parameter(Mandatory)][string]$Format,
        [object]$ExplicitDuration
    )
    $passed  = @($Tests | Where-Object { $_.Status -eq 'passed'  }).Count
    $failed  = @($Tests | Where-Object { $_.Status -eq 'failed'  }).Count
    $skipped = @($Tests | Where-Object { $_.Status -eq 'skipped' }).Count
    $duration = if ($null -ne $ExplicitDuration) {
        [double]$ExplicitDuration
    } else {
        [double](($Tests | Measure-Object -Property Duration -Sum).Sum)
    }
    [pscustomobject]@{
        Source   = $Source
        Format   = $Format
        Tests    = $Tests
        Total    = $Tests.Count
        Passed   = $passed
        Failed   = $failed
        Skipped  = $skipped
        Duration = [math]::Round($duration, 3)
    }
}

function Import-TestResults {
    <#
    .SYNOPSIS
        Discovers and parses every JUnit-XML/JSON test-result file at one or
        more paths (files or directories). Returns an array of result sets.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Path)

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) {
            throw "Path not found: $p"
        }
        $files = if (Test-Path -LiteralPath $p -PathType Container) {
            Get-ChildItem -LiteralPath $p -File -Recurse |
                Where-Object { $_.Extension -in '.xml', '.json' } |
                Sort-Object FullName
        } else {
            @(Get-Item -LiteralPath $p)
        }
        foreach ($f in $files) {
            switch ($f.Extension.ToLower()) {
                '.xml'  { $results.Add((ConvertFrom-JUnitXml -Path $f.FullName)) | Out-Null }
                '.json' { $results.Add((ConvertFrom-TestJson  -Path $f.FullName)) | Out-Null }
                default { Write-Warning "Unsupported extension, skipping: $($f.FullName)" }
            }
        }
    }
    # Emit each result set on the pipeline; callers wrap with @(...) when they
    # need .Count to be safe for 0/1 items.
    $results.ToArray()
}

function Get-AggregatedResults {
    <#
    .SYNOPSIS
        Aggregates per-file result sets into a single totals object.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ResultSets)

    $all = [System.Collections.Generic.List[object]]::new()
    foreach ($rs in $ResultSets) {
        foreach ($t in @($rs.Tests)) { $all.Add($t) | Out-Null }
    }
    $dur = [double](($ResultSets | Measure-Object -Property Duration -Sum).Sum)
    [pscustomobject]@{
        Files      = $ResultSets.Count
        TotalTests = $all.Count
        Passed     = @($all | Where-Object { $_.Status -eq 'passed'  }).Count
        Failed     = @($all | Where-Object { $_.Status -eq 'failed'  }).Count
        Skipped    = @($all | Where-Object { $_.Status -eq 'skipped' }).Count
        Duration   = [math]::Round($dur, 3)
        ResultSets = @($ResultSets)
    }
}

function Get-FlakyTest {
    <#
    .SYNOPSIS
        Returns tests that both passed AND failed across the provided result sets.
        Skipped-only runs don't count; only the pass/fail divergence matters.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ResultSets)

    $byName = @{}
    foreach ($rs in $ResultSets) {
        foreach ($t in @($rs.Tests)) {
            if (-not $byName.ContainsKey($t.Name)) {
                $byName[$t.Name] = [System.Collections.Generic.List[string]]::new()
            }
            [void]$byName[$t.Name].Add([string]$t.Status)
        }
    }
    $flaky = [System.Collections.Generic.List[object]]::new()
    foreach ($name in $byName.Keys) {
        $statuses = $byName[$name]
        if (($statuses -contains 'passed') -and ($statuses -contains 'failed')) {
            $flaky.Add([pscustomobject]@{
                Name    = $name
                Runs    = $statuses.Count
                Passed  = @($statuses | Where-Object { $_ -eq 'passed' }).Count
                Failed  = @($statuses | Where-Object { $_ -eq 'failed' }).Count
                Skipped = @($statuses | Where-Object { $_ -eq 'skipped' }).Count
            }) | Out-Null
        }
    }
    # Emit each flaky item on the pipeline. Callers wrap with @(...) to get a
    # safe count. Avoiding Write-Output -NoEnumerate here keeps @() semantics
    # simple: 0 items -> empty array; N items -> N-element array.
    $flaky | Sort-Object Name
}

function New-SummaryMarkdown {
    <#
    .SYNOPSIS
        Renders aggregated results + flaky list as Markdown for a GitHub Actions job summary.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Aggregated,
        [AllowEmptyCollection()][object[]]$FlakyTests = @()
    )
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Test Results Summary')
    [void]$sb.AppendLine('')

    # Totals
    [void]$sb.AppendLine('## Totals')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Metric | Value |')
    [void]$sb.AppendLine('| --- | ---: |')
    [void]$sb.AppendLine("| Result files | $($Aggregated.Files) |")
    [void]$sb.AppendLine("| Total tests  | $($Aggregated.TotalTests) |")
    [void]$sb.AppendLine("| Passed       | $($Aggregated.Passed) |")
    [void]$sb.AppendLine("| Failed       | $($Aggregated.Failed) |")
    [void]$sb.AppendLine("| Skipped      | $($Aggregated.Skipped) |")
    [void]$sb.AppendLine("| Duration (s) | $($Aggregated.Duration) |")
    [void]$sb.AppendLine('')

    # Status line
    $status = if ($Aggregated.TotalTests -eq 0) {
        '**Status:** NO TESTS'
    } elseif ($Aggregated.Failed -eq 0) {
        '**Status:** PASS (all tests passed)'
    } else {
        "**Status:** FAIL ($($Aggregated.Failed) failed)"
    }
    [void]$sb.AppendLine($status)
    [void]$sb.AppendLine('')

    # Flaky
    [void]$sb.AppendLine('## Flaky Tests')
    [void]$sb.AppendLine('')
    $fl = @($FlakyTests)
    if ($fl.Count -eq 0) {
        [void]$sb.AppendLine('No flaky tests detected.')
    } else {
        [void]$sb.AppendLine('| Test | Runs | Passed | Failed |')
        [void]$sb.AppendLine('| --- | ---: | ---: | ---: |')
        foreach ($f in $fl) {
            [void]$sb.AppendLine("| $($f.Name) | $($f.Runs) | $($f.Passed) | $($f.Failed) |")
        }
    }
    [void]$sb.AppendLine('')

    # Per-file breakdown
    [void]$sb.AppendLine('## Per-file Breakdown')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| File | Format | Tests | Passed | Failed | Skipped | Duration (s) |')
    [void]$sb.AppendLine('| --- | --- | ---: | ---: | ---: | ---: | ---: |')
    foreach ($rs in @($Aggregated.ResultSets)) {
        $fileName = [System.IO.Path]::GetFileName($rs.Source)
        [void]$sb.AppendLine("| $fileName | $($rs.Format) | $($rs.Total) | $($rs.Passed) | $($rs.Failed) | $($rs.Skipped) | $($rs.Duration) |")
    }

    $sb.ToString()
}

Export-ModuleMember -Function `
    ConvertFrom-JUnitXml, `
    ConvertFrom-TestJson, `
    Import-TestResults, `
    Get-AggregatedResults, `
    Get-FlakyTest, `
    New-SummaryMarkdown
