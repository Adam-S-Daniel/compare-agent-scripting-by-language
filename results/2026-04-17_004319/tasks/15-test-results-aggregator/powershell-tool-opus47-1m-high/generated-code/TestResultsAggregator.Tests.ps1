# Pester tests for TestResultsAggregator.ps1
# TDD: each Describe block represents an iteration. Tests were written first,
# then the minimum code to satisfy them was added to TestResultsAggregator.ps1.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'TestResultsAggregator.ps1'
    . $script:ModulePath
    $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Read-JUnitXmlResult' {
    It 'parses a simple JUnit XML file into test result objects' {
        $path = Join-Path $script:FixturesDir 'junit-run1.xml'
        $results = Read-JUnitXmlResult -Path $path
        $results | Should -Not -BeNullOrEmpty
        $results.Count | Should -Be 4
    }

    It 'captures name, classname, outcome, and duration' {
        $path = Join-Path $script:FixturesDir 'junit-run1.xml'
        $results = Read-JUnitXmlResult -Path $path
        $passed = $results | Where-Object { $_.Name -eq 'test_addition' }
        $passed.Outcome | Should -Be 'Passed'
        $passed.DurationSeconds | Should -Be 0.12
        $passed.ClassName | Should -Be 'suite.math'
    }

    It 'identifies failed tests' {
        $path = Join-Path $script:FixturesDir 'junit-run1.xml'
        $results = Read-JUnitXmlResult -Path $path
        $failed = $results | Where-Object { $_.Outcome -eq 'Failed' }
        $failed.Count | Should -Be 1
        $failed.Name | Should -Be 'test_division'
    }

    It 'identifies skipped tests' {
        $path = Join-Path $script:FixturesDir 'junit-run1.xml'
        $results = Read-JUnitXmlResult -Path $path
        $skipped = $results | Where-Object { $_.Outcome -eq 'Skipped' }
        $skipped.Count | Should -Be 1
        $skipped.Name | Should -Be 'test_pending'
    }

    It 'throws a descriptive error if the path does not exist' {
        { Read-JUnitXmlResult -Path '/no/such/file.xml' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws if the XML is malformed' {
        $bad = New-TemporaryFile
        Set-Content -Path $bad -Value '<not-valid-xml' -NoNewline
        try {
            { Read-JUnitXmlResult -Path $bad } | Should -Throw -ExpectedMessage '*XML*'
        } finally {
            Remove-Item $bad -Force
        }
    }
}

