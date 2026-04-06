# RunTests.ps1 — install Pester if needed, then invoke the test suite
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0' })) {
    Write-Host 'Installing Pester 5.x...'
    Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion 5.0
}

Import-Module Pester -MinimumVersion 5.0

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'MatrixGenerator.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $false

Invoke-Pester -Configuration $config
