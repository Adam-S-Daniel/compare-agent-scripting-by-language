#Requires -Module Pester

# Workflow structure checks — implemented against raw YAML text instead of a
# YAML parser because powershell-yaml is not guaranteed available in every
# PowerShell environment we run in (e.g. minimal act containers).

BeforeAll {
    $script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github/workflows/environment-matrix-generator.yml'
    $script:WorkflowText = Get-Content -Path $script:WorkflowPath -Raw
}

Describe 'Workflow: file and metadata' {
    It 'exists at the expected path' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'declares a human-readable name' {
        $script:WorkflowText | Should -Match '(?m)^name:\s*Environment Matrix Generator'
    }
}

Describe 'Workflow: triggers' {
    It 'triggers on push' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}push:'
    }
    It 'triggers on pull_request' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}pull_request:'
    }
    It 'supports workflow_dispatch' {
        $script:WorkflowText | Should -Match 'workflow_dispatch:'
    }
    It 'has a scheduled trigger' {
        $script:WorkflowText | Should -Match 'schedule:'
        $script:WorkflowText | Should -Match "cron:\s*'"
    }
}

Describe 'Workflow: permissions and env' {
    It 'restricts permissions to read-only contents' {
        $script:WorkflowText | Should -Match 'permissions:'
        $script:WorkflowText | Should -Match 'contents:\s*read'
    }
    It 'sets FIXTURE_DIR environment variable' {
        $script:WorkflowText | Should -Match 'FIXTURE_DIR:'
    }
}

Describe 'Workflow: jobs' {
    It 'defines a unit-tests job' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}unit-tests:'
    }
    It 'defines a generate-matrix job that depends on unit-tests' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}generate-matrix:'
        $script:WorkflowText | Should -Match 'needs:\s*unit-tests'
    }
    It 'uses actions/checkout@v4' {
        $script:WorkflowText | Should -Match 'actions/checkout@v4'
    }
    It 'uses shell: pwsh for run steps' {
        $script:WorkflowText | Should -Match 'shell:\s*pwsh'
    }
    It 'runs on ubuntu-latest' {
        $script:WorkflowText | Should -Match 'runs-on:\s*ubuntu-latest'
    }
}

Describe 'Workflow: script references point at files that exist' {
    It 'references src/Invoke-MatrixGenerator.ps1' {
        $script:WorkflowText | Should -Match 'src/Invoke-MatrixGenerator\.ps1'
        Test-Path (Join-Path $script:RepoRoot 'src/Invoke-MatrixGenerator.ps1') | Should -BeTrue
    }
    It 'references the ./tests directory' {
        $script:WorkflowText | Should -Match "'\./tests'"
        Test-Path (Join-Path $script:RepoRoot 'tests') | Should -BeTrue
    }
    It 'the src/New-BuildMatrix.ps1 file exists' {
        Test-Path (Join-Path $script:RepoRoot 'src/New-BuildMatrix.ps1') | Should -BeTrue
    }
    It 'has at least one fixture in the FIXTURE_DIR' {
        @(Get-ChildItem (Join-Path $script:RepoRoot 'fixtures') -Filter '*.json').Count | Should -BeGreaterThan 0
    }
}

Describe 'Workflow: actionlint validation' {
    It 'passes actionlint cleanly' {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlint) {
            Set-ItResult -Skipped -Because 'actionlint is not installed in this environment'
            return
        }
        $output = & $actionlint.Path $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}
