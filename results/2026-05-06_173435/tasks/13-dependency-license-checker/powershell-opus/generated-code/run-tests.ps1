# Test harness that runs all tests through GitHub Actions via act
# Creates temp git repos with fixtures, runs act, captures output, asserts results

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$ActResultFile = Join-Path $ProjectRoot "act-result.txt"

# Clear previous results
if (Test-Path $ActResultFile) { Remove-Item $ActResultFile }
"" | Set-Content $ActResultFile

$allPassed = $true

function Run-ActTest {
    param(
        [string]$TestName,
        [string]$Description
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "TEST: $TestName" -ForegroundColor Cyan
    Write-Host "$Description" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # Create temp directory for isolated git repo
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        # Copy project files
        Copy-Item "$ProjectRoot/DependencyLicenseChecker.ps1" $tempDir/
        Copy-Item "$ProjectRoot/DependencyLicenseChecker.Functions.ps1" $tempDir/
        Copy-Item "$ProjectRoot/DependencyLicenseChecker.Tests.ps1" $tempDir/
        Copy-Item -Recurse "$ProjectRoot/fixtures" "$tempDir/fixtures"
        Copy-Item -Recurse "$ProjectRoot/.github" "$tempDir/.github"
        Copy-Item "$ProjectRoot/.actrc" "$tempDir/.actrc"

        # Initialize git repo (act requires it)
        Push-Location $tempDir
        git init --quiet
        git add -A
        git commit -m "test setup" --quiet

        # Run act
        $actOutput = & act push --rm --pull=false 2>&1 | Out-String
        $actExitCode = $LASTEXITCODE

        Pop-Location

        # Append to results file
        $delimiter = "`n`n" + ("=" * 60) + "`n"
        $entry = "${delimiter}TEST CASE: $TestName`n$Description`nExit Code: $actExitCode`n" + ("=" * 60) + "`n$actOutput"
        Add-Content -Path $ActResultFile -Value $entry

        return @{
            Output   = $actOutput
            ExitCode = $actExitCode
        }
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item -Recurse -Force $tempDir
        }
    }
}

# ============================================================
# WORKFLOW STRUCTURE TESTS (YAML parsing, actionlint, file refs)
# ============================================================

Write-Host "`n" -NoNewline
Write-Host "=== WORKFLOW STRUCTURE TESTS ===" -ForegroundColor Yellow

# Test 1: actionlint passes
Write-Host "`nStructure Test 1: actionlint validation..." -ForegroundColor White
$lintResult = & actionlint "$ProjectRoot/.github/workflows/dependency-license-checker.yml" 2>&1
$lintExit = $LASTEXITCODE
if ($lintExit -eq 0) {
    Write-Host "  PASS: actionlint passes with exit code 0" -ForegroundColor Green
} else {
    Write-Host "  FAIL: actionlint exit code $lintExit" -ForegroundColor Red
    Write-Host "  $lintResult" -ForegroundColor Red
    $allPassed = $false
}
Add-Content -Path $ActResultFile -Value "`n=== STRUCTURE TEST: actionlint ===`nExit code: $lintExit`n$lintResult"

# Test 2: YAML structure validation
Write-Host "`nStructure Test 2: YAML structure..." -ForegroundColor White
$yaml = Get-Content "$ProjectRoot/.github/workflows/dependency-license-checker.yml" -Raw

$hasOnPush = $yaml -match "on:" -and $yaml -match "push:"
$hasJobs = $yaml -match "jobs:"
$hasTest = $yaml -match "test:"
$hasCheckout = $yaml -match "actions/checkout@v4"
$hasPwsh = $yaml -match "shell: pwsh"

if ($hasOnPush -and $hasJobs -and $hasTest -and $hasCheckout -and $hasPwsh) {
    Write-Host "  PASS: Workflow has correct structure (triggers, jobs, checkout, pwsh)" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Missing workflow elements" -ForegroundColor Red
    $allPassed = $false
}
Add-Content -Path $ActResultFile -Value "`n=== STRUCTURE TEST: YAML structure ===`non.push: $hasOnPush | jobs: $hasJobs | test: $hasTest | checkout: $hasCheckout | pwsh: $hasPwsh"

