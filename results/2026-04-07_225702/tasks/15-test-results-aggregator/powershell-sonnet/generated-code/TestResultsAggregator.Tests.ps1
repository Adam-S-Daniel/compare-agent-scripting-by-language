# TestResultsAggregator.Tests.ps1
# TDD tests for the Test Results Aggregator
# Uses Pester testing framework

# In Pester 5 the recommended way to make functions available in all blocks is
# to dot-source inside a top-level BeforeAll.  Script-level dot-sources run
# during the *discovery* phase and may not be visible during execution.
BeforeAll {
    . (Join-Path $PSScriptRoot "TestResultsAggregator.ps1")
}

Describe "Parse-JUnitXml" {
    BeforeAll {
        # Create a minimal JUnit XML fixture in memory
        $script:SampleJUnitXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="matrix-run-ubuntu" tests="4" failures="1" errors="0" skipped="1" time="3.25">
  <testsuite name="UnitTests" tests="4" failures="1" errors="0" skipped="1" time="3.25">
    <testcase name="Test_Addition" classname="MathTests" time="0.5"/>
    <testcase name="Test_Subtraction" classname="MathTests" time="0.3">
      <failure message="Expected 2 but got 3">AssertionError</failure>
    </testcase>
    <testcase name="Test_Multiplication" classname="MathTests" time="0.0">
      <skipped/>
    </testcase>
    <testcase name="Test_Division" classname="MathTests" time="1.2"/>
  </testsuite>
</testsuites>
"@
        $script:TempXmlFile = Join-Path $TestDrive "sample.xml"
        $script:SampleJUnitXml | Set-Content -Path $script:TempXmlFile -Encoding UTF8
    }

    It "parses test counts from a JUnit XML file" {
        $result = Parse-JUnitXml -Path $script:TempXmlFile

        $result.Total    | Should -Be 4
        $result.Passed   | Should -Be 2
        $result.Failed   | Should -Be 1
        $result.Skipped  | Should -Be 1
    }

    It "parses duration from a JUnit XML file" {
        $result = Parse-JUnitXml -Path $script:TempXmlFile

        $result.Duration | Should -Be 3.25
    }

    It "returns individual test cases" {
        $result = Parse-JUnitXml -Path $script:TempXmlFile

        $result.TestCases.Count | Should -Be 4
    }

    It "marks failed test cases correctly" {
        $result = Parse-JUnitXml -Path $script:TempXmlFile
        $failedCase = $result.TestCases | Where-Object { $_.Name -eq "Test_Subtraction" }

        $failedCase.Status | Should -Be "Failed"
        $failedCase.Message | Should -Match "Expected 2"
    }

    It "marks skipped test cases correctly" {
        $result = Parse-JUnitXml -Path $script:TempXmlFile
        $skippedCase = $result.TestCases | Where-Object { $_.Name -eq "Test_Multiplication" }

        $skippedCase.Status | Should -Be "Skipped"
    }

    It "marks passed test cases correctly" {
        $result = Parse-JUnitXml -Path $script:TempXmlFile
        $passedCase = $result.TestCases | Where-Object { $_.Name -eq "Test_Addition" }

        $passedCase.Status | Should -Be "Passed"
    }

    It "throws a meaningful error for missing files" {
        { Parse-JUnitXml -Path "nonexistent.xml" } | Should -Throw "*not found*"
    }
}

Describe "Parse-JsonResults" {
    BeforeAll {
        $script:SampleJson = @"
{
  "run": "windows-latest",
  "tests": [
    { "name": "Test_Login",    "suite": "AuthTests", "status": "passed",  "duration": 0.8 },
    { "name": "Test_Logout",   "suite": "AuthTests", "status": "failed",  "duration": 0.2, "message": "Timeout" },
    { "name": "Test_Register", "suite": "AuthTests", "status": "skipped", "duration": 0.0 }
  ],
  "summary": { "total": 3, "passed": 1, "failed": 1, "skipped": 1, "duration": 1.0 }
}
"@
        $script:TempJsonFile = Join-Path $TestDrive "sample.json"
        $script:SampleJson | Set-Content -Path $script:TempJsonFile -Encoding UTF8
    }

    It "parses test counts from a JSON file" {
        $result = Parse-JsonResults -Path $script:TempJsonFile

        $result.Total   | Should -Be 3
        $result.Passed  | Should -Be 1
        $result.Failed  | Should -Be 1
        $result.Skipped | Should -Be 1
    }

    It "parses duration from a JSON file" {
        $result = Parse-JsonResults -Path $script:TempJsonFile

        $result.Duration | Should -Be 1.0
    }

    It "returns individual test cases" {
        $result = Parse-JsonResults -Path $script:TempJsonFile

        $result.TestCases.Count | Should -Be 3
    }

    It "captures failure message from JSON" {
        $result = Parse-JsonResults -Path $script:TempJsonFile
        $failedCase = $result.TestCases | Where-Object { $_.Name -eq "Test_Logout" }

        $failedCase.Status  | Should -Be "Failed"
        $failedCase.Message | Should -Be "Timeout"
    }

    It "throws a meaningful error for missing files" {
        { Parse-JsonResults -Path "nonexistent.json" } | Should -Throw "*not found*"
    }
}

