<#
.SYNOPSIS
Test harness for running GitHub Actions workflow through act.

.DESCRIPTION
Sets up temporary test repositories and runs the workflow via act,
capturing and validating output.
#>

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputFile = Join-Path $scriptDir "act-result.txt"
$testCases = @()
$allPassed = $true

function Invoke-ActTest {
    param(
        [string]$TestName,
        [string]$Description,
        [hashtable[]]$Secrets,
        [string[]]$ExpectedPatterns
    )

    Write-Host "Running test: $TestName" -ForegroundColor Cyan

    $tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)")
    try {
        Set-Location $tempDir

        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"

        Copy-Item "$scriptDir/Invoke-SecretRotationValidator.ps1" .
        Copy-Item "$scriptDir/Invoke-SecretRotationValidator.Tests.ps1" .
        Copy-Item -Recurse "$scriptDir/.github" .

        git add -A
        git commit -q -m "Initial commit"

        $actOutput = & act push --rm 2>&1
        $actExitCode = $LASTEXITCODE

        Add-Content $outputFile ""
        Add-Content $outputFile "=== Test: $TestName ==="
        Add-Content $outputFile $actOutput

        if ($actExitCode -ne 0) {
            Write-Host "  ✗ FAILED: act exited with code $actExitCode" -ForegroundColor Red
            $allPassed = $false
        }
        else {
            $output = $actOutput | Out-String

            $jobSucceeded = $output -match "Job succeeded"
            if (-not $jobSucceeded) {
                Write-Host "  ✗ FAILED: Job did not succeed" -ForegroundColor Red
                $allPassed = $false
            }

            $allPatternsMatch = $true
            foreach ($pattern in $ExpectedPatterns) {
                if ($output -notmatch $pattern) {
                    Write-Host "  ✗ FAILED: Pattern not found: $pattern" -ForegroundColor Red
                    $allPatternsMatch = $false
                    $allPassed = $false
                }
            }

            if ($jobSucceeded -and $allPatternsMatch) {
                Write-Host "  ✓ PASSED" -ForegroundColor Green
            }
        }
    }
    finally {
        Set-Location $scriptDir
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    }
}

Set-Location $scriptDir

"Running GitHub Actions workflow tests via act..." | Out-String | Add-Content $outputFile

Invoke-ActTest `
    -TestName "Pester Tests" `
    -Description "Validates that all Pester tests pass" `
    -ExpectedPatterns @(
        "Tests passed",
        "validate"
    )

Invoke-ActTest `
    -TestName "Markdown Output" `
    -Description "Validates markdown report generation" `
    -ExpectedPatterns @(
        "# Secret Rotation Report",
        "## Expired",
        "## Warning",
        "## Ok"
    )

Invoke-ActTest `
    -TestName "JSON Output" `
    -Description "Validates JSON report generation" `
    -ExpectedPatterns @(
        "`"ok`"",
        "`"expired`"",
        "prod-secret"
    )

Write-Host ""
Write-Host "Test harness completed."
Write-Host "Results saved to: $outputFile"

if (-not $allPassed) {
    Write-Host "Some tests failed!" -ForegroundColor Red
    exit 1
}

Write-Host "All tests passed!" -ForegroundColor Green
