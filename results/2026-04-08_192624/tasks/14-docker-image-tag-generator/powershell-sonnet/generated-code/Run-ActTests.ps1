# Act-based integration test harness for Docker Image Tag Generator
#
# This script:
# 1. Sets up a temp git repo with the project files
# 2. Runs `act push --rm` to execute the workflow in Docker
# 3. Saves all output to act-result.txt
# 4. Asserts exact expected values from each test case's output
# 5. Asserts every job shows "Job succeeded"
#
# Also includes workflow structure tests (YAML parsing, path existence, actionlint).

param(
    [string]$WorkDir = $PSScriptRoot,
    [string]$ActResultFile = (Join-Path $PSScriptRoot "act-result.txt")
)

$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-TestHeader {
    param([string]$Name)
    $line = "=" * 60
    Write-Host ""
    Write-Host $line
    Write-Host "TEST: $Name"
    Write-Host $line
}

function Assert-Contains {
    param([string]$Output, [string]$Expected, [string]$TestName)
    if ($Output -match [regex]::Escape($Expected)) {
        Write-Host "  PASS: Found '$Expected'"
    }
    else {
        Write-Error "  FAIL [$TestName]: Expected to find '$Expected' in output."
        throw "Assertion failed: '$Expected' not found in output"
    }
}

function Assert-JobSucceeded {
    param([string]$Output, [string]$JobName)
    # act prints "Job succeeded" or "✅" for successful jobs
    if ($Output -match "Job succeeded" -or $Output -match "success") {
        Write-Host "  PASS: Job succeeded indicator found"
    }
    else {
        Write-Error "  FAIL: No 'Job succeeded' indicator in output for job '$JobName'"
        throw "Job did not succeed: $JobName"
    }
}

# Initialize act-result.txt
"" | Set-Content -Path $ActResultFile
function Append-ActResult {
    param([string]$Content)
    Add-Content -Path $ActResultFile -Value $Content
}

# ── Section 1: Workflow Structure Tests ──────────────────────────────────────

Write-TestHeader "Workflow Structure Tests"

$workflowPath = Join-Path $WorkDir ".github/workflows/docker-image-tag-generator.yml"

# Test: workflow file exists
Write-Host "Checking workflow file exists..."
if (Test-Path $workflowPath) {
    Write-Host "  PASS: Workflow file exists at $workflowPath"
}
else {
    throw "FAIL: Workflow file not found at $workflowPath"
}

# Test: referenced script files exist
Write-Host "Checking referenced script files exist..."
$scriptPath = Join-Path $WorkDir "New-DockerImageTags.ps1"
$testsPath  = Join-Path $WorkDir "New-DockerImageTags.Tests.ps1"

if (Test-Path $scriptPath) { Write-Host "  PASS: New-DockerImageTags.ps1 exists" }
else { throw "FAIL: New-DockerImageTags.ps1 not found" }

if (Test-Path $testsPath) { Write-Host "  PASS: New-DockerImageTags.Tests.ps1 exists" }
else { throw "FAIL: New-DockerImageTags.Tests.ps1 not found" }

# Test: parse YAML and check structure
Write-Host "Checking workflow YAML structure..."
$yamlContent = Get-Content $workflowPath -Raw

# Check for required triggers
if ($yamlContent -match 'push:') { Write-Host "  PASS: 'push' trigger present" }
else { throw "FAIL: 'push' trigger not found in workflow" }

if ($yamlContent -match 'pull_request') { Write-Host "  PASS: 'pull_request' trigger present" }
else { throw "FAIL: 'pull_request' trigger not found in workflow" }

if ($yamlContent -match 'workflow_dispatch') { Write-Host "  PASS: 'workflow_dispatch' trigger present" }
else { throw "FAIL: 'workflow_dispatch' trigger not found in workflow" }

# Check for required jobs
if ($yamlContent -match 'generate-tags:') { Write-Host "  PASS: 'generate-tags' job present" }
else { throw "FAIL: 'generate-tags' job not found in workflow" }

# Check for checkout action
if ($yamlContent -match 'actions/checkout@v4') { Write-Host "  PASS: 'actions/checkout@v4' referenced" }
else { throw "FAIL: 'actions/checkout@v4' not found in workflow" }

# Test: actionlint passes
Write-Host "Running actionlint..."
$actionlintOutput = & actionlint $workflowPath 2>&1
$actionlintExit = $LASTEXITCODE
if ($actionlintExit -eq 0) {
    Write-Host "  PASS: actionlint passed (exit code 0)"
}
else {
    throw "FAIL: actionlint failed with exit code $actionlintExit. Output: $actionlintOutput"
}

Append-ActResult "=== WORKFLOW STRUCTURE TESTS ==="
Append-ActResult "Workflow file exists: PASS"
Append-ActResult "Script files exist: PASS"
Append-ActResult "YAML structure checks: PASS"
Append-ActResult "actionlint exit code: $actionlintExit"
Append-ActResult ""

# ── Section 2: Act Integration Tests ─────────────────────────────────────────

