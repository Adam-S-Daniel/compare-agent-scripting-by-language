# Run-ActTests.ps1
# Test harness that executes each test case through the GitHub Actions workflow
# via `act push --rm`, captures output, and asserts on exact expected values.
#
# Usage:  pwsh Run-ActTests.ps1
# Output: act-result.txt (appended with delimited output for each case)

param(
    [string]$ActResultFile = "$PSScriptRoot/act-result.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ──────────────────────────────────────────────────────────────
# Test case definitions
# ──────────────────────────────────────────────────────────────
$testCases = @(
    @{
        Name            = "patch-bump"
        InitialVersion  = "1.0.0"
        CommitFixture   = "fixtures/patch-commits.txt"
        ExpectedVersion = "1.0.1"
        ExpectedBump    = "patch"
    },
    @{
        Name            = "minor-bump"
        InitialVersion  = "1.1.0"
        CommitFixture   = "fixtures/minor-commits.txt"
        ExpectedVersion = "1.2.0"
        ExpectedBump    = "minor"
    },
    @{
        Name            = "major-bump"
        InitialVersion  = "1.9.9"
        CommitFixture   = "fixtures/major-commits.txt"
        ExpectedVersion = "2.0.0"
        ExpectedBump    = "major"
    }
)

# ──────────────────────────────────────────────────────────────
# Helper: copy project files into a temp git repo
# ──────────────────────────────────────────────────────────────
function New-TempRepo {
    param(
        [string]$SourceDir,
        [string]$InitialVersion,
        [string]$CommitFixturePath   # relative path within SourceDir
    )

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tmpDir | Out-Null

    # Copy project files (exclude .git to avoid conflicts)
    $items = Get-ChildItem -Path $SourceDir -Force |
             Where-Object { $_.Name -ne ".git" }
    foreach ($item in $items) {
        Copy-Item -Path $item.FullName -Destination $tmpDir -Recurse -Force
    }

    # Seed the version file
    $InitialVersion | Set-Content (Join-Path $tmpDir "version.txt") -NoNewline

    # Seed commits.txt from the fixture
    $fixtureAbs = Join-Path $SourceDir $CommitFixturePath
    Copy-Item $fixtureAbs (Join-Path $tmpDir "commits.txt") -Force

    # Initialize git repo (act requires one)
    Push-Location $tmpDir
    git init -q
    git config user.email "test@example.com"
    git config user.name  "Test"
    git add -A
    git commit -q -m "initial"
    Pop-Location

    return $tmpDir
}

# ──────────────────────────────────────────────────────────────
# Initialise act-result.txt
# ──────────────────────────────────────────────────────────────
"Act Test Run — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Set-Content $ActResultFile
"=" * 72 | Add-Content $ActResultFile

$allPassed = $true

# ──────────────────────────────────────────────────────────────
# Run each test case
# ──────────────────────────────────────────────────────────────
foreach ($tc in $testCases) {
    Write-Host ""
    Write-Host "━━━ Running test case: $($tc.Name) ━━━" -ForegroundColor Cyan

    "" | Add-Content $ActResultFile
    "=== TEST CASE: $($tc.Name) ===" | Add-Content $ActResultFile
    "Initial version : $($tc.InitialVersion)" | Add-Content $ActResultFile
    "Commit fixture  : $($tc.CommitFixture)"  | Add-Content $ActResultFile
    "Expected version: $($tc.ExpectedVersion)" | Add-Content $ActResultFile
    "Expected bump   : $($tc.ExpectedBump)"   | Add-Content $ActResultFile
    "--- act output ---" | Add-Content $ActResultFile

    $tmpRepo = New-TempRepo `
        -SourceDir       $PSScriptRoot `
        -InitialVersion  $tc.InitialVersion `
        -CommitFixturePath $tc.CommitFixture

    try {
        Push-Location $tmpRepo

        # Run only the run-bumper job so the test stays fast;
        # unit-tests and workflow-validation are run in their own passes.
        $actArgs = @(
            "push", "--rm",
            "--job", "run-bumper",
            "--no-cache-server",
            "--detect-event"
        )

        Write-Host "Running: act $($actArgs -join ' ')" -ForegroundColor DarkGray
        $actOutput = & act @actArgs 2>&1
        $exitCode  = $LASTEXITCODE

        $actOutput | Add-Content $ActResultFile
        "" | Add-Content $ActResultFile

        # ── Assert exit code ──────────────────────────────────
        if ($exitCode -ne 0) {
            $msg = "FAIL [$($tc.Name)]: act exited with code $exitCode"
            Write-Host $msg -ForegroundColor Red
            $msg | Add-Content $ActResultFile
            $allPassed = $false
            continue
        }

        # ── Assert "Job succeeded" ────────────────────────────
        $outputStr = $actOutput -join "`n"
        if ($outputStr -notmatch "Job succeeded") {
            $msg = "FAIL [$($tc.Name)]: 'Job succeeded' not found in act output"
            Write-Host $msg -ForegroundColor Red
            $msg | Add-Content $ActResultFile
            $allPassed = $false
            continue
        }

        # ── Assert exact expected version in output ───────────
        if ($outputStr -notmatch "NEW_VERSION=$([regex]::Escape($tc.ExpectedVersion))") {
            $msg = "FAIL [$($tc.Name)]: expected 'NEW_VERSION=$($tc.ExpectedVersion)' in act output"
            Write-Host $msg -ForegroundColor Red
            $msg | Add-Content $ActResultFile
            $allPassed = $false
            continue
        }

        # ── Assert exact expected bump type in output ─────────
        if ($outputStr -notmatch "BUMP_TYPE=$([regex]::Escape($tc.ExpectedBump))") {
            $msg = "FAIL [$($tc.Name)]: expected 'BUMP_TYPE=$($tc.ExpectedBump)' in act output"
            Write-Host $msg -ForegroundColor Red
            $msg | Add-Content $ActResultFile
            $allPassed = $false
            continue
        }

        $ok = "PASS [$($tc.Name)]: version=$($tc.ExpectedVersion) bump=$($tc.ExpectedBump)"
        Write-Host $ok -ForegroundColor Green
        $ok | Add-Content $ActResultFile

    } finally {
        Pop-Location
        Remove-Item $tmpRepo -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ──────────────────────────────────────────────────────────────
# Run unit-tests and workflow-validation jobs (shared, not per-case)
# ──────────────────────────────────────────────────────────────
foreach ($job in @("unit-tests", "workflow-validation")) {
    Write-Host ""
    Write-Host "━━━ Running job: $job ━━━" -ForegroundColor Cyan

    "" | Add-Content $ActResultFile
    "=== JOB: $job ===" | Add-Content $ActResultFile
    "--- act output ---" | Add-Content $ActResultFile

    $tmpRepo = New-TempRepo `
        -SourceDir         $PSScriptRoot `
        -InitialVersion    "1.0.0" `
        -CommitFixturePath "fixtures/patch-commits.txt"

    try {
        Push-Location $tmpRepo

        $actArgs = @("push", "--rm", "--job", $job, "--no-cache-server", "--detect-event")
        Write-Host "Running: act $($actArgs -join ' ')" -ForegroundColor DarkGray
        $actOutput = & act @actArgs 2>&1
        $exitCode  = $LASTEXITCODE

        $actOutput | Add-Content $ActResultFile
        "" | Add-Content $ActResultFile

        if ($exitCode -ne 0) {
            $msg = "FAIL [$job]: act exited with code $exitCode"
            Write-Host $msg -ForegroundColor Red
            $msg | Add-Content $ActResultFile
            $allPassed = $false
            continue
        }

        $outputStr = $actOutput -join "`n"
        if ($outputStr -notmatch "Job succeeded") {
            $msg = "FAIL [$job]: 'Job succeeded' not found in act output"
            Write-Host $msg -ForegroundColor Red
            $msg | Add-Content $ActResultFile
            $allPassed = $false
            continue
        }

        $ok = "PASS [$job]"
        Write-Host $ok -ForegroundColor Green
        $ok | Add-Content $ActResultFile

    } finally {
        Pop-Location
        Remove-Item $tmpRepo -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ──────────────────────────────────────────────────────────────
# Final summary
# ──────────────────────────────────────────────────────────────
"" | Add-Content $ActResultFile
"=" * 72 | Add-Content $ActResultFile
if ($allPassed) {
    $summary = "ALL TESTS PASSED"
    Write-Host "`n$summary" -ForegroundColor Green
} else {
    $summary = "SOME TESTS FAILED — see above"
    Write-Host "`n$summary" -ForegroundColor Red
}
$summary | Add-Content $ActResultFile

Write-Host "`nResults written to: $ActResultFile" -ForegroundColor Cyan

if (-not $allPassed) {
    exit 1
}
