# Workflow.Tests.ps1
#
# Workflow-structure assertions (separate from the unit tests, which are
# pure-PowerShell). These tests parse the YAML, sanity-check the workflow
# shape, run actionlint, and -- when present -- validate the act-result.txt
# produced by Run-ActTests.ps1.
#
# To keep dependencies light we parse the YAML by reading its lines; the
# whole file is small enough that grep-style asserts are fine here.

BeforeAll {
    $script:RepoRoot     = Split-Path -Parent $PSScriptRoot
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github' 'workflows' 'artifact-cleanup-script.yml'
    $script:WorkflowText = Get-Content $script:WorkflowPath -Raw
    $script:ResultPath   = Join-Path $script:RepoRoot 'act-result.txt'
}

Describe 'Workflow file structure' {
    It 'workflow file exists at the expected path' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'declares all four expected trigger events' {
        $script:WorkflowText | Should -Match 'on:'
        $script:WorkflowText | Should -Match '(?m)^\s+push:'
        $script:WorkflowText | Should -Match '(?m)^\s+pull_request:'
        $script:WorkflowText | Should -Match '(?m)^\s+schedule:'
        $script:WorkflowText | Should -Match '(?m)^\s+workflow_dispatch:'
    }

    It 'sets read-only contents permissions' {
        $script:WorkflowText | Should -Match 'permissions:\s*\n\s*contents:\s*read'
    }

    It 'defines unit-tests and cleanup-plan jobs and chains them with needs' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}unit-tests:'
        $script:WorkflowText | Should -Match '(?m)^\s{2}cleanup-plan:'
        $script:WorkflowText | Should -Match 'needs:\s*unit-tests'
    }

    It 'references actions/checkout@v4 (pinned major version)' {
        $script:WorkflowText | Should -Match 'uses:\s*actions/checkout@v4'
    }

    It 'invokes Run-Cleanup.ps1 and uses pwsh shell' {
        $script:WorkflowText | Should -Match 'Run-Cleanup\.ps1'
        $script:WorkflowText | Should -Match 'shell:\s*pwsh'
    }
}

Describe 'Workflow references files that actually exist' {
    It 'ArtifactCleanup.ps1 exists' {
        Test-Path (Join-Path $script:RepoRoot 'ArtifactCleanup.ps1') | Should -BeTrue
    }
    It 'Run-Cleanup.ps1 exists' {
        Test-Path (Join-Path $script:RepoRoot 'Run-Cleanup.ps1') | Should -BeTrue
    }
    It 'tests/ArtifactCleanup.Tests.ps1 exists' {
        Test-Path (Join-Path $script:RepoRoot 'tests' 'ArtifactCleanup.Tests.ps1') | Should -BeTrue
    }
}

Describe 'actionlint' {
    It 'workflow passes actionlint with exit 0' {
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output | Out-String)
    }
}

Describe 'act-result.txt artifact (produced by Run-ActTests.ps1)' {
    It 'act-result.txt exists' {
        Test-Path $script:ResultPath | Should -BeTrue
    }

    It 'contains output for all three test cases' {
        $text = Get-Content $script:ResultPath -Raw
        $text | Should -Match 'CASE: age-only'
        $text | Should -Match 'CASE: keep-latest'
        $text | Should -Match 'CASE: combined'
    }

    It 'contains the exact expected SUMMARY line for each test case' {
        $text = Get-Content $script:ResultPath -Raw
        $text | Should -Match ([regex]::Escape('SUMMARY: deleted=2 retained=2 reclaimed_bytes=3145728 dry_run=true'))
        $text | Should -Match ([regex]::Escape('SUMMARY: deleted=3 retained=2 reclaimed_bytes=8000 dry_run=false'))
        $text | Should -Match ([regex]::Escape('SUMMARY: deleted=5 retained=2 reclaimed_bytes=8000 dry_run=false'))
    }

    It 'records "Job succeeded" at least twice per case (unit-tests + cleanup-plan, three cases = six total)' {
        $text = Get-Content $script:ResultPath -Raw
        ([regex]::Matches($text, 'Job succeeded')).Count | Should -BeGreaterOrEqual 6
    }

    It 'records exit=0 for every case header' {
        $text = Get-Content $script:ResultPath -Raw
        $caseHeaders = [regex]::Matches($text, 'CASE:\s+\S+\s+exit=(\d+)')
        $caseHeaders.Count | Should -Be 3
        foreach ($m in $caseHeaders) { $m.Groups[1].Value | Should -Be '0' }
    }
}
