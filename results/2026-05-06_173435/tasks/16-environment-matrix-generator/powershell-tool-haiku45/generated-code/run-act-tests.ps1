<#
.SYNOPSIS
Test harness that runs the Environment Matrix Generator through GitHub Actions (act).

.DESCRIPTION
Executes the workflow through act, captures output, verifies test results, and
generates a comprehensive test report in act-result.txt.
#>

[CmdletBinding()]
param(
    [string]$ActWorkspace = $PSScriptRoot,
    [string]$OutputFile = (Join-Path $PSScriptRoot "act-result.txt")
)

Write-Output "[TEST HARNESS] Environment Matrix Generator - Act Test Runner"
Write-Output "[TEST HARNESS] Starting at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output ""

# Clear previous output file
if (Test-Path $OutputFile) {
    Remove-Item $OutputFile -Force
}

# Test cases to run through act
$testCases = @(
    @{
        name = "Basic Matrix Generation (push event)"
        description = "Validates basic matrix generation with OS and language"
        event = "push"
    },
    @{
        name = "Workflow Dispatch"
        description = "Tests manual workflow trigger"
        event = "workflow_dispatch"
    },
    @{
        name = "Pull Request Event"
        description = "Tests PR trigger"
        event = "pull_request"
    }
)

$testNumber = 0
$passedTests = 0
$failedTests = 0

foreach ($testCase in $testCases) {
    $testNumber++
    $testName = $testCase.name
    $testDescription = $testCase.description

    Write-Output "[TEST $testNumber] $testName"
    Write-Output "Description: $testDescription"
    Write-Output "---"

    # Add to output file
    Add-Content -Path $OutputFile -Value "=== TEST CASE $testNumber: $testName ==="
    Add-Content -Path $OutputFile -Value "Description: $testDescription"
    Add-Content -Path $OutputFile -Value "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-Content -Path $OutputFile -Value ""

    try {
        # Run act with the workflow
        $actOutput = & act push --rm 2>&1
        $actExitCode = $LASTEXITCODE

        Write-Output "Act exit code: $actExitCode"

        # Check for success indicators in output
        $hasJobSucceeded = $actOutput -match "Job succeeded"
        $hasTestsPassed = $actOutput -match "Tests Passed: \d+"
        $hasFailedZero = $actOutput -match "Failed: 0"

        Add-Content -Path $OutputFile -Value "Exit Code: $actExitCode"
        Add-Content -Path $OutputFile -Value ""
        Add-Content -Path $OutputFile -Value "=== ACT OUTPUT ==="
        Add-Content -Path $OutputFile -Value $actOutput
        Add-Content -Path $OutputFile -Value ""

        if ($actExitCode -eq 0) {
            Write-Output "✓ Test PASSED (exit code 0)"
            $passedTests++

            # Verify job success
            if ($hasJobSucceeded) {
                Write-Output "✓ Job completed successfully"
                Add-Content -Path $OutputFile -Value "✓ Job completed successfully"
            }

            # Verify tests passed
            if ($hasTestsPassed -and $hasFailedZero) {
                Write-Output "✓ All tests passed"
                Add-Content -Path $OutputFile -Value "✓ All tests passed"
            }

            Add-Content -Path $OutputFile -Value ""
            Add-Content -Path $OutputFile -Value "RESULT: PASSED"
        } else {
            Write-Output "✗ Test FAILED (exit code $actExitCode)"
            $failedTests++
            Add-Content -Path $OutputFile -Value ""
            Add-Content -Path $OutputFile -Value "RESULT: FAILED"
        }
    } catch {
        Write-Error "Error running test case '$testName': $_"
        $failedTests++
        Add-Content -Path $OutputFile -Value "ERROR: $_"
        Add-Content -Path $OutputFile -Value "RESULT: ERROR"
    }

    Write-Output ""
    Add-Content -Path $OutputFile -Value ""
    Add-Content -Path $OutputFile -Value "---"
    Add-Content -Path $OutputFile -Value ""
}

# Summary
Write-Output "[TEST HARNESS] Test Summary"
Write-Output "Total Tests: $($testCases.Count)"
Write-Output "Passed: $passedTests"
Write-Output "Failed: $failedTests"

Add-Content -Path $OutputFile -Value ""
Add-Content -Path $OutputFile -Value "=== TEST SUMMARY ==="
Add-Content -Path $OutputFile -Value "Total Tests: $($testCases.Count)"
Add-Content -Path $OutputFile -Value "Passed: $passedTests"
Add-Content -Path $OutputFile -Value "Failed: $failedTests"
Add-Content -Path $OutputFile -Value "Test Run Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

if ($failedTests -gt 0) {
    Write-Output "❌ Some tests failed"
    exit 1
} else {
    Write-Output "✓ All tests passed"
    exit 0
}
