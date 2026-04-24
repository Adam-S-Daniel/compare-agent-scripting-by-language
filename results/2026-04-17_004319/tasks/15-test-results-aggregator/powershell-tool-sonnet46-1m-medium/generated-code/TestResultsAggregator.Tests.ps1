# TestResultsAggregator.Tests.ps1
# Pester v5 test suite for the Test Results Aggregator script.
# TDD: these tests were written before the implementation and drove the design.
# Run with: Invoke-Pester -Path ./TestResultsAggregator.Tests.ps1

BeforeAll {
    # Dot-source the implementation so all functions are available for testing
    . "$PSScriptRoot/Invoke-TestResultsAggregator.ps1"
}

# ============================================================
# RED phase test: parse JUnit XML files
# ============================================================
Describe "Get-JUnitResults" {
    BeforeAll {
        $FixturePath16 = "$PSScriptRoot/fixtures/junit-node16.xml"
        $FixturePath18 = "$PSScriptRoot/fixtures/junit-node18.xml"
    }

    It "returns RunName derived from filename" {
        $result = Get-JUnitResults -Path $FixturePath16
        $result.RunName | Should -Be "junit-node16"
    }

    It "counts tests, passed, failed, skipped correctly for node16 fixture" {
        $result = Get-JUnitResults -Path $FixturePath16
        $result.Tests   | Should -Be 5
        $result.Passed  | Should -Be 2
        $result.Failed  | Should -Be 2
        $result.Skipped | Should -Be 1
    }

    It "calculates total duration correctly for node16 fixture" {
        $result = Get-JUnitResults -Path $FixturePath16
        # 0.50 + 0.30 + 0.80 + 0.00 + 0.60 = 2.20
        $result.Duration | Should -Be 2.20
    }

    It "captures failure message from testcase failure element" {
        $result = Get-JUnitResults -Path $FixturePath16
        $testB = $result.TestCases | Where-Object { $_.Name -eq "TestB" }
        $testB.Message | Should -Be "Expected 1 but got 2"
    }

    It "marks skipped test with status skipped" {
        $result = Get-JUnitResults -Path $FixturePath16
        $testD = $result.TestCases | Where-Object { $_.Name -eq "TestD" }
        $testD.Status | Should -Be "skipped"
    }

    It "returns Format as junit" {
        $result = Get-JUnitResults -Path $FixturePath16
        $result.Format | Should -Be "junit"
    }

    It "throws a meaningful error for non-existent file" {
        { Get-JUnitResults -Path "/nonexistent/path/file.xml" } | Should -Throw -ExpectedMessage "*not found*"
    }
}

# ============================================================
# RED phase test: parse JSON result files
# ============================================================
Describe "Get-JsonResults" {
    BeforeAll {
        $FixtureLinux   = "$PSScriptRoot/fixtures/results-linux.json"
        $FixtureWindows = "$PSScriptRoot/fixtures/results-windows.json"
    }

    It "returns RunName derived from filename" {
        $result = Get-JsonResults -Path $FixtureLinux
        $result.RunName | Should -Be "results-linux"
    }

    It "counts tests, passed, failed, skipped correctly for linux fixture" {
        $result = Get-JsonResults -Path $FixtureLinux
        $result.Tests   | Should -Be 3
        $result.Passed  | Should -Be 2
        $result.Failed  | Should -Be 1
        $result.Skipped | Should -Be 0
    }

    It "calculates total duration correctly for linux fixture" {
        $result = Get-JsonResults -Path $FixtureLinux
        # 0.50 + 0.30 + 0.40 = 1.20
        $result.Duration | Should -Be 1.20
    }

    It "captures failure message from JSON test entry" {
        $result = Get-JsonResults -Path $FixtureLinux
        $api3 = $result.TestCases | Where-Object { $_.Name -eq "ApiTest3" }
        $api3.Message | Should -Be "HTTP 500: Internal Server Error"
    }

    It "returns Format as json" {
        $result = Get-JsonResults -Path $FixtureLinux
        $result.Format | Should -Be "json"
    }

    It "parses windows fixture with correct counts" {
        $result = Get-JsonResults -Path $FixtureWindows
        $result.Tests   | Should -Be 3
        $result.Passed  | Should -Be 1
        $result.Failed  | Should -Be 2
        $result.Skipped | Should -Be 0
    }

    It "throws a meaningful error for non-existent file" {
        { Get-JsonResults -Path "/nonexistent/path/file.json" } | Should -Throw -ExpectedMessage "*not found*"
    }
}

