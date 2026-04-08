# TestResultsAggregator.Tests.ps1
# Pester tests for the Test Results Aggregator module.
# TDD approach: each test was written FIRST (red), then implementation added (green), then refactored.

BeforeAll {
    . "$PSScriptRoot/TestResultsAggregator.ps1"
}

# --------------------------------------------------------------------------
# Import-JUnitResults: Parse JUnit XML files into a normalized structure
# --------------------------------------------------------------------------
Describe 'Import-JUnitResults' {

    Context 'with a valid JUnit XML file' {
        BeforeAll {
            $script:results = Import-JUnitResults -Path "$PSScriptRoot/fixtures/junit-run1.xml"
        }

        It 'returns an object with a TestCases array' {
            $results.TestCases | Should -Not -BeNullOrEmpty
        }

        It 'parses the correct number of test cases' {
            $results.TestCases.Count | Should -Be 5
        }

        It 'extracts test name and classname' {
            $tc = $results.TestCases | Where-Object { $_.Name -eq 'test_addition' }
            $tc.ClassName | Should -Be 'MathTests'
        }

        It 'marks passed tests as Passed' {
            $tc = $results.TestCases | Where-Object { $_.Name -eq 'test_addition' }
            $tc.Status | Should -Be 'Passed'
        }

        It 'marks failed tests as Failed with an error message' {
            $tc = $results.TestCases | Where-Object { $_.Name -eq 'test_subtraction' }
            $tc.Status | Should -Be 'Failed'
            $tc.ErrorMessage | Should -BeLike '*Expected 5*'
        }

        It 'marks skipped tests as Skipped' {
            $tc = $results.TestCases | Where-Object { $_.Name -eq 'test_split' }
            $tc.Status | Should -Be 'Skipped'
        }

        It 'parses duration as a double' {
            $tc = $results.TestCases | Where-Object { $_.Name -eq 'test_addition' }
            $tc.Duration | Should -BeOfType [double]
            $tc.Duration | Should -Be 1.1
        }

        It 'captures the total duration from the root element' {
            $results.TotalDuration | Should -Be 12.345
        }
    }

    Context 'with a non-existent file' {
        It 'throws a meaningful error' {
            { Import-JUnitResults -Path '/no/such/file.xml' } |
                Should -Throw '*does not exist*'
        }
    }

    Context 'with invalid XML content' {
        BeforeAll {
            $script:badFile = Join-Path $TestDrive 'bad.xml'
            'not xml at all' | Set-Content $badFile
        }

        It 'throws a meaningful error' {
            { Import-JUnitResults -Path $badFile } |
                Should -Throw '*Failed to parse*'
        }
    }
}

# --------------------------------------------------------------------------
# Import-JsonResults: Parse JSON test result files into a normalized structure
# --------------------------------------------------------------------------
Describe 'Import-JsonResults' {

    Context 'with a valid JSON results file' {
        BeforeAll {
            $script:results = Import-JsonResults -Path "$PSScriptRoot/fixtures/results-run1.json"
        }

        It 'returns an object with a TestCases array' {
            $results.TestCases | Should -Not -BeNullOrEmpty
        }

        It 'parses the correct number of test cases' {
            $results.TestCases.Count | Should -Be 3
        }

        It 'extracts test name and classname' {
            $tc = $results.TestCases | Where-Object { $_.Name -eq 'test_get_users' }
            $tc.ClassName | Should -Be 'APITests'
        }

        It 'normalizes status to title case (passed -> Passed)' {
            $tc = $results.TestCases | Where-Object { $_.Name -eq 'test_get_users' }
            $tc.Status | Should -Be 'Passed'
        }

        It 'captures error messages for failed tests' {
            $tc = $results.TestCases | Where-Object { $_.Name -eq 'test_create_user' }
            $tc.Status | Should -Be 'Failed'
            $tc.ErrorMessage | Should -BeLike '*ConnectionError*'
        }

        It 'marks skipped tests as Skipped' {
            $tc = $results.TestCases | Where-Object { $_.Name -eq 'test_delete_user' }
            $tc.Status | Should -Be 'Skipped'
        }

        It 'computes total duration as sum of all test durations' {
            $results.TotalDuration | Should -Be 1.7
        }
    }

    Context 'with a non-existent file' {
        It 'throws a meaningful error' {
            { Import-JsonResults -Path '/no/such/file.json' } |
                Should -Throw '*does not exist*'
        }
    }

    Context 'with invalid JSON content' {
        BeforeAll {
            $script:badFile = Join-Path $TestDrive 'bad.json'
            'not json{{{' | Set-Content $badFile
        }

        It 'throws a meaningful error' {
            { Import-JsonResults -Path $badFile } |
                Should -Throw '*Failed to parse*'
        }
    }
}

