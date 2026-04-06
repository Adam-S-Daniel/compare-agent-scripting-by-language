# TDD Tests for TestResultsAggregator module
# Following red/green/refactor: each Describe block represents a feature cycle
# Tests were written FIRST, then implementation was added to make them pass.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'TestResultsAggregator.psm1'
    Import-Module $modulePath -Force

    # Resolve fixture paths
    $script:FixturesDir = Join-Path -Path $PSScriptRoot -ChildPath 'fixtures'
    $script:JUnitRun1 = Join-Path -Path $script:FixturesDir -ChildPath 'junit-run1.xml'
    $script:JUnitRun2 = Join-Path -Path $script:FixturesDir -ChildPath 'junit-run2.xml'
    $script:JsonRun1 = Join-Path -Path $script:FixturesDir -ChildPath 'json-run1.json'
    $script:JsonRun2 = Join-Path -Path $script:FixturesDir -ChildPath 'json-run2.json'
}

# =============================================================================
# RED/GREEN CYCLE 1: JUnit XML Parsing
# First we wrote these tests (RED), then implemented Import-JUnitResults (GREEN)
# =============================================================================
Describe 'Import-JUnitResults' {
    Context 'when parsing a valid JUnit XML file' {
        BeforeAll {
            $script:result = Import-JUnitResults -Path $script:JUnitRun1
        }

        It 'returns a result object with a RunName' {
            $script:result.RunName | Should -Be 'Run1'
        }

        It 'contains the correct number of test cases' {
            $script:result.TestCases.Count | Should -Be 5
        }

        It 'parses passed tests correctly' {
            $passed = @($script:result.TestCases | Where-Object { $_.Status -eq 'passed' })
            $passed.Count | Should -Be 3
        }

        It 'parses failed tests correctly' {
            $failed = @($script:result.TestCases | Where-Object { $_.Status -eq 'failed' })
            $failed.Count | Should -Be 1
        }

        It 'parses skipped tests correctly' {
            $skipped = @($script:result.TestCases | Where-Object { $_.Status -eq 'skipped' })
            $skipped.Count | Should -Be 1
        }

        It 'captures test name and classname' {
            $first = $script:result.TestCases[0]
            $first.Name | Should -Be 'login succeeds with valid credentials'
            $first.ClassName | Should -Be 'AuthTests'
        }

        It 'captures test duration as a double' {
            $first = $script:result.TestCases[0]
            $first.Duration | Should -BeOfType [double]
            $first.Duration | Should -Be 2.1
        }

        It 'captures failure message for failed tests' {
            $failed = $script:result.TestCases | Where-Object { $_.Status -eq 'failed' }
            $failed.FailureMessage | Should -BeLike '*Expected 401*'
        }

        It 'captures total duration' {
            $script:result.TotalDuration | Should -BeGreaterThan 0
        }
    }

    Context 'when parsing the second run' {
        BeforeAll {
            $script:result2 = Import-JUnitResults -Path $script:JUnitRun2
        }

        It 'has no failures in run2' {
            $failed = @($script:result2.TestCases | Where-Object { $_.Status -eq 'failed' })
            $failed.Count | Should -Be 0
        }

        It 'returns RunName from the testsuites element' {
            $script:result2.RunName | Should -Be 'Run2'
        }
    }

    Context 'when given a non-existent file' {
        It 'throws a meaningful error' {
            { Import-JUnitResults -Path '/nonexistent/file.xml' } |
                Should -Throw '*does not exist*'
        }
    }

    Context 'when given invalid XML' {
        BeforeAll {
            $script:tempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'bad.xml'
            Set-Content -Path $script:tempFile -Value 'not valid xml <><>'
        }
        AfterAll {
            if (Test-Path -Path $script:tempFile) {
                Remove-Item -Path $script:tempFile -Force
            }
        }

        It 'throws a meaningful error for malformed XML' {
            { Import-JUnitResults -Path $script:tempFile } |
                Should -Throw '*Failed to parse*'
        }
    }
}

