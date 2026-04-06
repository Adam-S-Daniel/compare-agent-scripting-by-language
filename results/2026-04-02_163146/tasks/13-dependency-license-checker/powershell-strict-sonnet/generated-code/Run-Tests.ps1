# Run-Tests.ps1
# Installs Pester if needed, then runs the test suite.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Ensure Pester is available
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]'5.0' })) {
    Write-Host "Installing Pester 5..." -ForegroundColor Cyan
    Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion '5.0'
}

Import-Module Pester -MinimumVersion '5.0' -Force

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'LicenseChecker.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $PSScriptRoot 'TestResults.xml'

Invoke-Pester -Configuration $config
