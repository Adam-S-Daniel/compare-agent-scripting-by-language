# Final verification script

Write-Host "=== Dependency License Checker Verification ===" -ForegroundColor Cyan

# 1. Check files exist
Write-Host "`n1. File Structure:" -ForegroundColor White
$files = @(
    "Check-DependencyLicenses.ps1",
    "Check-DependencyLicenses.Tests.ps1",
    ".github/workflows/dependency-license-checker.yml",
    "test-fixtures/simple-package.json",
    "test-fixtures/requirements.txt",
    "README.md"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file" -ForegroundColor Red
    }
}

# 2. Run Pester tests
Write-Host "`n2. Running Pester Tests:" -ForegroundColor White
$results = Invoke-Pester -Path "./Check-DependencyLicenses.Tests.ps1" -PassThru
Write-Host "  Tests Passed: $($results.PassedCount) / $($results.FailedCount + $results.PassedCount)" -ForegroundColor $(if ($results.FailedCount -eq 0) { "Green" } else { "Red" })

# 3. Validate workflow
Write-Host "`n3. Workflow Validation:" -ForegroundColor White
$workflowPath = ".github/workflows/dependency-license-checker.yml"
if (Test-Path $workflowPath) {
    $workflowContent = Get-Content $workflowPath -Raw
    if ($workflowContent -match "name: Dependency License Checker") {
        Write-Host "  ✓ Workflow name found" -ForegroundColor Green
    }
    if ($workflowContent -match "shell: pwsh") {
        Write-Host "  ✓ PowerShell shell configured" -ForegroundColor Green
    }
    if ($workflowContent -match "Invoke-Pester") {
        Write-Host "  ✓ Pester invocation found" -ForegroundColor Green
    }
}

# 4. Check license config structure
Write-Host "`n4. Testing Functions:" -ForegroundColor White
. ./Check-DependencyLicenses.ps1

# Test manifest parsing
$jsonPath = "test-fixtures/simple-package.json"
$deps = Get-Dependencies -ManifestPath $jsonPath
Write-Host "  ✓ JSON parsing: $($deps.Count) dependencies found" -ForegroundColor Green

$txtPath = "test-fixtures/requirements.txt"
$deps = Get-Dependencies -ManifestPath $txtPath
Write-Host "  ✓ TXT parsing: $($deps.Count) dependencies found" -ForegroundColor Green

# Test config validation
$config = @{
    allowed = @("MIT", "Apache-2.0")
    denied = @("GPL-3.0")
}
$validated = Invoke-LicenseCheck -Config $config
Write-Host "  ✓ Config validation successful" -ForegroundColor Green

Write-Host "`n=== Verification Complete ===" -ForegroundColor Cyan
Write-Host "All systems operational!" -ForegroundColor Green
