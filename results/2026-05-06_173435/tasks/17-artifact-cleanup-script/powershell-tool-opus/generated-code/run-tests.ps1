#!/usr/bin/env pwsh
# Test harness: validates workflow structure, runs actionlint, and executes
# all test cases through act (GitHub Actions local runner).

$ErrorActionPreference = 'Continue'
$projectDir = $PSScriptRoot
$resultFile = Join-Path $projectDir 'act-result.txt'
$passed = 0
$failed = 0
$total = 0

'' | Set-Content $resultFile

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:total++
    if ($Condition) {
        Write-Output "  PASS: $Message"
        $script:passed++
    }
    else {
        Write-Output "  FAIL: $Message"
        $script:failed++
    }
}

# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================
Write-Output "`n=== WORKFLOW STRUCTURE TESTS ==="

$workflowPath = Join-Path $projectDir '.github/workflows/artifact-cleanup-script.yml'
$workflowContent = Get-Content $workflowPath -Raw

# Trigger events
Assert-True ($workflowContent -match '(?m)^\s*push:') "Workflow has push trigger"
Assert-True ($workflowContent -match '(?m)^\s*pull_request:') "Workflow has pull_request trigger"
Assert-True ($workflowContent -match '(?m)^\s*workflow_dispatch:') "Workflow has workflow_dispatch trigger"
Assert-True ($workflowContent -match '(?m)^\s*schedule:') "Workflow has schedule trigger"

# Structure
Assert-True ($workflowContent -match '(?m)^jobs:') "Workflow has jobs section"
Assert-True ($workflowContent -match 'actions/checkout@v4') "Workflow uses actions/checkout@v4"
Assert-True ($workflowContent -match 'shell:\s*pwsh') "Workflow uses shell: pwsh"
Assert-True ($workflowContent -match 'Invoke-Pester') "Workflow runs Invoke-Pester"
Assert-True ($workflowContent -match 'Invoke-ArtifactCleanup\.ps1') "Workflow references main script"

# Script file references exist
Assert-True (Test-Path (Join-Path $projectDir 'ArtifactCleanup.psm1')) "ArtifactCleanup.psm1 exists"
Assert-True (Test-Path (Join-Path $projectDir 'Invoke-ArtifactCleanup.ps1')) "Invoke-ArtifactCleanup.ps1 exists"
Assert-True (Test-Path (Join-Path $projectDir 'Invoke-ArtifactCleanup.Tests.ps1')) "Tests file exists"
Assert-True (Test-Path (Join-Path $projectDir 'fixtures/standard-artifacts.json')) "Standard fixture exists"
Assert-True (Test-Path (Join-Path $projectDir 'fixtures/empty-artifacts.json')) "Empty fixture exists"

# actionlint validation
Write-Output "`n--- actionlint ---"
$lintOutput = & actionlint $workflowPath 2>&1 | Out-String
$lintExitCode = $LASTEXITCODE
Assert-True ($lintExitCode -eq 0) "actionlint passes (exit code: $lintExitCode)"
if ($lintExitCode -ne 0) {
    Write-Output "    actionlint output: $lintOutput"
}

# ============================================================
# ACT TEST CASE 1: Full Test Suite
# ============================================================
Write-Output "`n=== ACT TEST: Full Test Suite ==="

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy project files
$filesToCopy = @(
    'ArtifactCleanup.psm1',
    'Invoke-ArtifactCleanup.ps1',
    'Invoke-ArtifactCleanup.Tests.ps1',
    '.actrc'
)
foreach ($f in $filesToCopy) {
    Copy-Item -Path (Join-Path $projectDir $f) -Destination (Join-Path $tempDir $f)
}
Copy-Item -Path (Join-Path $projectDir 'fixtures') -Destination (Join-Path $tempDir 'fixtures') -Recurse
New-Item -ItemType Directory -Path (Join-Path $tempDir '.github/workflows') -Force | Out-Null
Copy-Item -Path $workflowPath -Destination (Join-Path $tempDir '.github/workflows/artifact-cleanup-script.yml')

# Initialize git repo in temp dir
Push-Location $tempDir
& git init -q 2>&1 | Out-Null
& git config user.email "test@test.com" 2>&1 | Out-Null
& git config user.name "Test" 2>&1 | Out-Null
& git add -A 2>&1 | Out-Null
& git commit -q -m "test commit" 2>&1 | Out-Null

