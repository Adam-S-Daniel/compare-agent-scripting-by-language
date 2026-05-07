# Workflow structure tests — verify the GitHub Actions workflow is well-formed
# *before* paying for an act run. These run alongside the unit tests and are
# fast (no Docker) so they fail loudly on regressions.

BeforeAll {
    $script:RepoRoot    = Split-Path $PSScriptRoot -Parent
    $script:WorkflowFile = Join-Path $script:RepoRoot '.github/workflows/secret-rotation-validator.yml'

    # Use ConvertFrom-Yaml if available (powershell-yaml module), otherwise
    # fall back to a tiny structural check via line scanning. We keep the
    # fallback so the test still works in clean Pester environments.
    function script:Read-WorkflowText {
        Get-Content -LiteralPath $script:WorkflowFile -Raw
    }
}

Describe 'GitHub Actions workflow file' {
    It 'exists at the expected path' {
        Test-Path -LiteralPath $script:WorkflowFile | Should -BeTrue
    }

    It 'declares the four expected triggers (push, pull_request, schedule, workflow_dispatch)' {
        $text = script:Read-WorkflowText
        $text | Should -Match '(?m)^\s*push:'
        $text | Should -Match '(?m)^\s*pull_request:'
        $text | Should -Match '(?m)^\s*schedule:'
        $text | Should -Match '(?m)^\s*workflow_dispatch:'
    }

    It 'sets read-only contents permission' {
        $text = script:Read-WorkflowText
        $text | Should -Match 'permissions:\s*\n\s*contents:\s*read'
    }

    It 'has both unit-tests and validate jobs with proper dependency' {
        $text = script:Read-WorkflowText
        $text | Should -Match 'unit-tests:'
        $text | Should -Match 'validate:'
        $text | Should -Match 'needs:\s*unit-tests'
    }

    It 'uses actions/checkout@v4' {
        $text = script:Read-WorkflowText
        ([regex]::Matches($text, 'actions/checkout@v4')).Count | Should -BeGreaterOrEqual 2
    }

    It 'uses shell: pwsh on every run step' {
        $text = script:Read-WorkflowText
        # All run-using steps in this workflow should opt into pwsh.
        $runSteps     = ([regex]::Matches($text, '(?m)^\s*run:')).Count
        $pwshSteps    = ([regex]::Matches($text, '(?m)^\s*shell:\s*pwsh\b')).Count
        $pwshSteps    | Should -Be $runSteps
    }

    It 'references the actual script and tests folder paths' {
        $text = script:Read-WorkflowText
        $text | Should -Match 'src/Invoke-SecretRotationValidator\.ps1'
        $text | Should -Match "Run\.Path\s*=\s*'tests'"

        Test-Path (Join-Path $script:RepoRoot 'src/Invoke-SecretRotationValidator.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'src/SecretRotation.psm1')                | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'tests')                                   | Should -BeTrue
    }

    It 'passes actionlint' {
        $actionlint = (Get-Command actionlint -ErrorAction SilentlyContinue)
        if (-not $actionlint) {
            Set-ItResult -Skipped -Because 'actionlint not installed in this environment'
            return
        }
        $output = & actionlint $script:WorkflowFile 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
