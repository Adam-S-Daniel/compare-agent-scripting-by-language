#requires -Module Pester
# Pester tests for TestResultsAggregator. Demonstrates red/green TDD:
# each Describe block was authored as a failing test before the corresponding
# function was implemented in TestResultsAggregator.psm1.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'TestResultsAggregator.psm1'
    Import-Module $script:ModulePath -Force
    # Pester tests always read from test-fixtures/, which is the canonical full set.
    # The fixtures/ dir is what the aggregator consumes at runtime and may vary
    # by CI test case.
    $script:FixturesDir = Join-Path $PSScriptRoot 'test-fixtures'
}

Describe 'ConvertFrom-JUnitXml' {
    It 'parses a JUnit XML file with passed, failed, and skipped tests' {
        $results = ConvertFrom-JUnitXml -Path (Join-Path $FixturesDir 'run1.xml')
        $results.Count | Should -Be 4
        ($results | Where-Object Status -EQ 'Passed').Count  | Should -Be 2
        ($results | Where-Object Status -EQ 'Failed').Count  | Should -Be 1
        ($results | Where-Object Status -EQ 'Skipped').Count | Should -Be 1
    }

    It 'records duration as a numeric value' {
        $results = ConvertFrom-JUnitXml -Path (Join-Path $FixturesDir 'run1.xml')
        $sum = ($results | Measure-Object -Property Duration -Sum).Sum
        $sum | Should -BeGreaterThan 0
    }

    It 'throws a meaningful error for a missing file' {
        { ConvertFrom-JUnitXml -Path 'no-such-file.xml' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'ConvertFrom-TestJson' {
    It 'parses a JSON test result file' {
        $results = ConvertFrom-TestJson -Path (Join-Path $FixturesDir 'run3.json')
        $results.Count | Should -BeGreaterThan 0
        $results[0].Status | Should -BeIn @('Passed','Failed','Skipped')
    }

    It 'throws when tests array is missing' {
        $tmp = New-TemporaryFile
        '{"foo":"bar"}' | Set-Content -LiteralPath $tmp.FullName
        try {
            { ConvertFrom-TestJson -Path $tmp.FullName } |
                Should -Throw -ExpectedMessage "*missing 'tests'*"
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }
}

Describe 'Get-AggregatedResults' {
    It 'sums totals across multiple runs' {
        $r1 = ConvertFrom-JUnitXml  -Path (Join-Path $FixturesDir 'run1.xml')
        $r2 = ConvertFrom-JUnitXml  -Path (Join-Path $FixturesDir 'run2.xml')
        $r3 = ConvertFrom-TestJson  -Path (Join-Path $FixturesDir 'run3.json')
        $agg = Get-AggregatedResults -Runs @(,$r1; ,$r2; ,$r3)
        $agg.RunCount    | Should -Be 3
        $agg.TotalTests  | Should -Be ($r1.Count + $r2.Count + $r3.Count)
        $agg.TotalPassed | Should -BeGreaterThan 0
    }

    It 'flags tests as flaky when they pass in some runs and fail in others' {
        # Test "AlphaTest" passes in run1, fails in run2 -> should be flagged flaky.
        $r1 = ConvertFrom-JUnitXml  -Path (Join-Path $FixturesDir 'run1.xml')
        $r2 = ConvertFrom-JUnitXml  -Path (Join-Path $FixturesDir 'run2.xml')
        $agg = Get-AggregatedResults -Runs @(,$r1; ,$r2)
        $flakyNames = $agg.FlakyTests | ForEach-Object { $_.Test }
        $flakyNames | Should -Contain 'core::AlphaTest'
    }

    It 'does not flag tests that consistently pass or consistently fail' {
        $r1 = ConvertFrom-JUnitXml -Path (Join-Path $FixturesDir 'run1.xml')
        $r2 = ConvertFrom-JUnitXml -Path (Join-Path $FixturesDir 'run2.xml')
        $agg = Get-AggregatedResults -Runs @(,$r1; ,$r2)
        $flakyNames = $agg.FlakyTests | ForEach-Object { $_.Test }
        # BetaTest passes in both runs -> not flaky.
        $flakyNames | Should -Not -Contain 'core::BetaTest'
    }
}

Describe 'New-MarkdownSummary' {
    It 'emits a markdown table with totals and a flaky tests section' {
        $r1 = ConvertFrom-JUnitXml -Path (Join-Path $FixturesDir 'run1.xml')
        $r2 = ConvertFrom-JUnitXml -Path (Join-Path $FixturesDir 'run2.xml')
        $agg = Get-AggregatedResults -Runs @(,$r1; ,$r2)
        $md = New-MarkdownSummary -Aggregated $agg
        $md | Should -Match '# Test Results Summary'
        $md | Should -Match '\| Passed \|'
        $md | Should -Match '## Flaky Tests'
        $md | Should -Match 'AlphaTest'
    }

    It 'reports "None detected." when no flaky tests exist' {
        $r = ConvertFrom-JUnitXml -Path (Join-Path $FixturesDir 'run1.xml')
        $agg = Get-AggregatedResults -Runs @(,$r)
        $md = New-MarkdownSummary -Aggregated $agg
        $md | Should -Match 'None detected\.'
    }
}

Describe 'Invoke-Aggregator (end-to-end)' {
    It 'aggregates all fixture files and writes markdown to disk' {
        $out = Join-Path ([System.IO.Path]::GetTempPath()) "summary-$([guid]::NewGuid()).md"
        try {
            $result = Invoke-Aggregator -InputDir $FixturesDir -OutputFile $out
            Test-Path $out | Should -BeTrue
            $result.Aggregated.RunCount | Should -BeGreaterThan 0
            (Get-Content $out -Raw) | Should -Match 'Test Results Summary'
        } finally {
            if (Test-Path $out) { Remove-Item $out -Force }
        }
    }
}
