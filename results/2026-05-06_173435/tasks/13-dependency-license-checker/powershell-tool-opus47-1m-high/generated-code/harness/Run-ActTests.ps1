#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Drives every dependency-license-checker test case through the
    GitHub Actions workflow via `act`.

.DESCRIPTION
    For each test case:
      * creates a fresh temp directory with a clean clone of this project,
      * overlays the case's fixture files (manifest + mock licenses
        + license config), so the workflow's $env:MANIFEST_PATH etc.
        resolve to that case's data,
      * `git init` + initial commit (act needs a git repo),
      * runs `act push --rm` once,
      * appends stdout+stderr to act-result.txt with a clear delimiter,
      * asserts:
          - act exit code == 0
          - "Job succeeded" appears
          - the EXACT expected substrings for that case appear
            (verifying the workflow really classified the deps).

    Limited to <=3 act runs total per benchmark requirements: we have
    exactly 3 test cases (compliant, violation, mixed-with-unknown).
#>

[CmdletBinding()]
param(
    [string] $ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')),
    [string] $ResultLog  = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')) 'act-result.txt')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Test cases: each defines fixture content + the exact assertions we expect
# to find in the act output.
# ---------------------------------------------------------------------------
$cases = @(
    [pscustomobject]@{
        Name      = 'all-approved'
        Manifest  = @'
{
  "name": "demo",
  "version": "0.0.1",
  "dependencies": { "left-pad": "1.3.0", "lodash": "4.17.21" },
  "devDependencies": { "jest": "29.0.0" }
}
'@
        MockData  = @'
{ "left-pad": "MIT", "lodash": "MIT", "jest": "MIT" }
'@
        Config    = @'
{ "AllowList": ["MIT","Apache-2.0","BSD-3-Clause","ISC"], "DenyList": ["GPL-3.0","AGPL-3.0"] }
'@
        Expect    = @(
            'TOTAL=3 APPROVED=3 DENIED=0 UNKNOWN=0',
            'RESULT: COMPLIANT',
            'WORKFLOW_GATE_OK'
        )
        ForbidStrings = @('RESULT: VIOLATIONS_FOUND')
    },

    [pscustomobject]@{
        Name      = 'has-violation'
        Manifest  = @'
{
  "dependencies": { "left-pad": "1.3.0", "evil-pkg": "0.1.0" }
}
'@
        MockData  = @'
{ "left-pad": "MIT", "evil-pkg": "GPL-3.0" }
'@
        Config    = @'
{ "AllowList": ["MIT","Apache-2.0"], "DenyList": ["GPL-3.0","AGPL-3.0"] }
'@
        Expect    = @(
            'TOTAL=2 APPROVED=1 DENIED=1 UNKNOWN=0',
            'RESULT: VIOLATIONS_FOUND',
            # In default report-only mode the workflow itself succeeds even
            # with a violation, so the post-gate guard prints the OK marker.
            'WORKFLOW_GATE_OK'
        )
        ForbidStrings = @('RESULT: COMPLIANT')
    },

    [pscustomobject]@{
        Name      = 'mixed-with-unknown'
        Manifest  = @'
{
  "dependencies": { "left-pad": "1.3.0" },
  "devDependencies": { "mystery-lib": "1.0.0" }
}
'@
        MockData  = @'
{ "left-pad": "MIT" }
'@
        Config    = @'
{ "AllowList": ["MIT","Apache-2.0"], "DenyList": ["GPL-3.0"] }
'@
        Expect    = @(
            'TOTAL=2 APPROVED=1 DENIED=0 UNKNOWN=1',
            'RESULT: COMPLIANT',
            'WORKFLOW_GATE_OK'
        )
        ForbidStrings = @('RESULT: VIOLATIONS_FOUND')
    }
)

# ---------------------------------------------------------------------------
# Reset the act-result.txt artifact (must exist when done).
# ---------------------------------------------------------------------------
if (Test-Path $ResultLog) { Remove-Item -LiteralPath $ResultLog -Force }
"Act result log -- generated $(Get-Date -Format o)`n" | Set-Content -LiteralPath $ResultLog

$failures = New-Object System.Collections.Generic.List[string]

foreach ($case in $cases) {
    Write-Host "=== Running case: $($case.Name) ===" -ForegroundColor Cyan
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dlc-act-$($case.Name)-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tmp | Out-Null

    try {
        # Copy project into the temp directory.
        # We exclude any pre-existing .git so `git init` below owns the repo.
        $rsync = Get-Command rsync -ErrorAction SilentlyContinue
        if ($rsync) {
            & rsync -a --exclude='.git' --exclude='act-result.txt' --exclude='harness/' "$ProjectDir/" "$tmp/" | Out-Null
        } else {
            Copy-Item -Path (Join-Path $ProjectDir '*') -Destination $tmp -Recurse -Force
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $tmp '.git')
            Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $tmp 'act-result.txt')
        }

        # Overlay the case-specific fixtures.
        New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'fixtures') | Out-Null
        $case.Manifest | Set-Content -LiteralPath (Join-Path $tmp 'fixtures' 'manifest.package.json')
        $case.MockData | Set-Content -LiteralPath (Join-Path $tmp 'fixtures' 'mock-licenses.json')
        $case.Config   | Set-Content -LiteralPath (Join-Path $tmp 'fixtures' 'license-config.json')

        # Initialise a fresh repo so act doesn't pick up the parent benchmark workspace's git.
        Push-Location $tmp
        try {
            & git init -q
            & git config user.email 'harness@example.com'
            & git config user.name  'Harness'
            & git add .
            & git -c core.hooksPath=/dev/null commit -q -m "case: $($case.Name)" | Out-Null

            # Run act.
            # --pull=false forces use of the locally-built act-ubuntu-pwsh image
            # (mapped in .actrc); without it act tries to docker pull from a
            # non-existent registry and fails the Set-up-job stage.
            $actOutput = & act push --rm --pull=false 2>&1
            $actExit   = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        # Append to the result log with a delimiter.
        $delim = "================================================================`n"
        $delim += "=== TEST CASE: $($case.Name)   exit=$actExit`n"
        $delim += "================================================================`n"
        Add-Content -LiteralPath $ResultLog -Value $delim
        Add-Content -LiteralPath $ResultLog -Value ($actOutput -join "`n")
        Add-Content -LiteralPath $ResultLog -Value "`n"

        # ---- Assertions -------------------------------------------------
        if ($actExit -ne 0) {
            $failures.Add("$($case.Name): act exit code was $actExit (expected 0)")
        }

        $joined = ($actOutput -join "`n")

        if ($joined -notmatch 'Job succeeded') {
            $failures.Add("$($case.Name): missing 'Job succeeded' marker")
        }

        foreach ($needle in $case.Expect) {
            if (-not ($joined -like "*$needle*")) {
                $failures.Add("$($case.Name): expected substring not found: '$needle'")
            }
        }
        foreach ($forbid in $case.ForbidStrings) {
            if ($joined -like "*$forbid*") {
                $failures.Add("$($case.Name): forbidden substring present: '$forbid'")
            }
        }
    }
    finally {
        # Keep the temp dir on failure for diagnostics.
        if ($failures.Count -eq 0) {
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmp
        } else {
            Write-Host "Preserving temp dir for diagnostics: $tmp" -ForegroundColor Yellow
        }
    }
}

# ---------------------------------------------------------------------------
# Final verdict
# ---------------------------------------------------------------------------
if ($failures.Count -gt 0) {
    Write-Host "`nACT HARNESS FAILED:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "`nACT HARNESS PASSED: $($cases.Count) cases, all assertions met." -ForegroundColor Green
exit 0
