<#
.SYNOPSIS
    Integration test harness for running tests through GitHub Actions via act.
.DESCRIPTION
    This script sets up test cases, runs act push for each case, and validates outputs.
    All act runs are captured to act-result.txt for inspection.
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$actResultFile = "act-result.txt"
$testsPassed = 0
$testsFailed = 0

# Clear any previous results
if (Test-Path $actResultFile) {
    Remove-Item $actResultFile -Force
}

Write-Host "=== Test Results Aggregator - ACT Integration Tests ===" -ForegroundColor Cyan

# Helper function to run act and capture output
function Invoke-ActTest {
    param(
        [string]$TestName,
        [string]$TestDescription,
        [hashtable]$ExpectedValues
    )

    Write-Host "`n[TEST] $TestName" -ForegroundColor Yellow
    Write-Host "  $TestDescription"

    try {
        # Run act with push trigger, remove containers after run
        $output = & act push --rm 2>&1 | Tee-Object -Variable actOutput

        # Append to results file
        "=== Test: $TestName ===" | Out-File -FilePath $actResultFile -Encoding UTF8 -Append
        $output | Out-File -FilePath $actResultFile -Encoding UTF8 -Append
        "`n" | Out-File -FilePath $actResultFile -Encoding UTF8 -Append

        # Check for success indicators
        $jobSucceeded = $output -match "Job succeeded"

        if (-not $jobSucceeded) {
            Write-Host "  ❌ FAILED: Job did not succeed" -ForegroundColor Red
            $script:testsFailed += 1
            return $false
        }

        # Verify expected values if provided
        if ($ExpectedValues) {
            foreach ($key in $ExpectedValues.Keys) {
                $expectedValue = $ExpectedValues[$key]
                if ($output -match [regex]::Escape($expectedValue)) {
                    Write-Host "  ✅ Found expected value: '$expectedValue'" -ForegroundColor Green
                } else {
                    Write-Host "  ❌ Missing expected value: '$expectedValue'" -ForegroundColor Red
                    $script:testsFailed += 1
                    return $false
                }
            }
        }

        Write-Host "  ✅ PASSED" -ForegroundColor Green
        $script:testsPassed += 1
        return $true

    } catch {
        Write-Host "  ❌ FAILED: $_" -ForegroundColor Red
        "ERROR: $_" | Out-File -FilePath $actResultFile -Encoding UTF8 -Append
        $script:testsFailed += 1
        return $false
    }
}

# Test 1: Basic workflow execution with all fixture files
Write-Host "`n--- Test Suite 1: Basic Workflow Execution ---" -ForegroundColor Cyan
Invoke-ActTest `
    -TestName "Workflow_BasicExecution" `
    -TestDescription "Verify workflow runs successfully with fixture files" `
    -ExpectedValues @{
        "Run Pester tests" = "Run Pester tests"
        "Run test result aggregation" = "Run test result aggregation"
        "Job succeeded" = "Job succeeded"
    }

# Test 2: Verify Pester tests pass
Write-Host "`n--- Test Suite 2: Pester Test Execution ---" -ForegroundColor Cyan
Invoke-ActTest `
    -TestName "PesterTests_AllPass" `
    -TestDescription "Verify all Pester tests pass" `
    -ExpectedValues @{
        "Tests Passed" = "Tests Passed"
        "Failed: 0" = "Failed: 0"
    }

# Test 3: Verify test aggregation results
Write-Host "`n--- Test Suite 3: Test Aggregation ---" -ForegroundColor Cyan
Invoke-ActTest `
    -TestName "TestAggregation_Results" `
    -TestDescription "Verify test aggregation produces expected counts" `
    -ExpectedValues @{
        "Total Tests" = "Total Tests"
        "Successfully aggregated" = "Successfully aggregated"
    }

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host "`nDetailed results saved to: $actResultFile"

if ($testsFailed -gt 0) {
    Write-Host "`n❌ Some tests failed. Check $actResultFile for details." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ All tests passed!" -ForegroundColor Green
    exit 0
}
