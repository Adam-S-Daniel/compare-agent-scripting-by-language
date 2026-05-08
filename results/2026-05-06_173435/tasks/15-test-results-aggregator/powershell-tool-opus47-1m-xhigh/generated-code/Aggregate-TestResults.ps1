<#
.SYNOPSIS
    Aggregates JUnit XML and JSON test results, detects flaky tests, and emits
    a markdown summary suitable for $GITHUB_STEP_SUMMARY.

.DESCRIPTION
    Designed to be dot-sourced by Pester tests and also runnable as a script:

        ./Aggregate-TestResults.ps1 -InputDir fixtures -OutputPath summary.md

    Each public function returns plain PSCustomObjects so callers can compose
    pipelines without the script enforcing a single workflow.

    Test record schema (used internally by every reader):
        Name      [string]   test name
        Suite     [string]   class / suite name
        Status    [string]   passed | failed | skipped
        Duration  [double]   seconds
        Source    [string]   source file basename (used for flaky-run triage)
#>

[CmdletBinding()]
param(
    [string]$InputDir,
    [string]$OutputPath,
    # Path to write the GHA summary file. Defaults to $env:GITHUB_STEP_SUMMARY
    # when set so the caller doesn't have to plumb it through.
    [switch]$AppendStepSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------- Status normalization -------------------------------------------------

# Map common status spellings (pass / passed / PASS / ok / success) to the
# canonical 3-value status. Anything unrecognized becomes 'failed' so we never
# silently lose a failure -- safer to over-count than under-count.
function ConvertTo-CanonicalStatus {
    [OutputType([string])]
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return 'failed' }
    switch -regex ($Raw.Trim().ToLowerInvariant()) {
        '^(pass(ed)?|ok|success)$'        { return 'passed' }
        '^(skip(ped)?|pending|ignored)$'  { return 'skipped' }
        '^(fail(ed)?|error(ed)?|broken)$' { return 'failed' }
        default                           { return 'failed' }
    }
}

# ---------- Readers --------------------------------------------------------------

function Read-JUnitXml {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JUnit file not found: $Path"
    }

    [xml]$doc = $null
    try {
        $doc = [xml](Get-Content -LiteralPath $Path -Raw)
    } catch {
        # Re-raise with a JUnit-tagged message so callers can distinguish format
        # errors from IO errors. The original exception is preserved as InnerException.
        throw [System.InvalidOperationException]::new("Failed to parse JUnit XML '$Path': $($_.Exception.Message)", $_.Exception)
    }

    # Accept either <testsuite> or <testsuites> roots. Real-world reports use both.
    # NOTE: PowerShell's XML adapter shadows XmlElement.Name with the `name`
    # attribute when one is present, so we use .LocalName (the tag name) and
    # SelectNodes() with XPath rather than property navigation.
    $rootName = $doc.DocumentElement.LocalName
    $suiteNodes = @()
    if ($rootName -eq 'testsuites') {
        $suiteNodes = @($doc.DocumentElement.SelectNodes('testsuite'))
    } elseif ($rootName -eq 'testsuite') {
        $suiteNodes = @($doc.DocumentElement)
    } else {
        throw "Not a JUnit XML document (root element was '$rootName'): $Path"
    }

    $source = Split-Path -Leaf $Path
    # Use a generic List so we always return a flat collection — avoids the
    # PowerShell "single item vs array" ambiguity when the suite has 0 or 1 cases.
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($suite in $suiteNodes) {
        if ($null -eq $suite) { continue }
        $suiteName = $suite.GetAttribute('name')
        foreach ($tc in @($suite.SelectNodes('testcase'))) {
            if ($null -eq $tc) { continue }

            # Determine status from child elements: <failure>/<error> => failed,
            # <skipped> => skipped, otherwise => passed.
            $status = 'passed'
            if ($tc.SelectSingleNode('failure') -or $tc.SelectSingleNode('error')) {
                $status = 'failed'
            } elseif ($tc.SelectSingleNode('skipped')) {
                $status = 'skipped'
            }

            $duration = 0.0
            $timeAttr = $tc.GetAttribute('time')
            if ($timeAttr) {
                # InvariantCulture parse so '0.10' parses correctly under any locale.
                [double]::TryParse($timeAttr, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$duration) | Out-Null
            }

            $classname = $tc.GetAttribute('classname')
            $records.Add([pscustomobject]@{
                Name     = $tc.GetAttribute('name')
                Suite    = if ($classname) { $classname } else { $suiteName }
                Status   = $status
                Duration = [double]$duration
                Source   = $source
            })
        }
    }
    # Wrap with comma to prevent PowerShell pipeline from unrolling -- callers
    # that capture into a variable get a List back, callers that pipe will
    # still see individual elements after one unrolling step.
    return ,$records.ToArray()
}

