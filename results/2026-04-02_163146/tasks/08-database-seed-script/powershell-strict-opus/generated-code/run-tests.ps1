#!/usr/bin/env pwsh
# run-tests.ps1 - Runs the Pester test suite for DatabaseSeed module.
# Ensures Pester 5+ is available, then runs tests with detailed output.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Ensure we're in the script's directory
Set-Location $PSScriptRoot

# Check for Pester 5+
[object]$pesterMod = Get-Module -ListAvailable -Name Pester |
    Where-Object { [version]$_.Version -ge [version]'5.0.0' } |
    Select-Object -First 1

if ($null -eq $pesterMod) {
    Write-Host 'Pester 5 not found. Installing to CurrentUser scope...' -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion '5.0' -Force -SkipPublisherCheck -Scope CurrentUser
    Write-Host 'Pester installed.' -ForegroundColor Green
}

Import-Module -Name Pester -MinimumVersion '5.0' -Force

# Configure and run tests
[PesterConfiguration]$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'DatabaseSeed.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $true

Invoke-Pester -Configuration $config
