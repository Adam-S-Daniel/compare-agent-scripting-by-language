#requires -Version 7.0
#requires -Modules @{ModuleName='Pester'; ModuleVersion='5.0.0'}

# Workflow structure tests:
#   - validates that the workflow YAML exists, parses cleanly, and has the
#     expected triggers/jobs/steps
#   - confirms that paths referenced by the workflow exist on disk
#   - runs `actionlint` and asserts it exits 0
# These tests are FAST (no docker / no act) and run before the act-based
# integration tests so we catch trivial workflow breakage early.

BeforeDiscovery {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:WorkflowPath = Join-Path $RepoRoot ".github/workflows/test-results-aggregator.yml"
}

Describe "Workflow YAML structure" {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:WorkflowPath = Join-Path $RepoRoot ".github/workflows/test-results-aggregator.yml"
    }

    It "workflow file exists" {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It "parses as valid YAML" {
        # Pipe the workflow into python's yaml.safe_load via stdin. PowerShell
        # has no heredoc; using `Get-Content | python3` keeps the assertion
        # tool-free aside from python3 (already required by the harness).
        $script = "import yaml,sys; yaml.safe_load(sys.stdin); print('OK')"
        $result = Get-Content $script:WorkflowPath -Raw | python3 -c $script
        $result.Trim() | Should -Be 'OK'
    }

    It "declares push, pull_request, and workflow_dispatch triggers" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match '(?ms)^on:.*push:'
        $content | Should -Match '(?ms)^on:.*pull_request:'
        $content | Should -Match '(?ms)^on:.*workflow_dispatch:'
    }

    It "uses actions/checkout@v4 (pinned major)" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match 'actions/checkout@v4'
    }

    It "references Invoke-Aggregator.ps1" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match 'Invoke-Aggregator\.ps1'
    }

    It "uses pwsh shell on aggregation step" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match 'shell:\s*pwsh'
    }

    It "Invoke-Aggregator.ps1 exists in repo" {
        Test-Path (Join-Path $script:RepoRoot "Invoke-Aggregator.ps1") | Should -BeTrue
    }

    It "Aggregator.psm1 exists in repo" {
        Test-Path (Join-Path $script:RepoRoot "Aggregator.psm1") | Should -BeTrue
    }
}

Describe "actionlint validation" {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:WorkflowPath = Join-Path $RepoRoot ".github/workflows/test-results-aggregator.yml"
    }

    It "actionlint passes with exit code 0" {
        $output = & actionlint $script:WorkflowPath 2>&1
        $exit = $LASTEXITCODE
        if ($exit -ne 0) {
            Write-Host "actionlint output:`n$output"
        }
        $exit | Should -Be 0
    }
}
