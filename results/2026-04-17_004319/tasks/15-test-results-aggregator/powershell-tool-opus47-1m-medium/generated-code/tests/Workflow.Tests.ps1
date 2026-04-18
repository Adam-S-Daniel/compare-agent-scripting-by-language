# Structural tests for the GitHub Actions workflow.
# These exercise YAML parsing and referenced-file existence without spinning
# up Docker. actionlint is asserted only when it is available on PATH.

BeforeAll {
    $ProjectRoot  = Resolve-Path (Join-Path $PSScriptRoot '..')
    $WorkflowPath = Join-Path $ProjectRoot '.github' 'workflows' 'test-results-aggregator.yml'

    # Naive YAML-ish parse: good enough for structural keys since we control the file.
    # Use powershell-yaml only if installed; otherwise read as text for grep-style checks.
    $script:WorkflowText = Get-Content -LiteralPath $WorkflowPath -Raw
    $script:Yaml = $null
    if (Get-Module -ListAvailable -Name powershell-yaml) {
        Import-Module powershell-yaml
        $script:Yaml = ConvertFrom-Yaml $script:WorkflowText
    }
}

Describe 'Workflow file' {
    It 'exists' {
        Test-Path $WorkflowPath | Should -BeTrue
    }

    It 'declares the required trigger events' {
        $WorkflowText | Should -Match '(?m)^on:'
        $WorkflowText | Should -Match 'push:'
        $WorkflowText | Should -Match 'pull_request:'
        $WorkflowText | Should -Match 'workflow_dispatch:'
        $WorkflowText | Should -Match 'schedule:'
    }

    It 'uses actions/checkout@v4' {
        $WorkflowText | Should -Match 'actions/checkout@v4'
    }

    It 'declares permissions' {
        $WorkflowText | Should -Match '(?m)^permissions:'
    }

    It 'runs the aggregator script, which exists on disk' {
        $WorkflowText | Should -Match 'src/Aggregate-TestResults\.ps1'
        (Join-Path $ProjectRoot 'src' 'Aggregate-TestResults.ps1') | Should -Exist
        (Join-Path $ProjectRoot 'src' 'TestResultsAggregator.psm1') | Should -Exist
    }

    It 'uses shell: pwsh for run steps' {
        $WorkflowText | Should -Match 'shell:\s*pwsh'
    }

    It 'passes actionlint (when available)' {
        $al = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $al) {
            Set-ItResult -Skipped -Because 'actionlint not on PATH'
            return
        }
        $null = & actionlint $WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