# =============================================================================
# RED/GREEN CYCLE 2: JSON Test Result Parsing
# First we wrote these tests (RED), then implemented Import-JsonTestResults (GREEN)
# =============================================================================
Describe 'Import-JsonTestResults' {
    Context 'when parsing a valid JSON file' {
        BeforeAll {
            $script:result = Import-JsonTestResults -Path $script:JsonRun1
        }

        It 'returns a result object with a RunName' {
            $script:result.RunName | Should -Be 'Run1'
        }

        It 'contains the correct number of test cases' {
            $script:result.TestCases.Count | Should -Be 4
        }

        It 'parses passed tests correctly' {
            $passed = @($script:result.TestCases | Where-Object { $_.Status -eq 'passed' })
            $passed.Count | Should -Be 2
        }

        It 'parses failed tests correctly' {
            $failed = @($script:result.TestCases | Where-Object { $_.Status -eq 'failed' })
            $failed.Count | Should -Be 1
        }

        It 'parses skipped tests correctly' {
            $skipped = @($script:result.TestCases | Where-Object { $_.Status -eq 'skipped' })
            $skipped.Count | Should -Be 1
        }

        It 'captures test duration' {
            $first = $script:result.TestCases[0]
            $first.Duration | Should -BeOfType [double]
            $first.Duration | Should -Be 3.2
        }

        It 'captures failure message for failed tests' {
            $failed = $script:result.TestCases | Where-Object { $_.Status -eq 'failed' }
            $failed.FailureMessage | Should -BeLike '*Expected decline*'
        }

        It 'captures total duration' {
            $script:result.TotalDuration | Should -BeGreaterThan 0
        }
    }

    Context 'when given a non-existent file' {
        It 'throws a meaningful error' {
            { Import-JsonTestResults -Path '/nonexistent/file.json' } |
                Should -Throw '*does not exist*'
        }
    }

    Context 'when given invalid JSON' {
        BeforeAll {
            $script:tempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'bad.json'
            Set-Content -Path $script:tempFile -Value '{ not valid json'
        }
        AfterAll {
            if (Test-Path -Path $script:tempFile) {
                Remove-Item -Path $script:tempFile -Force
            }
        }

        It 'throws a meaningful error for malformed JSON' {
            { Import-JsonTestResults -Path $script:tempFile } |
                Should -Throw '*Failed to parse*'
        }
    }
}

# =============================================================================
# RED/GREEN CYCLE 3: Result Aggregation
# First we wrote these tests (RED), then implemented Merge-TestResults (GREEN)
# =============================================================================
Describe 'Merge-TestResults' {
    Context 'when merging results from multiple runs' {
        BeforeAll {
            $junitResult1 = Import-JUnitResults -Path $script:JUnitRun1
            $junitResult2 = Import-JUnitResults -Path $script:JUnitRun2
            $jsonResult1 = Import-JsonTestResults -Path $script:JsonRun1
            $jsonResult2 = Import-JsonTestResults -Path $script:JsonRun2
            $script:allResults = @($junitResult1, $junitResult2, $jsonResult1, $jsonResult2)
            $script:merged = Merge-TestResults -Results $script:allResults
        }

        It 'returns a hashtable with totals' {
            $script:merged | Should -Not -BeNullOrEmpty
            $script:merged.ContainsKey('TotalPassed') | Should -BeTrue
            $script:merged.ContainsKey('TotalFailed') | Should -BeTrue
            $script:merged.ContainsKey('TotalSkipped') | Should -BeTrue
            $script:merged.ContainsKey('TotalDuration') | Should -BeTrue
        }

        It 'computes correct total passed count across all runs' {
            # Run1 JUnit: 3 passed, Run2 JUnit: 4 passed
            # Run1 JSON: 2 passed, Run2 JSON: 3 passed
            $script:merged.TotalPassed | Should -Be 12
        }

        It 'computes correct total failed count across all runs' {
            # Run1 JUnit: 1 failed, Run2 JUnit: 0 failed
            # Run1 JSON: 1 failed, Run2 JSON: 0 failed
            $script:merged.TotalFailed | Should -Be 2
        }

        It 'computes correct total skipped count across all runs' {
            # Run1 JUnit: 1 skipped, Run2 JUnit: 1 skipped
            # Run1 JSON: 1 skipped, Run2 JSON: 1 skipped
            $script:merged.TotalSkipped | Should -Be 4
        }

        It 'computes total duration across all runs' {
            $script:merged.TotalDuration | Should -BeGreaterThan 0
        }

        It 'tracks the number of runs' {
            $script:merged.RunCount | Should -Be 4
        }

        It 'builds a per-test breakdown keyed by classname.name' {
            $script:merged.ContainsKey('TestDetails') | Should -BeTrue
            $script:merged.TestDetails.Count | Should -BeGreaterThan 0
        }

        It 'includes individual run outcomes in per-test details' {
            $key = 'AuthTests.login succeeds with valid credentials'
            $script:merged.TestDetails.ContainsKey($key) | Should -BeTrue
            $detail = $script:merged.TestDetails[$key]
            $detail.Outcomes.Count | Should -Be 2  # appeared in 2 JUnit runs
        }
    }

    Context 'when merging a single run' {
        BeforeAll {
            $single = Import-JUnitResults -Path $script:JUnitRun1
            $script:mergedSingle = Merge-TestResults -Results @($single)
        }

        It 'handles a single run correctly' {
            $script:mergedSingle.RunCount | Should -Be 1
            $script:mergedSingle.TotalPassed | Should -Be 3
            $script:mergedSingle.TotalFailed | Should -Be 1
            $script:mergedSingle.TotalSkipped | Should -Be 1
        }
    }

    Context 'when given an empty array' {
        It 'throws a meaningful error' {
            { Merge-TestResults -Results @() } |
                Should -Throw '*at least one*'
        }
    }
}

