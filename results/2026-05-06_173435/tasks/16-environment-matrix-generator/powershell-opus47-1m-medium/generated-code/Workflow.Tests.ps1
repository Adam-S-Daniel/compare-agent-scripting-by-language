# Pester tests covering workflow structure and tool validation. These do not
# run `act` themselves; they ensure the workflow is well-formed before we burn
# time on a containerized run.
BeforeAll {
    $script:WorkflowPath = Join-Path $PSScriptRoot '.github/workflows/environment-matrix-generator.yml'
}

Describe 'Workflow file structure' {
    It 'workflow file exists' {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It 'declares push, pull_request, schedule, and workflow_dispatch triggers' {
        $content = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $content | Should -Match '(?m)^on:'
        $content | Should -Match '(?m)^\s+push:'
        $content | Should -Match '(?m)^\s+pull_request:'
        $content | Should -Match '(?m)^\s+schedule:'
        $content | Should -Match '(?m)^\s+workflow_dispatch:'
    }

    It 'uses actions/checkout@v4' {
        (Get-Content -LiteralPath $script:WorkflowPath -Raw) | Should -Match 'actions/checkout@v4'
    }

    It 'sets least-privilege permissions' {
        (Get-Content -LiteralPath $script:WorkflowPath -Raw) | Should -Match 'permissions:[\s\S]*?contents:\s*read'
    }

    It 'references the script files that exist on disk' {
        $content = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $content | Should -Match 'Generate-Matrix\.ps1'
        $content | Should -Match 'MatrixGenerator\.Tests\.ps1'
        Test-Path (Join-Path $PSScriptRoot 'Generate-Matrix.ps1') | Should -Be $true
        Test-Path (Join-Path $PSScriptRoot 'MatrixGenerator.psm1') | Should -Be $true
        Test-Path (Join-Path $PSScriptRoot 'MatrixGenerator.Tests.ps1') | Should -Be $true
    }

    It 'uses shell: pwsh on run steps' {
        $content = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $content | Should -Match 'shell:\s*pwsh'
    }
}

Describe 'actionlint validation' {
    It 'passes actionlint with exit code 0' {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlint) { Set-ItResult -Skipped -Because 'actionlint not installed' }
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}
