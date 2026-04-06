# run-tests.ps1
# Convenience script: install Pester if missing, then run the test suite.
# Usage: pwsh run-tests.ps1

Set-Location $PSScriptRoot

# Ensure Pester >= 5.0 is available
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0' })) {
    Write-Host "Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion 5.0

# Run the test suite
$result = Invoke-Pester -Path (Join-Path $PSScriptRoot 'SecretRotationValidator.Tests.ps1') `
    -Output Normal -PassThru

Write-Host ""
Write-Host "Results: Total=$($result.TotalCount)  Passed=$($result.PassedCount)  Failed=$($result.FailedCount)" `
    -ForegroundColor $(if ($result.FailedCount -eq 0) { 'Green' } else { 'Red' })

exit $result.FailedCount
