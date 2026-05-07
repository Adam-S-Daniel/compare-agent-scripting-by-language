# Test harness — runs the GitHub Actions workflow under `act` for several
# fixtures, captures all output to act-result.txt, and asserts on exact
# expected values per fixture.
#
# Per task instructions: tests of the script's behaviour run only through
# the pipeline. We do NOT invoke the validator directly here.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot   = $PSScriptRoot
$resultPath = Join-Path $repoRoot 'act-result.txt'
if (Test-Path $resultPath) { Remove-Item -LiteralPath $resultPath }

# ---- Test cases -----------------------------------------------------------
# Each case has its own secrets.json + harness.config.json contents and a
# set of substring assertions on the act stdout.
$cases = @(
    @{
        name = 'mixed-buckets'
        config = @{ configPath = 'examples/secrets.json'; warningDays = 14; asOfDate = '2026-05-07'; format = 'json' }
        secrets = @{ secrets = @(
            @{ name = 'ok-secret';      lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('api') }
            @{ name = 'warn-secret';    lastRotated = '2026-02-15'; rotationPolicyDays = 90; requiredBy = @('worker') }
            @{ name = 'expired-secret'; lastRotated = '2025-01-01'; rotationPolicyDays = 90; requiredBy = @('cron','api') }
        )}
        expectSubstrings = @(
            '"expired": 1',
            '"warning": 1',
            '"ok": 1',
            '"total": 3',
            '"name": "expired-secret"',
            '"name": "warn-secret"',
            '"name": "ok-secret"',
            '## Expired',
            '## Warning',
            '## OK'
        )
    },
    @{
        name = 'all-ok'
        config = @{ configPath = 'examples/secrets.json'; warningDays = 7; asOfDate = '2026-05-07'; format = 'json' }
        secrets = @{ secrets = @(
            @{ name = 'fresh-1'; lastRotated = '2026-05-01'; rotationPolicyDays = 90;  requiredBy = @('api') }
            @{ name = 'fresh-2'; lastRotated = '2026-04-20'; rotationPolicyDays = 365; requiredBy = @('worker') }
        )}
        expectSubstrings = @(
            '"expired": 0',
            '"warning": 0',
            '"ok": 2',
            '"total": 2',
            '"name": "fresh-1"',
            '"name": "fresh-2"'
        )
    },
    @{
        name = 'all-expired'
        config = @{ configPath = 'examples/secrets.json'; warningDays = 14; asOfDate = '2026-05-07'; format = 'json' }
        secrets = @{ secrets = @(
            @{ name = 'old-db';   lastRotated = '2024-01-01'; rotationPolicyDays = 30; requiredBy = @('db') }
            @{ name = 'old-api';  lastRotated = '2024-06-01'; rotationPolicyDays = 60; requiredBy = @('api') }
            @{ name = 'old-cron'; lastRotated = '2025-01-01'; rotationPolicyDays = 90; requiredBy = @('cron') }
        )}
        expectSubstrings = @(
            '"expired": 3',
            '"warning": 0',
            '"ok": 0',
            '"total": 3',
            '"name": "old-db"',
            '"name": "old-api"',
            '"name": "old-cron"'
        )
    }
)

function Add-Delim { param([string] $s) Add-Content -LiteralPath $resultPath -Value $s }

$failures = @()

# ---- Structure tests (host-side, not through act) -------------------------
# These validate the workflow YAML itself, since you can't validate a
# workflow's structure from inside a workflow run.
Write-Host "=== Workflow structure tests ===" -ForegroundColor Cyan
Add-Delim "========== STRUCTURE TESTS =========="

$wfPath = Join-Path $repoRoot '.github/workflows/secret-rotation-validator.yml'
if (-not (Test-Path $wfPath)) { $failures += "[structure] workflow file missing: $wfPath" }

# actionlint
$alOut = & actionlint $wfPath 2>&1 | Out-String
Add-Delim "actionlint exit=$LASTEXITCODE"
Add-Delim $alOut
if ($LASTEXITCODE -ne 0) { $failures += "[structure] actionlint failed" }

