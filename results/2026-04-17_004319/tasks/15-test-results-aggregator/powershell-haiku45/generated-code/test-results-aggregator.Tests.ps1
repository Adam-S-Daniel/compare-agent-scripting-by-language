# Test suite for Test Results Aggregator
# Uses Pester framework for TDD-style testing

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot "test-results-aggregator.ps1"
    if (Test-Path $ModulePath) {
        . $ModulePath
    }
}

Describe "Test Results Aggregator" {
    Context "Initialization" {
        It "should define Invoke-TestResultsAggregator function" {
            (Get-Command Invoke-TestResultsAggregator -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }
    }

    Context "JUnit XML Parsing" {
        It "should parse a simple JUnit XML file" {
            $result = Get-JunitXmlTestResults -FilePath "nonexistent.xml"
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "JSON Parsing" {
        It "should parse a JSON test results file" {
            $result = Get-JsonTestResults -FilePath "nonexistent.json"
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Aggregation" {
        It "should aggregate multiple test results" {
            $result = Aggregate-TestResults -TestResults @()
            $result.Passed | Should -Be 0
            $result.Failed | Should -Be 0
        }
    }

    Context "Markdown Output" {
        It "should generate markdown summary" {
            $agg = @{Passed = 5; Failed = 2; Skipped = 1; Duration = 30}
            $result = ConvertTo-MarkdownSummary -AggregatedResults $agg
            $result | Should -Match "Passed"
            $result | Should -Match "Failed"
        }
    }

    Context "Flaky Test Detection" {
        It "should identify flaky tests" {
            $runs = @(
                @{
                    Tests = @(
                        @{Name = "FlakyTest"; Status = "passed"},
                        @{Name = "StableTest"; Status = "passed"}
                    )
                },
                @{
                    Tests = @(
                        @{Name = "FlakyTest"; Status = "failed"},
                        @{Name = "StableTest"; Status = "passed"}
                    )
                }
            )
            $result = Find-FlakyTests -MultipleRuns $runs
            $result | Should -Not -BeNullOrEmpty
            $result[0].Name | Should -Be "FlakyTest"
        }
    }
}