# =============================================================================
# RED/GREEN CYCLE 4: Flaky Test Detection
# First we wrote these tests (RED), then implemented Get-FlakyTests (GREEN)
# =============================================================================
Describe 'Get-FlakyTests' {
    Context 'when analyzing merged results with flaky tests' {
        BeforeAll {
            $junitResult1 = Import-JUnitResults -Path $script:JUnitRun1
            $junitResult2 = Import-JUnitResults -Path $script:JUnitRun2
            $jsonResult1 = Import-JsonTestResults -Path $script:JsonRun1
            $jsonResult2 = Import-JsonTestResults -Path $script:JsonRun2
            $allResults = @($junitResult1, $junitResult2, $jsonResult1, $jsonResult2)
            $merged = Merge-TestResults -Results $allResults
            $script:flakyTests = @(Get-FlakyTests -MergedResults $merged)
        }

        It 'identifies flaky tests (passed in some runs, failed in others)' {
            $script:flakyTests.Count | Should -BeGreaterThan 0
        }

        It 'detects "login fails with invalid password" as flaky (failed run1, passed run2)' {
            $names = $script:flakyTests | ForEach-Object { $_.Name }
            $names | Should -Contain 'login fails with invalid password'
        }

        It 'detects "charge card fails with expired card" as flaky (failed run1, passed run2)' {
            $names = $script:flakyTests | ForEach-Object { $_.Name }
            $names | Should -Contain 'charge card fails with expired card'
        }

        It 'does not flag consistently passing tests as flaky' {
            $names = $script:flakyTests | ForEach-Object { $_.Name }
            $names | Should -Not -Contain 'login succeeds with valid credentials'
        }

        It 'does not flag consistently skipped tests as flaky' {
            $names = $script:flakyTests | ForEach-Object { $_.Name }
            $names | Should -Not -Contain 'sends SMS on purchase'
        }

        It 'includes failure rate information' {
            $flaky = $script:flakyTests | Where-Object { $_.Name -eq 'login fails with invalid password' }
            $flaky.FailureRate | Should -BeGreaterThan 0
            $flaky.FailureRate | Should -BeLessThan 1
        }
    }

    Context 'when no tests are flaky' {
        BeforeAll {
            # Use only run2 files where everything passes
            $r2a = Import-JUnitResults -Path $script:JUnitRun2
            $r2b = Import-JsonTestResults -Path $script:JsonRun2
            $merged = Merge-TestResults -Results @($r2a, $r2b)
            $script:noFlaky = @(Get-FlakyTests -MergedResults $merged)
        }

        It 'returns an empty array when no flaky tests exist' {
            $script:noFlaky.Count | Should -Be 0
        }
    }
}

