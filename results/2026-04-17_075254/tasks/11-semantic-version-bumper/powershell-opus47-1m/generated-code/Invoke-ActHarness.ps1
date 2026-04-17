#!/usr/bin/env pwsh
# Harness: sets up a temp git repo with the project, runs `act push --rm` once
# (relying on the workflow's own matrix to cover all fixture cases), captures
# output to act-result.txt, and asserts on exact expected version values.
[CmdletBinding()]
param(
    [string] $OutputFile = (Join-Path $PSScriptRoot 'act-result.txt')
)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot

# Cases the workflow matrix runs. Used here for output assertions.
$cases = @(
    @{ Fixture = 'commits-minor.txt'; Expected = '1.2.0'; Bump = 'minor' },
    @{ Fixture = 'commits-patch.txt'; Expected = '1.1.1'; Bump = 'patch' },
    @{ Fixture = 'commits-major.txt'; Expected = '2.0.0'; Bump = 'major' },
    @{ Fixture = 'commits-none.txt';  Expected = '1.1.0'; Bump = 'none'  }
)

# Build a fresh temp git repo copy (act cares about the checkout).
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("svb-act-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
Write-Host "Staging temp repo at: $tmp"

Copy-Item -Path (Join-Path $projectRoot '*') -Destination $tmp -Recurse -Exclude @('act-result.txt','.git')
Copy-Item -Path (Join-Path $projectRoot '.github') -Destination $tmp -Recurse -Force
Copy-Item -Path (Join-Path $projectRoot '.actrc')  -Destination $tmp -Force -ErrorAction SilentlyContinue

Push-Location $tmp
try {
    git init -q -b main
    git config user.email ci@example.com
    git config user.name  ci
    git add -A
    git commit -q -m "init"

    if (Test-Path $OutputFile) { Remove-Item $OutputFile -Force }

    Write-Host "=== Running act push --rm ==="
    $header = "### act push --rm @ " + (Get-Date -Format s) + " ###`n"
    Add-Content -LiteralPath $OutputFile -Value $header
    # Single `act push` run: workflow matrix covers all cases.
    $actOut = & act push --rm --pull=false 2>&1 | Out-String
    Add-Content -LiteralPath $OutputFile -Value $actOut
    $actExit = $LASTEXITCODE
    Add-Content -LiteralPath $OutputFile -Value ("`n### act exit code: $actExit ###`n")
    Write-Host $actOut

    if ($actExit -ne 0) {
        throw "act exited with code $actExit. See $OutputFile."
    }

    # Assertions on output text.
    foreach ($c in $cases) {
        $f = $c.Fixture; $expectedVer = $c.Expected; $expectedBump = $c.Bump
        $needleVer  = "ASSERT_NEW_VERSION=$expectedVer"
        $needleBump = "ASSERT_BUMP_TYPE=$expectedBump"
        $needleOk   = "RESULT_OK fixture=$f new=$expectedVer bump=$expectedBump"
        if ($actOut -notmatch [regex]::Escape($needleVer)) {
            throw "Missing '$needleVer' in act output for fixture $f"
        }
        if ($actOut -notmatch [regex]::Escape($needleBump)) {
            throw "Missing '$needleBump' in act output for fixture $f"
        }
        if ($actOut -notmatch [regex]::Escape($needleOk)) {
            throw "Missing '$needleOk' in act output for fixture $f"
        }
        Write-Host "[PASS] $f -> $expectedVer ($expectedBump)"
    }

    # Every job should show Job succeeded. Matrix cells + test job.
    $succeededCount = ([regex]::Matches($actOut, 'Job succeeded')).Count
    Write-Host "Job succeeded count: $succeededCount"
    if ($succeededCount -lt ($cases.Count + 1)) {
        throw "Expected at least $($cases.Count + 1) 'Job succeeded' lines, got $succeededCount"
    }

    Write-Host "`nALL ACT TESTS PASSED."
}
finally {
    Pop-Location
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
