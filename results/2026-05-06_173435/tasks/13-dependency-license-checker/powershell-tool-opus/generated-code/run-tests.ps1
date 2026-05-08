$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$ActResult = Join-Path $ProjectRoot 'act-result.txt'

# Clear previous results
if (Test-Path $ActResult) { Remove-Item $ActResult -Force }
'' | Set-Content $ActResult

# ============================================================
# PART 1: Workflow structure tests
# ============================================================
Write-Host "`n========== WORKFLOW STRUCTURE TESTS ==========" -ForegroundColor Cyan

$workflowPath = Join-Path $ProjectRoot '.github/workflows/dependency-license-checker.yml'
$allPassed = $true

# Test: workflow file exists
if (Test-Path $workflowPath) {
    Write-Host "[PASS] Workflow file exists at .github/workflows/dependency-license-checker.yml" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Workflow file not found" -ForegroundColor Red
    $allPassed = $false
}

# Test: parse YAML structure
$yaml = Get-Content $workflowPath -Raw
if ($yaml -match 'on:' -and $yaml -match 'jobs:') {
    Write-Host "[PASS] Workflow has 'on' triggers and 'jobs' sections" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Missing 'on' or 'jobs' section" -ForegroundColor Red
    $allPassed = $false
}

# Test: expected triggers
if ($yaml -match 'push:' -and $yaml -match 'pull_request:' -and $yaml -match 'workflow_dispatch:') {
    Write-Host "[PASS] Workflow has push, pull_request, and workflow_dispatch triggers" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Missing expected triggers" -ForegroundColor Red
    $allPassed = $false
}

# Test: expected jobs
foreach ($job in @('test:', 'check-package-json:', 'check-requirements-txt:')) {
    if ($yaml -match $job) {
        Write-Host "[PASS] Workflow contains job: $job" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Missing job: $job" -ForegroundColor Red
        $allPassed = $false
    }
}

# Test: uses shell: pwsh
if ($yaml -match 'shell: pwsh') {
    Write-Host "[PASS] Workflow uses 'shell: pwsh'" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Workflow does not use 'shell: pwsh'" -ForegroundColor Red
    $allPassed = $false
}

# Test: references script files that exist
$scriptFiles = @('DependencyLicenseChecker.Tests.ps1', 'check-licenses.ps1')
foreach ($f in $scriptFiles) {
    if ($yaml -match [regex]::Escape($f)) {
        $fullPath = Join-Path $ProjectRoot $f
        if (Test-Path $fullPath) {
            Write-Host "[PASS] Workflow references $f and file exists" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Workflow references $f but file does NOT exist" -ForegroundColor Red
            $allPassed = $false
        }
    } else {
        Write-Host "[FAIL] Workflow does not reference $f" -ForegroundColor Red
        $allPassed = $false
    }
}

# Test: uses actions/checkout@v4
if ($yaml -match 'actions/checkout@v4') {
    Write-Host "[PASS] Workflow uses actions/checkout@v4" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Workflow does not use actions/checkout@v4" -ForegroundColor Red
    $allPassed = $false
}

# Test: actionlint passes
$lintResult = & actionlint $workflowPath 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[PASS] actionlint validation passed" -ForegroundColor Green
} else {
    Write-Host "[FAIL] actionlint validation failed: $lintResult" -ForegroundColor Red
    $allPassed = $false
}

$structureSection = @"
========== WORKFLOW STRUCTURE TESTS ==========
All structure tests passed: $allPassed
"@
Add-Content -Path $ActResult -Value $structureSection

# ============================================================
# PART 2: Run act for functional tests
# ============================================================
Write-Host "`n========== ACT FUNCTIONAL TESTS ==========" -ForegroundColor Cyan

# Create a temp git repo with the project files
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "license-checker-act-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy project files
$filesToCopy = @(
    'DependencyLicenseChecker.psm1',
    'DependencyLicenseChecker.Tests.ps1',
    'check-licenses.ps1'
)
foreach ($f in $filesToCopy) {
    Copy-Item (Join-Path $ProjectRoot $f) (Join-Path $tempDir $f)
}

# Copy fixtures
$fixturesDest = Join-Path $tempDir 'fixtures'
Copy-Item -Path (Join-Path $ProjectRoot 'fixtures') -Destination $fixturesDest -Recurse

# Copy workflow
$wfDest = Join-Path $tempDir '.github/workflows'
New-Item -ItemType Directory -Path $wfDest -Force | Out-Null
Copy-Item $workflowPath (Join-Path $wfDest 'dependency-license-checker.yml')

# Copy .actrc if present
$actrcSrc = Join-Path $ProjectRoot '.actrc'
if (Test-Path $actrcSrc) {
    Copy-Item $actrcSrc (Join-Path $tempDir '.actrc')
}

