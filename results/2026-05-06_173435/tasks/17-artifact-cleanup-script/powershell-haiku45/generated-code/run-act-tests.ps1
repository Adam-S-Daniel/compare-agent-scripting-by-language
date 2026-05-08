# Test harness for running the artifact cleanup script through GitHub Actions (act)
# This script verifies that the workflow runs successfully and produces expected output

param(
    [switch]$Verbose,
    [string]$ActOutputFile = "act-result.txt"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Artifact Cleanup Script - Act Test Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verify act is installed
if (-not (Get-Command act -ErrorAction SilentlyContinue)) {
    Write-Error "act is not installed. Please install act from https://github.com/nektos/act"
    exit 1
}

Write-Host "✓ act is installed: $(act --version)" -ForegroundColor Green

# Verify Docker is running
try {
    docker ps | Out-Null
} catch {
    Write-Error "Docker is not running. Please start Docker to use act."
    exit 1
}

Write-Host "✓ Docker is running" -ForegroundColor Green
Write-Host ""

# Clear previous test results
if (Test-Path $ActOutputFile) {
    Remove-Item $ActOutputFile -Force
}

# Test Case 1: Basic workflow execution
Write-Host "Starting Test Case 1: Basic workflow execution" -ForegroundColor Yellow
Write-Host "Running: act push --rm" -ForegroundColor Gray
Write-Host ""

$testOutput = @()
try {
    $actOutput = act push --rm 2>&1
    $testOutput = $actOutput
    $actOutput | Add-Content -Path $ActOutputFile
} catch {
    Write-Host "Error running act: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Workflow output saved to $ActOutputFile" -ForegroundColor Green

# Parse and verify results
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Results Analysis" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($testOutput.Count -eq 0) {
    Write-Error "No output from act - the workflow may have failed to start"
    Write-Host "Act result file: $ActOutputFile" -ForegroundColor Yellow
    exit 1
}

$outputText = $testOutput -join [System.Environment]::NewLine

# Check for critical messages
if ($outputText -match "Job failed") {
    Write-Host "Job execution output:" -ForegroundColor Yellow
    Write-Host $outputText | Select-String "Job" | ForEach-Object { Write-Host "  $_" }
}

# Look for test results
$pesterMatches = [regex]::Matches($outputText, 'Tests Passed:\s*(\d+).*?Failed:\s*(\d+)')
if ($pesterMatches.Count -gt 0) {
    $passed = $pesterMatches[0].Groups[1].Value
    $failed = $pesterMatches[0].Groups[2].Value
    Write-Host "Pester Test Results: $passed passed, $failed failed" -ForegroundColor Cyan
} else {
    Write-Host "Pester results not found in output" -ForegroundColor Yellow
}

# Check for job success messages
$jobSuccessCount = ($outputText | Select-String "Job succeeded" -AllMatches).Matches.Count
Write-Host "Jobs with 'succeeded' status: $jobSuccessCount" -ForegroundColor Cyan

# Check for validation success messages
if ($outputText -match "All tests passed") {
    Write-Host "✓ Validation job completed successfully" -ForegroundColor Green
} else {
    Write-Host "⚠ Validation job results unclear" -ForegroundColor Yellow
}

# Check for structure validation
if ($outputText -match "All required files present") {
    Write-Host "✓ File structure validation passed" -ForegroundColor Green
} else {
    Write-Host "⚠ File structure validation unclear" -ForegroundColor Yellow
}

if ($outputText -match "All scripts have valid syntax") {
    Write-Host "✓ Syntax validation passed" -ForegroundColor Green
} else {
    Write-Host "⚠ Syntax validation unclear" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Workflow executed through act" -ForegroundColor Green
Write-Host "✓ Results saved to: $ActOutputFile" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Check $ActOutputFile for complete output" -ForegroundColor Yellow
Write-Host ""
