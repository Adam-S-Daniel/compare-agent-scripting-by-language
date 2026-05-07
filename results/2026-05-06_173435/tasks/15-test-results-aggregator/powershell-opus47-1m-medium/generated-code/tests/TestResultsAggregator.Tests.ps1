# Pester tests for TestResultsAggregator. TDD style.
# Each Describe block was added by writing the failing test first,
# then the minimum implementation to pass.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'TestResultsAggregator.psm1'
    Import-Module $script:ModulePath -Force
    $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Read-JUnitTestResult' {
    It 'parses a JUnit XML file into structured test cases' {
        $path = Join-Path $script:FixturesDir 'junit-run1.xml'
        $cases = Read-JUnitTestResult -Path $path
        $cases.Count | Should -Be 4
        ($cases | Where-Object Name -eq 'test_login').Status | Should -Be 'Passed'
        ($cases | Where-Object Name -eq 'test_logout').Status | Should -Be 'Failed'
        ($cases | Where-Object Name -eq 'test_skipped_feature').Status | Should -Be 'Skipped'
        # Duration parsed to seconds (double)
        ($cases | Where-Object Name -eq 'test_login').DurationSeconds | Should -BeGreaterThan 0
    }

    It 'throws a meaningful error for a missing file' {
        { Read-JUnitTestResult -Path '/nonexistent/path.xml' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a meaningful error for a malformed XML file' {
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value '<not-valid-xml'
        try {
            { Read-JUnitTestResult -Path $tmp } |
                Should -Throw -ExpectedMessage '*XML*'
        } finally {
            Remove-Item $tmp -Force
        }
    }
}

Describe 'Read-JsonTestResult' {
    It 'parses a JSON test results file into structured test cases' {
        $path = Join-Path $script:FixturesDir 'results-run1.json'
        $cases = Read-JsonTestResult -Path $path
        $cases.Count | Should -BeGreaterThan 0
        $cases[0].PSObject.Properties.Name | Should -Contain 'Name'
        $cases[0].PSObject.Properties.Name | Should -Contain 'Status'
        $cases[0].PSObject.Properties.Name | Should -Contain 'DurationSeconds'
    }

    It 'throws for a missing file' {
        { Read-JsonTestResult -Path '/nonexistent/path.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Read-TestResultDirectory' {
    It 'auto-detects JUnit XML and JSON files in a directory and tags them with the run name' {
        $cases = Read-TestResultDirectory -Path $script:FixturesDir
        # Each case should carry the source file basename as RunName
        ($cases | Select-Object -ExpandProperty RunName -Unique).Count | Should -BeGreaterThan 1
    }
}

Describe 'Get-TestResultSummary' {
    It 'computes totals across all test cases' {
        $cases = @(
            [pscustomobject]@{ Name='a'; Status='Passed';  DurationSeconds=1.0; RunName='r1' }
            [pscustomobject]@{ Name='b'; Status='Failed';  DurationSeconds=2.0; RunName='r1' }
            [pscustomobject]@{ Name='c'; Status='Skipped'; DurationSeconds=0.0; RunName='r1' }
            [pscustomobject]@{ Name='d'; Status='Passed';  DurationSeconds=1.5; RunName='r2' }
        )
        $s = Get-TestResultSummary -Cases $cases
        $s.Total           | Should -Be 4
        $s.Passed          | Should -Be 2
        $s.Failed          | Should -Be 1
        $s.Skipped         | Should -Be 1
        $s.DurationSeconds | Should -Be 4.5
    }
}

Describe 'Find-FlakyTest' {
    It 'identifies tests that passed in some runs but failed in others' {
        $cases = @(
            [pscustomobject]@{ Name='stable_pass'; Status='Passed'; RunName='r1' }
            [pscustomobject]@{ Name='stable_pass'; Status='Passed'; RunName='r2' }
            [pscustomobject]@{ Name='flaky';       Status='Passed'; RunName='r1' }
            [pscustomobject]@{ Name='flaky';       Status='Failed'; RunName='r2' }
            [pscustomobject]@{ Name='always_fail'; Status='Failed'; RunName='r1' }
            [pscustomobject]@{ Name='always_fail'; Status='Failed'; RunName='r2' }
        )
        $flaky = Find-FlakyTest -Cases $cases
        $flaky.Count | Should -Be 1
        $flaky[0].Name | Should -Be 'flaky'
    }

    It 'returns an empty array if there are no flaky tests' {
        $cases = @(
            [pscustomobject]@{ Name='a'; Status='Passed'; RunName='r1' }
            [pscustomobject]@{ Name='a'; Status='Passed'; RunName='r2' }
        )
        $flaky = @(Find-FlakyTest -Cases $cases)
        $flaky.Count | Should -Be 0
    }
}

Describe 'Format-TestSummaryMarkdown' {
    It 'renders a markdown summary suitable for GitHub Actions' {
        $cases = @(
            [pscustomobject]@{ Name='a'; Status='Passed'; DurationSeconds=1.0; RunName='r1' }
            [pscustomobject]@{ Name='a'; Status='Failed'; DurationSeconds=1.1; RunName='r2' }
            [pscustomobject]@{ Name='b'; Status='Failed'; DurationSeconds=0.5; RunName='r1' }
        )
        $md = Format-TestSummaryMarkdown -Cases $cases
        $md | Should -Match '# Test Results'
        $md | Should -Match 'Passed'
        $md | Should -Match 'Failed'
        $md | Should -Match 'Flaky'
        $md | Should -Match '\| a \|'   # flaky test row
    }

    It 'shows a no-flaky-tests note when none are flaky' {
        $cases = @(
            [pscustomobject]@{ Name='a'; Status='Passed'; DurationSeconds=1.0; RunName='r1' }
        )
        $md = Format-TestSummaryMarkdown -Cases $cases
        $md | Should -Match 'No flaky tests'
    }
}

Describe 'Invoke-TestResultsAggregator (end-to-end)' {
    It 'aggregates a directory of fixtures and writes markdown to the output path' {
        $out = Join-Path ([System.IO.Path]::GetTempPath()) "summary-$([guid]::NewGuid()).md"
        try {
            Invoke-TestResultsAggregator -InputDirectory $script:FixturesDir -OutputPath $out | Out-Null
            Test-Path $out | Should -BeTrue
            $md = Get-Content $out -Raw
            $md | Should -Match '# Test Results'
            $md | Should -Match 'Total:'
        } finally {
            if (Test-Path $out) { Remove-Item $out -Force }
        }
    }
}
