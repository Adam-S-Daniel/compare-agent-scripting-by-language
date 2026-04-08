# ============================================================
# TestResultsAggregator.psm1
#
# Parses JUnit XML and JSON test result files produced by
# matrix CI builds, aggregates the results, identifies flaky
# tests, and generates a GitHub Actions job-summary in Markdown.
#
# Strict-mode compliance:
#   - Set-StrictMode -Version Latest
#   - $ErrorActionPreference = 'Stop'
#   - All parameters explicitly typed
#   - [OutputType()] on every function
#   - [CmdletBinding()] on every function
#   - No implicit type conversions
# ============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ──────────────────────────────────────────────────────────────
# Private helpers
# ──────────────────────────────────────────────────────────────

# Creates a strongly-structured TestCase PSCustomObject.
# All callers must supply explicit types — no implicit coercion.
function New-TestCase {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$ClassName,
        [Parameter(Mandatory)] [string]$Status,   # 'passed' | 'failed' | 'skipped'
        [Parameter()]          [double]$Duration = 0.0,
        [Parameter()]          [string]$Message  = '',
        [Parameter()]          [string]$RunId    = ''
    )

    # Build the fully-qualified test name used for flaky detection.
    [string]$fullName = if ([string]::IsNullOrEmpty($ClassName)) {
        $Name
    } else {
        "$ClassName.$Name"
    }

    return [PSCustomObject]@{
        Name      = $Name
        ClassName = $ClassName
        FullName  = $fullName
        Status    = $Status
        Duration  = $Duration
        Message   = $Message
        RunId     = $RunId
    }
}

# Wraps an array of TestCase objects into a TestRun summary object.
# Computes passed/failed/skipped counts and total duration from the
# provided tests array — keeps the logic in one place.
function New-TestRun {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string]        $RunId,
        [Parameter(Mandatory)] [string]        $Source,
        [Parameter(Mandatory)] [string]        $Format,   # 'junit-xml' | 'json'
        [Parameter(Mandatory)] [PSCustomObject[]] $Tests
    )

    [int]$passed  = [int]($Tests | Where-Object { [string]$_.Status -eq 'passed'  } | Measure-Object).Count
    [int]$failed  = [int]($Tests | Where-Object { [string]$_.Status -eq 'failed'  } | Measure-Object).Count
    [int]$skipped = [int]($Tests | Where-Object { [string]$_.Status -eq 'skipped' } | Measure-Object).Count

    # Measure-Object -Sum returns $null for Sum on an empty collection.
    $durationResult = $Tests | Measure-Object -Property Duration -Sum
    [double]$duration = if ($null -ne $durationResult.Sum) {
        [double]$durationResult.Sum
    } else {
        [double]0.0
    }

    return [PSCustomObject]@{
        RunId    = $RunId
        Source   = $Source
        Format   = $Format
        Tests    = $Tests
        Passed   = $passed
        Failed   = $failed
        Skipped  = $skipped
        Duration = $duration
        Total    = [int]$Tests.Count
    }
}

