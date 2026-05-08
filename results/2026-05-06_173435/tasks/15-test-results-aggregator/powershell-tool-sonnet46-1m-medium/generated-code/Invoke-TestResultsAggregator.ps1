# Invoke-TestResultsAggregator.ps1
# Aggregates test results from JUnit XML and JSON files across a matrix build.
# Functions are defined first so this file can be dot-sourced by Pester tests.
# Main logic runs only when $InputPath is supplied (direct invocation).

param(
    [string]$InputPath = "",   # directory containing test result files
    [string]$OutputPath = ""   # optional markdown output file; prints to stdout if empty
)

# ---------------------------------------------------------------------------
# Parse a JUnit XML test result file.
# Returns a hashtable: SuiteName, Tests[], Passed, Failed, Skipped, Duration
# ---------------------------------------------------------------------------
function ConvertFrom-JUnitXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "File not found: $Path"
    }

    try {
        [xml]$xml = Get-Content -Path $Path -Raw -ErrorAction Stop
    }
    catch {
        throw "Failed to parse JUnit XML '$Path': $_"
    }

    $result = @{
        SuiteName = ""
        Tests     = [System.Collections.Generic.List[hashtable]]::new()
        Passed    = 0
        Failed    = 0
        Skipped   = 0
        Duration  = 0.0
    }

    # Support both <testsuites><testsuite> and bare <testsuite> root elements
    $suites = if ($xml.testsuites) { $xml.testsuites.testsuite } else { $xml.testsuite }

    foreach ($suite in $suites) {
        if (-not $result.SuiteName) { $result.SuiteName = $suite.name }

        foreach ($tc in $suite.testcase) {
            $duration = if ($tc.time) { [double]$tc.time } else { 0.0 }
            $test = @{
                Name      = $tc.name
                ClassName = $tc.classname
                Duration  = $duration
                Status    = "passed"
                Error     = ""
            }

            if ($tc.failure) {
                $test.Status = "failed"
                $test.Error  = if ($tc.failure.message) { $tc.failure.message } else { "failure" }
                $result.Failed++
            }
            elseif ($tc.error) {
                $test.Status = "failed"
                $test.Error  = if ($tc.error.message) { $tc.error.message } else { "error" }
                $result.Failed++
            }
            elseif ($tc.skipped -ne $null) {
                $test.Status = "skipped"
                $result.Skipped++
            }
            else {
                $result.Passed++
            }

            $result.Duration += $duration
            $result.Tests.Add($test)
        }
    }

    return $result
}

# ---------------------------------------------------------------------------
# Parse a JSON test result file.
# Expected schema: { suiteName, tests: [{ name, status, duration, error? }] }
# Returns same hashtable shape as ConvertFrom-JUnitXml.
# ---------------------------------------------------------------------------
function ConvertFrom-TestResultJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "File not found: $Path"
    }

    try {
        $data = Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse JSON '$Path': $_"
    }

    $result = @{
        SuiteName = $data.suiteName
        Tests     = [System.Collections.Generic.List[hashtable]]::new()
        Passed    = 0
        Failed    = 0
        Skipped   = 0
        Duration  = 0.0
    }

    foreach ($t in $data.tests) {
        $err = ""
        if ($t.PSObject.Properties['error']) { $err = $t.error }

        $test = @{
            Name      = $t.name
            ClassName = $data.suiteName
            Duration  = [double]$t.duration
            Status    = $t.status
            Error     = $err
        }

        switch ($t.status) {
            "passed"  { $result.Passed++ }
            "failed"  { $result.Failed++ }
            "skipped" { $result.Skipped++ }
        }

        $result.Duration += [double]$t.duration
        $result.Tests.Add($test)
    }

    return $result
}

# ---------------------------------------------------------------------------
# Merge an array of RunResult objects (from ConvertFrom-JUnitXml / Json) into
# aggregated totals and per-test pass/fail counts for flaky detection.
# ---------------------------------------------------------------------------
function Merge-TestResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$RunResults
    )

    $aggregated = @{
        TotalFiles   = $RunResults.Count
        TotalTests   = 0
        Passed       = 0
        Failed       = 0
        Skipped      = 0
        Duration     = 0.0
        TestSummary  = [System.Collections.Generic.Dictionary[string,hashtable]]::new()
    }

    foreach ($run in $RunResults) {
        $aggregated.Duration += $run.Duration

        foreach ($test in $run.Tests) {
            $key = "$($run.SuiteName)/$($test.Name)"

            if (-not $aggregated.TestSummary.ContainsKey($key)) {
                $aggregated.TestSummary[$key] = @{
                    Name        = $test.Name
                    Suite       = $run.SuiteName
                    PassedRuns  = 0
                    FailedRuns  = 0
                    SkippedRuns = 0
                }
            }

            switch ($test.Status) {
                "passed"  { $aggregated.TestSummary[$key].PassedRuns++;  $aggregated.Passed++ }
                "failed"  { $aggregated.TestSummary[$key].FailedRuns++;  $aggregated.Failed++ }
                "skipped" { $aggregated.TestSummary[$key].SkippedRuns++; $aggregated.Skipped++ }
            }

            $aggregated.TotalTests++
        }
    }

    return $aggregated
}