# Init git repo in temp dir
Push-Location $tempDir
try {
    git init --quiet 2>&1 | Out-Null
    git config user.email "test@test.com"
    git config user.name "Test"
    git add -A 2>&1 | Out-Null
    git commit -m "initial" --quiet 2>&1 | Out-Null

    Write-Host "Running act push in $tempDir ..." -ForegroundColor Yellow
    $actOutput = & act push --rm --pull=false 2>&1 | Out-String
    $actExit = $LASTEXITCODE

    Write-Host $actOutput

    # Save act output
    $delimiter = "`n" + ("=" * 70) + "`n"
    Add-Content -Path $ActResult -Value "${delimiter}ACT PUSH OUTPUT (exit code: $actExit)${delimiter}"
    Add-Content -Path $ActResult -Value $actOutput

    # Assert act exited with 0
    if ($actExit -eq 0) {
        Write-Host "[PASS] act push exited with code 0" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] act push exited with code $actExit" -ForegroundColor Red
        $allPassed = $false
    }

    # Assert all jobs succeeded
    $jobSucceeded = ($actOutput | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count
    if ($jobSucceeded -ge 3) {
        Write-Host "[PASS] All 3 jobs succeeded ($jobSucceeded 'Job succeeded' found)" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Expected 3 job successes, found $jobSucceeded" -ForegroundColor Red
        $allPassed = $false
    }

    # Assert Pester test results appear: check for specific test counts
    $cleanOutput = $actOutput -replace '\x1b\[[0-9;]*m', ''
    if ($cleanOutput -match 'Tests Passed:\s+(\d+)') {
        $passedCount = [int]$Matches[1]
        if ($passedCount -ge 25) {
            Write-Host "[PASS] Pester reported $passedCount tests passed (expected >= 25)" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Pester reported only $passedCount tests passed (expected >= 25)" -ForegroundColor Red
            $allPassed = $false
        }
    } else {
        Write-Host "[FAIL] Could not find Pester test pass count in output" -ForegroundColor Red
        $allPassed = $false
    }

    # Assert package.json license check found denied deps (FAIL result)
    if ($actOutput -match 'LICENSE_CHECK_RESULT=FAIL') {
        Write-Host "[PASS] package.json check correctly reported FAIL (denied deps found)" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Expected LICENSE_CHECK_RESULT=FAIL for package.json check" -ForegroundColor Red
        $allPassed = $false
    }

    # Assert specific denied dependency appears: gpl-lib with GPL-3.0
    if ($actOutput -match '\[DENIED\].*gpl-lib.*GPL-3\.0') {
        Write-Host "[PASS] Output correctly shows gpl-lib as DENIED with GPL-3.0 license" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Expected gpl-lib DENIED with GPL-3.0 in output" -ForegroundColor Red
        $allPassed = $false
    }

    # Assert approved deps appear
    if ($actOutput -match '\[APPROVED\].*express.*MIT') {
        Write-Host "[PASS] Output correctly shows express as APPROVED with MIT license" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Expected express APPROVED with MIT in output" -ForegroundColor Red
        $allPassed = $false
    }

    # Assert requirements.txt check also found denied deps
    # Both manifests have gpl-lib, so both should show FAIL
    $failCount = ($actOutput | Select-String -Pattern 'LICENSE_CHECK_RESULT=FAIL' -AllMatches).Matches.Count
    if ($failCount -ge 2) {
        Write-Host "[PASS] Both manifest checks reported FAIL ($failCount FAIL results)" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Expected 2 FAIL results from license checks, got $failCount" -ForegroundColor Red
        $allPassed = $false
    }

    # Assert the report summary line with exact count
    if ($actOutput -match 'RESULT: FAIL - 1 denied license') {
        Write-Host "[PASS] Report shows exactly 1 denied license per manifest" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Expected 'RESULT: FAIL - 1 denied license' in output" -ForegroundColor Red
        $allPassed = $false
    }

    # Assert Pester found 0 failures (strip ANSI escape codes before matching)
    $cleanOutput = $actOutput -replace '\x1b\[[0-9;]*m', ''
    if ($cleanOutput -match 'Failed:\s+0') {
        Write-Host "[PASS] Pester reported 0 test failures" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Pester reported test failures" -ForegroundColor Red
        $allPassed = $false
    }

} finally {
    Pop-Location
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}

# ============================================================
# Final summary
# ============================================================
$summary = @"

========== FINAL SUMMARY ==========
All tests passed: $allPassed
"@
Add-Content -Path $ActResult -Value $summary

Write-Host "`n========== FINAL SUMMARY ==========" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