# ──────────────────────────────────────────────────────────────
# Public: ConvertFrom-JUnitXml
# TDD Cycle 1 — implemented to satisfy the first Describe block.
# ──────────────────────────────────────────────────────────────
function ConvertFrom-JUnitXml {
    <#
    .SYNOPSIS
        Parses a JUnit XML file into a TestRun object.
    .PARAMETER FilePath
        Path to the .xml file.
    .PARAMETER RunId
        Identifier for this run. Defaults to the file name without extension.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string]$FilePath,
        [Parameter()]          [string]$RunId = ''
    )

    if (-not (Test-Path -Path $FilePath)) {
        throw "File not found: '$FilePath'"
    }

    if ([string]::IsNullOrEmpty($RunId)) {
        $RunId = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    }

    [xml]$xml = Get-Content -Path $FilePath -Raw

    $testList = [System.Collections.Generic.List[PSCustomObject]]::new()

    # JUnit XML may have a <testsuites> wrapper or a bare <testsuite> root.
    # @() ensures we always iterate an array, even for a single element.
    [object[]]$suites = @(
        if ($null -ne $xml.testsuites) {
            $xml.testsuites.testsuite
        } else {
            $xml.testsuite
        }
    )

    foreach ($suite in $suites) {
        if ($null -eq $suite) { continue }

        # Again, @() guards against a single <testcase> being returned as
        # a scalar XmlElement rather than an array.
        [object[]]$cases = @($suite.testcase)

        foreach ($tc in $cases) {
            if ($null -eq $tc) { continue }

            # Use SelectSingleNode / GetAttribute to avoid strict-mode
            # property-not-found errors on XmlElement in PowerShell.
            [string]$name      = [string]$tc.GetAttribute('name')
            [string]$className = [string]$tc.GetAttribute('classname')
            [string]$timeAttr  = [string]$tc.GetAttribute('time')
            [double]$duration  = if ([string]::IsNullOrEmpty($timeAttr)) {
                [double]0.0
            } else {
                [double]$timeAttr
            }

            [string]$status  = 'passed'
            [string]$message = ''

            $failureNode = $tc.SelectSingleNode('failure')
            $errorNode   = $tc.SelectSingleNode('error')
            $skippedNode = $tc.SelectSingleNode('skipped')

            if ($null -ne $failureNode) {
                $status  = 'failed'
                [string]$msgAttr = [string]$failureNode.GetAttribute('message')
                $message = if (-not [string]::IsNullOrEmpty($msgAttr)) {
                    $msgAttr
                } else {
                    [string]$failureNode.InnerText
                }
            } elseif ($null -ne $errorNode) {
                $status  = 'failed'
                [string]$msgAttr = [string]$errorNode.GetAttribute('message')
                $message = if (-not [string]::IsNullOrEmpty($msgAttr)) {
                    $msgAttr
                } else {
                    [string]$errorNode.InnerText
                }
            } elseif ($null -ne $skippedNode) {
                $status = 'skipped'
            }

            $testCase = New-TestCase `
                -Name      $name `
                -ClassName $className `
                -Status    $status `
                -Duration  $duration `
                -Message   $message `
                -RunId     $RunId

            $testList.Add($testCase)
        }
    }

    [PSCustomObject[]]$testsArray = [PSCustomObject[]]@($testList.ToArray())
    return New-TestRun -RunId $RunId -Source $FilePath -Format 'junit-xml' -Tests $testsArray
}

# ──────────────────────────────────────────────────────────────
# Public: ConvertFrom-JsonTestResults
# TDD Cycle 2 — JSON parser implemented after JUnit parser tests pass.
# ──────────────────────────────────────────────────────────────
function ConvertFrom-JsonTestResults {
    <#
    .SYNOPSIS
        Parses a JSON test-results file into a TestRun object.
    .DESCRIPTION
        Supports two JSON shapes:
          { "runId": "...", "tests": [ { name, className, status, duration, message? } ] }
          { "runId": "...", "suites": [ { "name": "...", "tests": [...] } ] }
    .PARAMETER FilePath
        Path to the .json file.
    .PARAMETER RunId
        Override the run identifier. Defaults to the file's runId field, then the file name.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string]$FilePath,
        [Parameter()]          [string]$RunId = ''
    )

    if (-not (Test-Path -Path $FilePath)) {
        throw "File not found: '$FilePath'"
    }

    [string]$raw  = Get-Content -Path $FilePath -Raw
    $data = $raw | ConvertFrom-Json

    # Resolve RunId: parameter > file field > filename
    if ([string]::IsNullOrEmpty($RunId)) {
        if ($data.PSObject.Properties['runId'] -and
            -not [string]::IsNullOrEmpty([string]$data.runId)) {
            $RunId = [string]$data.runId
        } else {
            $RunId = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
        }
    }

    $testList = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Flat "tests" array — the preferred simple format.
    if ($data.PSObject.Properties['tests']) {
        foreach ($t in $data.tests) {
            [string]$msg = if ($t.PSObject.Properties['message']) {
                [string]$t.message
            } else {
                ''
            }
            $testList.Add(
                (New-TestCase `
                    -Name      ([string]$t.name) `
                    -ClassName ([string]$t.className) `
                    -Status    ([string]$t.status) `
                    -Duration  ([double]$t.duration) `
                    -Message   $msg `
                    -RunId     $RunId)
            )
        }
    } elseif ($data.PSObject.Properties['suites']) {
        # Nested suites format.
        foreach ($suite in $data.suites) {
            foreach ($t in $suite.tests) {
                [string]$className = if ($t.PSObject.Properties['className']) {
                    [string]$t.className
                } else {
                    [string]$suite.name
                }
                [string]$msg = if ($t.PSObject.Properties['message']) {
                    [string]$t.message
                } else {
                    ''
                }
                $testList.Add(
                    (New-TestCase `
                        -Name      ([string]$t.name) `
                        -ClassName $className `
                        -Status    ([string]$t.status) `
                        -Duration  ([double]$t.duration) `
                        -Message   $msg `
                        -RunId     $RunId)
                )
            }
        }
    }

    [PSCustomObject[]]$testsArray = [PSCustomObject[]]@($testList.ToArray())
    return New-TestRun -RunId $RunId -Source $FilePath -Format 'json' -Tests $testsArray
}

