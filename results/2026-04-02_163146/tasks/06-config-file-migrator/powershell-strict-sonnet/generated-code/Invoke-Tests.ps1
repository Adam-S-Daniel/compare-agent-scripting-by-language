# Invoke-Tests.ps1
# Entry point: installs Pester if needed and runs all tests.
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Ensure Pester v5+ is available
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { [version]$_.Version -ge [version]'5.0' })) {
    Write-Host 'Installing Pester v5...'
    Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser
}

Import-Module Pester -MinimumVersion 5.0

[string]$TestFile = Join-Path $PSScriptRoot 'ConfigMigrator.Tests.ps1'

Write-Host "Running tests: $TestFile"
$result = Invoke-Pester -Path $TestFile -Output Detailed -PassThru

if ($result.FailedCount -gt 0) {
    Write-Error "Tests FAILED: $($result.FailedCount) failed, $($result.PassedCount) passed."
    exit 1
}

Write-Host "All $($result.PassedCount) tests PASSED."
exit 0
