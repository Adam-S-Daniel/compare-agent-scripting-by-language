#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests the GitHub Actions workflow with different test cases.
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("approved", "denied")]
    [string]$TestCase = "approved"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Testing Dependency License Checker Workflow ===" -ForegroundColor Cyan

# Test Case 1: All approved licenses
if ($TestCase -eq "approved") {
    Write-Host "`nTest Case 1: All approved licenses"
    Write-Host "-----------------------------------" -ForegroundColor Yellow

    # Create temp git repo for act
    $tempDir = [System.IO.Path]::GetTempPath()
    $repoDir = Join-Path $tempDir "test-repo-approved"

    if (Test-Path $repoDir) {
        Remove-Item -Path $repoDir -Recurse -Force
    }

    mkdir $repoDir | Out-Null
    Set-Location $repoDir

    # Copy files
    Copy-Item -Path "$PSScriptRoot/.github" -Destination . -Recurse -Force
    Copy-Item -Path "$PSScriptRoot/DependencyLicenseChecker.ps1" -Destination . -Force
    Copy-Item -Path "$PSScriptRoot/Check-DependencyLicenses.ps1" -Destination . -Force
    Copy-Item -Path "$PSScriptRoot/DependencyLicenseChecker.Tests.ps1" -Destination . -Force
    Copy-Item -Path "$PSScriptRoot/test-fixtures" -Destination . -Recurse -Force
    Copy-Item -Path "$PSScriptRoot/.actrc" -Destination . -Force

    # Initialize git repo
    git init 2>&1 | Out-Null
    git config user.email "test@example.com" | Out-Null
    git config user.name "Test User" | Out-Null
    git add . | Out-Null
    git commit -m "Initial commit" 2>&1 | Out-Null

    # Run act
    Write-Host "Running workflow with approved licenses..."
    $output = act push --rm 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "✓ Test PASSED: Workflow succeeded with all approved licenses" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Test FAILED: Workflow failed with exit code $exitCode" -ForegroundColor Red
        Write-Host $output
        exit 1
    }

    Set-Location $PSScriptRoot
}

# Test Case 2: Denied licenses
elseif ($TestCase -eq "denied") {
    Write-Host "`nTest Case 2: Denied licenses (GPL-3.0)"
    Write-Host "-----------------------------------" -ForegroundColor Yellow

    # Create temp git repo for act
    $tempDir = [System.IO.Path]::GetTempPath()
    $repoDir = Join-Path $tempDir "test-repo-denied"

    if (Test-Path $repoDir) {
        Remove-Item -Path $repoDir -Recurse -Force
    }

    mkdir $repoDir | Out-Null
    Set-Location $repoDir

    # Copy files
    Copy-Item -Path "$PSScriptRoot/.github" -Destination . -Recurse -Force
    Copy-Item -Path "$PSScriptRoot/DependencyLicenseChecker.ps1" -Destination . -Force
    Copy-Item -Path "$PSScriptRoot/Check-DependencyLicenses.ps1" -Destination . -Force
    Copy-Item -Path "$PSScriptRoot/DependencyLicenseChecker.Tests.ps1" -Destination . -Force
    Copy-Item -Path "$PSScriptRoot/test-fixtures" -Destination . -Recurse -Force
    Copy-Item -Path "$PSScriptRoot/.actrc" -Destination . -Force

    # Initialize git repo
    git init 2>&1 | Out-Null
    git config user.email "test@example.com" | Out-Null
    git config user.name "Test User" | Out-Null
    git add . | Out-Null
    git commit -m "Initial commit" 2>&1 | Out-Null

    # Run act with GPL package
    Write-Host "Running workflow with GPL-licensed dependency..."
    $output = act push --rm -e <(ConvertTo-Json @{
        MANIFEST_FILE = "test-fixtures/package-with-gpl.json"
    }) 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "✓ Test PASSED: Workflow correctly failed with denied licenses" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Test FAILED: Workflow should have failed but succeeded" -ForegroundColor Red
        exit 1
    }

    Set-Location $PSScriptRoot
}

Write-Host "`n=== All workflow tests completed ===" -ForegroundColor Cyan
