# Workflow-structure tests. These run as part of the Pester suite (and so
# execute inside act via the workflow itself). Their purpose is to fail
# loudly if the workflow drifts away from the structure the harness relies
# on (sentinels, script paths, triggers, etc.).
#
# YAML parsing in PowerShell is done by hand here because we cannot count on
# powershell-yaml being installed in the act container. The patterns below
# only need to be "good enough" to confirm structural intent.

BeforeAll {
    $script:RepoRoot     = Split-Path -Parent $PSScriptRoot
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github/workflows/pr-label-assigner.yml'
    $script:WorkflowText = Get-Content -LiteralPath $script:WorkflowPath -Raw
}

Describe 'Workflow file' {
    It 'exists at the canonical path' {
        Test-Path -LiteralPath $script:WorkflowPath | Should -BeTrue
    }

    It 'declares the expected triggers' {
        $script:WorkflowText | Should -Match '(?ms)^on:\s*\n.*push:'
        $script:WorkflowText | Should -Match '(?ms)^on:\s*\n.*pull_request:'
        $script:WorkflowText | Should -Match '(?ms)^on:\s*\n.*workflow_dispatch:'
    }

    It 'declares both expected jobs' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}test:'
        $script:WorkflowText | Should -Match '(?m)^\s{2}assign-labels:'
    }

    It 'gates label assignment on test job success' {
        $script:WorkflowText | Should -Match 'needs:\s*test'
    }

    It 'references the script source path that exists on disk' {
        $script:WorkflowText | Should -Match './src/Get-PRLabels.ps1'
        Test-Path -LiteralPath (Join-Path $script:RepoRoot 'src/Get-PRLabels.ps1') |
            Should -BeTrue
    }

    It 'references the tests directory that exists on disk' {
        $script:WorkflowText | Should -Match './tests'
        Test-Path -LiteralPath (Join-Path $script:RepoRoot 'tests') |
            Should -BeTrue
    }

    It 'uses pinned actions/checkout@v4' {
        $script:WorkflowText | Should -Match 'uses:\s*actions/checkout@v4'
    }

    It 'uses pwsh shell on every run step' {
        # Indent-tolerant: any "run:" key must be matched by an equally-
        # indented "shell: pwsh" sibling somewhere in the file.
        $runCount   = ([regex]::Matches($script:WorkflowText, '(?m)^\s+run:')).Count
        $shellCount = ([regex]::Matches($script:WorkflowText, '(?m)^\s+shell:\s*pwsh')).Count
        $shellCount | Should -Be $runCount
    }

    It 'emits the LABELS-JSON sentinels the harness scrapes' {
        $script:WorkflowText | Should -Match 'LABELS-JSON-BEGIN'
        $script:WorkflowText | Should -Match 'LABELS-JSON-END'
    }
}
