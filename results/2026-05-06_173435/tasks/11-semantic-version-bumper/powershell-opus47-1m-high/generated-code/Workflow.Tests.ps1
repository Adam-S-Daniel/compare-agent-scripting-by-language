# Workflow.Tests.ps1
#
# End-to-end tests that exercise the GitHub Actions workflow through `act`.
# Each test case (patch / minor / major) is run as its own `act push --rm`
# invocation against a temp git repo seeded with the repo files plus a
# fixture-specific VERSION + commits.txt. We assert on the EXACT new version
# and bump type emitted by the bumper inside the workflow.
#
# Why this shape:
#   - Unit tests in Bumper.Tests.ps1 already cover internal correctness.
#     This file's job is to prove the *pipeline* wires everything up
#     correctly and produces the right output for the right input.
#   - We share a single act run per case (3 cases total) to stay under the
#     "<= 3 act push" budget.
#   - All act stdout/stderr is appended to act-result.txt with clear
#     delimiters so the artifact is easy to skim.

BeforeAll {
    $script:RepoRoot   = $PSScriptRoot
    $script:ResultFile = Join-Path $script:RepoRoot 'act-result.txt'
    if (Test-Path $script:ResultFile) { Remove-Item $script:ResultFile -Force }

    # Test cases: each one defines the seed VERSION and the fixture to drop
    # in as commits.txt, plus what we expect the workflow to emit.
    $script:Cases = @(
        @{ Name = 'patch'; Version = '1.0.0'; Fixture = 'commits-fix.txt';      ExpectedVersion = '1.0.1'; ExpectedBump = 'patch' }
        @{ Name = 'minor'; Version = '1.1.0'; Fixture = 'commits-feat.txt';     ExpectedVersion = '1.2.0'; ExpectedBump = 'minor' }
        @{ Name = 'major'; Version = '1.4.2'; Fixture = 'commits-breaking.txt'; ExpectedVersion = '2.0.0'; ExpectedBump = 'major' }
    )

    function Invoke-ActCase {
        param(
            [string]$Name,
            [string]$Version,
            [string]$FixturePath,
            [string]$ExpectedVersion,
            [string]$ExpectedBump
        )
        # Build an isolated working tree so the run can't pick up unrelated
        # state. We copy the project files, write VERSION/commits.txt for
        # the case, then `git init` so act has a real repo to operate on.
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "act-bumper-$Name-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        foreach ($item in @('Bumper.psm1','Bumper.Tests.ps1','bump-version.ps1','.actrc')) {
            Copy-Item -LiteralPath (Join-Path $script:RepoRoot $item) -Destination $tmp -Force
        }
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'fixtures')        -Destination $tmp -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot '.github')         -Destination $tmp -Recurse -Force

        Set-Content -LiteralPath (Join-Path $tmp 'VERSION') -Value $Version -NoNewline
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'fixtures' $FixturePath) `
                  -Destination (Join-Path $tmp 'commits.txt') -Force

        Push-Location $tmp
        try {
            git init --quiet -b main 2>&1 | Out-Null
            git config user.email "test@example.com" 2>&1 | Out-Null
            git config user.name  "Test"               2>&1 | Out-Null
            git add -A 2>&1 | Out-Null
            git commit -m "seed" --quiet 2>&1 | Out-Null

            # Run act. --rm cleans up the container afterwards.
            # --pull=false because the image is already built locally and
            # not available from any registry; pulling would (and did) fail.
            $output = & act push --rm --pull=false 2>&1 | Out-String
            $exit   = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        # Append to the result artifact with clear delimiters so multiple
        # cases can be inspected from a single file.
        $delim = '=' * 78
        Add-Content -LiteralPath $script:ResultFile -Value @"
$delim
CASE: $Name (version=$Version, fixture=$FixturePath)
EXPECTED: NEW_VERSION=$ExpectedVersion BUMP_TYPE=$ExpectedBump
ACT EXIT: $exit
$delim
$output
"@
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

        return [pscustomobject]@{
            Name   = $Name
            Exit   = $exit
            Output = $output
        }
    }

    # Pre-run all cases once, share results across It blocks. This keeps
    # the act invocations within the "<= 3 act push" budget.
    $script:Results = @{}
    foreach ($c in $script:Cases) {
        Write-Host "--- running act case '$($c.Name)' ---"
        $script:Results[$c.Name] = Invoke-ActCase `
            -Name            $c.Name `
            -Version         $c.Version `
            -FixturePath     $c.Fixture `
            -ExpectedVersion $c.ExpectedVersion `
            -ExpectedBump    $c.ExpectedBump
    }
}

