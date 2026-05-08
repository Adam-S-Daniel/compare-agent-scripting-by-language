# Workflow structure and validation tests
# Checks YAML structure, file references, and actionlint compliance

BeforeAll {
    $workflowPath = "$PSScriptRoot/../.github/workflows/test-results-aggregator.yml"
    $workflowContent = Get-Content -Raw $workflowPath
}

Describe "Workflow Structure" {
    It "workflow file exists" {
        Test-Path $workflowPath | Should -Be $true
    }

    It "has push trigger" {
        $workflowContent | Should -Match "push"
    }

    It "has pull_request trigger" {
        $workflowContent | Should -Match "pull_request"
    }

    It "has workflow_dispatch trigger" {
        $workflowContent | Should -Match "workflow_dispatch"
    }

    It "has schedule trigger" {
        $workflowContent | Should -Match "schedule"
    }

    It "uses actions/checkout@v4" {
        $workflowContent | Should -Match "actions/checkout@v4"
    }

    It "uses shell: pwsh for run steps" {
        $workflowContent | Should -Match "shell: pwsh"
    }

    It "has run-tests job" {
        $workflowContent | Should -Match "run-tests"
    }

    It "has aggregate-results job" {
        $workflowContent | Should -Match "aggregate-results"
    }

    It "aggregate-results depends on run-tests" {
        $workflowContent | Should -Match "needs: run-tests"
    }

    It "references the main script correctly" {
        $scriptPath = "$PSScriptRoot/../Invoke-TestResultsAggregator.ps1"
        Test-Path $scriptPath | Should -Be $true
    }

    It "references the fixtures directory correctly" {
        $fixturesPath = "$PSScriptRoot/../fixtures"
        Test-Path $fixturesPath | Should -Be $true
    }

    It "references tests directory correctly" {
        $testsPath = "$PSScriptRoot/../tests"
        Test-Path $testsPath | Should -Be $true
    }

    It "passes actionlint validation" {
        $al = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $al) {
            Set-ItResult -Skipped -Because "actionlint not installed in this environment"
            return
        }
        $output = & actionlint $workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
        $output | Should -BeNullOrEmpty
    }
}
