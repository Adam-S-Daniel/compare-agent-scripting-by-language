# Pester tests for the TestResultsAggregator module.
# Uses TDD red/green: each Describe block targets one behavior of the module.

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'src' 'TestResultsAggregator.psm1'
    Import-Module $ModulePath -Force
    # Unit-test fixtures live under tests/fixtures so that the act harness can
    # freely replace the top-level fixtures/ directory per case without breaking
    # unit tests.
    $FixtureRoot = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Import-JUnitResults' {
    It 'parses a JUnit XML file into test result objects' {
        $file = Join-Path $FixtureRoot 'run1' 'pytest-junit.xml'
        $results = Import-JUnitResults -Path $file
        $results | Should -HaveCount 5
        ($results | Where-Object { $_.Name -eq 'test_add' }).Status | Should -Be 'passed'
        ($results | Where-Object { $_.Name -eq 'test_divide_by_zero' }).Status | Should -Be 'failed'
        ($results | Where-Object { $_.Name -eq 'test_skip_me' }).Status | Should -Be 'skipped'
    }

    It 'captures duration as a [double] in seconds' {
        $file = Join-Path $FixtureRoot 'run1' 'pytest-junit.xml'
        $results = Import-JUnitResults -Path $file
        $add = $results | Where-Object { $_.Name -eq 'test_add' }
        $add.Duration | Should -BeOfType [double]
        $add.Duration | Should -BeGreaterThan 0
    }

    It 'records SourceFile for traceability' {
        $file = Join-Path $FixtureRoot 'run1' 'pytest-junit.xml'
        $results = Import-JUnitResults -Path $file
        $results[0].SourceFile | Should -Be (Resolve-Path $file).Path
    }

    It 'throws a clear error when the file does not exist' {
        { Import-JUnitResults -Path 'does-not-exist.xml' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a clear error when the file is not valid XML' {
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value 'not xml <<<'
        try {
            { Import-JUnitResults -Path $tmp } |
                Should -Throw -ExpectedMessage '*JUnit*'
        } finally {
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Import-JsonResults' {
    It 'parses a JSON test report into test result objects' {
        $file = Join-Path $FixtureRoot 'run1' 'jest-results.json'
        $results = Import-JsonResults -Path $file
        $results | Should -HaveCount 3
        ($results | Where-Object { $_.Name -eq 'renders title' }).Status | Should -Be 'passed'
        ($results | Where-Object { $_.Name -eq 'handles click' }).Status | Should -Be 'failed'
    }

    It 'throws a clear error when the file does not exist' {
        { Import-JsonResults -Path 'nope.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Import-TestResults (dispatcher)' {
    It 'dispatches by extension: .xml -> JUnit, .json -> JSON' {
        $xml = Import-TestResults -Path (Join-Path $FixtureRoot 'run1' 'pytest-junit.xml')
        $json = Import-TestResults -Path (Join-Path $FixtureRoot 'run1' 'jest-results.json')
        $xml.Count | Should -Be 5
        $json.Count | Should -Be 3
    }

    It 'throws on unknown extension' {
        $tmp = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, '.txt')
        Set-Content -Path $tmp -Value 'hello'
        try {
            { Import-TestResults -Path $tmp } |
                Should -Throw -ExpectedMessage '*Unsupported*'
        } finally {
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Get-AggregatedResults' {
    It 'totals passed/failed/skipped across all runs' {
        $files = @(
            (Join-Path $FixtureRoot 'run1' 'pytest-junit.xml'),
            (Join-Path $FixtureRoot 'run1' 'jest-results.json'),
            (Join-Path $FixtureRoot 'run2' 'pytest-junit.xml'),
            (Join-Path $FixtureRoot 'run3' 'pytest-junit.xml')
        )
        $agg = Get-AggregatedResults -Paths $files
        $agg.Totals.Total    | Should -Be 15
        $agg.Totals.Passed   | Should -Be 10
        $agg.Totals.Failed   | Should -Be 3
        $agg.Totals.Skipped  | Should -Be 2
        $agg.Totals.Duration | Should -BeGreaterThan 0
        $agg.FileCount       | Should -Be 4
    }

    It 'identifies flaky tests (passed in some runs, failed in others)' {
        $files = @(
            (Join-Path $FixtureRoot 'run1' 'pytest-junit.xml'),
            (Join-Path $FixtureRoot 'run2' 'pytest-junit.xml'),
            (Join-Path $FixtureRoot 'run3' 'pytest-junit.xml')
        )
        $agg = Get-AggregatedResults -Paths $files
        $flaky = $agg.FlakyTests
        $flaky | Should -HaveCount 1
        $flaky[0].Name | Should -Be 'test_network'
        $flaky[0].PassCount | Should -Be 2
        $flaky[0].FailCount | Should -Be 1
    }
}

Describe 'Format-MarkdownSummary' {
    It 'produces a markdown summary with totals and flaky section' {
        $files = @(
            (Join-Path $FixtureRoot 'run1' 'pytest-junit.xml'),
            (Join-Path $FixtureRoot 'run2' 'pytest-junit.xml'),
            (Join-Path $FixtureRoot 'run3' 'pytest-junit.xml')
        )
        $agg = Get-AggregatedResults -Paths $files
        $md = Format-MarkdownSummary -Aggregate $agg
        $md | Should -Match '# Test Results'
        $md | Should -Match 'Passed'
        $md | Should -Match 'Failed'
        $md | Should -Match 'Flaky'
        $md | Should -Match 'test_network'
    }

    It 'reports no-flaky message when there are none' {
        $files = @(Join-Path $FixtureRoot 'run1' 'pytest-junit.xml')
        $agg = Get-AggregatedResults -Paths $files
        $md = Format-MarkdownSummary -Aggregate $agg
        $md | Should -Match 'No flaky tests detected'
    }
}
