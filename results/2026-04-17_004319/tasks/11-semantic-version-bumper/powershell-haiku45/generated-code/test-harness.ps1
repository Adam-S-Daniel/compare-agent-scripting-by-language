# Test harness for running semantic version bumper tests through GitHub Actions via act
# This script sets up test fixtures and runs the workflow through act

param(
    [switch]$Verbose = $false
)

$ErrorActionPreference = 'Stop'
$resultFile = "act-result.txt"
$testCaseCount = 0
$successCount = 0
$failureCount = 0

# Initialize result file
"Semantic Version Bumper - act Workflow Test Results" | Set-Content $resultFile
"=" * 60 | Add-Content $resultFile
"Test started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $resultFile
"" | Add-Content $resultFile

function Write-TestLog {
    param([string]$Message)
    Write-Host $Message
    $Message | Add-Content $resultFile
}

function Run-TestCase {
    param(
        [string]$Name,
        [hashtable]$ExpectedResults,
        [scriptblock]$Setup
    )

    $testCaseCount++
    Write-TestLog ""
    Write-TestLog "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-TestLog "TEST CASE $testCaseCount: $Name"
    Write-TestLog "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    try {
        # Run setup
        if ($Setup) {
            & $Setup
        }

        # Run act push
        Write-TestLog "Running: act push --rm"
        $output = act push --rm 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            Write-TestLog "✗ FAILED: act exited with code $exitCode"
            $failureCount++
            $output | Add-Content $resultFile
            return $false
        }

        # Check for job succeeded messages
        if ($output -match "Job succeeded") {
            Write-TestLog "✓ Job succeeded"
        } else {
            Write-TestLog "⚠ No explicit success message found"
        }

        # Verify expected results
        $allPassed = $true
        foreach ($expectedKey in $ExpectedResults.Keys) {
            $expectedValue = $ExpectedResults[$expectedKey]
            if ($output -match [regex]::Escape($expectedValue)) {
                Write-TestLog "✓ Expected output found: $expectedValue"
            } else {
                Write-TestLog "✗ Expected output NOT found: $expectedValue"
                $allPassed = $false
            }
        }

        if ($allPassed) {
            Write-TestLog "✓ TEST CASE $testCaseCount PASSED"
            $successCount++
            return $true
        } else {
            Write-TestLog "✗ TEST CASE $testCaseCount FAILED"
            $failureCount++
            return $false
        }

    } catch {
        Write-TestLog "✗ TEST CASE $testCaseCount ERROR: $_"
        $failureCount++
        return $false
    }
}

# Verify prerequisites
Write-Host "Checking prerequisites..."
if (-not (Get-Command -Name act -ErrorAction SilentlyContinue)) {
    Write-Host "⚠ 'act' command not found. These tests require nektos/act to be installed."
    Write-Host "  Install with: https://github.com/nektos/act#installation"
    Write-TestLog "⚠ Prerequisites: act not found - cannot run full test suite"
    exit 0
}

Write-Host "✓ act is available: $(act --version)"
"Prerequisites check passed" | Add-Content $resultFile
"" | Add-Content $resultFile

# Verify Docker is running
Write-Host "Checking Docker..."
try {
    $dockerCheck = docker ps 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Docker is running"
        "Docker is running" | Add-Content $resultFile
    } else {
        Write-Host "⚠ Docker check inconclusive, but continuing..."
        "Docker check inconclusive" | Add-Content $resultFile
    }
} catch {
    Write-Host "⚠ Docker check failed, but continuing..."
    "Docker check inconclusive" | Add-Content $resultFile
}
"" | Add-Content $resultFile

# Run test cases
Write-TestLog ""
Write-TestLog "Starting workflow tests..."
Write-TestLog ""

# Test Case 1: Basic workflow run with Pester tests
Run-TestCase -Name "Pester Tests Execution" -ExpectedResults @{
    "Tests Passed: 16" = "Tests Passed: 16"
    "Failed: 0" = "Failed: 0"
} -Setup {}

# Test Case 2: Manual commit tests
Run-TestCase -Name "Manual Commit Version Bumping" -ExpectedResults @{
    "1.0.0" = "1.0.0"
    "1.1.0" = "1.1.0"
    "2.0.0" = "2.0.0"
} -Setup {}

# Test Case 3: Workflow file validation
Run-TestCase -Name "Workflow Syntax Validation" -ExpectedResults @{
    "Workflow file exists" = "Workflow file exists"
    "Workflow file readable" = "Workflow file readable"
} -Setup {}

# Summary
Write-TestLog ""
Write-TestLog "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-TestLog "TEST SUMMARY"
Write-TestLog "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-TestLog "Total test cases: $testCaseCount"
Write-TestLog "Passed: $successCount"
Write-TestLog "Failed: $failureCount"
Write-TestLog "Test ended: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

if ($failureCount -eq 0) {
    Write-TestLog "✓ ALL TESTS PASSED"
    exit 0
} else {
    Write-TestLog "✗ SOME TESTS FAILED"
    exit 1
}
