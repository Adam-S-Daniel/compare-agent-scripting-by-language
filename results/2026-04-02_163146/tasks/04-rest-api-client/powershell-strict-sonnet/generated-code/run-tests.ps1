# run-tests.ps1
# Installs Pester 5+ if not already available, then runs the test suite.
# Usage: pwsh ./run-tests.ps1

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Check for Pester 5+
[object]$pesterMod = Get-Module -ListAvailable -Name Pester |
    Where-Object { [Version]$_.Version -ge [Version]'5.0.0' } |
    Select-Object -First 1

if ($null -eq $pesterMod) {
    Write-Host 'Pester 5 not found. Installing to CurrentUser scope...' -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion '5.0' -Force -SkipPublisherCheck -Scope CurrentUser
    Write-Host 'Pester installed.' -ForegroundColor Green
} else {
    Write-Host "Pester $($pesterMod.Version) found." -ForegroundColor Cyan
}

Import-Module -Name Pester -MinimumVersion '5.0' -Force

[string]$testFile = Join-Path -Path $PSScriptRoot -ChildPath 'RestApiClient.Tests.ps1'
Invoke-Pester -Path $testFile -Output Detailed
