# Pester tests for the GitHub Actions workflow itself.
# These tests verify the YAML's structure (triggers, jobs, steps), confirm
# that every script path it references actually exists on disk, and run
# `actionlint` to assert the workflow is syntactically valid.

BeforeAll {
    $script:Repo = Join-Path $PSScriptRoot '..'
    $script:WorkflowPath = Join-Path $script:Repo '.github' 'workflows' 'pr-label-assigner.yml'
    $script:WorkflowText = Get-Content -Raw -LiteralPath $script:WorkflowPath
}

Describe 'Workflow file presence and lint' {
    It 'workflow file exists' {
        Test-Path -LiteralPath $script:WorkflowPath | Should -BeTrue
    }

    It 'passes actionlint cleanly' {
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}

Describe 'Workflow YAML structure' {
    # We avoid importing a YAML parser (not preinstalled) and instead do
    # targeted line-based checks. These suffice for structural assertions:
    # the file is small and well-known, and we verify key tokens exist.

    It 'declares a workflow name' {
        $script:WorkflowText | Should -Match '(?m)^name:\s*PR Label Assigner\s*$'
    }

    It 'has push, pull_request, and workflow_dispatch triggers' {
        $script:WorkflowText | Should -Match '(?ms)^on:\s*\r?\n([\s\S]+?)(?=^[a-zA-Z])'
        $script:WorkflowText | Should -Match '(?m)^\s+push:'
        $script:WorkflowText | Should -Match '(?m)^\s+pull_request:'
        $script:WorkflowText | Should -Match '(?m)^\s+workflow_dispatch:'
    }

    It 'sets read-only contents permission' {
        $script:WorkflowText | Should -Match 'contents:\s*read'
    }

    It 'defines two jobs: test and label' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}test:'
        $script:WorkflowText | Should -Match '(?m)^\s{2}label:'
    }

    It 'label job depends on test job' {
        $script:WorkflowText | Should -Match 'needs:\s*test'
    }

    It 'uses actions/checkout@v4' {
        $script:WorkflowText | Should -Match 'uses:\s*actions/checkout@v4'
    }

    It 'uses pwsh shell for run steps' {
        $script:WorkflowText | Should -Match 'shell:\s*pwsh'
    }
}

Describe 'Workflow references existing script files' {
    It 'references Get-PrLabels.ps1 which exists on disk' {
        $script:WorkflowText | Should -Match 'Get-PrLabels\.ps1'
        Test-Path (Join-Path $script:Repo 'Get-PrLabels.ps1') | Should -BeTrue
    }

    It 'references the tests directory which exists' {
        $script:WorkflowText | Should -Match './tests'
        Test-Path (Join-Path $script:Repo 'tests') | Should -BeTrue
    }

    It 'references current-fixture/changed-files.txt input path' {
        $script:WorkflowText | Should -Match 'current-fixture/changed-files\.txt'
    }

    It 'references current-fixture/config.json input path' {
        $script:WorkflowText | Should -Match 'current-fixture/config\.json'
    }
}

Describe 'Workflow output markers used by the harness' {
    It 'emits ===PR_LABELS_BEGIN=== marker' {
        $script:WorkflowText | Should -Match '===PR_LABELS_BEGIN==='
    }
    It 'emits ===PR_LABELS_END=== marker' {
        $script:WorkflowText | Should -Match '===PR_LABELS_END==='
    }
}
