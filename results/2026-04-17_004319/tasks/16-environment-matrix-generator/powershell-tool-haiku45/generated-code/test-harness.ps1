# Test Harness for Environment Matrix Generator
# Runs the GitHub Actions workflow locally using act and verifies results

param(
    [string]$ActBinary = 'act',
    [string]$OutputFile = 'act-result.txt'
)

function Write-TestLog {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $OutputFile -Value $Message
}

function Write-TestHeader {
    param([string]$TestName)
    $header = @"
================================================================================
Test: $TestName
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
================================================================================
"@
    Write-TestLog $header
}

function Run-ActWorkflow {
    param([string]$EventType = 'push')

    # Clear previous output
    Write-TestLog "`n"

    Write-TestLog "Running act with event: $EventType"

    # Run the workflow
    $output = & $ActBinary $EventType --rm 2>&1
    $exitCode = $LASTEXITCODE

    Write-TestLog "Exit Code: $exitCode"
    Write-TestLog ""
    Write-TestLog "=== ACT OUTPUT START ==="
    Write-TestLog $output
    Write-TestLog "=== ACT OUTPUT END ==="
    Write-TestLog ""

    return @{
        Output = $output
        ExitCode = $exitCode
    }
}

function Verify-TestResult {
    param(
        [string]$TestName,
        [hashtable]$Result,
        [scriptblock]$ValidationBlock
    )

    Write-TestLog "`nVerifying: $TestName"

    if ($Result.ExitCode -ne 0) {
        Write-TestLog "✗ FAILED: Workflow exited with code $($Result.ExitCode)"
        return $false
    }

    try {
        $output = $Result.Output
        & $ValidationBlock
        Write-TestLog "✓ PASSED: $TestName"
        return $true
    } catch {
        Write-TestLog "✗ FAILED: $TestName - $_"
        return $false
    }
}

# Initialize output file
"Environment Matrix Generator - Test Harness Results" | Out-File -Path $OutputFile -Encoding UTF8
"Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $OutputFile

# Test 1: Basic Pester Test Execution
Write-TestHeader "Test 1: Pester Tests via GitHub Actions"
$result = Run-ActWorkflow -EventType 'push'

Verify-TestResult -TestName "Pester tests pass" -Result $result -ValidationBlock {
    if ($output -notlike "*Tests Passed: 18*") {
        throw "Expected 18 tests to pass, got: $(Select-String 'Tests Passed:' -InputObject $output)"
    }
    if ($output -like "*Tests Failed: 1*" -or $output -like "*Tests Failed: 2*" -or $output -like "*Failed*" -and $output -notlike "*Tests Failed: 0*") {
        throw "Some tests failed: $(Select-String 'Tests Failed:' -InputObject $output)"
    }
}

# Test 2: Matrix Generation Output
Write-TestHeader "Test 2: Matrix Generation Output"
$result = Run-ActWorkflow -EventType 'push'

Verify-TestResult -TestName "Matrix generation produces valid JSON" -Result $result -ValidationBlock {
    if ($output -notlike "*Matrix entries:*") {
        throw "Expected to find matrix entry count in output"
    }

    # Check for both test fixtures (basic and complex)
    if ($output -notlike "*basic*" -or $output -notlike "*complex*") {
        throw "Expected both basic and complex test fixtures to run"
    }
}

# Test 3: All Jobs Succeed
Write-TestHeader "Test 3: All Jobs Succeed"
$result = Run-ActWorkflow -EventType 'push'

Verify-TestResult -TestName "All GitHub Actions jobs succeed" -Result $result -ValidationBlock {
    # In act output, we should see job completion markers
    $jobLines = $output | Select-String -Pattern "(Job|test|demo|validate)" | ForEach-Object { $_.Line }

    if ($jobLines.Count -eq 0) {
        throw "No job execution lines found in output"
    }

    Write-TestLog "Jobs executed:"
    $jobLines | ForEach-Object { Write-TestLog "  $_" }
}

# Test 4: JSON Output Validation
Write-TestHeader "Test 4: JSON Output Validation"
$result = Run-ActWorkflow -EventType 'push'

Verify-TestResult -TestName "JSON validation job succeeds" -Result $result -ValidationBlock {
    if ($output -notlike "*✓*Basic matrix JSON is valid*") {
        throw "Expected successful JSON validation message not found"
    }
    if ($output -notlike "*✓*Correctly rejected oversized matrix*") {
        throw "Expected size validation message not found"
    }
}

# Test 5: Workflow Dispatch
Write-TestHeader "Test 5: Manual Workflow Dispatch"
$result = Run-ActWorkflow -EventType 'workflow_dispatch'

Verify-TestResult -TestName "Workflow runs on manual dispatch" -Result $result -ValidationBlock {
    if ($result.ExitCode -ne 0) {
        throw "Workflow dispatch failed with exit code $($result.ExitCode)"
    }
}

Write-TestLog "`n`n"
Write-TestLog "================================================================================`n"
Write-TestLog "All Test Harness Tests Completed"
Write-TestLog "Results saved to: $(Resolve-Path $OutputFile)"
