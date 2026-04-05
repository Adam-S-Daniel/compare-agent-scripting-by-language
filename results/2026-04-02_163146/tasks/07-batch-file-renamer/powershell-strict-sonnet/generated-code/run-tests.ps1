Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Install Pester if not present
if (-not (Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'5.0.0' })) {
    Write-Host 'Installing Pester 5...'
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion 5.0.0

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'BatchFileRenamer.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $true

Invoke-Pester -Configuration $config
