# Pester tests that assert on the GitHub Actions workflow's structure
# (triggers, jobs, step references). These run inside the same act
# container as the unit tests, so the harness validates them through
# the pipeline rather than locally.
#
# Implementation note: we deliberately avoid pulling in `powershell-yaml`
# because act containers may not have network access to PSGallery. The
# workflow file is small enough that targeted regex assertions are both
# sufficient and cheaper than installing a module on every CI run.

BeforeAll {
    $script:RepoRoot     = Join-Path $PSScriptRoot '..'
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github' 'workflows' 'semantic-version-bumper.yml'
    $script:WorkflowText = if (Test-Path $script:WorkflowPath) { Get-Content -Raw $script:WorkflowPath } else { '' }
}

Describe 'workflow file presence' {
    It 'exists at the canonical path' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'is non-empty' {
        $script:WorkflowText.Length | Should -BeGreaterThan 0
    }
}

Describe 'workflow triggers' {
    It 'declares the push trigger' {
        $script:WorkflowText | Should -Match '(?m)^on:'
        $script:WorkflowText | Should -Match '(?m)^\s+push:'
    }
    It 'declares the pull_request trigger' {
        $script:WorkflowText | Should -Match '(?m)^\s+pull_request:'
    }
    It 'declares the workflow_dispatch trigger' {
        $script:WorkflowText | Should -Match '(?m)^\s+workflow_dispatch:'
    }
    It 'declares the schedule trigger' {
        $script:WorkflowText | Should -Match '(?m)^\s+schedule:'
    }
}

Describe 'workflow jobs' {
    It 'has a unit-tests job' {
        $script:WorkflowText | Should -Match '(?m)^\s+unit-tests:'
    }
    It 'has a bump-version job' {
        $script:WorkflowText | Should -Match '(?m)^\s+bump-version:'
    }
    It 'orders bump-version after unit-tests via needs' {
        $script:WorkflowText | Should -Match 'needs:\s*unit-tests'
    }
    It 'runs on ubuntu-latest' {
        $script:WorkflowText | Should -Match 'runs-on:\s*ubuntu-latest'
    }
    It 'uses pwsh as the default shell' {
        $script:WorkflowText | Should -Match 'shell:\s*pwsh'
    }
}

Describe 'workflow references existing scripts' {
    It 'references src/bump-version.ps1' {
        $script:WorkflowText | Should -Match 'src/bump-version\.ps1'
    }
    It 'src/bump-version.ps1 exists on disk' {
        Test-Path (Join-Path $script:RepoRoot 'src' 'bump-version.ps1') | Should -BeTrue
    }
    It 'src/SemverBumper.psm1 exists on disk' {
        Test-Path (Join-Path $script:RepoRoot 'src' 'SemverBumper.psm1') | Should -BeTrue
    }
    It 'tests/SemverBumper.Tests.ps1 exists on disk' {
        Test-Path (Join-Path $script:RepoRoot 'tests' 'SemverBumper.Tests.ps1') | Should -BeTrue
    }
}

Describe 'workflow security hygiene' {
    It 'declares an explicit permissions block' {
        $script:WorkflowText | Should -Match '(?m)^permissions:'
    }
    It 'pins contents to read' {
        $script:WorkflowText | Should -Match 'contents:\s*read'
    }
    It 'never references @main or @master on a uses: line' {
        $script:WorkflowText | Should -Not -Match 'uses:\s*\S+@main\b'
        $script:WorkflowText | Should -Not -Match 'uses:\s*\S+@master\b'
    }
}

Describe 'workflow checks out repo with full history' {
    It 'uses actions/checkout@v4' {
        $script:WorkflowText | Should -Match 'uses:\s*actions/checkout@v4'
    }
    It 'sets fetch-depth: 0 so git log can see every commit' {
        $script:WorkflowText | Should -Match 'fetch-depth:\s*0'
    }
}

Describe 'actionlint validation' {
    It 'passes actionlint cleanly' {
        # Skip when actionlint is not in PATH (e.g. inside the act container,
        # which is the unit-tests job's runtime). The harness runs actionlint
        # explicitly before invoking act, so coverage is preserved either way.
        $al = Get-Command -Name actionlint -ErrorAction SilentlyContinue
        if (-not $al) {
            Set-ItResult -Skipped -Because 'actionlint not present in this environment'
            return
        }
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}
