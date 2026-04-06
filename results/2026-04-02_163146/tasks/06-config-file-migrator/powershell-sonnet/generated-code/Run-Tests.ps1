# Run-Tests.ps1
# Convenience script to install Pester (if needed) and run all tests.

# Ensure Pester 5+ is available
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 5 })) {
    Write-Host "Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
}

Import-Module Pester -MinimumVersion 5.0.0

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot "ConfigMigrator.Tests.ps1"
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $PSScriptRoot "TestResults.xml"

Invoke-Pester -Configuration $config
