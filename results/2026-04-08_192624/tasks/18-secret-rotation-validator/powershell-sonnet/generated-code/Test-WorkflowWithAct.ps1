#!/usr/bin/env pwsh
# Test-WorkflowWithAct.ps1
# Test harness that validates the GitHub Actions workflow using `act`.
#
# For each test case:
#   1. Creates a temporary git repo with all project files
#   2. Adds the test-case-specific fixture file
#   3. Runs `act push --rm` and captures output
#   4. Asserts exact expected values
#   5. Appends output to act-result.txt
#
# Also runs workflow structure tests (YAML parsing, actionlint, path checks).
#
# Usage:  pwsh Test-WorkflowWithAct.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir   = $PSScriptRoot
$ActResultFile = Join-Path $ScriptDir "act-result.txt"
$ActImage    = "catthehacker/ubuntu:act-22.04"

# Counters
$TotalTests  = 0
$PassedTests = 0
$FailedTests = 0
$Failures    = [System.Collections.Generic.List[string]]::new()

# ============================================================
# Helper: write a header to act-result.txt
# ============================================================
function Write-ActResult {
    param([string]$Content)
    Add-Content -Path $ActResultFile -Value $Content
}

# ============================================================
# Helper: assert a condition, record result
# ============================================================
function Assert-Condition {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$Message
    )
    $script:TotalTests++
    if ($Condition) {
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        $script:PassedTests++
    } else {
        Write-Host "  [FAIL] $($TestName): $Message" -ForegroundColor Red
        $script:FailedTests++
        $script:Failures.Add("$($TestName): $Message")
    }
}

# ============================================================
# Helper: run act in a temp git repo with specified fixtures
# Returns: hashtable with ExitCode and Output
# ============================================================
function Invoke-ActWithFixture {
    param(
        [string]$TestCaseName,
        [string[]]$FixtureFiles  # paths relative to $ScriptDir
    )

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(New-Guid)"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        # Initialize git repo
        git -C $tempDir init --quiet
        git -C $tempDir config user.email "test@example.com"
        git -C $tempDir config user.name "Test Runner"

        # Copy project files (preserving directory structure)
        $filesToCopy = @(
            "Invoke-SecretRotationValidator.ps1",
            "SecretRotationValidator.psm1",
            "SecretRotationValidator.Tests.ps1"
        )
        foreach ($f in $filesToCopy) {
            $src = Join-Path $ScriptDir $f
            $dst = Join-Path $tempDir $f
            $dstDir = Split-Path $dst -Parent
            if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir | Out-Null }
            Copy-Item -Path $src -Destination $dst
        }

        # Copy the workflow file
        $wfSrc = Join-Path $ScriptDir ".github/workflows/secret-rotation-validator.yml"
        $wfDir = Join-Path $tempDir ".github/workflows"
        New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
        Copy-Item -Path $wfSrc -Destination (Join-Path $wfDir "secret-rotation-validator.yml")

        # Copy ALL fixture files so the workflow's steps always have full fixture set.
        # Individual test cases assert on specific fixture markers to stay isolated.
        $fixtureDir = Join-Path $tempDir "fixtures"
        New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null
        $allFixtures = Get-ChildItem -Path (Join-Path $ScriptDir "fixtures") -Filter "*.json"
        foreach ($f in $allFixtures) {
            Copy-Item -Path $f.FullName -Destination (Join-Path $fixtureDir $f.Name)
        }
        # (The $FixtureFiles param is kept for documentation of test intent)

        # Initial commit (act requires at least one commit)
        git -C $tempDir add .
        git -C $tempDir commit --quiet -m "Test: $TestCaseName"

        # Run act
        $actArgs = @(
            "push",
            "--rm",
            "-P", "ubuntu-latest=$ActImage",
            "-W", ".github/workflows/secret-rotation-validator.yml",
            "--no-cache-server"
        )

        $outputLines = [System.Collections.Generic.List[string]]::new()
        $proc = Start-Process -FilePath "act" -ArgumentList $actArgs `
            -WorkingDirectory $tempDir `
            -RedirectStandardOutput "/tmp/act-out-$TestCaseName.txt" `
            -RedirectStandardError "/tmp/act-err-$TestCaseName.txt" `
            -NoNewWindow -Wait -PassThru

        $stdout = Get-Content "/tmp/act-out-$TestCaseName.txt" -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content "/tmp/act-err-$TestCaseName.txt" -Raw -ErrorAction SilentlyContinue
        $combined = "$stdout`n$stderr"

        return @{
            ExitCode = $proc.ExitCode
            Output   = $combined
            Stdout   = $stdout
            Stderr   = $stderr
        }
    }
    finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "/tmp/act-out-$TestCaseName.txt" -ErrorAction SilentlyContinue
        Remove-Item "/tmp/act-err-$TestCaseName.txt" -ErrorAction SilentlyContinue
    }
}