# ──────────────────────────────────────────────────────────────
# Public: Merge-TestRuns
# TDD Cycle 3 — aggregates an array of TestRun objects into one
#               summary suitable for reporting.
# ──────────────────────────────────────────────────────────────
function Merge-TestRuns {
    <#
    .SYNOPSIS
        Combines multiple TestRun objects into one aggregated summary.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # AllowEmptyCollection lets callers pass @() without binding errors.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$TestRuns
    )

    $allTests     = [System.Collections.Generic.List[PSCustomObject]]::new()
    [int]$passed  = 0
    [int]$failed  = 0
    [int]$skipped = 0
    [double]$dur  = [double]0.0

    foreach ($run in $TestRuns) {
        $passed  += [int]$run.Passed
        $failed  += [int]$run.Failed
        $skipped += [int]$run.Skipped
        $dur     += [double]$run.Duration
        foreach ($t in $run.Tests) {
            $allTests.Add($t)
        }
    }

    return [PSCustomObject]@{
        Runs          = $TestRuns
        AllTests      = [PSCustomObject[]]@($allTests.ToArray())
        TotalPassed   = $passed
        TotalFailed   = $failed
        TotalSkipped  = $skipped
        TotalDuration = $dur
        TotalTests    = [int]$allTests.Count
        RunCount      = [int]$TestRuns.Count
    }
}

# ──────────────────────────────────────────────────────────────
# Public: Find-FlakyTests
# TDD Cycle 4 — a test is flaky iff it passed in ≥1 run AND
#               failed in ≥1 run (skipped runs are ignored).
# ──────────────────────────────────────────────────────────────
function Find-FlakyTests {
    <#
    .SYNOPSIS
        Identifies tests whose status differs across runs.
    .DESCRIPTION
        A test is considered flaky when the same test (by FullName)
        has both at least one 'passed' result and at least one 'failed'
        result across the supplied runs. Skipped runs are not counted.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$TestRuns
    )

    # Group all individual test results by their fully-qualified name.
    $byName = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[PSCustomObject]]]::new(
        [System.StringComparer]::Ordinal
    )

    foreach ($run in $TestRuns) {
        foreach ($t in $run.Tests) {
            [string]$key = [string]$t.FullName
            if (-not $byName.ContainsKey($key)) {
                $byName[$key] = [System.Collections.Generic.List[PSCustomObject]]::new()
            }
            $byName[$key].Add($t)
        }
    }

    $flakyList = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($key in $byName.Keys) {
        $results  = $byName[$key]
        [int]$p   = [int]($results | Where-Object { [string]$_.Status -eq 'passed' } | Measure-Object).Count
        [int]$f   = [int]($results | Where-Object { [string]$_.Status -eq 'failed' } | Measure-Object).Count

        if ($p -gt 0 -and $f -gt 0) {
            $flakyList.Add([PSCustomObject]@{
                FullName  = $key
                PassCount = $p
                FailCount = $f
                TotalRuns = [int]$results.Count
                Results   = [PSCustomObject[]]@($results.ToArray())
            })
        }
    }

    return [PSCustomObject[]]@($flakyList.ToArray())
}

