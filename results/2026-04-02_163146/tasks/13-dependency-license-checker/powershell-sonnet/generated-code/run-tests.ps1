$ErrorActionPreference = 'Stop'

# Ensure Pester 5 is available
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]'5.0' }
if (-not $pesterModule) {
    Write-Host "Installing Pester 5..."
    Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion 5.0
    Write-Host "Pester installed."
}

$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot/LicenseChecker.Tests.ps1"
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $true

Invoke-Pester -Configuration $config