Describe "Aggregate-Results" {
    BeforeAll {
        # Build two synthetic run-result objects (as returned by the parsers)
        $script:Run1 = [PSCustomObject]@{
            Source   = "run1.xml"
            Total    = 3
            Passed   = 2
            Failed   = 1
            Skipped  = 0
            Duration = 2.0
            TestCases = @(
                [PSCustomObject]@{ Name = "Test_A"; Suite = "Suite1"; Status = "Passed";  Duration = 0.5; Message = "" }
                [PSCustomObject]@{ Name = "Test_B"; Suite = "Suite1"; Status = "Failed";  Duration = 0.3; Message = "Oops" }
                [PSCustomObject]@{ Name = "Test_C"; Suite = "Suite1"; Status = "Passed";  Duration = 1.2; Message = "" }
            )
        }

        $script:Run2 = [PSCustomObject]@{
            Source   = "run2.json"
            Total    = 3
            Passed   = 3
            Failed   = 0
            Skipped  = 0
            Duration = 1.5
            TestCases = @(
                [PSCustomObject]@{ Name = "Test_A"; Suite = "Suite1"; Status = "Passed"; Duration = 0.4; Message = "" }
                [PSCustomObject]@{ Name = "Test_B"; Suite = "Suite1"; Status = "Passed"; Duration = 0.2; Message = "" }
                [PSCustomObject]@{ Name = "Test_C"; Suite = "Suite1"; Status = "Passed"; Duration = 0.9; Message = "" }
            )
        }
    }

    It "sums totals across all runs" {
        $agg = Aggregate-Results -RunResults @($script:Run1, $script:Run2)

        $agg.TotalTests   | Should -Be 6
        $agg.TotalPassed  | Should -Be 5
        $agg.TotalFailed  | Should -Be 1
        $agg.TotalSkipped | Should -Be 0
    }

    It "sums duration across all runs" {
        $agg = Aggregate-Results -RunResults @($script:Run1, $script:Run2)

        $agg.TotalDuration | Should -Be 3.5
    }

    It "reports the number of runs" {
        $agg = Aggregate-Results -RunResults @($script:Run1, $script:Run2)

        $agg.RunCount | Should -Be 2
    }
}

Describe "Find-FlakyTests" {
    BeforeAll {
        # Test_B fails in run1 but passes in run2 → flaky
        # Test_A passes in both → stable
        # Test_C passes in both → stable
        $script:Run1 = [PSCustomObject]@{
            Source    = "run1.xml"
            TestCases = @(
                [PSCustomObject]@{ Name = "Test_A"; Suite = "Suite1"; Status = "Passed" }
                [PSCustomObject]@{ Name = "Test_B"; Suite = "Suite1"; Status = "Failed" }
                [PSCustomObject]@{ Name = "Test_C"; Suite = "Suite1"; Status = "Passed" }
            )
        }
        $script:Run2 = [PSCustomObject]@{
            Source    = "run2.json"
            TestCases = @(
                [PSCustomObject]@{ Name = "Test_A"; Suite = "Suite1"; Status = "Passed" }
                [PSCustomObject]@{ Name = "Test_B"; Suite = "Suite1"; Status = "Passed" }
                [PSCustomObject]@{ Name = "Test_C"; Suite = "Suite1"; Status = "Passed" }
            )
        }
    }

    It "identifies flaky tests that pass in some runs and fail in others" {
        $flaky = Find-FlakyTests -RunResults @($script:Run1, $script:Run2)

        $flaky.Count          | Should -Be 1
        $flaky[0].Name        | Should -Be "Test_B"
    }

    It "reports pass and fail counts for flaky tests" {
        $flaky = Find-FlakyTests -RunResults @($script:Run1, $script:Run2)

        $flaky[0].PassCount | Should -Be 1
        $flaky[0].FailCount | Should -Be 1
    }

    It "returns empty when no flaky tests exist" {
        # Two identical all-pass runs
        $clean1 = [PSCustomObject]@{
            Source    = "clean1.xml"
            TestCases = @(
                [PSCustomObject]@{ Name = "Test_A"; Suite = "S"; Status = "Passed" }
            )
        }
        $clean2 = [PSCustomObject]@{
            Source    = "clean2.xml"
            TestCases = @(
                [PSCustomObject]@{ Name = "Test_A"; Suite = "S"; Status = "Passed" }
            )
        }

        $flaky = Find-FlakyTests -RunResults @($clean1, $clean2)

        $flaky | Should -BeNullOrEmpty
    }
}