# ──────────────────────────────────────────────────────────────
# Public: New-MarkdownSummary
# TDD Cycle 5 — renders the aggregated data as GitHub-flavoured
#               Markdown for use as a job summary.
# ──────────────────────────────────────────────────────────────
function New-MarkdownSummary {
    <#
    .SYNOPSIS
        Generates a Markdown job summary from aggregated test results.
    .PARAMETER AggregatedResults
        Output of Merge-TestRuns.
    .PARAMETER FlakyTests
        Output of Find-FlakyTests (may be empty).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [PSCustomObject]    $AggregatedResults,
        [Parameter()]          [PSCustomObject[]]  $FlakyTests = [PSCustomObject[]]@()
    )

    $sb = [System.Text.StringBuilder]::new()

    # ── Overall summary table ─────────────────────────────────
    [void]$sb.AppendLine('## Test Results Summary')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Metric | Value |')
    [void]$sb.AppendLine('|--------|------:|')
    [void]$sb.AppendLine("| Total Tests | $([int]$AggregatedResults.TotalTests) |")
    [void]$sb.AppendLine("| Passed      | $([int]$AggregatedResults.TotalPassed) |")
    [void]$sb.AppendLine("| Failed      | $([int]$AggregatedResults.TotalFailed) |")
    [void]$sb.AppendLine("| Skipped     | $([int]$AggregatedResults.TotalSkipped) |")
    [double]$roundedDur = [math]::Round([double]$AggregatedResults.TotalDuration, 2)
    [void]$sb.AppendLine("| Duration    | ${roundedDur}s |")
    [void]$sb.AppendLine("| Runs        | $([int]$AggregatedResults.RunCount) |")
    [void]$sb.AppendLine('')

    # ── Per-run breakdown table ───────────────────────────────
    [void]$sb.AppendLine('### Results by Run')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Run | Passed | Failed | Skipped | Duration |')
    [void]$sb.AppendLine('|-----|-------:|-------:|--------:|---------:|')

    foreach ($run in $AggregatedResults.Runs) {
        [double]$runDur = [math]::Round([double]$run.Duration, 2)
        [void]$sb.AppendLine("| $([string]$run.RunId) | $([int]$run.Passed) | $([int]$run.Failed) | $([int]$run.Skipped) | ${runDur}s |")
    }
    [void]$sb.AppendLine('')

    # ── Flaky tests section ───────────────────────────────────
    [int]$flakyCount = [int]$FlakyTests.Count

    if ($flakyCount -gt 0) {
        [void]$sb.AppendLine("### Flaky Tests ($flakyCount)")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('These tests produced inconsistent results across runs:')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('| Test | Passed | Failed | Total Runs |')
        [void]$sb.AppendLine('|------|-------:|-------:|-----------:|')

        foreach ($ft in $FlakyTests) {
            [void]$sb.AppendLine("| $([string]$ft.FullName) | $([int]$ft.PassCount) | $([int]$ft.FailCount) | $([int]$ft.TotalRuns) |")
        }
    } else {
        [void]$sb.AppendLine('### Flaky Tests')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('No flaky tests detected.')
    }
    [void]$sb.AppendLine('')

    return [string]$sb.ToString()
}

# ──────────────────────────────────────────────────────────────
# Public: Invoke-TestResultsAggregator
# TDD Cycle 6 — top-level orchestration; drives the full pipeline.
# ──────────────────────────────────────────────────────────────
function Invoke-TestResultsAggregator {
    <#
    .SYNOPSIS
        Parses, aggregates, and (optionally) renders a summary for a
        set of test-result files from a matrix CI build.
    .PARAMETER FilePaths
        Array of .xml (JUnit) or .json test-result file paths.
    .PARAMETER GenerateMarkdown
        When present, populates the Markdown property of the returned object.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string[]]$FilePaths,
        [Parameter()]          [switch] $GenerateMarkdown
    )

    $runList = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($path in $FilePaths) {
        [string]$ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()

        [PSCustomObject]$run = switch ($ext) {
            '.xml'  { ConvertFrom-JUnitXml        -FilePath $path }
            '.json' { ConvertFrom-JsonTestResults -FilePath $path }
            default {
                throw "Unsupported file format: '$ext' for '$path'. Supported: .xml (JUnit), .json"
            }
        }

        $runList.Add($run)
    }

    [PSCustomObject[]]$runs   = [PSCustomObject[]]@($runList.ToArray())
    [PSCustomObject]$agg      = Merge-TestRuns  -TestRuns $runs
    [PSCustomObject[]]$flaky  = Find-FlakyTests -TestRuns $runs

    [string]$markdown = ''
    if ($GenerateMarkdown) {
        $markdown = New-MarkdownSummary -AggregatedResults $agg -FlakyTests $flaky
    }

    return [PSCustomObject]@{
        AggregatedResults = $agg
        FlakyTests        = $flaky
        Markdown          = $markdown
    }
}

# ── Module exports ────────────────────────────────────────────
Export-ModuleMember -Function @(
    'ConvertFrom-JUnitXml'
    'ConvertFrom-JsonTestResults'
    'Merge-TestRuns'
    'Find-FlakyTests'
    'New-MarkdownSummary'
    'Invoke-TestResultsAggregator'
)
