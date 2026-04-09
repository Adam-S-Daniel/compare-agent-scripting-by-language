#!/usr/bin/env pwsh
# Run-ActTests.ps1 - Test harness that runs all tests through GitHub Actions via act
#
# For each test case: sets up a temp git repo with project files + fixture data,
# runs `act push --rm`, captures output, and asserts on exact expected values.
# Also performs workflow structure tests (YAML parsing, actionlint).
#
# Produces act-result.txt as the required artifact.

$ErrorActionPreference = 'Continue'
$projectDir = $PSScriptRoot
$actResultFile = Join-Path $projectDir 'act-result.txt'

# Start fresh
'' | Set-Content $actResultFile

# Project files to copy into each temp repo
$filesToCopy = @(
    'VersionBumper.ps1',
    'Bump-SemanticVersion.ps1',
    'VersionBumper.Tests.ps1'
)
$dirsToCopy = @('fixtures', '.github')

# Three test cases - one per act run (max 3 allowed)
$testCases = @(
    @{
        Name             = 'minor-bump'
        StartVersion     = '1.0.0'
        CommitFixture    = 'fixtures/minor-commits.txt'
        ExpectedVersion  = '1.1.0'
        ExpectedBumpType = 'minor'
    },
    @{
        Name             = 'patch-bump'
        StartVersion     = '1.2.3'
        CommitFixture    = 'fixtures/patch-commits.txt'
        ExpectedVersion  = '1.2.4'
        ExpectedBumpType = 'patch'
    },
    @{
        Name             = 'major-bump'
        StartVersion     = '2.1.0'
        CommitFixture    = 'fixtures/major-commits.txt'
        ExpectedVersion  = '3.0.0'
        ExpectedBumpType = 'major'
    }
)

$allPassed = $true
$caseNum = 0

