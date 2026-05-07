# Workflow.Tests.ps1
#
# End-to-end Pester test suite that drives the GitHub Actions workflow
# under `act` (nektos/act) for every fixture. Per the task spec:
#   - every test case executes through the pipeline (no direct script calls)
#   - act output for every case is appended to ./act-result.txt
#   - asserts on EXACT expected values, not "a version appeared"
#
# Also includes structural / lint checks for the workflow itself.

BeforeDiscovery {
    $script:RepoRoot = $PSScriptRoot
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github/workflows/semantic-version-bumper.yml'
    $script:ActResultFile = Join-Path $script:RepoRoot 'act-result.txt'

    # Test cases shape: a folder under fixtures/, the version we expect
    # the bumper to produce, and a regex we expect to find in the
    # changelog block of act's stdout.
    $script:Cases = @(
        @{ Name = 'feat-minor';      StartVersion = '1.1.0'; ExpectedVersion = '1.2.0'; ChangelogMatch = 'support unicode identifiers' }
        @{ Name = 'fix-patch';       StartVersion = '0.1.0'; ExpectedVersion = '0.1.1'; ChangelogMatch = 'retry transient 502s'        }
        @{ Name = 'breaking-major';  StartVersion = '1.4.2'; ExpectedVersion = '2.0.0'; ChangelogMatch = 'drop deprecated v1 API'      }
    )
}

BeforeAll {
    $script:RepoRoot     = $PSScriptRoot
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github/workflows/semantic-version-bumper.yml'
    $script:ActResultFile = Join-Path $script:RepoRoot 'act-result.txt'

    # Truncate the act-result.txt artifact at the start of the run so we
    # don't accumulate output across reruns.
    Set-Content -Path $script:ActResultFile -Value "act-result.txt - $(Get-Date -Format o)`n" -NoNewline

    # Files the workflow needs in the fixture's temp git repo.
    $script:ProjectFiles = @(
        'SemanticVersionBumper.ps1',
        'SemanticVersionBumper.Tests.ps1',
        'Bump.ps1',
        '.actrc'
    )

    function script:New-ActSandbox {
        param(
            [Parameter(Mandatory)] [string] $FixtureName
        )
        $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("svb-act-" + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $sandbox | Out-Null

        # Copy the project sources.
        foreach ($f in $script:ProjectFiles) {
            Copy-Item -Path (Join-Path $script:RepoRoot $f) -Destination (Join-Path $sandbox $f) -Force
        }

        # Copy the workflow into .github/workflows.
        $wfDir = Join-Path $sandbox '.github/workflows'
        New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
        Copy-Item -Path $script:WorkflowPath -Destination (Join-Path $wfDir 'semantic-version-bumper.yml') -Force

        # Materialise the fixture's package.json + commits.txt at the
        # sandbox root - the workflow expects them at ./.
        $fixDir = Join-Path $script:RepoRoot "fixtures/$FixtureName"
        Copy-Item -Path (Join-Path $fixDir 'package.json') -Destination (Join-Path $sandbox 'package.json') -Force
        Copy-Item -Path (Join-Path $fixDir 'commits.txt')  -Destination (Join-Path $sandbox 'commits.txt')  -Force

        # act needs a real git repo - it inspects HEAD when picking events.
        Push-Location $sandbox
        try {
            & git init -q
            & git config user.email 'svb@example.com'
            & git config user.name 'SVB Test Harness'
            & git add -A
            & git commit -q -m "fixture: $FixtureName" | Out-Null
        } finally {
            Pop-Location
        }
        return $sandbox
    }

    function script:Invoke-Act {
        param(
            [Parameter(Mandatory)] [string] $Sandbox
        )
        Push-Location $Sandbox
        try {
            $stdout = & act push --rm 2>&1
            $code = $LASTEXITCODE
            return [PSCustomObject]@{
                ExitCode = $code
                Output   = ($stdout -join "`n")
            }
        } finally {
            Pop-Location
        }
    }

    function script:Append-ActResult {
        param(
            [Parameter(Mandatory)] [string] $CaseName,
            [Parameter(Mandatory)] [int]    $ExitCode,
            [Parameter(Mandatory)] [string] $Output
        )
        $delim = "`n========== CASE: $CaseName (exit=$ExitCode) ==========`n"
        Add-Content -Path $script:ActResultFile -Value $delim
        Add-Content -Path $script:ActResultFile -Value $Output
    }
}

Describe 'Workflow file structure' {
    It 'exists at the expected path' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'parses as YAML' {
        # PowerShell 7 has no built-in YAML parser; do a structural smoke
        # parse via key-search rather than full parsing.
        $content = Get-Content -Raw $script:WorkflowPath
        $content | Should -Match '^name:\s*Semantic Version Bumper'
        $content | Should -Match '\non:\s*\n'
        $content | Should -Match '\njobs:\s*\n'
    }

    It 'declares the required triggers' {
        $content = Get-Content -Raw $script:WorkflowPath
        $content | Should -Match '\bpush:'
        $content | Should -Match '\bpull_request:'
        $content | Should -Match '\bworkflow_dispatch:'
        $content | Should -Match '\bschedule:'
    }

    It 'references the bumper script and tests files that exist on disk' {
        $content = Get-Content -Raw $script:WorkflowPath
        $content | Should -Match 'Bump\.ps1'
        $content | Should -Match 'SemanticVersionBumper\.Tests\.ps1'
        Test-Path (Join-Path $script:RepoRoot 'Bump.ps1')                       | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'SemanticVersionBumper.ps1')      | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'SemanticVersionBumper.Tests.ps1')| Should -BeTrue
    }

    It 'pins actions/checkout to v4' {
        $content = Get-Content -Raw $script:WorkflowPath
        $content | Should -Match 'actions/checkout@v4'
    }

    It 'declares restrictive permissions' {
        $content = Get-Content -Raw $script:WorkflowPath
        $content | Should -Match 'permissions:\s*\n\s+contents:\s*read'
    }

    It 'uses shell: pwsh on run steps' {
        $content = Get-Content -Raw $script:WorkflowPath
        $content | Should -Match 'shell:\s*pwsh'
    }
}

Describe 'actionlint passes' {
    It 'exits 0 on the workflow file' {
        $output = & actionlint $script:WorkflowPath 2>&1
        $code = $LASTEXITCODE
        if ($code -ne 0) { Write-Host ($output -join "`n") }
        $code | Should -Be 0
    }
}

Describe 'act push end-to-end (one run per fixture)' -Tag 'act' -ForEach $script:Cases {
    It "<Name>: workflow bumps <StartVersion> -> <ExpectedVersion>" {
        $sandbox = New-ActSandbox -FixtureName $_.Name
        try {
            $result = Invoke-Act -Sandbox $sandbox
            Append-ActResult -CaseName $_.Name -ExitCode $result.ExitCode -Output $result.Output

            $result.ExitCode | Should -Be 0 -Because "act must succeed for case '$($_.Name)'"
            $result.Output   | Should -Match 'Job succeeded'
            $result.Output   | Should -Match "NEW_VERSION=$([regex]::Escape($_.ExpectedVersion))"
            $result.Output   | Should -Match "PACKAGE_VERSION=$([regex]::Escape($_.ExpectedVersion))"
            $result.Output   | Should -Match $_.ChangelogMatch
            # Sanity: the Pester suite inside the workflow ran and passed.
            $result.Output   | Should -Match 'Tests Passed: 26'
            $result.Output   | Should -Match 'Failed: 0'
        } finally {
            if (Test-Path $sandbox) { Remove-Item $sandbox -Recurse -Force }
        }
    }
}
