# Pester 5 tests for the Test Results Aggregator
# TDD: these tests define expected behavior before implementation

BeforeAll {
    . "$PSScriptRoot/../src/Aggregate-TestResults.ps1"
    $script:FixturesPath = Join-Path $PSScriptRoot '..' 'fixtures'
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
}

Describe 'Import-JUnitResults' {
    Context 'with valid JUnit XML (run1)' {
        BeforeAll {
            $script:run1 = Import-JUnitResults -Path (Join-Path $script:FixturesPath 'junit-run1.xml')
        }

        It 'returns 5 tests' {
            $script:run1.Tests.Count | Should -Be 5
        }

        It 'returns suite name UnitTests' {
            $script:run1.Suite | Should -Be 'UnitTests'
        }

        It 'identifies 2 passed tests' {
            @($script:run1.Tests | Where-Object { $_.Status -eq 'passed' }).Count | Should -Be 2
        }

        It 'identifies 2 failed tests' {
            @($script:run1.Tests | Where-Object { $_.Status -eq 'failed' }).Count | Should -Be 2
        }

        It 'identifies 1 skipped test' {
            @($script:run1.Tests | Where-Object { $_.Status -eq 'skipped' }).Count | Should -Be 1
        }

        It 'captures failure message for test_api_response' {
            $test = $script:run1.Tests | Where-Object { $_.Name -eq 'test_api_response' }
            $test.Message | Should -Be 'Timeout connecting to API'
        }

        It 'captures duration for test_login as 1.2' {
            $test = $script:run1.Tests | Where-Object { $_.Name -eq 'test_login' }
            $test.Duration | Should -Be 1.2
        }
    }

    Context 'with valid JUnit XML (run2)' {
        BeforeAll {
            $script:run2 = Import-JUnitResults -Path (Join-Path $script:FixturesPath 'junit-run2.xml')
        }

        It 'returns 5 tests' {
            $script:run2.Tests.Count | Should -Be 5
        }

        It 'identifies 2 passed tests' {
            @($script:run2.Tests | Where-Object { $_.Status -eq 'passed' }).Count | Should -Be 2
        }

        It 'identifies 2 failed tests' {
            @($script:run2.Tests | Where-Object { $_.Status -eq 'failed' }).Count | Should -Be 2
        }
    }

    Context 'with missing file' {
        It 'throws a meaningful error' {
            { Import-JUnitResults -Path '/nonexistent/file.xml' } | Should -Throw '*does not exist*'
        }
    }
}

Describe 'Import-JsonResults' {
    Context 'with valid JSON (run1)' {
        BeforeAll {
            $script:jsonRun1 = Import-JsonResults -Path (Join-Path $script:FixturesPath 'results-run1.json')
        }

        It 'returns 3 tests' {
            $script:jsonRun1.Tests.Count | Should -Be 3
        }

        It 'returns suite name IntegrationTests' {
            $script:jsonRun1.Suite | Should -Be 'IntegrationTests'
        }

        It 'identifies 2 passed tests' {
            @($script:jsonRun1.Tests | Where-Object { $_.Status -eq 'passed' }).Count | Should -Be 2
        }

        It 'identifies 1 failed test' {
            @($script:jsonRun1.Tests | Where-Object { $_.Status -eq 'failed' }).Count | Should -Be 1
        }

        It 'captures failure message for test_endpoint_auth' {
            $test = $script:jsonRun1.Tests | Where-Object { $_.Name -eq 'test_endpoint_auth' }
            $test.Message | Should -Be '401 Unauthorized'
        }

        It 'captures duration for test_health_check as 0.8' {
            $test = $script:jsonRun1.Tests | Where-Object { $_.Name -eq 'test_health_check' }
            $test.Duration | Should -Be 0.8
        }
    }

    Context 'with valid JSON (run2)' {
        BeforeAll {
            $script:jsonRun2 = Import-JsonResults -Path (Join-Path $script:FixturesPath 'results-run2.json')
        }

        It 'returns 3 tests' {
            $script:jsonRun2.Tests.Count | Should -Be 3
        }

        It 'identifies 1 passed test' {
            @($script:jsonRun2.Tests | Where-Object { $_.Status -eq 'passed' }).Count | Should -Be 1
        }

        It 'identifies 2 failed tests' {
            @($script:jsonRun2.Tests | Where-Object { $_.Status -eq 'failed' }).Count | Should -Be 2
        }
    }

    Context 'with missing file' {
        It 'throws a meaningful error' {
            { Import-JsonResults -Path '/nonexistent/file.json' } | Should -Throw '*does not exist*'
        }
    }
}

