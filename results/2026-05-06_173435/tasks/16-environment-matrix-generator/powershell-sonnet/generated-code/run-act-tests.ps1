# run-act-tests.ps1
# Test harness: runs each fixture through GitHub Actions via `act push --rm`.
# Appends all act output to act-result.txt, then asserts on exact expected
# values.  Exits 0 only when every assertion passes.
#
# Usage:  pwsh -File ./run-act-tests.ps1

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptDir    = $PSScriptRoot
$actResultFile = Join-Path $scriptDir "act-result.txt"

# ── Pre-flight: validate workflow with actionlint ────────────────────────────
Set-Content -Path $actResultFile -Value @"
# act-result.txt
# Environment Matrix Generator — act test harness output
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

"@

Write-Host ""
Write-Host "=== Pre-flight: actionlint ===" -ForegroundColor Cyan
$wfFile     = Join-Path $scriptDir ".github/workflows/environment-matrix-generator.yml"
$lintOutput = & actionlint $wfFile 2>&1
$lintExit   = $LASTEXITCODE

Add-Content -Path $actResultFile -Value @"
============================================================
PRE-FLIGHT: actionlint
Exit code: $lintExit
$($lintOutput -join "`n")
============================================================

"@

if ($lintExit -ne 0) {
    Write-Host "FAIL: actionlint exited $lintExit" -ForegroundColor Red
    Write-Host ($lintOutput -join "`n")
    exit 1
}
Write-Host "PASS: actionlint exit code 0" -ForegroundColor Green

# ── Test case definitions ────────────────────────────────────────────────────
# Each case has:
#   Name          – human label
#   FixtureFile   – relative path to fixture (or $null to omit config.json)
#   Expected      – strings that MUST appear in act output (exact match)
$testCases = @(
    @{
        Name        = "basic-config"
        FixtureFile = "fixtures/basic-config.json"
        Expected    = @(
            '"ubuntu-latest"',
            '"windows-latest"',
            '"18"',
            '"20"',
            '"fail-fast": false',
            '"max-parallel": 4'
        )
    },
    @{
        Name        = "full-config"
        FixtureFile = "fixtures/full-config.json"
        Expected    = @(
            '"ubuntu-latest"',
            '"windows-latest"',
            '"macos-latest"',
            '"tag": "latest"',
            '"fail-fast": true',
            '"max-parallel": 10'
        )
    }
)

# ── Helper: set up a temp git repo and run act ───────────────────────────────
function Invoke-ActTestCase {
    param(
        [string]$Name,
        [string]$FixtureFile,
        [string[]]$Expected
    )

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$Name-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        # Copy all project files into the temp repo
        foreach ($item in @("New-BuildMatrix.ps1", "New-BuildMatrix.Tests.ps1",
                             ".github", "fixtures")) {
            $src = Join-Path $scriptDir $item
            if (Test-Path -Path $src -PathType Container) {
                Copy-Item -Path $src -Destination $tempDir -Recurse -Force
            } elseif (Test-Path -Path $src -PathType Leaf) {
                Copy-Item -Path $src -Destination $tempDir -Force
            }
        }

        # Copy .actrc so act uses the custom image
        $actrcSrc = Join-Path $scriptDir ".actrc"
        if (Test-Path $actrcSrc) {
            Copy-Item -Path $actrcSrc -Destination $tempDir -Force
        }

        # Place fixture as config.json (picked up by the workflow's last step)
        if ($FixtureFile) {
            $fixSrc = Join-Path $scriptDir $FixtureFile
            Copy-Item -Path $fixSrc -Destination (Join-Path $tempDir "config.json") -Force
        }

        # Initialize a minimal git repo so act can detect branch "main"
        Push-Location $tempDir
        try {
            git init --initial-branch=main 2>&1 | Out-Null
            git config user.email "test@example.com"
            git config user.name  "CI Test"
            git add -A 2>&1 | Out-Null
            git commit -m "ci: add project for $Name" 2>&1 | Out-Null
        } finally {
            Pop-Location
        }

        # Run act; --pull=false uses the local image without trying Docker Hub
        Write-Host "  Running: act push --rm --pull=false (in $tempDir)" -ForegroundColor Yellow
        Push-Location $tempDir
        try {
            $actOutput = & act push --rm --pull=false 2>&1
            $actExit   = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        return @{
            Output   = $actOutput
            ExitCode = $actExit
        }
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ── Run each test case (limit: 3 act invocations total) ─────────────────────
$actRunCount = 0
$allPassed   = $true
$divider     = "=" * 60

foreach ($tc in $testCases) {
    if ($actRunCount -ge 3) {
        Write-Warning "Reached 3-run limit; skipping '$($tc.Name)'."
        break
    }

    Write-Host ""
    Write-Host $divider -ForegroundColor Cyan
    Write-Host "TEST CASE: $($tc.Name)" -ForegroundColor Cyan
    Write-Host $divider -ForegroundColor Cyan

    $r = Invoke-ActTestCase -Name $tc.Name `
                            -FixtureFile $tc.FixtureFile `
                            -Expected $tc.Expected
    $actRunCount++

    $outputStr = $r.Output -join "`n"

    # Persist to act-result.txt
    Add-Content -Path $actResultFile -Value @"

$divider
TEST CASE: $($tc.Name)
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Exit code: $($r.ExitCode)
$divider
$outputStr

"@

    # ── Assertions ────────────────────────────────────────────────────────────
    $casePassed = $true

    # 1. act exit code must be 0
    if ($r.ExitCode -eq 0) {
        Write-Host "  PASS: act exit code = 0" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: act exit code = $($r.ExitCode) (expected 0)" -ForegroundColor Red
        Write-Host "  --- last 30 lines ---"
        $r.Output | Select-Object -Last 30 | ForEach-Object { Write-Host "  $_" }
        $casePassed = $false
    }

    # 2. "Job succeeded" must appear (validates every job ran without errors)
    if ($outputStr -match "Job succeeded") {
        Write-Host "  PASS: 'Job succeeded' found" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: 'Job succeeded' not found in output" -ForegroundColor Red
        $casePassed = $false
    }

    # 3. Exact expected strings must appear in the output
    foreach ($str in $tc.Expected) {
        if ($outputStr -match [regex]::Escape($str)) {
            Write-Host "  PASS: found expected: $str" -ForegroundColor Green
        } else {
            Write-Host "  FAIL: missing expected: $str" -ForegroundColor Red
            $casePassed = $false
        }
    }

    if (-not $casePassed) { $allPassed = $false }
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host $divider
$resultLine = if ($allPassed) {
    "RESULT: ALL TESTS PASSED ($actRunCount act run(s))"
} else {
    "RESULT: SOME TESTS FAILED ($actRunCount act run(s))"
}

Add-Content -Path $actResultFile -Value @"

$divider
$resultLine
$divider
"@

if ($allPassed) {
    Write-Host $resultLine -ForegroundColor Green
    exit 0
} else {
    Write-Host $resultLine -ForegroundColor Red
    exit 1
}
