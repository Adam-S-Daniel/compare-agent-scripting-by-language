# Structural tests for the GitHub Actions workflow.
BeforeAll {
    $script:wfPath = "$PSScriptRoot/.github/workflows/secret-rotation-validator.yml"
    $script:raw = Get-Content -LiteralPath $script:wfPath -Raw
}

Describe 'Workflow file structure' {
    It 'exists' { Test-Path $script:wfPath | Should -BeTrue }

    It 'declares the expected triggers' {
        $script:raw | Should -Match '(?m)^on:'
        $script:raw | Should -Match 'push:'
        $script:raw | Should -Match 'pull_request:'
        $script:raw | Should -Match 'workflow_dispatch:'
        $script:raw | Should -Match 'schedule:'
    }

    It 'declares tests and validate jobs with a dependency' {
        $script:raw | Should -Match '(?ms)^\s*tests:'
        $script:raw | Should -Match '(?ms)^\s*validate:'
        $script:raw | Should -Match 'needs:\s*tests'
    }

    It 'uses actions/checkout@v4' {
        $script:raw | Should -Match 'actions/checkout@v4'
    }

    It 'references the project scripts that exist on disk' {
        $script:raw | Should -Match 'SecretRotationValidator\.Tests\.ps1'
        $script:raw | Should -Match 'Invoke-Validator\.ps1'
        Test-Path "$PSScriptRoot/SecretRotationValidator.Tests.ps1" | Should -BeTrue
        Test-Path "$PSScriptRoot/Invoke-Validator.ps1" | Should -BeTrue
        Test-Path "$PSScriptRoot/SecretRotationValidator.ps1" | Should -BeTrue
        Test-Path "$PSScriptRoot/fixtures/secrets.json" | Should -BeTrue
    }

    It 'sets minimal permissions' {
        $script:raw | Should -Match 'permissions:\s*\n\s*contents:\s*read'
    }
}

Describe 'actionlint' {
    It 'passes actionlint with exit code 0' {
        $null = & actionlint $script:wfPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
