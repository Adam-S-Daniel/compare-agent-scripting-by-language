# Invoke-ActTests.ps1
#
# Act integration test harness.
# Runs the GitHub Actions workflow through 'act' (nektos/act) in Docker,
# captures output, asserts on EXACT expected values, and saves results to
# act-result.txt in the current working directory.
#
# Usage:
#   pwsh ./Invoke-ActTests.ps1
#
# Requirements: act and Docker must be installed and running.

$ErrorActionPreference = "Stop"

$WorkingDir   = $PSScriptRoot
$ActResultFile = Join-Path $WorkingDir "act-result.txt"

# ─── Helper ──────────────────────────────────────────────────────────────────
function Assert-Contains {
    param([string]$Text, [string]$Pattern, [string]$Description)
    if ($Text -notmatch [regex]::Escape($Pattern)) {
        # Try as a literal contains first
        if (-not $Text.Contains($Pattern)) {
            Write-Error "ASSERTION FAILED: '$Description' — expected to find: $Pattern"
            exit 1
        }
    }
    Write-Host "  PASS: $Description"
}

function Assert-Regex {
    param([string]$Text, [string]$Pattern, [string]$Description)
    if ($Text -notmatch $Pattern) {
        Write-Error "ASSERTION FAILED: '$Description' — pattern '$Pattern' not found"
        exit 1
    }
    Write-Host "  PASS: $Description"
}

# ─── Initialise result file ───────────────────────────────────────────────────
Set-Content -Path $ActResultFile -Value "" -Encoding UTF8
Write-Host ""
Write-Host "=== ACT INTEGRATION TESTS ==="
Write-Host "Results will be written to: $ActResultFile"
Write-Host ""

# ─── Test Case 1: Full aggregation with all three fixture files ───────────────
Write-Host "--- Test Case 1: Full Aggregation (JUnit XML x2 + JSON x1) ---"

# Build an isolated temp git repo so act has a clean context
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
Write-Host "Temp repo: $tmpDir"

try {
    # Copy all project files into the temp repo, including hidden files/dirs
    # Use robocopy-style approach: copy everything then remove excluded items
    Get-ChildItem -Path $WorkingDir -Force | Where-Object { $_.Name -notin @(".git", "act-result.txt") } | ForEach-Object {
        $dest = Join-Path $tmpDir $_.Name
        if ($_.PSIsContainer) {
            Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
        }
        else {
            Copy-Item -Path $_.FullName -Destination $dest -Force
        }
    }

    Push-Location $tmpDir

    # Initialise a minimal git repo and commit all files
    git init -b main              2>&1 | Out-Null
    git config user.email "ci@ci" 2>&1 | Out-Null
    git config user.name  "CI"    2>&1 | Out-Null
    git add -A                    2>&1 | Out-Null
    git commit -m "chore: test"   2>&1 | Out-Null

    Write-Host "Running: act push --rm --pull=false"
    Write-Host "(This may take 30-90 seconds for Docker container startup)"

    # --pull=false: use the locally available act-ubuntu-pwsh:latest image
    $actOutput  = & act push --rm --pull=false 2>&1
    $actExitCode = $LASTEXITCODE

    $outputStr = $actOutput -join "`n"

    # ─── Append to act-result.txt ─────────────────────────────────────────────
    Add-Content -Path $ActResultFile -Value "=== TEST CASE 1: Full Aggregation ===" -Encoding UTF8
    Add-Content -Path $ActResultFile -Value "Exit code: $actExitCode"             -Encoding UTF8
    Add-Content -Path $ActResultFile -Value $outputStr                             -Encoding UTF8
    Add-Content -Path $ActResultFile -Value "=== END TEST CASE 1 ==="             -Encoding UTF8
    Add-Content -Path $ActResultFile -Value ""                                     -Encoding UTF8

    Write-Host ""
    Write-Host "--- Assertions for Test Case 1 ---"

    # 1. act must exit 0
    if ($actExitCode -ne 0) {
        Write-Error "ASSERTION FAILED: act exited with code $actExitCode (expected 0)"
        exit 1
    }
    Write-Host "  PASS: act exited with code 0"

    # 2. Every job must succeed
    Assert-Regex -Text $outputStr -Pattern "Job succeeded" `
        -Description "Job succeeded"

    # 3. Exact values in the aggregator output
    Assert-Contains -Text $outputStr -Pattern "| Total Tests | 9 |" `
        -Description "Total Tests = 9"

    Assert-Contains -Text $outputStr -Pattern "| Passed | 7 |" `
        -Description "Passed = 7"

    Assert-Contains -Text $outputStr -Pattern "| Failed | 1 |" `
        -Description "Failed = 1"

    Assert-Contains -Text $outputStr -Pattern "| Skipped | 1 |" `
        -Description "Skipped = 1"

    Assert-Contains -Text $outputStr -Pattern "| Duration (s) | 3.40 |" `
        -Description "Duration = 3.40 s"

    # 4. Flaky test detection
    Assert-Contains -Text $outputStr -Pattern "test_register" `
        -Description "Flaky test 'test_register' appears in output"

    # 5. Pester tests passed — the Pester summary embeds ANSI codes between tokens
    #    so we check for the "Tests Passed:" prefix and rely on the step succeeding
    #    (act would exit non-zero if Pester reported failures with Run.Exit=$true)
    Assert-Regex -Text $outputStr -Pattern "Tests Passed: \d+" `
        -Description "Pester: 'Tests Passed:' summary line found"

    Write-Host ""
    Write-Host "All assertions passed for Test Case 1."
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== ALL ACT TESTS PASSED ==="
Write-Host "Results saved to: $ActResultFile"