# Parse YAML via PowerShell-Yaml if available; otherwise fall back to regex
# checks against the raw text. We avoid taking a hard module dependency.
$wfText = Get-Content -Raw $wfPath
foreach ($needle in @(
    'name: secret-rotation-validator',
    'actions/checkout@v4',
    'shell: pwsh',
    'Invoke-Pester',
    'Invoke-Validator.ps1',
    'workflow_dispatch:',
    'schedule:',
    'permissions:',
    'needs: test'
)) {
    if ($wfText -notmatch [regex]::Escape($needle)) {
        $failures += "[structure] workflow missing expected token: $needle"
    }
}

# Verify referenced script paths exist
foreach ($p in 'Invoke-Validator.ps1','SecretRotationValidator.psm1','SecretRotationValidator.Tests.ps1','harness.config.json','examples/secrets.json') {
    if (-not (Test-Path (Join-Path $repoRoot $p))) {
        $failures += "[structure] referenced file missing: $p"
    }
}
Add-Delim ("structure failures so far: " + ($failures.Count))

$caseIndex = 0
foreach ($case in $cases) {
    $caseIndex++
    Write-Host "=== Case $caseIndex/$($cases.Count): $($case.name) ===" -ForegroundColor Cyan

    # Set up an isolated temp git repo populated with the project files +
    # this case's fixture data, then run `act push --rm` from inside it.
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-srv-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        # Copy required files
        Copy-Item -Path (Join-Path $repoRoot '.github')                  -Destination $tmp -Recurse
        Copy-Item -Path (Join-Path $repoRoot '.actrc')                   -Destination $tmp
        Copy-Item -Path (Join-Path $repoRoot 'SecretRotationValidator.psm1')      -Destination $tmp
        Copy-Item -Path (Join-Path $repoRoot 'SecretRotationValidator.Tests.ps1') -Destination $tmp
        Copy-Item -Path (Join-Path $repoRoot 'Invoke-Validator.ps1')     -Destination $tmp

        # Per-case fixtures
        New-Item -ItemType Directory -Path (Join-Path $tmp 'examples') | Out-Null
        ($case.secrets | ConvertTo-Json -Depth 6) | Set-Content -Path (Join-Path $tmp 'examples/secrets.json')
        ($case.config  | ConvertTo-Json -Depth 6) | Set-Content -Path (Join-Path $tmp 'harness.config.json')

        Push-Location $tmp
        try {
            git init -q
            git -c user.email=a@b -c user.name=t add -A
            git -c user.email=a@b -c user.name=t commit -q -m "case $($case.name)" | Out-Null

            $output = & act push --rm --pull=false 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Add-Delim ("`n========== CASE: $($case.name) (exit=$exit) ==========")
        Add-Delim $output

        if ($exit -ne 0) {
            $failures += "[$($case.name)] act exited with $exit"
            continue
        }

        if ($output -notmatch 'Job succeeded') {
            $failures += "[$($case.name)] no 'Job succeeded' marker found"
        }
        # Both jobs must have succeeded (test + validate)
        $jobSucceededCount = ([regex]::Matches($output, 'Job succeeded')).Count
        if ($jobSucceededCount -lt 2) {
            $failures += "[$($case.name)] expected >=2 'Job succeeded' (test+validate), got $jobSucceededCount"
        }

        foreach ($expected in $case.expectSubstrings) {
            if ($output -notmatch [regex]::Escape($expected)) {
                $failures += "[$($case.name)] expected substring not found: $expected"
            }
        }
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Add-Delim "`n========== HARNESS SUMMARY =========="
if ($failures.Count -eq 0) {
    Add-Delim "ALL CASES PASSED ($($cases.Count))"
    Write-Host "ALL CASES PASSED ($($cases.Count))" -ForegroundColor Green
    exit 0
} else {
    Add-Delim "FAILURES:"
    foreach ($f in $failures) { Add-Delim " - $f" }
    Write-Host "FAILURES ($($failures.Count)):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host " - $f" -ForegroundColor Red }
    exit 1
}
