
# Test file for Test Results Aggregator
# Using red/green TDD: write failing tests first, then implement minimum code to pass

BeforeAll {
    # Import the aggregator module
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $aggregatorPath = Join-Path $scriptRoot "Aggregate-TestResults.ps1"

    # Source the aggregator script
    if (Test-Path $aggregatorPath) {
        . $aggregatorPath
    }
}

Describe "Test Results Aggregator - Red/Green TDD" {

    # RED TEST #1: Parse a single JUnit XML file
    Context "Parse JUnit XML" {
        It "should parse a single JUnit XML file and return test counts" {
            $fixtures = Get-Item tests/fixtures/junit/test-results-1.xml

            $result = Invoke-TestAggregation -InputPaths $fixtures.FullName

            $result | Should -Not -BeNullOrEmpty
            $result.TotalTests | Should -Be 8
            $result.TotalPassed | Should -Be 6
            $result.TotalFailed | Should -Be 1
            $result.TotalSkipped | Should -Be 1
        }
    }

    # RED TEST #2: Aggregate results from multiple JUnit XML files
    Context "Aggregate Multiple JUnit XML Files" {
        It "should aggregate test results from multiple JUnit XML files" {
            $fixtures = @(
                (Get-Item tests/fixtures/junit/test-results-1.xml).FullName,
                (Get-Item tests/fixtures/junit/test-results-2.xml).FullName
            )

            $result = Invoke-TestAggregation -InputPaths $fixtures

            $result.TotalTests | Should -Be 13  # 8 + 5
            $result.TotalPassed | Should -Be 10  # 6 + 4
            $result.TotalFailed | Should -Be 2   # 1 + 1
            $result.TotalSkipped | Should -Be 1   # 1 + 0
        }
    }

    # RED TEST #3: Identify flaky tests (tests that pass in some runs but fail in others)
    Context "Identify Flaky Tests" {
        It "should identify flaky tests across runs" {
            $fixtures = @(
                (Get-Item tests/fixtures/junit/test-results-1.xml).FullName,
                (Get-Item tests/fixtures/junit/test-results-2.xml).FullName
            )

            $result = Invoke-TestAggregation -InputPaths $fixtures

            # ShouldValidateToken passes in file 1 but fails in file 2
            $result.FlakyTests | Should -Not -BeNullOrEmpty
            $result.FlakyTests | Should -Contain "ShouldValidateToken"
        }
    }

    # RED TEST #4: Calculate total duration
    Context "Calculate Duration" {
        It "should calculate total test duration" {
            $fixtures = Get-Item tests/fixtures/junit/test-results-1.xml

            $result = Invoke-TestAggregation -InputPaths $fixtures.FullName

            $result.TotalDuration | Should -BeGreaterThan 0
            $result.TotalDuration | Should -BeLessThan 10
        }
    }

    # RED TEST #5: Generate Markdown summary
    Context "Generate Markdown Summary" {
        It "should generate a markdown summary of test results" {
            $fixtures = @(
                (Get-Item tests/fixtures/junit/test-results-1.xml).FullName,
                (Get-Item tests/fixtures/junit/test-results-2.xml).FullName
            )

            $result = Invoke-TestAggregation -InputPaths $fixtures
            $markdown = ConvertTo-TestResultsMarkdown -AggregationResult $result

            $markdown | Should -Not -BeNullOrEmpty
            $markdown | Should -Match "Test Results Summary"
            $markdown | Should -Match "13"  # Total tests
            $markdown | Should -Match "10"  # Passed
        }
    }

    # RED TEST #6: Parse JSON test results
    Context "Parse JSON Test Results" {
        It "should parse JSON test result files" {
            $fixtures = Get-Item tests/fixtures/json/test-results-1.json

            $result = Invoke-TestAggregation -InputPaths $fixtures.FullName

            $result | Should -Not -BeNullOrEmpty
            $result.TotalTests | Should -Be 5
            $result.TotalPassed | Should -Be 5
            $result.TotalFailed | Should -Be 0
        }
    }

    # RED TEST #7: Identify flaky tests in JSON results
    Context "Identify Flaky Tests in JSON" {
        It "should identify flaky tests across JSON test result files" {
            $fixtures = @(
                (Get-Item tests/fixtures/json/test-results-1.json).FullName,
                (Get-Item tests/fixtures/json/test-results-2.json).FullName
            )

            $result = Invoke-TestAggregation -InputPaths $fixtures

            # TestSubtract passes in file 1 but fails in file 2
            $result.FlakyTests | Should -Not -BeNullOrEmpty
            $result.FlakyTests | Should -Contain "TestSubtract"
        }
    }

    # RED TEST #8: Mixed XML and JSON files
    Context "Mixed File Formats" {
        It "should aggregate results from mixed XML and JSON files" {
            $fixtures = @(
                (Get-Item tests/fixtures/junit/test-results-1.xml).FullName,
                (Get-Item tests/fixtures/json/test-results-1.json).FullName
            )

            $result = Invoke-TestAggregation -InputPaths $fixtures

            $result.TotalTests | Should -Be 13  # 8 + 5
            $result.TotalPassed | Should -Be 11  # 6 + 5
        }
    }

    # RED TEST #9: Error handling for invalid files
    Context "Error Handling" {
        It "should handle missing files gracefully" {
            {
                Invoke-TestAggregation -InputPaths "nonexistent-file.xml"
            } | Should -Throw
        }
    }

    # RED TEST #10: Export to file
    Context "Export Results" {
        It "should export markdown summary to a file" {
            $fixtures = @(
                (Get-Item tests/fixtures/junit/test-results-1.xml).FullName,
                (Get-Item tests/fixtures/junit/test-results-2.xml).FullName
            )
            $outputPath = "TestResults-Summary.md"

            try {
                $result = Invoke-TestAggregation -InputPaths $fixtures -OutputPath $outputPath

                Test-Path $outputPath | Should -Be $true
                (Get-Content $outputPath | Measure-Object -Line).Lines | Should -BeGreaterThan 0
            } finally {
                if (Test-Path $outputPath) { Remove-Item $outputPath }
            }
        }
    }
}
