#requires -Version 7.0
<#
.SYNOPSIS
End-to-end test harness: drives the GitHub Actions workflow through `act` for
each fixture and asserts on exact expected values.

.DESCRIPTION
For every fixture (a `secrets.json` + `.as-of` + an expected-summary spec):
  1. Spin up a fresh temp git repo
  2. Copy the project files (.actrc, src, tests, .github, secrets.json, .as-of)
  3. Substitute the fixture's secrets.json + .as-of
  4. Run `act push --rm`
  5. Append all output to act-result.txt with a clear delimiter
  6. Assert exit code == 0
  7. Assert the SUMMARY line matches the expected counts exactly
  8. Assert each "Job succeeded" line is present
  9. Assert expected ::error / ::warning / OK lines per fixture

A failure in any case throws and the script exits non-zero. The act-result.txt
artifact is always produced for inspection.
#>
[CmdletBinding()]
param(
    [string] $ResultFile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'act-result.txt')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repoRoot = Split-Path $PSScriptRoot -Parent

# Each fixture defines: secrets to validate, the AS_OF date, and the *exact*
# values we expect the workflow to print. Keeping expectations pinned (not
# regex like "any number") is what differentiates a real assertion from a
# smoke test.
$fixtures = @(
    [pscustomobject]@{
        Name    = 'all-ok'
        AsOf    = '2026-05-07'
        Secrets = @(
            [pscustomobject]@{ Name='db';  LastRotated='2026-05-01'; RotationDays=90; RequiredBy=@('api') }
            [pscustomobject]@{ Name='api'; LastRotated='2026-05-05'; RotationDays=30; RequiredBy=@('web') }
        )
        Expected = @{
            Summary = 'SUMMARY total=2 expired=0 warning=0 ok=2'
            Errors  = @()
            Warns   = @()
            Oks     = @(
                'OK api due in 28 day(s)'
                'OK db due in 84 day(s)'
            )
        }
    }
    [pscustomobject]@{
        Name    = 'mixed'
        AsOf    = '2026-05-07'
        Secrets = @(
            [pscustomobject]@{ Name='ssh'; LastRotated='2026-01-01'; RotationDays=60; RequiredBy=@('infra') } # expired 66d
            [pscustomobject]@{ Name='jwt'; LastRotated='2026-04-09'; RotationDays=30; RequiredBy=@('auth')  } # warning, due in 2
            [pscustomobject]@{ Name='db';  LastRotated='2026-04-30'; RotationDays=90; RequiredBy=@('api')   } # ok
        )
        Expected = @{
            Summary = 'SUMMARY total=3 expired=1 warning=1 ok=1'
            Errors  = @('::error title=Expired secret::ssh overdue 66 day(s)')
            Warns   = @('::warning title=Rotation warning::jwt due in 2 day(s)')
            Oks     = @('OK db due in 83 day(s)')
        }
    }
    [pscustomobject]@{
        Name    = 'all-expired'
        AsOf    = '2026-05-07'
        Secrets = @(
            [pscustomobject]@{ Name='alpha'; LastRotated='2026-01-01'; RotationDays=30; RequiredBy=@('s') } # 96 overdue
            [pscustomobject]@{ Name='beta';  LastRotated='2026-02-01'; RotationDays=30; RequiredBy=@('s') } # 65 overdue
        )
        Expected = @{
            Summary = 'SUMMARY total=2 expired=2 warning=0 ok=0'
            # Sorted by most overdue first, so alpha first.
            Errors  = @(
                '::error title=Expired secret::alpha overdue 96 day(s)'
                '::error title=Expired secret::beta overdue 65 day(s)'
            )
            Warns   = @()
            Oks     = @()
        }
    }
)

# Reset the result file at start of run.
Set-Content -LiteralPath $ResultFile -Value "act harness run $(Get-Date -Format o)`n" -Encoding utf8

function Write-Section {
    param([string] $Path, [string] $Header, [string] $Body)
    $rule = '=' * 80
    Add-Content -LiteralPath $Path -Value ("`n{0}`n# {1}`n{2}`n{3}`n" -f $rule, $Header, $rule, $Body)
}

$failures = @()

foreach ($fx in $fixtures) {
    Write-Host "===== Running fixture: $($fx.Name) ====="

    # Stage a fresh worktree per fixture so act sees a clean checkout.
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) "act-$($fx.Name)-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $temp -Force | Out-Null

    # Copy project tree (filtering noisy directories).
    Copy-Item -Path (Join-Path $repoRoot '.github')   -Destination $temp -Recurse
    Copy-Item -Path (Join-Path $repoRoot 'src')       -Destination $temp -Recurse
    Copy-Item -Path (Join-Path $repoRoot 'tests')     -Destination $temp -Recurse
    Copy-Item -Path (Join-Path $repoRoot '.actrc')    -Destination $temp
    # secrets.json and .as-of get *replaced* by fixture values below.

    $fx.Secrets | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $temp 'secrets.json') -Encoding utf8
    $fx.AsOf | Set-Content -LiteralPath (Join-Path $temp '.as-of') -Encoding utf8 -NoNewline

    # act expects a git repo root.
    Push-Location $temp
    try {
        git init -q --initial-branch=main 2>&1 | Out-Null
        git -c user.email=h@x -c user.name=Harness add -A 2>&1 | Out-Null
        git -c user.email=h@x -c user.name=Harness commit -q -m "fixture $($fx.Name)" 2>&1 | Out-Null

        # Capture both stdout and stderr.
        $out = & act push --rm 2>&1 | Out-String
        $code = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    Write-Section -Path $ResultFile -Header "fixture=$($fx.Name) exit=$code" -Body $out

    # --- assertions -------------------------------------------------------
    $errs = @()

    if ($code -ne 0) {
        $errs += "act exited with code $code (expected 0)"
    }

    # Each job in the workflow should report success; "Job succeeded" is the
    # canonical line act emits per job.
    $jobSucceeded = ([regex]::Matches($out, 'Job succeeded')).Count
    if ($jobSucceeded -lt 2) {
        $errs += "expected >=2 'Job succeeded' lines, got $jobSucceeded"
    }

    if ($out -notmatch [regex]::Escape($fx.Expected.Summary)) {
        $errs += "missing summary line: $($fx.Expected.Summary)"
    }

    foreach ($expected in @($fx.Expected.Errors)) {
        if ($out -notmatch [regex]::Escape($expected)) {
            $errs += "missing error line: $expected"
        }
    }
    foreach ($expected in @($fx.Expected.Warns)) {
        if ($out -notmatch [regex]::Escape($expected)) {
            $errs += "missing warning line: $expected"
        }
    }
    foreach ($expected in @($fx.Expected.Oks)) {
        if ($out -notmatch [regex]::Escape($expected)) {
            $errs += "missing OK line: $expected"
        }
    }

    if ($errs.Count -gt 0) {
        Write-Host "FAILED $($fx.Name):" -ForegroundColor Red
        $errs | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        $failures += "$($fx.Name): $($errs -join '; ')"
    } else {
        Write-Host "PASS $($fx.Name)" -ForegroundColor Green
    }

    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "$($failures.Count) fixture(s) failed:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}

Write-Host ""
Write-Host "All $($fixtures.Count) fixtures passed. Output appended to $ResultFile" -ForegroundColor Green
exit 0
