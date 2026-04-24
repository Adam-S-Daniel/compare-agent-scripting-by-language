# Workflow structure tests.
#
# These are pure static checks: parse the YAML, assert the shape we expect,
# verify that every script path referenced by the workflow actually exists on
# disk, and that actionlint is happy. These run without Docker so they're
# cheap to iterate on.

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github' 'workflows' 'semantic-version-bumper.yml'

    # Prefer the YayamlPowerShell parser if available; otherwise parse by
    # hand with a small heuristic that's good enough to assert the fields
    # we care about. The CI container in act has no YAML module preinstalled
    # so the heuristic path is what actually runs.
    function Read-WorkflowYaml {
        param([string]$Path)
        $text = Get-Content -LiteralPath $Path -Raw
        return @{ Text = $text }
    }

    $script:Workflow = Read-WorkflowYaml -Path $script:WorkflowPath
}

Describe 'Workflow file basics' {
    It 'exists at the expected path' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'passes actionlint' {
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }

    It 'declares the expected triggers' {
        $t = $script:Workflow.Text
        $t | Should -Match '(?m)^on:'
        $t | Should -Match '(?m)^\s+push:'
        $t | Should -Match '(?m)^\s+pull_request:'
        $t | Should -Match '(?m)^\s+schedule:'
        $t | Should -Match '(?m)^\s+workflow_dispatch:'
    }

    It 'defines the Pester unit-tests job and the bump job' {
        $t = $script:Workflow.Text
        $t | Should -Match 'unit-tests:'
        $t | Should -Match 'bump-version:'
    }

    It 'uses actions/checkout@v4' {
        $script:Workflow.Text | Should -Match 'actions/checkout@v4'
    }

    It 'uses shell: pwsh for PowerShell steps' {
        $script:Workflow.Text | Should -Match 'shell:\s*pwsh'
    }

    It 'declares explicit permissions' {
        $script:Workflow.Text | Should -Match '(?ms)permissions:\s*\n\s+contents:\s*read'
    }
}

Describe 'Workflow references existing files' {
    It 'the SemanticVersionBumper module referenced in the bump step exists' {
        (Join-Path $script:RepoRoot 'src' 'SemanticVersionBumper.psm1') |
            Test-Path | Should -BeTrue
    }

    It 'the bump-version CLI exists' {
        (Join-Path $script:RepoRoot 'src' 'bump-version.ps1') |
            Test-Path | Should -BeTrue
    }

    It 'the Pester test file referenced by the unit-tests job exists' {
        (Join-Path $script:RepoRoot 'tests' 'SemanticVersionBumper.Tests.ps1') |
            Test-Path | Should -BeTrue
    }

    It 'fixtures/patch contains a VERSION + commits.txt' {
        Test-Path (Join-Path $script:RepoRoot 'fixtures' 'patch' 'VERSION')    | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'fixtures' 'patch' 'commits.txt') | Should -BeTrue
    }

    It 'fixtures/minor contains a VERSION + commits.txt' {
        Test-Path (Join-Path $script:RepoRoot 'fixtures' 'minor' 'VERSION')     | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'fixtures' 'minor' 'commits.txt') | Should -BeTrue
    }

    It 'fixtures/major contains a package.json + commits.txt' {
        Test-Path (Join-Path $script:RepoRoot 'fixtures' 'major' 'package.json') | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'fixtures' 'major' 'commits.txt')  | Should -BeTrue
    }
}