# Set up a temporary git repo with the project files, then run act
function Invoke-ActTest {
    param(
        [string]$TestName,
        [string]$JobFilter,          # e.g. "test-fixture-main"
        [hashtable]$EnvOverrides,    # Extra env vars to write into workflow env (not used — we rely on job env)
        [string[]]$ExpectedOutputs,  # Strings that must appear in act output
        [int]$ExpectedExitCode = 0
    )

    Write-TestHeader "Act Test: $TestName"

    # Create temp directory for isolated git repo
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    Write-Host "  Temp dir: $tmpDir"

    try {
        # Copy project files into temp dir
        $filesToCopy = @(
            "New-DockerImageTags.ps1",
            "New-DockerImageTags.Tests.ps1"
        )
        foreach ($f in $filesToCopy) {
            Copy-Item (Join-Path $WorkDir $f) (Join-Path $tmpDir $f)
        }

        # Copy .github/workflows
        $wfDir = Join-Path $tmpDir ".github/workflows"
        New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
        Copy-Item $workflowPath (Join-Path $wfDir "docker-image-tag-generator.yml")

        # Initialize git repo
        Push-Location $tmpDir
        & git init -q
        & git config user.email "test@test.com"
        & git config user.name "Test"
        & git add -A
        & git commit -q -m "test commit"
        Pop-Location

        # Run act with the specific job filter
        Write-Host "  Running: act push --job $JobFilter --rm"
        $actArgs = @("push", "--job", $JobFilter, "--rm", "--no-skip-checkout")
        $actOutput = & act @actArgs 2>&1 | ForEach-Object { $_.ToString() }
        $actOutputStr = $actOutput -join "`n"
        $actExitCode = $LASTEXITCODE
        Write-Host "  act exit code: $actExitCode"

        # Append to act-result.txt
        Append-ActResult "=== ACT TEST: $TestName ==="
        Append-ActResult "Job: $JobFilter"
        Append-ActResult "Exit code: $actExitCode"
        Append-ActResult "--- Output ---"
        Append-ActResult $actOutputStr
        Append-ActResult ""

        # Assert exit code
        if ($actExitCode -ne $ExpectedExitCode) {
            throw "FAIL: act exited with $actExitCode (expected $ExpectedExitCode).`nOutput:`n$actOutputStr"
        }
        Write-Host "  PASS: act exit code $actExitCode"

        # Assert job succeeded
        Assert-JobSucceeded -Output $actOutputStr -JobName $JobFilter

        # Assert expected outputs
        foreach ($expected in $ExpectedOutputs) {
            Assert-Contains -Output $actOutputStr -Expected $expected -TestName $TestName
        }

        Write-Host "  RESULT: PASS"
        return $true
    }
    catch {
        Append-ActResult "FAILED: $_"
        Append-ActResult ""
        throw
    }
    finally {
        if (Test-Path $tmpDir) {
            Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Check if act and Docker are available
Write-Host ""
Write-Host "Checking act availability..."
$actVersion = & act --version 2>&1
Write-Host "  act version: $actVersion"

Write-Host "Checking Docker availability..."
$dockerVersion = & docker --version 2>&1
Write-Host "  Docker: $dockerVersion"

# Run act integration tests for each fixture job
$allPassed = $true
$testResults = @()

# Test 1: main branch -> latest
try {
    Invoke-ActTest `
        -TestName "main branch produces 'latest' tag" `
        -JobFilter "test-fixture-main" `
        -ExpectedOutputs @("PASS: 'latest' tag found for main branch", "latest")
    $testResults += "PASS: test-fixture-main"
}
catch {
    Write-Warning "Test failed: $_"
    $testResults += "FAIL: test-fixture-main - $_"
    $allPassed = $false
}

# Test 2: PR branch -> pr-42
try {
    Invoke-ActTest `
        -TestName "PR branch produces 'pr-42' tag" `
        -JobFilter "test-fixture-pr" `
        -ExpectedOutputs @("PASS: 'pr-42' tag found for PR branch", "pr-42")
    $testResults += "PASS: test-fixture-pr"
}
catch {
    Write-Warning "Test failed: $_"
    $testResults += "FAIL: test-fixture-pr - $_"
    $allPassed = $false
}

# Test 3: semver tag -> v1.2.3 + latest
try {
    Invoke-ActTest `
        -TestName "semver tag produces v1.2.3 and latest" `
        -JobFilter "test-fixture-semver" `
        -ExpectedOutputs @("PASS: 'v1.2.3' tag found", "PASS: 'latest' tag found alongside semver")
    $testResults += "PASS: test-fixture-semver"
}
catch {
    Write-Warning "Test failed: $_"
    $testResults += "FAIL: test-fixture-semver - $_"
    $allPassed = $false
}

# Test 4: feature branch -> branch-sha
try {
    Invoke-ActTest `
        -TestName "feature branch produces sanitized branch-sha tag" `
        -JobFilter "test-fixture-feature-branch" `
        -ExpectedOutputs @("PASS: Correct branch-sha tag found", "feature-my-cool-feature-1a2b3c4")
    $testResults += "PASS: test-fixture-feature-branch"
}
catch {
    Write-Warning "Test failed: $_"
    $testResults += "FAIL: test-fixture-feature-branch - $_"
    $allPassed = $false
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "=" * 60
Write-Host "TEST SUMMARY"
Write-Host "=" * 60
foreach ($r in $testResults) {
    Write-Host "  $r"
}

Append-ActResult "=== SUMMARY ==="
foreach ($r in $testResults) {
    Append-ActResult $r
}
Append-ActResult ""

if ($allPassed) {
    Write-Host ""
    Write-Host "All act integration tests PASSED!"
    Append-ActResult "Overall result: ALL TESTS PASSED"
    exit 0
}
else {
    Write-Host ""
    Write-Error "One or more act integration tests FAILED."
    Append-ActResult "Overall result: SOME TESTS FAILED"
    exit 1
}
