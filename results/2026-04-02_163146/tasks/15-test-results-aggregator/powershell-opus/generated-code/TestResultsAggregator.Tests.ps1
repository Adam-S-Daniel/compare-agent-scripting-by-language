# TestResultsAggregator.Tests.ps1
# Pester tests for the TestResultsAggregator module.
# Following TDD: these tests are written FIRST, before implementation.

BeforeAll {
    # Import the module under test
    $modulePath = Join-Path $PSScriptRoot 'TestResultsAggregator.psm1'
    Import-Module $modulePath -Force

    # Resolve fixture paths relative to the test file
    $script:FixturesPath = Join-Path $PSScriptRoot 'fixtures'
}

# ============================================================
# RED phase: JUnit XML parsing tests
# ============================================================
Describe 'ConvertFrom-JUnitXml' {
    Context 'when parsing a valid JUnit XML file' {
        BeforeAll {
            $script:result = ConvertFrom-JUnitXml -Path (Join-Path $script:FixturesPath 'junit-run1.xml')
        }

        It 'returns a hashtable with source file info' {
            $script:result | Should -BeOfType [hashtable]
            $script:result.Source | Should -BeLike '*junit-run1.xml'
        }

        It 'extracts the correct total number of tests' {
            $script:result.TotalTests | Should -Be 5
        }

        It 'extracts the correct number of passed tests' {
            $script:result.Passed | Should -Be 3
        }

        It 'extracts the correct number of failed tests' {
            $script:result.Failed | Should -Be 1
        }

        It 'extracts the correct number of skipped tests' {
            $script:result.Skipped | Should -Be 1
        }

        It 'extracts the total duration' {
            $script:result.Duration | Should -BeGreaterThan 0
        }

        It 'contains individual test case details' {
            $script:result.Tests | Should -HaveCount 5
        }

        It 'includes test name, suite, status, and duration for each test' {
            $loginTest = $script:result.Tests | Where-Object { $_.Name -eq 'test_login_success' }
            $loginTest | Should -Not -BeNullOrEmpty
            $loginTest.Suite | Should -Be 'AuthTests'
            $loginTest.Status | Should -Be 'passed'
            $loginTest.Duration | Should -BeGreaterThan 0
        }

        It 'marks failed tests with status failed and includes error message' {
            $failedTest = $script:result.Tests | Where-Object { $_.Name -eq 'test_token_refresh' }
            $failedTest.Status | Should -Be 'failed'
            $failedTest.Error | Should -Not -BeNullOrEmpty
        }

        It 'marks skipped tests with status skipped' {
            $skippedTest = $script:result.Tests | Where-Object { $_.Name -eq 'test_delete_user' }
            $skippedTest.Status | Should -Be 'skipped'
        }
    }

    Context 'when the file does not exist' {
        It 'throws a meaningful error' {
            { ConvertFrom-JUnitXml -Path '/nonexistent/file.xml' } |
                Should -Throw '*does not exist*'
        }
    }

    Context 'when the file contains invalid XML' {
        BeforeAll {
            $script:badXmlPath = Join-Path $TestDrive 'bad.xml'
            'this is not xml <><>' | Set-Content $script:badXmlPath
        }

        It 'throws a meaningful error' {
            { ConvertFrom-JUnitXml -Path $script:badXmlPath } |
                Should -Throw '*Failed to parse*'
        }
    }
}