Describe 'Read-JsonResult' {
    It 'parses a JSON test-result file into test result objects' {
        $path = Join-Path $script:FixturesDir 'json-run1.json'
        $results = Read-JsonResult -Path $path
        $results.Count | Should -Be 3
    }

    It 'normalises outcomes to Passed / Failed / Skipped regardless of casing' {
        $path = Join-Path $script:FixturesDir 'json-run1.json'
        $results = Read-JsonResult -Path $path
        ($results | Where-Object { $_.Outcome -eq 'Passed' }).Count | Should -Be 2
        ($results | Where-Object { $_.Outcome -eq 'Failed' }).Count | Should -Be 1
    }

    It 'throws if the path does not exist' {
        { Read-JsonResult -Path '/no/such/file.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Read-TestResultFile (dispatch)' {
    It 'dispatches .xml files to the JUnit reader' {
        $path = Join-Path $script:FixturesDir 'junit-run1.xml'
        (Read-TestResultFile -Path $path).Count | Should -Be 4
    }

    It 'dispatches .json files to the JSON reader' {
        $path = Join-Path $script:FixturesDir 'json-run1.json'
        (Read-TestResultFile -Path $path).Count | Should -Be 3
    }

    It 'rejects unknown extensions' {
        $tmp = New-TemporaryFile
        try {
            { Read-TestResultFile -Path $tmp } | Should -Throw -ExpectedMessage '*Unsupported*'
        } finally {
            Remove-Item $tmp -Force
        }
    }
}

Describe 'Get-AggregatedResult' {
    It 'totals passed / failed / skipped / duration across multiple files' {
        $files = @(
            (Join-Path $script:FixturesDir 'junit-run1.xml'),
            (Join-Path $script:FixturesDir 'junit-run2.xml'),
            (Join-Path $script:FixturesDir 'json-run1.json')
        )
        $agg = Get-AggregatedResult -Paths $files
        $agg.Total | Should -Be 11        # 4 + 4 + 3
        $agg.Passed | Should -Be 7
        $agg.Failed | Should -Be 2
        $agg.Skipped | Should -Be 2
        # Durations sum: junit-run1 (0.12+0.08+0.05+0) + junit-run2 (0.11+0.09+0.05+0) + json-run1 (0.2+0.3+0.4)
        [math]::Round($agg.DurationSeconds, 2) | Should -Be 1.40
    }

    It 'tracks per-run results so flakiness can be calculated' {
        $files = @(
            (Join-Path $script:FixturesDir 'junit-run1.xml'),
            (Join-Path $script:FixturesDir 'junit-run2.xml')
        )
        $agg = Get-AggregatedResult -Paths $files
        $agg.Runs.Count | Should -Be 2
    }
}

Describe 'Get-FlakyTest' {
    It 'identifies tests that passed in one run and failed in another' {
        $files = @(
            (Join-Path $script:FixturesDir 'junit-run1.xml'),
            (Join-Path $script:FixturesDir 'junit-run2.xml')
        )
        $agg = Get-AggregatedResult -Paths $files
        $flaky = Get-FlakyTest -Aggregated $agg
        # test_division: failed in run1, passed in run2 -> flaky
        # test_subtraction: passed in both -> not flaky
        $flaky.Count | Should -Be 1
        $flaky[0].Name | Should -Contain 'test_division'
    }

    It 'returns an empty array when no tests are flaky' {
        $files = @((Join-Path $script:FixturesDir 'junit-run1.xml'))  # single run
        $agg = Get-AggregatedResult -Paths $files
        $flaky = Get-FlakyTest -Aggregated $agg
        @($flaky).Count | Should -Be 0
    }
}

Describe 'Format-MarkdownSummary' {
    BeforeAll {
        $files = @(
            (Join-Path $script:FixturesDir 'junit-run1.xml'),
            (Join-Path $script:FixturesDir 'junit-run2.xml'),
            (Join-Path $script:FixturesDir 'json-run1.json')
        )
        $script:Agg = Get-AggregatedResult -Paths $files
        $script:Md = Format-MarkdownSummary -Aggregated $script:Agg
    }

    It 'starts with a top-level heading' {
        $script:Md | Should -Match '^# Test Results'
    }

    It 'contains a totals table with correct counts' {
        $script:Md | Should -Match '\|\s*Total\s*\|\s*11\s*\|'
        $script:Md | Should -Match '\|\s*Passed\s*\|\s*7\s*\|'
        $script:Md | Should -Match '\|\s*Failed\s*\|\s*2\s*\|'
        $script:Md | Should -Match '\|\s*Skipped\s*\|\s*2\s*\|'
    }

    It 'contains a "Flaky tests" section listing flaky test names' {
        $script:Md | Should -Match '## Flaky tests'
        $script:Md | Should -Match 'test_division'
    }

    It 'reports duration in seconds' {
        $script:Md | Should -Match 'Duration'
        $script:Md | Should -Match '1\.40'
    }

    It 'still renders a "no flaky tests" section when the list is empty' {
        $agg = Get-AggregatedResult -Paths @((Join-Path $script:FixturesDir 'junit-run1.xml'))
        $md = Format-MarkdownSummary -Aggregated $agg
        $md | Should -Match '## Flaky tests'
        $md | Should -Match 'None'
    }
}

Describe 'Invoke-TestResultsAggregator (entry point)' {
    It 'writes the markdown summary to the requested output path and returns the summary object' {
        $out = Join-Path ([IO.Path]::GetTempPath()) ("summary-" + [Guid]::NewGuid() + ".md")
        try {
            $files = @(
                (Join-Path $script:FixturesDir 'junit-run1.xml'),
                (Join-Path $script:FixturesDir 'junit-run2.xml')
            )
            $summary = Invoke-TestResultsAggregator -Paths $files -OutputPath $out
            Test-Path $out | Should -BeTrue
            (Get-Content $out -Raw) | Should -Match '# Test Results'
            $summary.Total | Should -Be 8
            $summary.Failed | Should -Be 1
        } finally {
            if (Test-Path $out) { Remove-Item $out -Force }
        }
    }
}