# ============================================================
# RED phase test: aggregate results across multiple runs
# ============================================================
Describe "Get-AggregatedResults" {
    BeforeAll {
        # Four runs matching the fixture data
        $Runs = @(
            @{ Tests = 5; Passed = 2; Failed = 2; Skipped = 1; Duration = 2.20 },
            @{ Tests = 5; Passed = 3; Failed = 1; Skipped = 1; Duration = 1.90 },
            @{ Tests = 3; Passed = 2; Failed = 1; Skipped = 0; Duration = 1.20 },
            @{ Tests = 3; Passed = 1; Failed = 2; Skipped = 0; Duration = 1.50 }
        )
    }

    It "sums TotalTests across all runs" {
        $result = Get-AggregatedResults -Runs $Runs
        $result.TotalTests | Should -Be 16
    }

    It "sums Passed across all runs" {
        $result = Get-AggregatedResults -Runs $Runs
        $result.Passed | Should -Be 8
    }

    It "sums Failed across all runs" {
        $result = Get-AggregatedResults -Runs $Runs
        $result.Failed | Should -Be 6
    }

    It "sums Skipped across all runs" {
        $result = Get-AggregatedResults -Runs $Runs
        $result.Skipped | Should -Be 2
    }

    It "sums Duration across all runs and rounds to 2 decimal places" {
        $result = Get-AggregatedResults -Runs $Runs
        # 2.20 + 1.90 + 1.20 + 1.50 = 6.80
        $result.Duration | Should -Be 6.80
    }
}

# ============================================================
# RED phase test: identify flaky tests
# ============================================================
Describe "Get-FlakyTests" {
    BeforeAll {
        # Minimal run data reproducing the fixture scenario
        $Runs = @(
            @{
                RunName   = "junit-node16"
                TestCases = @(
                    @{ Name = "TestA";    Status = "passed" },
                    @{ Name = "TestB";    Status = "failed" },
                    @{ Name = "TestC";    Status = "passed" },
                    @{ Name = "TestD";    Status = "skipped" },
                    @{ Name = "FlakyTest"; Status = "failed" }
                )
            },
            @{
                RunName   = "junit-node18"
                TestCases = @(
                    @{ Name = "TestA";    Status = "passed" },
                    @{ Name = "TestB";    Status = "failed" },  # consistently failing
                    @{ Name = "TestC";    Status = "passed" },
                    @{ Name = "TestD";    Status = "skipped" },
                    @{ Name = "FlakyTest"; Status = "passed" }  # flaky: passes here!
                )
            },
            @{
                RunName   = "results-linux"
                TestCases = @(
                    @{ Name = "ApiTest1"; Status = "passed" },
                    @{ Name = "ApiTest2"; Status = "passed" },  # flaky: passes here!
                    @{ Name = "ApiTest3"; Status = "failed" }
                )
            },
            @{
                RunName   = "results-windows"
                TestCases = @(
                    @{ Name = "ApiTest1"; Status = "passed" },
                    @{ Name = "ApiTest2"; Status = "failed" },  # flaky: fails here!
                    @{ Name = "ApiTest3"; Status = "failed" }   # consistently failing
                )
            }
        )
    }

    It "detects exactly 2 flaky tests across the 4 runs" {
        $flaky = Get-FlakyTests -Runs $Runs
        $flaky | Should -HaveCount 2
    }

    It "identifies FlakyTest as flaky (fail in node16, pass in node18)" {
        $flaky = Get-FlakyTests -Runs $Runs
        ($flaky | ForEach-Object { $_.Name }) | Should -Contain "FlakyTest"
    }

    It "identifies ApiTest2 as flaky (pass in linux, fail in windows)" {
        $flaky = Get-FlakyTests -Runs $Runs
        ($flaky | ForEach-Object { $_.Name }) | Should -Contain "ApiTest2"
    }

    It "does NOT flag TestB as flaky (it fails in every run)" {
        $flaky = Get-FlakyTests -Runs $Runs
        ($flaky | ForEach-Object { $_.Name }) | Should -Not -Contain "TestB"
    }

    It "does NOT flag TestA as flaky (it passes in every run)" {
        $flaky = Get-FlakyTests -Runs $Runs
        ($flaky | ForEach-Object { $_.Name }) | Should -Not -Contain "TestA"
    }

    It "records PassedIn and FailedIn run names for FlakyTest" {
        $flaky = Get-FlakyTests -Runs $Runs
        $ft = $flaky | Where-Object { $_.Name -eq "FlakyTest" }
        $ft.PassedIn | Should -Contain "junit-node18"
        $ft.FailedIn | Should -Contain "junit-node16"
    }

    It "returns empty array when there are no flaky tests" {
        $noFlakyRuns = @(
            @{ RunName = "r1"; TestCases = @(@{ Name = "T1"; Status = "passed" }) },
            @{ RunName = "r2"; TestCases = @(@{ Name = "T1"; Status = "passed" }) }
        )
        $flaky = Get-FlakyTests -Runs $noFlakyRuns
        $flaky.Count | Should -Be 0
    }
}

