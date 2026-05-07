#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Aggregator.psm1 - Parses test result files (JUnit XML, JSON), aggregates
# them across simulated matrix runs, identifies flaky tests, and renders a
# markdown summary suitable for use as a GitHub Actions job summary.
#
# Public functions:
#   Read-TestResultFile     - dispatches by extension to JUnit/JSON readers
#   Read-JUnitFile          - parses a JUnit XML file -> normalized TestResult[]
#   Read-JsonResultFile     - parses a JSON file       -> normalized TestResult[]
#   Get-Aggregate           - rolls up totals + per-test outcome history
#   Find-FlakyTests         - returns tests whose outcomes vary across runs
#   New-MarkdownSummary     - renders aggregate + flaky info as markdown
#   Invoke-Aggregate        - composes the above end-to-end for a directory
#
# Normalized TestResult shape:
#   @{ Name; Suite; Outcome; Duration; SourceFile; Message }
#   Outcome is one of: 'passed', 'failed', 'skipped'.

function ConvertTo-Number {
    # Permissive numeric coercion: missing/empty -> 0, returns [double].
    param($Value)
    if ($null -eq $Value) { return 0.0 }
    $s = "$Value".Trim()
    if ([string]::IsNullOrEmpty($s)) { return 0.0 }
    [double]$n = 0
    if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)) {
        return $n
    }
    return 0.0
}

function Test-XmlChild {
    # StrictMode-safe presence check for an XmlElement child node.
    param($Node, [string] $Name)
    if ($null -eq $Node) { return $false }
    if ($Node -is [System.Xml.XmlElement]) {
        return ($null -ne $Node.SelectSingleNode($Name))
    }
    return $false
}

function Get-XmlAttr {
    # StrictMode-safe attribute getter; returns $Default if missing.
    param($Node, [string] $Name, $Default = $null)
    if ($null -eq $Node) { return $Default }
    if ($Node -is [System.Xml.XmlElement]) {
        if ($Node.HasAttribute($Name)) { return $Node.GetAttribute($Name) }
    }
    return $Default
}

function Read-JUnitFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )
    if (-not (Test-Path $Path)) {
        throw "JUnit file not found: $Path"
    }

    try {
        [xml]$doc = Get-Content -Path $Path -Raw
    } catch {
        throw "Failed to parse JUnit XML '$Path': $($_.Exception.Message)"
    }

    # Support <testsuites><testsuite>... and a top-level <testsuite> root.
    # XPath via SelectNodes avoids the dynamic property-access trap that
    # Set-StrictMode triggers when a child element is absent.
    $suites = @()
    $root = $doc.DocumentElement
    if ($null -ne $root) {
        if ($root.LocalName -eq 'testsuites') {
            $suites = @($root.SelectNodes('testsuite'))
        } elseif ($root.LocalName -eq 'testsuite') {
            $suites = @($root)
        }
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($suite in $suites) {
        if ($null -eq $suite) { continue }
        $suiteName = Get-XmlAttr $suite 'name' ''

        $cases = @($suite.SelectNodes('testcase'))
        foreach ($tc in $cases) {
            if ($null -eq $tc) { continue }

            # Outcome derives from presence of <failure>, <error>, or <skipped>.
            $outcome = 'passed'
            $message = $null
            if (Test-XmlChild $tc 'failure') {
                $outcome = 'failed'
                $node = $tc.SelectSingleNode('failure')
                $message = Get-XmlAttr $node 'message' $node.InnerText
            } elseif (Test-XmlChild $tc 'error') {
                $outcome = 'failed'
                $node = $tc.SelectSingleNode('error')
                $message = Get-XmlAttr $node 'message' $node.InnerText
            } elseif (Test-XmlChild $tc 'skipped') {
                $outcome = 'skipped'
                $node = $tc.SelectSingleNode('skipped')
                if ($null -ne $node) { $message = Get-XmlAttr $node 'message' $null }
            }

            $classAttr = Get-XmlAttr $tc 'classname' $suiteName
            $results.Add([pscustomobject]@{
                Name       = Get-XmlAttr $tc 'name' ''
                Suite      = $classAttr
                Outcome    = $outcome
                Duration   = ConvertTo-Number (Get-XmlAttr $tc 'time' 0)
                SourceFile = (Split-Path -Leaf $Path)
                Message    = $message
            })
        }
    }
    return ,$results.ToArray()
}