Describe "New-MarkdownSummary" {
    BeforeAll {
        $script:Aggregated = [PSCustomObject]@{
            TotalTests    = 10
            TotalPassed   = 8
            TotalFailed   = 1
            TotalSkipped  = 1
            TotalDuration = 5.5
            RunCount      = 2
        }

        $script:FlakyTests = @(
            [PSCustomObject]@{ Name = "Test_Flaky"; Suite = "Suite1"; PassCount = 1; FailCount = 1 }
        )
    }

    It "generates a markdown string" {
        $md = New-MarkdownSummary -Aggregated $script:Aggregated -FlakyTests $script:FlakyTests

        $md | Should -BeOfType [string]
        $md.Length | Should -BeGreaterThan 0
    }

    It "includes a totals table" {
        $md = New-MarkdownSummary -Aggregated $script:Aggregated -FlakyTests $script:FlakyTests

        $md | Should -Match "Passed"
        $md | Should -Match "Failed"
        $md | Should -Match "Skipped"
    }

    It "includes numeric totals" {
        $md = New-MarkdownSummary -Aggregated $script:Aggregated -FlakyTests $script:FlakyTests

        $md | Should -Match "10"  # total tests
        $md | Should -Match "8"   # passed
    }

    It "includes a flaky tests section when flaky tests exist" {
        $md = New-MarkdownSummary -Aggregated $script:Aggregated -FlakyTests $script:FlakyTests

        $md | Should -Match "Flaky"
        $md | Should -Match "Test_Flaky"
    }

    It "shows 'No flaky tests' when none found" {
        $md = New-MarkdownSummary -Aggregated $script:Aggregated -FlakyTests @()

        $md | Should -Match "No flaky tests"
    }
}

Describe "Invoke-Aggregator (integration)" {
    BeforeAll {
        # Create real fixture files that the integration function reads from disk
        $script:FixturesDir = Join-Path $TestDrive "fixtures"
        New-Item -ItemType Directory -Path $script:FixturesDir | Out-Null

        # JUnit XML fixture — run on ubuntu
        @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="ubuntu" tests="3" failures="1" errors="0" skipped="0" time="2.0">
  <testsuite name="Suite" tests="3" failures="1" errors="0" skipped="0" time="2.0">
    <testcase name="Test_Alpha" classname="Suite" time="0.5"/>
    <testcase name="Test_Beta"  classname="Suite" time="1.0">
      <failure message="NullRef">NullReferenceException</failure>
    </testcase>
    <testcase name="Test_Gamma" classname="Suite" time="0.5"/>
  </testsuite>
</testsuites>
"@ | Set-Content -Path (Join-Path $script:FixturesDir "ubuntu.xml") -Encoding UTF8

        # JSON fixture — run on windows, Beta passes (flaky!)
        @"
{
  "run": "windows",
  "tests": [
    { "name": "Test_Alpha", "suite": "Suite", "status": "passed",  "duration": 0.6, "message": "" },
    { "name": "Test_Beta",  "suite": "Suite", "status": "passed",  "duration": 1.1, "message": "" },
    { "name": "Test_Gamma", "suite": "Suite", "status": "passed",  "duration": 0.4, "message": "" }
  ],
  "summary": { "total": 3, "passed": 3, "failed": 0, "skipped": 0, "duration": 2.1 }
}
"@ | Set-Content -Path (Join-Path $script:FixturesDir "windows.json") -Encoding UTF8
    }

    It "produces a markdown summary from real fixture files" {
        $md = Invoke-Aggregator -Paths @(
            (Join-Path $script:FixturesDir "ubuntu.xml"),
            (Join-Path $script:FixturesDir "windows.json")
        )

        $md | Should -Match "Test Results"
        $md | Should -Match "6"       # total tests (3 + 3)
        $md | Should -Match "Test_Beta"  # flaky test appears
    }
}
