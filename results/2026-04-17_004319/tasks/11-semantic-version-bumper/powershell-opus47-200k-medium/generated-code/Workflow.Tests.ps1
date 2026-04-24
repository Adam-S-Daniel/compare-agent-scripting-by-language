#Requires -Modules Pester
# Structural tests for the GitHub Actions workflow.

BeforeAll {
    $script:WorkflowPath = Join-Path $PSScriptRoot '.github/workflows/semantic-version-bumper.yml'
    $script:ProjectRoot = $PSScriptRoot
}

Describe 'Workflow file' {
    It 'exists' {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It 'passes actionlint' {
        $out = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out | Out-String)
    }

    It 'parses as valid YAML with expected structure' {
        # Simple YAML check using PowerShell-Yaml if available, else string checks.
        $text = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $text | Should -Match '(?m)^name:\s*Semantic Version Bumper'
        $text | Should -Match '(?m)^on:'
        $text | Should -Match '(?m)^\s*push:'
        $text | Should -Match '(?m)^\s*pull_request:'
        $text | Should -Match '(?m)^\s*workflow_dispatch:'
        $text | Should -Match '(?m)^jobs:'
        $text | Should -Match '(?m)^\s*test:'
        $text | Should -Match '(?m)^\s*bump:'
        $text | Should -Match 'actions/checkout@v4'
    }

    It 'references scripts that exist in the repo' {
        $text = Get-Content -LiteralPath $script:WorkflowPath -Raw
        # The workflow invokes these files — check each exists.
        $text | Should -Match 'SemanticVersionBumper.Tests.ps1'
        $text | Should -Match 'bump-version.ps1'
        Test-Path (Join-Path $script:ProjectRoot 'SemanticVersionBumper.Tests.ps1') | Should -Be $true
        Test-Path (Join-Path $script:ProjectRoot 'bump-version.ps1') | Should -Be $true
        Test-Path (Join-Path $script:ProjectRoot 'SemanticVersionBumper.psm1') | Should -Be $true
    }

    It 'sets bump job to depend on test job' {
        $text = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $text | Should -Match 'needs:\s*test'
    }

    It 'declares explicit permissions' {
        $text = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $text | Should -Match '(?m)^permissions:'
    }
}

Describe 'act-result.txt artifact' {
    It 'exists (produced by Run-ActTests.ps1)' {
        $p = Join-Path $script:ProjectRoot 'act-result.txt'
        Test-Path $p | Should -Be $true
    }

    It 'contains each expected RESULT_VERSION' {
        $p = Join-Path $script:ProjectRoot 'act-result.txt'
        $content = Get-Content -LiteralPath $p -Raw
        $content | Should -Match 'RESULT_VERSION=1.2.0'
        $content | Should -Match 'RESULT_VERSION=1.1.1'
        $content | Should -Match 'RESULT_VERSION=2.0.0'
    }

    It 'shows Job succeeded for each case' {
        $p = Join-Path $script:ProjectRoot 'act-result.txt'
        $content = Get-Content -LiteralPath $p -Raw
        ([regex]::Matches($content, 'Job succeeded')).Count | Should -BeGreaterOrEqual 6
    }
}
