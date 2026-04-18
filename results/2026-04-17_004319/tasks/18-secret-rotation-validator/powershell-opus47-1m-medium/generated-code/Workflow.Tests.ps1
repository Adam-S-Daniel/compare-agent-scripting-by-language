# Workflow.Tests.ps1
# Structural tests for the GitHub Actions workflow file.

BeforeAll {
    $script:WorkflowPath = Join-Path $PSScriptRoot '.github/workflows/secret-rotation-validator.yml'
    $script:Raw = Get-Content -Raw -LiteralPath $WorkflowPath

    # Crude key checks via regex — keeps the test free of YAML deps.
    $script:Lines = Get-Content -LiteralPath $WorkflowPath
}

Describe 'Workflow file' {
    It 'exists' { Test-Path $WorkflowPath | Should -BeTrue }

    It 'declares the expected triggers' {
        $Raw | Should -Match '(?m)^on:'
        $Raw | Should -Match '(?m)^\s+push:'
        $Raw | Should -Match '(?m)^\s+pull_request:'
        $Raw | Should -Match '(?m)^\s+workflow_dispatch:'
        $Raw | Should -Match '(?m)^\s+schedule:'
    }

    It 'defines test and validate jobs with a needs dependency' {
        $Raw | Should -Match '(?m)^\s{2}test:'
        $Raw | Should -Match '(?m)^\s{2}validate:'
        $Raw | Should -Match 'needs:\s*test'
    }

    It 'uses actions/checkout@v4' { $Raw | Should -Match 'actions/checkout@v4' }
    It 'uses pwsh shell' { $Raw | Should -Match 'shell:\s*pwsh' }
    It 'declares read-only permissions' { $Raw | Should -Match '(?m)^permissions:\s*\r?\n\s+contents:\s*read' }

    It 'references files that exist on disk' {
        $Raw | Should -Match 'SecretRotation\.Tests\.ps1'
        $Raw | Should -Match 'Invoke-SecretRotation\.ps1'
        $Raw | Should -Match 'fixtures/secrets\.json'

        Test-Path (Join-Path $PSScriptRoot 'SecretRotation.Tests.ps1') | Should -BeTrue
        Test-Path (Join-Path $PSScriptRoot 'Invoke-SecretRotation.ps1') | Should -BeTrue
        Test-Path (Join-Path $PSScriptRoot 'fixtures/secrets.json')      | Should -BeTrue
    }

    It 'passes actionlint' {
        $proc = Start-Process -FilePath 'actionlint' -ArgumentList @($WorkflowPath) -NoNewWindow -PassThru -Wait `
                              -RedirectStandardOutput ([System.IO.Path]::GetTempFileName()) `
                              -RedirectStandardError  ([System.IO.Path]::GetTempFileName())
        $proc.ExitCode | Should -Be 0
    }
}
