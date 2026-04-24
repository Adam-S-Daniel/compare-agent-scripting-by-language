# Pester tests for TestResultsAggregator module
# Uses Pester 5.x syntax

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot 'TestResultsAggregator.psm1'
    Import-Module $ModulePath -Force
    $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Read-JUnitXml' {
    It 'parses a JUnit XML file into test case objects' {
        $path = Join-Path $script:FixturesDir 'run1.xml'
        $result = Read-JUnitXml -Path $path
        $result.Cases.Count | Should -Be 4
        $result.Cases[0].Name | Should -Be 'test_login'
        $result.Cases[0].Status | Should -Be 'passed'
        $result.Cases[0].Duration | Should -Be 0.5
    }

    It 'recognizes failed tests' {
        $path = Join-Path $script:FixturesDir 'run1.xml'
        $result = Read-JUnitXml -Path $path
        $failed = $result.Cases | Where-Object { $_.Status -eq 'failed' }
        $failed.Count | Should -Be 1
        $failed[0].Name | Should -Be 'test_flaky'
    }

    It 'recognizes skipped tests' {
        $path = Join-Path $script:FixturesDir 'run1.xml'
        $result = Read-JUnitXml -Path $path
        $skipped = $result.Cases | Where-Object { $_.Status -eq 'skipped' }
        $skipped.Count | Should -Be 1
    }

    It 'throws a clear error when the file does not exist' {
        { Read-JUnitXml -Path '/nonexistent/path.xml' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Read-TestResultJson' {
    It 'parses a JSON test result file' {
        $path = Join-Path $script:FixturesDir 'run2.json'
        $result = Read-TestResultJson -Path $path
        $result.Cases.Count | Should -Be 4
        ($result.Cases | Where-Object Status -EQ 'passed').Count | Should -Be 3
    }

    It 'throws a clear error when the file does not exist' {
        { Read-TestResultJson -Path '/nope.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Import-TestResults' {
    It 'dispatches to JUnit parser for .xml files' {
        $path = Join-Path $script:FixturesDir 'run1.xml'
        $result = Import-TestResults -Path $path
        $result.Cases.Count | Should -Be 4
    }

    It 'dispatches to JSON parser for .json files' {
        $path = Join-Path $script:FixturesDir 'run2.json'
        $result = Import-TestResults -Path $path
        $result.Cases.Count | Should -Be 4
    }

    It 'throws for unknown extensions' {
        { Import-TestResults -Path '/tmp/x.txt' } |
            Should -Throw -ExpectedMessage '*Unsupported*'
    }
}

Describe 'Get-AggregatedResults' {
    It 'computes totals across multiple runs' {
        $xmlPath = Join-Path $script:FixturesDir 'run1.xml'
        $jsonPath = Join-Path $script:FixturesDir 'run2.json'
        $agg = Get-AggregatedResults -Paths @($xmlPath, $jsonPath)
        $agg.Totals.Passed | Should -Be 5
        $agg.Totals.Failed | Should -Be 1
        $agg.Totals.Skipped | Should -Be 2
        $agg.Totals.Total | Should -Be 8
        $agg.Totals.Duration | Should -BeGreaterThan 0
    }

    It 'identifies flaky tests (pass in one run, fail in another)' {
        $xmlPath = Join-Path $script:FixturesDir 'run1.xml'
        $jsonPath = Join-Path $script:FixturesDir 'run2.json'
        $agg = Get-AggregatedResults -Paths @($xmlPath, $jsonPath)
        $agg.Flaky.Count | Should -Be 1
        $agg.Flaky[0].Name | Should -Be 'test_flaky'
    }

    It 'does not mark consistently-passing tests as flaky' {
        $xmlPath = Join-Path $script:FixturesDir 'run1.xml'
        $jsonPath = Join-Path $script:FixturesDir 'run2.json'
        $agg = Get-AggregatedResults -Paths @($xmlPath, $jsonPath)
        $agg.Flaky.Name | Should -Not -Contain 'test_login'
    }
}

Describe 'Format-MarkdownSummary' {
    BeforeAll {
        $xmlPath = Join-Path $script:FixturesDir 'run1.xml'
        $jsonPath = Join-Path $script:FixturesDir 'run2.json'
        $script:Agg = Get-AggregatedResults -Paths @($xmlPath, $jsonPath)
        $script:Md = Format-MarkdownSummary -Aggregation $script:Agg
    }

    It 'contains a top-level heading' {
        $script:Md | Should -Match '^# '
    }

    It 'reports the passed count' {
        $script:Md | Should -Match 'Passed.*5'
    }

    It 'reports the failed count' {
        $script:Md | Should -Match 'Failed.*1'
    }

    It 'lists flaky tests' {
        $script:Md | Should -Match 'test_flaky'
        $script:Md | Should -Match '(?i)flaky'
    }

    It 'includes duration' {
        $script:Md | Should -Match '(?i)duration'
    }
}

Describe 'GitHub Actions workflow' {
    BeforeAll {
        $script:WfPath = Join-Path $PSScriptRoot '.github/workflows/test-results-aggregator.yml'
        $script:WfText = Get-Content $script:WfPath -Raw
    }

    It 'exists' {
        Test-Path $script:WfPath | Should -BeTrue
    }

    It 'declares push, pull_request, workflow_dispatch, schedule triggers' {
        $script:WfText | Should -Match '(?m)^on:'
        $script:WfText | Should -Match 'push:'
        $script:WfText | Should -Match 'pull_request:'
        $script:WfText | Should -Match 'workflow_dispatch:'
        $script:WfText | Should -Match 'schedule:'
    }

    It 'uses actions/checkout@v4' {
        $script:WfText | Should -Match 'actions/checkout@v4'
    }

    It 'references scripts that exist on disk' {
        $script:WfText | Should -Match 'aggregate\.ps1'
        Test-Path (Join-Path $PSScriptRoot 'aggregate.ps1') | Should -BeTrue
        $script:WfText | Should -Match 'TestResultsAggregator\.Tests\.ps1'
        Test-Path (Join-Path $PSScriptRoot 'TestResultsAggregator.Tests.ps1') | Should -BeTrue
    }

    It 'sets contents: read permissions' {
        $script:WfText | Should -Match 'contents:\s*read'
    }

    It 'passes actionlint' {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlint) {
            Set-ItResult -Skipped -Because 'actionlint not available'
            return
        }
        & actionlint $script:WfPath 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'aggregate.ps1 entry script' {
    It 'writes markdown to the output path' {
        $xmlPath = Join-Path $script:FixturesDir 'run1.xml'
        $jsonPath = Join-Path $script:FixturesDir 'run2.json'
        $outPath = Join-Path ([IO.Path]::GetTempPath()) "summary-$(Get-Random).md"
        try {
            & (Join-Path $PSScriptRoot 'aggregate.ps1') `
                -InputPaths @($xmlPath, $jsonPath) `
                -OutputPath $outPath | Out-Null
            Test-Path $outPath | Should -BeTrue
            (Get-Content $outPath -Raw) | Should -Match 'Passed'
        } finally {
            if (Test-Path $outPath) { Remove-Item $outPath -Force }
        }
    }
}
