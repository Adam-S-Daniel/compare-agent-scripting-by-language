# Run-ActTests.ps1 - Integration test harness
# For each test case: sets up an isolated git repo, runs the GitHub Actions workflow
# via `act push --rm`, captures output, and asserts on exact expected values.
# All results are appended to act-result.txt.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot   = $PSScriptRoot
$actResultFile = Join-Path $projectRoot "act-result.txt"

# Wipe previous results
Set-Content $actResultFile -Value "Act Integration Test Results`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -Force

# ── helper: copy project files into a temp directory ─────────────────────────
function Copy-ProjectFiles {
    param([string]$Source, [string]$Destination)

    $excludes = @('act-result.txt', '.git', '.claude')

    Get-ChildItem -LiteralPath $Source -Force | Where-Object {
        $_.Name -notin $excludes
    } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

# ── helper: run a single test case ───────────────────────────────────────────
function Invoke-ActTestCase {
    param(
        [string]$Name,
        [hashtable]$Fixture,
        [string[]]$ExpectedPatterns   # strings that MUST appear in act output
    )

    $sep = "=" * 70
    $header = @"

$sep
TEST CASE: $Name
$sep
"@

    Write-Host $header
    Add-Content $actResultFile $header

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(New-Guid)"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        Copy-ProjectFiles -Source $projectRoot -Destination $tempDir

        # Write the per-test fixture to the well-known path the workflow reads
        $Fixture | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $tempDir "test-fixture.json")

        Push-Location $tempDir
        git init -b main 2>&1 | Out-Null
        git config user.email "test@test.com" 2>&1 | Out-Null
        git config user.name "Test Runner" 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -m "test: $Name" 2>&1 | Out-Null

        Write-Host "Running: act push --rm --pull=false"
        $actOutput = act push --rm --pull=false 2>&1
        $actExitCode = $LASTEXITCODE

        $outputStr = $actOutput -join "`n"

        # Append full output to results file
        Add-Content $actResultFile "Exit code: $actExitCode"
        Add-Content $actResultFile ""
        Add-Content $actResultFile $outputStr
        Add-Content $actResultFile ""

        # ── assertions ───────────────────────────────────────────────────────
        $passed = $true

        if ($actExitCode -ne 0) {
            Write-Error "FAIL [$Name]: act exited with code $actExitCode"
            $passed = $false
        }

        if ($outputStr -notmatch "Job succeeded") {
            Write-Error "FAIL [$Name]: 'Job succeeded' not found in act output"
            $passed = $false
        }

        foreach ($pattern in $ExpectedPatterns) {
            if ($outputStr -notmatch [regex]::Escape($pattern)) {
                Write-Error "FAIL [$Name]: Expected pattern not found: '$pattern'"
                $passed = $false
            }
        }

        if ($passed) {
            $msg = "RESULT: PASSED — $Name"
            Write-Host $msg -ForegroundColor Green
            Add-Content $actResultFile $msg
        } else {
            $msg = "RESULT: FAILED — $Name"
            Write-Host $msg -ForegroundColor Red
            Add-Content $actResultFile $msg
            throw "Test case '$Name' failed. See act-result.txt for details."
        }

    } finally {
        Pop-Location
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ════════════════════════════════════════════════════════════════════════════
# Test Case 1 — Basic matrix: 2 OS × 2 language versions, max-parallel, fail-fast
# Expected total-combinations = 4
# ════════════════════════════════════════════════════════════════════════════
Invoke-ActTestCase -Name "Basic Matrix (2x2, max-parallel=4, fail-fast=false)" `
    -Fixture @{
        os                  = @("ubuntu-latest", "windows-latest")
        "language-version"  = @("3.10", "3.11")
        maxParallel         = 4
        failFast            = $false
    } `
    -ExpectedPatterns @(
        "total-combinations: 4",
        "max-parallel: 4",
        "fail-fast: False"
    )

# ════════════════════════════════════════════════════════════════════════════
# Test Case 2 — Advanced matrix: 2×2×2 + 1 include = 9 combinations,
#               with exclude, max-parallel=3, fail-fast=true
# ════════════════════════════════════════════════════════════════════════════
Invoke-ActTestCase -Name "Advanced Matrix (2x2x2 + include, fail-fast=true)" `
    -Fixture @{
        os                  = @("ubuntu-latest", "windows-latest")
        "language-version"  = @("3.10", "3.11")
        "node-version"      = @("18", "20")
        include             = @(
            [ordered]@{ os = "macos-latest"; "language-version" = "3.12"; "node-version" = "20"; experimental = $true }
        )
        exclude             = @(
            [ordered]@{ os = "windows-latest"; "language-version" = "3.10"; "node-version" = "18" }
        )
        maxParallel         = 3
        failFast            = $true
    } `
    -ExpectedPatterns @(
        "total-combinations: 9",
        "max-parallel: 3",
        "fail-fast: True"
    )

Write-Host "`nAll act integration tests passed!" -ForegroundColor Green
Add-Content $actResultFile "`nAll test cases PASSED."