Describe 'Merge-TestResults' {
    Context 'with all four fixture files' {
        BeforeAll {
            $jRun1 = Import-JUnitResults -Path (Join-Path $script:FixturesPath 'junit-run1.xml')
            $jRun2 = Import-JUnitResults -Path (Join-Path $script:FixturesPath 'junit-run2.xml')
            $jsonRun1 = Import-JsonResults -Path (Join-Path $script:FixturesPath 'results-run1.json')
            $jsonRun2 = Import-JsonResults -Path (Join-Path $script:FixturesPath 'results-run2.json')
            $script:summary = Merge-TestResults -Results @($jRun1, $jRun2, $jsonRun1, $jsonRun2)
        }

        It 'computes total test count of 16' {
            $script:summary.TotalTests | Should -Be 16
        }

        It 'computes 7 passed' {
            $script:summary.Passed | Should -Be 7
        }

        It 'computes 7 failed' {
            $script:summary.Failed | Should -Be 7
        }

        It 'computes 2 skipped' {
            $script:summary.Skipped | Should -Be 2
        }

        It 'computes total duration of 32.30' {
            $script:summary.Duration | Should -Be 32.30
        }
    }

    Context 'with empty results' {
        It 'returns zero totals' {
            $empty = Merge-TestResults -Results @()
            $empty.TotalTests | Should -Be 0
            $empty.Passed | Should -Be 0
            $empty.Failed | Should -Be 0
            $empty.Skipped | Should -Be 0
            $empty.Duration | Should -Be 0
        }
    }
}

Describe 'Get-FlakyTests' {
    Context 'with all four fixture files' {
        BeforeAll {
            $jRun1 = Import-JUnitResults -Path (Join-Path $script:FixturesPath 'junit-run1.xml')
            $jRun2 = Import-JUnitResults -Path (Join-Path $script:FixturesPath 'junit-run2.xml')
            $jsonRun1 = Import-JsonResults -Path (Join-Path $script:FixturesPath 'results-run1.json')
            $jsonRun2 = Import-JsonResults -Path (Join-Path $script:FixturesPath 'results-run2.json')
            $script:flaky = Get-FlakyTests -Results @($jRun1, $jRun2, $jsonRun1, $jsonRun2)
        }

        It 'finds exactly 3 flaky tests' {
            $script:flaky.Count | Should -Be 3
        }

        It 'identifies test_cache_invalidation as flaky' {
            $names = $script:flaky | ForEach-Object { $_.Name }
            $names | Should -Contain 'test_cache_invalidation'
        }

        It 'identifies test_data_sync as flaky' {
            $names = $script:flaky | ForEach-Object { $_.Name }
            $names | Should -Contain 'test_data_sync'
        }

        It 'identifies test_database_connection as flaky' {
            $names = $script:flaky | ForEach-Object { $_.Name }
            $names | Should -Contain 'test_database_connection'
        }

        It 'does not identify test_login as flaky' {
            $names = $script:flaky | ForEach-Object { $_.Name }
            $names | Should -Not -Contain 'test_login'
        }

        It 'does not identify test_api_response as flaky' {
            $names = $script:flaky | ForEach-Object { $_.Name }
            $names | Should -Not -Contain 'test_api_response'
        }
    }
}

Describe 'Get-FailedTestDetails' {
    Context 'with all four fixture files' {
        BeforeAll {
            $jRun1 = Import-JUnitResults -Path (Join-Path $script:FixturesPath 'junit-run1.xml')
            $jRun2 = Import-JUnitResults -Path (Join-Path $script:FixturesPath 'junit-run2.xml')
            $jsonRun1 = Import-JsonResults -Path (Join-Path $script:FixturesPath 'results-run1.json')
            $jsonRun2 = Import-JsonResults -Path (Join-Path $script:FixturesPath 'results-run2.json')
            $script:failedDetails = Get-FailedTestDetails -Results @($jRun1, $jRun2, $jsonRun1, $jsonRun2)
        }

        It 'finds 2 consistently failed tests' {
            $script:failedDetails.Count | Should -Be 2
        }

        It 'includes test_api_response' {
            $names = $script:failedDetails | ForEach-Object { $_.Name }
            $names | Should -Contain 'test_api_response'
        }

        It 'includes test_endpoint_auth' {
            $names = $script:failedDetails | ForEach-Object { $_.Name }
            $names | Should -Contain 'test_endpoint_auth'
        }

        It 'excludes flaky test_database_connection' {
            $names = $script:failedDetails | ForEach-Object { $_.Name }
            $names | Should -Not -Contain 'test_database_connection'
        }
    }
}