Describe 'Workflow file structure' {
    BeforeAll {
        $script:WfPath = Join-Path $PSScriptRoot '.github/workflows/semantic-version-bumper.yml'
        $script:WfText = Get-Content -LiteralPath $script:WfPath -Raw
    }

    It 'exists at the required path' {
        Test-Path $script:WfPath | Should -BeTrue
    }

    It 'declares push, pull_request, workflow_dispatch and schedule triggers' {
        $script:WfText | Should -Match '(?m)^on:'
        $script:WfText | Should -Match '(?m)^\s*push:'
        $script:WfText | Should -Match '(?m)^\s*pull_request:'
        $script:WfText | Should -Match '(?m)^\s*workflow_dispatch:'
        $script:WfText | Should -Match '(?m)^\s*schedule:'
    }

    It 'defines test and bump jobs with bump depending on test' {
        $script:WfText | Should -Match '(?m)^\s*test:'
        $script:WfText | Should -Match '(?m)^\s*bump:'
        $script:WfText | Should -Match 'needs:\s*test'
    }

    It 'references repo files that actually exist' {
        # script files referenced from the workflow should be present.
        Test-Path (Join-Path $PSScriptRoot 'Bumper.psm1')       | Should -BeTrue
        Test-Path (Join-Path $PSScriptRoot 'Bumper.Tests.ps1')  | Should -BeTrue
        Test-Path (Join-Path $PSScriptRoot 'bump-version.ps1')  | Should -BeTrue
        Test-Path (Join-Path $PSScriptRoot 'fixtures')          | Should -BeTrue
    }

    It 'uses actions/checkout@v4 (an action reference recognised by actionlint)' {
        $script:WfText | Should -Match 'actions/checkout@v4'
    }

    It 'sets shell: pwsh on its run steps (PowerShell mode requirement)' {
        $script:WfText | Should -Match 'shell:\s*pwsh'
    }

    It 'declares explicit permissions (security best practice)' {
        $script:WfText | Should -Match '(?m)^permissions:'
    }
}

Describe 'actionlint validation' {
    It 'passes actionlint with exit code 0' {
        $wf = Join-Path $PSScriptRoot '.github/workflows/semantic-version-bumper.yml'
        $out = & actionlint $wf 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output:`n$out"
    }
}

Describe 'End-to-end via act' {
    Context 'patch case (fix-only commits)' {
        It 'act exits with code 0' {
            $script:Results['patch'].Exit | Should -Be 0
        }
        It 'workflow emits NEW_VERSION=1.0.1' {
            $script:Results['patch'].Output | Should -Match 'NEW_VERSION=1\.0\.1'
        }
        It 'workflow emits BUMP_TYPE=patch' {
            $script:Results['patch'].Output | Should -Match 'BUMP_TYPE=patch'
        }
        It 'every job reports Job succeeded' {
            ($script:Results['patch'].Output -split "`n" |
                Where-Object { $_ -match 'Job succeeded' }).Count | Should -BeGreaterThan 0
            ($script:Results['patch'].Output -split "`n" |
                Where-Object { $_ -match 'Job failed' }).Count | Should -Be 0
        }
    }

    Context 'minor case (feat commit)' {
        It 'act exits with code 0' {
            $script:Results['minor'].Exit | Should -Be 0
        }
        It 'workflow emits NEW_VERSION=1.2.0' {
            $script:Results['minor'].Output | Should -Match 'NEW_VERSION=1\.2\.0'
        }
        It 'workflow emits BUMP_TYPE=minor' {
            $script:Results['minor'].Output | Should -Match 'BUMP_TYPE=minor'
        }
        It 'every job reports Job succeeded' {
            ($script:Results['minor'].Output -split "`n" |
                Where-Object { $_ -match 'Job succeeded' }).Count | Should -BeGreaterThan 0
            ($script:Results['minor'].Output -split "`n" |
                Where-Object { $_ -match 'Job failed' }).Count | Should -Be 0
        }
    }

    Context 'major case (BREAKING CHANGE)' {
        It 'act exits with code 0' {
            $script:Results['major'].Exit | Should -Be 0
        }
        It 'workflow emits NEW_VERSION=2.0.0' {
            $script:Results['major'].Output | Should -Match 'NEW_VERSION=2\.0\.0'
        }
        It 'workflow emits BUMP_TYPE=major' {
            $script:Results['major'].Output | Should -Match 'BUMP_TYPE=major'
        }
        It 'every job reports Job succeeded' {
            ($script:Results['major'].Output -split "`n" |
                Where-Object { $_ -match 'Job succeeded' }).Count | Should -BeGreaterThan 0
            ($script:Results['major'].Output -split "`n" |
                Where-Object { $_ -match 'Job failed' }).Count | Should -Be 0
        }
    }

    It 'produced act-result.txt artifact' {
        $rf = Join-Path $PSScriptRoot 'act-result.txt'
        Test-Path $rf | Should -BeTrue
        (Get-Item $rf).Length | Should -BeGreaterThan 0
    }
}
