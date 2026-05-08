param(
    [switch]$Verbose
)

# Initialize result file
$resultFile = "act-result.txt"
"Test Results - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $resultFile
"=" * 80 | Out-File -FilePath $resultFile -Append

# Test case 1: Workflow structure validation
Write-Host "=== Test Case 1: Workflow structure validation ==="

$workflowFile = '.github/workflows/pr-label-assigner.yml'
$workflowValid = Test-Path $workflowFile

"" | Out-File -FilePath $resultFile -Append
"TEST CASE 1: Workflow structure validation" | Out-File -FilePath $resultFile -Append
"Workflow file exists: $workflowValid" | Out-File -FilePath $resultFile -Append

if ($workflowValid) {
    $yaml = Get-Content $workflowFile -Raw
    $hasJobs = $yaml -match 'jobs:'
    $hasTest = $yaml -match 'test:'
    $hasIntegration = $yaml -match 'integration-test:'
    $hasLint = $yaml -match 'lint:'

    "Contains jobs: $hasJobs" | Out-File -FilePath $resultFile -Append
    "Contains test job: $hasTest" | Out-File -FilePath $resultFile -Append
    "Contains integration-test job: $hasIntegration" | Out-File -FilePath $resultFile -Append
    "Contains lint job: $hasLint" | Out-File -FilePath $resultFile -Append

    if ($hasJobs -and $hasTest -and $hasIntegration) {
        Write-Host "✓ Test case 1 passed: Workflow structure valid" -ForegroundColor Green
    } else {
        Write-Host "✗ Test case 1 failed: Missing expected workflow sections" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Test case 1 failed: Workflow file not found" -ForegroundColor Red
}

# Test case 2: Verify Pester tests pass
Write-Host "=== Test Case 2: Verify Pester tests ==="
Write-Host "Running Pester tests locally..."
$testOutput = Invoke-Pester Tests/PrLabelAssigner.Tests.ps1 -PassThru -Verbose:$Verbose
$testExitCode = $LASTEXITCODE

"" | Out-File -FilePath $resultFile -Append
"TEST CASE 2: Pester test verification" | Out-File -FilePath $resultFile -Append
"Exit Code: $testExitCode" | Out-File -FilePath $resultFile -Append
"Tests Passed: $($testOutput.PassedCount)" | Out-File -FilePath $resultFile -Append
"Tests Failed: $($testOutput.FailedCount)" | Out-File -FilePath $resultFile -Append
"" | Out-File -FilePath $resultFile -Append

if ($testOutput.FailedCount -eq 0 -and $testOutput.PassedCount -gt 0) {
    Write-Host "✓ Test case 2 passed: All $($testOutput.PassedCount) Pester tests passed" -ForegroundColor Green
} else {
    Write-Host "✗ Test case 2 failed: $($testOutput.FailedCount) tests failed" -ForegroundColor Red
}

# Test case 3: Integration test - label assignment
Write-Host "=== Test Case 3: Label assignment integration test ==="
$testFiles = @(
    'docs/README.md',
    'src/api/endpoints.ps1',
    'Tests/unit.test.ps1',
    '.github/workflows/deploy.yml'
)

$labels = ./AssignPrLabels.ps1 -Files $testFiles 2>&1 | Where-Object { $_ -notmatch '^Applied|^Labels|^  -' }

"" | Out-File -FilePath $resultFile -Append
"TEST CASE 3: Integration test - label assignment" | Out-File -FilePath $resultFile -Append
"Input files: $($testFiles -join ', ')" | Out-File -FilePath $resultFile -Append
"Output labels: $($labels -join ', ')" | Out-File -FilePath $resultFile -Append
"" | Out-File -FilePath $resultFile -Append

$expectedLabels = @('documentation', 'api', 'source', 'tests', 'ci', 'devops')
$missingLabels = $expectedLabels | Where-Object { $_ -notin $labels }

if ($missingLabels.Count -eq 0) {
    Write-Host "✓ Test case 3 passed: All expected labels found" -ForegroundColor Green
    Write-Host "  Labels: $($labels -join ', ')" -ForegroundColor Green
} else {
    Write-Host "✗ Test case 3 failed: Missing labels: $($missingLabels -join ', ')" -ForegroundColor Red
}

# Test case 4: Config validation
Write-Host "=== Test Case 4: Config file validation ==="
$configValid = Test-Path 'label-config.json'
$parseable = $false

if ($configValid) {
    try {
        $config = Get-Content -Path 'label-config.json' -Raw | ConvertFrom-Json
        $parseable = $config.rules -and $config.rules.Count -gt 0
    }
    catch {
        Write-Host "✗ Config file not parseable: $_" -ForegroundColor Red
    }
}

"" | Out-File -FilePath $resultFile -Append
"TEST CASE 4: Config file validation" | Out-File -FilePath $resultFile -Append
"Config exists: $configValid" | Out-File -FilePath $resultFile -Append
"Config parseable: $parseable" | Out-File -FilePath $resultFile -Append
"Rule count: $(if ($config) { $config.rules.Count } else { 0 })" | Out-File -FilePath $resultFile -Append
"" | Out-File -FilePath $resultFile -Append

if ($configValid -and $parseable) {
    Write-Host "✓ Test case 4 passed: Config file valid with $($config.rules.Count) rules" -ForegroundColor Green
} else {
    Write-Host "✗ Test case 4 failed: Config file invalid" -ForegroundColor Red
}

# Final summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Results written to: $resultFile"
Write-Host ""

# Count results
$passCount = 4
$failCount = 0

if ($testOutput.FailedCount -gt 0) { $failCount++; $passCount-- }
if ($missingLabels.Count -gt 0) { $failCount++; $passCount-- }
if (-not ($configValid -and $parseable)) { $failCount++; $passCount-- }

Write-Host "Passed: $passCount/4"
Write-Host "Failed: $failCount/4"

if ($failCount -eq 0) {
    Write-Host "" -ForegroundColor Green
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
} else {
    Write-Host "" -ForegroundColor Red
    Write-Host "Some tests failed. Check output above and $resultFile for details." -ForegroundColor Red
    exit 1
}
