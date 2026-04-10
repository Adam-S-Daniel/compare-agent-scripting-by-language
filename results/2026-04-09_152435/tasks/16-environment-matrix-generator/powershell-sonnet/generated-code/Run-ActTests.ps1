# Run-ActTests.ps1
# Integration test harness for the Environment Matrix Generator.
#
# The workflow already exercises three distinct test cases in a single act run:
#   - basic fixture        (OS + Node versions, max-parallel, fail-fast=false)
#   - with-includes fixture (includes an extra macOS entry)
#   - with-excludes fixture (excludes two OS/node combos, fail-fast=true)
#
# This script:
#   1. Creates a temporary git repo containing all project files.
#   2. Runs `act push --rm --pull=false` once (covering all three cases).
#   3. Appends the full output to act-result.txt (clearly delimited).
#   4. Asserts act exited with code 0.
#   5. Asserts "Job succeeded" is present.
#   6. Asserts EXACT expected values for each test case from the act output.
#
# Usage:
#   pwsh ./Run-ActTests.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$WorkspaceRoot = $PSScriptRoot
$ActResultFile = Join-Path $WorkspaceRoot "act-result.txt"

# ─── Create/reset the result file ────────────────────────────────────────────
Set-Content -Path $ActResultFile -Value "# Act Test Results — Environment Matrix Generator`n`n" -Encoding UTF8

Write-Host "=== Environment Matrix Generator — Act Integration Tests ===" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceRoot"
Write-Host "Result file: $ActResultFile`n"

# ─── Set up a temporary git repo ─────────────────────────────────────────────
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-matrix-$(New-Guid)"
New-Item -ItemType Directory -Path $tmpDir | Out-Null

Write-Host "Created temp repo: $tmpDir" -ForegroundColor Yellow

try {
    # Copy all project files except the result file and .git
    $excludeNames = @('act-result.txt', '.git')
    Get-ChildItem -Path $WorkspaceRoot -Force |
        Where-Object { $_.Name -notin $excludeNames } |
        ForEach-Object {
            $dest = Join-Path $tmpDir $_.Name
            if ($_.PSIsContainer) {
                Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
            } else {
                Copy-Item -Path $_.FullName -Destination $dest -Force
            }
        }

    # Copy .actrc (sets the Docker image)
    $actrcSrc = Join-Path $WorkspaceRoot ".actrc"
    if (Test-Path $actrcSrc) {
        Copy-Item -Path $actrcSrc -Destination (Join-Path $tmpDir ".actrc") -Force
    }

    # Initialise git repo
    Push-Location $tmpDir
    & git init -b main              2>&1 | Out-Null
    & git config user.email "test@example.com" 2>&1 | Out-Null
    & git config user.name  "Test"             2>&1 | Out-Null
    & git add -A                    2>&1 | Out-Null
    & git commit -m "ci: all test cases"       2>&1 | Out-Null

    # ─── Run act ─────────────────────────────────────────────────────────────
    Write-Host "Running act push --rm --pull=false ..." -ForegroundColor Yellow
    $actOutput   = & act push --rm --pull=false 2>&1
    $actExitCode = $LASTEXITCODE

    $combined = $actOutput -join "`n"

    # ─── Write to act-result.txt ──────────────────────────────────────────────
    $bar = "=" * 70
    Add-Content -Path $ActResultFile -Value "$bar`n" -Encoding UTF8
    Add-Content -Path $ActResultFile -Value "RUN: act push --rm --pull=false`n" -Encoding UTF8
    Add-Content -Path $ActResultFile -Value "EXIT CODE: $actExitCode`n" -Encoding UTF8
    Add-Content -Path $ActResultFile -Value "$bar`n`n" -Encoding UTF8
    Add-Content -Path $ActResultFile -Value $combined -Encoding UTF8
    Add-Content -Path $ActResultFile -Value "`n`n$bar`n`n" -Encoding UTF8

    # Print to console
    $actOutput | ForEach-Object { Write-Host $_ }

    # ─── Assertions ──────────────────────────────────────────────────────────
    $failures = [System.Collections.Generic.List[string]]::new()

    function Assert-Contains {
        param([string]$Label, [string]$Expected)
        if ($combined -match [regex]::Escape($Expected)) {
            Write-Host "  [PASS] $Label" -ForegroundColor Green
        } else {
            $msg = "FAIL — $Label — expected '$Expected' not found"
            $failures.Add($msg)
            Write-Host "  [FAIL] $msg" -ForegroundColor Red
        }
    }

    # Fundamental: exit code and job success
    if ($actExitCode -ne 0) {
        $failures.Add("FAIL — act exited with code $actExitCode (expected 0)")
        Write-Host "  [FAIL] act exited with code $actExitCode" -ForegroundColor Red
    } else {
        Write-Host "  [PASS] act exit code = 0" -ForegroundColor Green
    }

    Assert-Contains "Job succeeded"          "Job succeeded"

    # All 24 Pester tests must pass
    Assert-Contains "Pester: Tests Passed 24" "Tests Passed: 24,"
    Assert-Contains "Pester: Failed 0"        "Failed: 0,"

    # ── Test case 1: basic fixture ──────────────────────────────────────────
    Write-Host "`n[Test case 1: basic-os-and-node]" -ForegroundColor Cyan
    Assert-Contains "basic: ubuntu-latest present"  '"ubuntu-latest"'
    Assert-Contains "basic: windows-latest present" '"windows-latest"'
    Assert-Contains "basic: node 18 present"        '"18"'
    Assert-Contains "basic: node 20 present"        '"20"'
    Assert-Contains "basic: max-parallel key"       '"max-parallel":'
    # Exact value check: max-parallel = 4
    Assert-Contains "basic: max-parallel = 4"       '"max-parallel": 4'
    # fail-fast = false
    Assert-Contains "basic: fail-fast = false"      '"fail-fast": false'

    # ── Test case 2: with-includes fixture ──────────────────────────────────
    Write-Host "`n[Test case 2: with-includes]" -ForegroundColor Cyan
    Assert-Contains "includes: macos-latest in include"  '"macos-latest"'
    Assert-Contains "includes: python 3.12 in include"   '"3.12"'
    Assert-Contains "includes: include key present"      '"include":'
    Assert-Contains "includes: max-parallel = 6"         '"max-parallel": 6'

    # ── Test case 3: with-excludes fixture ──────────────────────────────────
    Write-Host "`n[Test case 3: with-excludes]" -ForegroundColor Cyan
    Assert-Contains "excludes: exclude key present"      '"exclude":'
    Assert-Contains "excludes: node 16 present"          '"16"'
    Assert-Contains "excludes: fail-fast = true"         '"fail-fast": true'
    Assert-Contains "excludes: max-parallel = 4"         '"max-parallel": 4'

    # ── Summary ──────────────────────────────────────────────────────────────
    $summaryLine = if ($failures.Count -eq 0) {
        "## Summary: ALL ACT TESTS PASSED ($($failures.Count) failures)"
    } else {
        "## Summary: $($failures.Count) TEST(S) FAILED"
    }

    Add-Content -Path $ActResultFile -Value "`n$summaryLine`n" -Encoding UTF8
    foreach ($f in $failures) {
        Add-Content -Path $ActResultFile -Value "  - $f`n" -Encoding UTF8
    }

    Write-Host "`n$summaryLine" -ForegroundColor $(if ($failures.Count -eq 0) { 'Green' } else { 'Red' })

    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        exit 1
    }
    exit 0

} finally {
    Pop-Location -ErrorAction SilentlyContinue
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