function Read-JsonResults {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    $obj = $null
    try {
        $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw [System.InvalidOperationException]::new("Failed to parse JSON results '$Path': $($_.Exception.Message)", $_.Exception)
    }

    $source = Split-Path -Leaf $Path
    $suiteName = if ($obj.PSObject.Properties.Name -contains 'suite') { [string]$obj.suite } else { '' }
    $tests = if ($obj.PSObject.Properties.Name -contains 'tests') { @($obj.tests) } else { @() }

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($t in $tests) {
        if ($null -eq $t) { continue }
        $name = if ($t.PSObject.Properties.Name -contains 'name') { [string]$t.name } else { '' }
        $rawStatus = if ($t.PSObject.Properties.Name -contains 'status') { [string]$t.status } else { '' }
        $duration = 0.0
        if ($t.PSObject.Properties.Name -contains 'duration') {
            [double]::TryParse([string]$t.duration, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$duration) | Out-Null
        }
        $perTestSuite = if ($t.PSObject.Properties.Name -contains 'suite') { [string]$t.suite } else { $suiteName }

        $records.Add([pscustomobject]@{
            Name     = $name
            Suite    = $perTestSuite
            Status   = ConvertTo-CanonicalStatus -Raw $rawStatus
            Duration = [double]$duration
            Source   = $source
        })
    }
    return ,$records.ToArray()
}

function Read-TestResults {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$InputDir
    )

    if (-not (Test-Path -LiteralPath $InputDir -PathType Container)) {
        throw "Input directory not found: $InputDir"
    }

    # Sort so the output is deterministic; matters for flaky-run reporting and tests.
    $files = Get-ChildItem -LiteralPath $InputDir -File |
        Where-Object { $_.Extension -in '.xml', '.json' } |
        Sort-Object Name

    $all = [System.Collections.Generic.List[object]]::new()
    foreach ($f in $files) {
        $batch = switch ($f.Extension) {
            '.xml'  { Read-JUnitXml   -Path $f.FullName }
            '.json' { Read-JsonResults -Path $f.FullName }
        }
        # Each reader returns a wrapped array (see "return ,$records.ToArray()");
        # AddRange flattens it into our master list.
        if ($null -ne $batch) { $all.AddRange([object[]]$batch) }
    }
    return ,$all.ToArray()
}

# ---------- Aggregation ----------------------------------------------------------

function Get-TestSummary {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Records
    )
    $passed = @($Records | Where-Object { $_.Status -eq 'passed'  }).Count
    $failed = @($Records | Where-Object { $_.Status -eq 'failed'  }).Count
    $skipped = @($Records | Where-Object { $_.Status -eq 'skipped' }).Count
    # Measure-Object on empty input returns no Sum property, hence the guard.
    $duration = 0.0
    if ($Records.Count -gt 0) {
        $sum = ($Records | Measure-Object -Property Duration -Sum).Sum
        if ($null -ne $sum) { $duration = [double]$sum }
    }

    [pscustomobject]@{
        Total    = $Records.Count
        Passed   = $passed
        Failed   = $failed
        Skipped  = $skipped
        Duration = [double]$duration
    }
}

function Find-FlakyTests {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Records
    )

    # A test is flaky iff, across runs, it has BOTH a 'passed' and a 'failed'
    # observation. Skipped is informational and never makes a test flaky on its own.
    # Identity = Suite + Name (same name in different suites is a different test).
    $byKey = $Records | Group-Object -Property { "{0}::{1}" -f $_.Suite, $_.Name }

    $flaky = foreach ($g in $byKey) {
        $statuses = @($g.Group | ForEach-Object Status | Sort-Object -Unique)
        if (($statuses -contains 'passed') -and ($statuses -contains 'failed')) {
            $first = $g.Group[0]
            [pscustomobject]@{
                Suite    = $first.Suite
                Name     = $first.Name
                PassedIn = @($g.Group | Where-Object { $_.Status -eq 'passed' } | ForEach-Object Source | Sort-Object -Unique)
                FailedIn = @($g.Group | Where-Object { $_.Status -eq 'failed' } | ForEach-Object Source | Sort-Object -Unique)
            }
        }
    }
    return ,@($flaky)
}

# ---------- Markdown rendering ---------------------------------------------------

