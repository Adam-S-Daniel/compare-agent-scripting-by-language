#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
Workflow structure tests.

Parses the workflow YAML and asserts the shape the harness depends on:
triggers, jobs, step references to script files, and that actionlint passes.
These run before we ever invoke `act`, because catching a structural bug now
is orders of magnitude faster than after spinning up a Docker container.
#>

BeforeAll {
    $script:Root         = Split-Path -Parent $PSScriptRoot
    $script:WorkflowPath = Join-Path $script:Root '.github/workflows/environment-matrix-generator.yml'
    $script:Workflow     = Get-Content -LiteralPath $script:WorkflowPath -Raw

    # Cheap hand-rolled YAML field extraction rather than introducing the
    # powershell-yaml module, which isn't installed by default. We only need
    # substring checks.
    function Find-YamlLine {
        param([string] $Pattern)
        ($script:Workflow -split "`n") | Where-Object { $_ -match $Pattern }
    }
}

Describe 'Workflow file presence' {
    It 'workflow file exists' {
        Test-Path -LiteralPath $script:WorkflowPath | Should -BeTrue
    }
}

Describe 'Workflow triggers' {
    It 'listens on push' {
        $script:Workflow | Should -Match '(?m)^\s*push:'
    }
    It 'listens on pull_request' {
        $script:Workflow | Should -Match '(?m)^\s*pull_request:'
    }
    It 'supports workflow_dispatch' {
        $script:Workflow | Should -Match '(?m)^\s*workflow_dispatch:'
    }
}

Describe 'Required jobs' {
    It 'defines the unit-test job' {
        $script:Workflow | Should -Match '(?m)^\s*test:\s*$'
    }
    It 'defines the generate job' {
        $script:Workflow | Should -Match '(?m)^\s*generate:\s*$'
    }
    It 'generate depends on test' {
        $script:Workflow | Should -Match 'needs:\s*test'
    }
}

Describe 'Action versions and refs' {
    It 'pins actions/checkout to v4' {
        $script:Workflow | Should -Match 'actions/checkout@v4'
    }
    It 'uses shell: pwsh for run steps (avoids bash escaping traps)' {
        $script:Workflow | Should -Match 'shell:\s*pwsh'
    }
}

Describe 'Script path references' {
    It 'references MatrixGenerator.psm1 which exists on disk' {
        $script:Workflow | Should -Match 'MatrixGenerator\.psm1'
        Test-Path -LiteralPath (Join-Path $script:Root 'MatrixGenerator.psm1') | Should -BeTrue
    }
    It 'references MatrixGenerator.Tests.ps1 which exists on disk' {
        $script:Workflow | Should -Match 'MatrixGenerator\.Tests\.ps1'
        Test-Path -LiteralPath (Join-Path $script:Root 'MatrixGenerator.Tests.ps1') | Should -BeTrue
    }
    It 'references the fixtures directory which exists on disk' {
        $script:Workflow | Should -Match 'fixtures'
        Test-Path -LiteralPath (Join-Path $script:Root 'fixtures') | Should -BeTrue
    }
}

Describe 'Permissions and concurrency hardening' {
    It 'sets permissions block (least privilege)' {
        $script:Workflow | Should -Match '(?m)^permissions:'
    }
    It 'declares contents: read permission' {
        $script:Workflow | Should -Match 'contents:\s*read'
    }
    It 'defines a concurrency group' {
        $script:Workflow | Should -Match '(?m)^concurrency:'
    }
}

Describe 'actionlint' {
    It 'passes actionlint with exit code 0' {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlint) {
            Set-ItResult -Skipped -Because 'actionlint not installed on this host'
            return
        }
        $out = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
    }
}
