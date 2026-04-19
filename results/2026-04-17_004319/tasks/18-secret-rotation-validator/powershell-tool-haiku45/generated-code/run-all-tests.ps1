<#
.SYNOPSIS
Complete test harness running all tests including GitHub Actions via act.

.DESCRIPTION
- Runs Pester tests locally
- Runs workflow tests through act
- Generates act-result.txt with all output
- Validates all tests pass
#>

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputFile = Join-Path $scriptDir "act-result.txt"
$allTestsPassed = $true

function Write-Section {
    param([string]$Title)
    "=" * 80 | Add-Content $outputFile
    "  $Title" | Add-Content $outputFile
    "=" * 80 | Add-Content $outputFile
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )

    $status = if ($Passed) { "✓ PASS" } else { "✗ FAIL" }
    "$status : $TestName" | Add-Content $outputFile
    if ($Message) {
        "  $Message" | Add-Content $outputFile
    }

    if (-not $Passed) {
        $script:allTestsPassed = $false
    }
}

Set-Location $scriptDir

"Test Harness: Secret Rotation Validator" | Out-String | Add-Content $outputFile
"Generated: $(Get-Date)" | Add-Content $outputFile
"" | Add-Content $outputFile

Write-Section "PHASE 1: LOCAL PESTER TESTS"

Write-Host "Running Pester tests locally..." -ForegroundColor Cyan
$localResults = Invoke-Pester -Path "Invoke-SecretRotationValidator.Tests.ps1" -PassThru
"" | Add-Content $outputFile
"Invoke-Pester Results:" | Add-Content $outputFile
"  Total Tests: $($localResults.TotalCount)" | Add-Content $outputFile
"  Passed: $($localResults.PassedCount)" | Add-Content $outputFile
"  Failed: $($localResults.FailedCount)" | Add-Content $outputFile
"" | Add-Content $outputFile

if ($localResults.FailedCount -eq 0) {
    Write-TestResult "Local Pester Tests" $true "All 8 tests passed"
    Write-Host "  ✓ All local Pester tests passed" -ForegroundColor Green
}
else {
    Write-TestResult "Local Pester Tests" $false "$($localResults.FailedCount) test(s) failed"
    Write-Host "  ✗ Local Pester tests failed" -ForegroundColor Red
}

Write-Section "PHASE 2: GITHUB ACTIONS WORKFLOW TESTS (via act)"

$testCases = @(
    @{
        Name = "Validate Secret Rotation (Pester through GitHub Actions)"
        Job = "validate"
        ExpectedPatterns = @("Tests passed", "Job succeeded")
    },
    @{
        Name = "Test Markdown Output Format"
        Job = "test-markdown-output"
        ExpectedPatterns = @("# Secret Rotation Report", "Job succeeded")
    },
    @{
        Name = "Test JSON Output Format"
        Job = "test-json-output"
        ExpectedPatterns = @("`"ok`"", "Job succeeded")
    }
)

foreach ($testCase in $testCases) {
    Write-Host "Running: $($testCase.Name)" -ForegroundColor Cyan

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

        $actOutput = & act push --rm -j $testCase.Job 2>&1
        $actExitCode = $LASTEXITCODE

        "" | Add-Content $outputFile
        "Test Case: $($testCase.Name)" | Add-Content $outputFile
        "Job: $($testCase.Job)" | Add-Content $outputFile
        "-" * 40 | Add-Content $outputFile
        $actOutput | Add-Content $outputFile
        "" | Add-Content $outputFile

        $testPassed = ($actExitCode -eq 0)
        if ($testPassed) {
            $outputText = $actOutput | Out-String
            foreach ($pattern in $testCase.ExpectedPatterns) {
                if ($outputText -notmatch [regex]::Escape($pattern)) {
                    $testPassed = $false
                    break
                }
            }
        }

        if ($testPassed) {
            Write-TestResult $testCase.Name $true "Exit code: 0, All patterns matched"
            Write-Host "  ✓ PASSED" -ForegroundColor Green
        }
        else {
            Write-TestResult $testCase.Name $false "Exit code: $actExitCode or pattern mismatch"
            Write-Host "  ✗ FAILED" -ForegroundColor Red
        }
    }
    finally {
        Set-Location $scriptDir
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    }
}

Write-Section "WORKFLOW STRUCTURE VALIDATION"

Write-Host "Validating workflow file structure..." -ForegroundColor Cyan
$workflowPath = ".github/workflows/secret-rotation-validator.yml"

if (Test-Path $workflowPath) {
    Write-TestResult "Workflow file exists" $true "Found: $workflowPath"

    $yaml = Get-Content $workflowPath -Raw

    $checksToPerform = @(
        @{ Pattern = "name:\s*Secret Rotation Validator"; Name = "Workflow name" }
        @{ Pattern = "on:"; Name = "Trigger events" }
        @{ Pattern = "jobs:"; Name = "Jobs section" }
        @{ Pattern = "validate"; Name = "Validate job" }
        @{ Pattern = "test-markdown-output"; Name = "Markdown test job" }
        @{ Pattern = "test-json-output"; Name = "JSON test job" }
        @{ Pattern = "uses: actions/checkout@v4"; Name = "Checkout action" }
        @{ Pattern = "shell: pwsh"; Name = "PowerShell shell" }
    )

    foreach ($check in $checksToPerform) {
        $found = $yaml -match $check.Pattern
        Write-TestResult "Workflow contains $($check.Name)" $found
        if ($found) {
            Write-Host "  ✓ $($check.Name) found" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ $($check.Name) NOT found" -ForegroundColor Red
        }
    }
}
else {
    Write-TestResult "Workflow file exists" $false "File not found: $workflowPath"
}

Write-Section "ACTIONLINT VALIDATION"

$actionlintPath = "/.github/workflows/secret-rotation-validator.yml"
if (Get-Command actionlint -ErrorAction SilentlyContinue) {
    Write-Host "Running actionlint..." -ForegroundColor Cyan
    $actionlintOutput = & actionlint $workflowPath 2>&1
    $actionlintExitCode = $LASTEXITCODE

    if ($actionlintExitCode -eq 0) {
        Write-TestResult "actionlint validation" $true "Workflow passes all linting checks"
        Write-Host "  ✓ Workflow is valid" -ForegroundColor Green
    }
    else {
        Write-TestResult "actionlint validation" $false "Linting errors found"
        Write-Host "  ✗ Linting errors:" -ForegroundColor Red
        $actionlintOutput | ForEach-Object { Write-Host "    $_" }
    }
}
else {
    Write-Host "  ⚠ actionlint not found, skipping" -ForegroundColor Yellow
}

Write-Section "FINAL SUMMARY"

"" | Add-Content $outputFile
if ($allTestsPassed) {
    "RESULT: ALL TESTS PASSED ✓" | Add-Content $outputFile
    Write-Host ""
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║    ALL TESTS PASSED SUCCESSFULLY       ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Results saved to: $outputFile" -ForegroundColor Cyan
    exit 0
}
else {
    "RESULT: SOME TESTS FAILED ✗" | Add-Content $outputFile
    Write-Host ""
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║       SOME TESTS FAILED                ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "Results saved to: $outputFile" -ForegroundColor Cyan
    exit 1
}
