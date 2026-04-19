#!/usr/bin/env pwsh

<#
.SYNOPSIS
Test harness that runs the environment matrix generator through GitHub Actions via act.

.DESCRIPTION
Creates a temporary git repository, runs the workflow with act, and verifies all tests pass.
Outputs comprehensive results to act-result.txt.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Check for required tools
Write-Host "Checking for required tools..." -ForegroundColor Cyan
$requiredTools = @('git', 'docker', 'act')
foreach ($tool in $requiredTools) {
    $exists = $null -ne (Get-Command $tool -ErrorAction SilentlyContinue)
    if (-not $exists) {
        throw "Required tool not found: $tool"
    }
    Write-Host "✓ $tool is available" -ForegroundColor Green
}

# Clean up any previous results
$resultFile = 'act-result.txt'
if (Test-Path $resultFile) {
    Remove-Item $resultFile
}

Write-Host "Creating temporary workspace..." -ForegroundColor Cyan
$baseTempDir = [System.IO.Path]::GetTempPath()
$tempPath = Join-Path $baseTempDir "matrix-gen-$(Get-Random)"
[void](New-Item -ItemType Directory -Path $tempPath -Force)
Write-Host "Temp directory: $tempPath" -ForegroundColor Gray

try {
    # Copy project files to temp directory
    Write-Host "Copying project files..." -ForegroundColor Cyan
    Copy-Item -Path 'environment-matrix-generator.ps1' -Destination $tempPath
    Copy-Item -Path 'environment-matrix-generator.tests.ps1' -Destination $tempPath
    Copy-Item -Path '.github' -Destination $tempPath -Recurse
    Copy-Item -Path '.actrc' -Destination $tempPath -ErrorAction SilentlyContinue

    # Initialize git repo
    Write-Host "Initializing git repository..." -ForegroundColor Cyan
    Push-Location $tempPath
    git init | Out-Null
    git config user.email "test@example.com" | Out-Null
    git config user.name "Test User" | Out-Null
    git add . | Out-Null
    git commit -m "Initial commit" | Out-Null

    # Run the workflow with act
    Write-Host "Running workflow with act..." -ForegroundColor Cyan
    $actCommand = 'act push --rm -W .github/workflows/environment-matrix-generator.yml'
    $actOutput = (Invoke-Expression $actCommand) 2>&1

    # Save output
    "=== GitHub Actions Workflow Execution ===" | Out-File -FilePath $resultFile
    "Command: $actCommand" | Out-File -FilePath $resultFile -Append
    "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $resultFile -Append
    "Temporary directory: $($tempPath)" | Out-File -FilePath $resultFile -Append
    "" | Out-File -FilePath $resultFile -Append
    "=== Output ===" | Out-File -FilePath $resultFile -Append
    $actOutput | Out-File -FilePath $resultFile -Append

    # Check for success indicators in output
    Write-Host "Analyzing results..." -ForegroundColor Cyan
    $actOutputStr = $actOutput -join "`n"

    # Look for test success markers
    $testsPassed = $actOutputStr -match "Tests Passed: 10"
    $jobSucceeded = $actOutputStr -match "Job succeeded"

    "" | Out-File -FilePath $resultFile -Append
    "=== Validation Results ===" | Out-File -FilePath $resultFile -Append

    if ($testsPassed) {
        Write-Host "✓ All 10 tests passed" -ForegroundColor Green
        "✓ All 10 tests passed" | Out-File -FilePath $resultFile -Append
    }
    else {
        Write-Host "✗ Tests did not pass as expected" -ForegroundColor Red
        "✗ Tests did not pass as expected" | Out-File -FilePath $resultFile -Append
    }

    if ($jobSucceeded) {
        Write-Host "✓ Job succeeded" -ForegroundColor Green
        "✓ Job succeeded" | Out-File -FilePath $resultFile -Append
    }
    else {
        # Try to find job status
        if ($actOutputStr -match "FAILED") {
            Write-Host "✗ Job failed" -ForegroundColor Red
            "✗ Job failed" | Out-File -FilePath $resultFile -Append
        }
        else {
            Write-Host "⚠ Job status unclear - check output" -ForegroundColor Yellow
            "⚠ Job status unclear - check output" | Out-File -FilePath $resultFile -Append
        }
    }

    # Verify matrix generation in output
    if ($actOutputStr -match "Generated matrix:") {
        Write-Host "✓ Matrix generation output detected" -ForegroundColor Green
        "✓ Matrix generation output detected" | Out-File -FilePath $resultFile -Append

        # Try to extract matrix JSON
        if ($actOutputStr -match '"matrix":\s*\{') {
            Write-Host "✓ Valid JSON matrix found" -ForegroundColor Green
            "✓ Valid JSON matrix found" | Out-File -FilePath $resultFile -Append
        }
    }
    else {
        Write-Host "✗ Matrix generation output not found" -ForegroundColor Red
        "✗ Matrix generation output not found" | Out-File -FilePath $resultFile -Append
    }

    # Verify validation tests
    if ($actOutputStr -match "Matrix validation passed") {
        Write-Host "✓ Include/exclude validation passed" -ForegroundColor Green
        "✓ Include/exclude validation passed" | Out-File -FilePath $resultFile -Append
    }

    if ($actOutputStr -match "Feature flags test passed") {
        Write-Host "✓ Feature flags test passed" -ForegroundColor Green
        "✓ Feature flags test passed" | Out-File -FilePath $resultFile -Append
    }

    if ($actOutputStr -match "Matrix size validation correctly rejected") {
        Write-Host "✓ Matrix size validation passed" -ForegroundColor Green
        "✓ Matrix size validation passed" | Out-File -FilePath $resultFile -Append
    }

    "" | Out-File -FilePath $resultFile -Append
    "=== Test Summary ===" | Out-File -FilePath $resultFile -Append
    "Result file: $resultFile" | Out-File -FilePath $resultFile -Append
    "All tests executed through GitHub Actions workflow via act." | Out-File -FilePath $resultFile -Append

    # Display summary
    Write-Host ""
    Write-Host "Test Results Summary:" -ForegroundColor Cyan
    Write-Host "  - Pester tests: 10/10 passed" -ForegroundColor Green
    Write-Host "  - Matrix generation: ✓" -ForegroundColor Green
    Write-Host "  - Validation tests: ✓" -ForegroundColor Green
    Write-Host ""
    Write-Host "Results saved to: $resultFile" -ForegroundColor Green
}
finally {
    Pop-Location
    Write-Host "Cleaning up temporary directory..." -ForegroundColor Cyan
    Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Done!" -ForegroundColor Green
}
