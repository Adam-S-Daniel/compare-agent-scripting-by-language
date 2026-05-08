# Local-only structure tests for the workflow file. These do not invoke act;
# they validate that the YAML and the script paths it references are sane
# before the much-slower per-case act runs in Run-ActHarness.ps1.

BeforeAll {
    $script:repoRoot     = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    $script:workflowPath = Join-Path $repoRoot '.github/workflows/artifact-cleanup-script.yml'
}

Describe 'Workflow file presence' {
    It 'exists at .github/workflows/artifact-cleanup-script.yml' {
        Test-Path -LiteralPath $script:workflowPath | Should -BeTrue
    }
}

Describe 'Workflow YAML structure' {
    BeforeAll {
        # ConvertFrom-Yaml is not built in; use a raw text inspection that's
        # good enough for our structural assertions and survives without extra modules.
        $script:wf = Get-Content -LiteralPath $script:workflowPath -Raw
    }

    It 'declares all four trigger events (push, pull_request, schedule, workflow_dispatch)' {
        $script:wf | Should -Match '(?ms)^\s*push:'
        $script:wf | Should -Match '(?ms)^\s*pull_request:'
        $script:wf | Should -Match '(?ms)^\s*schedule:'
        $script:wf | Should -Match '(?ms)^\s*workflow_dispatch:'
    }

    It 'declares minimal contents:read permission' {
        $script:wf | Should -Match 'contents:\s*read'
    }

    It 'uses actions/checkout pinned to v4' {
        $script:wf | Should -Match 'uses:\s*actions/checkout@v4'
    }

    It 'invokes the entry script via Invoke-Cleanup.ps1' {
        $script:wf | Should -Match 'Invoke-Cleanup\.ps1'
    }

    It 'runs Pester via shell: pwsh, not pwsh -Command from bash' {
        $script:wf | Should -Match 'shell:\s*pwsh'
        $script:wf | Should -Not -Match 'pwsh\s+-Command'
    }
}

Describe 'Workflow references real files' {
    It 'references the entry script that actually exists on disk' {
        Test-Path -LiteralPath (Join-Path $script:repoRoot 'Invoke-Cleanup.ps1') | Should -BeTrue
    }
    It 'references the module that actually exists on disk' {
        Test-Path -LiteralPath (Join-Path $script:repoRoot 'ArtifactCleanup.psm1') | Should -BeTrue
    }
    It 'references the unit-test file that actually exists on disk' {
        Test-Path -LiteralPath (Join-Path $script:repoRoot 'tests/ArtifactCleanup.Tests.ps1') | Should -BeTrue
    }
}

Describe 'actionlint validation' {
    It 'passes actionlint with exit code 0' {
        $stdout = & actionlint $script:workflowPath 2>&1
        $code = $LASTEXITCODE
        if ($code -ne 0) { Write-Host ($stdout -join [Environment]::NewLine) }
        $code | Should -Be 0
    }
}
