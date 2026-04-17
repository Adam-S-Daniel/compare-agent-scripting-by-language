#!/usr/bin/env pwsh
<#
.SYNOPSIS
    End-to-end test harness that exercises the workflow through `act`.

.DESCRIPTION
    For each fixture, the harness:
      1. Creates a fresh temp git repo
      2. Copies the script, module, and workflow into the temp repo
      3. Drops the fixture version file + commit log in as the inputs the
         workflow expects (version.txt + commits.txt, or package.json)
      4. Runs `act push --rm` and captures all output
      5. Appends the output — clearly delimited — to act-result.txt
      6. Asserts: exit code is 0, every job says "Job succeeded", and the
         final NEW_VERSION printed by the script equals the known-good value

    Limited to at most 3 `act push` runs total per the task constraints. We
    batch four test cases across three runs by enabling all four in separate
    temp repos but capping concurrency at one run per repo.
#>
[CmdletBinding()]
param(
    [string]$ResultFile = (Join-Path $PSScriptRoot 'act-result.txt')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$here = $PSScriptRoot

# Test cases. Each test case declares the inputs and the known-good expected
# new version. The expected value was derived by hand from the commit log
# and the previous version — that's the whole point of the assertion.
#
# We cap at three cases because the task limits total `act push` invocations
# to three. These three exercise all three bump types (Minor, Major, Patch)
# and therefore every branch of the precedence logic.
$cases = @(
    @{
        Name            = 'feat-minor'
        Description     = 'feat + fix + docs, previous 1.1.0 -> expect minor bump 1.2.0'
        VersionSource   = 'fixtures/feat-minor.version.txt'
        VersionTarget   = 'version.txt'
        CommitSource    = 'fixtures/feat-minor.commits.txt'
        ExpectedVersion = '1.2.0'
        ExpectedBump    = 'Minor'
    },
    @{
        Name            = 'breaking-major'
        Description     = 'feat! with BREAKING CHANGE, previous 1.4.7 -> expect major bump 2.0.0'
        VersionSource   = 'fixtures/breaking-major.version.txt'
        VersionTarget   = 'version.txt'
        CommitSource    = 'fixtures/breaking-major.commits.txt'
        ExpectedVersion = '2.0.0'
        ExpectedBump    = 'Major'
    },
    @{
        Name            = 'fix-patch'
        Description     = 'only fixes, previous 0.5.0 -> expect patch bump 0.5.1'
        VersionSource   = 'fixtures/fix-patch.version.txt'
        VersionTarget   = 'version.txt'
        CommitSource    = 'fixtures/fix-patch.commits.txt'
        ExpectedVersion = '0.5.1'
        ExpectedBump    = 'Patch'
    }
)

# Clear the result log — we start fresh each run.
Set-Content -LiteralPath $ResultFile -Value ("# act-result.txt — generated $(Get-Date -Format o)`n")

$failures = 0
$ran = 0

foreach ($case in $cases) {
    $ran++
    $banner = "=" * 78
    $header = "$banner`n# CASE [$ran]: $($case.Name) — $($case.Description)`n$banner"
    Write-Host $header -ForegroundColor Cyan
    Add-Content -LiteralPath $ResultFile -Value $header

    # Fresh temp repo per case. act expects a git repo with the workflow in
    # .github/workflows/. Each case gets its own so state doesn't bleed.
    $repo = Join-Path ([IO.Path]::GetTempPath()) "act-svb-$($case.Name)-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $repo | Out-Null

    try {
        # Copy script, module, and workflow into the temp repo.
        Copy-Item -LiteralPath (Join-Path $here 'Invoke-VersionBumper.ps1') -Destination $repo
        Copy-Item -LiteralPath (Join-Path $here 'SemanticVersionBumper.psm1') -Destination $repo
        Copy-Item -LiteralPath (Join-Path $here 'SemanticVersionBumper.Tests.ps1') -Destination $repo
        New-Item -ItemType Directory -Path (Join-Path $repo '.github/workflows') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $here '.github/workflows/semantic-version-bumper.yml') -Destination (Join-Path $repo '.github/workflows/')

        # Drop fixture into the repo under the workflow's expected input name.
        Copy-Item -LiteralPath (Join-Path $here $case.VersionSource) -Destination (Join-Path $repo $case.VersionTarget)
        Copy-Item -LiteralPath (Join-Path $here $case.CommitSource)  -Destination (Join-Path $repo 'commits.txt')

        # Also copy .actrc so act uses the pwsh-enabled image.
        if (Test-Path (Join-Path $here '.actrc')) {
            Copy-Item -LiteralPath (Join-Path $here '.actrc') -Destination $repo
        }

        # git init + initial commit so actions/checkout sees a real ref.
        Push-Location $repo
        try {
            git init --quiet -b main 2>&1 | Out-Null
            git config user.email test@example.invalid
            git config user.name  test
            git add -A
            git commit --quiet -m "fixture: $($case.Name)" 2>&1 | Out-Null

            # Workflow env forces the PS script to read from our fixture paths.
            $env:VERSION_FILE_OVERRIDE = $case.VersionTarget

            # Run act. We want stdout + stderr captured together so we can
            # parse the final NEW_VERSION= line out of the job log.
            Write-Host ">>> running: act push --rm" -ForegroundColor Yellow
            # --pull=false is critical: our .actrc maps ubuntu-latest to a
            # locally-built image (act-ubuntu-pwsh). Without --pull=false act
            # tries to docker-pull it and fails with "repository does not exist".
            $actOut = & act push --rm --pull=false `
                -W .github/workflows/semantic-version-bumper.yml `
                --env "VERSION_FILE=$($case.VersionTarget)" 2>&1
            $actExit = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        # Archive the raw act output for this case.
        Add-Content -LiteralPath $ResultFile -Value ">>> act exit code: $actExit"
        Add-Content -LiteralPath $ResultFile -Value '--- act output start ---'
        $actOut | ForEach-Object { Add-Content -LiteralPath $ResultFile -Value $_ }
        Add-Content -LiteralPath $ResultFile -Value '--- act output end ---'

        # Assertions
        $issues = @()
        if ($actExit -ne 0) {
            $issues += "act exit code was $actExit, expected 0"
        }

        $joined = ($actOut | ForEach-Object { [string]$_ }) -join "`n"

        # Both jobs (unit-tests + bump) must succeed.
        $succeededCount = ([regex]::Matches($joined, 'Job succeeded')).Count
        if ($succeededCount -lt 2) {
            $issues += "expected at least 2 'Job succeeded' markers, saw $succeededCount"
        }

        # Parse NEW_VERSION=X.Y.Z from act output.
        $m = [regex]::Match($joined, 'NEW_VERSION=(?<v>\d+\.\d+\.\d+)')
        if (-not $m.Success) {
            $issues += "could not find NEW_VERSION=... line in act output"
        }
        elseif ($m.Groups['v'].Value -ne $case.ExpectedVersion) {
            $issues += "expected NEW_VERSION=$($case.ExpectedVersion) but saw $($m.Groups['v'].Value)"
        }

        # Also parse the BUMP= echo line from the workflow's Print results step.
        $bm = [regex]::Match($joined, '(?m)^BUMP=(?<b>\w+)')
        if ($bm.Success -and $bm.Groups['b'].Value -ne $case.ExpectedBump) {
            $issues += "expected BUMP=$($case.ExpectedBump) but saw $($bm.Groups['b'].Value)"
        }

        if ($issues.Count -gt 0) {
            $failures++
            $msg = "FAIL [$($case.Name)]:`n  - " + ($issues -join "`n  - ")
            Write-Host $msg -ForegroundColor Red
            Add-Content -LiteralPath $ResultFile -Value $msg
        }
        else {
            $msg = "PASS [$($case.Name)] — NEW_VERSION=$($case.ExpectedVersion), BUMP=$($case.ExpectedBump)"
            Write-Host $msg -ForegroundColor Green
            Add-Content -LiteralPath $ResultFile -Value $msg
        }
    }
    finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$summary = if ($failures -eq 0) {
    "ALL $ran act cases passed"
} else {
    "$failures of $ran act cases FAILED"
}

Write-Host ""
Write-Host ("=" * 78) -ForegroundColor Cyan
Write-Host $summary -ForegroundColor ($(if ($failures -eq 0) { 'Green' } else { 'Red' }))
Add-Content -LiteralPath $ResultFile -Value ""
Add-Content -LiteralPath $ResultFile -Value ("=" * 78)
Add-Content -LiteralPath $ResultFile -Value "SUMMARY: $summary"

if ($failures -gt 0) { exit 1 }
exit 0
