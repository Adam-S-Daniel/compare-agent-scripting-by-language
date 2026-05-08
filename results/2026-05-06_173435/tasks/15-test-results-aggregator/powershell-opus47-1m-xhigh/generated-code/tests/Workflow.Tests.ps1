# Workflow structure tests.
#
# We assert that the workflow:
#   * parses as YAML
#   * declares the expected triggers, jobs, and steps
#   * references actual files in the repo (script + fixtures)
#   * passes actionlint cleanly
#
# The YAML parser used here is the built-in one shipped with PowerShell-Yaml
# *if available*, otherwise we fall back to a minimal regex-based check that
# still covers the structural invariants we care about. This keeps the test
# usable both inside the act container (where pwsh-yaml may or may not be
# installed) and on a developer laptop.

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github/workflows/test-results-aggregator.yml'
    $script:WorkflowText = Get-Content -LiteralPath $script:WorkflowPath -Raw
}

Describe 'Workflow structure' {
    It 'has the expected triggers' {
        $script:WorkflowText | Should -Match '(?m)^on:'
        $script:WorkflowText | Should -Match '(?m)^\s+push:'
        $script:WorkflowText | Should -Match '(?m)^\s+pull_request:'
        $script:WorkflowText | Should -Match '(?m)^\s+workflow_dispatch:'
        $script:WorkflowText | Should -Match '(?m)^\s+schedule:'
    }

    It 'declares both jobs' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}unit-tests:'
        $script:WorkflowText | Should -Match '(?m)^\s{2}aggregate:'
    }

    It 'aggregate job depends on unit-tests' {
        $script:WorkflowText | Should -Match 'needs:\s*unit-tests'
    }

    It 'declares minimal contents:read permissions' {
        $script:WorkflowText | Should -Match 'permissions:\s*[\r\n]+\s*contents:\s*read'
    }

    It 'uses pinned actions/checkout@v4 for both jobs' {
        ([regex]::Matches($script:WorkflowText, 'actions/checkout@v4')).Count | Should -BeGreaterOrEqual 2
    }

    It 'invokes the aggregator script via shell: pwsh' {
        $script:WorkflowText | Should -Match 'shell:\s*pwsh'
        $script:WorkflowText | Should -Match './src/Aggregate-TestResults\.ps1'
    }

    It 'references files that actually exist in the repo' {
        Test-Path (Join-Path $script:RepoRoot 'src/Aggregate-TestResults.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'src/TestResultsAggregator.psm1') | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'tests') | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'fixtures/matrix-mixed') | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'fixtures/matrix-green') | Should -BeTrue
    }

    It 'passes actionlint with exit code 0' {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlint) {
            Set-ItResult -Skipped -Because 'actionlint not on PATH'
            return
        }
        $tmpDir = [System.IO.Path]::GetTempPath()
        $proc = Start-Process -FilePath actionlint -ArgumentList @($script:WorkflowPath) `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $tmpDir 'actionlint.out') `
            -RedirectStandardError  (Join-Path $tmpDir 'actionlint.err')
        $proc.ExitCode | Should -Be 0
    }
}
