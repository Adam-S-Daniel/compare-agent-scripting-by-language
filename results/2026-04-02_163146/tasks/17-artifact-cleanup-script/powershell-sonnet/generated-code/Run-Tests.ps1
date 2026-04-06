# Run-Tests.ps1
# Installs Pester if needed, then runs all tests.

# Ensure Pester 5+ is installed
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { [version]$_.Version -ge [version]'5.0' })) {
    Write-Host "Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
}

Import-Module Pester -MinimumVersion 5.0

$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot/ArtifactCleanup.Tests.ps1"
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = "$PSScriptRoot/TestResults.xml"

Invoke-Pester -Configuration $config
