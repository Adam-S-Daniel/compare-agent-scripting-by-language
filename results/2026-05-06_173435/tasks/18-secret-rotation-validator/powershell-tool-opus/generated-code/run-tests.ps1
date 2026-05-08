# Test harness: runs all tests through act and validates output.
# Writes act output to act-result.txt.

$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$actResult = Join-Path $projectDir 'act-result.txt'

# Clear previous results
if (Test-Path $actResult) { Remove-Item $actResult }
Set-Content -Path $actResult -Value "=== Secret Rotation Validator - Act Test Results ===$([Environment]::NewLine)"

# --- Workflow structure tests ---
Write-Host "`n=== WORKFLOW STRUCTURE TESTS ===" -ForegroundColor Cyan

$workflowPath = Join-Path $projectDir '.github/workflows/secret-rotation-validator.yml'

# Test: workflow file exists
if (-not (Test-Path $workflowPath)) {
    throw "FAIL: Workflow file does not exist at $workflowPath"
}
Write-Host "PASS: Workflow file exists" -ForegroundColor Green

# Test: parse YAML and check structure
$yaml = Get-Content $workflowPath -Raw
if ($yaml -notmatch 'on:') { throw "FAIL: Missing 'on:' trigger block" }
if ($yaml -notmatch 'push:') { throw "FAIL: Missing push trigger" }
if ($yaml -notmatch 'pull_request:') { throw "FAIL: Missing pull_request trigger" }
if ($yaml -notmatch 'schedule:') { throw "FAIL: Missing schedule trigger" }
if ($yaml -notmatch 'workflow_dispatch:') { throw "FAIL: Missing workflow_dispatch trigger" }
if ($yaml -notmatch 'jobs:') { throw "FAIL: Missing jobs block" }
if ($yaml -notmatch 'validate-secrets:') { throw "FAIL: Missing validate-secrets job" }
if ($yaml -notmatch 'actions/checkout@v4') { throw "FAIL: Missing actions/checkout@v4" }
if ($yaml -notmatch 'shell: pwsh') { throw "FAIL: Missing shell: pwsh" }
Write-Host "PASS: Workflow has expected structure (triggers, jobs, steps)" -ForegroundColor Green

# Test: workflow references script files that exist
$scriptFile = Join-Path $projectDir 'SecretRotationValidator.ps1'
$testFile = Join-Path $projectDir 'SecretRotationValidator.Tests.ps1'
$fixtureFile = Join-Path $projectDir 'fixtures/secrets.json'
if (-not (Test-Path $scriptFile)) { throw "FAIL: SecretRotationValidator.ps1 not found" }
if (-not (Test-Path $testFile)) { throw "FAIL: SecretRotationValidator.Tests.ps1 not found" }
if (-not (Test-Path $fixtureFile)) { throw "FAIL: fixtures/secrets.json not found" }
Write-Host "PASS: All referenced script files exist" -ForegroundColor Green

# Test: actionlint passes
$actionlintOutput = & actionlint $workflowPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "FAIL: actionlint errors: $actionlintOutput"
}
Write-Host "PASS: actionlint validation passed (exit code 0)" -ForegroundColor Green

Add-Content -Path $actResult -Value "--- Workflow Structure Tests: ALL PASSED ---$([Environment]::NewLine)"

# --- Act integration test ---
Write-Host "`n=== ACT INTEGRATION TEST ===" -ForegroundColor Cyan

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # Set up a temp git repo with project files
    Copy-Item -Path (Join-Path $projectDir 'SecretRotationValidator.ps1') -Destination $tempDir
    Copy-Item -Path (Join-Path $projectDir 'SecretRotationValidator.Tests.ps1') -Destination $tempDir
    Copy-Item -Path (Join-Path $projectDir 'fixtures') -Destination $tempDir -Recurse
    $ghDir = Join-Path $tempDir '.github/workflows'
    New-Item -ItemType Directory -Path $ghDir -Force | Out-Null
    Copy-Item -Path $workflowPath -Destination $ghDir

    # Check for custom act image
    $actImage = docker images -q act-ubuntu-pwsh:latest 2>$null
    $actrcPath = Join-Path $tempDir '.actrc'
    if ($actImage) {
        Set-Content -Path $actrcPath -Value @("-P ubuntu-latest=act-ubuntu-pwsh:latest", "--pull=false")
    }

    Push-Location $tempDir
    git init --initial-branch=main | Out-Null
    git add -A | Out-Null
    git commit -m "init" --allow-empty 2>&1 | Out-Null
    git add -A | Out-Null
    git commit -m "add files" 2>&1 | Out-Null

    Write-Host "Running act push --rm in $tempDir ..." -ForegroundColor Yellow
    $actOutput = & act push --rm 2>&1 | Out-String
    $actExit = $LASTEXITCODE
    Pop-Location

    Add-Content -Path $actResult -Value "--- Act Run: push event ---"
    Add-Content -Path $actResult -Value $actOutput
    Add-Content -Path $actResult -Value "--- Act Exit Code: $actExit ---$([Environment]::NewLine)"

    # Assert act exited 0
    if ($actExit -ne 0) {
        Write-Host $actOutput
        throw "FAIL: act exited with code $actExit"
    }
    Write-Host "PASS: act exited with code 0" -ForegroundColor Green

    # Assert job succeeded
    if ($actOutput -notmatch 'Job succeeded') {
        throw "FAIL: 'Job succeeded' not found in act output"
    }
    Write-Host "PASS: Job succeeded found in output" -ForegroundColor Green

    # Assert Pester tests passed (14 tests)
    if ($actOutput -notmatch 'Tests Passed: 14') {
        throw "FAIL: Expected 'Tests Passed: 14' in act output"
    }
    Write-Host "PASS: All 14 Pester tests passed in act" -ForegroundColor Green

    # Assert exact summary values from JSON report
    if ($actOutput -notmatch 'SUMMARY: total=5 expired=2 warning=1 ok=2') {
        throw "FAIL: Expected exact summary 'total=5 expired=2 warning=1 ok=2'"
    }
    Write-Host "PASS: JSON report summary matches expected values (total=5 expired=2 warning=1 ok=2)" -ForegroundColor Green

    # Assert markdown report content
    if ($actOutput -notmatch 'Secret Rotation Report') {
        throw "FAIL: Markdown report header not found"
    }
    Write-Host "PASS: Markdown report generated successfully" -ForegroundColor Green

    # Assert specific secret names in output
    if ($actOutput -notmatch 'DB_PASSWORD') { throw "FAIL: DB_PASSWORD not found in output" }
    if ($actOutput -notmatch 'API_KEY_EXTERNAL') { throw "FAIL: API_KEY_EXTERNAL not found in output" }
    if ($actOutput -notmatch 'JWT_SIGNING_KEY') { throw "FAIL: JWT_SIGNING_KEY not found in output" }
    Write-Host "PASS: All expected secret names found in output" -ForegroundColor Green

    # Assert expired secrets are identified correctly
    if ($actOutput -notmatch 'EXPIRED') {
        throw "FAIL: EXPIRED status not found in output"
    }
    Write-Host "PASS: Expired status correctly identified" -ForegroundColor Green

    Add-Content -Path $actResult -Value "--- All Assertions: PASSED ---$([Environment]::NewLine)"

} finally {
    if (Test-Path $tempDir) {
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    }
}

Write-Host "`n=== ALL TESTS PASSED ===" -ForegroundColor Green
Add-Content -Path $actResult -Value "=== ALL TESTS PASSED ==="
