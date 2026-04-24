# Run-ActTests.ps1
# Act integration test harness.
# Sets up a temp git repo, runs the workflow via `act push`, captures output,
# saves it to act-result.txt, and asserts on exact expected values.
#
# Usage: pwsh Run-ActTests.ps1
# Limit: at most 3 `act push` invocations total.

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ActResultFile = "$PSScriptRoot/act-result.txt"
$TestErrors    = 0

# Initialize the result file with a header
Set-Content -Path $ActResultFile -Value "Act Integration Test Results - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Content -Path $ActResultFile -Value ("=" * 70)

function Write-Pass([string]$Msg) {
    Write-Host "[PASS] $Msg" -ForegroundColor Green
}

function Write-Fail([string]$Msg) {
    Write-Host "[FAIL] $Msg" -ForegroundColor Red
    $script:TestErrors++
}

function Assert-ExitCode([int]$Actual, [int]$Expected, [string]$Context) {
    if ($Actual -eq $Expected) {
        Write-Pass "Exit code = $Expected  ($Context)"
    } else {
        Write-Fail "Exit code: expected $Expected, got $Actual  ($Context)"
    }
}

function Assert-Contains([string]$Text, [string]$Literal, [string]$Msg) {
    if ($Text.Contains($Literal)) {
        Write-Pass $Msg
    } else {
        Write-Fail "$Msg  [pattern: '$Literal' not found in output]"
    }
}

# ============================================================
# Test Case 1: Full aggregation — all 4 fixture files
# Expected: 16 total, 8 passed, 6 failed, 2 skipped, 6.80s, 2 flaky
# ============================================================
Write-Host ""
Write-Host "=== Test Case 1: Full aggregation (junit-node16, junit-node18, results-linux, results-windows) ===" -ForegroundColor Cyan

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir | Out-Null

try {
    # Copy all project files including hidden dirs (.github, .actrc, fixtures)
    Get-ChildItem -Path $PSScriptRoot -Force |
        Where-Object { $_.Name -ne (Split-Path $ActResultFile -Leaf) } |
        ForEach-Object {
            if ($_.PSIsContainer) {
                Copy-Item -Path $_.FullName -Destination (Join-Path $TempDir $_.Name) -Recurse -Force
            } else {
                Copy-Item -Path $_.FullName -Destination $TempDir -Force
            }
        }

    Push-Location $TempDir
    try {
        # Initialize git repo required for `act push`
        & git init --quiet
        & git config user.email "ci@example.com"
        & git config user.name "CI Test"
        & git add -A
        & git commit -m "test: run workflow via act" --quiet

        Write-Host "Running act push --rm --pull=false ..."
        # .actrc in the temp dir sets -P ubuntu-latest=act-ubuntu-pwsh:latest
        # --pull=false prevents act from re-pulling the locally-built image
        $actOutput = & act push --rm --pull=false 2>&1
        $actExitCode = $LASTEXITCODE
        $actStr = $actOutput -join "`n"

        # Append to act-result.txt
        Add-Content -Path $ActResultFile -Value ""
        Add-Content -Path $ActResultFile -Value "--- TEST CASE 1: Full aggregation ---"
        Add-Content -Path $ActResultFile -Value $actStr
        Add-Content -Path $ActResultFile -Value "--- EXIT CODE: $actExitCode ---"
        Add-Content -Path $ActResultFile -Value ""

        # Assertions — exact expected values
        Assert-ExitCode $actExitCode 0 "act push full aggregation"
        Assert-Contains $actStr "Job succeeded"              "Job succeeded"
        Assert-Contains $actStr "SUMMARY_TOTAL_TESTS=16"    "Total tests = 16"
        Assert-Contains $actStr "SUMMARY_PASSED=8"          "Passed = 8"
        Assert-Contains $actStr "SUMMARY_FAILED=6"          "Failed = 6"
        Assert-Contains $actStr "SUMMARY_SKIPPED=2"         "Skipped = 2"
        Assert-Contains $actStr "SUMMARY_DURATION=6.80"     "Duration = 6.80s"
        Assert-Contains $actStr "SUMMARY_FLAKY_COUNT=2"     "Flaky count = 2"
        Assert-Contains $actStr "FlakyTest"                 "FlakyTest appears in output"
        Assert-Contains $actStr "ApiTest2"                  "ApiTest2 appears in output"
        Assert-Contains $actStr "All Pester tests passed"   "Pester tests passed inside act"
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
}

# ============================================================
# Final summary
# ============================================================
Write-Host ""
Add-Content -Path $ActResultFile -Value ""
Add-Content -Path $ActResultFile -Value "=== FINAL: $TestErrors error(s) ==="

if ($TestErrors -gt 0) {
    Write-Host "Act integration tests FAILED: $TestErrors error(s)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All act integration tests PASSED!" -ForegroundColor Green
}