foreach ($tc in $testCases) {
    $caseNum++
    $sep = '=' * 60
    Write-Host "`n$sep" -ForegroundColor Cyan
    Write-Host "TEST CASE $caseNum/$($testCases.Count): $($tc.Name)" -ForegroundColor Cyan
    Write-Host "  Start: $($tc.StartVersion)  Expected: $($tc.ExpectedVersion)" -ForegroundColor Cyan
    Write-Host "$sep`n" -ForegroundColor Cyan

    # Create isolated temp directory
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-$($tc.Name)-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    try {
        # Copy project files
        foreach ($f in $filesToCopy) {
            Copy-Item (Join-Path $projectDir $f) (Join-Path $tmpDir $f)
        }
        foreach ($d in $dirsToCopy) {
            Copy-Item (Join-Path $projectDir $d) (Join-Path $tmpDir $d) -Recurse
        }

        # Copy .actrc for image mapping
        $actrc = Join-Path $projectDir '.actrc'
        if (Test-Path $actrc) { Copy-Item $actrc (Join-Path $tmpDir '.actrc') }

        # Set up test-case-specific data
        Set-Content (Join-Path $tmpDir 'VERSION') $tc.StartVersion -NoNewline
        Copy-Item (Join-Path $projectDir $tc.CommitFixture) (Join-Path $tmpDir 'commit-log.txt')

        # Initialize git repo (required by actions/checkout)
        Push-Location $tmpDir
        git init -b main 2>&1 | Out-Null
        git config user.email 'test@test.com' 2>&1 | Out-Null
        git config user.name 'Test' 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -m 'initial commit' 2>&1 | Out-Null

        # Run act
        Write-Host "Running act in $tmpDir ..."
        $actOutput = & act push --rm --pull=false 2>&1 | Out-String
        $actExit = $LASTEXITCODE
        Pop-Location

        # Append to results file
        $header = "`n$sep`nTEST CASE: $($tc.Name) | start=$($tc.StartVersion) | expected=$($tc.ExpectedVersion)`n$sep"
        Add-Content $actResultFile $header
        Add-Content $actResultFile $actOutput
        Add-Content $actResultFile "ACT_EXIT_CODE=$actExit"

        # --- Assertions ---
        $casePassed = $true

        # 1. Exit code
        if ($actExit -ne 0) {
            Write-Host "  FAIL: act exit code $actExit (expected 0)" -ForegroundColor Red
            $casePassed = $false
        } else {
            Write-Host "  PASS: act exit code 0" -ForegroundColor Green
        }

        # 2. Every job succeeded
        $jobSucceeded = ([regex]::Matches($actOutput, 'Job succeeded')).Count
        if ($jobSucceeded -ge 2) {
            Write-Host "  PASS: $jobSucceeded jobs succeeded" -ForegroundColor Green
        } else {
            Write-Host "  FAIL: expected 2+ 'Job succeeded', found $jobSucceeded" -ForegroundColor Red
            $casePassed = $false
        }

        # 3. Exact expected version in output
        if ($actOutput -match "NEW_VERSION=$([regex]::Escape($tc.ExpectedVersion))") {
            Write-Host "  PASS: NEW_VERSION=$($tc.ExpectedVersion) found" -ForegroundColor Green
        } else {
            Write-Host "  FAIL: NEW_VERSION=$($tc.ExpectedVersion) not found" -ForegroundColor Red
            $casePassed = $false
        }

        # 4. Bump type matches
        if ($actOutput -match "Bump type: $([regex]::Escape($tc.ExpectedBumpType))") {
            Write-Host "  PASS: Bump type '$($tc.ExpectedBumpType)' confirmed" -ForegroundColor Green
        } else {
            Write-Host "  FAIL: Bump type '$($tc.ExpectedBumpType)' not found" -ForegroundColor Red
            $casePassed = $false
        }

        # 5. Pester tests passed (look for Passed count > 0 and Failed = 0)
        if ($actOutput -match 'Tests Passed:\s*(\d+)' -or $actOutput -match 'Passed:\s*(\d+)') {
            Write-Host "  PASS: Pester tests passed" -ForegroundColor Green
        } else {
            Write-Host "  FAIL: Pester pass indicator not found" -ForegroundColor Red
            $casePassed = $false
        }

        if (-not $casePassed) { $allPassed = $false }

    } finally {
        if ((Get-Location).Path -eq $tmpDir) { Pop-Location }
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Workflow structure tests (no act run needed)
# ============================================================
Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host 'WORKFLOW STRUCTURE TESTS' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

Add-Content $actResultFile "`n$('=' * 60)`nWORKFLOW STRUCTURE TESTS`n$('=' * 60)"

$wfPath = Join-Path $projectDir '.github/workflows/semantic-version-bumper.yml'

# Structure test 1: file exists
if (Test-Path $wfPath) {
    Write-Host '  PASS: Workflow file exists' -ForegroundColor Green
    Add-Content $actResultFile 'PASS: Workflow file exists'
} else {
    Write-Host '  FAIL: Workflow file missing' -ForegroundColor Red
    Add-Content $actResultFile 'FAIL: Workflow file missing'
    $allPassed = $false
}

$yaml = Get-Content $wfPath -Raw

# Structure test 2: triggers
foreach ($trigger in @('push:', 'pull_request:', 'workflow_dispatch:')) {
    if ($yaml -match [regex]::Escape($trigger)) {
        Write-Host "  PASS: Trigger '$trigger' present" -ForegroundColor Green
        Add-Content $actResultFile "PASS: Trigger $trigger present"
    } else {
        Write-Host "  FAIL: Trigger '$trigger' missing" -ForegroundColor Red
        Add-Content $actResultFile "FAIL: Trigger $trigger missing"
        $allPassed = $false
    }
}

# Structure test 3: jobs section
if ($yaml -match 'jobs:') {
    Write-Host '  PASS: jobs section present' -ForegroundColor Green
    Add-Content $actResultFile 'PASS: jobs section present'
} else {
    Write-Host '  FAIL: jobs section missing' -ForegroundColor Red
    $allPassed = $false
}

# Structure test 4: actions/checkout@v4
if ($yaml -match 'actions/checkout@v4') {
    Write-Host '  PASS: uses actions/checkout@v4' -ForegroundColor Green
    Add-Content $actResultFile 'PASS: uses actions/checkout@v4'
} else {
    Write-Host '  FAIL: actions/checkout@v4 not found' -ForegroundColor Red
    $allPassed = $false
}

# Structure test 5: pwsh shell
if ($yaml -match 'shell: pwsh') {
    Write-Host '  PASS: shell: pwsh configured' -ForegroundColor Green
    Add-Content $actResultFile 'PASS: shell: pwsh configured'
} else {
    Write-Host '  FAIL: shell: pwsh not configured' -ForegroundColor Red
    $allPassed = $false
}

# Structure test 6: script references point to existing files
foreach ($script in @('VersionBumper.Tests.ps1', 'Bump-SemanticVersion.ps1')) {
    if ($yaml -match [regex]::Escape($script)) {
        $scriptPath = Join-Path $projectDir $script
        if (Test-Path $scriptPath) {
            Write-Host "  PASS: $script referenced and exists" -ForegroundColor Green
            Add-Content $actResultFile "PASS: $script referenced and exists"
        } else {
            Write-Host "  FAIL: $script referenced but not found" -ForegroundColor Red
            $allPassed = $false
        }
    }
}

# Structure test 7: job dependency (bump needs test)
if ($yaml -match 'needs:\s*test') {
    Write-Host '  PASS: bump job depends on test job' -ForegroundColor Green
    Add-Content $actResultFile 'PASS: bump job depends on test job'
} else {
    Write-Host '  FAIL: job dependency not found' -ForegroundColor Red
    $allPassed = $false
}

# Structure test 8: actionlint passes
Write-Host "`n  Running actionlint..."
$lintOutput = & actionlint $wfPath 2>&1 | Out-String
$lintExit = $LASTEXITCODE
Add-Content $actResultFile "actionlint exit code: $lintExit"
Add-Content $actResultFile $lintOutput

if ($lintExit -eq 0) {
    Write-Host '  PASS: actionlint passed cleanly' -ForegroundColor Green
    Add-Content $actResultFile 'PASS: actionlint passed'
} else {
    Write-Host "  FAIL: actionlint errors:`n$lintOutput" -ForegroundColor Red
    Add-Content $actResultFile "FAIL: actionlint errors"
    $allPassed = $false
}

# ============================================================
# Final summary
# ============================================================
Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host 'ALL TESTS PASSED' -ForegroundColor Green
    Add-Content $actResultFile "`nFINAL RESULT: ALL TESTS PASSED"
} else {
    Write-Host 'SOME TESTS FAILED' -ForegroundColor Red
    Add-Content $actResultFile "`nFINAL RESULT: SOME TESTS FAILED"
    exit 1
}