# Test 3: Script files referenced in workflow exist
Write-Host "`nStructure Test 3: Script file references..." -ForegroundColor White
$scriptsExist = (Test-Path "$ProjectRoot/DependencyLicenseChecker.ps1") -and
                (Test-Path "$ProjectRoot/DependencyLicenseChecker.Functions.ps1") -and
                (Test-Path "$ProjectRoot/DependencyLicenseChecker.Tests.ps1") -and
                (Test-Path "$ProjectRoot/fixtures/package.json") -and
                (Test-Path "$ProjectRoot/fixtures/requirements.txt") -and
                (Test-Path "$ProjectRoot/fixtures/license-config.json")
if ($scriptsExist) {
    Write-Host "  PASS: All referenced script and fixture files exist" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Some referenced files are missing" -ForegroundColor Red
    $allPassed = $false
}
Add-Content -Path $ActResultFile -Value "`n=== STRUCTURE TEST: File references ===`nAll files exist: $scriptsExist"

# ============================================================
# ACT INTEGRATION TEST
# ============================================================

Write-Host "`n`n=== ACT INTEGRATION TEST ===" -ForegroundColor Yellow

$result = Run-ActTest -TestName "Full Pipeline" -Description "Run complete workflow: unit tests + package.json check + requirements.txt denied detection"

# Assert act exited successfully
if ($result.ExitCode -eq 0) {
    Write-Host "  PASS: act exited with code 0" -ForegroundColor Green
} else {
    Write-Host "  FAIL: act exited with code $($result.ExitCode)" -ForegroundColor Red
    Write-Host "  Output (last 50 lines):" -ForegroundColor Red
    $lines = $result.Output -split "`n"
    $lines[-50..-1] | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    $allPassed = $false
}

# Assert all jobs succeeded
$jobSucceeded = ($result.Output -match "Job succeeded")
if ($jobSucceeded) {
    Write-Host "  PASS: Jobs reported success" -ForegroundColor Green
} else {
    Write-Host "  FAIL: No 'Job succeeded' found in output" -ForegroundColor Red
    $allPassed = $false
}

# Assert Pester tests ran and passed
$pesterPassed = ($result.Output -match "Tests Passed")
if ($pesterPassed) {
    Write-Host "  PASS: Pester tests passed" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Pester test results not found" -ForegroundColor Red
    $allPassed = $false
}

# Assert package.json check shows RESULT: PASS (all MIT deps)
$passResult = ($result.Output -match "RESULT: PASS")
if ($passResult) {
    Write-Host "  PASS: package.json check shows 'RESULT: PASS'" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Expected 'RESULT: PASS' for package.json" -ForegroundColor Red
    $allPassed = $false
}

# Assert requirements.txt check correctly detected denied licenses
$deniedDetected = ($result.Output -match "Correctly detected denied licenses")
if ($deniedDetected) {
    Write-Host "  PASS: requirements.txt denied license detection confirmed" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Expected denied license detection message" -ForegroundColor Red
    $allPassed = $false
}

# Assert specific dependency details in output
$expressApproved = ($result.Output -match "\[APPROVED\] express@4.18.2")
if ($expressApproved) {
    Write-Host "  PASS: express@4.18.2 correctly shown as [APPROVED]" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Expected '[APPROVED] express@4.18.2' in output" -ForegroundColor Red
    $allPassed = $false
}

$gplDenied = ($result.Output -match "\[DENIED\] gpl-library@1.0.0")
if ($gplDenied) {
    Write-Host "  PASS: gpl-library@1.0.0 correctly shown as [DENIED]" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Expected '[DENIED] gpl-library@1.0.0' in output" -ForegroundColor Red
    $allPassed = $false
}

# Assert correct counts in package.json report
$totalDeps4 = ($result.Output -match "Total dependencies: 4")
if ($totalDeps4) {
    Write-Host "  PASS: package.json reports exactly 4 total dependencies" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Expected 'Total dependencies: 4' for package.json" -ForegroundColor Red
    $allPassed = $false
}

# ============================================================
# FINAL SUMMARY
# ============================================================

Write-Host "`n`n========================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Results saved to: $ActResultFile"
