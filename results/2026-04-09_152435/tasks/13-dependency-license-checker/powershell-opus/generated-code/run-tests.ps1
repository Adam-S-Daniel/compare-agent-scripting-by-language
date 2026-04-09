# run-tests.ps1
# Test harness that runs all tests through GitHub Actions via act.
# Creates temp git repos with fixtures, runs act push, captures output,
# and asserts on expected values.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$projectDir = $PSScriptRoot
$actResultFile = Join-Path $projectDir 'act-result.txt'

# Clear previous results
if (Test-Path $actResultFile) {
    Remove-Item $actResultFile
}

# --- Workflow structure tests ---
Write-Output "=== WORKFLOW STRUCTURE TESTS ==="
Write-Output ""

# Test 1: YAML structure validation
Write-Output "--- Test: Workflow YAML structure ---"
$workflowPath = Join-Path $projectDir '.github/workflows/dependency-license-checker.yml'
$yaml = Get-Content -Path $workflowPath -Raw

# Check triggers
$hasPush = $yaml -match 'push:'
$hasPR = $yaml -match 'pull_request:'
$hasDispatch = $yaml -match 'workflow_dispatch:'
Write-Output "  Has push trigger: $hasPush"
Write-Output "  Has pull_request trigger: $hasPR"
Write-Output "  Has workflow_dispatch trigger: $hasDispatch"
if (-not $hasPush) { throw "Missing push trigger" }
if (-not $hasPR) { throw "Missing pull_request trigger" }
if (-not $hasDispatch) { throw "Missing workflow_dispatch trigger" }

# Check jobs and steps
$hasLicenseCheckJob = $yaml -match 'license-check:'
$hasCheckout = $yaml -match 'actions/checkout@v4'
$hasPwshShell = $yaml -match 'shell: pwsh'
Write-Output "  Has license-check job: $hasLicenseCheckJob"
Write-Output "  Has checkout step: $hasCheckout"
Write-Output "  Has pwsh shell: $hasPwshShell"
if (-not $hasLicenseCheckJob) { throw "Missing license-check job" }
if (-not $hasCheckout) { throw "Missing checkout step" }
if (-not $hasPwshShell) { throw "Missing pwsh shell" }

# Test 2: Script file references exist
Write-Output ""
Write-Output "--- Test: Script file references exist ---"
$scripts = @(
    'DependencyLicenseChecker.psm1',
    'DependencyLicenseChecker.Tests.ps1',
    'Invoke-LicenseCheck.ps1'
)
foreach ($script in $scripts) {
    $path = Join-Path $projectDir $script
    if (Test-Path $path) {
        Write-Output "  PASS: $script exists"
    }
    else {
        throw "Missing script: $script"
    }
}

# Check fixture files
$fixtures = @(
    'fixtures/package.json',
    'fixtures/requirements.txt',
    'fixtures/license-config.json',
    'fixtures/denied-config.json',
    'fixtures/mixed-config.json'
)
foreach ($fixture in $fixtures) {
    $path = Join-Path $projectDir $fixture
    if (Test-Path $path) {
        Write-Output "  PASS: $fixture exists"
    }
    else {
        throw "Missing fixture: $fixture"
    }
}

# Test 3: actionlint validation
Write-Output ""
Write-Output "--- Test: actionlint validation ---"
$lintResult = & actionlint $workflowPath 2>&1
$lintExitCode = $LASTEXITCODE
if ($lintExitCode -eq 0) {
    Write-Output "  PASS: actionlint passed (exit code 0)"
}
else {
    Write-Output "  FAIL: actionlint errors: $lintResult"
    throw "actionlint failed with exit code $lintExitCode"
}

Write-Output ""
Write-Output "=== ALL WORKFLOW STRUCTURE TESTS PASSED ==="
Write-Output ""

# --- Act integration test ---
Write-Output "=== ACT INTEGRATION TEST ==="
Write-Output ""

# Create a temp directory for the test repo
$tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "license-checker-test-$(Get-Random)"
New-Item -ItemType Directory -Path $tempBase -Force | Out-Null