# ============================================================
# RED phase: JSON parsing tests
# ============================================================
Describe 'ConvertFrom-TestResultJson' {
    Context 'when parsing a valid JSON file' {
        BeforeAll {
            $script:result = ConvertFrom-TestResultJson -Path (Join-Path $script:FixturesPath 'results-run1.json')
        }

        It 'returns a hashtable with source file info' {
            $script:result | Should -BeOfType [hashtable]
            $script:result.Source | Should -BeLike '*results-run1.json'
        }

        It 'extracts the correct total number of tests' {
            $script:result.TotalTests | Should -Be 5
        }

        It 'extracts the correct number of passed tests' {
            $script:result.Passed | Should -Be 3
        }

        It 'extracts the correct number of failed tests' {
            $script:result.Failed | Should -Be 1
        }

        It 'extracts the correct number of skipped tests' {
            $script:result.Skipped | Should -Be 1
        }

        It 'extracts the total duration' {
            $script:result.Duration | Should -BeGreaterThan 0
        }

        It 'contains individual test case details' {
            $script:result.Tests | Should -HaveCount 5
        }

        It 'normalizes test data with name, suite, status, and duration' {
            $dbTest = $script:result.Tests | Where-Object { $_.Name -eq 'test_database_connection' }
            $dbTest | Should -Not -BeNullOrEmpty
            $dbTest.Suite | Should -Be 'DatabaseTests'
            $dbTest.Status | Should -Be 'passed'
            $dbTest.Duration | Should -BeGreaterThan 0
        }

        It 'includes error messages for failed tests' {
            $failedTest = $script:result.Tests | Where-Object { $_.Name -eq 'test_cache_invalidation' }
            $failedTest.Status | Should -Be 'failed'
            $failedTest.Error | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when the file does not exist' {
        It 'throws a meaningful error' {
            { ConvertFrom-TestResultJson -Path '/nonexistent/file.json' } |
                Should -Throw '*does not exist*'
        }
    }

    Context 'when the file contains invalid JSON' {
        BeforeAll {
            $script:badJsonPath = Join-Path $TestDrive 'bad.json'
            'not valid json {{{' | Set-Content $script:badJsonPath
        }

        It 'throws a meaningful error' {
            { ConvertFrom-TestResultJson -Path $script:badJsonPath } |
                Should -Throw '*Failed to parse*'
        }
    }
}

# ============================================================
# RED phase: Result aggregation tests
# ============================================================
Describe 'Merge-TestResults' {
    BeforeAll {
        # Parse all JUnit fixtures to build input data
        $script:run1 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixturesPath 'junit-run1.xml')
        $script:run2 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixturesPath 'junit-run2.xml')
        $script:run3 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixturesPath 'junit-run3.xml')
        $script:aggregated = Merge-TestResults -Results @($script:run1, $script:run2, $script:run3)
    }

    It 'returns a hashtable' {
        $script:aggregated | Should -BeOfType [hashtable]
    }

    It 'computes total tests across all runs' {
        # 5 tests * 3 runs = 15 total test executions
        $script:aggregated.TotalTests | Should -Be 15
    }

    It 'computes total passed across all runs' {
        # Run1: 3 passed, Run2: 4 passed, Run3: 3 passed = 10
        $script:aggregated.Passed | Should -Be 10
    }

    It 'computes total failed across all runs' {
        # Run1: 1 failed, Run2: 0 failed, Run3: 1 failed = 2
        $script:aggregated.Failed | Should -Be 2
    }

    It 'computes total skipped across all runs' {
        # 1 skipped per run = 3
        $script:aggregated.Skipped | Should -Be 3
    }

    It 'computes total duration across all runs' {
        # 12.345 + 14.5 + 11.8 = 38.645
        $script:aggregated.TotalDuration | Should -BeGreaterOrEqual 38.0
        $script:aggregated.TotalDuration | Should -BeLessOrEqual 39.0
    }

    It 'tracks the number of runs' {
        $script:aggregated.RunCount | Should -Be 3
    }

    It 'collects unique test names' {
        $script:aggregated.UniqueTests | Should -HaveCount 5
    }

    Context 'when mixing JSON and JUnit results' {
        BeforeAll {
            $script:jsonRun1 = ConvertFrom-TestResultJson -Path (Join-Path $script:FixturesPath 'results-run1.json')
            $script:jsonRun2 = ConvertFrom-TestResultJson -Path (Join-Path $script:FixturesPath 'results-run2.json')
            $script:mixed = Merge-TestResults -Results @($script:jsonRun1, $script:jsonRun2)
        }

        It 'aggregates JSON results correctly' {
            $script:mixed.TotalTests | Should -Be 10
            $script:mixed.RunCount | Should -Be 2
        }
    }
}

