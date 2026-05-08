# Test harness: runs workflow structure tests and functional tests via act
# All test cases execute through the GitHub Actions workflow via act

$ErrorActionPreference = 'Continue'
$script:testsPassed = 0
$script:testsFailed = 0
$script:actResultFile = Join-Path $PSScriptRoot 'act-result.txt'
$projectDir = $PSScriptRoot

# Clear previous results
if (Test-Path $script:actResultFile) { Remove-Item $script:actResultFile }
'' | Out-File $script:actResultFile -Encoding utf8

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        $script:testsPassed++
        Write-Host "  PASS: $Message" -ForegroundColor Green
    } else {
        $script:testsFailed++
        Write-Host "  FAIL: $Message" -ForegroundColor Red
    }
}

# ==============================================================
# WORKFLOW STRUCTURE TESTS
# ==============================================================
Write-Host "`n=== Workflow Structure Tests ===" -ForegroundColor Cyan

$workflowPath = Join-Path $projectDir '.github/workflows/test-results-aggregator.yml'
$workflowContent = Get-Content $workflowPath -Raw

# Trigger events
Assert-True ($workflowContent -match 'on:') "Workflow has 'on:' trigger section"
Assert-True ($workflowContent -match 'push:') "Workflow triggers on push"
Assert-True ($workflowContent -match 'pull_request:') "Workflow triggers on pull_request"
Assert-True ($workflowContent -match 'workflow_dispatch:') "Workflow triggers on workflow_dispatch"

# Jobs and steps
Assert-True ($workflowContent -match 'jobs:') "Workflow has jobs section"
Assert-True ($workflowContent -match 'runs-on:\s*ubuntu-latest') "Job runs on ubuntu-latest"
Assert-True ($workflowContent -match 'actions/checkout@v4') "Workflow uses actions/checkout@v4"
Assert-True ($workflowContent -match 'shell:\s*pwsh') "Workflow uses pwsh shell"

# File references exist
Assert-True ($workflowContent -match 'Aggregate-TestResults\.Tests\.ps1') "Workflow references test file"
Assert-True ($workflowContent -match 'Aggregate-TestResults\.ps1') "Workflow references main script"
Assert-True ($workflowContent -match '\./fixtures') "Workflow references fixtures directory"

# Verify referenced files exist
Assert-True (Test-Path (Join-Path $projectDir 'Aggregate-TestResults.ps1')) "Main script file exists"
Assert-True (Test-Path (Join-Path $projectDir 'Aggregate-TestResults.Tests.ps1')) "Test file exists"
Assert-True (Test-Path (Join-Path $projectDir 'fixtures')) "Fixtures directory exists"

# Actionlint validation
$actionlintResult = & actionlint $workflowPath 2>&1
$actionlintExit = $LASTEXITCODE
Assert-True ($actionlintExit -eq 0) "actionlint passes with exit code 0"

# ==============================================================
# FUNCTIONAL TESTS VIA ACT
# ==============================================================
Write-Host "`n=== Functional Tests via Act ===" -ForegroundColor Cyan

# Set up temp git repo with project files
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "test-aggregator-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempDir '.github/workflows') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempDir 'fixtures') -Force | Out-Null

# Copy project files
Copy-Item (Join-Path $projectDir 'Aggregate-TestResults.ps1') $tempDir
Copy-Item (Join-Path $projectDir 'Aggregate-TestResults.Tests.ps1') $tempDir
Copy-Item (Join-Path $projectDir '.github/workflows/test-results-aggregator.yml') (Join-Path $tempDir '.github/workflows/')
Copy-Item (Join-Path $projectDir 'fixtures/*') (Join-Path $tempDir 'fixtures/')
Copy-Item (Join-Path $projectDir '.actrc') $tempDir

# Initialize git repo
Push-Location $tempDir
try {
    & git init --quiet 2>&1 | Out-Null
    & git add -A 2>&1 | Out-Null
    & git commit -m "initial" --quiet 2>&1 | Out-Null

    Write-Host "`n--- Running act push --rm ---" -ForegroundColor Yellow
    $actOutput = & act push --rm --pull=false 2>&1 | Out-String
    $actExitCode = $LASTEXITCODE

    # Save output to act-result.txt
    "=== ACT RUN: Full Test Suite ===" | Out-File $script:actResultFile -Append -Encoding utf8
    "Exit Code: $actExitCode" | Out-File $script:actResultFile -Append -Encoding utf8
    "--- Output ---" | Out-File $script:actResultFile -Append -Encoding utf8
    $actOutput | Out-File $script:actResultFile -Append -Encoding utf8
    "=== END ACT RUN ===" | Out-File $script:actResultFile -Append -Encoding utf8

    # Assert act succeeded
    Assert-True ($actExitCode -eq 0) "act push exited with code 0"

    # Assert job succeeded
    Assert-True ($actOutput -match 'Job succeeded') "Output contains 'Job succeeded'"

    # Assert Pester tests all passed (18 tests, 0 failed)
    Assert-True ($actOutput -match 'Tests Passed: 18') "All 18 Pester tests passed"
    Assert-True ($actOutput -match 'Failed: 0') "Zero Pester tests failed"

    # Assert exact aggregation output values
    Assert-True ($actOutput -match '\| Total Tests \| 15 \|') "Aggregation shows Total Tests = 15"
    Assert-True ($actOutput -match '\| Passed \| 9 \|') "Aggregation shows Passed = 9"
    Assert-True ($actOutput -match '\| Failed \| 3 \|') "Aggregation shows Failed = 3"
    Assert-True ($actOutput -match '\| Skipped \| 3 \|') "Aggregation shows Skipped = 3"
    Assert-True ($actOutput -match '\| Duration \| 8\.40s \|') "Aggregation shows Duration = 8.40s"
    Assert-True ($actOutput -match '\| Pass Rate \| 75\.0% \|') "Aggregation shows Pass Rate = 75.0%"

    # Assert flaky tests detected correctly
    Assert-True ($actOutput -match 'Flaky Tests') "Output contains Flaky Tests section"
    Assert-True ($actOutput -match 'TestLogout \| 2 \| 1') "TestLogout identified as flaky (2 pass, 1 fail)"
    Assert-True ($actOutput -match 'TestSignup \| 1 \| 2') "TestSignup identified as flaky (1 pass, 2 fail)"

    # Assert per-run results
    Assert-True ($actOutput -match 'Unit Tests - Chrome \| 3 \| 1 \| 1 \| 2\.80s') "Per-run Chrome results correct"
    Assert-True ($actOutput -match 'Unit Tests - Firefox \| 2 \| 2 \| 1 \| 2\.80s') "Per-run Firefox results correct"
    Assert-True ($actOutput -match 'Unit Tests - Safari \| 4 \| 0 \| 1 \| 2\.80s') "Per-run Safari results correct"

    # Assert failed test details
    Assert-True ($actOutput -match 'Email validation error') "Failed test shows email validation error"
    Assert-True ($actOutput -match 'Session timeout') "Failed test shows session timeout error"

} finally {
    Pop-Location
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ==============================================================
# SUMMARY
# ==============================================================
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $script:testsPassed" -ForegroundColor Green
Write-Host "Failed: $script:testsFailed" -ForegroundColor Red
Write-Host "Results saved to: $script:actResultFile"

if ($script:testsFailed -gt 0) {
    Write-Host "`nSOME TESTS FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
    exit 0
}
