# Test suite for Test Results Aggregator using Pester
# TDD: tests written before implementation

BeforeAll {
    . "$PSScriptRoot/../Invoke-TestResultsAggregator.ps1"
}

Describe "Parse-JUnitXml" {
    BeforeAll {
        $fixturePath = "$PSScriptRoot/../fixtures/junit-pass.xml"
    }

    It "returns a result object from a JUnit XML file" {
        $result = Parse-JUnitXml -Path $fixturePath
        $result | Should -Not -BeNullOrEmpty
    }

    It "extracts total passed count" {
        $result = Parse-JUnitXml -Path $fixturePath
        $result.Passed | Should -Be 3
    }

    It "extracts total failed count" {
        $result = Parse-JUnitXml -Path $fixturePath
        $result.Failed | Should -Be 0
    }

    It "extracts total skipped count" {
        $result = Parse-JUnitXml -Path $fixturePath
        $result.Skipped | Should -Be 1
    }

    It "extracts total duration in seconds" {
        $result = Parse-JUnitXml -Path $fixturePath
        $result.Duration | Should -Be 1.5
    }

    It "extracts individual test cases" {
        $result = Parse-JUnitXml -Path $fixturePath
        $result.Tests.Count | Should -Be 4
    }

    It "captures test name and status for each case" {
        $result = Parse-JUnitXml -Path $fixturePath
        $passed = $result.Tests | Where-Object { $_.Name -eq "TestAlpha" }
        $passed.Status | Should -Be "passed"
    }

    It "handles a file with failures" {
        $result = Parse-JUnitXml -Path "$PSScriptRoot/../fixtures/junit-fail.xml"
        $result.Failed | Should -Be 2
        $result.Passed | Should -Be 1
    }

    It "throws a meaningful error for missing file" {
        { Parse-JUnitXml -Path "nonexistent.xml" } | Should -Throw "*not found*"
    }
}

Describe "Parse-JsonResults" {
    BeforeAll {
        $fixturePath = "$PSScriptRoot/../fixtures/results.json"
    }

    It "returns a result object from a JSON results file" {
        $result = Parse-JsonResults -Path $fixturePath
        $result | Should -Not -BeNullOrEmpty
    }

    It "extracts passed count from JSON" {
        $result = Parse-JsonResults -Path $fixturePath
        $result.Passed | Should -Be 2
    }

    It "extracts failed count from JSON" {
        $result = Parse-JsonResults -Path $fixturePath
        $result.Failed | Should -Be 1
    }

    It "extracts skipped count from JSON" {
        $result = Parse-JsonResults -Path $fixturePath
        $result.Skipped | Should -Be 0
    }

    It "extracts duration from JSON" {
        $result = Parse-JsonResults -Path $fixturePath
        $result.Duration | Should -Be 2.3
    }

    It "extracts individual test cases from JSON" {
        $result = Parse-JsonResults -Path $fixturePath
        $result.Tests.Count | Should -Be 3
    }

    It "throws a meaningful error for missing file" {
        { Parse-JsonResults -Path "nonexistent.json" } | Should -Throw "*not found*"
    }
}