# Run act
Write-Output "Running act push --rm (this may take 30-90 seconds)..."
$actOutput = & act push --rm 2>&1 | Out-String
$actExitCode = $LASTEXITCODE
Pop-Location

# Strip ANSI color codes for reliable matching
$cleanOutput = $actOutput -replace '\x1b\[[0-9;]*m', ''

# Save to result file
"=== ACT TEST CASE 1: Full Test Suite ===" | Add-Content $resultFile
"Exit code: $actExitCode" | Add-Content $resultFile
"" | Add-Content $resultFile
$cleanOutput | Add-Content $resultFile
"" | Add-Content $resultFile
"=== END ACT TEST CASE 1 ===" | Add-Content $resultFile

# ---- Assertions on act output ----
Write-Output "`n--- Act Execution ---"
Assert-True ($actExitCode -eq 0) "act exited with code 0 (got: $actExitCode)"
Assert-True ($cleanOutput -match 'Job succeeded') "Job succeeded message found"

# Pester results
Write-Output "`n--- Pester Results ---"
Assert-True ($cleanOutput -match 'PESTER_RESULT: Passed=(\d+) Failed=0') "All Pester tests passed with zero failures"
if ($cleanOutput -match 'PESTER_RESULT: Passed=(\d+) Failed=(\d+)') {
    Write-Output "    Pester: Passed=$($Matches[1]) Failed=$($Matches[2])"
}

# Standard fixture: exact expected values
Write-Output "`n--- Standard Fixture Assertions ---"
Assert-True ($cleanOutput -match 'Total artifacts: 10') "Standard: total artifacts = 10"
Assert-True ($cleanOutput -match 'Artifacts to delete: 4') "Standard: artifacts to delete = 4"
Assert-True ($cleanOutput -match 'Artifacts to retain: 6') "Standard: artifacts to retain = 6"
Assert-True ($cleanOutput -match 'Space to reclaim: 18874368 bytes') "Standard: space reclaimed = 18874368 bytes"
Assert-True ($cleanOutput -match 'Space retained: 26214400 bytes') "Standard: space retained = 26214400 bytes"
Assert-True ($cleanOutput -match 'Mode: DRY-RUN') "Standard: dry-run mode active"

# Verify specific deletion reasons
Assert-True ($cleanOutput -match 'build-linux-121.*exceeded max age of 30 days \(36 days old\)') "Standard: build-linux-121 deleted for age (36 days)"
Assert-True ($cleanOutput -match 'deploy-logs-10.*exceeded max age of 30 days \(67 days old\)') "Standard: deploy-logs-10 deleted for age (67 days)"
Assert-True ($cleanOutput -match "test-results-198.*exceeded keep-latest-2 per workflow 'test-results'") "Standard: test-results-198 deleted for keep-latest-2"
Assert-True ($cleanOutput -match 'build-windows-49.*exceeded max total size of 30 MB') "Standard: build-windows-49 deleted for max size"

# Verify retained artifacts
Assert-True ($cleanOutput -match 'build-linux-122 \| 5242880 bytes') "Standard: build-linux-122 retained"
Assert-True ($cleanOutput -match 'coverage-report-5 \| 3145728 bytes') "Standard: coverage-report-5 retained"

# Empty fixture: exact expected values
Write-Output "`n--- Empty Fixture Assertions ---"
Assert-True ($cleanOutput -match 'Total artifacts: 0') "Empty: total artifacts = 0"
Assert-True ($cleanOutput -match 'Artifacts to delete: 0') "Empty: artifacts to delete = 0"
Assert-True ($cleanOutput -match 'Artifacts to retain: 0') "Empty: artifacts to retain = 0"
Assert-True ($cleanOutput -match 'Space to reclaim: 0 bytes') "Empty: space reclaimed = 0 bytes"
Assert-True ($cleanOutput -match '\(none\)') "Empty: shows (none) for empty lists"

# Cleanup temp directory
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# ============================================================
# FINAL RESULTS
# ============================================================
Write-Output "`n=== FINAL RESULTS ==="
Write-Output "Total: $total, Passed: $passed, Failed: $failed"

if ($failed -gt 0) {
    Write-Output "SOME TESTS FAILED"
    exit 1
}
Write-Output "ALL TESTS PASSED"
exit 0