try {
    # Copy all project files to the temp directory
    $filesToCopy = @(
        'DependencyLicenseChecker.psm1',
        'DependencyLicenseChecker.Tests.ps1',
        'Invoke-LicenseCheck.ps1'
    )
    foreach ($file in $filesToCopy) {
        Copy-Item -Path (Join-Path $projectDir $file) -Destination $tempBase
    }

    # Copy fixtures
    $fixtureDir = Join-Path $tempBase 'fixtures'
    New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null
    Copy-Item -Path (Join-Path $projectDir 'fixtures/*') -Destination $fixtureDir

    # Copy workflow
    $wfDir = Join-Path $tempBase '.github/workflows'
    New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
    Copy-Item -Path $workflowPath -Destination $wfDir

    # Copy .actrc if it exists
    $actrcSource = Join-Path $projectDir '.actrc'
    if (Test-Path $actrcSource) {
        Copy-Item -Path $actrcSource -Destination $tempBase
    }

    # Initialize git repo (act requires it)
    Push-Location $tempBase
    & git init --initial-branch=main 2>&1 | Out-Null
    & git config user.email "test@test.com" 2>&1 | Out-Null
    & git config user.name "Test" 2>&1 | Out-Null
    & git add -A 2>&1 | Out-Null
    & git commit -m "initial commit" 2>&1 | Out-Null

    Write-Output "Running act push from: $tempBase"
    Write-Output ""

    # Run act
    $actOutput = & act push --rm --pull=false 2>&1 | Out-String
    $actExitCode = $LASTEXITCODE

    Pop-Location

    # Write output to act-result.txt
    $separator = "=" * 70
    $resultContent = @"
$separator
TEST CASE: Full license checker pipeline
$separator
Exit Code: $actExitCode
$separator
$actOutput
$separator
"@

    Set-Content -Path $actResultFile -Value $resultContent

    Write-Output "act exit code: $actExitCode"
    Write-Output ""

    # Assert act succeeded
    if ($actExitCode -ne 0) {
        Write-Output "ACT OUTPUT:"
        Write-Output $actOutput
        throw "act push failed with exit code $actExitCode"
    }

    # Assert on specific expected output values
    Write-Output "--- Asserting expected output values ---"

    # Check that Pester tests ran and all passed
    if ($actOutput -match 'Tests Passed: (\d+)') {
        $passedCount = [int]$Matches[1]
        Write-Output "  PASS: Pester reported $passedCount tests passed"
        if ($passedCount -ne 23) {
            throw "Expected 23 tests passed, got $passedCount"
        }
    }
    else {
        throw "Could not find Pester test results in act output"
    }

    if ($actOutput -match 'Failed: (\d+)') {
        $failedCount = [int]$Matches[1]
        if ($failedCount -ne 0) {
            throw "Expected 0 failed tests, got $failedCount"
        }
        Write-Output "  PASS: 0 tests failed"
    }

    # Check package.json license check output
    if ($actOutput -match 'Total dependencies: 3') {
        Write-Output "  PASS: package.json reported 3 total dependencies"
    }
    else {
        throw "Expected 'Total dependencies: 3' in output"
    }

    if ($actOutput -match 'RESULT: PASS - All licenses compliant') {
        Write-Output "  PASS: All-approved config returned PASS"
    }
    else {
        throw "Expected 'RESULT: PASS - All licenses compliant' in output"
    }

    # Check requirements.txt license check output
    if ($actOutput -match 'Total dependencies: 4') {
        Write-Output "  PASS: requirements.txt reported 4 total dependencies"
    }
    else {
        throw "Expected 'Total dependencies: 4' in output"
    }

    # Check denied license detection
    if ($actOutput -match 'Correctly detected denied licenses \(exit code 1\)') {
        Write-Output "  PASS: Denied license detection worked"
    }
    else {
        throw "Expected denied license detection message in output"
    }

    # Check mixed config detection
    if ($actOutput -match 'Correctly detected denied licenses with mixed config \(exit code 1\)') {
        Write-Output "  PASS: Mixed config denied license detection worked"
    }
    else {
        throw "Expected mixed config denied detection message in output"
    }

    # Check specific license values in output
    if ($actOutput -match 'Approved: 3') {
        Write-Output "  PASS: Approved count 3 for all-approved config"
    }
    else {
        throw "Expected 'Approved: 3' in output"
    }

    if ($actOutput -match 'Approved: 4') {
        Write-Output "  PASS: Approved count 4 for requirements.txt"
    }
    else {
        throw "Expected 'Approved: 4' in output"
    }

    # Check that all jobs succeeded
    $jobSucceeded = [regex]::Matches($actOutput, 'Job succeeded')
    if ($jobSucceeded.Count -ge 1) {
        Write-Output "  PASS: Job succeeded ($($jobSucceeded.Count) occurrence(s))"
    }
    else {
        throw "Expected 'Job succeeded' in act output"
    }

    Write-Output ""
    Write-Output "=== ALL ACT INTEGRATION TESTS PASSED ==="
}
finally {
    # Cleanup temp dir
    if (Test-Path $tempBase) {
        Remove-Item -Path $tempBase -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ""
Write-Output "=== ALL TESTS COMPLETE ==="
Write-Output "Results written to: $actResultFile"
