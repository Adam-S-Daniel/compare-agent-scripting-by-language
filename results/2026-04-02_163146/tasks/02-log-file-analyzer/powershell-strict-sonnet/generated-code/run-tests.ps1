Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge '5.0' })) {
    Write-Host 'Installing Pester...'
    Install-Module Pester -MinimumVersion 5.0 -Force -Scope CurrentUser -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion 5.0

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'LogAnalyzer.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $false

Invoke-Pester -Configuration $config
