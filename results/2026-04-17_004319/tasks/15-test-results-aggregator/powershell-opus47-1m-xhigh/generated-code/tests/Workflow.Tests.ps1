# Workflow structure tests — parse the YAML, check that the expected shape
# exists, all referenced script paths resolve, and actionlint passes.

BeforeAll {
    $script:Repo         = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:WorkflowPath = Join-Path $script:Repo '.github/workflows/test-results-aggregator.yml'
    $yaml = Get-Content -LiteralPath $script:WorkflowPath -Raw
    # Avoid adding a hard YAML-module dep; the structure test just greps for
    # known markers and uses simple indentation parsing.
    $script:YamlText = $yaml
}

Describe 'Workflow file structure' {
    It 'exists' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'declares the expected trigger events' {
        $script:YamlText | Should -Match '(?m)^on:'
        $script:YamlText | Should -Match '(?m)^\s+push:'
        $script:YamlText | Should -Match '(?m)^\s+pull_request:'
        $script:YamlText | Should -Match '(?m)^\s+workflow_dispatch:'
        $script:YamlText | Should -Match '(?m)^\s+schedule:'
    }

    It 'declares both the unit-tests and aggregate jobs' {
        $script:YamlText | Should -Match '(?m)^\s{2}unit-tests:'
        $script:YamlText | Should -Match '(?m)^\s{2}aggregate:'
    }

    It 'uses actions/checkout@v4 and actions/upload-artifact@v4' {
        $script:YamlText | Should -Match 'actions/checkout@v4'
        $script:YamlText | Should -Match 'actions/upload-artifact@v4'
    }

    It 'uses shell: pwsh for script steps' {
        $script:YamlText | Should -Match 'shell:\s+pwsh'
    }

    It 'sets least-privilege permissions (contents: read)' {
        $script:YamlText | Should -Match 'permissions:'
        $script:YamlText | Should -Match 'contents:\s+read'
    }

    It 'references the aggregator script' {
        $script:YamlText | Should -Match 'Aggregate-TestResults\.ps1'
        Test-Path (Join-Path $script:Repo 'Aggregate-TestResults.ps1') | Should -BeTrue
    }

    It 'references the Pester test file' {
        $script:YamlText | Should -Match 'tests/TestResultsAggregator\.Tests\.ps1'
        Test-Path (Join-Path $script:Repo 'tests/TestResultsAggregator.Tests.ps1') | Should -BeTrue
    }

    It 'has job dependency aggregate -> unit-tests' {
        $script:YamlText | Should -Match 'needs:\s+unit-tests'
    }
}

Describe 'actionlint validation' {
    It 'passes actionlint with exit code 0' {
        $out  = & actionlint $script:WorkflowPath 2>&1
        $code = $LASTEXITCODE
        if ($code -ne 0) { Write-Host ($out -join "`n") }
        $code | Should -Be 0
    }
}
