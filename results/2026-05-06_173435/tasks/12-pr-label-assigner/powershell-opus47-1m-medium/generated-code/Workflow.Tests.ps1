# Workflow-structure tests: parse the YAML, sanity-check it, run actionlint.
# Does NOT run act (that's done by the act harness).

BeforeAll {
    $script:repoRoot   = $PSScriptRoot
    $script:workflow   = Join-Path $repoRoot '.github/workflows/pr-label-assigner.yml'
    # Minimal YAML reader: we don't want a yaml-cpp dep, so just inspect text.
    $script:yamlText   = Get-Content -Raw $workflow
}

Describe 'Workflow file' {
    It 'exists' { Test-Path $workflow | Should -BeTrue }

    It 'declares the expected triggers' {
        $yamlText | Should -Match 'on:\s*\r?\n\s*push:'
        $yamlText | Should -Match 'pull_request:'
        $yamlText | Should -Match 'workflow_dispatch:'
    }

    It 'uses pinned actions/checkout@v4' {
        $yamlText | Should -Match 'actions/checkout@v4'
    }

    It 'invokes scripts whose paths exist on disk' {
        Test-Path (Join-Path $repoRoot 'PrLabelAssigner.ps1')      | Should -BeTrue
        Test-Path (Join-Path $repoRoot 'Run-Assigner.ps1')         | Should -BeTrue
        Test-Path (Join-Path $repoRoot 'PrLabelAssigner.Tests.ps1')| Should -BeTrue
        Test-Path (Join-Path $repoRoot 'fixtures/files.json')      | Should -BeTrue
        Test-Path (Join-Path $repoRoot 'fixtures/rules.json')      | Should -BeTrue
        $yamlText | Should -Match 'Run-Assigner\.ps1'
        $yamlText | Should -Match 'PrLabelAssigner\.Tests\.ps1'
    }

    It 'uses shell: pwsh on run steps' {
        $yamlText | Should -Match 'shell:\s*pwsh'
    }

    It 'passes actionlint' {
        $out = & actionlint $workflow 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
    }
}
