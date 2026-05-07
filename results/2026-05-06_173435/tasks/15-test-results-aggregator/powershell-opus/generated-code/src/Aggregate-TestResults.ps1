# Test Results Aggregator
# Parses JUnit XML and JSON test result files, aggregates across matrix runs,
# computes totals, identifies flaky tests, and generates a markdown summary.

function Import-JUnitResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File does not exist: $Path"
    }

    [xml]$xml = Get-Content -Path $Path -Raw
    $suiteNode = $xml.SelectSingleNode('//testsuite')

    $tests = [System.Collections.ArrayList]::new()
    foreach ($tc in $suiteNode.SelectNodes('testcase')) {
        $status = 'passed'
        $message = ''

        $failureNode = $tc.SelectSingleNode('failure')
        $skippedNode = $tc.SelectSingleNode('skipped')

        if ($failureNode) {
            $status = 'failed'
            $message = $failureNode.GetAttribute('message')
        }
        elseif ($skippedNode) {
            $status = 'skipped'
            $message = $skippedNode.GetAttribute('message')
        }

        [void]$tests.Add(@{
            Name     = $tc.GetAttribute('name')
            Status   = $status
            Duration = [double]$tc.GetAttribute('time')
            Message  = $message
        })
    }

    return @{
        Source = [System.IO.Path]::GetFileName($Path)
        Suite  = $suiteNode.GetAttribute('name')
        Tests  = @($tests)
    }
}

function Import-JsonResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File does not exist: $Path"
    }

    $json = Get-Content -Path $Path -Raw | ConvertFrom-Json

    $tests = [System.Collections.ArrayList]::new()
    foreach ($t in $json.tests) {
        [void]$tests.Add(@{
            Name     = $t.name
            Status   = $t.status
            Duration = [double]$t.duration
            Message  = if ($t.message) { [string]$t.message } else { '' }
        })
    }

    return @{
        Source = [System.IO.Path]::GetFileName($Path)
        Suite  = $json.suite
        Tests  = @($tests)
    }
}

function Get-FlakyTests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results
    )

    $testOutcomes = @{}
    foreach ($run in $Results) {
        foreach ($test in $run.Tests) {
            if (-not $testOutcomes.ContainsKey($test.Name)) {
                $testOutcomes[$test.Name] = [System.Collections.ArrayList]::new()
            }
            [void]$testOutcomes[$test.Name].Add($test.Status)
        }
    }

    $flaky = [System.Collections.ArrayList]::new()
    foreach ($testName in ($testOutcomes.Keys | Sort-Object)) {
        $statuses = $testOutcomes[$testName]
        $hasPassed = 'passed' -in $statuses
        $hasFailed = 'failed' -in $statuses
        if ($hasPassed -and $hasFailed) {
            $passCount = @($statuses | Where-Object { $_ -eq 'passed' }).Count
            $failCount = @($statuses | Where-Object { $_ -eq 'failed' }).Count
            [void]$flaky.Add(@{
                Name      = $testName
                PassCount = $passCount
                FailCount = $failCount
            })
        }
    }

    return @($flaky)
}

function Get-FailedTestDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results
    )

    # Collect all outcomes per test
    $testOutcomes = @{}
    foreach ($run in $Results) {
        foreach ($test in $run.Tests) {
            if (-not $testOutcomes.ContainsKey($test.Name)) {
                $testOutcomes[$test.Name] = @{
                    Statuses = [System.Collections.ArrayList]::new()
                    Suite    = $run.Suite
                    Message  = ''
                }
            }
            [void]$testOutcomes[$test.Name].Statuses.Add($test.Status)
            if ($test.Status -eq 'failed' -and $test.Message) {
                $testOutcomes[$test.Name].Message = $test.Message
                $testOutcomes[$test.Name].Suite = $run.Suite
            }
        }
    }

    # Only include tests that always fail (never passed) — excludes flaky tests
    $failed = [System.Collections.ArrayList]::new()
    foreach ($testName in ($testOutcomes.Keys | Sort-Object)) {
        $info = $testOutcomes[$testName]
        $hasFailed = 'failed' -in $info.Statuses
        $hasPassed = 'passed' -in $info.Statuses
        if ($hasFailed -and -not $hasPassed) {
            [void]$failed.Add(@{
                Name    = $testName
                Suite   = $info.Suite
                Message = $info.Message
            })
        }
    }

    return @($failed)
}

function Merge-TestResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results
    )

    $totalTests = 0
    $passed = 0
    $failed = 0
    $skipped = 0
    $duration = 0.0

    foreach ($run in $Results) {
        foreach ($test in $run.Tests) {
            $totalTests++
            switch ($test.Status) {
                'passed'  { $passed++ }
                'failed'  { $failed++ }
                'skipped' { $skipped++ }
            }
            $duration += $test.Duration
        }
    }

    $flakyTests = Get-FlakyTests -Results $Results
    $failedTests = Get-FailedTestDetails -Results $Results

    return @{
        TotalTests  = $totalTests
        Passed      = $passed
        Failed      = $failed
        Skipped     = $skipped
        Duration    = [math]::Round($duration, 2)
        FlakyTests  = $flakyTests
        FailedTests = $failedTests
    }
}

function Export-MarkdownSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Summary
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine('# Test Results Summary')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Totals')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Metric | Count |')
    [void]$sb.AppendLine('|--------|-------|')
    [void]$sb.AppendLine("| Total | $($Summary.TotalTests) |")
    [void]$sb.AppendLine("| Passed | $($Summary.Passed) |")
    [void]$sb.AppendLine("| Failed | $($Summary.Failed) |")
    [void]$sb.AppendLine("| Skipped | $($Summary.Skipped) |")

    $durationStr = $Summary.Duration.ToString('F2')
    [void]$sb.AppendLine("| Duration | ${durationStr}s |")
    [void]$sb.AppendLine()

    if ($Summary.FlakyTests -and $Summary.FlakyTests.Count -gt 0) {
        [void]$sb.AppendLine('## Flaky Tests')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Test Name | Pass Count | Fail Count |')
        [void]$sb.AppendLine('|-----------|------------|------------|')
        foreach ($ft in $Summary.FlakyTests) {
            [void]$sb.AppendLine("| $($ft.Name) | $($ft.PassCount) | $($ft.FailCount) |")
        }
        [void]$sb.AppendLine()
    }

    if ($Summary.FailedTests -and $Summary.FailedTests.Count -gt 0) {
        [void]$sb.AppendLine('## Failed Tests')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Test Name | Suite | Message |')
        [void]$sb.AppendLine('|-----------|-------|---------|')
        foreach ($ft in $Summary.FailedTests) {
            [void]$sb.AppendLine("| $($ft.Name) | $($ft.Suite) | $($ft.Message) |")
        }
        [void]$sb.AppendLine()
    }

    return $sb.ToString()
}
