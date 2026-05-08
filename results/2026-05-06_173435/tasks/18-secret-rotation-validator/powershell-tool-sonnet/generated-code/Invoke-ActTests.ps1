# Invoke-ActTests.ps1
# Test harness that runs the GitHub Actions workflow through act (nektos/act).
# Sets up a temporary git repo with project files, runs `act push --rm`,
# captures output, asserts on exact expected values, and writes act-result.txt.
#
# Usage: pwsh ./Invoke-ActTests.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot  = $PSScriptRoot
$ResultFile   = Join-Path $ProjectRoot "act-result.txt"

# Clear any previous results
if (Test-Path $ResultFile) { Remove-Item $ResultFile }

# ── Helper: run a single act test case ──────────────────────────────────────
function Invoke-ActTestCase {
    param(
        [string]   $CaseName,
        [string]   $FixturePath,        # relative to ProjectRoot
        [string[]] $ExpectedStrings     # exact substrings that must appear in act output
    )

    Write-Host "`n=== Test Case: $CaseName ===" -ForegroundColor Cyan

    # Create a fresh temp directory for the isolated git repo
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$CaseName-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        # Copy all project files (including dotdirs like .github) then remove .git so git init starts clean
        bash -c "cp -r '$ProjectRoot/.' '$tempDir/' && rm -rf '$tempDir/.git' '$tempDir/act-result.txt' 2>/dev/null; true"

        # Replace the default fixture with the case-specific one if provided
        if ($FixturePath -and (Test-Path (Join-Path $ProjectRoot $FixturePath))) {
            $destFixture = Join-Path $tempDir "fixtures/secrets-standard.json"
            Copy-Item (Join-Path $ProjectRoot $FixturePath) $destFixture
        }

        # Initialise a git repo and commit all files
        Push-Location $tempDir
        try {
            git init -q
            git config user.email "test@example.com"
            git config user.name  "Test"
            git add -A
            git commit -q -m "test: $CaseName"
        } finally {
            Pop-Location
        }

        # Run act with --pull=false to use the local act-ubuntu-pwsh:latest image
        Write-Host "Running: act push --rm --pull=false" -ForegroundColor Yellow
        $actOutput = & act push --rm --pull=false --directory $tempDir 2>&1 | Out-String
        $actExitCode = $LASTEXITCODE

        Write-Host $actOutput

        # Delimiter header for act-result.txt
        $delimiter = @"
===== TEST CASE: $CaseName =====
Exit code: $actExitCode
"@
        Add-Content -Path $ResultFile -Value $delimiter
        Add-Content -Path $ResultFile -Value $actOutput
        Add-Content -Path $ResultFile -Value "===== END: $CaseName =====`n"

        # Assert exit code 0
        if ($actExitCode -ne 0) {
            throw "act exited with code $actExitCode for test case '$CaseName'"
        }

        # Assert "Job succeeded" appears
        if ($actOutput -notmatch "Job succeeded") {
            throw "Expected 'Job succeeded' in act output for '$CaseName'. Output:`n$actOutput"
        }

        # Assert each expected string appears in the output
        foreach ($expected in $ExpectedStrings) {
            if ($actOutput -notmatch [regex]::Escape($expected)) {
                throw "Expected '$expected' in act output for '$CaseName'. Output:`n$actOutput"
            }
        }

        Write-Host "PASS: $CaseName" -ForegroundColor Green
        return $true

    } finally {
        # Clean up temp directory
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ── Test Cases ───────────────────────────────────────────────────────────────

$allPassed = $true

try {
    # Test Case 1: Standard fixture (expired, warning, ok)
    # Reference date 2024-06-01 with secrets-standard.json
    # Expected: DB_PASSWORD=EXPIRED, API_KEY=WARNING, JWT_SECRET=OK
    $result1 = Invoke-ActTestCase `
        -CaseName "standard-fixture" `
        -FixturePath "fixtures/secrets-standard.json" `
        -ExpectedStrings @(
            "All tests passed"
            "Expired count: 1"
            "Warning count: 1"
            "OK count: 1"
            "Expired secret: DB_PASSWORD"
            "Warning secret: API_KEY"
            "OK secret: JWT_SECRET"
            "All assertions passed"
        )
} catch {
    $allPassed = $false
    Write-Host "FAIL: standard-fixture - $_" -ForegroundColor Red
    Add-Content -Path $ResultFile -Value "ERROR: standard-fixture - $_"
}

# ── Final Summary ─────────────────────────────────────────────────────────────

Write-Host "`n========== Act Test Summary ==========" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "All act test cases PASSED" -ForegroundColor Green
    Write-Host "Results written to: $ResultFile"
    exit 0
} else {
    Write-Host "One or more act test cases FAILED" -ForegroundColor Red
    Write-Host "See $ResultFile for details"
    exit 1
}
