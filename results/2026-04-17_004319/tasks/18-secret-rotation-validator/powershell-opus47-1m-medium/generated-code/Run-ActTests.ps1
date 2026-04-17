#!/usr/bin/env pwsh
# Run-ActTests.ps1
# End-to-end harness: every test case runs through GitHub Actions via `act`.
#
# For each case we build a fresh git repo with the project files + that case's
# fixture, invoke `act push --rm`, capture output, and assert on the exact
# SUMMARY line plus job-success markers. All output is appended to act-result.txt.

[CmdletBinding()] param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$ResultFile  = Join-Path $ProjectRoot 'act-result.txt'
if (Test-Path $ResultFile) { Remove-Item $ResultFile -Force }
New-Item -ItemType File -Path $ResultFile | Out-Null

function Add-Result([string]$Text) {
    Add-Content -LiteralPath $ResultFile -Value $Text
}

# --- Test cases ----------------------------------------------------------
# Each case: a name, fixture JSON, env vars passed via `act --env`, and the
# expected exact SUMMARY line that should appear in stdout.
$cases = @(
    @{
        Name = 'mixed-statuses-markdown'
        Fixture = @{ secrets = @(
            @{ name='ok-token';   lastRotated='2026-04-10'; rotationPolicyDays=90;  requiredBy=@('api') }
            @{ name='warn-key';   lastRotated='2026-01-25'; rotationPolicyDays=90;  requiredBy=@('worker') }
            @{ name='dead-cred';  lastRotated='2025-06-01'; rotationPolicyDays=90;  requiredBy=@('legacy') }
        ) } | ConvertTo-Json -Depth 6
        Env = @{ WARNING_DAYS='14'; REFERENCE_DATE='2026-04-17'; REPORT_FORMAT='markdown' }
        ExpectSummary = 'SUMMARY: EXPIRED=1 WARNING=1 OK=1 TOTAL=3'
        ExpectExtra = @('## Expired', '## Warning', '## Ok', 'dead-cred')
    },
    @{
        Name = 'all-ok-json'
        Fixture = @{ secrets = @(
            @{ name='fresh-1'; lastRotated='2026-04-10'; rotationPolicyDays=180; requiredBy=@('a') }
            @{ name='fresh-2'; lastRotated='2026-04-15'; rotationPolicyDays=365; requiredBy=@('b') }
        ) } | ConvertTo-Json -Depth 6
        Env = @{ WARNING_DAYS='7'; REFERENCE_DATE='2026-04-17'; REPORT_FORMAT='json' }
        ExpectSummary = 'SUMMARY: EXPIRED=0 WARNING=0 OK=2 TOTAL=2'
        ExpectExtra = @('"Total": 2', '"Expired": 0', '"Ok": 2')
    },
    @{
        Name = 'wide-warning-window-catches-more'
        Fixture = @{ secrets = @(
            @{ name='exp-1';  lastRotated='2025-12-01'; rotationPolicyDays=90;  requiredBy=@('x') }
            @{ name='exp-2';  lastRotated='2025-11-01'; rotationPolicyDays=90;  requiredBy=@('y') }
            @{ name='warn-1'; lastRotated='2025-12-01'; rotationPolicyDays=180; requiredBy=@('z') }
            @{ name='ok-1';   lastRotated='2026-04-10'; rotationPolicyDays=365; requiredBy=@('q') }
        ) } | ConvertTo-Json -Depth 6
        Env = @{ WARNING_DAYS='60'; REFERENCE_DATE='2026-04-17'; REPORT_FORMAT='markdown' }
        ExpectSummary = 'SUMMARY: EXPIRED=2 WARNING=1 OK=1 TOTAL=4'
        ExpectExtra = @('exp-1', 'exp-2', 'warn-1')
    }
)

$projectFiles = @(
    'SecretRotation.psm1'
    'SecretRotation.Tests.ps1'
    'Invoke-SecretRotation.ps1'
    '.actrc'
)

$failures = @()

foreach ($case in $cases) {
    $caseName = $case.Name
    Write-Host "===== Running case: $caseName =====" -ForegroundColor Cyan

    # Build an isolated git repo for this case.
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-srv-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tmp 'fixtures') -Force | Out-Null

        Copy-Item (Join-Path $ProjectRoot '.github/workflows/secret-rotation-validator.yml') (Join-Path $tmp '.github/workflows/secret-rotation-validator.yml')
        foreach ($f in $projectFiles) {
            $src = Join-Path $ProjectRoot $f
            if (Test-Path $src) { Copy-Item $src (Join-Path $tmp $f) }
        }
        Set-Content -LiteralPath (Join-Path $tmp 'fixtures/secrets.json') -Value $case.Fixture -Encoding utf8

        Push-Location $tmp
        try {
            & git init -q
            & git config user.email 'ci@example.com'
            & git config user.name  'ci'
            & git add -A
            & git -c commit.gpgsign=false commit -q -m "case: $caseName"

            $envArgs = @()
            foreach ($k in $case.Env.Keys) { $envArgs += @('--env', "$k=$($case.Env[$k])") }

            Add-Result ""
            Add-Result "================================================================"
            Add-Result "CASE: $caseName"
            Add-Result "ENV: $($case.Env | ConvertTo-Json -Compress)"
            Add-Result "================================================================"

            $output = & act push --rm --pull=false @envArgs 2>&1 | Out-String
            $exit   = $LASTEXITCODE
            Add-Result $output
            Add-Result "ACT_EXIT_CODE=$exit"
        } finally {
            Pop-Location
        }
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }

    # ---- Assertions on captured output ----
    $caseFailed = $false

    if ($exit -ne 0) {
        $failures += "[$caseName] act exited with $exit (expected 0)"
        $caseFailed = $true
    }

    if ($output -notmatch [regex]::Escape($case.ExpectSummary)) {
        $failures += "[$caseName] expected summary line not found: '$($case.ExpectSummary)'"
        $caseFailed = $true
    }

    foreach ($needle in $case.ExpectExtra) {
        if ($output -notmatch [regex]::Escape($needle)) {
            $failures += "[$caseName] expected substring not found: '$needle'"
            $caseFailed = $true
        }
    }

    # Both jobs must show success in act's output.
    $successCount = ([regex]::Matches($output, 'Job succeeded')).Count
    if ($successCount -lt 2) {
        $failures += "[$caseName] expected 2 'Job succeeded' markers, found $successCount"
        $caseFailed = $true
    }

    if ($caseFailed) {
        Write-Host "  FAIL: $caseName" -ForegroundColor Red
    } else {
        Write-Host "  PASS: $caseName" -ForegroundColor Green
    }
}

Add-Result ""
Add-Result "================================================================"
if ($failures.Count -gt 0) {
    Add-Result "RESULT: FAIL ($($failures.Count) failures)"
    foreach ($f in $failures) { Add-Result " - $f" }
    Write-Host ""
    Write-Host "FAILURES:" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host " - $f" -ForegroundColor Red }
    exit 1
} else {
    Add-Result "RESULT: PASS (all $($cases.Count) cases)"
    Write-Host ""
    Write-Host "All $($cases.Count) act-driven cases passed." -ForegroundColor Green
    exit 0
}