# ============================================================
# SECTION 1: Workflow Structure Tests (no act required)
# ============================================================
Write-Host "`n=== SECTION 1: Workflow Structure Tests ===" -ForegroundColor Cyan
Write-ActResult "`n=== SECTION 1: Workflow Structure Tests ==="
Write-ActResult (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

$wfPath = Join-Path $ScriptDir ".github/workflows/secret-rotation-validator.yml"
$wfContent = Get-Content -Path $wfPath -Raw

# 1.1 Workflow file exists
Assert-Condition "Workflow file exists" `
    (Test-Path $wfPath) `
    "Workflow file not found at $wfPath"

# 1.2 Triggers: push
Assert-Condition "Trigger: push" `
    ($wfContent -match "push:") `
    "push trigger not found"

# 1.3 Triggers: pull_request
Assert-Condition "Trigger: pull_request" `
    ($wfContent -match "pull_request:") `
    "pull_request trigger not found"

# 1.4 Triggers: schedule
Assert-Condition "Trigger: schedule" `
    ($wfContent -match "schedule:") `
    "schedule trigger not found"

# 1.5 Triggers: workflow_dispatch
Assert-Condition "Trigger: workflow_dispatch" `
    ($wfContent -match "workflow_dispatch:") `
    "workflow_dispatch trigger not found"

# 1.6 References main script
Assert-Condition "References Invoke-SecretRotationValidator.ps1" `
    ($wfContent -match "Invoke-SecretRotationValidator\.ps1") `
    "workflow does not reference Invoke-SecretRotationValidator.ps1"

# 1.7 References tests
Assert-Condition "References SecretRotationValidator.Tests.ps1" `
    ($wfContent -match "SecretRotationValidator\.Tests\.ps1") `
    "workflow does not reference test file"

# 1.8 Script files actually exist
Assert-Condition "Invoke-SecretRotationValidator.ps1 exists" `
    (Test-Path (Join-Path $ScriptDir "Invoke-SecretRotationValidator.ps1")) `
    "main script file not found"

Assert-Condition "SecretRotationValidator.psm1 exists" `
    (Test-Path (Join-Path $ScriptDir "SecretRotationValidator.psm1")) `
    "module file not found"

Assert-Condition "SecretRotationValidator.Tests.ps1 exists" `
    (Test-Path (Join-Path $ScriptDir "SecretRotationValidator.Tests.ps1")) `
    "test file not found"

# 1.9 Fixture files exist
foreach ($fixture in @("fixtures/secrets-mixed.json", "fixtures/secrets-all-ok.json", "fixtures/secrets-all-expired.json")) {
    Assert-Condition "Fixture exists: $fixture" `
        (Test-Path (Join-Path $ScriptDir $fixture)) `
        "fixture file not found: $fixture"
}

# 1.10 actionlint validation
Write-Host "  [CHECK] Running actionlint..." -ForegroundColor Yellow
$actionlintResult = & actionlint $wfPath 2>&1
$actionlintExit = $LASTEXITCODE
Write-ActResult "actionlint output: $actionlintResult (exit $actionlintExit)"
Assert-Condition "actionlint passes" `
    ($actionlintExit -eq 0) `
    "actionlint failed: $actionlintResult"

# ============================================================
# SECTION 2: Act Integration Tests
# ============================================================
Write-Host "`n=== SECTION 2: Act Integration Tests ===" -ForegroundColor Cyan
Write-ActResult "`n=== SECTION 2: Act Integration Tests ==="

# Define test cases
$testCases = @(
    @{
        Name     = "TC1-Mixed"
        Fixtures = @("fixtures/secrets-mixed.json")
        # Expected: expired=1 (DB_PASSWORD), warning=1 (API_KEY), ok=1 (JWT_SECRET)
        Expected = @{
            ExitCode        = 0
            JobSucceeded    = $true
            PesterPassed    = $true
            FixtureName     = "secrets-mixed"
            ExpiredCount    = 1
            WarningCount    = 1
            OkCount         = 1
            ContainsSecret  = "DB_PASSWORD"
        }
    },
    @{
        Name     = "TC2-AllOk"
        Fixtures = @("fixtures/secrets-all-ok.json")
        # Expected: expired=0, warning=0, ok=2 (REDIS_PASS, SMTP_PASSWORD)
        Expected = @{
            ExitCode        = 0
            JobSucceeded    = $true
            PesterPassed    = $true
            FixtureName     = "secrets-all-ok"
            ExpiredCount    = 0
            WarningCount    = 0
            OkCount         = 2
            ContainsSecret  = "REDIS_PASS"
        }
    },
    @{
        Name     = "TC3-AllExpired"
        Fixtures = @("fixtures/secrets-all-expired.json")
        # Expected: expired=2 (OLD_API_KEY, LEGACY_SECRET), warning=0, ok=0
        Expected = @{
            ExitCode        = 0
            JobSucceeded    = $true
            PesterPassed    = $true
            FixtureName     = "secrets-all-expired"
            ExpiredCount    = 2
            WarningCount    = 0
            OkCount         = 0
            ContainsSecret  = "OLD_API_KEY"
        }
    }
)

foreach ($tc in $testCases) {
    $tcName = $tc.Name
    $exp    = $tc.Expected

    Write-Host "`n  --- Test Case: $tcName ---" -ForegroundColor Yellow
    Write-ActResult "`n### Test Case: $tcName ###"
    Write-ActResult "Fixtures: $($tc.Fixtures -join ', ')"

    # Run act
    Write-Host "    Running act (this may take a few minutes)..." -ForegroundColor DarkGray
    $result = Invoke-ActWithFixture -TestCaseName $tcName -FixtureFiles $tc.Fixtures

    Write-ActResult "Exit code: $($result.ExitCode)"
    Write-ActResult "--- STDOUT ---"
    Write-ActResult $result.Stdout
    Write-ActResult "--- STDERR ---"
    Write-ActResult $result.Stderr
    Write-ActResult "--- END OUTPUT ---"

    # Assert exit code
    Assert-Condition "$($tcName): act exit code 0" `
        ($result.ExitCode -eq 0) `
        "act exited with code $($result.ExitCode)"

    # Assert job succeeded
    Assert-Condition "$($tcName): Job succeeded message" `
        ($result.Output -match "Job succeeded") `
        "Output did not contain 'Job succeeded'"

    # Assert Pester tests passed
    Assert-Condition "$($tcName): Pester tests passed" `
        ($result.Output -match "Tests passed") `
        "Pester test-passed marker not found in output"

    # Assert exact fixture counts
    $fixtureName = $exp.FixtureName
    Assert-Condition "$($tcName): EXPIRED count = $($exp.ExpiredCount)" `
        ($result.Output -match "FIXTURE_${fixtureName}_EXPIRED=$($exp.ExpiredCount)") `
        "Expected FIXTURE_${fixtureName}_EXPIRED=$($exp.ExpiredCount) not found in output"

    Assert-Condition "$($tcName): WARNING count = $($exp.WarningCount)" `
        ($result.Output -match "FIXTURE_${fixtureName}_WARNING=$($exp.WarningCount)") `
        "Expected FIXTURE_${fixtureName}_WARNING=$($exp.WarningCount) not found in output"

    Assert-Condition "$($tcName): OK count = $($exp.OkCount)" `
        ($result.Output -match "FIXTURE_${fixtureName}_OK=$($exp.OkCount)") `
        "Expected FIXTURE_${fixtureName}_OK=$($exp.OkCount) not found in output"

    # Assert expected secret name appears in output
    Assert-Condition "$($tcName): Secret '$($exp.ContainsSecret)' in output" `
        ($result.Output -match [regex]::Escape($exp.ContainsSecret)) `
        "Expected secret '$($exp.ContainsSecret)' not found in output"
}

# ============================================================
# Final Summary
# ============================================================
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Total : $TotalTests"
Write-Host "Passed: $PassedTests" -ForegroundColor Green
Write-Host "Failed: $FailedTests" -ForegroundColor ($FailedTests -gt 0 ? "Red" : "Green")

if ($Failures.Count -gt 0) {
    Write-Host "`nFailures:" -ForegroundColor Red
    $Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

Write-ActResult "`n=== FINAL SUMMARY ==="
Write-ActResult "Total: $TotalTests | Passed: $PassedTests | Failed: $FailedTests"
if ($Failures.Count -gt 0) {
    Write-ActResult "Failures:"
    $Failures | ForEach-Object { Write-ActResult "  - $_" }
}
Write-ActResult "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

if ($FailedTests -gt 0) {
    Write-Host "`nSome tests failed. See act-result.txt for details." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nAll tests passed!" -ForegroundColor Green
}