# --------------------------------------------------------------------------
# Merge-TestResults: Aggregate results from multiple runs into totals
# --------------------------------------------------------------------------
Describe 'Merge-TestResults' {

    Context 'with two JUnit runs and two JSON runs' {
        BeforeAll {
            $script:run1 = Import-JUnitResults -Path "$PSScriptRoot/fixtures/junit-run1.xml"
            $script:run2 = Import-JUnitResults -Path "$PSScriptRoot/fixtures/junit-run2.xml"
            $script:run3 = Import-JsonResults  -Path "$PSScriptRoot/fixtures/results-run1.json"
            $script:run4 = Import-JsonResults  -Path "$PSScriptRoot/fixtures/results-run2.json"
            $script:merged = Merge-TestResults -Results @($run1, $run2, $run3, $run4)
        }

        It 'returns an object with Passed, Failed, Skipped counts' {
            $merged.PSObject.Properties.Name | Should -Contain 'Passed'
            $merged.PSObject.Properties.Name | Should -Contain 'Failed'
            $merged.PSObject.Properties.Name | Should -Contain 'Skipped'
        }

        It 'counts total test executions across all runs' {
            $merged.TotalTests | Should -Be 16
        }

        It 'counts passed tests correctly' {
            # run1: 3 passed, run2: 3 passed, run3: 1 passed, run4: 2 passed = 9
            $merged.Passed | Should -Be 9
        }

        It 'counts failed tests correctly' {
            # run1: 1 failed, run2: 1 failed, run3: 1 failed, run4: 0 = 3
            $merged.Failed | Should -Be 3
        }

        It 'counts skipped tests correctly' {
            # run1: 1 skipped, run2: 1 skipped, run3: 1 skipped, run4: 1 = 4
            $merged.Skipped | Should -Be 4
        }

        It 'sums total duration across all runs' {
            # 12.345 + 11.8 + 1.7 + 1.2 = 27.045
            $merged.TotalDuration | Should -Be 27.045
        }

        It 'includes all individual test case records' {
            $merged.AllTestCases.Count | Should -Be 16
        }
    }

    Context 'with an empty results array' {
        BeforeAll {
            $script:merged = Merge-TestResults -Results @()
        }

        It 'returns zero totals' {
            $merged.TotalTests | Should -Be 0
            $merged.Passed | Should -Be 0
            $merged.Failed | Should -Be 0
            $merged.Skipped | Should -Be 0
            $merged.TotalDuration | Should -Be 0
        }
    }
}

# --------------------------------------------------------------------------
# Get-FlakyTests: Identify tests that passed in some runs and failed in others
# --------------------------------------------------------------------------
Describe 'Get-FlakyTests' {

    Context 'with mixed JUnit results across two runs' {
        BeforeAll {
            # In run1, test_subtraction fails; in run2, it passes — flaky.
            # In run1, test_concat passes; in run2, test_concat fails — flaky.
            $script:run1 = Import-JUnitResults -Path "$PSScriptRoot/fixtures/junit-run1.xml"
            $script:run2 = Import-JUnitResults -Path "$PSScriptRoot/fixtures/junit-run2.xml"
            $script:merged = Merge-TestResults -Results @($run1, $run2)
            $script:flaky = Get-FlakyTests -MergedResults $merged
        }

        It 'identifies test_subtraction as flaky' {
            $flaky.Name | Should -Contain 'test_subtraction'
        }

        It 'identifies test_concat as flaky' {
            $flaky.Name | Should -Contain 'test_concat'
        }

        It 'does not flag consistently passing tests' {
            $flaky.Name | Should -Not -Contain 'test_addition'
            $flaky.Name | Should -Not -Contain 'test_multiplication'
        }

        It 'does not flag consistently skipped tests' {
            $flaky.Name | Should -Not -Contain 'test_split'
        }

        It 'includes pass and fail counts for each flaky test' {
            $sub = $flaky | Where-Object { $_.Name -eq 'test_subtraction' }
            $sub.PassCount | Should -Be 1
            $sub.FailCount | Should -Be 1
        }
    }

    Context 'with no flaky tests' {
        BeforeAll {
            # Two identical passing runs — no flakiness
            $script:run = Import-JsonResults -Path "$PSScriptRoot/fixtures/results-run2.json"
            $script:merged = Merge-TestResults -Results @($run, $run)
            $script:flaky = Get-FlakyTests -MergedResults $merged
        }

        It 'returns an empty array' {
            $flaky | Should -BeNullOrEmpty
        }
    }
}

