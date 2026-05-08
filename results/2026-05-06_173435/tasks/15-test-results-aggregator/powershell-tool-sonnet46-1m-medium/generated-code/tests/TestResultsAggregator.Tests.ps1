# TestResultsAggregator.Tests.ps1
# Pester test suite for the Test Results Aggregator script.
#
# TDD methodology:
#   RED   - each Describe/It was written before the corresponding implementation
#   GREEN - minimum code written to make each test pass
#   REFACTOR - code cleaned up while keeping tests green

BeforeAll {
    # Dot-source the main script to load all functions without running main logic.
    # $InputPath is empty so the guard at the bottom of the script does not execute.
    . "$PSScriptRoot/../Invoke-TestResultsAggregator.ps1"

    # ---------------------------------------------------------------------------
    # Test-only helpers for generating fixture XML/JSON strings.
    # These must live in BeforeAll so Pester 5's run-phase scope can see them.
    # ---------------------------------------------------------------------------
    function New-JUnitXml {
        param([string]$SuiteName, [array]$Cases)
        $failures = ($Cases | Where-Object { $_.Status -eq 'failed' }).Count
        $skipped  = ($Cases | Where-Object { $_.Status -eq 'skipped' }).Count
        $tcLines = foreach ($c in $Cases) {
            $inner = switch ($c.Status) {
                'failed'  { "      <failure message=`"$($c.Error)`">AssertionError</failure>" }
                'skipped' { "      <skipped/>" }
                default   { "" }
            }
            "    <testcase name=`"$($c.Name)`" classname=`"$SuiteName`" time=`"$($c.Duration)`">`n$inner`n    </testcase>"
        }
        @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="$SuiteName" tests="$($Cases.Count)" failures="$failures" skipped="$skipped">
$($tcLines -join "`n")
  </testsuite>
</testsuites>
"@
    }

    function New-JsonResult {
        param([string]$SuiteName, [array]$Cases)
        $tests = $Cases | ForEach-Object {
            $err = if ($_.ContainsKey('Error') -and $_.Error) { ", `"error`": `"$($_.Error)`"" } else { "" }
            "    { `"name`": `"$($_.Name)`", `"status`": `"$($_.Status)`", `"duration`": $($_.Duration)$err }"
        }
        @"
{
  "suiteName": "$SuiteName",
  "tests": [
$($tests -join ",`n")
  ]
}
"@
    }
}

# ===========================================================================
# TDD RED → GREEN: ConvertFrom-JUnitXml
# ===========================================================================
Describe "ConvertFrom-JUnitXml" {
    BeforeAll {
        $xml = New-JUnitXml -SuiteName "Suite.Unit" -Cases @(
            @{ Name = "TestA"; Status = "passed";  Duration = 0.10; Error = "" },
            @{ Name = "TestB"; Status = "failed";  Duration = 0.20; Error = "Expected 1 got 2" },
            @{ Name = "TestC"; Status = "passed";  Duration = 0.30; Error = "" },
            @{ Name = "TestD"; Status = "skipped"; Duration = 0.00; Error = "" }
        )
        Set-Content -Path "TestDrive:\junit-run1.xml" -Value $xml
    }

    It "returns a result object from a valid JUnit XML file" {
        $result = ConvertFrom-JUnitXml -Path "TestDrive:\junit-run1.xml"
        $result | Should -Not -BeNullOrEmpty
    }

    It "parses the suite name" {
        $result = ConvertFrom-JUnitXml -Path "TestDrive:\junit-run1.xml"
        $result.SuiteName | Should -Be "Suite.Unit"
    }

    It "counts tests correctly" {
        $result = ConvertFrom-JUnitXml -Path "TestDrive:\junit-run1.xml"
        $result.Tests.Count | Should -Be 4
        $result.Passed       | Should -Be 2
        $result.Failed       | Should -Be 1
        $result.Skipped      | Should -Be 1
    }

    It "captures individual test statuses" {
        $result = ConvertFrom-JUnitXml -Path "TestDrive:\junit-run1.xml"
        ($result.Tests | Where-Object Name -eq "TestA").Status | Should -Be "passed"
        ($result.Tests | Where-Object Name -eq "TestB").Status | Should -Be "failed"
        ($result.Tests | Where-Object Name -eq "TestD").Status | Should -Be "skipped"
    }

    It "sums duration correctly" {
        $result = ConvertFrom-JUnitXml -Path "TestDrive:\junit-run1.xml"
        # 0.10 + 0.20 + 0.30 + 0.00 = 0.60
        [math]::Round($result.Duration, 2) | Should -Be 0.60
    }

    It "throws a meaningful error for a missing file" {
        { ConvertFrom-JUnitXml -Path "TestDrive:\nonexistent.xml" } | Should -Throw
    }
}

# ===========================================================================
# TDD RED → GREEN: ConvertFrom-TestResultJson
# ===========================================================================
Describe "ConvertFrom-TestResultJson" {
    BeforeAll {
        $json = New-JsonResult -SuiteName "Suite.Integration" -Cases @(
            @{ Name = "TestE"; Status = "passed"; Duration = 0.40 },
            @{ Name = "TestF"; Status = "failed"; Duration = 0.50; Error = "Connection refused" }
        )
        Set-Content -Path "TestDrive:\json-run1.json" -Value $json
    }

    It "returns a result object from a valid JSON file" {
        $result = ConvertFrom-TestResultJson -Path "TestDrive:\json-run1.json"
        $result | Should -Not -BeNullOrEmpty
    }

    It "parses suite name and test counts" {
        $result = ConvertFrom-TestResultJson -Path "TestDrive:\json-run1.json"
        $result.SuiteName   | Should -Be "Suite.Integration"
        $result.Tests.Count | Should -Be 2
        $result.Passed      | Should -Be 1
        $result.Failed      | Should -Be 1
        $result.Skipped     | Should -Be 0
    }

    It "captures error message from failed test" {
        $result = ConvertFrom-TestResultJson -Path "TestDrive:\json-run1.json"
        $failed = $result.Tests | Where-Object Name -eq "TestF"
        $failed.Error | Should -Be "Connection refused"
    }

    It "throws a meaningful error for a missing file" {
        { ConvertFrom-TestResultJson -Path "TestDrive:\no.json" } | Should -Throw
    }
}

# ===========================================================================
# TDD RED → GREEN: Merge-TestResults
# ===========================================================================
Describe "Merge-TestResults" {
    BeforeAll {
        # Two runs of the same suite; TestC is flaky (passed then failed)
        $Script:RunA = @{
            SuiteName = "Suite.Unit"
            Duration  = 0.60
            Passed    = 2; Failed = 1; Skipped = 1
            Tests     = @(
                @{ Name = "TestA"; Status = "passed";  Duration = 0.10; Error = "" },
                @{ Name = "TestB"; Status = "failed";  Duration = 0.20; Error = "err" },
                @{ Name = "TestC"; Status = "passed";  Duration = 0.30; Error = "" },
                @{ Name = "TestD"; Status = "skipped"; Duration = 0.00; Error = "" }
            )
        }
        $Script:RunB = @{
            SuiteName = "Suite.Unit"
            Duration  = 0.75
            Passed    = 1; Failed = 2; Skipped = 1
            Tests     = @(
                @{ Name = "TestA"; Status = "passed";  Duration = 0.15; Error = "" },
                @{ Name = "TestB"; Status = "failed";  Duration = 0.25; Error = "err" },
                @{ Name = "TestC"; Status = "failed";  Duration = 0.35; Error = "timeout" },
                @{ Name = "TestD"; Status = "skipped"; Duration = 0.00; Error = "" }
            )
        }
    }

    It "merges two runs into correct totals" {
        $agg = Merge-TestResults -RunResults @($Script:RunA, $Script:RunB)
        $agg.TotalTests | Should -Be 8
        $agg.Passed     | Should -Be 3
        $agg.Failed     | Should -Be 3
        $agg.Skipped    | Should -Be 2
    }

    It "accumulates duration across runs" {
        $agg = Merge-TestResults -RunResults @($Script:RunA, $Script:RunB)
        # 0.60 + 0.75 = 1.35 accumulated from individual test durations
        [math]::Round($agg.Duration, 2) | Should -Be 1.35
    }

    It "tracks per-test pass/fail counts for flaky detection" {
        $agg = Merge-TestResults -RunResults @($Script:RunA, $Script:RunB)
        $key = "Suite.Unit/TestC"
        $agg.TestSummary[$key].PassedRuns | Should -Be 1
        $agg.TestSummary[$key].FailedRuns | Should -Be 1
    }
}

# ===========================================================================
# TDD RED → GREEN: Find-FlakyTests
# ===========================================================================
Describe "Find-FlakyTests" {
    It "identifies tests that both passed and failed across runs" {
        $testSummary = @{
            "Suite.Unit/TestA" = @{ Name = "TestA"; Suite = "Suite.Unit"; PassedRuns = 2; FailedRuns = 0; SkippedRuns = 0 }
            "Suite.Unit/TestB" = @{ Name = "TestB"; Suite = "Suite.Unit"; PassedRuns = 0; FailedRuns = 2; SkippedRuns = 0 }
            "Suite.Unit/TestC" = @{ Name = "TestC"; Suite = "Suite.Unit"; PassedRuns = 1; FailedRuns = 1; SkippedRuns = 0 }
        }
        $agg = @{ TestSummary = $testSummary }
        # Force [array] to prevent PowerShell's single-item unrolling
        [array]$flaky = Find-FlakyTests -Aggregated $agg
        $flaky.Count     | Should -Be 1
        $flaky[0].Name   | Should -Be "TestC"
    }

    It "returns empty array when no flaky tests exist" {
        $testSummary = @{
            "Suite.Unit/TestA" = @{ Name = "TestA"; Suite = "Suite.Unit"; PassedRuns = 2; FailedRuns = 0; SkippedRuns = 0 }
        }
        $agg = @{ TestSummary = $testSummary }
        [array]$flaky = Find-FlakyTests -Aggregated $agg
        $flaky.Count | Should -Be 0
    }
}

# ===========================================================================
# TDD RED → GREEN: New-MarkdownSummary
# ===========================================================================
Describe "New-MarkdownSummary" {
    BeforeAll {
        $Script:Agg = @{
            TotalTests  = 12
            Passed      = 6
            Failed      = 4
            Skipped     = 2
            Duration    = 3.25
            TestSummary = @{}
        }
        $Script:Flaky = @(
            @{ Name = "TestC"; Suite = "Suite.UnitTests";        PassedRuns = 1; FailedRuns = 1 },
            @{ Name = "TestF"; Suite = "Suite.IntegrationTests"; PassedRuns = 1; FailedRuns = 1 }
        )
    }

    It "contains the summary table with correct totals" {
        $md = New-MarkdownSummary -Aggregated $Script:Agg -FlakyTests $Script:Flaky
        $md | Should -Match '\| Total\s*\|\s*12\s*\|'
        $md | Should -Match '\| Passed\s*\|\s*6\s*\|'
        $md | Should -Match '\| Failed\s*\|\s*4\s*\|'
        $md | Should -Match '\| Skipped\s*\|\s*2\s*\|'
        $md | Should -Match '3\.25s'
    }

    It "lists flaky tests by name" {
        $md = New-MarkdownSummary -Aggregated $Script:Agg -FlakyTests $Script:Flaky
        $md | Should -Match 'TestC'
        $md | Should -Match 'TestF'
    }

    It "shows flaky count in section header" {
        $md = New-MarkdownSummary -Aggregated $Script:Agg -FlakyTests $Script:Flaky
        $md | Should -Match 'Flaky Tests \(2\)'
    }

    It "shows 'No flaky tests' when there are none" {
        # Must use explicit empty array so the [AllowEmptyCollection()] path is exercised
        $emptyFlaky = @()
        $md = New-MarkdownSummary -Aggregated $Script:Agg -FlakyTests $emptyFlaky
        $md | Should -Match 'No flaky tests'
    }
}

# ===========================================================================
# TDD RED → GREEN: Workflow structure verification
# ===========================================================================
Describe "Workflow structure" {
    BeforeAll {
        $Script:WorkflowPath = "$PSScriptRoot/../.github/workflows/test-results-aggregator.yml"
        $Script:ScriptPath   = "$PSScriptRoot/../Invoke-TestResultsAggregator.ps1"
    }

    It "workflow file exists" {
        $Script:WorkflowPath | Should -Exist
    }

    It "main script file exists" {
        $Script:ScriptPath | Should -Exist
    }

    It "workflow has push trigger" {
        $content = Get-Content $Script:WorkflowPath -Raw
        $content | Should -Match '\bpush\b'
    }

    It "workflow has pull_request trigger" {
        $content = Get-Content $Script:WorkflowPath -Raw
        $content | Should -Match 'pull_request'
    }

    It "workflow has workflow_dispatch trigger" {
        $content = Get-Content $Script:WorkflowPath -Raw
        $content | Should -Match 'workflow_dispatch'
    }

    It "workflow references the aggregator script" {
        $content = Get-Content $Script:WorkflowPath -Raw
        $content | Should -Match 'Invoke-TestResultsAggregator'
    }

    It "workflow uses shell: pwsh for run steps" {
        $content = Get-Content $Script:WorkflowPath -Raw
        $content | Should -Match 'shell:\s*pwsh'
    }

    It "actionlint validates the workflow" {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlint) {
            Set-ItResult -Skipped -Because "actionlint not available in this environment"
            return
        }
        $output = & actionlint $Script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}

# ===========================================================================
# TDD RED → GREEN: End-to-end aggregation (integration)
# ===========================================================================
Describe "End-to-end aggregation" {
    BeforeAll {
        $xml1 = New-JUnitXml -SuiteName "Suite.UnitTests" -Cases @(
            @{ Name = "TestA"; Status = "passed";  Duration = 0.10; Error = "" },
            @{ Name = "TestB"; Status = "failed";  Duration = 0.20; Error = "Expected 1 got 2" },
            @{ Name = "TestC"; Status = "passed";  Duration = 0.30; Error = "" },
            @{ Name = "TestD"; Status = "skipped"; Duration = 0.00; Error = "" }
        )
        $xml2 = New-JUnitXml -SuiteName "Suite.UnitTests" -Cases @(
            @{ Name = "TestA"; Status = "passed";  Duration = 0.15; Error = "" },
            @{ Name = "TestB"; Status = "failed";  Duration = 0.25; Error = "Expected 1 got 2" },
            @{ Name = "TestC"; Status = "failed";  Duration = 0.35; Error = "Timeout" },
            @{ Name = "TestD"; Status = "skipped"; Duration = 0.00; Error = "" }
        )
        $json1 = New-JsonResult -SuiteName "Suite.IntegrationTests" -Cases @(
            @{ Name = "TestE"; Status = "passed"; Duration = 0.40 },
            @{ Name = "TestF"; Status = "passed"; Duration = 0.50 }
        )
        $json2 = New-JsonResult -SuiteName "Suite.IntegrationTests" -Cases @(
            @{ Name = "TestE"; Status = "passed"; Duration = 0.45 },
            @{ Name = "TestF"; Status = "failed"; Duration = 0.55; Error = "Connection refused" }
        )

        $fixtureDir = "TestDrive:\fixtures"
        New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null
        Set-Content -Path "$fixtureDir\junit-run1.xml"  -Value $xml1
        Set-Content -Path "$fixtureDir\junit-run2.xml"  -Value $xml2
        Set-Content -Path "$fixtureDir\json-run1.json"  -Value $json1
        Set-Content -Path "$fixtureDir\json-run2.json"  -Value $json2

        $Script:E2ESummary = Invoke-TestResultsAggregator -InputPath $fixtureDir
    }

    It "produces a non-empty markdown summary" {
        $Script:E2ESummary | Should -Not -BeNullOrEmpty
    }

    It "reports correct total (12 test runs across 4 files)" {
        $Script:E2ESummary | Should -Match '\| Total\s*\|\s*12\s*\|'
    }

    It "reports 6 passed" {
        $Script:E2ESummary | Should -Match '\| Passed\s*\|\s*6\s*\|'
    }

    It "reports 4 failed" {
        $Script:E2ESummary | Should -Match '\| Failed\s*\|\s*4\s*\|'
    }

    It "reports 2 skipped" {
        $Script:E2ESummary | Should -Match '\| Skipped\s*\|\s*2\s*\|'
    }

    It "reports total duration of 3.25s" {
        $Script:E2ESummary | Should -Match '3\.25s'
    }

    It "identifies TestC as flaky" {
        $Script:E2ESummary | Should -Match 'TestC'
    }

    It "identifies TestF as flaky" {
        $Script:E2ESummary | Should -Match 'TestF'
    }
}
