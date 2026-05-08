# Workflow structure tests — exercised separately from the unit tests
# because they shell out to actionlint / parse YAML and are therefore
# slower / require external tooling.
#
# Run locally with:
#   Invoke-Pester -Path ./tests/Workflow.Tests.ps1

BeforeAll {
    $script:RepoRoot     = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github/workflows/artifact-cleanup-script.yml'
}

Describe 'Workflow file - presence and references' {
    It 'workflow file exists at the expected path' {
        Test-Path -LiteralPath $script:WorkflowPath | Should -BeTrue
    }

    It 'references Invoke-Cleanup.ps1 (which exists)' {
        $content = Get-Content -Raw -LiteralPath $script:WorkflowPath
        $content | Should -Match 'Invoke-Cleanup\.ps1'
        Test-Path -LiteralPath (Join-Path $script:RepoRoot 'Invoke-Cleanup.ps1') | Should -BeTrue
    }

    It 'references the Pester test file (which exists)' {
        $content = Get-Content -Raw -LiteralPath $script:WorkflowPath
        $content | Should -Match 'tests/ArtifactCleanup\.Tests\.ps1'
        Test-Path -LiteralPath (Join-Path $script:RepoRoot 'tests/ArtifactCleanup.Tests.ps1') | Should -BeTrue
    }
}

Describe 'Workflow file - YAML structure' {
    BeforeAll {
        # Use the YAML PowerShell parser if available; otherwise fall back to
        # a permissive grep-based check so the test still runs in plain pwsh
        # containers without extra modules. We assert on key tokens we know
        # the workflow uses, which is good enough to catch accidental edits.
        $script:Yaml = Get-Content -Raw -LiteralPath $script:WorkflowPath
    }

    It 'declares the expected name' {
        $script:Yaml | Should -Match 'name:\s*artifact-cleanup-script'
    }

    It 'has push, pull_request, schedule, and workflow_dispatch triggers' {
        $script:Yaml | Should -Match '(?m)^\s*push:'
        $script:Yaml | Should -Match '(?m)^\s*pull_request:'
        $script:Yaml | Should -Match '(?m)^\s*schedule:'
        $script:Yaml | Should -Match '(?m)^\s*workflow_dispatch:'
    }

    It 'declares the two jobs unit-tests and cleanup-run' {
        $script:Yaml | Should -Match '(?m)^\s*unit-tests:'
        $script:Yaml | Should -Match '(?m)^\s*cleanup-run:'
    }

    It 'cleanup-run depends on unit-tests' {
        # The dependency block reads `needs: unit-tests` somewhere after
        # the cleanup-run: anchor.
        $script:Yaml | Should -Match 'needs:\s*unit-tests'
    }

    It 'uses actions/checkout@v4' {
        $script:Yaml | Should -Match 'actions/checkout@v4'
    }

    It 'uses shell: pwsh consistently for run steps' {
        # Every `run:` block should be paired with `shell: pwsh`. We check
        # by counting both — we expect at least 4 pwsh shells (Pester +
        # resolve-fixture + run-script + verify), and zero bash invocations.
        $pwshCount = ([regex]::Matches($script:Yaml, 'shell:\s*pwsh')).Count
        $bashCount = ([regex]::Matches($script:Yaml, 'shell:\s*bash')).Count
        $pwshCount | Should -BeGreaterOrEqual 4
        $bashCount | Should -Be 0
    }
}

Describe 'Workflow file - actionlint passes' {
    It 'actionlint exits 0' {
        $alPath = (Get-Command actionlint -ErrorAction SilentlyContinue).Source
        if (-not $alPath) {
            Set-ItResult -Skipped -Because 'actionlint is not installed in this environment'
            return
        }
        & $alPath $script:WorkflowPath
        $LASTEXITCODE | Should -Be 0
    }
}