# =============================================================================
# RED/GREEN CYCLE 5: Markdown Summary Generation
# First we wrote these tests (RED), then implemented New-MarkdownSummary (GREEN)
# =============================================================================
Describe 'New-MarkdownSummary' {
    Context 'when generating a summary from merged results' {
        BeforeAll {
            $junitResult1 = Import-JUnitResults -Path $script:JUnitRun1
            $junitResult2 = Import-JUnitResults -Path $script:JUnitRun2
            $jsonResult1 = Import-JsonTestResults -Path $script:JsonRun1
            $jsonResult2 = Import-JsonTestResults -Path $script:JsonRun2
            $allResults = @($junitResult1, $junitResult2, $jsonResult1, $jsonResult2)
            $merged = Merge-TestResults -Results $allResults
            $flakyTests = @(Get-FlakyTests -MergedResults $merged)
            $script:markdown = New-MarkdownSummary -MergedResults $merged -FlakyTests $flakyTests
        }

        It 'returns a non-empty string' {
            $script:markdown | Should -Not -BeNullOrEmpty
        }

        It 'includes a title header' {
            $script:markdown | Should -BeLike '*# Test Results Summary*'
        }

        It 'includes total passed count' {
            $script:markdown | Should -BeLike '*Passed*12*'
        }

        It 'includes total failed count' {
            $script:markdown | Should -BeLike '*Failed*2*'
        }

        It 'includes total skipped count' {
            $script:markdown | Should -BeLike '*Skipped*4*'
        }

        It 'includes total duration' {
            $script:markdown | Should -BeLike '*Duration*'
        }

        It 'includes run count' {
            $script:markdown | Should -BeLike '*4*run*'
        }

        It 'includes a flaky tests section' {
            $script:markdown | Should -BeLike '*Flaky Tests*'
        }

        It 'lists flaky test names in the summary' {
            $script:markdown | Should -BeLike '*login fails with invalid password*'
        }

        It 'includes failure rate for flaky tests' {
            # The flaky test has 50% failure rate (1 fail out of 2 runs)
            $script:markdown | Should -BeLike '*50*%*'
        }

        It 'includes a table with markdown formatting' {
            $script:markdown | Should -BeLike '*|*|*'
        }
    }

    Context 'when there are no flaky tests' {
        BeforeAll {
            $r2 = Import-JUnitResults -Path $script:JUnitRun2
            $merged = Merge-TestResults -Results @($r2)
            $script:markdownNoFlaky = New-MarkdownSummary -MergedResults $merged -FlakyTests @()
        }

        It 'indicates no flaky tests were found' {
            $script:markdownNoFlaky | Should -BeLike '*No flaky tests*'
        }
    }
}

# =============================================================================
# RED/GREEN CYCLE 6: Integration / End-to-End
# Verify the full pipeline works together
# =============================================================================
Describe 'End-to-End Integration' {
    Context 'when processing a mix of JUnit and JSON files' {
        BeforeAll {
            $script:summary = Invoke-TestResultsAggregator -Path $script:FixturesDir
        }

        It 'produces a markdown summary string' {
            $script:summary | Should -Not -BeNullOrEmpty
            $script:summary | Should -BeOfType [string]
        }

        It 'includes the summary header' {
            $script:summary | Should -BeLike '*# Test Results Summary*'
        }

        It 'identifies flaky tests in the output' {
            $script:summary | Should -BeLike '*Flaky Tests*'
        }
    }

    Context 'when given a directory with no test files' {
        BeforeAll {
            $script:emptyDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'empty-test-dir'
            if (-not (Test-Path -Path $script:emptyDir)) {
                New-Item -Path $script:emptyDir -ItemType Directory | Out-Null
            }
        }
        AfterAll {
            if (Test-Path -Path $script:emptyDir) {
                Remove-Item -Path $script:emptyDir -Force -Recurse
            }
        }

        It 'throws a meaningful error when no test files are found' {
            { Invoke-TestResultsAggregator -Path $script:emptyDir } |
                Should -Throw '*No test result files*'
        }
    }
}