function Format-MarkdownSummary {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Records
    )

    $summary = Get-TestSummary -Records $Records
    $flaky   = Find-FlakyTests -Records $Records
    $failed  = @($Records | Where-Object { $_.Status -eq 'failed' })

    # Choose a status emoji-free heading to keep the markdown CI-renderer-agnostic.
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('## Test Results Summary')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Metric   | Count |')
    [void]$sb.AppendLine('| -------- | ----- |')
    [void]$sb.AppendLine("| Total    | $($summary.Total) |")
    [void]$sb.AppendLine("| Passed   | $($summary.Passed) |")
    [void]$sb.AppendLine("| Failed   | $($summary.Failed) |")
    [void]$sb.AppendLine("| Skipped  | $($summary.Skipped) |")
    # Two-decimal seconds keeps the output stable across re-runs while still
    # showing sub-second precision where it matters.
    $durStr = ('{0:N2}s' -f $summary.Duration)
    [void]$sb.AppendLine("| Duration | $durStr |")
    [void]$sb.AppendLine('')

    [void]$sb.AppendLine('### Flaky Tests')
    [void]$sb.AppendLine('')
    if ($flaky.Count -eq 0) {
        [void]$sb.AppendLine('_No flaky tests detected._')
    } else {
        [void]$sb.AppendLine('| Suite | Test | Passed In | Failed In |')
        [void]$sb.AppendLine('| ----- | ---- | --------- | --------- |')
        foreach ($f in ($flaky | Sort-Object Suite, Name)) {
            $passedIn = ($f.PassedIn -join ', ')
            $failedIn = ($f.FailedIn -join ', ')
            [void]$sb.AppendLine("| $($f.Suite) | $($f.Name) | $passedIn | $failedIn |")
        }
    }
    [void]$sb.AppendLine('')

    [void]$sb.AppendLine('### Failed Tests')
    [void]$sb.AppendLine('')
    if ($failed.Count -eq 0) {
        [void]$sb.AppendLine('_No failed tests._')
    } else {
        [void]$sb.AppendLine('| Suite | Test | Source |')
        [void]$sb.AppendLine('| ----- | ---- | ------ |')
        foreach ($r in ($failed | Sort-Object Source, Suite, Name)) {
            [void]$sb.AppendLine("| $($r.Suite) | $($r.Name) | $($r.Source) |")
        }
    }

    return $sb.ToString()
}

# ---------- Entry point ----------------------------------------------------------

function Invoke-Aggregator {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$InputDir,
        [Parameter(Mandatory)][string]$OutputPath
    )

    $records = Read-TestResults -InputDir $InputDir
    $summary = Get-TestSummary -Records $records
    $md      = Format-MarkdownSummary -Records $records

    # Ensure parent directory exists (e.g. when OutputPath points at a fresh dir).
    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $md -Encoding UTF8

    # Echo high-signal numbers to stdout so CI logs / `act` output can grep them.
    Write-Host ("Total={0} Passed={1} Failed={2} Skipped={3} Duration={4:N2}s" -f `
        $summary.Total, $summary.Passed, $summary.Failed, $summary.Skipped, $summary.Duration)

    $flaky = Find-FlakyTests -Records $records
    Write-Host ("FlakyCount={0}" -f $flaky.Count)
    foreach ($f in ($flaky | Sort-Object Suite, Name)) {
        Write-Host ("Flaky: {0}::{1}" -f $f.Suite, $f.Name)
    }

    return $md
}

# ---------- Script entry (only when invoked, not dot-sourced) --------------------

# $MyInvocation.InvocationName is '.' for dot-sourcing. Only run the entry
# point when invoked as a script, otherwise the test file (which dot-sources)
# would trigger the body.
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '') {
    if ($PSBoundParameters.ContainsKey('InputDir') -or $PSBoundParameters.ContainsKey('OutputPath')) {
        if (-not $InputDir)   { throw 'Missing -InputDir' }
        if (-not $OutputPath) {
            if ($AppendStepSummary -and $env:GITHUB_STEP_SUMMARY) {
                $OutputPath = $env:GITHUB_STEP_SUMMARY
            } else {
                throw 'Missing -OutputPath (or pass -AppendStepSummary with GITHUB_STEP_SUMMARY set)'
            }
        }
        Invoke-Aggregator -InputDir $InputDir -OutputPath $OutputPath | Out-Null

        if ($AppendStepSummary -and $env:GITHUB_STEP_SUMMARY -and ($OutputPath -ne $env:GITHUB_STEP_SUMMARY)) {
            Get-Content -LiteralPath $OutputPath -Raw | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY
        }
    }
}
