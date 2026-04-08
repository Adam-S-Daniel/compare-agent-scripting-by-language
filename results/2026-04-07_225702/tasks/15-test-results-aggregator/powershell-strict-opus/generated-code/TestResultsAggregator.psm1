# TestResultsAggregator.psm1
# Module for parsing test result files (JUnit XML, JSON), aggregating results
# across matrix builds, detecting flaky tests, and generating markdown summaries.
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# --- Data model: each parsed test case is a hashtable with these keys ---
# Name, ClassName, Duration (double), Status (passed/failed/skipped), ErrorMessage, RunSource

# ============================================================================
# Parse a single JUnit XML file and return an array of test-case hashtables.
# ============================================================================
function ConvertFrom-JUnitXml {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JUnit XML file not found: $Path"
    }

    [xml]$doc = Get-Content -LiteralPath $Path -Raw

    [hashtable[]]$results = @()

    # Handle both <testsuites><testsuite> and bare <testsuite> roots
    [System.Xml.XmlElement[]]$suites = @()
    if ($doc.DocumentElement.LocalName -eq 'testsuites') {
        $suites = @($doc.DocumentElement.ChildNodes | Where-Object { $_.LocalName -eq 'testsuite' })
    } elseif ($doc.DocumentElement.LocalName -eq 'testsuite') {
        $suites = @($doc.DocumentElement)
    } else {
        throw "Unrecognised JUnit XML root element: $($doc.DocumentElement.LocalName)"
    }

    foreach ($suite in $suites) {
        foreach ($tc in ($suite.ChildNodes | Where-Object { $_.LocalName -eq 'testcase' })) {
            [string]$status = 'passed'
            [string]$errorMsg = ''

            $failureNode = $tc.SelectSingleNode('failure')
            $skippedNode = $tc.SelectSingleNode('skipped')
            $errorNode   = $tc.SelectSingleNode('error')

            if ($null -ne $failureNode) {
                $status = 'failed'
                $errorMsg = [string]$failureNode.GetAttribute('message')
            } elseif ($null -ne $errorNode) {
                $status = 'failed'
                $errorMsg = [string]$errorNode.GetAttribute('message')
            } elseif ($null -ne $skippedNode) {
                $status = 'skipped'
                $errorMsg = [string]$skippedNode.GetAttribute('message')
            }

            [hashtable]$entry = @{
                Name         = [string]$tc.GetAttribute('name')
                ClassName    = [string]$tc.GetAttribute('classname')
                Duration     = [double]($tc.GetAttribute('time'))
                Status       = $status
                ErrorMessage = $errorMsg
                RunSource    = $Path
            }
            $results += $entry
        }
    }

    return $results
}

# ============================================================================
# Parse a single JSON test results file and return an array of test-case hashtables.
# Expected schema: { testSuites: [ { name, tests: [ { name, classname, duration, status, error?, skipReason? } ] } ] }
# ============================================================================
function ConvertFrom-JsonTestResult {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON test result file not found: $Path"
    }

    [string]$raw = Get-Content -LiteralPath $Path -Raw
    $data = $raw | ConvertFrom-Json

    if ($null -eq $data.testSuites) {
        throw "JSON file missing 'testSuites' property: $Path"
    }

    [hashtable[]]$results = @()

    foreach ($suite in $data.testSuites) {
        foreach ($t in $suite.tests) {
            [string]$errorMsg = ''
            # Under strict mode, accessing a non-existent property throws.
            # Use PSObject.Properties to safely check for optional fields.
            if ($null -ne $t.PSObject.Properties['error']) {
                $errorMsg = [string]$t.error.message
            } elseif ($null -ne $t.PSObject.Properties['skipReason']) {
                $errorMsg = [string]$t.skipReason
            }

            [hashtable]$entry = @{
                Name         = [string]$t.name
                ClassName    = [string]$t.classname
                Duration     = [double]$t.duration
                Status       = [string]$t.status
                ErrorMessage = $errorMsg
                RunSource    = $Path
            }
            $results += $entry
        }
    }

    return $results
}

# ============================================================================
# Detect file format and dispatch to the appropriate parser.
# ============================================================================
function Import-TestResults {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Test result file not found: $Path"
    }

    [string]$ext = [System.IO.Path]::GetExtension($Path).ToLower()

    switch ($ext) {
        '.xml'  { return ConvertFrom-JUnitXml -Path $Path }
        '.json' { return ConvertFrom-JsonTestResult -Path $Path }
        default { throw "Unsupported test result format: $ext (file: $Path)" }
    }
}

# ============================================================================
# Aggregate results from multiple parsed test-case arrays.
# Returns a hashtable with Passed, Failed, Skipped, TotalDuration, and TestCases.
# ============================================================================
function Merge-TestResults {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable[][]]$ResultSets
    )

    [hashtable[]]$allCases = @()
    foreach ($set in $ResultSets) {
        $allCases += $set
    }

    [int]$passed  = ($allCases | Where-Object { $_.Status -eq 'passed' }).Count
    [int]$failed  = ($allCases | Where-Object { $_.Status -eq 'failed' }).Count
    [int]$skipped = ($allCases | Where-Object { $_.Status -eq 'skipped' }).Count
    [double]$totalDuration = 0.0
    foreach ($c in $allCases) {
        $totalDuration += [double]$c.Duration
    }

    return @{
        Passed        = $passed
        Failed        = $failed
        Skipped       = $skipped
        Total         = $allCases.Count
        TotalDuration = [System.Math]::Round($totalDuration, 3)
        TestCases     = $allCases
    }
}

