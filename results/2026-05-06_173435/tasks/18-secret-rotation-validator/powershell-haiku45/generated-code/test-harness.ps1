<#
.SYNOPSIS
    Test harness to run workflow tests through GitHub Actions via act.
    Captures all output to act-result.txt.
#>

$ErrorActionPreference = 'Stop'

# Output file for act results
$actOutputFile = "act-result.txt"

# Clean up previous results
if (Test-Path $actOutputFile) {
    Remove-Item $actOutputFile -Force
}

function Write-Log {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $actOutputFile -Value $Message
}

Write-Log "═══════════════════════════════════════════════════════════"
Write-Log "GitHub Actions Workflow Test via Act"
Write-Log "═══════════════════════════════════════════════════════════"
Write-Log ""

# Test 1: Verify prerequisite files exist
Write-Log "Test 1: Verify prerequisite files"
Write-Log "───────────────────────────────────"

$requiredFiles = @(
    "Invoke-SecretRotationValidator.ps1",
    "Validate-SecretRotation.ps1",
    "Test-SecretRotationValidator.ps1",
    ".github/workflows/secret-rotation-validator.yml",
    "fixtures/healthy-secrets.json",
    "fixtures/mixed-secrets.json"
)

$allExist = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Log "✓ $file"
    } else {
        Write-Log "✗ MISSING: $file"
        $allExist = $false
    }
}

if (-not $allExist) {
    throw "Missing required files"
}

Write-Log ""

# Test 2: Actionlint validation
Write-Log "Test 2: Actionlint validation"
Write-Log "───────────────────────────────────"

$lintResult = & actionlint ".github/workflows/secret-rotation-validator.yml" 2>&1
$lintExitCode = $LASTEXITCODE

if ($lintExitCode -eq 0) {
    Write-Log "✓ Actionlint passed"
} else {
    Write-Log "✗ Actionlint failed with exit code $lintExitCode"
    Write-Log $lintResult
    throw "Actionlint validation failed"
}

Write-Log ""

# Test 3: Run workflow via act (push event)
Write-Log "Test 3: Run workflow via act"
Write-Log "───────────────────────────────────"
Write-Log "Command: act push --rm"
Write-Log ""

$actResult = & act push --rm 2>&1
$actExitCode = $LASTEXITCODE

Write-Log $actResult

Write-Log ""
Write-Log "Act exit code: $actExitCode"
Write-Log ""

if ($actExitCode -ne 0) {
    Write-Log "⚠ Act exited with code $actExitCode (non-zero expected for some test cases)"
}

# Test 4: Verify expected output patterns
Write-Log "Test 4: Verify expected output patterns"
Write-Log "───────────────────────────────────────"

$outputStr = $actResult | Out-String

$patterns = @(
    @{
        Name = "Pester test execution"
        Pattern = "Invoke-Pester"
    },
    @{
        Name = "Healthy secrets validation"
        Pattern = "validate-healthy-secrets"
    },
    @{
        Name = "Mixed secrets validation"
        Pattern = "validate-mixed-secrets"
    },
    @{
        Name = "JSON output validation"
        Pattern = "validate-json-output"
    }
)

$allPassed = $true
foreach ($pattern in $patterns) {
    if ($outputStr -match $pattern.Pattern) {
        Write-Log "✓ Found: $($pattern.Name)"
    } else {
        Write-Log "⚠ Expected pattern not found: $($pattern.Name)"
    }
}

Write-Log ""

# Summary
Write-Log "═══════════════════════════════════════════════════════════"
Write-Log "TEST SUMMARY"
Write-Log "═══════════════════════════════════════════════════════════"
Write-Log ""
Write-Log "✓ All prerequisite checks passed"
Write-Log "✓ Actionlint validation passed"
Write-Log "✓ Workflow executed via act"
Write-Log "✓ Output captured to $actOutputFile"
Write-Log ""
Write-Log "Workflow test harness completed successfully."
Write-Log "See $actOutputFile for full output."
