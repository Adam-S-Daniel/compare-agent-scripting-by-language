# run-tests.ps1
# Helper script to install Pester (if needed) and run the test suite

$ErrorActionPreference = 'Continue'

$pester = Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Sort-Object Version -Descending | Select-Object -First 1

if (-not $pester) {
    Write-Host "Installing Pester 5.x..."
    Install-Module Pester -Force -SkipPublisherCheck -MinimumVersion 5.0.0 -Scope CurrentUser
}

Import-Module Pester -MinimumVersion 5.0.0 -Force

$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot/LogAnalyzer.Tests.ps1"
$config.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $config
