# Workflow structure tests. These are fast static checks - they do NOT execute
# the workflow (that's the act harness's job). They verify that:
#   - the YAML is parseable and has the expected shape
#   - every script path referenced by the workflow exists on disk
#   - actionlint accepts the workflow
#
# Run with:  Invoke-Pester -Path ./WorkflowStructure.Tests.ps1

BeforeAll {
    $script:Root = $PSScriptRoot
    $script:WfPath = Join-Path $script:Root '.github/workflows/test-results-aggregator.yml'

    # We intentionally parse the YAML without a real YAML library: a small regex
    # pass extracts just what we need and keeps this test portable.
    $script:WfText = Get-Content -LiteralPath $script:WfPath -Raw
}

Describe 'Workflow file on disk' {
    It 'exists at .github/workflows/test-results-aggregator.yml' {
        Test-Path $script:WfPath | Should -BeTrue
    }
}

Describe 'Workflow triggers' {
    It 'triggers on push' { $script:WfText | Should -Match '(?m)^on:\s*$[\s\S]*?\bpush:' }
    It 'triggers on pull_request' { $script:WfText | Should -Match 'pull_request:' }
    It 'triggers on workflow_dispatch' { $script:WfText | Should -Match 'workflow_dispatch:' }
    It 'has a schedule block' { $script:WfText | Should -Match 'schedule:' }
}

Describe 'Workflow jobs' {
    It 'defines a pester-unit-tests job' {
        $script:WfText | Should -Match '(?m)^\s{2}pester-unit-tests:'
    }
    It 'defines an aggregate job that depends on pester-unit-tests' {
        $script:WfText | Should -Match '(?m)^\s{2}aggregate:'
        $script:WfText | Should -Match 'needs:\s*pester-unit-tests'
    }
    It 'uses ubuntu-latest runners' {
        ($script:WfText -split "`n" | Where-Object { $_ -match 'runs-on:\s*ubuntu-latest' }).Count |
            Should -BeGreaterOrEqual 2
    }
    It 'uses actions/checkout@v4' {
        $script:WfText | Should -Match 'actions/checkout@v4'
    }
    It 'uses shell: pwsh for run steps' {
        $script:WfText | Should -Match 'shell:\s*pwsh'
    }
}

Describe 'Referenced script paths exist' {
    It 'TestResultsAggregator.Tests.ps1 referenced by the workflow exists' {
        $script:WfText | Should -Match 'TestResultsAggregator\.Tests\.ps1'
        Test-Path (Join-Path $script:Root 'TestResultsAggregator.Tests.ps1') | Should -BeTrue
    }
    It 'Invoke-Aggregator.ps1 referenced by the workflow exists' {
        $script:WfText | Should -Match 'Invoke-Aggregator\.ps1'
        Test-Path (Join-Path $script:Root 'Invoke-Aggregator.ps1') | Should -BeTrue
    }
    It 'TestResultsAggregator.ps1 library exists (sourced by Invoke-Aggregator.ps1)' {
        Test-Path (Join-Path $script:Root 'TestResultsAggregator.ps1') | Should -BeTrue
    }
    It 'fixtures directory exists (Pester reference data) with at least one file' {
        $fx = Join-Path $script:Root 'fixtures'
        Test-Path $fx | Should -BeTrue
        @(Get-ChildItem $fx -File).Count | Should -BeGreaterThan 0
    }
    It 'input directory exists (default aggregator input) with at least one file' {
        $in = Join-Path $script:Root 'input'
        Test-Path $in | Should -BeTrue
        @(Get-ChildItem $in -File).Count | Should -BeGreaterThan 0
    }
}

Describe 'actionlint' {
    # actionlint isn't installed in the act container - skip there. The host
    # runs this test from the act harness and from local development, so the
    # check still happens before we ever invoke `act`.
    BeforeDiscovery {
        $script:ActionlintAvailable = [bool](Get-Command actionlint -ErrorAction SilentlyContinue)
    }
    It 'reports no issues for the workflow' -Skip:(-not $script:ActionlintAvailable) {
        $out = & actionlint $script:WfPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $out"
    }
}