# ---------------------------------------------------------------------------
# Return test entries that both passed AND failed across different runs.
# ---------------------------------------------------------------------------
function Find-FlakyTests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Aggregated
    )

    # Use Where-Object pipeline; caller should use [array] to prevent unrolling
    return @($Aggregated.TestSummary.Values | Where-Object { $_.PassedRuns -gt 0 -and $_.FailedRuns -gt 0 })
}

# ---------------------------------------------------------------------------
# Render aggregated results and flaky tests as a GitHub-flavoured markdown summary.
# ---------------------------------------------------------------------------
function New-MarkdownSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Aggregated,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$FlakyTests
    )

    $dur = [math]::Round($Aggregated.Duration, 2)

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("## Test Results Summary")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Metric | Value |")
    [void]$sb.AppendLine("|--------|-------|")
    [void]$sb.AppendLine("| Total | $($Aggregated.TotalTests) |")
    [void]$sb.AppendLine("| Passed | $($Aggregated.Passed) |")
    [void]$sb.AppendLine("| Failed | $($Aggregated.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($Aggregated.Skipped) |")
    [void]$sb.AppendLine("| Duration | ${dur}s |")
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("## Flaky Tests ($($FlakyTests.Count))")
    [void]$sb.AppendLine("")

    if ($FlakyTests.Count -gt 0) {
        [void]$sb.AppendLine("| Test | Suite | Passed Runs | Failed Runs |")
        [void]$sb.AppendLine("|------|-------|-------------|-------------|")
        foreach ($t in ($FlakyTests | Sort-Object Name)) {
            [void]$sb.AppendLine("| $($t.Name) | $($t.Suite) | $($t.PassedRuns) | $($t.FailedRuns) |")
        }
    }
    else {
        [void]$sb.AppendLine("No flaky tests detected.")
    }

    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# High-level entry point: discover files, parse, aggregate, return markdown.
# Used directly by the workflow and by end-to-end Pester tests.
# ---------------------------------------------------------------------------
function Invoke-TestResultsAggregator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [string]$OutputPath = ""
    )

    if (-not (Test-Path -Path $InputPath -PathType Container)) {
        Write-Error "Input directory not found: $InputPath"
        exit 1
    }

    $runResults = [System.Collections.Generic.List[hashtable]]::new()

    # Parse JUnit XML files
    Get-ChildItem -Path $InputPath -Filter "*.xml" | ForEach-Object {
        try {
            $r = ConvertFrom-JUnitXml -Path $_.FullName
            $runResults.Add($r)
            Write-Verbose "Parsed XML: $($_.Name) -> $($r.Tests.Count) tests"
        }
        catch {
            Write-Warning "Skipping $($_.Name): $_"
        }
    }

    # Parse JSON test result files
    Get-ChildItem -Path $InputPath -Filter "*.json" | ForEach-Object {
        try {
            $r = ConvertFrom-TestResultJson -Path $_.FullName
            $runResults.Add($r)
            Write-Verbose "Parsed JSON: $($_.Name) -> $($r.Tests.Count) tests"
        }
        catch {
            Write-Warning "Skipping $($_.Name): $_"
        }
    }

    if ($runResults.Count -eq 0) {
        Write-Warning "No test result files found in: $InputPath"
    }

    $aggregated         = Merge-TestResults -RunResults @($runResults)
    [array]$flaky       = Find-FlakyTests   -Aggregated $aggregated
    if ($null -eq $flaky) { $flaky = @() }
    $summary            = New-MarkdownSummary -Aggregated $aggregated -FlakyTests $flaky

    if ($OutputPath) {
        Set-Content -Path $OutputPath -Value $summary
        Write-Verbose "Summary written to: $OutputPath"
    }

    return $summary
}

# ---------------------------------------------------------------------------
# Main: runs only when the script is invoked directly (not dot-sourced by tests)
# ---------------------------------------------------------------------------
if ($InputPath) {
    $summary = Invoke-TestResultsAggregator -InputPath $InputPath -OutputPath $OutputPath
    Write-Host $summary

    if ($env:GITHUB_STEP_SUMMARY) {
        Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $summary
    }
}