# ============================================================
# RED phase: Flaky test detection tests
# ============================================================
Describe 'Find-FlakyTests' {
    Context 'with JUnit results containing a flaky test' {
        BeforeAll {
            # test_token_refresh: failed in run1, passed in run2, failed in run3 => flaky
            $script:run1 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixturesPath 'junit-run1.xml')
            $script:run2 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixturesPath 'junit-run2.xml')
            $script:run3 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixturesPath 'junit-run3.xml')
            $script:flaky = Find-FlakyTests -Results @($script:run1, $script:run2, $script:run3)
        }

        It 'identifies test_token_refresh as flaky' {
            $script:flaky | Should -Not -BeNullOrEmpty
            $flakyNames = $script:flaky | ForEach-Object { $_.Name }
            $flakyNames | Should -Contain 'test_token_refresh'
        }

        It 'reports the pass and fail counts for flaky tests' {
            $tokenTest = $script:flaky | Where-Object { $_.Name -eq 'test_token_refresh' }
            $tokenTest.PassCount | Should -Be 1
            $tokenTest.FailCount | Should -Be 2
        }

        It 'does not mark consistently passing tests as flaky' {
            $flakyNames = $script:flaky | ForEach-Object { $_.Name }
            $flakyNames | Should -Not -Contain 'test_login_success'
        }

        It 'does not mark consistently skipped tests as flaky' {
            $flakyNames = $script:flaky | ForEach-Object { $_.Name }
            $flakyNames | Should -Not -Contain 'test_delete_user'
        }
    }

    Context 'with JSON results containing flaky tests' {
        BeforeAll {
            # test_cache_invalidation: failed in run1, passed in run2 => flaky
            # test_cache_hit_rate: passed in run1, failed in run2 => flaky
            $script:jsonRun1 = ConvertFrom-TestResultJson -Path (Join-Path $script:FixturesPath 'results-run1.json')
            $script:jsonRun2 = ConvertFrom-TestResultJson -Path (Join-Path $script:FixturesPath 'results-run2.json')
            $script:flaky = Find-FlakyTests -Results @($script:jsonRun1, $script:jsonRun2)
        }

        It 'identifies both flaky tests' {
            $script:flaky | Should -HaveCount 2
            $flakyNames = $script:flaky | ForEach-Object { $_.Name }
            $flakyNames | Should -Contain 'test_cache_invalidation'
            $flakyNames | Should -Contain 'test_cache_hit_rate'
        }
    }

    Context 'when no tests are flaky' {
        BeforeAll {
            # Two identical passing runs
            $script:stableResults = @(
                @{
                    Source = 'stable1'
                    TotalTests = 2
                    Passed = 2
                    Failed = 0
                    Skipped = 0
                    Duration = 1.0
                    Tests = @(
                        @{ Name = 'test_a'; Suite = 'S'; Status = 'passed'; Duration = 0.5; Error = $null },
                        @{ Name = 'test_b'; Suite = 'S'; Status = 'passed'; Duration = 0.5; Error = $null }
                    )
                },
                @{
                    Source = 'stable2'
                    TotalTests = 2
                    Passed = 2
                    Failed = 0
                    Skipped = 0
                    Duration = 1.0
                    Tests = @(
                        @{ Name = 'test_a'; Suite = 'S'; Status = 'passed'; Duration = 0.5; Error = $null },
                        @{ Name = 'test_b'; Suite = 'S'; Status = 'passed'; Duration = 0.5; Error = $null }
                    )
                }
            )
            $script:flaky = Find-FlakyTests -Results $script:stableResults
        }

        It 'returns an empty array' {
            $script:flaky | Should -HaveCount 0
        }
    }
}

