# Workflow.Tests.ps1
#
# Static structural checks on the GitHub Actions workflow:
#   - File parses as YAML
#   - Triggers / jobs / steps look right
#   - Script paths referenced from the workflow actually exist on disk
#   - actionlint exits 0
#
# These are required by the task spec ("WORKFLOW STRUCTURE TESTS") and run as
# regular Pester tests via `Invoke-Pester ./Workflow.Tests.ps1`.

BeforeAll {
    $script:WorkflowPath = Join-Path $PSScriptRoot '.github/workflows/environment-matrix-generator.yml'
    $script:WorkflowText = Get-Content -Raw -LiteralPath $script:WorkflowPath
}

Describe 'Workflow file - existence and YAML parse' {

    It 'workflow file exists' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'parses as YAML via PowerShell-Yaml or python fallback' {
        # We don't take a hard dep on PowerShell-Yaml. Use python3 (always present in CI/dev)
        # to confirm the file is structurally valid YAML.
        $py = "import sys, yaml; yaml.safe_load(open(r'$($script:WorkflowPath)'))"
        & python3 -c $py
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'Workflow file - structure' {

    It 'declares push, pull_request, workflow_dispatch, and schedule triggers' {
        $script:WorkflowText | Should -Match 'push:'
        $script:WorkflowText | Should -Match 'pull_request:'
        $script:WorkflowText | Should -Match 'workflow_dispatch:'
        $script:WorkflowText | Should -Match 'schedule:'
    }

    It 'declares the unit-tests and generate-matrix jobs' {
        $script:WorkflowText | Should -Match '(?ms)^\s*unit-tests:'
        $script:WorkflowText | Should -Match '(?ms)^\s*generate-matrix:'
    }

    It 'generate-matrix depends on unit-tests' {
        # job dependency expressed via `needs: unit-tests`
        $script:WorkflowText | Should -Match 'needs:\s*unit-tests'
    }

    It 'pins actions/checkout to v4' {
        ([regex]::Matches($script:WorkflowText, 'actions/checkout@v4')).Count | Should -BeGreaterOrEqual 2
    }

    It 'uses shell: pwsh on run steps (PowerShell mode requirement)' {
        ([regex]::Matches($script:WorkflowText, 'shell:\s*pwsh')).Count | Should -BeGreaterOrEqual 2
    }

    It 'declares minimal contents:read permission' {
        $script:WorkflowText | Should -Match 'permissions:\s*\n\s*contents:\s*read'
    }
}

Describe 'Workflow file - script references resolve on disk' {
    # Every script path the workflow runs must actually exist, otherwise the
    # workflow is shipping a dead reference.

    It 'references MatrixGenerator.Tests.ps1 which exists' {
        $script:WorkflowText | Should -Match 'MatrixGenerator\.Tests\.ps1'
        Test-Path (Join-Path $PSScriptRoot 'MatrixGenerator.Tests.ps1') | Should -BeTrue
    }

    It 'references Generate-Matrix.ps1 which exists' {
        $script:WorkflowText | Should -Match 'Generate-Matrix\.ps1'
        Test-Path (Join-Path $PSScriptRoot 'Generate-Matrix.ps1') | Should -BeTrue
    }

    It 'references the fixtures/ directory which exists with at least one JSON file' {
        $script:WorkflowText | Should -Match 'fixtures'
        $fixtureDir = Join-Path $PSScriptRoot 'fixtures'
        Test-Path $fixtureDir | Should -BeTrue
        @(Get-ChildItem $fixtureDir -Filter *.json).Count | Should -BeGreaterThan 0
    }
}

Describe 'Workflow file - actionlint passes' {

    It 'actionlint reports zero issues' {
        & actionlint $script:WorkflowPath
        $LASTEXITCODE | Should -Be 0
    }
}
