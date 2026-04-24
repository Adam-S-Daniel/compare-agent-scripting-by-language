# Pester v5 tests for the TestResultsAggregator module.
# These were written first (red), then the module was implemented (green).

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'TestResultsAggregator.psm1'
    Import-Module $script:ModulePath -Force

    $script:FixturesRoot = Join-Path $PSScriptRoot 'fixtures'
    $script:DefaultFixtures = Join-Path $script:FixturesRoot 'default'
    $script:AllPassingFixtures = Join-Path $script:FixturesRoot 'all-passing'
    $script:MultiFlakyFixtures = Join-Path $script:FixturesRoot 'multi-flaky'
}

Describe 'Import-JUnitXml' {
    It 'parses a testsuites document and returns passed/failed/skipped cases' {
        $path = Join-Path $script:DefaultFixtures 'run1-junit.xml'
        $run = Import-JUnitXml -Path $path

        $run.Format | Should -Be 'junit'
        $run.Tests.Count | Should -Be 3
        ($run.Tests | Where-Object Status -EQ 'passed').Count | Should -Be 2
        ($run.Tests | Where-Object Status -EQ 'failed').Count | Should -Be 1
    }

    It 'extracts test duration from the time attribute' {
        $path = Join-Path $script:DefaultFixtures 'run1-junit.xml'
        $run = Import-JUnitXml -Path $path
        $login = $run.Tests | Where-Object Name -EQ 'test_login' | Select-Object -First 1
        $login.Duration | Should -BeGreaterThan 0
    }

    It 'captures the failure message when present' {
        $path = Join-Path $script:DefaultFixtures 'run1-junit.xml'
        $run = Import-JUnitXml -Path $path
        $failed = $run.Tests | Where-Object Status -EQ 'failed' | Select-Object -First 1
        $failed.Message | Should -Not -BeNullOrEmpty
    }

    It 'throws a meaningful error when the file does not exist' {
        { Import-JUnitXml -Path (Join-Path $script:FixturesRoot 'does-not-exist.xml') } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Import-JsonResults' {
    It 'parses a JSON result file and returns normalized cases' {
        $path = Join-Path $script:DefaultFixtures 'run3-integration.json'
        $run = Import-JsonResults -Path $path

        $run.Format | Should -Be 'json'
        $run.Tests.Count | Should -Be 2
        ($run.Tests | Where-Object Status -EQ 'passed').Count | Should -Be 1
        ($run.Tests | Where-Object Status -EQ 'skipped').Count | Should -Be 1
    }

    It 'normalizes status values to lower case' {
        $path = Join-Path $script:DefaultFixtures 'run3-integration.json'
        $run = Import-JsonResults -Path $path
        foreach ($t in $run.Tests) {
            $t.Status | Should -Match '^(passed|failed|skipped)$'
        }
    }

    It 'throws on missing file' {
        { Import-JsonResults -Path (Join-Path $script:FixturesRoot 'missing.json') } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Import-TestResults (auto-detect)' {
    It 'picks JUnit parser for .xml' {
        $run = Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run1-junit.xml')
        $run.Format | Should -Be 'junit'
    }

    It 'picks JSON parser for .json' {
        $run = Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run3-integration.json')
        $run.Format | Should -Be 'json'
    }

    It 'throws for unsupported extensions' {
        $tmp = New-TemporaryFile
        Rename-Item $tmp "$($tmp.FullName).txt" -Force
        try {
            { Import-TestResults -Path "$($tmp.FullName).txt" } |
                Should -Throw -ExpectedMessage '*Unsupported*'
        }
        finally {
            Remove-Item -Force "$($tmp.FullName).txt" -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Merge-TestRuns' {
    It 'aggregates totals across multiple runs' {
        $runs = @(
            (Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run1-junit.xml')),
            (Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run2-junit.xml')),
            (Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run3-integration.json'))
        )
        $agg = Merge-TestRuns -Runs $runs

        $agg.TotalTests | Should -Be 8
        $agg.TotalPassed | Should -Be 4
        $agg.TotalFailed | Should -Be 3
        $agg.TotalSkipped | Should -Be 1
        $agg.TotalDuration | Should -BeGreaterThan 0
        $agg.Runs.Count | Should -Be 3
    }
}

Describe 'Find-FlakyTests' {
    It 'identifies a test that passes in one run and fails in another' {
        $runs = @(
            (Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run1-junit.xml')),
            (Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run2-junit.xml'))
        )
        $flaky = Find-FlakyTests -Runs $runs
        $flaky.Count | Should -Be 1
        $flaky[0].Name | Should -Be 'test_logout'
        $flaky[0].Statuses | Should -Contain 'passed'
        $flaky[0].Statuses | Should -Contain 'failed'
    }

    It 'does not flag tests that are always failing or always passing' {
        $runs = @(
            (Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run1-junit.xml')),
            (Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run2-junit.xml'))
        )
        $flaky = Find-FlakyTests -Runs $runs
        $flaky.Name | Should -Not -Contain 'test_checkout'
        $flaky.Name | Should -Not -Contain 'test_login'
    }

    It 'finds multiple flaky tests across three runs' {
        $runs = Get-ChildItem -Path $script:MultiFlakyFixtures -Include *.xml,*.json -File -Recurse |
            ForEach-Object { Import-TestResults -Path $_.FullName }
        $flaky = Find-FlakyTests -Runs $runs
        $flaky.Count | Should -Be 2
    }
}

Describe 'Format-GitHubSummary' {
    It 'produces markdown with totals and flaky test sections' {
        $runs = @(
            (Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run1-junit.xml')),
            (Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run2-junit.xml')),
            (Import-TestResults -Path (Join-Path $script:DefaultFixtures 'run3-integration.json'))
        )
        $agg = Merge-TestRuns -Runs $runs
        $md = Format-GitHubSummary -Aggregate $agg

        $md | Should -Match '# Test Results Summary'
        $md | Should -Match '## Totals'
        $md | Should -Match '## Flaky tests'
        $md | Should -Match '## Per-run breakdown'
        $md | Should -Match 'test_logout'
    }

    It 'reports "No flaky tests detected" when no flakiness is present' {
        $runs = @(
            (Import-TestResults -Path (Join-Path $script:AllPassingFixtures 'suite.json'))
        )
        $agg = Merge-TestRuns -Runs $runs
        $md = Format-GitHubSummary -Aggregate $agg

        $md | Should -Match 'No flaky tests detected'
    }
}