# ============================================================================
# Identify flaky tests: tests that passed in some runs and failed in others.
# Groups by ClassName + Name, then checks for mixed statuses.
# Returns an array of hashtables with Name, ClassName, Runs (array of status per run).
# ============================================================================
function Find-FlakyTests {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$TestCases
    )

    # Group by composite key (ClassName::Name)
    [hashtable]$grouped = @{}
    foreach ($tc in $TestCases) {
        [string]$key = "$($tc.ClassName)::$($tc.Name)"
        if (-not $grouped.ContainsKey($key)) {
            $grouped[$key] = [System.Collections.ArrayList]::new()
        }
        [void]$grouped[$key].Add($tc)
    }

    [hashtable[]]$flaky = @()
    foreach ($key in $grouped.Keys) {
        [System.Collections.ArrayList]$runs = $grouped[$key]
        # Only consider non-skipped statuses for flakiness
        [string[]]$nonSkippedStatuses = @($runs | Where-Object { $_.Status -ne 'skipped' } | ForEach-Object { $_.Status })
        if ($nonSkippedStatuses.Count -lt 2) { continue }

        [bool]$hasPassed = ($nonSkippedStatuses -contains 'passed')
        [bool]$hasFailed = ($nonSkippedStatuses -contains 'failed')
        if ($hasPassed -and $hasFailed) {
            [hashtable]$first = $runs[0]
            [hashtable[]]$runDetails = @($runs | ForEach-Object {
                @{ Status = [string]$_.Status; RunSource = [string]$_.RunSource }
            })
            $flaky += @{
                Name      = [string]$first.Name
                ClassName = [string]$first.ClassName
                Runs      = $runDetails
            }
        }
    }

    return $flaky
}

# ============================================================================
# Generate a Markdown summary suitable for a GitHub Actions job summary.
# ============================================================================
function New-MarkdownSummary {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$AggregatedResults,

        [Parameter()]
        [hashtable[]]$FlakyTests = @()
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    # Header with overall status emoji
    [string]$statusIcon = if ($AggregatedResults.Failed -gt 0) { '❌' } else { '✅' }
    [void]$sb.AppendLine("# $statusIcon Test Results Summary")
    [void]$sb.AppendLine()

    # Totals table
    [void]$sb.AppendLine('| Metric | Count |')
    [void]$sb.AppendLine('|--------|-------|')
    [void]$sb.AppendLine("| **Total** | $($AggregatedResults.Total) |")
    [void]$sb.AppendLine("| **Passed** | $($AggregatedResults.Passed) |")
    [void]$sb.AppendLine("| **Failed** | $($AggregatedResults.Failed) |")
    [void]$sb.AppendLine("| **Skipped** | $($AggregatedResults.Skipped) |")
    [void]$sb.AppendLine("| **Duration** | $($AggregatedResults.TotalDuration)s |")
    [void]$sb.AppendLine()

    # Failed tests detail
    [hashtable[]]$failedCases = @($AggregatedResults.TestCases | Where-Object { $_.Status -eq 'failed' })
    if ($failedCases.Count -gt 0) {
        [void]$sb.AppendLine('## Failed Tests')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Test | Class | Error | Source |')
        [void]$sb.AppendLine('|------|-------|-------|--------|')
        foreach ($f in $failedCases) {
            [string]$name = [string]$f.Name
            [string]$cls  = [string]$f.ClassName
            [string]$err  = [string]$f.ErrorMessage
            [string]$src  = [System.IO.Path]::GetFileName([string]$f.RunSource)
            [void]$sb.AppendLine("| $name | $cls | $err | $src |")
        }
        [void]$sb.AppendLine()
    }

    # Flaky tests section
    if ($FlakyTests.Count -gt 0) {
        [void]$sb.AppendLine('## ⚠️ Flaky Tests')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('These tests produced inconsistent results across runs:')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Test | Class | Results |')
        [void]$sb.AppendLine('|------|-------|---------|')
        foreach ($ft in $FlakyTests) {
            [string]$name = [string]$ft.Name
            [string]$cls  = [string]$ft.ClassName
            [string[]]$runStrs = @($ft.Runs | ForEach-Object {
                [string]$s = [string]$_.Status
                [string]$src = [System.IO.Path]::GetFileName([string]$_.RunSource)
                "$s ($src)"
            })
            [string]$runSummary = $runStrs -join ', '
            [void]$sb.AppendLine("| $name | $cls | $runSummary |")
        }
        [void]$sb.AppendLine()
    }

    return $sb.ToString()
}

Export-ModuleMember -Function @(
    'ConvertFrom-JUnitXml',
    'ConvertFrom-JsonTestResult',
    'Import-TestResults',
    'Merge-TestResults',
    'Find-FlakyTests',
    'New-MarkdownSummary'
)
