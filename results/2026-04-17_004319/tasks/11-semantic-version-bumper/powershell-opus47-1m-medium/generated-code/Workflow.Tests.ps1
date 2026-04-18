#!/usr/bin/env pwsh
<#
.SYNOPSIS
  End-to-end test harness: runs the workflow with `act` for each fixture case,
  asserts exit codes, parses output, and asserts exact expected versions.

  Every test case goes through `act push --rm` — no direct script invocation.

.OUTPUTS
  Appends all `act` output to ./act-result.txt (required artifact).
#>
[CmdletBinding()]
param()

BeforeDiscovery {
    # These are the canonical test cases. Expected NEW_VERSION values are
    # derived from a fixed starting version of 1.1.0 baked into the workflow.
    $script:Cases = @(
        @{ Fixture = 'patch'; ExpectedVersion = '1.1.1'; ExpectedBump = 'patch' }
        @{ Fixture = 'minor'; ExpectedVersion = '1.2.0'; ExpectedBump = 'minor' }
        @{ Fixture = 'major'; ExpectedVersion = '2.0.0'; ExpectedBump = 'major' }
    )
}

BeforeAll {
    $script:RepoRoot   = $PSScriptRoot
    $script:ResultFile = Join-Path $script:RepoRoot 'act-result.txt'
    $script:Workflow   = Join-Path $script:RepoRoot '.github/workflows/semantic-version-bumper.yml'

    # Reset artifact file once per test run.
    if (Test-Path -LiteralPath $script:ResultFile) { Remove-Item -LiteralPath $script:ResultFile -Force }
    Set-Content -LiteralPath $script:ResultFile -Value "# act-result.txt - workflow run output`n"

    $script:Cases = @(
        @{ Fixture = 'patch'; ExpectedVersion = '1.1.1'; ExpectedBump = 'patch' }
        @{ Fixture = 'minor'; ExpectedVersion = '1.2.0'; ExpectedBump = 'minor' }
        @{ Fixture = 'major'; ExpectedVersion = '2.0.0'; ExpectedBump = 'major' }
    )

    function script:Invoke-ActCase {
        param([string]$Fixture)

        # Copy project into an isolated temp git repo so act operates on its own worktree.
        $work = Join-Path ([System.IO.Path]::GetTempPath()) ("act-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
        Copy-Item -Path (Join-Path $script:RepoRoot '*') -Destination $work -Recurse -Force `
                  -Exclude @('act-result.txt')

        Push-Location $work
        try {
            git init -q | Out-Null
            git config user.email "ci@example.com"
            git config user.name  "ci"
            git add -A | Out-Null
            git commit -q -m "seed" | Out-Null

            # Inline env var for just this case, pushed into the job via --env.
            $actArgs = @(
                'push',
                '--rm',
                '--pull=false',
                '--workflows', '.github/workflows/semantic-version-bumper.yml',
                '--env', "FIXTURE_NAME=$Fixture"
            )
            $raw = & act @actArgs 2>&1
            $code = $LASTEXITCODE

            Add-Content -LiteralPath $script:ResultFile -Value "`n===== CASE: $Fixture (exit=$code) =====`n"
            Add-Content -LiteralPath $script:ResultFile -Value ($raw -join "`n")

            return [pscustomobject]@{
                ExitCode = $code
                Output   = ($raw -join "`n")
            }
        }
        finally {
            Pop-Location
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Workflow structure' {
    It 'workflow file exists' {
        Test-Path -LiteralPath $script:Workflow | Should -BeTrue
    }
    It 'passes actionlint' {
        $out = & actionlint $script:Workflow 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint said: $out"
    }
    It 'references bump-version.ps1 and the SemVerBumper module' {
        $text = Get-Content -LiteralPath $script:Workflow -Raw
        $text | Should -Match 'bump-version\.ps1'
        Test-Path -LiteralPath (Join-Path $script:RepoRoot 'bump-version.ps1')   | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:RepoRoot 'SemVerBumper.psm1')  | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:RepoRoot 'SemVerBumper.Tests.ps1') | Should -BeTrue
    }
    It 'declares expected triggers and jobs' {
        # Minimal YAML probing (no yaml parser installed by default).
        $text = Get-Content -LiteralPath $script:Workflow -Raw
        $text | Should -Match '(?m)^on:'
        $text | Should -Match 'push:'
        $text | Should -Match 'workflow_dispatch:'
        $text | Should -Match '(?m)^\s{2}test:'
        $text | Should -Match '(?m)^\s{2}bump:'
        $text | Should -Match 'actions/checkout@v4'
        $text | Should -Match 'shell: pwsh'
    }
    It 'fixture files all exist' {
        foreach ($case in $script:Cases) {
            Test-Path -LiteralPath (Join-Path $script:RepoRoot "fixtures/commits-$($case.Fixture).txt") |
                Should -BeTrue
        }
    }
}

Describe 'Workflow end-to-end via act' -Tag 'act' {
    It '<Fixture> fixture produces version <ExpectedVersion>' -ForEach $script:Cases {
        $r = script:Invoke-ActCase -Fixture $Fixture

        $r.ExitCode | Should -Be 0 -Because "act output was:`n$($r.Output)"

        # Every job must report success. Count occurrences across the full string.
        $succeeded = ([regex]::Matches($r.Output, 'Job succeeded')).Count
        $failed    = ([regex]::Matches($r.Output, 'Job failed')).Count
        $failed    | Should -Be 0 -Because "no jobs should fail, output:`n$($r.Output)"
        $succeeded | Should -BeGreaterOrEqual 2 -Because "expected both 'test' and 'bump' jobs to succeed"

        # Exact-value assertions.
        $r.Output | Should -Match "NEW_VERSION=$([regex]::Escape($ExpectedVersion))"
        $r.Output | Should -Match "BUMP=$ExpectedBump"
    }
}
