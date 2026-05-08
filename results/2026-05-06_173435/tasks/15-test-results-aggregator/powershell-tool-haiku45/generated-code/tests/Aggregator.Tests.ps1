BeforeAll {
    . "$PSScriptRoot/../src/Aggregator.ps1"
}

Describe "ParseJunitXml" {
    It "should parse passing JUnit XML file" {
        $result = ParseJunitXml "$PSScriptRoot/fixtures/junit/passing.xml"

        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 3
        $result[0].Name | Should -Be "AddPositiveNumbers"
        $result[0].Status | Should -Be "passed"
        $result[0].Duration | Should -Be 0.150
    }

    It "should parse failing JUnit XML file" {
        $result = ParseJunitXml "$PSScriptRoot/fixtures/junit/failing.xml"

        $result.Count | Should -Be 4
        ($result | Where-Object { $_.Status -eq "passed" }).Count | Should -Be 1
        ($result | Where-Object { $_.Status -eq "failed" }).Count | Should -Be 2
        ($result | Where-Object { $_.Status -eq "skipped" }).Count | Should -Be 1
    }

    It "should include test class name" {
        $result = ParseJunitXml "$PSScriptRoot/fixtures/junit/failing.xml"
        $result[0].Class | Should -Be "ValidationTests"
    }

    It "should calculate total time from testsuite" {
        $result = ParseJunitXml "$PSScriptRoot/fixtures/junit/failing.xml"
        [double]::Parse(($result | Measure-Object -Property Duration -Sum).Sum.ToString()) | Should -BeGreaterThan 0
    }
}

Describe "ParseJsonResults" {
    It "should parse passing JSON test results" {
        $result = ParseJsonResults "$PSScriptRoot/fixtures/json/passing.json"

        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 3
        $result[0].Name | Should -Be "TrimWhitespace"
        $result[0].Status | Should -Be "passed"
    }

    It "should parse failing JSON test results" {
        $result = ParseJsonResults "$PSScriptRoot/fixtures/json/failing.json"

        ($result | Where-Object { $_.Status -eq "passed" }).Count | Should -Be 1
        ($result | Where-Object { $_.Status -eq "failed" }).Count | Should -Be 2
        ($result | Where-Object { $_.Status -eq "skipped" }).Count | Should -Be 1
    }

    It "should include error message for failed tests" {
        $result = ParseJsonResults "$PSScriptRoot/fixtures/json/failing.json"
        $failed = $result | Where-Object { $_.Status -eq "failed" } | Select-Object -First 1
        $failed.Message | Should -Not -BeNullOrEmpty
    }
}

Describe "AggregateResults" {
    It "should combine results from multiple files" {
        $junitResult = ParseJunitXml "$PSScriptRoot/fixtures/junit/passing.xml"
        $jsonResult = ParseJsonResults "$PSScriptRoot/fixtures/json/passing.json"

        $aggregated = AggregateResults @($junitResult, $jsonResult)

        $aggregated.Count | Should -Be 6
    }

    It "should track unique tests from different sources" {
        $junitResult = ParseJunitXml "$PSScriptRoot/fixtures/junit/failing.xml"
        $jsonResult = ParseJsonResults "$PSScriptRoot/fixtures/json/failing.json"

        $aggregated = AggregateResults @($junitResult, $jsonResult)

        $aggregated.Count | Should -Be 8
    }
}

Describe "CalculateTotals" {
    It "should calculate correct totals from single file" {
        $result = ParseJunitXml "$PSScriptRoot/fixtures/junit/failing.xml"
        $totals = CalculateTotals $result

        $totals.Total | Should -Be 4
        $totals.Passed | Should -Be 1
        $totals.Failed | Should -Be 2
        $totals.Skipped | Should -Be 1
    }

    It "should calculate totals from aggregated results" {
        $junitResult = ParseJunitXml "$PSScriptRoot/fixtures/junit/passing.xml"
        $jsonResult = ParseJsonResults "$PSScriptRoot/fixtures/json/passing.json"

        $aggregated = AggregateResults @($junitResult, $jsonResult)
        $totals = CalculateTotals $aggregated

        $totals.Total | Should -Be 6
        $totals.Passed | Should -Be 6
        $totals.Failed | Should -Be 0
        $totals.Skipped | Should -Be 0
    }

    It "should calculate duration from test results" {
        $result = ParseJunitXml "$PSScriptRoot/fixtures/junit/failing.xml"
        $totals = CalculateTotals $result

        $totals.Duration | Should -BeGreaterThan 0
    }

    It "should handle empty results" {
        $totals = CalculateTotals @()

        $totals.Total | Should -Be 0
        $totals.Passed | Should -Be 0
        $totals.Failed | Should -Be 0
        $totals.Skipped | Should -Be 0
        $totals.Duration | Should -Be 0
    }
}

