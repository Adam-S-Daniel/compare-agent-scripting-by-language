#!/usr/bin/env pwsh
# Run-ActTests.ps1
# Act integration test harness for the Secret Rotation Validator.
#
# This script:
#   1. Sets up a temporary git repository with the project files
#   2. Runs `act push --rm` to execute the GitHub Actions workflow in Docker
#   3. Captures all output and appends it to act-result.txt
#   4. Asserts on exact expected values in the workflow output
#   5. Exits 0 on success, 1 on any failure
#
# Run from the project root:
#   pwsh ./Run-ActTests.ps1

$ErrorActionPreference = 'Stop'

$ProjectRoot   = $PSScriptRoot
$ActResultFile = Join-Path $ProjectRoot "act-result.txt"

# Clear the result file at the start of each run
Set-Content -Path $ActResultFile -Value "# act integration test results`n"

$AllPassed = $true

function Write-Pass {
    param([string]$Msg)
    Write-Host "[PASS] $Msg" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Msg)
    Write-Host "[FAIL] $Msg" -ForegroundColor Red
    $script:AllPassed = $false
}

# ----------------------------------------------------------------
# Invoke-ActTestCase
# Sets up a temp repo, runs act, saves output, asserts on values.
# ----------------------------------------------------------------
function Invoke-ActTestCase {
    param(
        [string]$TestName,
        # Hashtable of assertion-name -> expected-string-fragment
        [hashtable]$Assertions
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "TEST CASE: $TestName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $TempDir | Out-Null

    try {
        # --- Copy project files into the temp repo ---
        Copy-Item "$ProjectRoot/SecretRotationValidator.ps1"       $TempDir
        Copy-Item "$ProjectRoot/SecretRotationValidator.Tests.ps1" $TempDir

        # Copy fixtures directory
        $fixturesDest = Join-Path $TempDir "fixtures"
        Copy-Item "$ProjectRoot/fixtures" -Destination $fixturesDest -Recurse

        # Copy .actrc (specifies which Docker image to use)
        if (Test-Path "$ProjectRoot/.actrc") {
            Copy-Item "$ProjectRoot/.actrc" $TempDir
        }

        # Copy workflow
        $wfDir = Join-Path $TempDir ".github/workflows"
        New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
        Copy-Item "$ProjectRoot/.github/workflows/secret-rotation-validator.yml" $wfDir

        # --- Initialize git repository ---
        Push-Location $TempDir
        git init -b main                           2>&1 | Out-Null
        git config user.email "test@example.com"   2>&1 | Out-Null
        git config user.name  "Test Runner"        2>&1 | Out-Null
        git add -A                                 2>&1 | Out-Null
        git commit -m "test: secret rotation validator" 2>&1 | Out-Null

        # --- Run act ---
        Write-Host "Running: act push --rm --pull=false (in $TempDir)" -ForegroundColor Yellow
        $actOutput = act push --rm --pull=false 2>&1
        $ActExitCode = $LASTEXITCODE
        Pop-Location

        # Convert output array to a single string for searching
        $OutputStr = $actOutput | Out-String

        # --- Write to act-result.txt ---
        $Divider = "=" * 60
        Add-Content -Path $ActResultFile -Value "`n$Divider"
        Add-Content -Path $ActResultFile -Value "TEST CASE: $TestName"
        Add-Content -Path $ActResultFile -Value "Exit code: $ActExitCode"
        Add-Content -Path $ActResultFile -Value $Divider
        Add-Content -Path $ActResultFile -Value $OutputStr
        Add-Content -Path $ActResultFile -Value "$Divider`n"

        # --- Assert exit code 0 ---
        if ($ActExitCode -ne 0) {
            Write-Fail "$TestName - act exited with code $ActExitCode"
            Write-Host "--- act output tail ---" -ForegroundColor Red
            $actOutput | Select-Object -Last 30 | ForEach-Object { Write-Host $_ }
            return
        }
        Write-Pass "$TestName - act exit code 0"

        # --- Assert "Job succeeded" appears in output ---
        if ($OutputStr -notmatch "Job succeeded") {
            Write-Fail "$TestName - 'Job succeeded' not found in act output"
            return
        }
        Write-Pass "$TestName - Job succeeded"

        # --- Run each named assertion ---
        foreach ($entry in $Assertions.GetEnumerator()) {
            $assertName    = $entry.Key
            $expectedValue = $entry.Value
            if ($OutputStr -match [regex]::Escape($expectedValue)) {
                Write-Pass "$TestName :: $assertName (found: '$expectedValue')"
            }
            else {
                Write-Fail "$TestName :: $assertName - expected '$expectedValue' not found in output"
            }
        }

    }
    finally {
        # Always clean up the temp directory
        if (Test-Path $TempDir) {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ================================================================
# TEST CASE 1: Mixed secrets fixture
# Expected: 3 total, 1 expired, 1 warning, 1 ok
# Reference date: 2026-04-10
#   EXPIRED_DB_PASSWORD: rotated 2026-01-01, expiry 2026-04-01, overdue 9 days
#   WARNING_API_KEY:     rotated 2026-01-17, expiry 2026-04-17, 7 days remaining
#   OK_OAUTH_SECRET:     rotated 2026-02-01, expiry 2026-05-02, 22 days remaining
# ================================================================
Invoke-ActTestCase -TestName "mixed-secrets" -Assertions @{
    "summary-total-3"        = '"total": 3'
    "summary-expired-1"      = '"expired": 1'
    "summary-warning-1"      = '"warning": 1'
    "summary-ok-1"           = '"ok": 1'
    "expired-secret-name"    = "EXPIRED_DB_PASSWORD"
    "warning-secret-name"    = "WARNING_API_KEY"
    "ok-secret-name"         = "OK_OAUTH_SECRET"
    "expired-expiry-date"    = "2026-04-01"
    "warning-expiry-date"    = "2026-04-17"
    "ok-expiry-date"         = "2026-05-02"
    "pester-tests-pass"      = "Tests Passed:"
}

# ================================================================
# Print final summary
# ================================================================
Write-Host "`n========================================"
if ($AllPassed) {
    Write-Host "ALL ACT TESTS PASSED" -ForegroundColor Green
    Write-Host "Results saved to: $ActResultFile"
    exit 0
}
else {
    Write-Host "SOME ACT TESTS FAILED — see above" -ForegroundColor Red
    Write-Host "Results saved to: $ActResultFile"
    exit 1
}