function Read-JsonResultFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )
    if (-not (Test-Path $Path)) {
        throw "JSON result file not found: $Path"
    }

    try {
        $raw = Get-Content -Path $Path -Raw
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON '$Path': $($_.Exception.Message)"
    }

    # Accept either { tests: [...] } or a bare [...].
    $tests = @()
    if ($data -is [System.Array]) {
        $tests = $data
    } elseif ($data.PSObject.Properties.Match('tests').Count -gt 0) {
        $tests = @($data.tests)
    } else {
        throw "JSON '$Path' has no 'tests' array at the top level"
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($t in $tests) {
        if ($null -eq $t) { continue }
        $outcomeRaw = if ($t.PSObject.Properties.Match('outcome').Count -gt 0) { [string]$t.outcome } else { 'passed' }
        $outcome = switch -Regex ($outcomeRaw.ToLowerInvariant()) {
            '^(pass|passed|ok|success)$' { 'passed'; break }
            '^(fail|failed|error|errored)$' { 'failed'; break }
            '^(skip|skipped|pending|ignored)$' { 'skipped'; break }
            default { 'passed' }
        }

        $results.Add([pscustomobject]@{
            Name       = [string]$t.name
            Suite      = if ($t.PSObject.Properties.Match('suite').Count -gt 0) { [string]$t.suite } else { '' }
            Outcome    = $outcome
            Duration   = ConvertTo-Number $t.duration
            SourceFile = (Split-Path -Leaf $Path)
            Message    = if ($t.PSObject.Properties.Match('message').Count -gt 0) { [string]$t.message } else { $null }
        })
    }
    return ,$results.ToArray()
}

function Read-TestResultFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    $ext = ([System.IO.Path]::GetExtension($Path)).ToLowerInvariant()
    switch ($ext) {
        '.xml'  { return ,(Read-JUnitFile -Path $Path) }
        '.json' { return ,(Read-JsonResultFile -Path $Path) }
        default { throw "Unsupported test result format: '$ext' for $Path" }
    }
}

function Get-Aggregate {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object[]] $Results)

    $passed  = 0
    $failed  = 0
    $skipped = 0
    [double]$duration = 0
    foreach ($r in $Results) {
        switch ($r.Outcome) {
            'passed'  { $passed++ }
            'failed'  { $failed++ }
            'skipped' { $skipped++ }
        }
        $duration += [double]$r.Duration
    }

    [pscustomobject]@{
        Total    = $Results.Count
        Passed   = $passed
        Failed   = $failed
        Skipped  = $skipped
        Duration = [Math]::Round($duration, 3)
    }
}

function Find-FlakyTests {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object[]] $Results)

    # A test is flaky if, across all runs, it has at least one 'passed' AND at
    # least one 'failed' outcome. Skipped doesn't count as flake on its own.
    $byKey = @{}
    foreach ($r in $Results) {
        $key = if ([string]::IsNullOrWhiteSpace($r.Suite)) { $r.Name } else { "$($r.Suite)::$($r.Name)" }
        if (-not $byKey.ContainsKey($key)) {
            $byKey[$key] = [pscustomobject]@{
                Key      = $key
                Name     = $r.Name
                Suite    = $r.Suite
                Runs     = New-Object System.Collections.Generic.List[object]
            }
        }
        $byKey[$key].Runs.Add([pscustomobject]@{
            Outcome    = $r.Outcome
            SourceFile = $r.SourceFile
        })
    }

    $flaky = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $byKey.Values) {
        $outcomes = @($entry.Runs | ForEach-Object { $_.Outcome })
        $hasPass = $outcomes -contains 'passed'
        $hasFail = $outcomes -contains 'failed'
        if ($hasPass -and $hasFail) {
            $flaky.Add([pscustomobject]@{
                Name     = $entry.Name
                Suite    = $entry.Suite
                Runs     = $entry.Runs.ToArray()
                PassedIn = @($entry.Runs | Where-Object { $_.Outcome -eq 'passed' } | ForEach-Object { $_.SourceFile })
                FailedIn = @($entry.Runs | Where-Object { $_.Outcome -eq 'failed' } | ForEach-Object { $_.SourceFile })
            })
        }
    }
    return ,$flaky.ToArray()
}

