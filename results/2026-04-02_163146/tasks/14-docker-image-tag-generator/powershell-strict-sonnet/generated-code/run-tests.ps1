Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]'5.0' })) {
    Write-Host 'Installing Pester 5...'
    Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion 5.0 -Force

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'DockerTagGenerator.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $false

Invoke-Pester -Configuration $config
