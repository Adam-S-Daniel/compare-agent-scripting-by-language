# TestResultsAggregator.Tests.ps1
# TDD test suite for the Test Results Aggregator
#
# RED/GREEN TDD cycles:
# Cycle 1: Parse-JUnitXml - parse JUnit XML files into test result objects
# Cycle 2: Parse-JsonResults - parse JSON result files into test result objects
# Cycle 3: Aggregate-TestResults - combine results from multiple runs
# Cycle 4: Find-FlakyTests - identify tests that passed in some runs but failed in others
# Cycle 5: New-MarkdownSummary - generate a GitHub Actions markdown summary

BeforeAll {
    # Load the implementation. This will FAIL on the first run (RED phase)
    # because TestResultsAggregator.ps1 does not exist yet.
    . "$PSScriptRoot/TestResultsAggregator.ps1"
}

# =============================================================================
# CYCLE 1: Parse-JUnitXml
# =============================================================================
Describe "Parse-JUnitXml" {

    It "returns an array of test result objects from a valid JUnit XML file" {
        $results = Parse-JUnitXml -Path "$PSScriptRoot/fixtures/junit-matrix-1.xml"
        $results | Should -Not -BeNullOrEmpty
        $results.Count | Should -BeGreaterThan 0
    }

    It "returns objects with Name, Suite, Status, Duration, RunId properties" {
        $results = Parse-JUnitXml -Path "$PSScriptRoot/fixtures/junit-matrix-1.xml" -RunId "matrix-1"
        $first = $results[0]
        $first.PSObject.Properties.Name | Should -Contain "Name"
        $first.PSObject.Properties.Name | Should -Contain "Suite"
        $first.PSObject.Properties.Name | Should -Contain "Status"
        $first.PSObject.Properties.Name | Should -Contain "Duration"
        $first.PSObject.Properties.Name | Should -Contain "RunId"
    }

    It "correctly identifies passed tests (no failure/error/skipped child)" {
        $results = Parse-JUnitXml -Path "$PSScriptRoot/fixtures/junit-matrix-1.xml" -RunId "matrix-1"
        $passed = $results | Where-Object { $_.Name -eq "UnitTests::TestA" }
        $passed.Status | Should -Be "passed"
    }

    It "correctly identifies failed tests" {
        $results = Parse-JUnitXml -Path "$PSScriptRoot/fixtures/junit-matrix-1.xml" -RunId "matrix-1"
        $failed = $results | Where-Object { $_.Name -eq "UnitTests::TestB" }
        $failed.Status | Should -Be "failed"
    }

    It "correctly identifies skipped tests" {
        $results = Parse-JUnitXml -Path "$PSScriptRoot/fixtures/junit-matrix-1.xml" -RunId "matrix-1"
        $skipped = $results | Where-Object { $_.Name -eq "UnitTests::TestC" }
        $skipped.Status | Should -Be "skipped"
    }

    It "captures the duration as a number" {
        $results = Parse-JUnitXml -Path "$PSScriptRoot/fixtures/junit-matrix-1.xml" -RunId "matrix-1"
        $testD = $results | Where-Object { $_.Name -eq "UnitTests::TestD" }
        $testD.Duration | Should -BeOfType [double]
        $testD.Duration | Should -BeGreaterThan 0
    }

    It "tags each result with the RunId" {
        $results = Parse-JUnitXml -Path "$PSScriptRoot/fixtures/junit-matrix-1.xml" -RunId "run-xyz"
        $results | ForEach-Object { $_.RunId | Should -Be "run-xyz" }
    }

    It "throws a meaningful error for a missing file" {
        { Parse-JUnitXml -Path "nonexistent.xml" } | Should -Throw "*not found*"
    }

    It "handles multiple testsuites in a single file" {
        $results = Parse-JUnitXml -Path "$PSScriptRoot/fixtures/junit-matrix-2.xml" -RunId "matrix-2"
        # junit-matrix-2.xml has two testsuites
        $suites = $results | Select-Object -ExpandProperty Suite -Unique
        $suites.Count | Should -BeGreaterOrEqual 2
    }
}

