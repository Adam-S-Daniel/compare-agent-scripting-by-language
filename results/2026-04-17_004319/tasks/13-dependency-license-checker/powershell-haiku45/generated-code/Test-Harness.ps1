#!/usr/bin/env pwsh

# Test harness that runs the GitHub Actions workflow through act
# Captures output and validates results

[CmdletBinding()]
param(
    [string]$ActResultsFile = "./act-result.txt"
)

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
}

function Run-ActTest {
    param(
        [string]$TestName,
        [hashtable]$Env = @{}
    )

    Write-Host "`n[TEST] $TestName" -ForegroundColor Yellow

    # Add environment variables if provided
    $actEnv = @{
        "GITHUB_REPOSITORY" = "test/repo"
        "GITHUB_REF" = "refs/heads/main"
        "GITHUB_EVENT_NAME" = "push"
    } + $Env

    # Run act with the workflow
    Write-Host "Running act push --rm --job dependency-license-check..."

    try {
        $output = & act push --rm --job dependency-license-check 2>&1 | ForEach-Object { $_.ToString() }
        $exitCode = $LASTEXITCODE

        # Append to results file
        Add-Content -Path $ActResultsFile -Value "=================================================================================="
        Add-Content -Path $ActResultsFile -Value "TEST: $TestName"
        Add-Content -Path $ActResultsFile -Value "=================================================================================="
        Add-Content -Path $ActResultsFile -Value $output
        Add-Content -Path $ActResultsFile -Value ""

        if ($exitCode -ne 0) {
            Write-Host "[FAILED] Exit code: $exitCode" -ForegroundColor Red
            Write-Host "Last output lines:"
            $output[-10..-1] | ForEach-Object { Write-Host "  $_" }
            return $false
        }

        Write-Host "[PASSED]" -ForegroundColor Green

        # Validate output contains expected markers
        $outputStr = $output -join "`n"
        if ($outputStr -match "Job succeeded") {
            Write-Host "✓ Job completed successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "✗ Job did not complete successfully" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $ActResultsFile -Value "ERROR: $($_.Exception.Message)"
        return $false
    }
}

function Test-WorkflowStructure {
    Write-Header "Workflow Structure Validation"

    $workflowPath = ".github/workflows/dependency-license-checker.yml"

    if (-not (Test-Path $workflowPath)) {
        Write-Host "[FAILED] Workflow file not found: $workflowPath" -ForegroundColor Red
        return $false
    }

    Write-Host "[PASSED] Workflow file exists" -ForegroundColor Green

    # Parse YAML (PowerShell doesn't have built-in YAML parser, so we do basic checks)
    $content = Get-Content $workflowPath -Raw

    $checks = @(
        @{ Pattern = "on:"; Description = "Trigger events defined" }
        @{ Pattern = "jobs:"; Description = "Jobs defined" }
        @{ Pattern = "shell: pwsh"; Description = "PowerShell shell configured" }
        @{ Pattern = "Checkout code"; Description = "Checkout step present" }
        @{ Pattern = "dependency-license-check"; Description = "License check job present" }
        @{ Pattern = "Run-LicenseCheck.ps1"; Description = "Script reference correct" }
    )

    $passed = 0
    foreach ($check in $checks) {
        if ($content -match $check.Pattern) {
            Write-Host "  ✓ $($check.Description)" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  ✗ $($check.Description)" -ForegroundColor Red
        }
    }

    Write-Host "`nStructure checks: $passed/$($checks.Count) passed"
    return $passed -eq $checks.Count
}

function Test-ActionLint {
    Write-Header "ActionLint Validation"

    $workflowPath = ".github/workflows/dependency-license-checker.yml"

    try {
        $output = & actionlint $workflowPath 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Host "[PASSED] ActionLint validation successful" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[FAILED] ActionLint validation failed" -ForegroundColor Red
            Write-Host $output
            return $false
        }
    } catch {
        Write-Host "[ERROR] ActionLint not available or error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-ScriptFiles {
    Write-Header "Script File Validation"

    $requiredFiles = @(
        "DependencyLicenseChecker.ps1"
        "Run-LicenseCheck.ps1"
        "DependencyLicenseChecker.Tests.ps1"
        "config.json"
        "package.json"
    )

    $passed = 0
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-Host "  ✓ $file" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  ✗ $file not found" -ForegroundColor Red
        }
    }

    Write-Host "`nFile checks: $passed/$($requiredFiles.Count) passed"
    return $passed -eq $requiredFiles.Count
}

function Main {
    Write-Header "Dependency License Checker - GitHub Actions Test Harness"

    # Clean up old results file
    if (Test-Path $ActResultsFile) {
        Remove-Item $ActResultsFile
    }

    $allPassed = $true

    # Run validation tests
    $allPassed = (Test-ScriptFiles) -and $allPassed
    $allPassed = (Test-ActionLint) -and $allPassed
    $allPassed = (Test-WorkflowStructure) -and $allPassed

    # Run act-based tests
    Write-Header "GitHub Actions Workflow Tests (via act)"

    # Test 1: Basic workflow run with package.json
    Write-Host "`nTest Case 1: Basic Dependency Check (package.json)" -ForegroundColor Yellow
    $test1 = Run-ActTest -TestName "Basic package.json check"
    $allPassed = $test1 -and $allPassed

    # Test 2: Verify report generation
    Write-Host "`nTest Case 2: Report Generation" -ForegroundColor Yellow
    if (Test-Path "./license-report-npm.json") {
        $report = Get-Content "./license-report-npm.json" | ConvertFrom-Json
        $approved = ($report | Where-Object { $_.status -eq "approved" }).Count
        Write-Host "Report generated with $approved approved dependencies" -ForegroundColor Green
    }

    # Summary
    Write-Header "Test Results Summary"

    if (Test-Path $ActResultsFile) {
        $resultSize = (Get-Item $ActResultsFile).Length
        Write-Host "Act results saved to: $ActResultsFile ($resultSize bytes)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "First 20 lines of results:"
        Get-Content $ActResultsFile -TotalCount 20 | ForEach-Object { Write-Host "  $_" }
    }

    if ($allPassed) {
        Write-Host ""
        Write-Host "[OVERALL] All tests PASSED! ✓" -ForegroundColor Green
        exit 0
    } else {
        Write-Host ""
        Write-Host "[OVERALL] Some tests FAILED! ✗" -ForegroundColor Red
        exit 1
    }
}

Main