# ============================================================
# RED phase: Markdown summary generation tests
# ============================================================
Describe 'ConvertTo-MarkdownSummary' {
    BeforeAll {
        $script:aggregated = @{
            TotalTests    = 15
            Passed        = 10
            Failed        = 2
            Skipped       = 3
            TotalDuration = 38.645
            RunCount      = 3
            UniqueTests   = @('test_login_success', 'test_login_failure', 'test_token_refresh', 'test_get_users', 'test_delete_user')
            Runs          = @(
                @{ Source = 'junit-run1.xml'; Passed = 3; Failed = 1; Skipped = 1; TotalTests = 5; Duration = 12.345 },
                @{ Source = 'junit-run2.xml'; Passed = 4; Failed = 0; Skipped = 1; TotalTests = 5; Duration = 14.500 },
                @{ Source = 'junit-run3.xml'; Passed = 3; Failed = 1; Skipped = 1; TotalTests = 5; Duration = 11.800 }
            )
        }
        $script:flakyTests = @(
            @{ Name = 'test_token_refresh'; Suite = 'AuthTests'; PassCount = 1; FailCount = 2; TotalRuns = 3 }
        )
        $script:markdown = ConvertTo-MarkdownSummary -AggregatedResults $script:aggregated -FlakyTests $script:flakyTests
    }

    It 'returns a non-empty string' {
        $script:markdown | Should -Not -BeNullOrEmpty
        $script:markdown | Should -BeOfType [string]
    }

    It 'includes a title header' {
        $script:markdown | Should -Match '# .*[Tt]est.*[Rr]esults'
    }

    It 'includes total passed count' {
        $script:markdown | Should -Match '10.*passed'
    }

    It 'includes total failed count' {
        $script:markdown | Should -Match '2.*failed'
    }

    It 'includes total skipped count' {
        $script:markdown | Should -Match '3.*skipped'
    }

    It 'includes the duration' {
        $script:markdown | Should -Match '38\.\d+.*s'
    }

    It 'includes a per-run breakdown' {
        $script:markdown | Should -Match 'junit-run1\.xml'
        $script:markdown | Should -Match 'junit-run2\.xml'
        $script:markdown | Should -Match 'junit-run3\.xml'
    }

    It 'includes a flaky tests section when flaky tests exist' {
        $script:markdown | Should -Match '[Ff]laky'
        $script:markdown | Should -Match 'test_token_refresh'
    }

    Context 'when there are no flaky tests' {
        BeforeAll {
            $script:markdownNoFlaky = ConvertTo-MarkdownSummary -AggregatedResults $script:aggregated -FlakyTests @()
        }

        It 'does not include a flaky tests warning section' {
            # Should not have a flaky section header, but may mention "0 flaky" or omit entirely
            $script:markdownNoFlaky | Should -Not -Match '⚠️.*[Ff]laky'
        }
    }

    Context 'when all tests pass' {
        BeforeAll {
            $script:allPassAggregated = @{
                TotalTests    = 6
                Passed        = 6
                Failed        = 0
                Skipped       = 0
                TotalDuration = 5.0
                RunCount      = 2
                UniqueTests   = @('test_a', 'test_b', 'test_c')
                Runs          = @(
                    @{ Source = 'run1.xml'; Passed = 3; Failed = 0; Skipped = 0; TotalTests = 3; Duration = 2.5 },
                    @{ Source = 'run2.xml'; Passed = 3; Failed = 0; Skipped = 0; TotalTests = 3; Duration = 2.5 }
                )
            }
            $script:markdownAllPass = ConvertTo-MarkdownSummary -AggregatedResults $script:allPassAggregated -FlakyTests @()
        }

        It 'includes a success indicator' {
            $script:markdownAllPass | Should -Match 'pass'
        }
    }
}