Describe 'Export-MarkdownSummary' {
    Context 'with aggregated results from all fixtures' {
        BeforeAll {
            $jRun1 = Import-JUnitResults -Path (Join-Path $script:FixturesPath 'junit-run1.xml')
            $jRun2 = Import-JUnitResults -Path (Join-Path $script:FixturesPath 'junit-run2.xml')
            $jsonRun1 = Import-JsonResults -Path (Join-Path $script:FixturesPath 'results-run1.json')
            $jsonRun2 = Import-JsonResults -Path (Join-Path $script:FixturesPath 'results-run2.json')
            $summary = Merge-TestResults -Results @($jRun1, $jRun2, $jsonRun1, $jsonRun2)
            $script:markdown = Export-MarkdownSummary -Summary $summary
        }

        It 'contains the header' {
            $script:markdown | Should -Match '# Test Results Summary'
        }

        It 'contains Passed count of 7' {
            $script:markdown | Should -Match '\|\s*Passed\s*\|\s*7\s*\|'
        }

        It 'contains Failed count of 7' {
            $script:markdown | Should -Match '\|\s*Failed\s*\|\s*7\s*\|'
        }

        It 'contains Skipped count of 2' {
            $script:markdown | Should -Match '\|\s*Skipped\s*\|\s*2\s*\|'
        }

        It 'contains Duration of 32.30s' {
            $script:markdown | Should -Match '\|\s*Duration\s*\|\s*32\.30s\s*\|'
        }

        It 'contains Flaky Tests section' {
            $script:markdown | Should -Match '## Flaky Tests'
        }

        It 'lists test_database_connection as flaky' {
            $script:markdown | Should -Match 'test_database_connection'
        }

        It 'lists test_cache_invalidation as flaky' {
            $script:markdown | Should -Match 'test_cache_invalidation'
        }

        It 'lists test_data_sync as flaky' {
            $script:markdown | Should -Match 'test_data_sync'
        }

        It 'contains Failed Tests section' {
            $script:markdown | Should -Match '## Failed Tests'
        }

        It 'lists test_api_response in failed details' {
            $script:markdown | Should -Match 'test_api_response.*Timeout connecting to API'
        }

        It 'lists test_endpoint_auth in failed details' {
            $script:markdown | Should -Match 'test_endpoint_auth.*401 Unauthorized'
        }
    }
}

Describe 'Workflow Structure' {
    BeforeAll {
        $script:workflowPath = Join-Path $script:RepoRoot '.github' 'workflows' 'test-results-aggregator.yml'
        $script:workflowContent = Get-Content -Path $script:workflowPath -Raw
    }

    It 'workflow file exists' {
        Test-Path $script:workflowPath | Should -Be $true
    }

    It 'has push trigger' {
        $script:workflowContent | Should -Match 'push:'
    }

    It 'has pull_request trigger' {
        $script:workflowContent | Should -Match 'pull_request:'
    }

    It 'has workflow_dispatch trigger' {
        $script:workflowContent | Should -Match 'workflow_dispatch:'
    }

    It 'has jobs section' {
        $script:workflowContent | Should -Match 'jobs:'
    }

    It 'uses actions/checkout@v4' {
        $script:workflowContent | Should -Match 'actions/checkout@v4'
    }

    It 'references Aggregate-TestResults.ps1' {
        $script:workflowContent | Should -Match 'Aggregate-TestResults\.ps1'
    }

    It 'references tests directory' {
        $script:workflowContent | Should -Match './tests'
    }

    It 'script file exists at referenced path' {
        $scriptPath = Join-Path $script:RepoRoot 'src' 'Aggregate-TestResults.ps1'
        Test-Path $scriptPath | Should -Be $true
    }

    It 'passes actionlint validation' {
        $cmd = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $cmd) {
            Set-ItResult -Skipped -Because 'actionlint not installed'
            return
        }
        $output = & actionlint $script:workflowPath 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}