# =============================================================================
# CYCLE 2: Parse-JsonResults
# =============================================================================
Describe "Parse-JsonResults" {

    It "returns an array of test result objects from a valid JSON results file" {
        $results = Parse-JsonResults -Path "$PSScriptRoot/fixtures/json-matrix-1.json" -RunId "json-1"
        $results | Should -Not -BeNullOrEmpty
        $results.Count | Should -BeGreaterThan 0
    }

    It "returns objects with Name, Suite, Status, Duration, RunId properties" {
        $results = Parse-JsonResults -Path "$PSScriptRoot/fixtures/json-matrix-1.json" -RunId "json-1"
        $first = $results[0]
        $first.PSObject.Properties.Name | Should -Contain "Name"
        $first.PSObject.Properties.Name | Should -Contain "Suite"
        $first.PSObject.Properties.Name | Should -Contain "Status"
        $first.PSObject.Properties.Name | Should -Contain "Duration"
        $first.PSObject.Properties.Name | Should -Contain "RunId"
    }

    It "correctly maps passed/failed/skipped status from JSON" {
        $results = Parse-JsonResults -Path "$PSScriptRoot/fixtures/json-matrix-1.json" -RunId "json-1"
        $passed = $results | Where-Object { $_.Name -eq "IntegrationTests::TestE" }
        $failed = $results | Where-Object { $_.Name -eq "IntegrationTests::TestF" }
        $passed.Status | Should -Be "passed"
        $failed.Status | Should -Be "failed"
    }

    It "tags each result with the RunId" {
        $results = Parse-JsonResults -Path "$PSScriptRoot/fixtures/json-matrix-1.json" -RunId "my-run"
        $results | ForEach-Object { $_.RunId | Should -Be "my-run" }
    }

    It "throws a meaningful error for a missing file" {
        { Parse-JsonResults -Path "nonexistent.json" } | Should -Throw "*not found*"
    }

    It "throws a meaningful error for invalid JSON" {
        $badFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $badFile -Value "{ not valid json"
        try {
            { Parse-JsonResults -Path $badFile -RunId "bad" } | Should -Throw "*Invalid JSON*"
        } finally {
            Remove-Item -Path $badFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# =============================================================================
# CYCLE 3: Aggregate-TestResults
# =============================================================================
Describe "Aggregate-TestResults" {

    BeforeAll {
        # Build test data representing two matrix runs
        $script:Run1Results = @(
            [PSCustomObject]@{ Name = "Suite1::TestA"; Suite = "Suite1"; Status = "passed";  Duration = 1.0; RunId = "run1" }
            [PSCustomObject]@{ Name = "Suite1::TestB"; Suite = "Suite1"; Status = "failed";  Duration = 0.5; RunId = "run1" }
            [PSCustomObject]@{ Name = "Suite1::TestC"; Suite = "Suite1"; Status = "skipped"; Duration = 0.0; RunId = "run1" }
        )
        $script:Run2Results = @(
            [PSCustomObject]@{ Name = "Suite1::TestA"; Suite = "Suite1"; Status = "failed";  Duration = 1.1; RunId = "run2" }
            [PSCustomObject]@{ Name = "Suite1::TestB"; Suite = "Suite1"; Status = "passed";  Duration = 0.4; RunId = "run2" }
            [PSCustomObject]@{ Name = "Suite1::TestC"; Suite = "Suite1"; Status = "skipped"; Duration = 0.0; RunId = "run2" }
        )
        $script:AllResults = $script:Run1Results + $script:Run2Results
    }

    It "returns an object with TotalPassed, TotalFailed, TotalSkipped, TotalDuration" {
        $agg = Aggregate-TestResults -Results $script:AllResults
        $agg.PSObject.Properties.Name | Should -Contain "TotalPassed"
        $agg.PSObject.Properties.Name | Should -Contain "TotalFailed"
        $agg.PSObject.Properties.Name | Should -Contain "TotalSkipped"
        $agg.PSObject.Properties.Name | Should -Contain "TotalDuration"
    }

    It "correctly counts passed tests across runs" {
        $agg = Aggregate-TestResults -Results $script:AllResults
        # run1: TestA passed; run2: TestB passed => 2 passed total
        $agg.TotalPassed | Should -Be 2
    }

    It "correctly counts failed tests across runs" {
        $agg = Aggregate-TestResults -Results $script:AllResults
        # run1: TestB failed; run2: TestA failed => 2 failed total
        $agg.TotalFailed | Should -Be 2
    }

    It "correctly counts skipped tests across runs" {
        $agg = Aggregate-TestResults -Results $script:AllResults
        # run1: TestC skipped; run2: TestC skipped => 2 skipped
        $agg.TotalSkipped | Should -Be 2
    }

    It "correctly sums total duration across all runs" {
        $agg = Aggregate-TestResults -Results $script:AllResults
        # 1.0 + 0.5 + 0.0 + 1.1 + 0.4 + 0.0 = 3.0
        $agg.TotalDuration | Should -Be 3.0
    }

    It "includes all individual test results in the output" {
        $agg = Aggregate-TestResults -Results $script:AllResults
        $agg.PSObject.Properties.Name | Should -Contain "TestRuns"
        $agg.TestRuns.Count | Should -Be 6
    }

    It "handles an empty result set without error" {
        $agg = Aggregate-TestResults -Results @()
        $agg.TotalPassed  | Should -Be 0
        $agg.TotalFailed  | Should -Be 0
        $agg.TotalSkipped | Should -Be 0
        $agg.TotalDuration | Should -Be 0
    }
}

# =============================================================================
# CYCLE 4: Find-FlakyTests
# =============================================================================
Describe "Find-FlakyTests" {

    BeforeAll {
        $script:MixedResults = @(
            # TestA: passed in run1, failed in run2 => FLAKY
            [PSCustomObject]@{ Name = "Suite::TestA"; Suite = "Suite"; Status = "passed"; Duration = 1.0; RunId = "run1" }
            [PSCustomObject]@{ Name = "Suite::TestA"; Suite = "Suite"; Status = "failed"; Duration = 1.1; RunId = "run2" }
            # TestB: failed in both => NOT flaky (consistently failing)
            [PSCustomObject]@{ Name = "Suite::TestB"; Suite = "Suite"; Status = "failed"; Duration = 0.5; RunId = "run1" }
            [PSCustomObject]@{ Name = "Suite::TestB"; Suite = "Suite"; Status = "failed"; Duration = 0.4; RunId = "run2" }
            # TestC: passed in both => NOT flaky
            [PSCustomObject]@{ Name = "Suite::TestC"; Suite = "Suite"; Status = "passed"; Duration = 0.2; RunId = "run1" }
            [PSCustomObject]@{ Name = "Suite::TestC"; Suite = "Suite"; Status = "passed"; Duration = 0.3; RunId = "run2" }
            # TestD: passed in run1, skipped in run2 => NOT flaky (no failed run)
            [PSCustomObject]@{ Name = "Suite::TestD"; Suite = "Suite"; Status = "passed";  Duration = 0.1; RunId = "run1" }
            [PSCustomObject]@{ Name = "Suite::TestD"; Suite = "Suite"; Status = "skipped"; Duration = 0.0; RunId = "run2" }
        )
    }

    It "returns only tests that both passed and failed across runs" {
        $flaky = Find-FlakyTests -Results $script:MixedResults
        $flaky.Count | Should -Be 1
        $flaky[0].Name | Should -Be "Suite::TestA"
    }

    It "returns objects with Name, PassedRuns, FailedRuns properties" {
        $flaky = Find-FlakyTests -Results $script:MixedResults
        $flaky[0].PSObject.Properties.Name | Should -Contain "Name"
        $flaky[0].PSObject.Properties.Name | Should -Contain "PassedRuns"
        $flaky[0].PSObject.Properties.Name | Should -Contain "FailedRuns"
    }

    It "lists which RunIds the test passed in and which it failed in" {
        $flaky = Find-FlakyTests -Results $script:MixedResults
        $testA = $flaky[0]
        $testA.PassedRuns | Should -Contain "run1"
        $testA.FailedRuns | Should -Contain "run2"
    }

    It "returns an empty array when there are no flaky tests" {
        $stable = @(
            [PSCustomObject]@{ Name = "Suite::TestX"; Suite = "Suite"; Status = "passed"; Duration = 1.0; RunId = "run1" }
            [PSCustomObject]@{ Name = "Suite::TestX"; Suite = "Suite"; Status = "passed"; Duration = 1.0; RunId = "run2" }
        )
        $flaky = Find-FlakyTests -Results $stable
        $flaky | Should -BeNullOrEmpty
    }

    It "handles an empty result set without error" {
        $flaky = Find-FlakyTests -Results @()
        $flaky | Should -BeNullOrEmpty
    }

    It "detects flaky tests when one run has it passing and another failing (multiple suites)" {
        $multiSuite = @(
            [PSCustomObject]@{ Name = "SuiteA::Test1"; Suite = "SuiteA"; Status = "passed"; Duration = 0.1; RunId = "run1" }
            [PSCustomObject]@{ Name = "SuiteA::Test1"; Suite = "SuiteA"; Status = "failed"; Duration = 0.2; RunId = "run2" }
            [PSCustomObject]@{ Name = "SuiteB::Test2"; Suite = "SuiteB"; Status = "passed"; Duration = 0.3; RunId = "run1" }
            [PSCustomObject]@{ Name = "SuiteB::Test2"; Suite = "SuiteB"; Status = "passed"; Duration = 0.4; RunId = "run2" }
        )
        $flaky = Find-FlakyTests -Results $multiSuite
        $flaky.Count | Should -Be 1
        $flaky[0].Name | Should -Be "SuiteA::Test1"
    }
}

# =============================================================================
# CYCLE 5: New-MarkdownSummary
# =============================================================================
Describe "New-MarkdownSummary" {

    BeforeAll {
        $script:SampleAgg = [PSCustomObject]@{
            TotalPassed  = 8
            TotalFailed  = 2
            TotalSkipped = 1
            TotalDuration = 12.345
            TestRuns = @(
                [PSCustomObject]@{ Name = "Suite::TestA"; Suite = "Suite"; Status = "passed";  Duration = 1.0; RunId = "run1" }
                [PSCustomObject]@{ Name = "Suite::TestA"; Suite = "Suite"; Status = "failed";  Duration = 1.1; RunId = "run2" }
                [PSCustomObject]@{ Name = "Suite::TestB"; Suite = "Suite"; Status = "failed";  Duration = 0.5; RunId = "run1" }
                [PSCustomObject]@{ Name = "Suite::TestB"; Suite = "Suite"; Status = "passed";  Duration = 0.4; RunId = "run2" }
            )
        }
        $script:SampleFlaky = @(
            [PSCustomObject]@{
                Name       = "Suite::TestA"
                PassedRuns = @("run1")
                FailedRuns = @("run2")
            }
        )
    }

    It "returns a non-empty string" {
        $md = New-MarkdownSummary -Aggregation $script:SampleAgg -FlakyTests $script:SampleFlaky
        $md | Should -Not -BeNullOrEmpty
        $md | Should -BeOfType [string]
    }

    It "includes a heading" {
        $md = New-MarkdownSummary -Aggregation $script:SampleAgg -FlakyTests $script:SampleFlaky
        $md | Should -Match "^#"
    }

    It "includes total passed count" {
        $md = New-MarkdownSummary -Aggregation $script:SampleAgg -FlakyTests $script:SampleFlaky
        $md | Should -Match "8"
    }

    It "includes total failed count" {
        $md = New-MarkdownSummary -Aggregation $script:SampleAgg -FlakyTests $script:SampleFlaky
        $md | Should -Match "2"
    }

    It "includes total skipped count" {
        $md = New-MarkdownSummary -Aggregation $script:SampleAgg -FlakyTests $script:SampleFlaky
        $md | Should -Match "1"
    }

    It "includes duration" {
        $md = New-MarkdownSummary -Aggregation $script:SampleAgg -FlakyTests $script:SampleFlaky
        $md | Should -Match "12.34"
    }

    It "includes a flaky tests section when there are flaky tests" {
        $md = New-MarkdownSummary -Aggregation $script:SampleAgg -FlakyTests $script:SampleFlaky
        $md | Should -Match "(?i)flaky"
    }

    It "names each flaky test in the summary" {
        $md = New-MarkdownSummary -Aggregation $script:SampleAgg -FlakyTests $script:SampleFlaky
        $md | Should -Match "Suite::TestA"
    }

    It "says 'no flaky tests' when there are none" {
        $md = New-MarkdownSummary -Aggregation $script:SampleAgg -FlakyTests @()
        $md | Should -Match "(?i)no flaky"
    }

    It "produces valid markdown table syntax (pipe characters)" {
        $md = New-MarkdownSummary -Aggregation $script:SampleAgg -FlakyTests $script:SampleFlaky
        $md | Should -Match "\|"
    }
}

# =============================================================================
# CYCLE 6: End-to-end integration test using fixture files
# =============================================================================
Describe "End-to-end: Invoke-TestResultsAggregator" {

    It "processes all fixture files and produces a markdown summary" {
        $files = @(
            @{ Path = "$PSScriptRoot/fixtures/junit-matrix-1.xml"; RunId = "junit-1"; Format = "junit" }
            @{ Path = "$PSScriptRoot/fixtures/junit-matrix-2.xml"; RunId = "junit-2"; Format = "junit" }
            @{ Path = "$PSScriptRoot/fixtures/json-matrix-1.json"; RunId = "json-1";  Format = "json"  }
            @{ Path = "$PSScriptRoot/fixtures/json-matrix-2.json"; RunId = "json-2";  Format = "json"  }
        )
        $result = Invoke-TestResultsAggregator -InputFiles $files
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeOfType [string]
        $result | Should -Match "(?i)passed"
        $result | Should -Match "(?i)failed"
    }

    It "detects flaky tests across fixture files" {
        $files = @(
            @{ Path = "$PSScriptRoot/fixtures/junit-matrix-1.xml"; RunId = "junit-1"; Format = "junit" }
            @{ Path = "$PSScriptRoot/fixtures/junit-matrix-2.xml"; RunId = "junit-2"; Format = "junit" }
        )
        $result = Invoke-TestResultsAggregator -InputFiles $files
        # junit-matrix-2.xml flips some results, so we should see flaky tests mentioned
        $result | Should -Match "(?i)flaky"
    }
}
