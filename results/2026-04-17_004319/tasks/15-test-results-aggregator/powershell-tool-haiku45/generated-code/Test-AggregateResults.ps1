param(
    [string]$TestPath = $PSScriptRoot
)

# Import the module we're testing
$modulePath = Join-Path $TestPath "Test-ResultsAggregator.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}

# TDD Test 1: Parse a single JUnit XML file
Describe "Parse-JUnitXml" {
    It "should parse a valid JUnit XML file" {
        # Arrange: Create a test fixture
        $xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
    <testsuite name="TestSuite1" tests="3" failures="1" skipped="0" time="1.5">
        <testcase name="test_pass" time="0.5"/>
        <testcase name="test_fail" time="0.5">
            <failure message="assertion failed">Stack trace here</failure>
        </testcase>
        <testcase name="test_skip" time="0.5">
            <skipped message="skipped by user"/>
        </testcase>
    </testsuite>
</testsuites>
"@
        $xmlFile = Join-Path ([System.IO.Path]::GetTempPath()) "test.xml"
        Set-Content -Path $xmlFile -Value $xmlContent

        # Act
        $result = Parse-JUnitXml -Path $xmlFile

        # Assert
        $result | Should -Not -BeNullOrEmpty
        $result.passed | Should -Be 1
        $result.failed | Should -Be 1
        $result.skipped | Should -Be 1
        $result.totalDuration | Should -Be 1.5

        # Cleanup
        Remove-Item $xmlFile -Force
    }
}

# TDD Test 2: Parse a JSON test results file
Describe "Parse-JsonTestResults" {
    It "should parse a valid JSON test results file" {
        # Arrange
        $jsonContent = @"
{
    "tests": 3,
    "passes": 2,
    "failures": 1,
    "skipped": 0,
    "duration": 2000,
    "testCases": [
        {"name": "test_one", "state": "passed", "duration": 500},
        {"name": "test_two", "state": "passed", "duration": 600},
        {"name": "test_three", "state": "failed", "duration": 900}
    ]
}
"@
        $jsonFile = Join-Path ([System.IO.Path]::GetTempPath()) "results.json"
        Set-Content -Path $jsonFile -Value $jsonContent

        # Act
        $result = Parse-JsonTestResults -Path $jsonFile

        # Assert
        $result | Should -Not -BeNullOrEmpty
        $result.passed | Should -Be 2
        $result.failed | Should -Be 1
        $result.skipped | Should -Be 0
        $result.totalDuration | Should -Be 2

        # Cleanup
        Remove-Item $jsonFile -Force
    }
}

# TDD Test 3: Aggregate multiple test results
Describe "Aggregate-TestResults" {
    It "should aggregate results from multiple files" {
        # Arrange: Create two test result files
        $xml1 = @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
    <testsuite name="Suite1" tests="2" failures="0" skipped="0" time="1.0">
        <testcase name="test_a" time="0.5"/>
        <testcase name="test_b" time="0.5"/>
    </testsuite>
</testsuites>
"@
        $json1 = @"
{
    "tests": 2,
    "passes": 2,
    "failures": 0,
    "skipped": 0,
    "duration": 1500,
    "testCases": [
        {"name": "test_c", "state": "passed", "duration": 1000},
        {"name": "test_d", "state": "passed", "duration": 500}
    ]
}
"@
        $xmlFile = Join-Path ([System.IO.Path]::GetTempPath()) "test1.xml"
        $jsonFile = Join-Path ([System.IO.Path]::GetTempPath()) "test2.json"
        Set-Content -Path $xmlFile -Value $xml1
        Set-Content -Path $jsonFile -Value $json1

        # Act
        $results = @(
            Parse-JUnitXml -Path $xmlFile
            Parse-JsonTestResults -Path $jsonFile
        )
        $aggregated = Aggregate-TestResults -Results $results

        # Assert
        $aggregated.totalPassed | Should -Be 4
        $aggregated.totalFailed | Should -Be 0
        $aggregated.totalSkipped | Should -Be 0
        $aggregated.totalDuration | Should -Be 2.5

        # Cleanup
        Remove-Item $xmlFile, $jsonFile -Force
    }
}

# TDD Test 4: Identify flaky tests
Describe "Identify-FlakyTests" {
    It "should identify tests that passed in some runs and failed in others" {
        # Arrange
        $run1 = @{
            testCases = @(
                @{name = "test_flaky"; state = "passed"; duration = 100},
                @{name = "test_stable"; state = "passed"; duration = 100}
            )
        }
        $run2 = @{
            testCases = @(
                @{name = "test_flaky"; state = "failed"; duration = 100},
                @{name = "test_stable"; state = "passed"; duration = 100}
            )
        }

        # Act
        $flaky = Identify-FlakyTests -Runs @($run1, $run2)

        # Assert
        $flaky | Should -Contain "test_flaky"
        $flaky | Should -Not -Contain "test_stable"
    }
}

# TDD Test 5: Generate Markdown summary
Describe "Generate-MarkdownSummary" {
    It "should generate a markdown summary of test results" {
        # Arrange
        $summary = @{
            totalTests = 10
            totalPassed = 7
            totalFailed = 2
            totalSkipped = 1
            totalDuration = 5.5
            flakyTests = @("test_flaky1", "test_flaky2")
            runCount = 2
        }

        # Act
        $markdown = Generate-MarkdownSummary -Summary $summary

        # Assert
        $markdown | Should -Match "Test Results"
        $markdown | Should -Match "Passed.*7"
        $markdown | Should -Match "Failed.*2"
        $markdown | Should -Match "Skipped.*1"
        $markdown | Should -Match "test_flaky1"
    }
}
