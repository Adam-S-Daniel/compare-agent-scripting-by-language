# run-tests.ps1
# Convenience script: installs Pester if needed, then runs all tests.

# Install Pester 5 if it is not already available
if (-not (Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -ge '5.0' })) {
    Write-Host "Pester 5 not found — installing..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion '5.0' -Force -Scope CurrentUser -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion '5.0'

# Run all tests with detailed output
$result = Invoke-Pester -Path "$PSScriptRoot/SearchReplace.Tests.ps1" -Output Detailed -PassThru

# Exit with non-zero code if any tests failed (useful for CI)
if ($result.FailedCount -gt 0) {
    exit 1
}
