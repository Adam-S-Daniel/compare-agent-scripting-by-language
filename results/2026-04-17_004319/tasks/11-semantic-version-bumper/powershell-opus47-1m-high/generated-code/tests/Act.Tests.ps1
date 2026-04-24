# Act-based end-to-end tests.
#
# Every test case exercises the GitHub Actions workflow via nektos/act in a
# Docker container. We:
#   1. Copy the project into a temp directory.
#   2. Swap in the fixture's VERSION/commits files.
#   3. Initialize a throwaway git repo (act expects one).
#   4. Run `act push --rm` once per case, passing SVB_FIXTURE in the env.
#   5. Append the full stdout/stderr to act-result.txt (the required artifact).
#   6. Assert act exited 0, "Job succeeded" appears for every job, and the
#      NEW_VERSION emitted by the workflow matches an exact expected value.
#
# The harness is budgeted to at most 3 act runs in total, one per fixture.
# All three cases share one Describe so the test file can't accidentally
# execute the harness twice.

BeforeAll {
    $script:RepoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:ActResult  = Join-Path $script:RepoRoot 'act-result.txt'
    $script:WorkflowRel = '.github/workflows/semantic-version-bumper.yml'

    # Reset the artifact on each full run. Individual cases append.
    if (Test-Path $script:ActResult) { Remove-Item $script:ActResult -Force }
    Set-Content -LiteralPath $script:ActResult -Value "act-result.txt — generated $(Get-Date -Format o)`n" -NoNewline

    # Materialize a sandbox that mirrors the project.
    $script:Sandbox = Join-Path ([IO.Path]::GetTempPath()) ("svb-act-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:Sandbox | Out-Null

    # Copy everything except git state and the act-result file itself.
    $exclude = @('.git', 'act-result.txt')
    Get-ChildItem -LiteralPath $script:RepoRoot -Force |
        Where-Object { $exclude -notcontains $_.Name } |
        ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $script:Sandbox -Recurse -Force
        }

    # Initialise a git repo inside the sandbox (act refuses otherwise).
    Push-Location $script:Sandbox
    try {
        & git init -q
        & git config user.email "svb-tests@example.com"
        & git config user.name "SVB Tests"
        & git add -A
        & git commit -q -m "initial" | Out-Null
    } finally {
        Pop-Location
    }

    function Invoke-ActCase {
        param(
            [Parameter(Mandatory)][string]$Fixture,
            [Parameter(Mandatory)][string]$ExpectedVersion,
            [Parameter(Mandatory)][string]$ExpectedBump
        )
        $env:SVB_FIXTURE = $Fixture
        # act reads .actrc (which pins the custom image) from the project root.
        # Run "push" so all triggers fire and both jobs execute.
        $logFile = Join-Path $script:Sandbox "act-$Fixture.log"
        Push-Location $script:Sandbox
        try {
            # --env passes SVB_FIXTURE into the container so the workflow
            # bumps the right fixture. Capture stdout+stderr together.
            # --pull=false: the act-ubuntu-pwsh:latest image is built locally
            #   and not pushed to a registry, so act must not try to re-pull it.
            $output = & act push `
                --rm `
                --pull=false `
                --env "SVB_FIXTURE=$Fixture" `
                --workflows $script:WorkflowRel 2>&1
            $exit = $LASTEXITCODE
            $outputStr = ($output | Out-String)
            Set-Content -LiteralPath $logFile -Value $outputStr -NoNewline
        } finally {
            Pop-Location
            Remove-Item Env:\SVB_FIXTURE -ErrorAction SilentlyContinue
        }

        # Append delimited output to the shared artifact.
        $delim = "`n" + ('=' * 72) + "`n=== ACT CASE: $Fixture (exit=$exit) ===`n" + ('=' * 72) + "`n"
        Add-Content -LiteralPath $script:ActResult -Value $delim
        Add-Content -LiteralPath $script:ActResult -Value $outputStr

        return [pscustomobject]@{
            Fixture         = $Fixture
            ExpectedVersion = $ExpectedVersion
            ExpectedBump    = $ExpectedBump
            Exit            = $exit
            Output          = $outputStr
        }
    }

    # Run each case exactly once and memoize.
    $script:Cases = @(
        Invoke-ActCase -Fixture 'patch' -ExpectedVersion '1.0.1' -ExpectedBump 'patch'
        Invoke-ActCase -Fixture 'minor' -ExpectedVersion '1.2.0' -ExpectedBump 'minor'
        Invoke-ActCase -Fixture 'major' -ExpectedVersion '2.0.0' -ExpectedBump 'major'
    )
}

Describe 'Act-based workflow execution' {
    It 'produces the act-result.txt artifact' {
        Test-Path $script:ActResult | Should -BeTrue
        (Get-Item $script:ActResult).Length | Should -BeGreaterThan 0
    }

    It 'records output for every fixture case' {
        $content = Get-Content $script:ActResult -Raw
        foreach ($f in @('patch', 'minor', 'major')) {
            $content | Should -Match "ACT CASE: $f"
        }
    }

    Context 'patch fixture' {
        It 'exits 0' {
            ($script:Cases | Where-Object Fixture -eq 'patch').Exit | Should -Be 0
        }
        It 'emits exactly the expected new version (1.0.0 -> 1.0.1)' {
            $out = ($script:Cases | Where-Object Fixture -eq 'patch').Output
            $out | Should -Match 'SVB_NEW_VERSION=1\.0\.1'
            $out | Should -Match 'SVB_OLD_VERSION=1\.0\.0'
            $out | Should -Match 'SVB_BUMP_TYPE=patch'
        }
        It 'shows both jobs succeeded' {
            $out = ($script:Cases | Where-Object Fixture -eq 'patch').Output
            ([regex]::Matches($out, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'minor fixture' {
        It 'exits 0' {
            ($script:Cases | Where-Object Fixture -eq 'minor').Exit | Should -Be 0
        }
        It 'emits exactly the expected new version (1.1.0 -> 1.2.0)' {
            $out = ($script:Cases | Where-Object Fixture -eq 'minor').Output
            $out | Should -Match 'SVB_NEW_VERSION=1\.2\.0'
            $out | Should -Match 'SVB_OLD_VERSION=1\.1\.0'
            $out | Should -Match 'SVB_BUMP_TYPE=minor'
        }
        It 'shows both jobs succeeded' {
            $out = ($script:Cases | Where-Object Fixture -eq 'minor').Output
            ([regex]::Matches($out, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'major fixture' {
        It 'exits 0' {
            ($script:Cases | Where-Object Fixture -eq 'major').Exit | Should -Be 0
        }
        It 'emits exactly the expected new version (1.5.2 -> 2.0.0)' {
            $out = ($script:Cases | Where-Object Fixture -eq 'major').Output
            $out | Should -Match 'SVB_NEW_VERSION=2\.0\.0'
            $out | Should -Match 'SVB_OLD_VERSION=1\.5\.2'
            $out | Should -Match 'SVB_BUMP_TYPE=major'
        }
        It 'shows both jobs succeeded' {
            $out = ($script:Cases | Where-Object Fixture -eq 'major').Output
            ([regex]::Matches($out, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
        }
    }
}
