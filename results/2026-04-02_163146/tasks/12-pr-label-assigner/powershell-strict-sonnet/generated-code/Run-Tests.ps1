#Requires -Version 7.0
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Ensure Pester 5.x is installed
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { [version]$_.Version -ge [version]'5.0.0' })) {
    Write-Host 'Installing Pester 5.x...' -ForegroundColor Cyan
    Install-Module -Name Pester -MinimumVersion '5.0.0' -Force -Scope CurrentUser
}

Import-Module Pester -MinimumVersion '5.0.0'

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'PrLabelAssigner.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $true

Invoke-Pester -Configuration $config