# ============================================================
# RED phase test: generate markdown summary
# ============================================================
Describe "New-MarkdownSummary" {
    BeforeAll {
        $Aggregate = @{
            TotalTests = 16
            Passed     = 8
            Failed     = 6
            Skipped    = 2
            Duration   = 6.80
        }
        $FlakyTests = @(
            @{ Name = "ApiTest2"; PassedIn = @("results-linux");  FailedIn = @("results-windows") },
            @{ Name = "FlakyTest"; PassedIn = @("junit-node18"); FailedIn = @("junit-node16") }
        )
        $Runs = @(
            @{
                RunName   = "junit-node16"; Tests = 5; Passed = 2; Failed = 2; Skipped = 1; Duration = 2.20
                TestCases = @(@{ Name = "TestB"; Status = "failed"; Message = "Expected 1 but got 2" })
            },
            @{
                RunName   = "junit-node18"; Tests = 5; Passed = 3; Failed = 1; Skipped = 1; Duration = 1.90
                TestCases = @(@{ Name = "TestB"; Status = "failed"; Message = "Expected 1 but got 2" })
            }
        )
        $Md = New-MarkdownSummary -Aggregate $Aggregate -FlakyTests $FlakyTests -Runs $Runs
    }

    It "starts with a level-1 heading" {
        $Md | Should -Match "^# Test Results Summary"
    }

    It "contains total tests count (16)" {
        $Md | Should -Match "Total Tests"
        $Md | Should -Match "\b16\b"
    }

    It "contains passed count (8)" {
        $Md | Should -Match "\|\s*Passed\s*\|"
        $Md | Should -Match "\|\s*8\s*\|"
    }

    It "contains duration formatted to 2 decimal places" {
        $Md | Should -Match "6\.80s"
    }

    It "contains flaky test names in the flaky section" {
        $Md | Should -Match "FlakyTest"
        $Md | Should -Match "ApiTest2"
    }

    It "has a Flaky Tests section header" {
        $Md | Should -Match "## Flaky Tests"
    }

    It "uses markdown table syntax (pipe-delimited rows)" {
        $Md | Should -Match "\|.*\|.*\|"
    }

    It "includes per-run breakdown table" {
        $Md | Should -Match "## Results by Run"
        $Md | Should -Match "junit-node16"
    }

    It "shows no flaky section text when there are no flaky tests" {
        $emptyFlaky = @()
        $md2 = New-MarkdownSummary -Aggregate $Aggregate -FlakyTests $emptyFlaky -Runs $Runs
        $md2 | Should -Match "No flaky tests detected"
    }
}

# ============================================================
# Workflow structure tests (also required by the benchmark)
# ============================================================
Describe "Workflow Structure" {
    BeforeAll {
        $WorkflowPath    = "$PSScriptRoot/.github/workflows/test-results-aggregator.yml"
        $WorkflowContent = Get-Content $WorkflowPath -Raw -ErrorAction Stop
    }

    It "workflow file exists at expected path" {
        Test-Path $WorkflowPath | Should -Be $true
    }

    It "has a push trigger" {
        $WorkflowContent | Should -Match "push"
    }

    It "has a pull_request trigger" {
        $WorkflowContent | Should -Match "pull_request"
    }

    It "uses actions/checkout@v4" {
        $WorkflowContent | Should -Match "actions/checkout@v4"
    }

    It "references the main script Invoke-TestResultsAggregator" {
        $WorkflowContent | Should -Match "Invoke-TestResultsAggregator"
    }

    It "main script file exists" {
        Test-Path "$PSScriptRoot/Invoke-TestResultsAggregator.ps1" | Should -Be $true
    }

    It "fixture files exist" {
        Test-Path "$PSScriptRoot/fixtures/junit-node16.xml"   | Should -Be $true
        Test-Path "$PSScriptRoot/fixtures/junit-node18.xml"   | Should -Be $true
        Test-Path "$PSScriptRoot/fixtures/results-linux.json" | Should -Be $true
        Test-Path "$PSScriptRoot/fixtures/results-windows.json" | Should -Be $true
    }

    It "uses shell: pwsh for PowerShell steps" {
        $WorkflowContent | Should -Match "shell:\s*pwsh"
    }

    It "passes actionlint validation" -Skip:(-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
        $lintOutput = & actionlint $WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint errors: $lintOutput"
    }
}