Describe "Merge-TestResults" {
    BeforeAll {
        $r1 = [PSCustomObject]@{
            Passed = 3; Failed = 1; Skipped = 0; Duration = 1.5
            Tests = @(
                [PSCustomObject]@{ Name = "Test1"; Status = "passed"; Suite = "SuiteA" }
                [PSCustomObject]@{ Name = "Test2"; Status = "failed"; Suite = "SuiteA" }
                [PSCustomObject]@{ Name = "Test3"; Status = "passed"; Suite = "SuiteB" }
                [PSCustomObject]@{ Name = "Test4"; Status = "passed"; Suite = "SuiteB" }
            )
        }
        $r2 = [PSCustomObject]@{
            Passed = 2; Failed = 2; Skipped = 1; Duration = 2.0
            Tests = @(
                [PSCustomObject]@{ Name = "Test1"; Status = "passed"; Suite = "SuiteA" }
                [PSCustomObject]@{ Name = "Test2"; Status = "passed"; Suite = "SuiteA" }
                [PSCustomObject]@{ Name = "Test3"; Status = "failed"; Suite = "SuiteB" }
                [PSCustomObject]@{ Name = "Test4"; Status = "failed"; Suite = "SuiteB" }
                [PSCustomObject]@{ Name = "Test5"; Status = "skipped"; Suite = "SuiteB" }
            )
        }
    }

    It "sums passed counts across runs" {
        $merged = Merge-TestResults -Results @($r1, $r2)
        $merged.TotalPassed | Should -Be 5
    }

    It "sums failed counts across runs" {
        $merged = Merge-TestResults -Results @($r1, $r2)
        $merged.TotalFailed | Should -Be 3
    }

    It "sums skipped counts across runs" {
        $merged = Merge-TestResults -Results @($r1, $r2)
        $merged.TotalSkipped | Should -Be 1
    }

    It "sums duration across runs" {
        $merged = Merge-TestResults -Results @($r1, $r2)
        $merged.TotalDuration | Should -Be 3.5
    }

    It "identifies flaky tests (passed in some runs, failed in others)" {
        $merged = Merge-TestResults -Results @($r1, $r2)
        $flakyNames = $merged.FlakyTests | Select-Object -ExpandProperty Name
        $flakyNames | Should -Contain "Test2"
        $flakyNames | Should -Contain "Test3"
        $flakyNames | Should -Contain "Test4"
    }

    It "does not flag consistently passing tests as flaky" {
        $merged = Merge-TestResults -Results @($r1, $r2)
        $flakyNames = $merged.FlakyTests | Select-Object -ExpandProperty Name
        $flakyNames | Should -Not -Contain "Test1"
    }

    It "does not flag consistently failing tests as flaky" {
        # Test5 only appears in r2 as skipped - not flaky
        $merged = Merge-TestResults -Results @($r1, $r2)
        $flakyNames = $merged.FlakyTests | Select-Object -ExpandProperty Name
        $flakyNames | Should -Not -Contain "Test5"
    }
}

Describe "New-MarkdownSummary" {
    BeforeAll {
        $merged = [PSCustomObject]@{
            TotalPassed   = 5
            TotalFailed   = 2
            TotalSkipped  = 1
            TotalDuration = 3.5
            RunCount      = 2
            FlakyTests    = @(
                [PSCustomObject]@{ Name = "FlakyTest1"; PassCount = 1; FailCount = 1 }
            )
        }
    }

    It "returns a non-empty markdown string" {
        $md = New-MarkdownSummary -Merged $merged
        $md | Should -Not -BeNullOrEmpty
    }

    It "includes a heading" {
        $md = New-MarkdownSummary -Merged $merged
        $md | Should -Match "## Test Results"
    }

    It "includes passed count" {
        $md = New-MarkdownSummary -Merged $merged
        $md | Should -Match "5"
    }

    It "includes failed count" {
        $md = New-MarkdownSummary -Merged $merged
        $md | Should -Match "2"
    }

    It "includes skipped count" {
        $md = New-MarkdownSummary -Merged $merged
        $md | Should -Match "1"
    }

    It "includes duration" {
        $md = New-MarkdownSummary -Merged $merged
        $md | Should -Match "3.5"
    }

    It "includes flaky test section when flaky tests exist" {
        $md = New-MarkdownSummary -Merged $merged
        $md | Should -Match "Flaky"
        $md | Should -Match "FlakyTest1"
    }

    It "shows no flaky tests section when none exist" {
        $noFlaky = [PSCustomObject]@{
            TotalPassed = 3; TotalFailed = 0; TotalSkipped = 0
            TotalDuration = 1.0; RunCount = 2; FlakyTests = @()
        }
        $md = New-MarkdownSummary -Merged $noFlaky
        $md | Should -Not -Match "Flaky"
    }
}

Describe "Invoke-Aggregation (integration)" {
    It "processes a directory of mixed fixture files end-to-end" {
        $result = Invoke-Aggregation -Path "$PSScriptRoot/../fixtures"
        $result | Should -Not -BeNullOrEmpty
        $result.TotalPassed | Should -BeGreaterThan 0
    }

    It "returns markdown summary from Invoke-Aggregation" {
        $md = Invoke-Aggregation -Path "$PSScriptRoot/../fixtures" -OutputMarkdown
        $md | Should -Match "## Test Results"
    }
}