Describe "IdentifyFlakyTests" {
    It "should identify tests that pass and fail across runs" {
        $run1 = ParseJunitXml "$PSScriptRoot/fixtures/junit/run1.xml"
        $run2 = ParseJunitXml "$PSScriptRoot/fixtures/junit/run2.xml"

        $flaky = IdentifyFlakyTests @($run1, $run2)

        $flaky | Should -Not -BeNullOrEmpty
        $flaky | Where-Object { $_.Name -eq "DatabaseTimeout" } | Should -Not -BeNullOrEmpty
        $flaky[0].PassCount | Should -Be 1
        $flaky[0].FailCount | Should -Be 1
    }

    It "should identify flaky tests across JSON runs" {
        $run1 = ParseJsonResults "$PSScriptRoot/fixtures/json/run1.json"
        $run2 = ParseJsonResults "$PSScriptRoot/fixtures/json/run2.json"

        $flaky = IdentifyFlakyTests @($run1, $run2)

        $flaky | Should -Not -BeNullOrEmpty
        $flaky[0].Name | Should -Be "Timeout"
    }

    It "should return empty array when no flaky tests" {
        $run1 = ParseJunitXml "$PSScriptRoot/fixtures/junit/passing.xml"
        $run2 = ParseJunitXml "$PSScriptRoot/fixtures/junit/passing.xml"

        $flaky = IdentifyFlakyTests @($run1, $run2)

        $flaky.Count | Should -Be 0
    }
}

Describe "GenerateMarkdownSummary" {
    It "should generate markdown for single file results" {
        $result = ParseJunitXml "$PSScriptRoot/fixtures/junit/passing.xml"
        $totals = CalculateTotals $result
        $markdown = GenerateMarkdownSummary $totals @() "Test Report"

        $markdown | Should -Match "## Test Report"
        $markdown | Should -Match "✅"
        $markdown | Should -Match "Passed: 3"
        $markdown | Should -Match "Failed: 0"
    }

    It "should include flaky tests section when present" {
        $run1 = ParseJunitXml "$PSScriptRoot/fixtures/junit/run1.xml"
        $run2 = ParseJunitXml "$PSScriptRoot/fixtures/junit/run2.xml"

        $aggregated = AggregateResults @($run1, $run2)
        $totals = CalculateTotals $aggregated
        $flaky = IdentifyFlakyTests @($run1, $run2)

        $markdown = GenerateMarkdownSummary $totals $flaky "Flaky Test Report"

        $markdown | Should -Match "Flaky Tests"
        $markdown | Should -Match "DatabaseTimeout"
    }

    It "should not include flaky section when no flaky tests" {
        $result = ParseJunitXml "$PSScriptRoot/fixtures/junit/passing.xml"
        $totals = CalculateTotals $result
        $markdown = GenerateMarkdownSummary $totals @() "Report"

        $markdown | Should -Not -Match "Flaky Tests"
    }

    It "should show failure emoji for failures" {
        $result = ParseJunitXml "$PSScriptRoot/fixtures/junit/failing.xml"
        $totals = CalculateTotals $result
        $markdown = GenerateMarkdownSummary $totals @() "Report"

        $markdown | Should -Match "❌"
    }

    It "should include duration in report" {
        $result = ParseJunitXml "$PSScriptRoot/fixtures/junit/failing.xml"
        $totals = CalculateTotals $result
        $markdown = GenerateMarkdownSummary $totals @() "Report"

        $markdown | Should -Match "Duration:"
    }
}

Describe "Main workflow - aggregating matrix build results" {
    It "should aggregate multiple file types and generate summary" {
        $files = @(
            "$PSScriptRoot/fixtures/junit/passing.xml",
            "$PSScriptRoot/fixtures/json/passing.json",
            "$PSScriptRoot/fixtures/junit/failing.xml",
            "$PSScriptRoot/fixtures/json/failing.json"
        )

        $results = @()
        foreach ($file in $files) {
            if ($file -match "\.xml$") {
                $results += ParseJunitXml $file
            } elseif ($file -match "\.json$") {
                $results += ParseJsonResults $file
            }
        }

        $aggregated = AggregateResults $results
        $totals = CalculateTotals $aggregated

        $run1 = ParseJunitXml "$PSScriptRoot/fixtures/junit/run1.xml"
        $run2 = ParseJunitXml "$PSScriptRoot/fixtures/junit/run2.xml"
        $flaky = IdentifyFlakyTests $run1, $run2

        $summary = GenerateMarkdownSummary $totals $flaky "Matrix Build Summary"

        $summary | Should -Not -BeNullOrEmpty
        $summary | Should -Match "Matrix Build Summary"
        $totals.Total | Should -Be 14
    }
}