# --------------------------------------------------------------------------
# New-MarkdownSummary: Generate a GitHub Actions job summary in Markdown
# --------------------------------------------------------------------------
Describe 'New-MarkdownSummary' {

    Context 'with aggregated results including flaky tests' {
        BeforeAll {
            $script:run1 = Import-JUnitResults -Path "$PSScriptRoot/fixtures/junit-run1.xml"
            $script:run2 = Import-JUnitResults -Path "$PSScriptRoot/fixtures/junit-run2.xml"
            $script:merged = Merge-TestResults -Results @($run1, $run2)
            $script:flaky = Get-FlakyTests -MergedResults $merged
            $script:md = New-MarkdownSummary -MergedResults $merged -FlakyTests $flaky
        }

        It 'returns a non-empty string' {
            $md | Should -Not -BeNullOrEmpty
        }

        It 'includes a heading' {
            $md | Should -BeLike '*# Test Results Summary*'
        }

        It 'includes total test count' {
            $md | Should -BeLike '*10*'
        }

        It 'includes passed count' {
            $md | Should -BeLike '*6*'
        }

        It 'includes failed count' {
            $md | Should -BeLike '*2*'
        }

        It 'includes skipped count' {
            $md | Should -BeLike '*2*'
        }

        It 'includes total duration' {
            $md | Should -BeLike '*24.145*'
        }

        It 'includes a flaky tests section' {
            $md | Should -BeLike '*Flaky Tests*'
        }

        It 'lists flaky test names' {
            $md | Should -BeLike '*test_subtraction*'
            $md | Should -BeLike '*test_concat*'
        }

        It 'includes a failed tests section with error messages' {
            $md | Should -BeLike '*Failed Tests*'
            $md | Should -BeLike '*Expected 5*'
        }
    }

    Context 'with no failures and no flaky tests' {
        BeforeAll {
            $script:run = Import-JsonResults -Path "$PSScriptRoot/fixtures/results-run2.json"
            $script:merged = Merge-TestResults -Results @($run)
            $script:md = New-MarkdownSummary -MergedResults $merged -FlakyTests @()
        }

        It 'shows a green status when all tests pass' {
            $md | Should -BeLike '*Passed*'
        }

        It 'does not include a flaky tests section when there are none' {
            $md | Should -Not -BeLike '*Flaky Tests*'
        }

        It 'does not include a failed tests section when there are none' {
            $md | Should -Not -BeLike '*Failed Tests*'
        }
    }
}

# --------------------------------------------------------------------------
# Invoke-TestResultsAggregator: End-to-end orchestration
# --------------------------------------------------------------------------
Describe 'Invoke-TestResultsAggregator' {

    Context 'processing a directory of mixed fixture files' {
        BeforeAll {
            $script:output = Invoke-TestResultsAggregator -Path "$PSScriptRoot/fixtures"
        }

        It 'returns a result with a Markdown property' {
            $output.Markdown | Should -Not -BeNullOrEmpty
        }

        It 'returns merged results' {
            $output.Merged.TotalTests | Should -BeGreaterThan 0
        }

        It 'returns flaky test info' {
            $output.PSObject.Properties.Name | Should -Contain 'FlakyTests'
        }
    }

    Context 'with a directory containing no test files' {
        BeforeAll {
            $script:emptyDir = Join-Path $TestDrive 'empty'
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        }

        It 'throws a meaningful error' {
            { Invoke-TestResultsAggregator -Path $emptyDir } |
                Should -Throw '*No test result files found*'
        }
    }
}
