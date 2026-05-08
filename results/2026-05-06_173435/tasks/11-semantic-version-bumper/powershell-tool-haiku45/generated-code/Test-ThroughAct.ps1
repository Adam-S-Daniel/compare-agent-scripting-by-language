# Test-ThroughAct.ps1
# Runs the semantic version bumper tests through GitHub Actions via act

param(
    [string]$OutputFile = "./act-result.txt"
)

$ErrorActionPreference = "Stop"
$actRunCount = 0
$actFailures = @()
$testResults = @()

# Clean up the output file if it exists
if (Test-Path $OutputFile) {
    Remove-Item $OutputFile -Force
}

Write-Host "========================================" | Tee-Object -FilePath $OutputFile -Append
Write-Host "Testing Semantic Version Bumper via Act" | Tee-Object -FilePath $OutputFile -Append
Write-Host "========================================" | Tee-Object -FilePath $OutputFile -Append
Write-Host ""

# Define test cases
$testCases = @(
    @{
        name      = "Unit Tests"
        command   = "pwsh -Command `"Invoke-Pester ./SemanticVersionBumper.Tests.ps1 -PassThru`""
        expectPattern = "Tests Passed: 20"
    },
    @{
        name    = "Workflow Structure Validation"
        command = "test -f .github/workflows/semantic-version-bumper.yml && echo 'Workflow exists' || (echo 'Workflow missing'; exit 1)"
        expectPattern = "Workflow exists"
    },
    @{
        name    = "ActionLint Validation"
        command = "actionlint .github/workflows/semantic-version-bumper.yml && echo 'ActionLint passed' || (echo 'ActionLint failed'; exit 1)"
        expectPattern = "passed"
    }
)

Write-Host "Running Act with GitHub Actions workflow..." | Tee-Object -FilePath $OutputFile -Append
Write-Host ""

try {
    # Run act for the push event
    Write-Host "Executing: act push --rm" | Tee-Object -FilePath $OutputFile -Append

    $actOutput = & act push --rm 2>&1
    $actExitCode = $LASTEXITCODE
    $actRunCount++

    $actOutput | Tee-Object -FilePath $OutputFile -Append

    if ($actExitCode -eq 0) {
        Write-Host ""
        Write-Host "✓ Act execution completed successfully (exit code 0)" | Tee-Object -FilePath $OutputFile -Append
        $testResults += @{
            name   = "Act Execution"
            passed = $true
            exitCode = $actExitCode
        }
    }
    else {
        Write-Host ""
        Write-Host "✗ Act execution failed (exit code $actExitCode)" | Tee-Object -FilePath $OutputFile -Append
        $testResults += @{
            name   = "Act Execution"
            passed = $false
            exitCode = $actExitCode
        }
        $actFailures += "Act execution failed with exit code $actExitCode"
    }

    # Verify key patterns in output
    Write-Host ""
    Write-Host "Validating output patterns..." | Tee-Object -FilePath $OutputFile -Append

    $patterns = @(
        "Run Unit Tests"
        "Run Pester tests"
        "test-unit"
        "test-integration"
        "validate-workflow"
    )

    foreach ($pattern in $patterns) {
        if ($actOutput -match $pattern) {
            Write-Host "✓ Found pattern: $pattern" | Tee-Object -FilePath $OutputFile -Append
        }
        else {
            Write-Host "⚠ Pattern not found: $pattern" | Tee-Object -FilePath $OutputFile -Append
        }
    }

}
catch {
    Write-Host ""
    Write-Host "✗ Error running act: $_" | Tee-Object -FilePath $OutputFile -Append
    $testResults += @{
        name   = "Act Execution"
        passed = $false
        error  = $_
    }
    $actFailures += "Error: $_"
}

# Print summary
Write-Host ""
Write-Host "========================================" | Tee-Object -FilePath $OutputFile -Append
Write-Host "Test Summary" | Tee-Object -FilePath $OutputFile -Append
Write-Host "========================================" | Tee-Object -FilePath $OutputFile -Append

$passedCount = ($testResults | Where-Object { $_.passed }).Count
$failedCount = ($testResults | Where-Object { -not $_.passed }).Count

Write-Host "Act Runs:       $actRunCount" | Tee-Object -FilePath $OutputFile -Append
Write-Host "Tests Passed:   $passedCount" | Tee-Object -FilePath $OutputFile -Append
Write-Host "Tests Failed:   $failedCount" | Tee-Object -FilePath $OutputFile -Append
Write-Host ""

if ($actFailures.Count -gt 0) {
    Write-Host "Failures:" | Tee-Object -FilePath $OutputFile -Append
    foreach ($failure in $actFailures) {
        Write-Host "  - $failure" | Tee-Object -FilePath $OutputFile -Append
    }
    Write-Host ""
    exit 1
}
else {
    Write-Host "✓ All tests passed!" | Tee-Object -FilePath $OutputFile -Append
    Write-Host ""
    exit 0
}