function New-MarkdownSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Aggregate,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Results,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Flaky
    )

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Test Results Summary")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Totals")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Metric | Value |")
    [void]$sb.AppendLine("| --- | --- |")
    [void]$sb.AppendLine("| Total | $($Aggregate.Total) |")
    [void]$sb.AppendLine("| Passed | $($Aggregate.Passed) |")
    [void]$sb.AppendLine("| Failed | $($Aggregate.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($Aggregate.Skipped) |")
    # Format duration with two decimals for stable assertions in tests.
    $durStr = ('{0:N2}' -f [double]$Aggregate.Duration)
    [void]$sb.AppendLine("| Duration | ${durStr}s |")
    [void]$sb.AppendLine("| Flaky tests | $($Flaky.Count) |")
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("## Flaky Tests")
    [void]$sb.AppendLine("")
    if ($Flaky.Count -eq 0) {
        [void]$sb.AppendLine("_None detected._")
    } else {
        foreach ($f in $Flaky) {
            $passList = ($f.PassedIn -join ', ')
            $failList = ($f.FailedIn -join ', ')
            [void]$sb.AppendLine("- **$($f.Name)** (suite: $($f.Suite)) — passed in: $passList; failed in: $failList")
        }
    }
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("## Failed Tests")
    [void]$sb.AppendLine("")
    $failedResults = @($Results | Where-Object { $_.Outcome -eq 'failed' })
    if ($failedResults.Count -eq 0) {
        [void]$sb.AppendLine("_None._")
    } else {
        foreach ($r in $failedResults) {
            $msg = if ($r.Message) { ": " + ($r.Message -replace '\s+', ' ') } else { '' }
            [void]$sb.AppendLine("- $($r.Name) ($($r.SourceFile))$msg")
        }
    }
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("## Plain-text summary")
    [void]$sb.AppendLine("")
    # The plain-text section gives the act-output assertions clean,
    # un-tabled values to match against without parsing markdown tables.
    [void]$sb.AppendLine("Total: $($Aggregate.Total)")
    [void]$sb.AppendLine("Passed: $($Aggregate.Passed)")
    [void]$sb.AppendLine("Failed: $($Aggregate.Failed)")
    [void]$sb.AppendLine("Skipped: $($Aggregate.Skipped)")
    [void]$sb.AppendLine("Duration: ${durStr}s")
    [void]$sb.AppendLine("Flaky tests: $($Flaky.Count)")

    return $sb.ToString()
}

function Invoke-Aggregate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $InputDirectory
    )
    if (-not (Test-Path -LiteralPath $InputDirectory -PathType Container)) {
        throw "Input directory not found: $InputDirectory"
    }

    # Pick up *.xml and *.json files (any depth). The test fixture layout
    # places result files directly in the input dir but recursion is harmless.
    $files = @(Get-ChildItem -Path $InputDirectory -Recurse -File |
                Where-Object { $_.Extension -match '^\.(xml|json)$' } |
                Sort-Object FullName)

    if ($files.Count -eq 0) {
        throw "No test result files (*.xml, *.json) found in: $InputDirectory"
    }

    $all = New-Object System.Collections.Generic.List[object]
    foreach ($f in $files) {
        try {
            $r = Read-TestResultFile -Path $f.FullName
            if ($r) { $all.AddRange([object[]]$r) }
        } catch {
            # Surface parse errors clearly — don't silently drop a file.
            throw "Error reading $($f.FullName): $($_.Exception.Message)"
        }
    }

    $resultsArr = $all.ToArray()
    $agg   = Get-Aggregate -Results $resultsArr
    $flaky = Find-FlakyTests -Results $resultsArr
    $md    = New-MarkdownSummary -Aggregate $agg -Results $resultsArr -Flaky $flaky

    return [pscustomobject]@{
        Aggregate = $agg
        Flaky     = $flaky
        Results   = $resultsArr
        Markdown  = $md
        Files     = $files | ForEach-Object FullName
    }
}

Export-ModuleMember -Function `
    Read-JUnitFile, `
    Read-JsonResultFile, `
    Read-TestResultFile, `
    Get-Aggregate, `
    Find-FlakyTests, `
    New-MarkdownSummary, `
    Invoke-Aggregate
