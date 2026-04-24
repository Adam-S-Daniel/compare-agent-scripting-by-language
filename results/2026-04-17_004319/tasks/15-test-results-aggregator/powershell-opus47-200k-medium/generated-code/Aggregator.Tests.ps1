# Pester tests for the Aggregator module.
# Written red/green TDD style: each Describe block covers one capability.

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot 'Aggregator.psm1'
    Import-Module $ModulePath -Force
    $FixturesRoot = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Import-JUnitResults' {
    It 'parses passed, failed, and skipped cases from JUnit XML' {
        $path = Join-Path $FixturesRoot 'run1/junit-suite-a.xml'
        $results = Import-JUnitResults -Path $path
        $results.Count | Should -Be 3
        ($results | Where-Object Status -EQ 'passed').Count  | Should -Be 1
        ($results | Where-Object Status -EQ 'failed').Count  | Should -Be 1
        ($results | Where-Object Status -EQ 'skipped').Count | Should -Be 1
    }

    It 'captures per-test duration' {
        $path = Join-Path $FixturesRoot 'run1/junit-suite-a.xml'
        $r = Import-JUnitResults -Path $path
        ($r | Measure-Object -Property Duration -Sum).Sum | Should -BeGreaterThan 0
    }

    It 'throws when the file is missing' {
        { Import-JUnitResults -Path 'does-not-exist.xml' } | Should -Throw
    }
}

Describe 'Import-JsonResults' {
    It 'parses passed/failed/skipped from JSON' {
        $path = Join-Path $FixturesRoot 'run1/results.json'
        $results = Import-JsonResults -Path $path
        $results.Count | Should -BeGreaterThan 0
        $results[0].PSObject.Properties.Name | Should -Contain 'Name'
        $results[0].PSObject.Properties.Name | Should -Contain 'Status'
    }

    It 'rejects JSON missing the tests array' {
        $tmp = New-TemporaryFile
        Set-Content -LiteralPath $tmp '{"other":1}'
        try {
            { Import-JsonResults -Path $tmp } | Should -Throw
        } finally { Remove-Item $tmp -Force }
    }
}

Describe 'Merge-TestResults' {
    It 'computes totals across runs' {
        $rs = @(
            [pscustomobject]@{Name='t1';Status='passed';Duration=0.1;Source='a'}
            [pscustomobject]@{Name='t2';Status='failed';Duration=0.2;Source='a'}
            [pscustomobject]@{Name='t3';Status='skipped';Duration=0.0;Source='a'}
        )
        $agg = Merge-TestResults -Results $rs
        $agg.Total   | Should -Be 3
        $agg.Passed  | Should -Be 1
        $agg.Failed  | Should -Be 1
        $agg.Skipped | Should -Be 1
        [math]::Abs($agg.Duration - 0.3) | Should -BeLessThan 0.0001
    }

    It 'flags a test as flaky when it passed in one run and failed in another' {
        $rs = @(
            [pscustomobject]@{Name='flaky1';Status='passed';Duration=0;Source='a'}
            [pscustomobject]@{Name='flaky1';Status='failed';Duration=0;Source='b'}
            [pscustomobject]@{Name='stable';Status='passed';Duration=0;Source='a'}
            [pscustomobject]@{Name='stable';Status='passed';Duration=0;Source='b'}
        )
        $agg = Merge-TestResults -Results $rs
        $agg.Flaky | Should -Contain 'flaky1'
        $agg.Flaky | Should -Not -Contain 'stable'
    }
}

Describe 'Format-MarkdownSummary' {
    It 'emits a markdown table with totals and a flaky section' {
        $rs = @(
            [pscustomobject]@{Name='t1';Status='passed';Duration=0.1;Source='a'}
            [pscustomobject]@{Name='t1';Status='failed';Duration=0.2;Source='b'}
        )
        $agg = Merge-TestResults -Results $rs
        $md = Format-MarkdownSummary -Aggregate $agg
        $md | Should -Match '# Test Results Summary'
        $md | Should -Match '\| Passed \| 1 \|'
        $md | Should -Match '\| Failed \| 1 \|'
        $md | Should -Match '## Flaky Tests'
        $md | Should -Match '- t1'
        $md | Should -Match 'FAILURE'
    }

    It 'reports SUCCESS when no failures are present' {
        $rs = @([pscustomobject]@{Name='ok';Status='passed';Duration=0;Source='a'})
        $md = Format-MarkdownSummary -Aggregate (Merge-TestResults -Results $rs)
        $md | Should -Match 'SUCCESS'
        $md | Should -Match '_None detected._'
    }
}

Describe 'Invoke-Aggregator (end-to-end)' {
    It 'aggregates the full fixture set and writes markdown' {
        $out = Join-Path ([IO.Path]::GetTempPath()) ("agg-" + [Guid]::NewGuid() + ".md")
        try {
            $agg = Invoke-Aggregator -InputPath $FixturesRoot -OutputPath $out
            Test-Path $out | Should -BeTrue
            $agg.Total | Should -BeGreaterThan 0
            (Get-Content $out -Raw) | Should -Match '# Test Results Summary'
        } finally {
            if (Test-Path $out) { Remove-Item $out -Force }
        }
    }

    It 'throws when the input path contains no fixtures' {
        $empty = Join-Path ([IO.Path]::GetTempPath()) ("empty-" + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $empty | Out-Null
        try {
            { Invoke-Aggregator -InputPath $empty -OutputPath (Join-Path $empty 'out.md') } |
                Should -Throw
        } finally { Remove-Item $empty -Recurse -Force }
    }
}
